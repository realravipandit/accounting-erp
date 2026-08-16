import 'dart:io';

import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ðŸ‘ˆ Required for SystemChrome
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sas_akount_login/features/dashboard/home_screen.dart';
import 'package:sas_akount_login/features/auth/login_screen.dart';
import 'package:sas_akount_login/features/auth/register_screen.dart';
import 'package:sas_akount_login/features/sales/sale_screen.dart';
import 'package:sas_akount_login/features/purchase/purchase_screen.dart';
import 'package:sas_akount_login/features/search/search_screen.dart';
import 'package:sas_akount_login/features/auth/splash_screen.dart';

void main() {
  // Ensures Flutter services are ready before we check platforms or databases
  WidgetsFlutterBinding.ensureInitialized();

  // ðŸŒŸ 1. Make system navigation/gesture bar transparent & edge-to-edge
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent, // Removes the solid black box
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark, // Adjust to light if your theme is dark
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // 2. First, check if we are NOT on the web.
  // 3. If we are on a mobile/desktop device, check if it's Windows or Linux to init FFI.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAS Akount',
      // ðŸŒŸ This builder ensures Flutter's engine can never overwrite your transparent navigation bar
      builder: (context, child) {
        SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark, // Use Brightness.light if your app background is dark
        ));
        return child!;
      },
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => HomePage(),
        '/sales': (context) => const SaleScreen(),
        '/purchases': (context) => const PurchaseScreen(),
        '/search': (context) => const SearchScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
