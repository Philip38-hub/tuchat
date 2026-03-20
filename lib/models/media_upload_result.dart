class MediaUploadResult {
  const MediaUploadResult({
    required this.path,
    required this.publicUrl,
    required this.mimeType,
  });

  final String path;
  final String publicUrl;
  final String mimeType;
}
