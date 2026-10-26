import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'strings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  final prefs = await SharedPreferences.getInstance();
  // Load saved language
  final lang = prefs.getString('app_lang') ?? 'en';
  S.setLang(lang);
  runApp(DrClickerApp(prefs: prefs));
}

class DrClickerApp extends StatelessWidget {
  final SharedPreferences prefs;
  const DrClickerApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dr.Clicker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2E7D32),
          secondary: Color(0xFF66BB6A),
          surface: Color(0xFF141E14),
          onPrimary: Colors.white,
          onSurface: Color(0xFFE8F5E9),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A120A),
        useMaterial3: true,
      ),
      home: HomeScreen(prefs: prefs),
    );
  }
}
