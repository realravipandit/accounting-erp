import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sas_app/features/auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _ambientController;
  late AnimationController _shimmerController;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _pulseScale;

  // Seamless gradient palette harmonious with the Sunrise Login Theme
  static const Color _bgTop = Color(0xFF9BBDE2);
  static const Color _bgMid = Color(0xFFD4E2DF);
  static const Color _bgBottom = Color(0xFFF6E6CD);
  static const Color _ink = Color(0xFF1A1B1C);
  static const Color _muted = Color(0xFF6B6A66);

  @override
  void initState() {
    super.initState();

    // 1. Entrance choreography
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _logoScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 0.9, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Ambient breathing spheres
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _ambientController, curve: Curves.easeInOutSine),
    );

    // 3. Shimmer progress bar
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _entranceController.forward();

    // Smooth navigation handoff to LoginScreen
    Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 650),
        ),
      );
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ambientController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // Atmospheric Base Gradient
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_bgTop, _bgMid, _bgBottom],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Ambient Glowing Aurora Orbs
            AnimatedBuilder(
              animation: _pulseScale,
              builder: (context, _) {
                return Stack(
                  children: [
                    // Top-Left Soft Cerulean Glow
                    Positioned(
                      top: -120,
                      left: -80,
                      child: Transform.scale(
                        scale: _pulseScale.value,
                        child: Container(
                          width: 380,
                          height: 380,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF7FA9DE).withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    ),
                    // Center-Right Warm Tangerine & Amber Radiance
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.35,
                      right: -100,
                      child: Transform.scale(
                        scale: _pulseScale.value * 0.95,
                        child: Container(
                          width: 320,
                          height: 320,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF0BD86).withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                    // Bottom-Left Mint-Seafoam Pool
                    Positioned(
                      bottom: -80,
                      left: -60,
                      child: Transform.scale(
                        scale: _pulseScale.value * 1.05,
                        child: Container(
                          width: 340,
                          height: 340,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFBCE3DC).withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // Ultra-Diffused Glass Frosting Layer
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),

            // Foreground Layout
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // Hero App Emblem: Clean Floating Logo (No White Capsule/Card)
                  Center(
                    child: AnimatedBuilder(
                      animation: _entranceController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _logoScale.value,
                          child: Opacity(
                            opacity: _logoFade.value,
                            child: child,
                          ),
                        );
                      },
                      child: Hero(
                        tag: 'app_logo_animation',
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 84,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.layers_rounded,
                            size: 80,
                            color: _ink,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Brand Typography
                  FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(
                      position: _textSlide,
                      child: Column(
                        children: [
                          const Text(
                            'SAS APP',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 18,
                                height: 1,
                                color: _muted.withValues(alpha: 0.4),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'BUSINESS SOLUTIONS',
                                  style: TextStyle(
                                    color: _muted.withValues(alpha: 0.9),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 3.5,
                                  ),
                                ),
                              ),
                              Container(
                                width: 18,
                                height: 1,
                                color: _muted.withValues(alpha: 0.4),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Dynamic Micro Shimmer Progress Line
                  FadeTransition(
                    opacity: _textFade,
                    child: AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, _) {
                        return Container(
                          width: 120,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              children: [
                                Positioned(
                                  left: -60 + (_shimmerController.value * 180),
                                  top: 0,
                                  bottom: 0,
                                  width: 60,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          _ink.withValues(alpha: 0.7),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Company Attribution Footer
                  FadeTransition(
                    opacity: _textFade,
                    child: Column(
                      children: [
                        Text(
                          'S.M. SOFTECH SOLUTIONS',
                          style: TextStyle(
                            color: _ink.withValues(alpha: 0.65),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'v1.0.0 - BUSINESS EDITION',
                          style: TextStyle(
                            color: _muted.withValues(alpha: 0.55),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}