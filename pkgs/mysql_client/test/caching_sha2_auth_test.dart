import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mysql_client/src/mysql_client/caching_sha2_auth.dart';
import 'package:test/test.dart';

Uint8List _xor(Uint8List a, Uint8List b) {
  var res = Uint8List(a.length);
  for (var i = 0; i < a.length; i++) {
    res[i] = a[i] ^ b[i];
  }
  return res;
}

Uint8List _mgf1(Uint8List seed, int maskLen) {
  var t = <int>[];
  var counterLimit = (maskLen + 19) ~/ 20;
  var buffer = Uint8List(seed.length + 4);
  buffer.setRange(0, seed.length, seed);
  var byteData = buffer.buffer.asByteData();
  for (var counter = 0; counter < counterLimit; counter++) {
    byteData.setUint32(seed.length, counter, Endian.big);
    t.addAll(sha1.convert(buffer).bytes);
  }
  return Uint8List.fromList(t.sublist(0, maskLen));
}

BigInt _decodeBigInt(Uint8List b) {
  var hex = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join('');
  return BigInt.parse(hex, radix: 16);
}

Uint8List _encodeBigInt(BigInt b, int length) {
  var hex = b.toRadixString(16);
  if (hex.length % 2 != 0) hex = '0$hex';
  var bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  var res = Uint8List(length);
  var start = length - bytes.length;
  res.setAll(start > 0 ? start : 0, bytes);
  return res;
}

String _decryptOAEPAndUnmask(
  Uint8List ciphertext,
  BigInt n,
  BigInt d,
  Uint8List scramble,
) {
  var k = (n.bitLength + 7) >> 3;
  var c = _decodeBigInt(ciphertext);
  var m = c.modPow(d, n);
  var em = _encodeBigInt(m, k);

  expect(em[0], equals(0x00));
  var hLen = 20;
  var maskedSeed = em.sublist(1, 1 + hLen);
  var maskedDB = em.sublist(1 + hLen);

  var seedMask = _mgf1(maskedDB, hLen);
  var seed = _xor(maskedSeed, seedMask);
  var dbMask = _mgf1(seed, k - hLen - 1);
  var db = _xor(maskedDB, dbMask);

  var lHash = sha1.convert(<int>[]).bytes;
  expect(db.sublist(0, hLen), equals(lHash));

  var idx = hLen;
  while (idx < db.length && db[idx] == 0x00) {
    idx++;
  }
  expect(db[idx], equals(0x01));

  var maskedPassword = db.sublist(idx + 1);
  var unmasked = Uint8List(maskedPassword.length);
  for (var i = 0; i < maskedPassword.length; i++) {
    unmasked[i] = maskedPassword[i] ^ scramble[i % scramble.length];
  }
  expect(unmasked.last, equals(0)); // trailing null byte
  return utf8.decode(unmasked.sublist(0, unmasked.length - 1));
}

void main() {
  test('parsePemPublicKey standard and resilient to trailing packet nulls', () {
    const pem = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuK1YlZZvQv38l/F6oB4I
v91H5hXJv8+b4LhL4Qh1+qkV8I449qL+fR0hO6GjL+rOxgxLZL39Q8XjQ2N4Fk9/
uI2+Z2B15aZ8D7t6Yg4K6F35M7t2P7z6XzZq+6z9sHqD8nJ0zB+y1M0d7Q0M6j8I
D5C8q1F2V1H8B3L5X6q2+gJc0j4H9N3/Z9aX8f1F9F2W3D0D8H4Y5qZ7g+U3O7f+
eU2V2A7R5H7y9D3/N1j0F8f7C8o0F+U9U2s9/W4D1A9Y1P7A/o0Q6Q2Y2A1g7p6F
+F4b5H2v0G6R+1t4c2f1w6D+r0X5V8g4K1K2X3M0a3I7f8C6H/Q0f5G6v+u6/h7D
1QIDAQAB
-----END PUBLIC KEY-----
\u0000\u0000
''';

    var key = parsePemPublicKey(pem);
    expect(key.exponent, equals(BigInt.from(65537)));
    expect(key.modulus.bitLength, greaterThan(2047));
  });

  test('encryptPassword round-trip recovery via RSA mathematical decryption', () {
    var mod = BigInt.parse(
      'b41376d3d7b0c3af8e56f3197aace853f1b038d5ed865000ec5f7bcae99f3'
      '950b2a0b32efff9e645cc2eca2b5e5a8d04c4c202c34807ef098c2cae9f026093076358'
      'ef42770eb77c260da2f91a46ee3c36b78020ed38966234a5dbb9706321b54a7efee3e6e'
      '236d01ee50bfc9f95a956dd15c1256e8969768567e7436f142b93',
      radix: 16,
    );
    var exp = BigInt.from(65537);
    var priv = BigInt.parse(
      '86db6cca0965dfa6c1ba6c2450b2dceac0bd705305a6e8934871d98b849a3'
      '19a35ac1384c73ea72cee54bc22ee6e71dd785cb324fbf4b517395add0b48047b16732c'
      '7e82efe70e7a8a75180d0a403cd19c5e0a6a052402c84e1c04f9199244ef70e76a9a98c'
      '06d09eb15274041394c623c05aaabfc210d31aef9e0ded2929dc1',
      radix: 16,
    );

    var pubKey = RSAPublicKey(mod, exp);
    var scramble = Uint8List.fromList(List.generate(20, (i) => i ^ 0x55));
    var pwd = 'secret_database_password_123!';

    var cipher = encryptPassword(pwd, scramble, pubKey);
    expect(cipher.length, equals(128)); // 1024-bit key = 128 bytes

    var recovered = _decryptOAEPAndUnmask(cipher, mod, priv, scramble);
    expect(recovered, equals(pwd));
  });

  test('encryptPassword validates scramble length and modulus sizing', () {
    var mod = BigInt.from(65537); // Very small modulus (< 336 bits)
    var pubKey = RSAPublicKey(mod, BigInt.from(3));

    expect(
      () => encryptPassword('pwd', Uint8List(10), pubKey),
      throwsArgumentError,
    );

    expect(
      () => encryptPassword('pwd', Uint8List(20), pubKey),
      throwsException,
    );
  });
}
