class ShortTermCache {
  ShortTermCache._();

  static final Map<String, _ShortTermCacheEntry> _entries =
      <String, _ShortTermCacheEntry>{};
  static final Map<String, Future<dynamic>> _inFlightRequests =
      <String, Future<dynamic>>{};

  static T? read<T>(String namespace, String key) {
    final String compositeKey = _compositeKey(namespace, key);
    final _ShortTermCacheEntry? entry = _entries[compositeKey];

    if (entry == null) {
      return null;
    }

    if (DateTime.now().isAfter(entry.expiresAt)) {
      _entries.remove(compositeKey);
      return null;
    }

    return _clone(entry.value) as T;
  }

  static void write<T>(
    String namespace,
    String key,
    T value, {
    required Duration ttl,
  }) {
    _entries[_compositeKey(namespace, key)] = _ShortTermCacheEntry(
      value: _clone(value),
      expiresAt: DateTime.now().add(ttl),
    );
  }

  static void invalidateNamespace(String namespace) {
    _entries.removeWhere(
      (String compositeKey, _ShortTermCacheEntry _) =>
          compositeKey.startsWith('$namespace::'),
    );
    _inFlightRequests.removeWhere(
      (String compositeKey, Future<dynamic> _) =>
          compositeKey.startsWith('$namespace::'),
    );
  }

  static void invalidate(String namespace, String key) {
    final String compositeKey = _compositeKey(namespace, key);
    _entries.remove(compositeKey);
    _inFlightRequests.remove(compositeKey);
  }

  static void clear() {
    _entries.clear();
    _inFlightRequests.clear();
  }

  static Future<T> runSingleFlight<T>(
    String namespace,
    String key,
    Future<T> Function() loader,
  ) {
    final String compositeKey = _compositeKey(namespace, key);
    final Future<dynamic>? existingRequest = _inFlightRequests[compositeKey];
    if (existingRequest != null) {
      return existingRequest.then((dynamic value) => value as T);
    }

    final Future<T> request = loader();
    _inFlightRequests[compositeKey] = request;

    return request
        .whenComplete(() {
          final Future<dynamic>? activeRequest =
              _inFlightRequests[compositeKey];
          if (identical(activeRequest, request)) {
            _inFlightRequests.remove(compositeKey);
          }
        })
        .then((T value) => value);
  }

  static dynamic _clone(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.fromEntries(
        value.entries.map(
          (MapEntry<dynamic, dynamic> entry) => MapEntry<String, dynamic>(
            entry.key.toString(),
            _clone(entry.value),
          ),
        ),
      );
    }

    if (value is List) {
      return value.map<dynamic>(_clone).toList(growable: false);
    }

    return value;
  }

  static String _compositeKey(String namespace, String key) {
    return '$namespace::$key';
  }
}

class _ShortTermCacheEntry {
  const _ShortTermCacheEntry({required this.value, required this.expiresAt});

  final dynamic value;
  final DateTime expiresAt;
}
