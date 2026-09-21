import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sas_app/services/auth/auth_service.dart';
import 'package:sas_app/services/auth/biometric_service.dart';
import 'package:sas_app/services/auth/biometric_enrollment.dart';
import 'package:sas_app/core/database/db_helper.dart';
import 'package:sas_app/features/company/company_selection_screen.dart';
import 'package:sas_app/core/services/toast_service.dart';
import 'package:sas_app/core/config/config.dart';

final _storage = const FlutterSecureStorage();

enum _ConnState { idle, checking, ok, failed }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  // --- Configure your default IP / port here ---
  static const String _kDefaultServerAddress = '163.61.41.109:5000';

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _serverController = TextEditingController();

  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _serverFocus = FocusNode();

  final DBHelper _dbHelper = DBHelper();
  final AuthService _apiService = AuthService();
  final BiometricService _bio = BiometricService();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isAkountMaster = false;

  // --- Biometric / saved accounts state ---
  bool _bioAvailable = false;
  List<SavedBiometricAccount> _savedAccounts = [];
  String? _busyAccountId; // account tile currently signing in

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

  // Auto-prompt fires once per app launch, not again after logging out.
  static bool _autoPromptedThisLaunch = false;

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
    _loadBiometricState();

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
    // "Remember me" was replaced by biometric saved accounts. Clear the old
    // saved username/password so an unprotected copy is not left on the device.
    await _storage.delete(key: 'saved_username');
    await _storage.delete(key: 'saved_password');
    await _storage.delete(key: 'remember_me');

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

      final toCheck = _serverController.text.trim().isNotEmpty
          ? _serverController.text
          : _kDefaultServerAddress;
      _checkServer(toCheck, silent: true);
    }
  }

  // ── Biometric state ──────────────────────────────────────────────────────

  Future<void> _loadBiometricState() async {
    final available = await _bio.isAvailable();
    final accounts = available ? await _bio.getAccounts() : <SavedBiometricAccount>[];
    if (!mounted) return;
    setState(() {
      _bioAvailable = available;
      _savedAccounts = accounts;
    });
    _maybeAutoPrompt();
  }

  /// If "Auto-prompt on app open" is on: sign in with the chosen account, the
  /// only saved account, or show the account list when several are saved and
  /// none is chosen.
  Future<void> _maybeAutoPrompt() async {
    if (_autoPromptedThisLaunch) return;
    _autoPromptedThisLaunch = true;

    if (!_bioAvailable || _savedAccounts.isEmpty) return;
    if (!await _bio.getAutoPrompt()) return;

    SavedBiometricAccount? target;
    if (_savedAccounts.length == 1) {
      target = _savedAccounts.first;
    } else {
      final chosenId = await _bio.getAutoPromptAccountId();
      for (final a in _savedAccounts) {
        if (a.id == chosenId) target = a;
      }
    }

    // Let the login screen finish its entrance animation first.
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || _isLoading) return;

    if (target != null) {
      _signInWithSavedAccount(target);
    } else {
      _showBiometricSheet();
    }
  }

  Future<void> _refreshAccounts() async {
    final accounts = _bioAvailable ? await _bio.getAccounts() : <SavedBiometricAccount>[];
    if (!mounted) return;
    setState(() {
      _savedAccounts = accounts;
    });
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
    final target = rawInput.trim().isEmpty ? _kDefaultServerAddress : rawInput.trim();
    if (!silent) {
      setState(() => _serverState = _ConnState.checking);
    }

    final baseUrl = _normalizeServerAddress(target);
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

  // ── Sign in ──────────────────────────────────────────────────────────────

  /// Shared sign-in call used by both the manual form and saved accounts.
  /// Returns true on success. On failure it shows a toast and clears the
  /// loading state. On success the loading state is left on until navigation.
  Future<bool> _signIn({
    required String username,
    required String password,
    required String baseUrl,
    required bool akountMaster,
    String invalidMessage = 'Invalid username or password.',
  }) async {
    setState(() => _isLoading = true);

    await _storage.write(key: _kActiveServerKey, value: baseUrl);
    await _storage.write(key: 'saved_central_db', value: akountMaster.toString());

    final targetDb = akountMaster ? 'SmAkountMaster' : 'SASBillingMaster';

    try {
      final isAuthenticated = await _apiService.login(username, password, targetDb);
      if (!mounted) return false;

      if (isAuthenticated) {
        await _storage.write(key: _kLastGoodServerKey, value: baseUrl);
        await _storage.write(key: 'current_username', value: username);
        return true;
      }

      setState(() => _isLoading = false);
      ToastService.showError(context, invalidMessage);
      return false;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _isLoading = false);
      ToastService.showError(context, 'Connection failed: Unable to reach the server.');
      debugPrint('Backend Connection Error: $e');
      return false;
    }
  }

  void _finishLogin() {
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
  }

  /// Manual sign in (username + password form).
  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty) {
      ToastService.showError(context, 'Please enter your username');
      return;
    }

    // Fallback: If empty, use the default IP address
    final rawServer = _serverController.text.trim();
    final serverToConnect = rawServer.isEmpty ? _kDefaultServerAddress : rawServer;
    final baseUrl = _normalizeServerAddress(serverToConnect);

    final ok = await _signIn(
      username: username,
      password: password,
      baseUrl: baseUrl,
      akountMaster: _isAkountMaster,
    );
    if (!ok || !mounted) return;

    await _prepareBiometricEnrollment(
      username: username,
      password: password,
      baseUrl: baseUrl,
      akountMaster: _isAkountMaster,
    );
    if (!mounted) return;

    _finishLogin();
  }

  /// Sign in with a saved account: biometric prompt first, then the stored
  /// password goes through the normal login call.
  Future<void> _signInWithSavedAccount(SavedBiometricAccount account) async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() => _busyAccountId = account.id);

    final auth = await _bio.authenticate(reason: 'Sign in as ${account.username}');
    if (!mounted) return;

    if (!auth.success) {
      setState(() => _busyAccountId = null);
      if (!auth.canceled) {
        ToastService.showError(context, auth.message ?? 'Biometric authentication failed.');
      }
      return;
    }

    final password = await _bio.readPassword(account.id);
    if (!mounted) return;

    if (password == null || password.isEmpty) {
      await _bio.removeAccount(account.id);
      if (!mounted) return;
      setState(() => _busyAccountId = null);
      await _refreshAccounts();
      if (!mounted) return;
      ToastService.showError(context, 'Saved credentials not found. Please sign in with your password.');
      return;
    }

    // Mirror the account's database, server and username into the manual form.
    setState(() {
      _isAkountMaster = account.isAkount;
      _serverController.text = account.serverAddress;
      _usernameController.text = account.username;
    });

    final ok = await _signIn(
      username: account.username,
      password: password,
      baseUrl: account.serverAddress,
      akountMaster: account.isAkount,
      invalidMessage: 'Sign in failed. If your password changed, use another account to update it.',
    );
    if (!mounted) return;
    setState(() => _busyAccountId = null);

    if (!ok) return;
    await _bio.markUsed(account.id);
    if (!mounted) return;
    _finishLogin();
  }

  /// After a successful manual login: if this account already has biometric
  /// login, silently refresh its stored password. Otherwise stage it so the
  /// dashboard can offer to enable biometric login once the company is chosen.
  Future<void> _prepareBiometricEnrollment({
    required String username,
    required String password,
    required String baseUrl,
    required bool akountMaster,
  }) async {
    if (!_bioAvailable) return;

    final targetDb = akountMaster ? 'SmAkountMaster' : 'SASBillingMaster';
    final id = BiometricService.accountId(
      username: username,
      centralDatabase: targetDb,
      serverAddress: baseUrl,
    );

    try {
      if (await _bio.hasAccount(id)) {
        BiometricEnrollment.clear();
        await _bio.saveAccount(
          username: username,
          password: password,
          centralDatabase: targetDb,
          serverAddress: baseUrl,
        );
        return;
      }

      if (!await _bio.getOfferEnabled()) {
        BiometricEnrollment.clear();
        return;
      }

      BiometricEnrollment.stage(
        username: username,
        password: password,
        centralDatabase: targetDb,
        serverAddress: baseUrl,
      );
    } catch (e) {
      debugPrint('Biometric enrollment staging error: $e');
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
                              ...[
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
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    onTap: () {},
                                    child: Text(
                                      'Forgot password?',
                                      style: TextStyle(
                                        color: _textMain,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
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
                                if (_bioAvailable && _savedAccounts.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  Center(
                                    child: TextButton.icon(
                                      onPressed: _isLoading ? null : _showBiometricSheet,
                                      style: TextButton.styleFrom(foregroundColor: _textMain),
                                      icon: const Icon(Icons.fingerprint_rounded, size: 22),
                                      label: const Text(
                                        'Login with biometric',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.language_rounded,
                              size: 15,
                              color: _textMain.withValues(alpha: 0.65),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'www.smsoftech.com.np',
                              style: TextStyle(
                                color: _textMain.withValues(alpha: 0.75),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '\u00A9 2026 S.M. Softech Solutions Pvt. Ltd.\nAll rights reserved.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _textMain.withValues(alpha: 0.5),
                            fontSize: 11.5,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
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

  // ── Biometric bottom sheet ───────────────────────────────────────────────

  Future<void> _showBiometricSheet() async {
    if (_isLoading || _savedAccounts.isEmpty) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();

    final picked = await showModalBottomSheet<SavedBiometricAccount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 420),
        reverseDuration: Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (ctx) => _buildBiometricSheet(ctx),
    );

    if (picked == null || !mounted) return;

    // Let the sheet finish closing before the system fingerprint prompt appears.
    await Future.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;
    _signInWithSavedAccount(picked);
  }

  Widget _buildBiometricSheet(BuildContext ctx) {
    final bottomInset = MediaQuery.of(ctx).padding.bottom;
    final maxListHeight = MediaQuery.of(ctx).size.height * 0.45;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: _textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.fingerprint_rounded, color: _textMain, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Login with biometric',
                      style: TextStyle(
                        color: _textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose an account to continue',
                      style: TextStyle(color: _textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxListHeight),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _savedAccounts.length,
              itemBuilder: (_, i) {
                final account = _savedAccounts[i];
                return TweenAnimationBuilder<double>(
                  key: ValueKey(account.id),
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 320 + i * 70),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(
                      offset: Offset(0, 14 * (1 - v)),
                      child: child,
                    ),
                  ),
                  child: _buildAccountTile(
                    account,
                    onTap: () => Navigator.pop(ctx, account),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Use password instead',
              style: TextStyle(color: _textMain, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTile(
    SavedBiometricAccount account, {
    required VoidCallback onTap,
  }) {
    final server = account.serverAddress.replaceFirst(RegExp(r'^https?://'), '');
    final initial = account.username.isNotEmpty ? account.username[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _inputBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _accentColor.withValues(alpha: 0.35),
                  child: Text(
                    initial,
                    style: TextStyle(color: _textMain, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.username,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _textMain, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${account.databaseLabel}  \u2022  $server',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.fingerprint_rounded, color: _textMain, size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Server input ─────────────────────────────────────────────────────────

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
          hintText: 'Server address (leave blank for default)',
          hintStyle: TextStyle(color: _textMuted, fontSize: 13),
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