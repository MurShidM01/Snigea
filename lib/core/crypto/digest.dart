import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Lower-case hexadecimal MD5 digest of [bytes].
String md5HexBytes(List<int> bytes) => md5.convert(bytes).toString();

/// Lower-case hexadecimal MD5 digest of the UTF-8 encoding of [value].
String md5Hex(String value) => md5HexBytes(utf8.encode(value));

/// Base64 (standard alphabet) encoding.
String base64EncodeBytes(List<int> bytes) => base64.encode(bytes);

/// Decodes standard base64, returning `null` when the input is invalid.
List<int>? base64DecodeOrNull(String value) {
  try {
    return base64.decode(base64.normalize(value));
  } on FormatException {
    return null;
  }
}

/// Decodes a base64 payload that may use the URL-safe alphabet and may be
/// unpadded, mirroring the tolerant decoding used for CloudFront policies.
List<int>? base64DecodeTolerant(String value) {
  var normalized = value.replaceAll('-', '+').replaceAll('_', '/');
  final padding = (4 - normalized.length % 4) % 4;
  if (padding > 0) {
    normalized = normalized.padRight(normalized.length + padding, '=');
  }
  return base64DecodeOrNull(normalized);
}

/// HMAC-MD5 of [message] using [secret], returned as raw bytes.
List<int> hmacMd5Bytes(List<int> secret, List<int> message) {
  final hmac = Hmac(md5, secret);
  return hmac.convert(message).bytes;
}

/// HMAC-MD5 of [message] using [secret], base64 encoded.
String hmacMd5Base64(List<int> secret, String message) =>
    base64EncodeBytes(hmacMd5Bytes(secret, utf8.encode(message)));
