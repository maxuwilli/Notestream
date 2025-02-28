import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';


class ThemeState extends ChangeNotifier {
  SharedPreferences? _sp;
   String keyThemeColor = "theme_color_hex_string";
 String keyThemeMode = "theme_mode";
  Color defaultAppColor = const Color.fromARGB(255, 202, 161, 15);

  set sharedPreferences(SharedPreferences sp) {
    _sp ??= sp;
  }

  // Get/Set for theme color (hex value)
  String get _themeColorHexString => _sp!.getString(keyThemeColor) ?? '';

  set _themeColorHexString(String hexString) {
    _sp!.setString(keyThemeColor, hexString);
  }

  // Get/Set for theme mode (0, 1, 2 == system, light, dark)
  int get _getThemeMode => _sp!.getInt(keyThemeMode) ?? 0;

  set _setThemeMode(int optionValue) {
    _sp!.setInt(keyThemeMode, optionValue);
  }

  final ThemeData _baseTheme = ThemeData(
    // scaffoldBackgroundColor: Colors.white,
    fontFamily: 'Consolas',
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Colors.red,
    ),
    useMaterial3: true,
    // colorScheme: ColorScheme.fromSeed(
    //   seedColor: appSeedColor,
    //   // brightness: Brightness.dark,
    // ),
  );

  void changeSeedColor(Color color) {
    String hexString = color.toHexString();
    _themeColorHexString = hexString;
    notifyListeners();
  }

  void changeThemeMode(int themeMode) {
    // 0 == System
    // 1 == Light
    // 2 == Dark
    _setThemeMode = themeMode;
    notifyListeners();
  }

  Color get seedColor {
    String hexString = _themeColorHexString;
    
    if (hexString.isEmpty) {
      return defaultAppColor;
    } else {
      Color appColor = Color(int.parse(hexString, radix: 16));
      return appColor;
    }
    
  }

  ThemeData get lightTheme {
    return _baseTheme.copyWith(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      )
    );
  }

  ThemeData get darkTheme {
    return _baseTheme.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      textTheme: Typography.whiteCupertino,
      iconButtonTheme: const IconButtonThemeData(style: ButtonStyle(iconColor: WidgetStatePropertyAll<Color>(Colors.white))),
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      )
    );
  }

  int get themeMode {
    int value = _getThemeMode;
    return value;
  }
}
