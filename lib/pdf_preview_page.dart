import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path/path.dart' as p;

class PdfPreviewPage extends StatefulWidget {
  final String filePath;

  const PdfPreviewPage({super.key, required this.filePath});

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  late PdfControllerPinch pdfController;

  @override
  void initState() {
    super.initState();
    pdfController = PdfControllerPinch(
      document: PdfDocument.openFile(widget.filePath),
    );
  }

  @override
  void dispose() {
    pdfController.dispose();
    super.dispose();
  }

  Future<void> savePdfToDownloads() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final fileName = 'laporan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

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
        SnackBar(content: Text("PDF disimpan di: $savedFilePath")),
      );

      await tempFile.delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal menyimpan PDF: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Laporan PDF"),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: savePdfToDownloads,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              await Share.shareXFiles([XFile(widget.filePath)], text: 'Laporan PDF');
            },
          ),
        ],
      ),
      body: PdfViewPinch(controller: pdfController),
    );
  }
}
