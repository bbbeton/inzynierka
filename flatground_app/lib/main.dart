import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/main_tab_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const FlatgroundApp());
}

class FlatgroundApp extends StatelessWidget {
  const FlatgroundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FLATGROUND',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const MainTabScreen(),
    );
  }
}
