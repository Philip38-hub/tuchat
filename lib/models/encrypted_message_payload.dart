class EncryptedMessagePayload {
  const EncryptedMessagePayload({
    required this.encryptedMessage,
    required this.encryptedSymmetricKey,
    required this.initializationVector,
    this.algorithm = 'AES-256-CBC/RSA-2048',
  });

  final String encryptedMessage;
  final String encryptedSymmetricKey;
  final String initializationVector;
  final String algorithm;

  Map<String, dynamic> toMap() {
    return {
      'encryptedMessage': encryptedMessage,
      'encryptedSymmetricKey': encryptedSymmetricKey,
      'initializationVector': initializationVector,
      'algorithm': algorithm,
    };
  }

  factory EncryptedMessagePayload.fromMap(Map<String, dynamic> map) {
    return EncryptedMessagePayload(
      encryptedMessage: (map['encryptedMessage'] ?? '').toString(),
      encryptedSymmetricKey: (map['encryptedSymmetricKey'] ?? '').toString(),
      initializationVector: (map['initializationVector'] ?? '').toString(),
      algorithm:
          (map['algorithm'] ?? 'AES-256-CBC/RSA-2048').toString(),
    );
  }
}
