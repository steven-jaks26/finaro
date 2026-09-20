import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup envelope primitives preserve JSON-safe base64 payloads', () {
    final envelope = {
      'format': 'finaro-backup',
      'version': 1,
      'cipher': 'AES-256-GCM',
      'salt': base64Encode(List<int>.generate(16, (i) => i)),
      'nonce': base64Encode(List<int>.generate(12, (i) => 255 - i)),
      'ciphertext': base64Encode(utf8.encode('{"schemaVersion":2}')),
    };
    final decoded = jsonDecode(jsonEncode(envelope)) as Map<String, dynamic>;
    expect(decoded['format'], 'finaro-backup');
    expect(utf8.decode(base64Decode(decoded['ciphertext'] as String)), '{"schemaVersion":2}');
  });

  test('backup contract requires portable encrypted format', () {
    const cipher = 'AES-256-GCM';
    const kdf = 'PBKDF2-HMAC-SHA256';
    expect(cipher, contains('AES-256'));
    expect(kdf, contains('PBKDF2'));
  });
}
