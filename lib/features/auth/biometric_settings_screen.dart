import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sas_app/services/auth/biometric_service.dart';
import 'package:sas_app/core/services/toast_service.dart';

/// Post-login screen to review and manage biometric login on this device.
/// Accounts can only be ADDED from the "Enable biometric login?" sheet on the
/// dashboard, because that needs the password.
class BiometricSettingsScreen extends StatefulWidget {
  const BiometricSettingsScreen({super.key});

  @override
  State<BiometricSettingsScreen> createState() => _BiometricSettingsScreenState();
}

class _BiometricSettingsScreenState extends State<BiometricSettingsScreen> {
  static const Color _bg = Color(0xFFF9FAFB);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _body = Color(0xFF334155);
  static const Color _muted = Color(0xFF8A8F9A);
  static const Color _border = Color(0xFFE7E9ED);
  static const Color _accent = Color(0xFF4F46E5);
  static const Color _accentBg = Color(0xFFEEF0FE);
  static const Color _danger = Color(0xFFE11D48);
  static const Color _success = Color(0xFF059669);
  static const Color _warning = Color(0xFFD97706);

  static const String _askEachTime = '__ask__';

  final BiometricService _bio = BiometricService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _loading = true;
  bool _busy = false;

  BiometricDeviceStatus? _device;
  List<SavedBiometricAccount> _accounts = [];
  Map<String, DateTime?> _lastUsed = {};
  String? _currentId;

  bool _offerEnabled = true;
  bool _autoPrompt = false;
  String? _autoPromptId; // null = ask each time

  final Set<String> _removing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final device = await _bio.getDeviceStatus();
    final accounts = await _bio.getAccounts();
    final offer = await _bio.getOfferEnabled();
    final auto = await _bio.getAutoPrompt();

    var autoId = await _bio.getAutoPromptAccountId();
    if (autoId != null && !accounts.any((a) => a.id == autoId)) autoId = null;

    final lastUsed = <String, DateTime?>{};
    for (final a in accounts) {
      lastUsed[a.id] = await _bio.getLastUsed(a.id);
    }

    String? currentId;
    try {
      final username = await _storage.read(key: 'current_username');
      final server = await _storage.read(key: 'active_server_address');
      final central = await _storage.read(key: 'saved_central_db');
      if (username != null && username.isNotEmpty && server != null && server.isNotEmpty) {
        currentId = BiometricService.accountId(
          username: username,
          centralDatabase: central == 'true' ? 'SmAkountMaster' : 'SASBillingMaster',
          serverAddress: server,
        );
      }
    } catch (_) {
      // Tag is cosmetic; ignore storage errors.
    }

