import 'dart:convert';

import '../../core/crypto/digest.dart';

/// A MovieBox visitor session.
class MovieBoxSession {
  const MovieBoxSession({
    required this.token,
    required this.createdAt,
    this.userId,
    this.expiresAt,
  });

  final String token;
  final String? userId;
  final int? expiresAt;
  final int createdAt;

  /// Sessions are considered valid for 7 days when no expiry is advertised.
  bool isValid() {
    if (token.trim().isEmpty) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiry = expiresAt;
    if (expiry != null) {
      return now + 60 < expiry;
    }
    return now < createdAt + 7 * 24 * 3600;
  }

  /// Builds a session from a raw token, extracting claims when possible.
  factory MovieBoxSession.fromTokenAndPayload(
    String token, {
    String? explicitUserId,
  }) {
    final claims = parseJwtClaims(token);
    return MovieBoxSession(
      token: token,
      userId: explicitUserId ?? claims.userId,
      expiresAt: claims.expiresAt,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'user_id': userId,
    'expires_at': expiresAt,
    'created_at': createdAt,
  };

  factory MovieBoxSession.fromJson(Map<String, dynamic> json) =>
      MovieBoxSession(
        token: json['token'] as String? ?? '',
        userId: json['user_id'] as String?,
        expiresAt: (json['expires_at'] as num?)?.toInt(),
        createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      );
}

/// The user id and expiry embedded in a JWT.
class JwtClaims {
  const JwtClaims({this.userId, this.expiresAt});

  final String? userId;
  final int? expiresAt;
}

/// Extracts the `userId`/`uid`/`sub` and `exp` claims of a JWT.
JwtClaims parseJwtClaims(String token) {
  final parts = token.split('.');
  if (parts.length < 2) return const JwtClaims();

  final payload = parts[1];
  final decoded = base64DecodeTolerant(payload);
  if (decoded == null) return const JwtClaims();

  Object? json;
  try {
    json = jsonDecode(utf8.decode(decoded));
  } on FormatException {
    return const JwtClaims();
  }
  if (json is! Map<String, dynamic>) return const JwtClaims();

  String? userId;
  for (final key in ['userId', 'uid', 'sub']) {
    final value = json[key];
    if (value is String && value.isNotEmpty) {
      userId = value;
      break;
    }
    if (value is num) {
      userId = value.toString();
      break;
    }
  }

  int? expiresAt;
  final exp = json['exp'];
  if (exp is num) {
    expiresAt = exp.toInt();
  } else if (exp is String) {
    expiresAt = int.tryParse(exp);
  }

  return JwtClaims(userId: userId, expiresAt: expiresAt);
}
