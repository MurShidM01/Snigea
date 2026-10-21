import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:snigea/core/crypto/digest.dart';

void main() {
  group('md5Hex', () {
    test('matches the reference digests', () {
      expect(md5Hex(''), 'd41d8cd98f00b204e9800998ecf8427e');
      expect(md5Hex('abc'), '900150983cd24fb0d6963f7d28e17f72');
    });
  });

  group('base64DecodeTolerant', () {
    test('decodes padded and unpadded payloads', () {
      expect(utf8.decode(base64DecodeTolerant('aGVsbG8=')!), 'hello');
      expect(utf8.decode(base64DecodeTolerant('aGVsbG8')!), 'hello');
    });

    test('decodes the url safe alphabet', () {
      // The bytes 0xFB 0xFF encoded with the url safe alphabet.
      final bytes = base64DecodeTolerant('-_8');
      expect(bytes, isNotNull);
      expect(bytes, [0xFB, 0xFF]);
    });

    test('returns null for invalid input', () {
      expect(base64DecodeTolerant('not base64!!'), isNull);
    });
  });

  group('hmacMd5Base64', () {
    test('produces a stable signature', () {
      final signature = hmacMd5Base64(
        List<int>.generate(16, (index) => index),
        'message',
      );
      expect(signature, isNotEmpty);
      expect(
        hmacMd5Base64(List<int>.generate(16, (index) => index), 'message'),
        signature,
      );
    });
  });
}
