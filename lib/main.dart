import 'dart:io';

import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sas_akount_login/screens/home_screen.dart';
import 'package:sas_akount_login/screens/login_screen.dart';
import 'package:sas_akount_login/screens/register_screen.dart';
import 'package:sas_akount_login/screens/sale_screen.dart';
import 'package:sas_akount_login/screens/purchase_screen.dart';
import 'package:sas_akount_login/screens/search_screen.dart';
import 'package:sas_akount_login/screens/splash_screen.dart';

void main() {
  // Ensures Flutter services are ready before we check platforms or databases
  WidgetsFlutterBinding.ensureInitialized();

  // 1. First, check if we are NOT on the web.
  // 2. If we are on a mobile/desktop device, check if it's Windows or Linux to init FFI.
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomePage(),
        '/sales': (context) => const SaleScreen(),
        '/purchases': (context) => const PurchaseScreen(),
        '/search': (context) => const SearchScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}