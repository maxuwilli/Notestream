import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SettingsList(sections: [
        SettingsSection(tiles: [
          SettingsTile(title: const Text('Theme color'),
          )
        ])
      ]),
    );
  }
}