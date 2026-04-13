class PaginatedResult<T> {
  const PaginatedResult({
    required this.items,
    required this.currentPage,
    required this.perPage,
    required this.totalItems,
    required this.hasMorePages,
  });

  final List<T> items;
  final int currentPage;
  final int perPage;
  final int totalItems;
  final bool hasMorePages;

  factory PaginatedResult.fromResponse(
    Map<String, dynamic> response,
    T Function(dynamic item) itemMapper, {
    int fallbackPage = 1,
    int fallbackPerPage = 25,
  }) {
    final List<T> items =
        (response['data'] as List<dynamic>? ?? const <dynamic>[])
            .map(itemMapper)
            .toList();
    final Map<String, dynamic> meta = response['meta'] is Map
        ? Map<String, dynamic>.from(response['meta'] as Map)
        : const <String, dynamic>{};

    final int currentPage =
        _readInt(meta['current_page']) ?? fallbackPage.clamp(1, 999999);
    final int perPage =
        _readInt(meta['per_page']) ?? fallbackPerPage.clamp(1, 999999);
    final int totalItems = _readInt(meta['total']) ?? items.length;
    final bool hasMorePages =
        meta['has_more_pages'] == true || (currentPage * perPage) < totalItems;

    return PaginatedResult<T>(
      items: items,
      currentPage: currentPage,
      perPage: perPage,
      totalItems: totalItems,
      hasMorePages: hasMorePages,
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }
}
