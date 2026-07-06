import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

/// Keys whose presence on a breadcrumb's `data` map means the breadcrumb is
/// carrying licensed answer text - the whole breadcrumb is dropped rather
/// than redacted, since the answer content itself must never leave the
/// device.
const _answerTextKeys = {'body', 'sections', 'body_md', 'question'};

const _maxBreadcrumbMessageLength = 200;

final _bearerTokenPattern = RegExp(r'Bearer [A-Za-z0-9._-]+');

String _redact(String value) =>
    value.replaceAll(_bearerTokenPattern, 'Bearer [redacted]');

/// `options.beforeSend`: strips anything that could leak licensed exam
/// content or an auth token before an event reaches Sentry.
///
/// - `event.request` is dropped entirely (may carry IPs/headers).
/// - Every string reachable from `message`, `exceptions`, `extra`, and
///   `contexts` has `Bearer <token>` redacted.
/// - Breadcrumbs carrying answer text (see [_answerTextKeys]) are dropped;
///   surviving breadcrumb messages are redacted and capped at 200 chars.
FutureOr<SentryEvent?> scrubEvent(SentryEvent event, Hint hint) {
  final message =
      event.message?.copyWith(formatted: _redact(event.message!.formatted));

  final exceptions = event.exceptions
      ?.map((e) => e.copyWith(value: e.value == null ? null : _redact(e.value!)))
      .toList(growable: false);

  final breadcrumbs = event.breadcrumbs
      ?.where((b) => b.data == null || !_answerTextKeys.any(b.data!.containsKey))
      .map(_scrubBreadcrumb)
      .toList(growable: false);

  // ignore: deprecated_member_use
  final extra = event.extra == null
      ? null
      : (Map<String, dynamic>.from(event.extra!)
          // Same answer-text keys as breadcrumbs (e.g. `question`) - the
          // key alone means the value is licensed content, not just a
          // Bearer token, so drop the entry rather than redact it.
        ..removeWhere((key, _) => _answerTextKeys.contains(key)))
          .map((key, value) =>
              MapEntry(key, value is String ? _redact(value) : value));

  for (final key in event.contexts.keys.toList(growable: false)) {
    if (_answerTextKeys.contains(key)) {
      event.contexts.remove(key);
      continue;
    }
    final value = event.contexts[key];
    if (value is String) {
      event.contexts[key] = _redact(value);
    }
  }

  // `copyWith` can't null out `request` (it falls back to `this.request`
  // when passed null), so drop it via the constructor directly.
  return SentryEvent(
    eventId: event.eventId,
    timestamp: event.timestamp,
    platform: event.platform,
    logger: event.logger,
    serverName: event.serverName,
    release: event.release,
    dist: event.dist,
    environment: event.environment,
    modules: event.modules,
    message: message,
    transaction: event.transaction,
    throwable: event.throwableMechanism,
    level: event.level,
    culprit: event.culprit,
    tags: event.tags,
    // ignore: deprecated_member_use
    extra: extra,
    fingerprint: event.fingerprint,
    user: event.user,
    contexts: event.contexts,
    breadcrumbs: breadcrumbs,
    sdk: event.sdk,
    exceptions: exceptions,
    threads: event.threads,
    type: event.type,
    debugMeta: event.debugMeta,
    // request intentionally omitted - always dropped.
  );
}

Breadcrumb _scrubBreadcrumb(Breadcrumb breadcrumb) {
  var message = breadcrumb.message;
  if (message != null) {
    message = _redact(message);
    if (message.length > _maxBreadcrumbMessageLength) {
      message = message.substring(0, _maxBreadcrumbMessageLength);
    }
  }
  return breadcrumb.copyWith(message: message);
}

/// `options.beforeBreadcrumb`: strips request/response bodies from HTTP
/// breadcrumbs before they're even added to the scope, so cached page/answer
/// bodies never sit in memory waiting for a crash to ship them.
Breadcrumb? beforeBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
  if (breadcrumb == null) return null;
  final data = breadcrumb.data;
  if (data == null) return _scrubBreadcrumb(breadcrumb);
  if (_answerTextKeys.any(data.containsKey)) return null;

  final strippedData = Map<String, dynamic>.from(data)
    ..remove('request_body')
    ..remove('response_body');
  return _scrubBreadcrumb(breadcrumb.copyWith(data: strippedData));
}
