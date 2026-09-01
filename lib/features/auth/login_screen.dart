import 'dart:async';
import 'dart:convert';
import 'dart:ui'; 

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:sas_app/services/auth/auth_service.dart';
import 'package:sas_app/core/database/db_helper.dart';
import 'register_screen.dart';
import 'package:sas_app/features/company/company_selection_screen.dart';
import 'package:sas_app/core/services/toast_service.dart'; // Update path if needed

final _storage = const FlutterSecureStorage();

enum _ConnState { idle, checking, ok, failed }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _serverController = TextEditingController();

  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _serverFocus = FocusNode();

  final DBHelper _dbHelper = DBHelper();
  final AuthService _apiService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _isAkountMaster = false;

  // --- Server address state ---
  _ConnState _serverState = _ConnState.idle;
  String? _lastKnownGoodServer;
  bool _showServerSuggestion = false;
  Timer? _debounce;

  static const _kActiveServerKey = 'active_server_address';
  static const _kLastGoodServerKey = 'last_known_good_server';

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
  final Color _successColor = const Color(0xFF4CAF7D);
  final Color _errorColor = const Color(0xFFE11D48);

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
    _serverFocus.addListener(() {
      setState(() {
        _showServerSuggestion = _serverFocus.hasFocus &&
            _lastKnownGoodServer != null &&
            _serverController.text.trim().isEmpty;
      });
    });

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

    final activeServer = await _storage.read(key: _kActiveServerKey);
    final lastGood = await _storage.read(key: _kLastGoodServerKey);

    if (mounted) {
      setState(() {
        if (activeServer != null && activeServer.isNotEmpty) {
          _serverController.text = activeServer;
        }
        _lastKnownGoodServer = lastGood;
      });

      if (_serverController.text.trim().isNotEmpty) {
        _checkServer(_serverController.text, silent: true);
      }
    }
  }

  String _normalizeServerAddress(String input) {
    var addr = input.trim();
    if (!addr.startsWith('http://') && !addr.startsWith('https://')) {
      addr = 'http://$addr';
    }
    if (addr.endsWith('/')) addr = addr.substring(0, addr.length - 1);
    return addr;
  }

  Future<void> _checkServer(String rawInput, {bool silent = false}) async {
    if (rawInput.trim().isEmpty) {
      setState(() => _serverState = _ConnState.idle);
      return;
    }

    if (!silent) {
      setState(() => _serverState = _ConnState.checking);
    }

    final baseUrl = _normalizeServerAddress(rawInput);

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/health'))
          .timeout(const Duration(seconds: 3));

      if (!mounted) return;
      bool ok = false;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        ok = body['status'] == 'ok';
      }

      setState(() => _serverState = ok ? _ConnState.ok : _ConnState.failed);

      if (ok) {
        await _storage.write(key: _kActiveServerKey, value: baseUrl);
        await _storage.write(key: _kLastGoodServerKey, value: baseUrl);
        _lastKnownGoodServer = baseUrl;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _serverState = _ConnState.failed);
      debugPrint('Server health check failed: $e');
    }
  }

  void _onServerChanged(String value) {
    setState(() => _showServerSuggestion = false);
    _debounce?.cancel();
    setState(() => _serverState = _ConnState.idle);
    _debounce = Timer(const Duration(milliseconds: 700), () {
      _checkServer(value);
    });
  }

  void _applySuggestion() {
    if (_lastKnownGoodServer == null) return;
    _serverController.text = _lastKnownGoodServer!;
    setState(() => _showServerSuggestion = false);
    _checkServer(_lastKnownGoodServer!);
  }

  void _login() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final username = _usernameController.text.trim();
    final password = _passwordController.text; // Now accepts blank

    if (username.isEmpty) {
      setState(() => _isLoading = false);
      ToastService.showError(context, 'Please enter your username');
      return;
    }

    if (_serverController.text.trim().isEmpty) {
      setState(() => _isLoading = false);
      ToastService.showError(context, 'Please enter a server address');
      return;
    }

    final baseUrl = _normalizeServerAddress(_serverController.text);
    
    await _storage.write(key: _kActiveServerKey, value: baseUrl);
    await _storage.write(key: 'saved_central_db', value: _isAkountMaster.toString());

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
        await _storage.write(key: _kLastGoodServerKey, value: baseUrl);

        // Optional: Show success toast right before navigating
        ToastService.showSuccess(context, 'Login successful!');

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
        ToastService.showError(context, 'Invalid username or password.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ToastService.showError(context, 'Connection failed: Unable to reach the server.');
      debugPrint('Backend Connection Error: $e');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _serverController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _serverFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemStatusBarContrastEnforced: false,
      ),
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF9BBDE2),
                Color(0xFFD4E2DF),
                Color(0xFFF6E6CD),
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
                        _buildToggle(),
                        const SizedBox(height: 36),
                        Container(
                          padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 40,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Hero(
                                  tag: 'app_logo_animation',
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    height: 44,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.layers_rounded,
                                      size: 44,
                                      color: _textMain,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                'Sign in to SAS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  color: _textMain,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Welcome back to your workspace',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _textMuted,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 28),
                              _buildServerInput(),
                              if (_showServerSuggestion) _buildServerSuggestion(),
                              const SizedBox(height: 12),
                              _buildInput(
                                controller: _usernameController,
                                focusNode: _usernameFocus,
                                label: 'Username',
                                icon: Icons.person_outline_rounded,
                                obscure: false,
                              ),
                              const SizedBox(height: 12),
                              _buildInput(
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                label: 'Password',
                                icon: Icons.lock_outline_rounded,
                                obscure: _obscurePassword,
                                isPassword: true,
                              ),
                              const SizedBox(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(
                                              color: _rememberMe ? _accentColor : _textMuted.withValues(alpha: 0.5),
                                              width: 1.5,
                                            ),
                                            color: _rememberMe ? _accentColor : Colors.transparent,
                                          ),
                                          child: _rememberMe
                                              ? const Icon(Icons.check, size: 13, color: Colors.white)
                                              : null,
                                        ),
                                        const SizedBox(width: 9),
                                        Text(
                                          'Remember me',
                                          style: TextStyle(color: _textMuted, fontSize: 13.5),
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
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 30),
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _btnBg,
                                    foregroundColor: _textMain,
                                    disabledBackgroundColor: _btnBg.withValues(alpha: 0.5),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
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
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(color: _textMain.withValues(alpha: 0.7), fontSize: 14),
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
                        const SizedBox(height: 20),
                        Text(
                          'By signing in, you agree to our Terms of Service\nand Privacy Policy.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _textMain.withValues(alpha: 0.5),
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

  Widget _buildServerInput() {
    final isFocused = _serverFocus.hasFocus;
    Widget? statusIcon;

    switch (_serverState) {
      case _ConnState.checking:
        statusIcon = SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: _textMuted),
        );
        break;
      case _ConnState.ok:
        statusIcon = Icon(Icons.check_circle_rounded, color: _successColor, size: 18);
        break;
      case _ConnState.failed:
        statusIcon = Icon(Icons.error_rounded, color: _errorColor, size: 18);
        break;
      case _ConnState.idle:
        statusIcon = null;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isFocused ? _inputBg.withValues(alpha: 0.9) : _inputBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocused ? _accentColor : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: TextFormField(
        controller: _serverController,
        focusNode: _serverFocus,
        style: TextStyle(color: _textMain, fontSize: 14.5),
        cursorColor: _accentColor,
        cursorHeight: 18,
        keyboardType: TextInputType.url,
        onChanged: _onServerChanged,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Server address',
          hintStyle: TextStyle(color: _textMuted, fontSize: 14),
          prefixIcon: Icon(
            Icons.dns_rounded,
            color: isFocused ? _textMain : _textMuted,
            size: 19,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 20),
          suffixIcon: statusIcon == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(widthFactor: 1, child: statusIcon),
                ),
          suffixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildServerSuggestion() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: GestureDetector(
        onTap: _applySuggestion,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Icon(Icons.history_rounded, size: 14, color: _textMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _lastKnownGoodServer!,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _textMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      height: 56,
      width: 280,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutBack,
            alignment: _isAkountMaster ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                ),
              ),
            ),
          ),
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
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: !_isAkountMaster ? _textMain : _textMuted.withValues(alpha: 0.7),
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
                        color: _isAkountMaster ? _textMain : _textMuted.withValues(alpha: 0.7),
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

  Widget _buildInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    required bool obscure,
    bool isPassword = false,
  }) {
    final isFocused = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isFocused ? _inputBg.withValues(alpha: 0.9) : _inputBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocused ? _accentColor : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscure,
        style: TextStyle(color: _textMain, fontSize: 14.5),
        cursorColor: _accentColor,
        cursorHeight: 18,
        decoration: InputDecoration(
          isDense: true,
          hintText: label,
          hintStyle: TextStyle(color: _textMuted, fontSize: 14),
          prefixIcon: Icon(
            icon,
            color: isFocused ? _textMain : _textMuted,
            size: 19,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: _textMuted,
                    size: 19,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 20),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}