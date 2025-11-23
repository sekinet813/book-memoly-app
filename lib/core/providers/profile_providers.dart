import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/profile.dart';
import '../services/profile_service.dart';
import '../services/supabase_service.dart';
import 'auth_providers.dart';

final profileServiceProvider = Provider<ProfileService?>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  if (supabase == null) {
    return null;
  }
  return ProfileService(client: supabase.client);
});

class ProfileState {
  const ProfileState({
    this.profile,
    this.isLoading = true,
    this.isSaving = false,
    this.errorMessage,
  });

  final UserProfile? profile;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  ProfileState copyWith({
    UserProfile? profile,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier(this._ref) : super(const ProfileState()) {
    _loadProfile();
  }

  final Ref _ref;

  ProfileService? get _service => _ref.read(profileServiceProvider);
  String? get _userId => _ref.read(currentUserIdProvider);

  Future<void> _loadProfile() async {
    final service = _service;
    final userId = _userId;

    if (service == null || userId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final profile = await service.fetchProfile(userId);
      state = state.copyWith(
        profile: profile ?? UserProfile(userId: userId, name: ''),
        isLoading: false,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to load profile: $error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription('Failed to load profile'),
        ),
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'プロフィールの読み込みに失敗しました。',
      );
    }
  }

  Future<bool> saveProfile({
    required String name,
    String? bio,
    required List<String> readingThemes,
  }) async {
    final service = _service;
    final userId = _userId;

    if (service == null || userId == null) {
      state = state.copyWith(
        errorMessage: 'プロフィール機能を使用するにはSupabaseの設定が必要です。',
      );
      return false;
    }

    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final profile = (state.profile ??
              UserProfile(userId: userId, name: name, bio: bio))
          .copyWith(
        name: name,
        bio: bio,
        readingThemes: readingThemes,
      );

      final saved = await service.upsertProfile(profile);
      state = state.copyWith(profile: saved, isSaving: false);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Failed to save profile: $error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription('Failed to save profile'),
        ),
      );
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'プロフィールの保存に失敗しました。',
      );
      return false;
    }
  }

  Future<bool> uploadAvatar(XFile file) async {
    final service = _service;
    final userId = _userId;

    if (service == null || userId == null) {
      state = state.copyWith(
        errorMessage: 'プロフィール機能を使用するにはSupabaseの設定が必要です。',
      );
      return false;
    }

    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final bytes = await file.readAsBytes();
      final url = await service.uploadAvatar(
        userId: userId,
        fileBytes: bytes,
        fileName: file.name,
      );

      final updatedProfile = (state.profile ??
              UserProfile(userId: userId, name: '', avatarUrl: url))
          .copyWith(avatarUrl: url);

      state = state.copyWith(profile: updatedProfile, isSaving: false);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Failed to upload avatar: $error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription('Failed to upload avatar'),
        ),
      );
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'アバターのアップロードに失敗しました。',
      );
      return false;
    }
  }

  void reload() {
    _loadProfile();
  }

  void handleUserChanged() {
    state = const ProfileState();
    _loadProfile();
  }
}

final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final notifier = ProfileNotifier(ref);

  ref.listen<String?>(currentUserIdProvider, (previous, next) {
    if (previous != next) {
      notifier.handleUserChanged();
    }
  });

  return notifier;
});
