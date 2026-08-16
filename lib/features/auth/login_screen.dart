import 'package:flutter/material.dart';
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

  // State for Database Toggle (false = Billing, true = Akount)
  bool _isAkountMaster = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // Load saved credentials and persistent database choice on screen load
    _loadSavedData();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _usernameFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    _animationController.forward();
  }

  // Fetch and inject saved credentials and persistent database preference
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

    // Load saved database toggle preference
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

    String username = _usernameController.text.trim();
    String password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both username and password')),
      );
      return;
    }

    // Determine hidden database name based on toggle state
    String hiddenTargetDatabase = _isAkountMaster ? 'SmAkountMaster' : 'SASBillingMaster';

    try {
      bool isAuthenticated = await _apiService.login(username, password, hiddenTargetDatabase);

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
            pageBuilder: (context, animation, secondaryAnimation) => const CompanySelectionScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid username or password.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection failed: Unable to reach the server.'),
          backgroundColor: Color(0xFFD97706),
          duration: Duration(seconds: 4),
        ),
      );
      debugPrint('Backend Connection Error: $e');
    }
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
    final Color scaffoldBackground = _isAkountMaster
        ? Colors.blueGrey[50]!
        : const Color(0xFFF9FAFB);

    return Scaffold(
      extendBody: true, // Ã°Å¸Å’Å¸ Extends the background all the way down behind the gesture bar
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Row(
            children: [
              Text(
                'Billing',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: !_isAkountMaster ? FontWeight.bold : FontWeight.normal,
                  color: !_isAkountMaster ? const Color(0xFF4F46E5) : Colors.grey,
                ),
              ),
              Switch(
                value: _isAkountMaster,
                activeThumbColor: const Color(0xFF9333EA),
                inactiveThumbColor: const Color(0xFF4F46E5),
                inactiveTrackColor: const Color(0xFFEEF0FE),
                onChanged: (bool value) async {
                  setState(() {
                    _isAkountMaster = value;
                  });
                  // Save toggle preference instantly to secure storage
                  await _storage.write(key: 'saved_central_db', value: value.toString());
                },
              ),
              Text(
                'Akount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: _isAkountMaster ? FontWeight.bold : FontWeight.normal,
                  color: _isAkountMaster ? const Color(0xFF9333EA) : Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
            ],
          )
        ],
      ),
      body: Container(
        color: scaffoldBackground,
        child: Stack(
          children: [
            SafeArea(
              bottom: false, // Ã°Å¸Å’Å¸ Lets the bottom content flow transparently under the gesture bar
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFEEF0FE), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.10),
                              blurRadius: 40,
                              spreadRadius: -6,
                              offset: const Offset(0, 20),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Center(
                              child: Hero(
                                tag: 'app_logo_animation',
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  height: 50,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            SlideTransition(
                              position: _slideAnimation,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: Column(
                                  children: [
                                    Center(
                                      child: ShaderMask(
                                        shaderCallback: (bounds) => const LinearGradient(
                                          colors: [Color(0xFF4F46E5), Color(0xFF9333EA)],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ).createShader(bounds),
                                        child: const Text(
                                          'Log in to your account',
                                          style: TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: -0.6,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Center(
                                      child: Text(
                                        'Welcome back! Please enter your details.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 40),
                                    TweenAnimationBuilder<double>(
                                      tween: Tween<double>(begin: 1.0, end: _usernameFocus.hasFocus ? 1.02 : 1.0),
                                      duration: const Duration(milliseconds: 200),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, scale, child) {
                                        return Transform.scale(
                                          scale: scale,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(14),
                                              boxShadow: _usernameFocus.hasFocus ? [
                                                BoxShadow(
                                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                                                  blurRadius: 16,
                                                  offset: const Offset(0, 6),
                                                )
                                              ] : null,
                                            ),
                                            child: TextFormField(
                                              controller: _usernameController,
                                              focusNode: _usernameFocus,
                                              style: const TextStyle(color: Color(0xFF0F172A)),
                                              decoration: InputDecoration(
                                                labelText: 'Username',
                                                hintText: _usernameFocus.hasFocus ? 'Enter your username' : '',
                                                labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 15),
                                                floatingLabelStyle: const TextStyle(
                                                  color: Color(0xFF4F46E5),
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600
                                                ),
                                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                                prefixIcon: Icon(
                                                  Icons.person_outline,
                                                  color: _usernameFocus.hasFocus ? const Color(0xFF4F46E5) : const Color(0xFF9CA3AF),
                                                ),
                                                filled: true,
                                                fillColor: const Color(0xFFF8F9FC),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(14),
                                                  borderSide: const BorderSide(color: Color(0xFFE9EAF2)),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(14),
                                                  borderSide: const BorderSide(color: Color(0xFFE9EAF2)),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(14),
                                                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.6),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 24),
                                    TweenAnimationBuilder<double>(
                                      tween: Tween<double>(begin: 1.0, end: _passwordFocus.hasFocus ? 1.02 : 1.0),
                                      duration: const Duration(milliseconds: 200),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, scale, child) {
                                        return Transform.scale(
                                          scale: scale,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(14),
                                              boxShadow: _passwordFocus.hasFocus ? [
                                                BoxShadow(
                                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                                                  blurRadius: 16,
                                                  offset: const Offset(0, 6),
                                                )
                                              ] : null,
                                            ),
                                            child: TextFormField(
                                              controller: _passwordController,
                                              focusNode: _passwordFocus,
                                              obscureText: _obscurePassword,
                                              style: const TextStyle(color: Color(0xFF0F172A)),
                                              decoration: InputDecoration(
                                                labelText: 'Password',
                                                hintText: _passwordFocus.hasFocus ? '--------' : '',
                                                labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 15),
                                                floatingLabelStyle: const TextStyle(
                                                  color: Color(0xFF4F46E5),
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600
                                                ),
                                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                                prefixIcon: Icon(
                                                  Icons.lock_outline,
                                                  color: _passwordFocus.hasFocus ? const Color(0xFF4F46E5) : const Color(0xFF9CA3AF),
                                                ),
                                                filled: true,
                                                fillColor: const Color(0xFFF8F9FC),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(14),
                                                  borderSide: const BorderSide(color: Color(0xFFE9EAF2)),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(14),
                                                  borderSide: const BorderSide(color: Color(0xFFE9EAF2)),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(14),
                                                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.6),
                                                ),
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                                    color: const Color(0xFF9CA3AF),
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _obscurePassword = !_obscurePassword;
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: Checkbox(
                                                value: _rememberMe,
                                                activeColor: const Color(0xFF4F46E5),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                side: const BorderSide(color: Color(0xFFD1D5DB)),
                                                onChanged: (value) {
                                                  setState(() {
                                                    _rememberMe = value ?? false;
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Remember me !',
                                              style: TextStyle(
                                                color: Color(0xFF374151),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        GestureDetector(
                                          onTap: () {},
                                          child: const Text(
                                            'Forgot password?',
                                            style: TextStyle(
                                              color: Color(0xFF4F46E5),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF4F46E5), Color(0xFF9333EA)],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF4F46E5).withValues(alpha: 0.30),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: _login,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: const Text(
                                            'Sign In',
                                            style: TextStyle(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          "Don't have an account? ",
                                          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => const RegisterScreen(),
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            'Sign up',
                                            style: TextStyle(
                                              color: Color(0xFF4F46E5),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'By signing in, you agree to our Terms of Service\nand Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              AnimatedOpacity(
                opacity: _isLoading ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.7),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

