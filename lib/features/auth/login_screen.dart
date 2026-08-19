import 'dart:ui'; // Required for ImageFilter.blur in the liquid toggle
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for AnnotatedRegion & SystemUIOverlayStyle
import 'package:sas_akount_login/services/auth/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sas_akount_login/core/database/db_helper.dart';
import 'register_screen.dart';
import 'package:sas_akount_login/features/company/company_selection_screen.dart';

final _storage = const FlutterSecureStorage();

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final DBHelper _dbHelper = DBHelper();
  final AuthService _apiService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _isAkountMaster = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // --- Theme Colors: Sunrise Vibe ---
  final Color _cardBg = const Color(0xFFF9F5EC); 
  final Color _inputBg = const Color(0xFFE8E2D2); 
  final Color _btnBg = const Color(0xFFE3DCC8); 
  final Color _textMain = const Color(0xFF1A1B1C); 
  final Color _textMuted = const Color(0xFF6B6A66); 
  final Color _accentColor = const Color(0xFF9BBDE2); 

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _usernameFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    _animationController.forward();
  }

  Future<void> _loadSavedData() async {
    final savedRememberMe = await _storage.read(key: 'remember_me');
    if (savedRememberMe == 'true') {
      final savedUsername = await _storage.read(key: 'saved_username');
      final savedPassword = await _storage.read(key: 'saved_password');
      if (mounted) {
        setState(() {
          _rememberMe = true;
          _usernameController.text = savedUsername ?? '';
          _passwordController.text = savedPassword ?? '';
        });
      }
    }
    final savedDbMode = await _storage.read(key: 'saved_central_db');
    if (savedDbMode != null && mounted) {
      setState(() {
        _isAkountMaster = savedDbMode == 'true';
      });
    }
  }

  void _login() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _isLoading = false);
      _showSnack('Please fill in both username and password', isError: true);
      return;
    }
    final targetDb = _isAkountMaster ? 'SmAkountMaster' : 'SASBillingMaster';

    try {
      final isAuthenticated = await _apiService.login(username, password, targetDb);
      if (!mounted) return;

      if (isAuthenticated) {
        if (_rememberMe) {
          await _storage.write(key: 'saved_username', value: username);
          await _storage.write(key: 'saved_password', value: password);
          await _storage.write(key: 'remember_me', value: 'true');
        } else {
          await _storage.delete(key: 'saved_username');
          await _storage.delete(key: 'saved_password');
          await _storage.write(key: 'remember_me', value: 'false');
        }
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const CompanySelectionScreen(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
      } else {
        setState(() => _isLoading = false);
        _showSnack('Invalid username or password.', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Connection failed: Unable to reach the server.', isError: true);
      debugPrint('Backend Connection Error: $e');
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? const Color(0xFFE11D48) : const Color(0xFF9BBDE2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AnnotatedRegion explicitly tells the system to keep the gesture bar transparent on this screen
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark, 
        systemNavigationBarContrastEnforced: false, // Forces Android to drop the translucent background
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemStatusBarContrastEnforced: false,
      ),
      child: Scaffold(
        // extendBody is crucial: it forces the background to draw UNDER the transparent gesture bar
        extendBody: true,
        extendBodyBehindAppBar: true,
        
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF9BBDE2), // Sky Blue
                Color(0xFFD4E2DF), // Muted Transition
                Color(0xFFF6E6CD), // Peach/Cream
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Liquid Toggle
                        _buildToggle(),
                        const SizedBox(height: 40),
                        
                        // Main Card
                        Container(
                          padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 40,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Logo
                              Center(
                                child: Hero(
                                  tag: 'app_logo_animation',
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    height: 48,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.layers_rounded,
                                      size: 48,
                                      color: _textMain,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                'Sign in to SAS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                  color: _textMain,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Welcome back to your workspace',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _textMuted,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 36),
                              
                              // Username Input
                              _buildInput(
                                controller: _usernameController,
                                focusNode: _usernameFocus,
                                label: 'Username',
                                icon: Icons.person_outline_rounded,
                                obscure: false,
                              ),
                              const SizedBox(height: 16),
                              
                              // Password Input
                              _buildInput(
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                label: 'Password',
                                icon: Icons.lock_outline_rounded,
                                obscure: _obscurePassword,
                                isPassword: true,
                              ),
                              const SizedBox(height: 20),
                              
                              // Remember + Forgot Password
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: _rememberMe ? _accentColor : _textMuted.withOpacity(0.5),
                                              width: 1.5,
                                            ),
                                            color: _rememberMe ? _accentColor : Colors.transparent,
                                          ),
                                          child: _rememberMe
                                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Remember me',
                                          style: TextStyle(color: _textMuted, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {}, // TODO: Implement forgot password
                                    child: Text(
                                      'Forgot password?',
                                      style: TextStyle(
                                        color: _textMain,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 36),
                              
                              // Sign In Button
                              SizedBox(
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _btnBg,
                                    foregroundColor: _textMain,
                                    disabledBackgroundColor: _btnBg.withOpacity(0.5),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(50), 
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.black87,
                                          ),
                                        )
                                      : const Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Create account
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(color: _textMain.withOpacity(0.7), fontSize: 14),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                );
                              },
                              child: Text(
                                'Create one',
                                style: TextStyle(
                                  color: _textMain,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'By signing in, you agree to our Terms of Service\nand Privacy Policy.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _textMain.withOpacity(0.5),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Liquid Glass Elastic Toggle Switch
  // Liquid Glass Elastic Toggle Switch
  Widget _buildToggle() {
    return Container(
      height: 56, // Matched to the video's proportions
      width: 280,
      padding: const EdgeInsets.all(6), // Inner padding creates the track effect
      decoration: BoxDecoration(
        // The track: Soft translucent white with a shadow (like the video's light mode)
        color: Colors.white.withOpacity(0.6), 
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        children: [
          // 1. The Sliding Liquid Glass Pill
          AnimatedAlign(
            // easeOutBack gives that slight liquid/elastic overshoot as it settles
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutBack, 
            alignment: _isAkountMaster ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5, // Takes up exactly half the track
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: BackdropFilter(
                  // The liquid glass blur from the video's dark mode
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: Container(
                    decoration: BoxDecoration(
                      // The "greyed out" active color from the video's light mode
                      color: Colors.black.withOpacity(0.07), 
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // 2. The Text Options
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    setState(() => _isAkountMaster = false);
                    await _storage.write(key: 'saved_central_db', value: 'false');
                  },
                  child: Center(
                    // Smoothly animates the text weight and color when selected
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: !_isAkountMaster ? _textMain : _textMuted.withOpacity(0.7),
                        fontWeight: !_isAkountMaster ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                      child: const Text('Billing'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    setState(() => _isAkountMaster = true);
                    await _storage.write(key: 'saved_central_db', value: 'true');
                  },
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: _isAkountMaster ? _textMain : _textMuted.withOpacity(0.7),
                        fontWeight: _isAkountMaster ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                      child: const Text('Akount'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Borderless, heavily rounded input fields
  Widget _buildInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    required bool obscure,
    bool isPassword = false,
  }) {
    final isFocused = focusNode.hasFocus;
    
    return Container(
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFocused ? _accentColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscure,
        style: TextStyle(color: _textMain, fontSize: 15),
        cursorColor: _textMain,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isFocused ? _textMain : _textMuted,
            fontSize: 14,
          ),
          floatingLabelStyle: TextStyle(
            color: _textMain,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(
            icon,
            color: isFocused ? _textMain : _textMuted,
            size: 22,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: _textMuted,
                    size: 22,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}