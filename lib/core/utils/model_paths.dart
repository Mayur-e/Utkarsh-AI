import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Copies a model from Flutter assets to the app's documents directory.
/// ONNX Runtime needs a file system path, not an asset path.
/// Safe to call multiple times — skips copy if file already exists.
Future<String> getModelPath(String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/models/$filename');

  if (!await file.exists()) {
    await file.parent.create(recursive: true);
    final bytes = await rootBundle.load('assets/models/$filename');
    await file.writeAsBytes(bytes.buffer.asUint8List());
  }

  return file.path;
}
