import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

class LanApiDiscovery {
  LanApiDiscovery._();

  static final NetworkInfo _networkInfo = NetworkInfo();
  static Future<String?>? _inFlight;
  static String? _cachedBaseUrl;
  static String? _cachedSubnetPrefix;

  static Future<String?> discover({required int port}) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return Future<String?>.value(null);
    }

    final inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _discover(port);
    _inFlight = future;
    future.whenComplete(() {
      _inFlight = null;
    });
    return future;
  }

  static Future<String?> _discover(int port) async {
    final phoneIp = await _networkInfo.getWifiIP();
    final subnetPrefix = _subnetPrefix(phoneIp);
    if (subnetPrefix == null) {
      return null;
    }

    final cachedBaseUrl = _cachedBaseUrl;
    if (_cachedSubnetPrefix == subnetPrefix && cachedBaseUrl != null) {
      if (await _isHealthy(cachedBaseUrl)) {
        return cachedBaseUrl;
      }
      _cachedBaseUrl = null;
    }

    final ownLastOctet = _lastOctet(phoneIp!);
    final candidates = _candidateHosts(ownLastOctet);

    for (var i = 0; i < candidates.length; i += 24) {
      final batch = candidates.skip(i).take(24).toList();
      final result = await _probeBatch(subnetPrefix, batch, port);
      if (result != null) {
        _cachedSubnetPrefix = subnetPrefix;
        _cachedBaseUrl = result;
        return result;
      }
    }

    return null;
  }

  static Future<String?> _probeBatch(
    String subnetPrefix,
    List<int> hosts,
    int port,
  ) async {
    final completer = Completer<String?>();
    var remaining = hosts.length;

    for (final host in hosts) {
      () async {
        final baseUrl = 'http://$subnetPrefix.$host:$port';
        final healthy = await _isHealthy(baseUrl);
        if (!completer.isCompleted && healthy) {
          completer.complete(baseUrl);
          return;
        }

        remaining -= 1;
        if (remaining == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      }();
    }

    return completer.future;
  }

  static Future<bool> _isHealthy(String baseUrl) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 300);

    try {
      final request = await client
          .getUrl(Uri.parse('$baseUrl/up'))
          .timeout(const Duration(milliseconds: 500));
      final response = await request.close().timeout(
        const Duration(milliseconds: 500),
      );
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  static String? _subnetPrefix(String? ip) {
    if (ip == null) return null;
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  static int? _lastOctet(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    return int.tryParse(parts[3]);
  }

  static List<int> _candidateHosts(int? ownLastOctet) {
    final preferred = <int>[
      1,
      2,
      10,
      20,
      30,
      50,
      100,
      101,
      110,
      111,
      150,
      200,
      254,
    ];
    final all = <int>[];
    final seen = <int>{};

    void add(int value) {
      if (value <= 0 || value >= 255) return;
      if (ownLastOctet != null && value == ownLastOctet) return;
      if (seen.add(value)) {
        all.add(value);
      }
    }

    for (final value in preferred) {
      add(value);
    }
    for (var value = 1; value <= 254; value++) {
      add(value);
    }
    return all;
  }
}
