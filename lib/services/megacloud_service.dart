import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

/// Megacloud Stream Decryption Service
class MegacloudService {
  // Megacloud V3 Secret Key (Base64 encoded) - for when encryption is enabled
  static const String _megacloudV3Key =
      '7MeMRClEneUmFoHRO3u3ypzAZXlVgNtBE2pKDw==';

  /// Extract client key (_k) from embed page HTML
  static String? extractClientKey(String html) {
    // Pattern for window._lk_db.x + window._lk_db.y + window._lk_db.z
    final lkDbPattern = RegExp(
      r'window\._lk_db\s*=\s*\{[^}]*["\x27]_k["\x27]\s*:\s*["\x27]([^"\x27]+)',
    );
    final lkDbMatch = lkDbPattern.firstMatch(html);
    if (lkDbMatch != null) return lkDbMatch.group(1);

    // Pattern for data-dpi attribute
    final dpiPattern = RegExp(r'data-dpi=["\x27]([^"\x27]+)');
    final dpiMatch = dpiPattern.firstMatch(html);
    if (dpiMatch != null) return dpiMatch.group(1);

    return null;
  }

  /// Extract data-id from embed page
  static String? extractDataId(String html) {
    final patterns = [
      RegExp(r'data-id=["\x27]([^"\x27]+)'),
      RegExp(r'dataId:["\x27]([^"\x27]+)'),
      RegExp(r'["\x27]dataId["\x27]\s*:\s*["\x27]([^"\x27]+)'),
      RegExp(r'data-id="([^"]+)"'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) return match.group(1);
    }

    return null;
  }

  /// OpenSSL EVP_BytesToKey Key Derivation Function
  static Map<String, Uint8List> evpBytesToKey({
    required Uint8List password,
    required Uint8List salt,
    required int keyLength,
    required int ivLength,
  }) {
    final keyIvLength = keyLength + ivLength;
    final List<Uint8List> derivedBytes = [];
    int lastHashLength = 0;

    while (derivedBytes.length * 16 < keyIvLength) {
      final buffer = BytesBuilder();

      if (lastHashLength > 0) {
        buffer.add(derivedBytes.last);
      }

      buffer.add(password);
      buffer.add(salt);

      Uint8List hash = Uint8List.fromList(md5.convert(buffer.toBytes()).bytes);
      derivedBytes.add(hash);
      lastHashLength = hash.length;
    }

    final allBytes = BytesBuilder();
    for (final bytes in derivedBytes) {
      allBytes.add(bytes);
    }

    final result = allBytes.toBytes();
    return {
      'key': result.sublist(0, keyLength),
      'iv': result.sublist(keyLength, keyLength + ivLength),
    };
  }

  /// Decrypt Salted Base64 ciphertext using AES-256-CBC
  static String decryptSources(String encryptedData) {
    try {
      final encryptedBytes = base64Decode(encryptedData);

      final magic = String.fromCharCodes(encryptedBytes.sublist(0, 8));
      if (magic != 'Salted__') {
        throw Exception('Invalid encrypted data: missing Salted__ header');
      }

      final salt = encryptedBytes.sublist(8, 16);
      final secretKeyBytes = base64Decode(_megacloudV3Key);

      final derived = evpBytesToKey(
        password: secretKeyBytes,
        salt: salt,
        keyLength: 32,
        ivLength: 16,
      );

      final ciphertext = encryptedBytes.sublist(16);

      final key = encrypt.Key(derived['key']!);
      final iv = encrypt.IV(derived['iv']!);

      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
      );

      final decrypted = encrypter.decryptBytes(
        encrypt.Encrypted(ciphertext),
        iv: iv,
      );

      return utf8.decode(decrypted);
    } catch (e) {
      throw Exception('Decryption failed: \$e');
    }
  }

  /// Check if URL is an encrypted source (starts with Salted__ base64)
  static bool isEncryptedSource(String data) {
    try {
      final decoded = base64Decode(data);
      final magic = String.fromCharCodes(decoded.sublist(0, 8));
      return magic == 'Salted__';
    } catch (e) {
      return false;
    }
  }

  /// Decrypt and parse sources in one call
  static Map<String, dynamic> decryptAndParse(String encryptedBase64) {
    final decrypted = decryptSources(encryptedBase64);
    return jsonDecode(decrypted);
  }

  /// Get proxy URL for stream
  static String getProxiedStreamUrl(String originalUrl, String proxyBaseUrl) {
    final encodedUrl = Uri.encodeComponent(originalUrl);
    return '$proxyBaseUrl/proxy?url=$encodedUrl';
  }
}
