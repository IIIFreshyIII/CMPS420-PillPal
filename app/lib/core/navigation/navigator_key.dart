import 'package:flutter/material.dart';

/// Global root navigator key for navigating or opening modal overlays
/// from outside the primary widget tree (e.g., from MaterialApp.builder).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
