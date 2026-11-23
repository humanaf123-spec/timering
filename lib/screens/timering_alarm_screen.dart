import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/automation_service.dart';
import '../services/notification_service.dart';

class TimeringAlarmScreen extends StatefulWidget {
  const TimeringAlarmScreen({super.key});

  @override
  State<TimeringAlarmScreen> createState() => _TimeringAlarmScreenState();
}

class _TimeringAlarmScreenState extends State<TimeringAlarmScreen> {
  final Box _alarmBox = Hive.box('timering_alarms');
  final Box _recycleBox = Hive.box('recycle_bin');

  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _msgCtrl = TextEditingController();

  String _actionType = 'SMS';
  bool _isWhatsAppVoice = false;
  DateTime _alarmDateTime = DateTime.now().add(const Duration(minutes: 2));

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _alarmDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_alarmDateTime),
    );
    if (time == null || !mounted) return;

    setState(() {
      _alarmDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _saveOnceAlarm() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('தயவுசெய்து Phone / WhatsApp எண்ணை உள்ளிடவும்.')),
      );
      return;
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final notifId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    final alarmData = <String, dynamic>{
      'id': id,
      'notifId': notifId,
      'phone': phone,
      'message': _msgCtrl.text.trim(),
      'type': _actionType,
      'isWhatsAppVoice': _isWhatsAppVoice,
      'scheduledAt': _alarmDateTime.toIso8601String(),
      'mode': 'ONCE_ONLY',
      'status': 'SAVED & READY',
    };

    await _alarmBox.put(id, alarmData);

    await NotificationService.scheduleOnceNotification(
      id: notifId,
      title: 'Timering Alarm ($_actionType)',
      body: '$phone - Save செய்யப்பட்ட நேரத்திற்குத் தயாராக உள்ளது.',
      scheduledTime: _alarmDateTime,
      playAlarmSound: true,
    );

    _phoneCtrl.clear();
    _msgCtrl.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Once-Only Alarm சேமிக்கப்பட்டது. நேரமானதும் செயல்படும்.'),
        ),
      );
      setState(() {});
    }
  }

  void _confirmWhatsAppTap(Map item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('WhatsApp 1-Tap Confirmation'),
        content: Text(
          '3rd-party ஆட்டோமேஷன் காரணமாக WhatsApp Ban ஆகாமல் இருக்க, தானாக அனுப்பப்படவில்லை.\n\n'
          'எண்: ${item['phone']}\n'
          'வகை: ${item['isWhatsAppVoice'] == true ? 'Voice Record நினைவூட்டல்' : 'Message'}\n'
          'செய்தி: ${item['message'] ?? ''}\n\n'
          'நீங்கள் Tap செய்தால் மட்டுமே WhatsApp திறக்கும்.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('பிறகு'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('1-Tap திறக்கவும்'),
            onPressed: () {
              Navigator.pop(context);
              AutomationService.openWhatsAppOneTap(
                alarmId: item['id'].toString(),
                phoneNumber: item['phone'].toString(),
                message: (item['message'] ?? '').toString(),
                isVoiceReminder: item['isWhatsAppVoice'] == true,
              );
            },
          ),
        ],
      ),
    );
  }

  void _executeAlarmAction(Map item) {
    final id = item['id'].toString();
    final phone = item['phone'].toString();
    final msg = (item['message'] ?? '').toString();
    final type = item['type'].toString();

    if (type == 'SMS') {
      AutomationService.runAutoSms(
        alarmId: id,
        phoneNumber: phone,
        message: msg.isEmpty ? 'Reminder from Timering' : msg,
      );
    } else if (type == 'CALL') {
      AutomationService.runAutoCall(
        alarmId: id,
        phoneNumber: phone,
        holdMuteSeconds: 7,
      );
    } else if (type == 'WHATSAPP') {
      _confirmWhatsAppTap(item);
    }
  }

  void _deleteToRecycleBin(String key, Map item) {
    final moved = Map<String, dynamic>.from(item);
    moved['sourceBox'] = 'timering_alarms';
    moved['deletedAt'] = DateTime.now().toIso8601String();
    _recycleBox.put(key, moved);
    _alarmBox.delete(key);

    if (item['notifId'] is int) {
      NotificationService.cancelNotification(item['notifId'] as int);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('30-நாள் Recycle Bin-க்கு மாற்றப்பட்டது.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedTime =
        '${_alarmDateTime.day}/${_alarmDateTime.month}/${_alarmDateTime.year}  '
        '${_alarmDateTime.hour.toString().padLeft(2, '0')}:${_alarmDateTime.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Timering Alarm (Once Only)')),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'நபர் / Phone / WhatsApp எண்',
                      hintText: 'எ.கா: +94771234567',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _msgCtrl,
                    decoration: const InputDecoration(
                      labelText: 'செய்தி / குறிப்பு (SMS அல்லது WhatsApp-க்கு)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('செயல்: '),
                      const SizedBox(width: 6),
                      DropdownButton<String>(
                        value: _actionType,
                        items: const [
                          DropdownMenuItem(value: 'SMS', child: Text('Auto SMS')),
                          DropdownMenuItem(value: 'CALL', child: Text('20s Auto Call')),
                          DropdownMenuItem(value: 'WHATSAPP', child: Text('WhatsApp 1-Tap')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _actionType = val);
                          }
                        },
                      ),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.schedule),
                        label: Text(formattedTime, style: const TextStyle(fontSize: 12.5)),
                        onPressed: _pickDateTime,
                      ),
                    ],
                  ),
                  if (_actionType == 'WHATSAPP')
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Voice Record நினைவூட்டலாகக் காட்டு'),
                      value: _isWhatsAppVoice,
                      onChanged: (v) => setState(() => _isWhatsAppVoice = v),
                    ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.alarm_add),
                      label: const Text('Save Once-Only Alarm'),
                      onPressed: _saveOnceAlarm,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _alarmBox.listenable(),
              builder: (context, Box box, _) {
                final keys = box.keys.toList();
                if (keys.isEmpty) {
                  return const Center(
                    child: Text('இன்னும் Once-Only Alarm எதுவும் சேமிக்கப்படவில்லை.'),
                  );
                }

                return ListView.builder(
                  itemCount: keys.length,
                  itemBuilder: (context, index) {
                    final key = keys[index];
                    final raw = box.get(key);
                    if (raw is! Map) return const SizedBox.shrink();
                    final item = Map<String, dynamic>.from(raw);
                    final statusText = (item['status'] ?? 'SAVED').toString();
                    final isPending = statusText.startsWith('PENDING');

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      child: ListTile(
                        leading: Icon(
                          item['type'] == 'CALL'
                              ? Icons.phone_callback
                              : item['type'] == 'WHATSAPP'
                                  ? Icons.chat_bubble_outline
                                  : Icons.sms_outlined,
                          color: isPending ? Colors.orange : Colors.tealAccent,
                        ),
                        title: Text('${item['phone']} • ${item['type']} (Once)'),
                        subtitle: Text('நிலை: $statusText'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: () => _executeAlarmAction(item),
                              child: Text(isPending ? 'OK' : 'Run'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteToRecycleBin(key, item),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
