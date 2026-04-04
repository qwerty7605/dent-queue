int compareAppointmentQueueDisplayOrder(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final int dateCompare = _sortableDate(a).compareTo(_sortableDate(b));
  if (dateCompare != 0) {
    return dateCompare;
  }

  final int timeCompare = _sortableTime(a).compareTo(_sortableTime(b));
  if (timeCompare != 0) {
    return timeCompare;
  }

  final int timestampCompare = _compareNullableDateTimes(
    _parseTimestamp(_rawTimestamp(a)),
    _parseTimestamp(_rawTimestamp(b)),
  );
  if (timestampCompare != 0) {
    return timestampCompare;
  }

  final int idCompare = _sortableInt(
    _rawId(a),
  ).compareTo(_sortableInt(_rawId(b)));
  if (idCompare != 0) {
    return idCompare;
  }

  final int queueCompare = _sortableInt(
    a['queue_number'],
  ).compareTo(_sortableInt(b['queue_number']));
  if (queueCompare != 0) {
    return queueCompare;
  }

  return _sortableText(
    a['patient_name'],
  ).compareTo(_sortableText(b['patient_name']));
}

int compareAppointmentQueueDisplayOrderDescending(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) => compareAppointmentQueueDisplayOrder(b, a);

String _sortableDate(Map<String, dynamic> appointment) {
  final String raw = _rawDate(appointment);
  if (raw.isEmpty) {
    return '9999-12-31';
  }

  final DateTime? parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    return raw;
  }

  final String year = parsed.year.toString().padLeft(4, '0');
  final String month = parsed.month.toString().padLeft(2, '0');
  final String day = parsed.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

int _sortableTime(Map<String, dynamic> appointment) {
  final String raw = _rawTime(appointment);
  if (raw.isEmpty) {
    return 1 << 30;
  }

  final RegExpMatch? twelveHourMatch = RegExp(
    r'^(\d{1,2}):(\d{2})\s*([AP]M)$',
    caseSensitive: false,
  ).firstMatch(raw);
  if (twelveHourMatch != null) {
    final int? hour = int.tryParse(twelveHourMatch.group(1) ?? '');
    final int? minute = int.tryParse(twelveHourMatch.group(2) ?? '');
    final String suffix = (twelveHourMatch.group(3) ?? '').toUpperCase();
    if (hour != null && minute != null) {
      final int normalizedHour = switch (suffix) {
        'AM' => hour == 12 ? 0 : hour,
        'PM' => hour == 12 ? 12 : hour + 12,
        _ => hour,
      };
      return (normalizedHour * 60 * 60) + (minute * 60);
    }
  }

  final RegExpMatch? twentyFourHourMatch = RegExp(
    r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$',
  ).firstMatch(raw);
  if (twentyFourHourMatch == null) {
    return 1 << 30;
  }

  final int? hour = int.tryParse(twentyFourHourMatch.group(1) ?? '');
  final int? minute = int.tryParse(twentyFourHourMatch.group(2) ?? '');
  final int second = int.tryParse(twentyFourHourMatch.group(3) ?? '0') ?? 0;
  if (hour == null || minute == null) {
    return 1 << 30;
  }

  return (hour * 60 * 60) + (minute * 60) + second;
}

DateTime? _parseTimestamp(String raw) {
  if (raw.isEmpty) {
    return null;
  }

  return DateTime.tryParse(raw) ??
      DateTime.tryParse(raw.replaceFirst(' ', 'T'));
}

int _compareNullableDateTimes(DateTime? a, DateTime? b) {
  if (a == null && b == null) {
    return 0;
  }
  if (a == null) {
    return 1;
  }
  if (b == null) {
    return -1;
  }

  return a.compareTo(b);
}

String _rawDate(Map<String, dynamic> appointment) {
  return (appointment['appointment_date'] ?? appointment['date'])
          ?.toString()
          .trim() ??
      '';
}

String _rawTime(Map<String, dynamic> appointment) {
  return (appointment['appointment_time'] ??
              appointment['time'] ??
              appointment['time_slot'])
          ?.toString()
          .trim() ??
      '';
}

String _rawTimestamp(Map<String, dynamic> appointment) {
  return (appointment['timestamp_created'] ?? appointment['created_at'])
          ?.toString()
          .trim() ??
      '';
}

dynamic _rawId(Map<String, dynamic> appointment) {
  return appointment['id'] ?? appointment['appointment_id'];
}

int _sortableInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  if (value == null) {
    return 1 << 30;
  }

  return int.tryParse(value.toString()) ?? (1 << 30);
}

String _sortableText(dynamic value) =>
    value?.toString().trim().toLowerCase() ?? '';
