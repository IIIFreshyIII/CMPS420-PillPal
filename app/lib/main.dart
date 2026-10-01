import 'dart:io' show Platform;

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
  _hideBottomNavBar();
  // SystemUiMode.manual has no auto-hide timer of its own -- once a swipe
  // reveals the bar it stays until something re-hides it. This callback
  // fires on every such reveal and re-hides it after a couple seconds,
  // matching the auto-dismiss behavior of Android's "sticky immersive" bars
  // while still keeping the status bar always visible (which a plain
  // SystemUiMode.immersiveSticky switch can't do -- it hides both bars
  // together).
  SystemChrome.setSystemUIChangeCallback((systemOverlaysAreVisible) async {
    if (!systemOverlaysAreVisible) return;
    await Future.delayed(const Duration(seconds: 2));
    _hideBottomNavBar();
  });
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      // A fully transparent bar left the icons hard to spot during the
      // brief swipe-reveal (contrast depended entirely on whatever app
      // content happened to be behind them). A ~40% black scrim gives a
      // consistent dark band to read the icons against, so they're switched
      // to light/white to actually show up on it.
      systemNavigationBarColor: Color(0x66000000), // black @ 40% alpha
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: true,
    ),
  );
  runApp(const PillPalApp());
}

void _hideBottomNavBar() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top]);
}

class PillPalApp extends StatelessWidget {
  const PillPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PillPal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Android keeps the system nav bar persistently hidden and only lets
      // it transiently reveal via an edge swipe (re-hidden after ~2s, above).
      // That transient reveal briefly reports a non-zero bottom
      // padding/viewPadding through MediaQuery, and anything that reacts to
      // it -- a bottom bar, a bottom-anchored panel, any SafeArea -- visibly
      // jumps for that instant. Stripping the bottom inset here, once, for
      // the whole app means nothing in the tree can react to it, instead of
      // chasing down every current and future widget that touches it.
      // iOS is untouched: its home-indicator inset is a real, static safe
      // area, not a transient one, and FloatingTabBar depends on it.
      builder: Platform.isAndroid
          ? (context, child) => MediaQuery.removeViewPadding(
                context: context,
                removeBottom: true,
                child: MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: child!,
                ),
              )
          : null,
      home: const HomeScaffold(),
    );
  }
}