    if (!mounted) return;
    setState(() {
      _device = device;
      _accounts = accounts;
      _lastUsed = lastUsed;
      _currentId = currentId;
      _offerEnabled = offer;
      _autoPrompt = auto;
      _autoPromptId = autoId;
      _loading = false;
    });
  }

  // ── Preferences ──────────────────────────────────────────────────────────

  Future<void> _setOffer(bool value) async {
    HapticFeedback.selectionClick();
    setState(() => _offerEnabled = value);
    await _bio.setOfferEnabled(value);
  }

  Future<void> _setAutoPrompt(bool value) async {
    HapticFeedback.selectionClick();
    setState(() => _autoPrompt = value);
    await _bio.setAutoPrompt(value);
  }

  String _accountLabel(String id) {
    for (final a in _accounts) {
      if (a.id == id) return '${a.username} (${a.databaseLabel})';
    }
    return 'Ask me each time';
  }

  Future<void> _chooseAutoAccount() async {
    if (_accounts.length < 2) return;
    HapticFeedback.selectionClick();

    final result = await showModalBottomSheet<String>(
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
      builder: (ctx) => _buildAccountChooser(ctx),
    );

    if (result == null || !mounted) return;
    final id = result == _askEachTime ? null : result;
    setState(() => _autoPromptId = id);
    await _bio.setAutoPromptAccountId(id);
  }

  Widget _buildAccountChooser(BuildContext ctx) {
    final bottomInset = MediaQuery.of(ctx).padding.bottom;
    final maxListHeight = MediaQuery.of(ctx).size.height * 0.45;
    final selected = _autoPromptId ?? _askEachTime;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const Text(
            'Account to auto-prompt',
            style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose which account the app signs in to when it opens.',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxListHeight),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final a in _accounts)
                  _optionTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: _accentBg,
                      child: Text(
                        a.username.isNotEmpty ? a.username[0].toUpperCase() : '?',
                        style: const TextStyle(color: _accent, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    title: a.username,
                    subtitle: '${a.databaseLabel}  \u2022  ${a.serverAddress.replaceFirst(RegExp(r'^https?://'), '')}',
                    selected: selected == a.id,
                    onTap: () => Navigator.pop(ctx, a.id),
                  ),
                _optionTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: _accentBg, shape: BoxShape.circle),
                    child: const Icon(Icons.people_outline_rounded, color: _accent, size: 20),
                  ),
                  title: 'Ask me each time',
                  subtitle: 'Show the list of saved accounts',
                  selected: selected == _askEachTime,
                  onTap: () => Navigator.pop(ctx, _askEachTime),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionTile({
    required Widget leading,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? _accentBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? _accent.withValues(alpha: 0.5) : _border,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _ink, fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: selected ? _accent : _muted.withValues(alpha: 0.5),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Removal ──────────────────────────────────────────────────────────────

  Future<bool> _authenticate(String reason) async {
    final result = await _bio.authenticate(reason: reason);
    if (!mounted) return false;
    if (!result.success) {
      if (!result.canceled) {
        ToastService.showError(context, result.message ?? 'Authentication failed.');
      }
      return false;
    }
    return true;
  }

  Future<void> _removeOne(SavedBiometricAccount account) async {
    if (_busy) return;

    final confirmed = await _confirmSheet(
      title: 'Remove biometric login?',
      message: 'Fingerprint sign-in for ${account.username} (${account.databaseLabel}) '
          'will be removed from this device. You can enable it again the next time '
          'you sign in with your password.',
      confirmLabel: 'Remove',
    );
    if (confirmed != true || !mounted) return;
    if (!await _authenticate('Confirm to remove ${account.username}')) return;

    setState(() => _busy = true);
    await _bio.removeAccount(account.id);
    if (!mounted) return;

    setState(() => _removing.add(account.id));
    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;

    setState(() {
      _accounts = _accounts.where((a) => a.id != account.id).toList();
      _lastUsed.remove(account.id);
      if (_autoPromptId == account.id) _autoPromptId = null;
      _removing.remove(account.id);
      _busy = false;
    });
    ToastService.showSuccess(context, 'Biometric login removed');
  }

  Future<void> _removeAll() async {
    if (_busy || _accounts.isEmpty) return;

    final confirmed = await _confirmSheet(
      title: 'Remove all accounts?',
      message: 'Biometric sign-in will be removed for all ${_accounts.length} accounts on '
          'this device. You will need your password to sign in until you enable it again.',
      confirmLabel: 'Remove all',
    );
    if (confirmed != true || !mounted) return;
    if (!await _authenticate('Confirm to remove all biometric accounts')) return;

    setState(() => _busy = true);
    await _bio.removeAll();
    if (!mounted) return;

    setState(() => _removing.addAll(_accounts.map((a) => a.id)));
    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;

    setState(() {
      _accounts = [];
      _lastUsed = {};
      _autoPromptId = null;
      _removing.clear();
      _busy = false;
    });
    ToastService.showSuccess(context, 'All biometric logins removed');
  }

  Future<bool?> _confirmSheet({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    HapticFeedback.selectionClick();

    return showModalBottomSheet<bool>(
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
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).padding.bottom;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(24, 10, 24, 20 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _danger.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: _danger, size: 30),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _ink, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 14, height: 1.45),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _danger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  ),
                  child: Text(confirmLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: _muted, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _lastUsedText(DateTime? t) {
    if (t == null) return 'Not used yet';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Last used just now';
    if (d.inMinutes < 60) return 'Last used ${d.inMinutes} min ago';
    if (d.inHours < 24) return 'Last used ${d.inHours} h ago';
    if (d.inDays == 1) return 'Last used yesterday';
    if (d.inDays < 30) return 'Last used ${d.inDays} days ago';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return 'Last used ${t.day} ${months[t.month - 1]} ${t.year}';
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 0.8),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _ink),
        title: const Text(
          'Biometric login',
          style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _accentBg, height: 1),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: _accent))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(18, 18, 18, 32 + bottomSafe),
      children: [
        _buildStatusCard(),
        const SizedBox(height: 22),
        _sectionLabel('PREFERENCES'),
        const SizedBox(height: 10),
        _buildPreferencesCard(),
        const SizedBox(height: 22),
        _sectionLabel('SAVED ACCOUNTS'),
        const SizedBox(height: 10),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.passthrough,
              alignment: Alignment.topCenter,
              children: [...previous, if (current != null) current],
            ),
            child: _accounts.isEmpty ? _buildEmptyAccounts() : _buildAccountsList(),
          ),
        ),
        const SizedBox(height: 22),
        _sectionLabel('SECURITY TIPS'),
        const SizedBox(height: 10),
        _buildTipsCard(),
      ],
    );
  }

  Widget _buildStatusCard() {
    final device = _device;

    late final Color tone;
    late final IconData icon;
    late final String title;
    late final String text;

    switch (device?.state) {
      case BiometricDeviceState.ready:
        tone = _success;
        icon = Icons.check_circle_rounded;
        title = '${device!.label} is ready';
        text = 'This device supports it and has it set up, so biometric login can be used here.';
        break;
      case BiometricDeviceState.notEnrolled:
        tone = _warning;
        icon = Icons.info_outline_rounded;
        title = 'Nothing set up on this device';
        text = 'Add a fingerprint or face in your phone\'s Settings, then come back. '
            'Biometric login stays hidden until then.';
        break;
      case BiometricDeviceState.unsupported:
      case null:
        tone = _muted;
        icon = Icons.block_rounded;
        title = 'Not available on this device';
        text = 'This device or platform does not support biometric sign-in, so saved '
            'accounts cannot be used here.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: tone.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, color: tone, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(text, style: const TextStyle(color: _body, fontSize: 13, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard() {
    final hasAccounts = _accounts.isNotEmpty;
    final showChooser = _autoPrompt && _accounts.length > 1;

    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _switchRow(
            icon: Icons.notifications_active_outlined,
            title: 'Offer after sign-in',
            subtitle: 'Ask to enable biometric login on the dashboard after you sign in with a password.',
            value: _offerEnabled,
            onChanged: _setOffer,
          ),
          const Divider(height: 1, color: _border),
          _switchRow(
            icon: Icons.bolt_rounded,
            title: 'Auto-prompt on app open',
            subtitle: hasAccounts
                ? 'Start biometric sign-in as soon as the app opens.'
                : 'Enable biometric login for an account first.',
            value: _autoPrompt && hasAccounts,
            onChanged: hasAccounts ? _setAutoPrompt : null,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: showChooser
                ? Column(
                    children: [
                      const Divider(height: 1, color: _border),
                      _chooserRow(),
                    ],
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Opacity(
      opacity: onChanged == null ? 0.55 : 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: _accentBg, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: _accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: _ink, fontSize: 14.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: _accent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chooserRow() {
    final label = _autoPromptId == null ? 'Ask me each time' : _accountLabel(_autoPromptId!);

    return InkWell(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      onTap: _chooseAutoAccount,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: _accentBg, borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.person_outline_rounded, color: _accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account to use',
                    style: TextStyle(color: _ink, fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _accent, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyAccounts() {
    return Container(
      key: const ValueKey('empty'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(color: _accentBg, shape: BoxShape.circle),
            child: const Icon(Icons.fingerprint_rounded, color: _accent, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'No saved accounts',
            style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'When you sign in with your password you will be offered biometric login. '
            'Accounts you enable will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 13, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsList() {
    return Column(
      key: const ValueKey('accounts'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _accounts.length; i++) _buildAnimatedTile(_accounts[i], i),
        if (_accounts.length > 1) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _removeAll,
              style: OutlinedButton.styleFrom(
                foregroundColor: _danger,
                side: BorderSide(color: _danger.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.delete_sweep_outlined, size: 20),
              label: const Text(
                'Remove all accounts',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// One value drives both animations: 0 -> 1 on first show (fade + slide in,
  /// staggered by index), 1 -> 0 when the account is removed (fade + collapse).
  Widget _buildAnimatedTile(SavedBiometricAccount account, int index) {
    final removing = _removing.contains(account.id);

    return TweenAnimationBuilder<double>(
      key: ValueKey(account.id),
      tween: Tween<double>(begin: 0.0, end: removing ? 0.0 : 1.0),
      duration: Duration(milliseconds: removing ? 300 : 320 + index * 70),
      curve: removing ? Curves.easeInCubic : Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: v.clamp(0.0, 1.0),
            child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
          ),
        ),
      ),
      child: _buildTile(account),
    );
  }

  Widget _buildTile(SavedBiometricAccount account) {
    final isCurrent = account.id == _currentId;
    final server = account.serverAddress.replaceFirst(RegExp(r'^https?://'), '');
    final initial = account.username.isNotEmpty ? account.username[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _accentBg,
            child: Text(
              initial,
              style: const TextStyle(color: _accent, fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        account.username,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Signed in now',
                          style: TextStyle(color: _success, fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${account.databaseLabel}  \u2022  $server',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12.5),
                ),
                const SizedBox(height: 2),
                Text(
                  _lastUsedText(_lastUsed[account.id]),
                  style: const TextStyle(color: _muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline_rounded, color: _danger, size: 22),
            onPressed: _busy ? null : () => _removeOne(account),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    Widget tip(IconData icon, String text) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 17, color: _accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: const TextStyle(color: _body, fontSize: 13, height: 1.45)),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          tip(
            Icons.lock_outline_rounded,
            'Passwords stay encrypted on this device and are unlocked with your fingerprint or face.',
          ),
          tip(
            Icons.phone_android_rounded,
            'Don\'t enable this on a shared phone. Anyone whose fingerprint or face is enrolled on it can sign in.',
          ),
          tip(
            Icons.sync_rounded,
            'If you change your password, sign in with it once to update the saved copy.',
          ),
        ],
      ),
    );
  }
}