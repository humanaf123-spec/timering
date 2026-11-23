import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'services/notification_service.dart';
import 'screens/home_selector_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('timering_alarms');
  await Hive.openBox('planner_pages');
  await Hive.openBox('pdf_library');
  await Hive.openBox('quiz_items');
  await Hive.openBox('recycle_bin');
  await Hive.openBox('app_settings');

  _purgeExpiredRecycleBin();

  await NotificationService.init();

  runApp(const TimeringApp());
}

void _purgeExpiredRecycleBin() {
  final recycleBox = Hive.box('recycle_bin');
  final now = DateTime.now();
  final keysToDelete = <dynamic>[];

  for (final key in recycleBox.keys) {
    final item = recycleBox.get(key);
    if (item is Map && item['deletedAt'] != null) {
      final deletedDate = DateTime.tryParse(item['deletedAt'].toString());
      if (deletedDate != null && now.difference(deletedDate).inDays >= 30) {
        keysToDelete.add(key);
      }
    }
  }

  for (final key in keysToDelete) {
    recycleBox.delete(key);
  }
}

class TimeringApp extends StatefulWidget {
  const TimeringApp({super.key});

  @override
  State<TimeringApp> createState() => _TimeringAppState();
}

class _TimeringAppState extends State<TimeringApp> {
  final Box settingsBox = Hive.box('app_settings');
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    final isDark = settingsBox.get('isDarkMode', defaultValue: true) as bool;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  void toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
      settingsBox.put('isDarkMode', _themeMode == ThemeMode.dark);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Timering',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.tealAccent,
        brightness: Brightness.dark,
      ),
      home: AppLockScreen(onToggleTheme: toggleTheme),
    );
  }
}

class AppLockScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const AppLockScreen({super.key, required this.onToggleTheme});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _unlocked = false;
  String _message = "Timering லாக் செய்யப்பட்டுள்ளது";

  @override
  void initState() {
    super.initState();
    _checkLock();
  }

  Future<void> _checkLock() async {
    final lockEnabled =
        Hive.box('app_settings').get('biometricLockEnabled', defaultValue: true)
            as bool;
    if (!lockEnabled) {
      setState(() => _unlocked = true);
      return;
    }

    try {
      final canCheck = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!canCheck) {
        setState(() => _unlocked = true);
        return;
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason:
            'Timering ஆப்பைத் திறக்க Fingerprint அல்லது போன் Lock-ஐ உறுதிப்படுத்தவும்',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (mounted) {
        setState(() {
          _unlocked = didAuthenticate;
          if (!didAuthenticate) {
            _message = "Lock உறுதிப்படுத்தப்படவில்லை. மீண்டும் முயற்சிக்கவும்.";
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _unlocked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) {
      return HomeSelectorScreen(onToggleTheme: widget.onToggleTheme);
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fingerprint, size: 84, color: Colors.tealAccent),
              const SizedBox(height: 16),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _checkLock,
                icon: const Icon(Icons.lock_open),
                label: const Text("Unlock Timering"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
