String? firstApiErrorMessage(dynamic value) {
  if (value is List) {
    for (final dynamic item in value) {
      final String message = item?.toString().trim() ?? '';
      if (message.isNotEmpty) {
        return message;
      }
    }
  }

  final String message = value?.toString().trim() ?? '';
  return message.isNotEmpty ? message : null;
}

Map<String, String> collectApiFieldErrors(
  Map<String, dynamic>? errors,
  Map<String, List<String>> fieldMappings,
) {
  if (errors == null || errors.isEmpty) {
    return const <String, String>{};
  }

  final Map<String, String> fieldErrors = <String, String>{};

  fieldMappings.forEach((String field, List<String> keys) {
    for (final String key in keys) {
      final String? message = firstApiErrorMessage(errors[key]);
      if (message != null) {
        fieldErrors[field] = message;
        break;
      }
    }
  });

  return fieldErrors;
}

String? firstUnhandledApiError(
  Map<String, dynamic>? errors, {
  Iterable<String> handledKeys = const <String>[],
}) {
  if (errors == null || errors.isEmpty) {
    return null;
  }

  final Set<String> ignoredKeys = handledKeys.toSet();
  for (final MapEntry<String, dynamic> entry in errors.entries) {
    if (ignoredKeys.contains(entry.key)) {
      continue;
    }

    final String? message = firstApiErrorMessage(entry.value);
    if (message != null) {
      return message;
    }
  }

  return null;
}

Set<String> flattenApiErrorKeys(Map<String, List<String>> fieldMappings) {
  final Set<String> keys = <String>{};
  for (final List<String> values in fieldMappings.values) {
    keys.addAll(values);
  }
  return keys;
}
