import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:tuchat/models/encrypted_message_payload.dart';
import 'package:tuchat/services/base_service.dart';

class StoredKeyPair {
  const StoredKeyPair({
    required this.publicKey,
    required this.privateKey,
  });

  final String publicKey;
  final String privateKey;
}

class EncryptionService extends BaseService {
  EncryptionService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  static const String _privateKeyPrefix = 'rsa_private_key';
  static const String _publicKeyPrefix = 'rsa_public_key';

  Future<StoredKeyPair> ensureKeyPair({
    required String uid,
    String? expectedPublicKey,
  }) async {
    try {
      final storedPrivateKey = await _secureStorage.read(
        key: _privateKeyStorageKey(uid),
      );
      final storedPublicKey = await _secureStorage.read(
        key: _publicKeyStorageKey(uid),
      );

      final hasStoredPair =
          storedPrivateKey != null &&
          storedPrivateKey.isNotEmpty &&
          storedPublicKey != null &&
          isValidPublicKey(storedPublicKey);
      final expectedKeyIsValid =
          expectedPublicKey != null && isValidPublicKey(expectedPublicKey);

      if (hasStoredPair &&
          (!expectedKeyIsValid || storedPublicKey == expectedPublicKey)) {
        return StoredKeyPair(
          publicKey: storedPublicKey,
          privateKey: storedPrivateKey,
        );
      }

      final generatedPair = generateKeyPair();
      await _persistKeyPair(uid: uid, keyPair: generatedPair);
      return generatedPair;
    } catch (e) {
      logError('Failed to ensure RSA key pair: $e');
      throw handleException(e);
    }
  }

  Future<EncryptedMessagePayload> encryptMessage({
    required String plainText,
    required String recipientPublicKey,
  }) async {
    try {
      if (plainText.isEmpty) {
        throw 'Message cannot be empty.';
      }

      if (!isValidPublicKey(recipientPublicKey)) {
        throw 'Recipient public key is invalid.';
      }

      final random = Random.secure();
      final aesKeyBytes = _randomBytes(random, 32);
      final ivBytes = _randomBytes(random, 16);

      final aesEncrypter = encrypt.Encrypter(
        encrypt.AES(
          encrypt.Key(Uint8List.fromList(aesKeyBytes)),
          mode: encrypt.AESMode.cbc,
        ),
      );
      final encryptedBody = aesEncrypter.encrypt(
        plainText,
        iv: encrypt.IV(Uint8List.fromList(ivBytes)),
      );

      final publicKey =
          encrypt.RSAKeyParser().parse(recipientPublicKey) as RSAPublicKey;
      final rsaEncrypter = encrypt.Encrypter(
        encrypt.RSA(
          publicKey: publicKey,
          encoding: encrypt.RSAEncoding.PKCS1,
        ),
      );
      final encryptedSymmetricKey = rsaEncrypter.encryptBytes(aesKeyBytes);

      return EncryptedMessagePayload(
        encryptedMessage: encryptedBody.base64,
        encryptedSymmetricKey: encryptedSymmetricKey.base64,
        initializationVector: base64Encode(ivBytes),
      );
    } catch (e) {
      logError('Failed to encrypt message: $e');
      throw handleException(e);
    }
  }

  Future<String> decryptMessage({
    required String uid,
    required EncryptedMessagePayload payload,
  }) async {
    try {
      final privateKeyPem = await _secureStorage.read(
        key: _privateKeyStorageKey(uid),
      );
      if (privateKeyPem == null || privateKeyPem.isEmpty) {
        throw 'Private key not found on this device.';
      }

      final privateKey =
          encrypt.RSAKeyParser().parse(privateKeyPem) as RSAPrivateKey;
      final rsaEncrypter = encrypt.Encrypter(
        encrypt.RSA(
          privateKey: privateKey,
          encoding: encrypt.RSAEncoding.PKCS1,
        ),
      );

      final aesKey = rsaEncrypter.decryptBytes(
        encrypt.Encrypted.fromBase64(payload.encryptedSymmetricKey),
      );

      final aesEncrypter = encrypt.Encrypter(
        encrypt.AES(
          encrypt.Key(Uint8List.fromList(aesKey)),
          mode: encrypt.AESMode.cbc,
        ),
      );

      return aesEncrypter.decrypt(
        encrypt.Encrypted.fromBase64(payload.encryptedMessage),
        iv: encrypt.IV.fromBase64(payload.initializationVector),
      );
    } catch (e) {
      logError('Failed to decrypt message: $e');
      throw handleException(e);
    }
  }

