import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path/path.dart' as p;

class ExcelPreviewPage extends StatelessWidget {
  final String filePath;

  const ExcelPreviewPage({super.key, required this.filePath});

  Future<void> saveExcelToDownloads(BuildContext context) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final fileName = 'laporan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, fileName));
      await tempFile.writeAsBytes(bytes);

      MediaStore.appFolder = 'Food Order Reports';
      final mediaStore = MediaStore();

      final savedFilePath = await mediaStore.saveFile(
        tempFilePath: tempFile.path,
        dirType: DirType.download,
        dirName: DirName.download,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Excel disimpan di: $savedFilePath")),
      );

      await tempFile.delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal menyimpan Excel: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = File(filePath);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Laporan Excel"),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => saveExcelToDownloads(context),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.shareXFiles([XFile(filePath)], text: 'Laporan Excel'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/sheet_logo.png',
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 20),
            Text(
              "Laporan Excel berhasil dibuat:\n\n${file.path}",
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
