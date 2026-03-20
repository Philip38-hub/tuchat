import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

ImageProvider<Object>? buildProfileImageProvider(String? profilePicUrl) {
  final value = profilePicUrl?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }

  if (value.startsWith('data:image/') && value.contains(',')) {
    final bytes = decodeProfileImageBytes(value);
    if (bytes != null) {
      return MemoryImage(bytes);
    }
    return null;
  }

  return NetworkImage(value);
}

Uint8List? decodeProfileImageBytes(String? profilePicUrl) {
  final value = profilePicUrl?.trim() ?? '';
  if (!value.startsWith('data:image/') || !value.contains(',')) {
    return null;
  }

  final encoded = value.substring(value.indexOf(',') + 1);
  try {
    return base64Decode(encoded);
  } catch (_) {
    return null;
  }
}
