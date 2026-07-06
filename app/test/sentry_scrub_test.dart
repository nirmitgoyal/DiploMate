import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:diplomate/sentry_scrub.dart';

void main() {
  group('scrubEvent', () {
    test('strips answer text, JWTs, and the request; keeps unrelated data',
        () async {
      final event = SentryEvent(
        message: const SentryMessage('unrelated crash message survives'),
        request: SentryRequest(url: 'https://api.diplomate.app/manifest'),
        exceptions: const [
          SentryException(
            type: 'DioException',
            value: 'auth failed, header: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6',
          ),
        ],
        breadcrumbs: [
          Breadcrumb(
            message: 'chapter body loaded',
            data: const {'body': 'A TAP block is performed under ultrasound...'},
          ),
          Breadcrumb(message: 'unrelated nav breadcrumb survives'),
        ],
        // ignore: deprecated_member_use
        extra: const {'question': 'Describe the TAP block'},
      );

      final scrubbed = await scrubEvent(event, Hint());

      expect(scrubbed, isNotNull);

      // The request must be dropped entirely (may carry PII/IPs).
      expect(scrubbed!.request, isNull);

      // No JWT survives anywhere in the serialized event.
      final json = scrubbed.toJson().toString();
      expect(json.contains('Bearer ey'), isFalse);
      expect(json.contains('TAP block'), isFalse);
      expect(
        json.contains('A TAP block is performed under ultrasound'),
        isFalse,
      );

      // Unrelated data is left alone.
      expect(json.contains('unrelated crash message survives'), isTrue);
      expect(json.contains('unrelated nav breadcrumb survives'), isTrue);

      // The breadcrumb carrying answer text (`body` key) is dropped outright.
      expect(scrubbed.breadcrumbs?.length, 1);
      expect(scrubbed.breadcrumbs?.single.message,
          'unrelated nav breadcrumb survives');
    });

    test('caps breadcrumb messages at 200 chars', () async {
      final longMessage = 'x' * 500;
      final event = SentryEvent(
        breadcrumbs: [Breadcrumb(message: longMessage)],
      );

      final scrubbed = await scrubEvent(event, Hint());

      expect(scrubbed!.breadcrumbs!.single.message!.length, 200);
    });

    test('redacts a bare Bearer token in the message field', () async {
      final event = SentryEvent(
        message: const SentryMessage(
            'request failed with Bearer eyJhbGciOiJIUzI1NiJ9.abc-DEF_123'),
      );

      final scrubbed = await scrubEvent(event, Hint());

      final json = scrubbed!.toJson().toString();
      expect(json.contains('Bearer ey'), isFalse);
      expect(json.contains('Bearer [redacted]'), isTrue);
    });
  });
}
