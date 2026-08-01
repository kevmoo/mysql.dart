import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class RSAPublicKey {
  final BigInt modulus;
  final BigInt exponent;

  RSAPublicKey(this.modulus, this.exponent);
}

RSAPublicKey parsePemPublicKey(String pem) {
  var base64str = pem
      .split('\n')
      .where(
        (l) =>
            !l.trim().startsWith('-----') &&
            !l.contains('BEGIN') &&
            !l.contains('END'),
      )
      .join('')
      .replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');

  var bytes = base64Decode(base64str);
  var offset = 0;

  int readLength() {
    var len = bytes[offset++];
    if (len & 0x80 != 0) {
      var count = len & 0x7F;
      len = 0;
      for (var i = 0; i < count; i++) {
        len = (len << 8) | bytes[offset++];
      }
    }
    return len;
  }

  void verifyTag(int tag) {
    if (bytes[offset++] != tag) throw FormatException('Expected tag $tag');
  }

  try {
    // SubjectPublicKeyInfo (SEQUENCE)
    verifyTag(0x30);
    readLength();

    // AlgorithmIdentifier (SEQUENCE)
    verifyTag(0x30);
    var algLen = readLength();
    offset += algLen; // skip algorithm identifier

    // subjectPublicKey (BIT STRING)
    verifyTag(0x03);
    readLength();
    // unused bytes
    offset++;

    // RSAPublicKey (SEQUENCE)
    verifyTag(0x30);
    readLength();

    // modulus (INTEGER)
    verifyTag(0x02);
    var modLen = readLength();
    var modulusBytes = bytes.sublist(offset, offset + modLen);
    offset += modLen;

    // exponent (INTEGER)
    verifyTag(0x02);
    var expLen = readLength();
    var exponentBytes = bytes.sublist(offset, offset + expLen);
    offset += expLen;

    BigInt toBigInt(Uint8List b) {
      var hex = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join('');
      return BigInt.parse(hex, radix: 16);
    }

    return RSAPublicKey(toBigInt(modulusBytes), toBigInt(exponentBytes));
  } catch (e) {
    throw FormatException('Invalid PEM format: $e');
  }
}

Uint8List _xorBytes(Uint8List a, Uint8List b) {
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
  if (bytes.length > length) {
    if (bytes.length == length + 1 && bytes[0] == 0) {
      bytes = bytes.sublist(1);
    } else {
      throw Exception('Integer too large for designated target length');
    }
  }
  var res = Uint8List(length);
  var start = length - bytes.length;
  res.setAll(start > 0 ? start : 0, bytes);
  return res;
}

Uint8List encryptPassword(
  String password,
  Uint8List scramble,
  RSAPublicKey key,
) {
  if (scramble.length != 20) {
    throw ArgumentError(
      'Expected 20-byte authentication challenge; got ${scramble.length}',
    );
  }
  var pwdBytes = utf8.encode(password);
  var pwdZero = Uint8List.fromList([...pwdBytes, 0]);
  var maskedPassword = Uint8List(pwdZero.length);
  for (var i = 0; i < pwdZero.length; i++) {
    maskedPassword[i] = pwdZero[i] ^ scramble[i % scramble.length];
  }

  // OAEP Encryption
  var k = (key.modulus.bitLength + 7) >> 3;
  var hLen = 20;

  if (k < 2 * hLen + 2) {
    throw Exception('RSA modulus too small for OAEP SHA-1 padding');
  }

  if (maskedPassword.length > k - 2 * hLen - 2) {
    throw Exception('Message too long');
  }

  var lHash = sha1.convert(<int>[]).bytes;
  var ps = Uint8List(k - maskedPassword.length - 2 * hLen - 2);

  var db = Uint8List.fromList([...lHash, ...ps, 0x01, ...maskedPassword]);

  var rand = Random.secure();
  var seed = Uint8List(hLen);
  for (var i = 0; i < hLen; i++) {
    seed[i] = rand.nextInt(256);
  }

  var dbMask = _mgf1(seed, k - hLen - 1);
  var maskedDB = _xorBytes(db, dbMask);

  var seedMask = _mgf1(maskedDB, hLen);
  var maskedSeed = _xorBytes(seed, seedMask);

  var em = Uint8List.fromList([0x00, ...maskedSeed, ...maskedDB]);

  var m = _decodeBigInt(em);
  var c = m.modPow(key.exponent, key.modulus);

  return _encodeBigInt(c, k);
}
