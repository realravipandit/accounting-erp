import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sas_akount_login/services/auth/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sas_akount_login/features/dashboard/home_screen.dart';
import 'package:sas_akount_login/features/auth/login_screen.dart';

// --- Sunrise Theme Colors ---
class SunriseTheme {
  static const Color bgTop = Color(0xFF9BBDE2);
  static const Color bgMid = Color(0xFFD4E2DF);
  static const Color bgBottom = Color(0xFFF6E6CD);
  static const Color cardBg = Color(0xFFF9F5EC);
  static const Color btnBg = Color(0xFFE3DCC8);
  static const Color textMain = Color(0xFF1A1B1C);
  static const Color textMuted = Color(0xFF6B6A66);
  static const Color accent = Color(0xFF9BBDE2);
  static const Color danger = Color(0xFFD94C4C);
}

class CompanySelectionScreen extends StatefulWidget {
  const CompanySelectionScreen({super.key});

  @override
  State<CompanySelectionScreen> createState() => _CompanySelectionScreenState();
}

class _CompanySelectionScreenState extends State<CompanySelectionScreen> {
  final AuthService _apiService = AuthService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  List<dynamic> _companies = [];
  Map<String, dynamic>? _selectedCompany;
  bool _isLoading = true;
  bool _isContinuing = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final companies = await _apiService.getCompanies();
      if (!mounted) return;
      setState(() {
        _companies = companies;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleContinue() async {
    if (_selectedCompany == null || _isContinuing) return;

    setState(() => _isContinuing = true);

    try {
      await _storage.write(
        key: 'selected_company_id',
        value: _selectedCompany!['CompanyID']?.toString() ?? '',
      );
      await _storage.write(
        key: 'selected_company_code',
        value: _selectedCompany!['CompanyCode']?.toString() ?? '',
      );
      await _storage.write(
        key: 'selected_company_name',
        value: _selectedCompany!['CompanyName']?.toString() ?? '',
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => HomePage(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 250),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isContinuing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to save your selected workspace.', style: TextStyle(color: Colors.white)),
          backgroundColor: SunriseTheme.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _selectCompany(Map<String, dynamic> company) {
    setState(() {
      _selectedCompany = company;
    });
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
                SunriseTheme.bgTop,
                SunriseTheme.bgMid,
                SunriseTheme.bgBottom,
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
          child: SafeArea(
            bottom: false, // Let the bottom bar handle the safe area for edge-to-edge design
            child: Column(
              children: [
                _buildHeader(),
                _buildHeroSection(),
                Expanded(child: _buildContent()),
                _buildBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
      child: Row(
        children: [
          // Logo Pill
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.layers_rounded,
                color: SunriseTheme.textMain,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _loadCompanies,
            tooltip: 'Refresh companies',
            icon: Icon(
              Icons.refresh_rounded,
              color: SunriseTheme.textMain.withValues(alpha: 0.7),
            ),
          ),
          IconButton(
            onPressed: _logout,
            tooltip: 'Logout',
            icon: const Icon(
              Icons.logout_rounded,
              color: SunriseTheme.danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Welcome back',
            style: TextStyle(
              fontSize: 16,
              color: SunriseTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a workspace',
            style: TextStyle(
              fontFamily: 'Outfit', // Or your custom font
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: SunriseTheme.textMain,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isLoading
                ? 'Loading your available companies...'
                : '${_companies.length} workspace${_companies.length == 1 ? '' : 's'} available for you',
            style: TextStyle(
              fontSize: 14,
              color: SunriseTheme.textMain.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _companies.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: SunriseTheme.textMain,
          strokeWidth: 2.5,
        ),
      );
    }
    if (_errorMessage.isNotEmpty) {
      return _buildErrorState();
    }
    if (_companies.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), // Extra padding for bottom bar
      physics: const BouncingScrollPhysics(),
      itemCount: _companies.length,
      itemBuilder: (context, index) {
        final company = Map<String, dynamic>.from(_companies[index] as Map);
        return _CompanyCard(
          name: company['CompanyName']?.toString() ?? 'Unknown Company',
          code: company['CompanyCode']?.toString() ?? 'N/A',
          isSelected: _selectedCompany?['CompanyID'] == company['CompanyID'],
          onTap: () => _selectCompany(company),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: SunriseTheme.cardBg,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 40,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: SunriseTheme.danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: SunriseTheme.danger,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Unable to load workspaces',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: SunriseTheme.textMain,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: SunriseTheme.textMuted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadCompanies,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SunriseTheme.btnBg,
                  foregroundColor: SunriseTheme.textMain,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Try again', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: SunriseTheme.cardBg,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 40,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: SunriseTheme.textMain.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.business_center_outlined,
                  size: 32,
                  color: SunriseTheme.textMuted,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No workspaces found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: SunriseTheme.textMain,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ask your administrator to assign a company to your account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SunriseTheme.textMuted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final canContinue = _selectedCompany != null && !_isContinuing;
    
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedCompany != null) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: SunriseTheme.textMain,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedCompany!['CompanyName']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: SunriseTheme.textMain,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: canContinue ? _handleContinue : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: SunriseTheme.btnBg,
                      disabledBackgroundColor: SunriseTheme.btnBg.withValues(alpha: 0.5),
                      foregroundColor: SunriseTheme.textMain,
                      disabledForegroundColor: SunriseTheme.textMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50), // Fully rounded pill
                      ),
                    ),
                    child: _isContinuing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(SunriseTheme.textMain),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Continue to workspace',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  final String name;
  final String code;
  final bool isSelected;
  final VoidCallback onTap;

  const _CompanyCard({
    required this.name,
    required this.code,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack, // The elastic liquid bounce physics
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.6) : SunriseTheme.cardBg.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? SunriseTheme.accent : Colors.white.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.08 : 0.02),
              blurRadius: isSelected ? 20 : 10,
              offset: Offset(0, isSelected ? 8 : 4),
            )
          ],
        ),
        child: Row(
          children: [
            // Smooth Avatar Icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: isSelected ? SunriseTheme.accent.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.domain_rounded,
                  color: isSelected ? SunriseTheme.textMain : SunriseTheme.textMuted,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Company Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 16,
                      color: SunriseTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Code: $code',
                    style: TextStyle(
                      fontSize: 13,
                      color: SunriseTheme.textMuted.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            
            // Selection Indicator
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: SunriseTheme.textMain, size: 24),
          ],
        ),
      ),
    );
  }
}