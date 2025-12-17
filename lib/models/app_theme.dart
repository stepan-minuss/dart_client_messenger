import 'package:flutter/material.dart';

class AppTheme {
  final String name;
  final Color primaryColor;
  final Color backgroundColor;
  final Color bubbleColorMe;
  final Color bubbleColorOther;
  final Color textColor;
  final Color secondaryTextColor;
  final Brightness brightness;

  const AppTheme({
    required this.name,
    required this.primaryColor,
    required this.backgroundColor,
    required this.bubbleColorMe,
    required this.bubbleColorOther,
    required this.textColor,
    required this.secondaryTextColor,
    required this.brightness,
  });

  AppTheme copyWith({
    String? name,
    Color? primaryColor,
    Color? backgroundColor,
    Color? bubbleColorMe,
    Color? bubbleColorOther,
    Color? textColor,
    Color? secondaryTextColor,
    Brightness? brightness,
  }) {
    return AppTheme(
      name: name ?? this.name,
      primaryColor: primaryColor ?? this.primaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      bubbleColorMe: bubbleColorMe ?? this.bubbleColorMe,
      bubbleColorOther: bubbleColorOther ?? this.bubbleColorOther,
      textColor: textColor ?? this.textColor,
      secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor,
      brightness: brightness ?? this.brightness,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'primaryColor': primaryColor.value,
      'backgroundColor': backgroundColor.value,
      'bubbleColorMe': bubbleColorMe.value,
      'bubbleColorOther': bubbleColorOther.value,
      'textColor': textColor.value,
      'secondaryTextColor': secondaryTextColor.value,
      'brightness': brightness == Brightness.dark ? 'dark' : 'light',
    };
  }

  factory AppTheme.fromJson(Map<String, dynamic> json) {
    return AppTheme(
      name: json['name'] ?? 'Custom',
      primaryColor: Color(json['primaryColor']),
      backgroundColor: Color(json['backgroundColor']),
      bubbleColorMe: Color(json['bubbleColorMe']),
      bubbleColorOther: Color(json['bubbleColorOther']),
      textColor: Color(json['textColor']),
      secondaryTextColor: Color(json['secondaryTextColor']),
      brightness: json['brightness'] == 'dark' ? Brightness.dark : Brightness.light,
    );
  }

  static const AppTheme cyberViolet = AppTheme(
    name: 'Cyber Violet',
    primaryColor: Color(0xFF7C4DFF),
    backgroundColor: Color(0xFF121212),
    bubbleColorMe: Color(0xFF7C4DFF),
    bubbleColorOther: Color(0xFF1E1E1E),
    textColor: Color(0xFFFFFFFF),
    secondaryTextColor: Color(0xFFB0B0B0),
    brightness: Brightness.dark,
  );

  static const AppTheme light = AppTheme(
    name: 'Light',
    primaryColor: Color(0xFF2196F3),
    backgroundColor: Color(0xFFF5F5F5),
    bubbleColorMe: Color(0xFF2196F3),
    bubbleColorOther: Color(0xFFE0E0E0),
    textColor: Color(0xFF000000),
    secondaryTextColor: Color(0xFF757575),
    brightness: Brightness.light,
  );

  static const AppTheme matrix = AppTheme(
    name: 'Matrix',
    primaryColor: Color(0xFF00FF41),
    backgroundColor: Color(0xFF0D0208),
    bubbleColorMe: Color(0xFF008F11),
    bubbleColorOther: Color(0xFF003B00),
    textColor: Color(0xFF00FF41),
    secondaryTextColor: Color(0xFF008F11),
    brightness: Brightness.dark,
  );

  ThemeData toThemeData() {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        background: backgroundColor,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textColor),
        bodyMedium: TextStyle(color: textColor),
        bodySmall: TextStyle(color: secondaryTextColor),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      cardColor: bubbleColorOther,
    );
  }
}
