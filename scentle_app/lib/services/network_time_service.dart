import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// Verifies true UTC time via lightweight HTTP HEAD requests to prevent
/// device-clock manipulation and anti-time-travel cheating in Daily Scentle.
class NetworkTimeService {
  static final NetworkTimeService instance = NetworkTimeService._internal();

  NetworkTimeService._internal();

  Duration _networkOffset = Duration.zero;
  bool _isVerifiedNetworkTime = false;
  bool _isTimeManipulated = false;
  DateTime? _lastVerifiedNetworkUtc;

  Duration get networkOffset => _networkOffset;
  bool get isVerifiedNetworkTime => _isVerifiedNetworkTime;
  bool get isTimeManipulated => _isTimeManipulated;
  DateTime? get lastVerifiedNetworkUtc => _lastVerifiedNetworkUtc;

  static const List<String> timeSources = [
    'https://www.google.com',
    'https://cloudflare.com',
  ];

  /// Synchronizes with network time servers via a 2-second timeout HEAD request.
  /// Gracefully falls back to local device UTC if the device is offline.
  Future<DateTime> syncNetworkTime({
    http.Client? client,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;

    try {
      for (final url in timeSources) {
        try {
          final uri = Uri.parse(url);
          final response = await httpClient.head(uri).timeout(timeout);

          final dateHeader = response.headers['date'];
          if (dateHeader != null && dateHeader.isNotEmpty) {
            final networkUtc = parseHttpDate(dateHeader);
            final deviceUtc = DateTime.now().toUtc();

            _networkOffset = networkUtc.difference(deviceUtc);
            _isVerifiedNetworkTime = true;
            _lastVerifiedNetworkUtc = networkUtc;

            // Flag manipulation if device clock is altered by >= 2 hours forward or backward
            _isTimeManipulated = _networkOffset.inHours.abs() >= 2;

            if (_isTimeManipulated) {
              developer.log(
                'NetworkTimeService: Device clock discrepancy detected (${_networkOffset.inHours}h offset).',
                name: 'NetworkTimeService',
              );
            }

            return networkUtc;
          }
        } catch (e) {
          // Try next time source on error
          continue;
        }
      }
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }

    // Graceful offline fallback
    _isVerifiedNetworkTime = false;
    developer.log(
      'NetworkTimeService: Offline or unreachable. Using device UTC.',
      name: 'NetworkTimeService',
    );
    return DateTime.now().toUtc();
  }

  /// Returns the current verified UTC date.
  /// If network verification succeeded, applies the calculated offset.
  /// If offline, safely falls back to local device UTC.
  DateTime getVerifiedUtcDate() {
    if (_isVerifiedNetworkTime) {
      return DateTime.now().toUtc().add(_networkOffset);
    }
    return DateTime.now().toUtc();
  }

  /// Sets manual offset for unit testing without live network calls.
  @visibleForTesting
  void setOffsetForTesting(Duration offset, {bool isVerified = true}) {
    _networkOffset = offset;
    _isVerifiedNetworkTime = isVerified;
    _isTimeManipulated = offset.inHours.abs() >= 2;
  }

  /// Resets service state for unit testing.
  @visibleForTesting
  void resetForTesting() {
    _networkOffset = Duration.zero;
    _isVerifiedNetworkTime = false;
    _isTimeManipulated = false;
    _lastVerifiedNetworkUtc = null;
  }

  /// Parses RFC 1123 / HTTP standard date strings into UTC DateTime.
  static DateTime parseHttpDate(String dateStr) {
    try {
      return DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'").parseUtc(dateStr.trim());
    } catch (_) {
      try {
        return DateFormat("EEE, dd-MMM-yy HH:mm:ss 'GMT'").parseUtc(dateStr.trim());
      } catch (_) {
        return DateTime.tryParse(dateStr)?.toUtc() ?? DateTime.now().toUtc();
      }
    }
  }
}
