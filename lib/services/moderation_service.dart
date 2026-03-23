import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ModerationResult {
  const ModerationResult({
    required this.action,
    required this.reason,
    required this.matchedCount,
  });

  final String action;
  final String reason;
  final int matchedCount;

  factory ModerationResult.fromJson(Map<String, dynamic> json) {
    return ModerationResult(
      action: (json['action'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      matchedCount: _parseMatchedCount(json['matched_count']),
    );
  }

  static int _parseMatchedCount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

class ModerationService {
  ModerationService({http.Client? client}) : _client = client ?? http.Client();

  static const String _baseUrl = 'https://safespot-backend-b68n.onrender.com';

  final http.Client _client;
  Timer? _warmUpTimer;

  Future<void> warmUpBackend() async {
    try {
      await _client
          .get(Uri.parse('$_baseUrl/'))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Warm-up failures are intentionally ignored.
    }
  }

  Future<void> startWarmUpSequence() async {
    _warmUpTimer?.cancel();
    await warmUpBackend();

    _warmUpTimer = Timer(const Duration(minutes: 15), () async {
      await warmUpBackend();
      _warmUpTimer = null;
    });
  }

  void cancelWarmUpSequence() {
    _warmUpTimer?.cancel();
    _warmUpTimer = null;
  }

  Future<ModerationResult> moderatePost(String text) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/api/moderate'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Moderation request failed with status ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw Exception('Moderation response is not a valid JSON object.');
      }

      final result = ModerationResult.fromJson(
        Map<String, dynamic>.from(decoded),
      );

      if (result.action != 'allow' && result.action != 'takedown') {
        throw Exception('Unexpected moderation action: ${result.action}.');
      }

      return result;
    } catch (error) {
      throw Exception('Unable to moderate post: $error');
    }
  }

  void dispose() {
    cancelWarmUpSequence();
    _client.close();
  }
}
