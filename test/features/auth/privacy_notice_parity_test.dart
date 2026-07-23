import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/features/auth/data/privacy_notice_content.dart';

void main() {
  group('privacy notice parity', () {
    test('key phrases present in both files', () {
      final markdownContent =
          File('docs/PRIVACY_NOTICE.md').readAsStringSync();

      final keyPhrases = [
        'Row-Level-Security',
        'Frankfurt',
        'TLS 1.3',
        'AES-256',
        'Art. 6 Abs. 1 lit. b',
        'Art. 6 Abs. 1 lit. a',
        'Art. 15',
        'Art. 17',
        'Art. 20',
        'Art. 28',
        'Supabase',
        'Juli 2026',
      ];

      for (final phrase in keyPhrases) {
        expect(
          markdownContent.contains(phrase),
          isTrue,
          reason: 'Phrase "$phrase" not found in PRIVACY_NOTICE.md',
        );
        expect(
          kPrivacyNoticeDe.contains(phrase),
          isTrue,
          reason: 'Phrase "$phrase" not found in kPrivacyNoticeDe constant',
        );
      }
    });

    test('section count preserved', () {
      final separatorCount = '---'.allMatches(kPrivacyNoticeDe).length;
      expect(
        separatorCount,
        greaterThanOrEqualTo(5),
        reason: 'Expected at least 5 section separators, found $separatorCount',
      );
    });
  });
}
