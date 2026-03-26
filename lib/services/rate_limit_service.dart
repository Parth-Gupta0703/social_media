// lib/services/rate_limit_service.dart
//
// Client-side rate limiting — pure Dart, no network, no Firebase.
// Rule: minimum 20 seconds must pass between two consecutive posts.

import 'package:flutter/foundation.dart';

class RateLimitResult {
  const RateLimitResult({required this.allowed, this.reason});

  final bool allowed;
  final String? reason; // Only set when allowed == false.

  factory RateLimitResult.allowed() => const RateLimitResult(allowed: true);
  factory RateLimitResult.denied(String reason) =>
      RateLimitResult(allowed: false, reason: reason);
}

class RateLimitService {
  RateLimitService._internal();
  static final RateLimitService instance = RateLimitService._internal();

  static const int _minGapSeconds = 20;

  final List<DateTime> _timestamps = [];

  /// Returns allowed=true if the user may post now.
  /// Returns allowed=false with a human-readable reason if they must wait.
  RateLimitResult canCreatePost() {
    if (_timestamps.isEmpty) return RateLimitResult.allowed();

    final elapsed = DateTime.now().difference(_timestamps.last).inSeconds;
    if (elapsed < _minGapSeconds) {
      final wait = _minGapSeconds - elapsed;
      return RateLimitResult.denied(
        'Please wait $wait more ${wait == 1 ? 'second' : 'seconds'} before posting again.',
      );
    }
    return RateLimitResult.allowed();
  }

  /// Call ONLY after a post is successfully written to Firestore.
  void recordPost() {
    _timestamps.add(DateTime.now());
    debugPrint('[RateLimit] Post recorded.');
  }

  /// Returns seconds remaining until next post is allowed, or 0 if ready now.
  int secondsUntilNextAllowed() {
    if (_timestamps.isEmpty) return 0;
    final elapsed = DateTime.now().difference(_timestamps.last).inSeconds;
    if (elapsed >= _minGapSeconds) return 0;
    return _minGapSeconds - elapsed;
  }

  /// Call on logout to clear state between accounts.
  void reset() {
    _timestamps.clear();
    debugPrint('[RateLimit] Reset.');
  }
}
