import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';

import '../lib/src/mysql_client/caching_sha2_auth.dart';

void main() {
  test('parsePemPublicKey', () {
    const pem = """
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuK1YlZZvQv38l/F6oB4I
v91H5hXJv8+b4LhL4Qh1+qkV8I449qL+fR0hO6GjL+rOxgxLZL39Q8XjQ2N4Fk9/
uI2+Z2B15aZ8D7t6Yg4K6F35M7t2P7z6XzZq+6z9sHqD8nJ0zB+y1M0d7Q0M6j8I
D5C8q1F2V1H8B3L5X6q2+gJc0j4H9N3/Z9aX8f1F9F2W3D0D8H4Y5qZ7g+U3O7f+
eU2V2A7R5H7y9D3/N1j0F8f7C8o0F+U9U2s9/W4D1A9Y1P7A/o0Q6Q2Y2A1g7p6F
+F4b5H2v0G6R+1t4c2f1w6D+r0X5V8g4K1K2X3M0a3I7f8C6H/Q0f5G6v+u6/h7D
1QIDAQAB
-----END PUBLIC KEY-----
""";

    var key = parsePemPublicKey(pem);

    // Check exponent
    expect(key.exponent, equals(BigInt.from(65537)));
    // Check modulus bit length
    expect(key.modulus.bitLength, greaterThan(2047));
  });

  test('encryptPassword output length', () {
    const pem = """
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuK1YlZZvQv38l/F6oB4I
v91H5hXJv8+b4LhL4Qh1+qkV8I449qL+fR0hO6GjL+rOxgxLZL39Q8XjQ2N4Fk9/
uI2+Z2B15aZ8D7t6Yg4K6F35M7t2P7z6XzZq+6z9sHqD8nJ0zB+y1M0d7Q0M6j8I
D5C8q1F2V1H8B3L5X6q2+gJc0j4H9N3/Z9aX8f1F9F2W3D0D8H4Y5qZ7g+U3O7f+
eU2V2A7R5H7y9D3/N1j0F8f7C8o0F+U9U2s9/W4D1A9Y1P7A/o0Q6Q2Y2A1g7p6F
+F4b5H2v0G6R+1t4c2f1w6D+r0X5V8g4K1K2X3M0a3I7f8C6H/Q0f5G6v+u6/h7D
1QIDAQAB
-----END PUBLIC KEY-----
""";
    var key = parsePemPublicKey(pem);

    var scramble = Uint8List.fromList(List.generate(20, (i) => i));
    var pwd = encryptPassword("password", scramble, key);

    // 2048-bit key -> 256 bytes output
    expect(pwd.length, equals(256));
  });
}
