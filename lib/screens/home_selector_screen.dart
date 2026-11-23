import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'timering_alarm_screen.dart';
import 'planner_hub_screen.dart';
import 'pdf_library_screen.dart';
import 'quiz_screen.dart';
import 'recycle_bin_screen.dart';

class HomeSelectorScreen extends StatelessWidget {
  final VoidCallback onToggleTheme;
  const HomeSelectorScreen({super.key, required this.onToggleTheme});

  Future<void> _launchWeb(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('இணைப்பைத் திறக்க முடியவில்லை.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TIMERING',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: '30-Day Recycle Bin',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecycleBinScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            tooltip: 'Dark / Light Theme',
            onPressed: onToggleTheme,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'தெர்ந்தெடுத்துச் செல்லவும் (Select Feature)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),

            _FeatureCard(
              title: '1. Timering Alarm & Call/SMS/WhatsApp',
              subtitle:
                  'Once-Only Alarm • Auto SMS (Pending Queue) • 20s Call Limit • Safe WhatsApp 1-Tap',
              icon: Icons.alarm,
              accentColor: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TimeringAlarmScreen()),
              ),
            ),
            const SizedBox(height: 14),

            _FeatureCard(
              title: '2. Study, Work & Countdown Planner',
              subtitle:
                  'Multi-Page Notes • Live Days-to-Seconds Countdown • Movie Releases • Timetable',
              icon: Icons.event_note,
              accentColor: Colors.indigo,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlannerHubScreen()),
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'கற்றல் & விரைவு கருவிகள் (Tools & External Apps)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF Library & Reader'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PdfLibraryScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.quiz),
                    label: const Text('Quiz Practice'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuizScreen()),
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ToolChipButton(
                  icon: Icons.auto_awesome,
                  label: 'Gemini AI',
                  onTap: () => _launchWeb(context, 'https://gemini.google.com'),
                ),
                _ToolChipButton(
                  icon: Icons.public,
                  label: 'Chrome',
                  onTap: () => _launchWeb(context, 'https://www.google.com'),
                ),
                _ToolChipButton(
                  icon: Icons.cloud_done,
                  label: 'Offline + Sync',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Offline Storage செயலில் உள்ளது. இணையம் இருக்கும்போது Cloud Sync தயார்.',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: accentColor.withOpacity(0.12),
          border: Border.all(color: accentColor.withOpacity(0.5), width: 1.4),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: accentColor,
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(subtitle, style: const TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _ToolChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          children: [
            CircleAvatar(radius: 22, child: Icon(icon)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
