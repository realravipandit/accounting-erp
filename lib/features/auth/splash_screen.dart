import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui'; // Required for the glass blur effect
import 'package:sas_app/features/auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _masterController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Controls the fade-in of the text
    _masterController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Controls the slow breathing effect of the background gradients
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _masterController, curve: Curves.easeIn),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _masterController.forward();

    // 2-second hold before seamless transition
    Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800), 
        ),
      );
    });
  }

  @override
  void dispose() {
    _masterController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), 
      body: Stack(
        children: [
          // --- AURORA BACKGROUND LAYER ---
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  // Top-left dark blue glow
                  Positioned(
                    top: -100,
                    left: -100,
                    child: Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF1E3A8A), // Deep Corporate Blue
                        ),
                      ),
                    ),
                  ),
                  // Bottom-right vibrant blue glow
                  Positioned(
                    bottom: -150,
                    right: -50,
                    child: Transform.scale(
                      scale: _pulseAnimation.value * 0.9,
                      child: Container(
                        width: 400,
                        height: 400,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.6), // Vibrant Blue
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
          ),

          // --- FROSTED GLASS LAYER ---
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                color: const Color(0xFFF9FAFB).withValues(alpha: 0.7), 
              ),
            ),
          ),

          // --- FOREGROUND LAYER ---
          // Logo remains perfectly centered for the Hero flight
          Center(
            child: Hero(
              tag: 'app_logo_animation', 
              child: Image.asset(
                'assets/images/logo.png',
                height: 90, 
              ),
            ),
          ),
          
          // Bottom Typography and Custom Loader
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SAS AKOUNT',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4.0, 
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ENTERPRISE POS',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Sleek horizontal loading bar instead of the standard circle
                  SizedBox(
                    width: 120,
                    height: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: const LinearProgressIndicator(
                        backgroundColor: Color(0xFFE5E7EB),
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
