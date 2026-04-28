import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<Uint8List?> pickExcelFileBytes() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['xlsx'],
    withData: true,
  );
  return result?.files.single.bytes;
}
