import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers.dart';
import '../state/style.dart';
import '../theme/analytics_tokens.dart';
import '../theme/app_style.dart';

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
    final theme = Theme.of(context);
    final current = ref.watch(styleProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Appearance', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Applies on this PC only.', style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final s in AppStyle.values)
              _StyleCard(
                style: s,
                selected: s == current,
                onTap: () => ref.read(styleProvider.notifier).select(s),
              ),
          ],
        ),
        const SizedBox(height: 28),
        Text('Server', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          width: 480,
          child: TextField(
            controller: _ctrl,
            decoration: InputDecoration(labelText: 'Server URL', errorText: _error),
            keyboardType: TextInputType.url,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(onPressed: _save, child: const Text('Save')),
        ),
        const SizedBox(height: 12),
        const Text('Phones must be on the same Wi-Fi as the server PC. '
            'Use the PC LAN IP, not localhost.'),
      ],
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({required this.style, required this.selected, required this.onTap});

  final AppStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = AnalyticsTokens.of(context);
    final p = palettes[style]!;
    final radius = BorderRadius.circular(tokens.radius);
    return SizedBox(
      width: 250,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  for (final c in [p.background, p.card, p.accent, p.chart[1], p.text])
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Text(style.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                  if (selected) Icon(Icons.check_circle, color: scheme.primary, size: 18),
                ]),
                const SizedBox(height: 4),
                Text(style.description, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
