import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

Future<void> saveFileToDownloadsViaMediaStore(
    Uint8List bytes,
    String filename,
    String mimeType,
    BuildContext context,
    ) async {
  try {
    // Simpan file sementara
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(p.join(tempDir.path, filename));
    await tempFile.writeAsBytes(bytes);

    // Simpan ke folder Downloads via MediaStore
    final mediaStore = MediaStore();
    final savedFilePath = await mediaStore.saveFile(
      tempFilePath: tempFile.path,
      dirType: DirType.download,
      dirName: DirName.download,
      relativePath: null,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("File berhasil disimpan: $savedFilePath")),
    );

    await tempFile.delete(); // opsional: hapus file sementara
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Gagal menyimpan file: $e")),
    );
  }
}
