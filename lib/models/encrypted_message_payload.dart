class EncryptedMessagePayload {
  const EncryptedMessagePayload({
    required this.encryptedMessage,
    required this.recipientEncryptedSymmetricKey,
    required this.initializationVector,
    this.senderEncryptedSymmetricKey,
    this.algorithm = 'AES-256-CBC/RSA-2048',
  });

  final String encryptedMessage;
  final String recipientEncryptedSymmetricKey;
  final String initializationVector;
  final String? senderEncryptedSymmetricKey;
  final String algorithm;

  Map<String, dynamic> toMap() {
    return {
      'encryptedMessage': encryptedMessage,
      'encryptedSymmetricKey': recipientEncryptedSymmetricKey,
      'recipientEncryptedSymmetricKey': recipientEncryptedSymmetricKey,
      'senderEncryptedSymmetricKey': senderEncryptedSymmetricKey,
      'initializationVector': initializationVector,
      'algorithm': algorithm,
    };
  }

  factory EncryptedMessagePayload.fromMap(Map<String, dynamic> map) {
    final recipientKey =
        (map['recipientEncryptedSymmetricKey'] ?? map['encryptedSymmetricKey'] ?? '')
            .toString();

    return EncryptedMessagePayload(
      encryptedMessage: (map['encryptedMessage'] ?? '').toString(),
      recipientEncryptedSymmetricKey: recipientKey,
      initializationVector: (map['initializationVector'] ?? '').toString(),
      senderEncryptedSymmetricKey:
          map['senderEncryptedSymmetricKey']?.toString(),
      algorithm:
          (map['algorithm'] ?? 'AES-256-CBC/RSA-2048').toString(),
    );
  }
}
