import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sas_akount_login/features/dashboard/home_screen.dart';
import 'package:sas_akount_login/features/auth/login_screen.dart';
import 'package:sas_akount_login/features/auth/register_screen.dart';
import 'package:sas_akount_login/features/sales/sale_screen.dart';
import 'package:sas_akount_login/features/purchase/purchase_screen.dart';
import 'package:sas_akount_login/features/search/search_screen.dart';
import 'package:sas_akount_login/features/auth/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false, 
    statusBarColor: Colors.transparent, 
    statusBarIconBrightness: Brightness.dark,
    systemStatusBarContrastEnforced: false, 
  ));

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
      builder: (context, child) {
        SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarContrastEnforced: false, 
        ));
        return child!;
      },
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF9F5EC), 
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
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