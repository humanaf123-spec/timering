import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final Box _quizBox = Hive.box('quiz_items');
  final Box _recycleBox = Hive.box('recycle_bin');

  int _currentIndex = 0;
  int _score = 0;
  String? _selectedOption;
  bool _answered = false;

  void _addQuizQuestionDialog() {
    final qCtrl = TextEditingController();
    final optACtrl = TextEditingController();
    final optBCtrl = TextEditingController();
    final optCCtrl = TextEditingController();
    final optDCtrl = TextEditingController();
    String correctLetter = 'A';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('புதிய Quiz கேள்வி சேர்'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qCtrl,
                  decoration: const InputDecoration(labelText: 'கேள்வி'),
                ),
                TextField(
                  controller: optACtrl,
                  decoration: const InputDecoration(labelText: 'விருப்பம் A'),
                ),
                TextField(
                  controller: optBCtrl,
                  decoration: const InputDecoration(labelText: 'விருப்பம் B'),
                ),
                TextField(
                  controller: optCCtrl,
                  decoration: const InputDecoration(labelText: 'விருப்பம் C'),
                ),
                TextField(
                  controller: optDCtrl,
                  decoration: const InputDecoration(labelText: 'விருப்பம் D'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: correctLetter,
                  decoration: const InputDecoration(labelText: 'சரியான விடை'),
                  items: const [
                    DropdownMenuItem(value: 'A', child: Text('A')),
                    DropdownMenuItem(value: 'B', child: Text('B')),
                    DropdownMenuItem(value: 'C', child: Text('C')),
                    DropdownMenuItem(value: 'D', child: Text('D')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => correctLetter = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ரத்து'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (qCtrl.text.trim().isEmpty) return;
                final key = DateTime.now().millisecondsSinceEpoch.toString();
                await _quizBox.put(key, <String, dynamic>{
                  'id': key,
                  'question': qCtrl.text.trim(),
                  'A': optACtrl.text.trim().isEmpty
                      ? 'Option A'
                      : optACtrl.text.trim(),
                  'B': optBCtrl.text.trim().isEmpty
                      ? 'Option B'
                      : optBCtrl.text.trim(),
                  'C': optCCtrl.text.trim().isEmpty
                      ? 'Option C'
                      : optCCtrl.text.trim(),
                  'D': optDCtrl.text.trim().isEmpty
                      ? 'Option D'
                      : optDCtrl.text.trim(),
                  'answer': correctLetter,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {
                  _currentIndex = 0;
                  _score = 0;
                  _answered = false;
                  _selectedOption = null;
                });
              },
              child: const Text('சேமி'),
            ),
          ],
        ),
      ),
    );
  }

  void _checkAnswer(String letter, String correctLetter) {
    if (_answered) return;
    setState(() {
      _selectedOption = letter;
      _answered = true;
      if (letter == correctLetter) {
        _score++;
      }
    });
  }

  void _deleteQuestionToRecycleBin(String key, Map item) {
    final moved = Map<String, dynamic>.from(item);
    moved['sourceBox'] = 'quiz_items';
    moved['deletedAt'] = DateTime.now().toIso8601String();
    _recycleBox.put(key, moved);
    _quizBox.delete(key);

    setState(() {
      _currentIndex = 0;
      _answered = false;
      _selectedOption = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('கேள்வி 30-நாள் Recycle Bin-க்கு மாற்றப்பட்டது.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Practice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'கேள்வி சேர்',
            onPressed: _addQuizQuestionDialog,
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _quizBox.listenable(),
        builder: (context, Box box, _) {
          final keys = box.keys.toList();
          if (keys.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'இன்னும் Quiz கேள்விகள் சேர்க்கப்படவில்லை.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _addQuizQuestionDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('முதல் கேள்வியைச் சேர்க்கவும்'),
                  ),
                ],
              ),
            );
          }

          final safeIndex = _currentIndex % keys.length;
          final key = keys[safeIndex];
          final raw = box.get(key);
          if (raw is! Map) return const SizedBox.shrink();
          final item = Map<String, dynamic>.from(raw);
          final correctLetter = (item['answer'] ?? 'A').toString();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'கேள்வி ${safeIndex + 1} / ${keys.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'மதிப்பெண்: $_score',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.tealAccent,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          _deleteQuestionToRecycleBin(key.toString(), item),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      item['question']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                for (final letter in ['A', 'B', 'C', 'D'])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ElevatedButton(
                      onPressed: () => _checkAnswer(letter, correctLetter),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('$letter: ${item[letter] ?? ''}'),
                      ),
                    ),
                  ),
                if (_answered) ...[
                  const SizedBox(height: 6),
                  Text(
                    _selectedOption == correctLetter
                        ? 'சரியான விடை!'
                        : 'தவறு. சரியான விடை: $correctLetter',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _selectedOption == correctLetter
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.navigate_next),
                    label: const Text('அடுத்த கேள்வி'),
                    onPressed: () {
                      setState(() {
                        _currentIndex = (safeIndex + 1) % keys.length;
                        _answered = false;
                        _selectedOption = null;
                      });
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
