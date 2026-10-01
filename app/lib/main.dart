import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'screens/home/home_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Hide the bottom navigation bar entirely (kept persistently visible by
  // edgeToEdge, just made translucent) -- only the top status bar stays.
  // The bar reappears temporarily if the user swipes up from the bottom
  // edge, standard Android gesture-nav behavior; PillPal's own back/tab
  // controls don't depend on it being visible.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  runApp(const PillPalApp());
}

class PillPalApp extends StatelessWidget {
  const PillPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PillPal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScaffold(),
    );
  }
}