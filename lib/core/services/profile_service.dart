import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

class ProfileService {
  ProfileService({required SupabaseClient client}) : _client = client;

  static const _profilesTable = 'profiles';
  static const _avatarsBucket = 'avatars';

  final SupabaseClient _client;

  Future<UserProfile?> fetchProfile(String userId) async {
    final response = await _client
        .from(_profilesTable)
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return UserProfile.fromMap(response);
  }

  Future<UserProfile> upsertProfile(UserProfile profile) async {
    final response = await _client
        .from(_profilesTable)
        .upsert(profile.toMap())
        .select()
        .single();

    return UserProfile.fromMap(response);
  }

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List fileBytes,
    String? fileName,
    String? mimeType,
  }) async {
    final extension = path.extension(fileName ?? '').replaceFirst('.', '');
    final safeExtension = extension.isEmpty ? 'jpg' : extension;
    final objectName =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

    await _client.storage.from(_avatarsBucket).uploadBinary(
          objectName,
          fileBytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: true,
            contentType: mimeType ?? 'image/$safeExtension',
          ),
        );

    final publicUrl =
        _client.storage.from(_avatarsBucket).getPublicUrl(objectName);
    debugPrint('Uploaded avatar to $publicUrl');
    return publicUrl;
  }
}
