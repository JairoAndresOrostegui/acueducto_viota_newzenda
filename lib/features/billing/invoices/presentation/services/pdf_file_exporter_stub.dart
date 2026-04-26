import 'dart:typed_data';

const bool supportsDirectDownload = false;

Future<void> savePdf({
  required Uint8List bytes,
  required String fileName,
}) {
  throw UnsupportedError('Direct PDF download is not available.');
}
