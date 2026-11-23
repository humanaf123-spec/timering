import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PdfLibraryScreen extends StatefulWidget {
  const PdfLibraryScreen({super.key});

  @override
  State<PdfLibraryScreen> createState() => _PdfLibraryScreenState();
}

class _PdfLibraryScreenState extends State<PdfLibraryScreen> {
  final Box pdfBox = Hive.box('pdf_library');

  Future<void> _addPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;

    final filePath = result.files.single.path!;
    final fileName = result.files.single.name;
    final fileSize = File(filePath).existsSync()
        ? (File(filePath).lengthSync() / 1024).toStringAsFixed(1)
        : '0';

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await pdfBox.put(id, {
      'id': id,
      'name': fileName,
      'path': filePath,
      'sizeKb': fileSize,
      'addedAt': DateTime.now().toIso8601String(),
    });
    setState(() {});
  }

  Future<void> _openPdfExternal(BuildContext context, Map item) async {
    final path = (item['path'] ?? '').toString();
    if (path.isEmpty || !File(path).existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF கோப்பு கிடைக்கவில்லை.')),
        );
      }
      return;
    }

    final uri = Uri.file(path);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF Path: $path'),
        ),
      );
    }
  }

  Future<void> _deletePdf(String key) async {
    final item = pdfBox.get(key);
    if (item is Map) {
      final recycleBox = Hive.box('recycle_bin');
      final binMap = Map<String, dynamic>.from(item);
      binMap['sourceBox'] = 'pdf_library';
      binMap['deletedAt'] = DateTime.now().toIso8601String();
      await recycleBox.put('pdf_$key', binMap);
      await pdfBox.delete(key);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = pdfBox.keys.toList().reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('PDF Library')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPdf,
        icon: const Icon(Icons.upload_file),
        label: const Text('Add PDF'),
      ),
      body: keys.isEmpty
          ? const Center(
              child: Text(
                'PDF கோப்புகள் எதுவும் இல்லை.\n"Add PDF" அழுத்தி சேர்க்கவும்.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: keys.length,
              itemBuilder: (context, index) {
                final key = keys[index];
                final item = Map<String, dynamic>.from(pdfBox.get(key) ?? {});
                final name = (item['name'] ?? 'Document.pdf').toString();
                final sizeKb = (item['sizeKb'] ?? '0').toString();

                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.redAccent,
                    ),
                    title: Text(name),
                    subtitle: Text('Size: $sizeKb KB'),
                    onTap: () => _openPdfExternal(context, item),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deletePdf(key.toString()),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
