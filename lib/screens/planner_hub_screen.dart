import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/notification_service.dart';

class PlannerHubScreen extends StatefulWidget {
  const PlannerHubScreen({super.key});

  @override
  State<PlannerHubScreen> createState() => _PlannerHubScreenState();
}

class _PlannerHubScreenState extends State<PlannerHubScreen> {
  final Box _pagesBox = Hive.box('planner_pages');
  final Box _recycleBox = Hive.box('recycle_bin');
  late Timer _secondTimer;

  @override
  void initState() {
    super.initState();
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _secondTimer.cancel();
    super.dispose();
  }

  String _detectTopicType(String title, String fallback) {
    final lower = title.toLowerCase();
    if (lower.contains('movie') ||
        lower.contains('film') ||
        lower.contains('படம்') ||
        lower.contains('சினிமா') ||
        lower.contains('release')) {
      return 'Movie Release';
    }
    if (lower.contains('study') ||
        lower.contains('exam') ||
        lower.contains('marine') ||
        lower.contains('english') ||
        lower.contains('படிப்பு') ||
        lower.contains('பாடம்')) {
      return 'Study & Timetable';
    }
    if (lower.contains('work') ||
        lower.contains('job') ||
        lower.contains('வேலை') ||
        lower.contains('plan')) {
      return 'Work & Plans';
    }
    return fallback;
  }

  String _formatSecondsCountdown(String? isoTarget) {
    if (isoTarget == null) return 'Countdown அமைக்கப்படவில்லை';
    final target = DateTime.tryParse(isoTarget);
    if (target == null) return 'Countdown அமைக்கப்படவில்லை';

    final diff = target.difference(DateTime.now());
    if (diff.isNegative || diff.inSeconds == 0) {
      return 'நேரம் வந்துவிட்டது!';
    }

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;

    return '$days நாட்கள் : ${hours.toString().padLeft(2, '0')}ம : '
        '${minutes.toString().padLeft(2, '0')}நி : ${seconds.toString().padLeft(2, '0')}வி';
  }

