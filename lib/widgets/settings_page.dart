import 'package:flutter/material.dart';
import 'package:notestream_app/state/theme_state.dart';
import 'package:provider/provider.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';


class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // List<Color> colorOptions = [
  //   Colors.teal,
  //   Colors.yellow,
  //   Colors.orange,
  //   Colors.green,
  //   Colors.lightBlue,
  //   Colors.red,
  //   Colors.brown,
  //   Colors.black,
  // ];

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeState>(builder: (context, themeState, child) {
      List<bool> themeModeSelections = [false, false, false];
      int themeMode = themeState.themeMode;
      themeModeSelections[themeMode] = true;
      Color seedColor = themeState.seedColor;
      return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            leading: BackButton(
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SettingsList(sections: [
            SettingsSection(tiles: [
              SettingsTile(
                title: const Text('Theme color'),
                value: CircleAvatar(
                  backgroundColor: themeState.seedColor,
                ),
                onPressed: (context) {
                  showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Pick a color'),
                          content: BlockPicker(
                            pickerColor: seedColor,
                            onColorChanged: (color) {
                              themeState.changeSeedColor(color);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      });
                },
              ),
              // SettingsTile.switchTile(
              //   initialValue: isAutoTheme,
              //   title: const Text('System (auto) brightness'),
              //   onToggle: (value) {
              //     if (value) {
              //       themeState.changeThemeMode(ThemeMode.system);
              //     } else {
              //       if (isLightMode) {
              //         themeState.changeThemeMode(ThemeMode.light);
              //       } else {
              //         themeState.changeThemeMode(ThemeMode.dark);
              //       }
              //     }
              //   },
              // ),
              SettingsTile(
                title: const Text('Brightness'),
                value: ToggleButtons(
                  isSelected: themeModeSelections,
                  onPressed: (index) {
                    themeState.changeThemeMode(index);
                  },
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child:
                          Text('System (auto)', style: TextStyle(fontSize: 18)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Light', style: TextStyle(fontSize: 18)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Dark', style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              ),
            ]),
          ]));
    });
  }
}
