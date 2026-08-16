import 'package:flutter/material.dart';
import 'package:sas_akount_login/services/auth/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sas_akount_login/features/dashboard/home_screen.dart';
import 'package:sas_akount_login/features/auth/login_screen.dart';
import 'package:sas_akount_login/services/dashboard/dashboard_service.dart';

class _Tokens {
  static const background = Color(0xFFF7F8FC);
  static const surface = Colors.white;
  static const text = Color(0xFF1D2433);
  static const mutedText = Color(0xFF7A8497);
  static const border = Color(0xFFE9ECF3);

  static const primary = Color(0xFF5B5FEF);
  static const primaryDark = Color(0xFF4549D8);
  static const primarySoft = Color(0xFFEDEEFF);

  static const sky = Color(0xFFE7F4FF);
  static const lavender = Color(0xFFF0EDFF);
  static const success = Color(0xFF24A26A);
  static const danger = Color(0xFFD94C4C);

  static const headingFont = 'Space Grotesk';
}

class CompanySelectionScreen extends StatefulWidget {
  const CompanySelectionScreen({super.key});

  @override
  State<CompanySelectionScreen> createState() =>
      _CompanySelectionScreenState();
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
        const SnackBar(
          content: Text('Unable to save your selected workspace.'),
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
    return Scaffold(
      backgroundColor: _Tokens.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildHeroSection(),
            Expanded(child: _buildContent()),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          Container(
            height: 55,
            width: 150,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _Tokens.border),
            ),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _loadCompanies,
            tooltip: 'Refresh companies',
            icon: const Icon(
              Icons.refresh_rounded,
              color: _Tokens.mutedText,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _logout,
            tooltip: 'Logout',
            icon: const Icon(
              Icons.logout_rounded,
              color: _Tokens.danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _Tokens.lavender,
            _Tokens.sky,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            top: -18,
            child: Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.38),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 42,
            bottom: -38,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: _Tokens.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      color: _Tokens.primary,
                      size: 15,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'WORKSPACES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: _Tokens.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Choose where\nyou want to work.',
                style: TextStyle(
                  fontFamily: _Tokens.headingFont,
                  fontSize: 28,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  color: _Tokens.text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isLoading
                    ? 'Loading your available companies...'
                    : '${_companies.length} workspace${_companies.length == 1 ? '' : 's'} available for you',
                style: const TextStyle(
                  fontSize: 13,
                  color: _Tokens.mutedText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _companies.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: _Tokens.primary,
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      physics: const BouncingScrollPhysics(),
      itemCount: _companies.length,
      itemBuilder: (context, index) {
        final company = Map<String, dynamic>.from(_companies[index] as Map);

        return _CompanyCard(
          index: index,
          name: company['CompanyName']?.toString() ?? 'Unknown Company',
          code: company['CompanyCode']?.toString() ?? 'N/A',
          isSelected:
              _selectedCompany?['CompanyID'] == company['CompanyID'],
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
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _Tokens.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _Tokens.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEEEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: _Tokens.danger,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Unable to load workspaces',
                style: TextStyle(
                  fontFamily: _Tokens.headingFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: _Tokens.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _Tokens.mutedText,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _loadCompanies,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _Tokens.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _Tokens.border),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.business_center_outlined,
              size: 38,
              color: _Tokens.mutedText,
            ),
            SizedBox(height: 14),
            Text(
              'No workspaces found',
              style: TextStyle(
                fontFamily: _Tokens.headingFont,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _Tokens.text,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'Ask your administrator to assign a company to your account.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _Tokens.mutedText,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final canContinue = _selectedCompany != null && !_isContinuing;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        border: const Border(
          top: BorderSide(color: _Tokens.border),
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
                    size: 17,
                    color: _Tokens.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedCompany!['CompanyName']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _Tokens.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: canContinue ? _handleContinue : null,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _Tokens.primary,
                  disabledBackgroundColor: _Tokens.primarySoft,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: _Tokens.mutedText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isContinuing
                    ? const SizedBox(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue to workspace',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  final int index;
  final String name;
  final String code;
  final bool isSelected;
  final VoidCallback onTap;

  const _CompanyCard({
    required this.index,
    required this.name,
    required this.code,
    required this.isSelected,
    required this.onTap,
  });

  Color get _iconColor {
    const colors = [
      Color(0xFF5B5FEF),
      Color(0xFF159C73),
      Color(0xFFE87845),
      Color(0xFF9A5FE8),
      Color(0xFF1685C7),
    ];

    return colors[index % colors.length];
  }

  Color get _iconBackground {
    const colors = [
      Color(0xFFEDEEFF),
      Color(0xFFE6F7F0),
      Color(0xFFFFEEE7),
      Color(0xFFF2EAFF),
      Color(0xFFE6F4FD),
    ];

    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _Tokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? _Tokens.primary : _Tokens.border,
          width: isSelected ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? _Tokens.primary.withValues(alpha: 0.14)
                : Colors.black.withValues(alpha: 0.025),
            blurRadius: isSelected ? 18 : 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isSelected ? _Tokens.primarySoft : _iconBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.domain_rounded,
                    color: isSelected ? _Tokens.primary : _iconColor,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: _Tokens.headingFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                          color: _Tokens.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Company code  Ã‚Â·  $code',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _Tokens.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: isSelected ? _Tokens.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? _Tokens.primary : _Tokens.border,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

