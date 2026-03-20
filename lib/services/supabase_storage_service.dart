import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tuchat/config/supabase_config.dart';
import 'package:tuchat/models/media_upload_result.dart';
import 'package:tuchat/services/base_service.dart';

class SupabaseStorageService extends BaseService {
  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw 'Supabase Storage is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY when running the app.';
    }

    return Supabase.instance.client;
  }

  Future<MediaUploadResult> uploadBytes({
    required Uint8List bytes,
    required String path,
    required String mimeType,
  }) async {
    try {
      await _client.storage.from(SupabaseConfig.bucket).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          cacheControl: '3600',
          contentType: mimeType,
          upsert: true,
        ),
      );

      final publicUrl = _client.storage
          .from(SupabaseConfig.bucket)
          .getPublicUrl(path);

      return MediaUploadResult(
        path: path,
        publicUrl: publicUrl,
        mimeType: mimeType,
      );
    } catch (e) {
      logError('Failed to upload bytes to Supabase Storage: $e');
      throw handleException(e);
    }
  }

  Future<Uint8List> downloadBytes(String path) async {
    try {
      return await _client.storage.from(SupabaseConfig.bucket).download(path);
    } catch (e) {
      logError('Failed to download bytes from Supabase Storage: $e');
      throw handleException(e);
    }
  }
}
