import 'package:flutter/material.dart';

// Global Theme Notifier to handle light/dark mode switching across the app
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