  bool isValidPublicKey(String publicKey) {
    try {
      final parsedKey = encrypt.RSAKeyParser().parse(publicKey);
      return parsedKey is RSAPublicKey;
    } catch (_) {
      return false;
    }
  }

  StoredKeyPair generateKeyPair() {
    final random = FortunaRandom();
    random.seed(
      KeyParameter(Uint8List.fromList(_randomBytes(Random.secure(), 32))),
    );

    final generator = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
          random,
        ),
      );

    final keyPair = generator.generateKeyPair();
    final publicKey = keyPair.publicKey as RSAPublicKey;
    final privateKey = keyPair.privateKey as RSAPrivateKey;

    return StoredKeyPair(
      publicKey: _encodePublicKeyToPem(publicKey),
      privateKey: _encodePrivateKeyToPem(privateKey),
    );
  }

  Future<String?> getStoredPublicKey(String uid) {
    return _secureStorage.read(key: _publicKeyStorageKey(uid));
  }

  Future<void> _persistKeyPair({
    required String uid,
    required StoredKeyPair keyPair,
  }) async {
    await _secureStorage.write(
      key: _privateKeyStorageKey(uid),
      value: keyPair.privateKey,
    );
    await _secureStorage.write(
      key: _publicKeyStorageKey(uid),
      value: keyPair.publicKey,
    );
  }

  String _privateKeyStorageKey(String uid) => '$_privateKeyPrefix:$uid';

  String _publicKeyStorageKey(String uid) => '$_publicKeyPrefix:$uid';

  List<int> _randomBytes(Random random, int length) {
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  String _encodePublicKeyToPem(RSAPublicKey publicKey) {
    final algorithmSeq = ASN1Sequence()
      ..add(ASN1ObjectIdentifier.fromComponentString('1.2.840.113549.1.1.1'))
      ..add(ASN1Null());

    final publicKeySeq = ASN1Sequence()
      ..add(ASN1Integer(publicKey.modulus!))
      ..add(ASN1Integer(publicKey.exponent!));

    final topLevelSeq = ASN1Sequence()
      ..add(algorithmSeq)
      ..add(ASN1BitString(Uint8List.fromList(publicKeySeq.encodedBytes)));

    return _formatPem(
      'PUBLIC KEY',
      Uint8List.fromList(topLevelSeq.encodedBytes),
    );
  }

  String _encodePrivateKeyToPem(RSAPrivateKey privateKey) {
    final version = ASN1Integer(BigInt.zero);
    final privateKeySeq = ASN1Sequence()
      ..add(version)
      ..add(ASN1Integer(privateKey.n!))
      ..add(ASN1Integer(privateKey.exponent!))
      ..add(ASN1Integer(privateKey.privateExponent!))
      ..add(ASN1Integer(privateKey.p!))
      ..add(ASN1Integer(privateKey.q!))
      ..add(
        ASN1Integer(privateKey.privateExponent! % (privateKey.p! - BigInt.one)),
      )
      ..add(
        ASN1Integer(privateKey.privateExponent! % (privateKey.q! - BigInt.one)),
      )
      ..add(ASN1Integer(privateKey.q!.modInverse(privateKey.p!)));

    return _formatPem(
      'RSA PRIVATE KEY',
      Uint8List.fromList(privateKeySeq.encodedBytes),
    );
  }

  String _formatPem(String label, Uint8List bytes) {
    final base64Key = base64Encode(bytes);
    final chunks = <String>[];
    for (var index = 0; index < base64Key.length; index += 64) {
      final end = (index + 64 < base64Key.length)
          ? index + 64
          : base64Key.length;
      chunks.add(base64Key.substring(index, end));
    }

    return '-----BEGIN $label-----\n'
        '${chunks.join('\n')}\n'
        '-----END $label-----';
  }
}
