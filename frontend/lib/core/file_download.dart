import 'file_download_io.dart'
    if (dart.library.html) 'file_download_web.dart'
    as impl;

Future<String?> saveDownloadedFile({
  required String filename,
  required List<int> bytes,
  required String mimeType,
}) {
  return impl.saveDownloadedFile(
    filename: filename,
    bytes: bytes,
    mimeType: mimeType,
  );
}
