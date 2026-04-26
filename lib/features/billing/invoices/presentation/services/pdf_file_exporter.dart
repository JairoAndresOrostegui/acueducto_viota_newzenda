import 'dart:typed_data';

import 'package:printing/printing.dart';

import 'pdf_file_exporter_stub.dart'
    if (dart.library.html) 'pdf_file_exporter_web.dart' as platform_exporter;

class PdfFileExporter {
  static Future<void> save({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (platform_exporter.supportsDirectDownload) {
      await platform_exporter.savePdf(bytes: bytes, fileName: fileName);
      return;
    }

    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}
