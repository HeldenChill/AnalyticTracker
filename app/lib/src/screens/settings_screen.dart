import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _ctrl = TextEditingController(text: ref.read(baseUrlProvider));
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = _ctrl.text.trim();
    final uri = Uri.tryParse(v);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      setState(() => _error = 'Enter a URL like http://192.168.1.20:8080');
      return;
    }
    setState(() => _error = null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(baseUrlPrefKey, v);
    ref.read(baseUrlProvider.notifier).set(v);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(labelText: 'Server URL', errorText: _error),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _save, child: const Text('Save')),
        const SizedBox(height: 16),
        const Text('Phones must be on the same Wi-Fi as the server PC. '
            'Use the PC LAN IP, not localhost.'),
      ],
    );
  }
}