  Future<void> _openPageEditor({String? existingKey, Map? existingItem}) async {
    final titleCtrl = TextEditingController(
      text: existingItem?['title']?.toString() ?? '',
    );
    final notesCtrl = TextEditingController(
      text: existingItem?['notes']?.toString() ?? '',
    );
    String selectedCategory =
        existingItem?['category']?.toString() ?? 'Study & Timetable';
    DateTime targetDate = DateTime.tryParse(
          existingItem?['targetDate']?.toString() ?? '',
        ) ??
        DateTime.now().add(const Duration(days: 3, hours: 2));
    bool reminderEnabled = existingItem?['reminderEnabled'] == true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            existingKey == null ? 'புதிய பக்கம் (New Page)' : 'பக்கத்தைத் திருத்து',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'தலைப்பு (எ.கா: Marine Biology / New Movie)',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'வகை / பிரிவு'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Study & Timetable',
                      child: Text('Study & Timetable'),
                    ),
                    DropdownMenuItem(
                      value: 'Work & Plans',
                      child: Text('Work & Plans'),
                    ),
                    DropdownMenuItem(
                      value: 'Movie Release',
                      child: Text('Movie Release'),
                    ),
                    DropdownMenuItem(
                      value: 'Personal Notes',
                      child: Text('Personal Notes'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedCategory = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes, Timetable & Schedule',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timer),
                  title: const Text('Countdown இலக்கு நாள் & நேரம்'),
                  subtitle: Text(
                    '${targetDate.day}/${targetDate.month}/${targetDate.year} '
                    '${targetDate.hour.toString().padLeft(2, '0')}:${targetDate.minute.toString().padLeft(2, '0')}',
                  ),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: targetDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2035),
                    );
                    if (d == null || !ctx.mounted) return;
                    final t = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(targetDate),
                    );
                    if (t == null) return;
                    setDialogState(() {
                      targetDate = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        t.hour,
                        t.minute,
                      );
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Countdown Reminder Notification'),
                  value: reminderEnabled,
                  onChanged: (v) => setDialogState(() => reminderEnabled = v),
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
                final rawTitle = titleCtrl.text.trim();
                final finalTitle = rawTitle.isEmpty ? 'Untitled Page' : rawTitle;
                final autoDetectedCategory = _detectTopicType(
                  finalTitle,
                  selectedCategory,
                );

                final key = existingKey ??
                    DateTime.now().millisecondsSinceEpoch.toString();
                final notifId = existingItem?['notifId'] is int
                    ? existingItem!['notifId'] as int
                    : DateTime.now().millisecondsSinceEpoch.remainder(100000);

                final pageData = <String, dynamic>{
                  'id': key,
                  'notifId': notifId,
                  'title': finalTitle,
                  'category': autoDetectedCategory,
                  'notes': notesCtrl.text,
                  'targetDate': targetDate.toIso8601String(),
                  'reminderEnabled': reminderEnabled,
                  'updatedAt': DateTime.now().toIso8601String(),
                };

                await _pagesBox.put(key, pageData);

                if (reminderEnabled && targetDate.isAfter(DateTime.now())) {
                  await NotificationService.scheduleOnceNotification(
                    id: notifId,
                    title: 'Timering Countdown: $finalTitle',
                    body: '$autoDetectedCategory - குறித்த நேரத்திற்கான நினைவூட்டல்.',
                    scheduledTime: targetDate,
                    playAlarmSound: true,
                  );
                } else {
                  await NotificationService.cancelNotification(notifId);
                }

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('சேமி'),
            ),
          ],
        ),
      ),
    );
  }

  void _movePageToRecycleBin(String key, Map item) {
    final moved = Map<String, dynamic>.from(item);
    moved['sourceBox'] = 'planner_pages';
    moved['deletedAt'] = DateTime.now().toIso8601String();
    _recycleBox.put(key, moved);
    _pagesBox.delete(key);

    if (item['notifId'] is int) {
      NotificationService.cancelNotification(item['notifId'] as int);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('பக்கம் 30-நாள் Recycle Bin-க்கு மாற்றப்பட்டது.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study, Work & Countdown Pages'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPageEditor(),
        icon: const Icon(Icons.add),
        label: const Text('புதிய பக்கம்'),
      ),
      body: ValueListenableBuilder(
        valueListenable: _pagesBox.listenable(),
        builder: (context, Box box, _) {
          final keys = box.keys.toList();
          if (keys.isEmpty) {
            return const Center(
              child: Text(
                'இன்னும் பக்கங்கள் உருவாக்கப்படவில்லை.\n"+ புதிய பக்கம்" அழுத்தித் தொடங்கவும்.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return PageView.builder(
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final key = keys[index];
              final raw = box.get(key);
              if (raw is! Map) return const SizedBox.shrink();
              final item = Map<String, dynamic>.from(raw);

              return Card(
                margin: const EdgeInsets.all(14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Chip(
                            label: Text(item['category']?.toString() ?? 'Page'),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'திருத்து',
                            onPressed: () => _openPageEditor(
                              existingKey: key.toString(),
                              existingItem: item,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            tooltip: 'Recycle Bin-க்கு அனுப்பு',
                            onPressed: () =>
                                _movePageToRecycleBin(key.toString(), item),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['title']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.teal.withOpacity(0.14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Live Countdown (நாட்கள் : மணி : நிமிடம் : வினாடி)',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatSecondsCountdown(
                                item['targetDate']?.toString(),
                              ),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Notes / Timetable / Schedule:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            item['notes']?.toString() ?? '',
                            style: const TextStyle(fontSize: 15.5, height: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'பக்கம் ${index + 1} / ${keys.length} • பக்கங்களை மாற்ற Swipe செய்யவும்',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
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
