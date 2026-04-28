// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List?> pickExcelFileBytes() {
  final completer = Completer<Uint8List?>();
  final input = html.FileUploadInputElement()
    ..accept = '.xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    ..multiple = false;

  input.onChange.first.then((_) {
    final file = input.files?.isEmpty ?? true ? null : input.files!.first;
    if (file == null) {
      completer.complete(null);
      return;
    }

    final reader = html.FileReader();
    reader.onError.first.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(reader.error ?? StateError('No fue posible leer el archivo.'));
      }
    });
    reader.onLoadEnd.first.then((_) {
      if (completer.isCompleted) {
        return;
      }
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(result.asUint8List());
      } else {
        completer.completeError(StateError('El archivo no entrego bytes validos.'));
      }
    });
    reader.readAsArrayBuffer(file);
  });

  input.click();
  return completer.future;
}
