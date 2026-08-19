import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            'Gameplay',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF66584B),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          Consumer<SettingsProvider>(
            builder: (context, settings, _) {
              return Material(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  value: settings.hapticsEnabled,
                  onChanged: settings.setHapticsEnabled,
                  title: const Text('Haptics'),
                  subtitle: const Text(
                    'Vibration feedback when you tap arrows on the board.',
                  ),
                  secondary: const Icon(Icons.vibration_rounded),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
