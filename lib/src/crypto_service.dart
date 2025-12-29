import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class AtomCryptoService {
  static final iv = Uint8List.fromList(List<int>.generate(16, (i) => i));

  static Future<String> encrypt(
    String plainText,
    Uint8List password,
    Uint8List salt,
  ) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha512(),
      iterations: 65536,
      bits: 256,
    );

    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(password),
      nonce: salt,
    );

    final aes = AesCbc.with256bits(
      macAlgorithm: MacAlgorithm.empty,
      paddingAlgorithm: PaddingAlgorithm.pkcs7,
    );

    final box = await aes.encrypt(
      utf8.encode(plainText),
      secretKey: key,
      nonce: iv,
    );

    return box.cipherText
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static Future<String> decrypt(
    String hexCipher,
    Uint8List password,
    Uint8List salt,
  ) async {
    final cipher = <int>[];
    for (var i = 0; i < hexCipher.length; i += 2) {
      cipher.add(int.parse(hexCipher.substring(i, i + 2), radix: 16));
    }

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha512(),
      iterations: 65536,
      bits: 256,
    );

    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(password),
      nonce: salt,
    );

    final aes = AesCbc.with256bits(
      macAlgorithm: MacAlgorithm.empty,
      paddingAlgorithm: PaddingAlgorithm.pkcs7,
    );

    final box = SecretBox(cipher, nonce: iv, mac: Mac.empty);

    final decrypted = await aes.decrypt(box, secretKey: key);
    return utf8.decode(decrypted);
  }
}
