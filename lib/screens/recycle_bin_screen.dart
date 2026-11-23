import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class RecycleBinScreen extends StatelessWidget {
  const RecycleBinScreen({super.key});

  int _remainingDays(String? deletedIso) {
    if (deletedIso == null) return 30;
    final deletedAt = DateTime.tryParse(deletedIso);
    if (deletedAt == null) return 30;
    final elapsed = DateTime.now().difference(deletedAt).inDays;
    final left = 30 - elapsed;
    return left < 0 ? 0 : left;
  }

  void _restoreItem(BuildContext context, dynamic key, Map item) {
    final targetBoxName = item['sourceBox']?.toString() ?? 'planner_pages';
    final targetBox = Hive.box(targetBoxName);
    final recycleBox = Hive.box('recycle_bin');

    final restored = Map<String, dynamic>.from(item);
    restored.remove('sourceBox');
    restored.remove('deletedAt');

    targetBox.put(key, restored);
    recycleBox.delete(key);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('மீண்டும் பழைய இடத்தில் மீட்கப்பட்டது.')),
    );
  }

  void _permanentDelete(BuildContext context, dynamic key) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('நிரந்தரமாக அழிக்கவா?'),
        content: const Text(
          'இதை நிரந்தரமாக அழித்தால் மீண்டும் எடுக்க முடியாது. உறுதியா?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ரத்து'),
          ),
          ElevatedButton(
            onPressed: () {
              Hive.box('recycle_bin').delete(key);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('நிரந்தரமாக அழிக்கப்பட்டது.')),
              );
            },
            child: const Text('நிரந்தரமாக அழி'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recycleBox = Hive.box('recycle_bin');

    return Scaffold(
      appBar: AppBar(title: const Text('30-Day Recycle Bin')),
      body: ValueListenableBuilder(
        valueListenable: recycleBox.listenable(),
        builder: (context, Box box, _) {
          final keys = box.keys.toList();
          if (keys.isEmpty) {
            return const Center(
              child: Text(
                'Recycle Bin காலியாக உள்ளது.\nநீக்கப்பட்டவை 30 நாட்கள் வரை இங்கு இருக்கும்.',
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

              final title =
                  (item['title'] ?? item['phone'] ?? item['question'] ?? 'Saved Item')
                      .toString();
              final daysLeft = _remainingDays(item['deletedAt']?.toString());

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(
                    Icons.restore_from_trash,
                    color: Colors.amber,
                  ),
                  title: Text(title),
                  subtitle: Text('மீதமுள்ள நாட்கள்: $daysLeft / 30 நாட்கள்'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore, color: Colors.tealAccent),
                        tooltip: 'Restore',
                        onPressed: () => _restoreItem(context, key, item),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_forever,
                          color: Colors.redAccent,
                        ),
                        tooltip: 'Delete Permanently',
                        onPressed: () => _permanentDelete(context, key),
                      ),
                    ],
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
