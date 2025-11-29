import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GuestAuthService extends ChangeNotifier {
  static const _guestUserIdKey = 'guest_user_id';

  String? _userId;
  bool _initialized = false;

  String? get userId => _userId;
  bool get isGuest => _userId != null;
  bool get isInitializing => !_initialized;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString(_guestUserIdKey);
    _initialized = true;
    notifyListeners();
  }

  Future<void> signInAsGuest() async {
    if (!_initialized) {
      await initialize();
    }

    if (_userId != null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _userId = _generateGuestId();
    await prefs.setString(_guestUserIdKey, _userId!);
    notifyListeners();
  }

  Future<void> signOut() async {
    if (!_initialized) {
      await initialize();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestUserIdKey);
    _userId = null;
    notifyListeners();
  }

  String _generateGuestId() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(1 << 32);
    return 'guest_${timestamp}_$randomPart';
  }
}
