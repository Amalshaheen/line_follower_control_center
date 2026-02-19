import 'package:flutter/material.dart';
import 'screens/device_selection_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Line Follower Control Center',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF06B6D4),
          secondary: const Color(0xFF7C3AED),
          tertiary: const Color(0xFF10B981),
          error: const Color(0xFFEF4444),
          surface: const Color(0xFF1F2937),
          surfaceVariant: const Color(0xFF2D3748),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1F2937),
          elevation: 2,
          centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: const Color(0xFF06B6D4),
          inactiveTrackColor: const Color(0xFF2D3748),
          thumbColor: const Color(0xFF06B6D4),
          overlayColor: const Color(0xFF06B6D4).withOpacity(0.2),
        ),
      ),
      home: const DeviceSelectionScreen(),
    );
  }
}
