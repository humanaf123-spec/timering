import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/syncfusion_flutter_pdfviewer.dart';

class PdfLibraryScreen extends StatefulWidget {
  const PdfLibraryScreen({super.key});

  @override
  State<PdfLibraryScreen> createState() => _PdfLibraryScreenState();
}

class _PdfLibraryScreenState extends State<PdfLibraryScreen> {
  final Box _pdfBox = Hive.box('pdf_library');
  final Box _recycleBox = Hive.box('recycle_bin');

  Future<void> _pickAndAddPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;

    final filePath = result.files.single.path!;
    final fileName = result.files.single.name;
    final key = DateTime.now().millisecondsSinceEpoch.toString();

    await _pdfBox.put(key, <String, dynamic>{
      'id': key,
      'title': fileName,
      'path': filePath,
      'addedAt': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$fileName" PDF Library-யில் சேர்க்கப்பட்டது.')),
      );
    }
  }

  void _deletePdfToRecycleBin(String key, Map item) {
    final moved = Map<String, dynamic>.from(item);
    moved['sourceBox'] = 'pdf_library';
    moved['deletedAt'] = DateTime.now().toIso8601String();
    _recycleBox.put(key, moved);
    _pdfBox.delete(key);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF 30-நாள் Recycle Bin-க்கு மாற்றப்பட்டது.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Library & Reader')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndAddPdf,
        icon: const Icon(Icons.upload_file),
        label: const Text('PDF சேர்'),
      ),
      body: ValueListenableBuilder(
        valueListenable: _pdfBox.listenable(),
        builder: (context, Box box, _) {
          final keys = box.keys.toList();
          if (keys.isEmpty) {
            return const Center(
              child: Text(
                'PDF Library காலியாக உள்ளது.\n"+ PDF சேர்" அழுத்தி ஃபைலைச் சேர்க்கவும்.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final key = keys[index];
              final raw = box.get(key);
              if (raw is! Map) return const SizedBox.shrink();
              final item = Map<String, dynamic>.from(raw);
              final title = item['title']?.toString() ?? 'Document.pdf';
              final path = item['path']?.toString() ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(
                    Icons.picture_as_pdf,
                    color: Colors.redAccent,
                  ),
                  title: Text(title),
                  subtitle: const Text('Tap to read offline'),
                  onTap: () {
                    if (path.isEmpty || !File(path).existsSync()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'PDF ஃபைல் கிடைக்கவில்லை அல்லது இடம் மாறியுள்ளது.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            _PdfViewerPage(title: title, filePath: path),
                      ),
                    );
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deletePdfToRecycleBin(key.toString(), item),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PdfViewerPage extends StatelessWidget {
  final String title;
  final String filePath;

  const _PdfViewerPage({required this.title, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SfPdfViewer.file(File(filePath)),
    );
  }
}
