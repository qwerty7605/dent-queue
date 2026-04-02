import 'dart:io';

Future<String?> saveDownloadedFile({
  required String filename,
  required List<int> bytes,
  required String mimeType,
}) async {
  final sanitizedFilename = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final file = File('${Directory.systemTemp.path}/$sanitizedFilename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
