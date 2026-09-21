import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sas_app/services/auth/biometric_service.dart';
import 'package:sas_app/core/services/toast_service.dart';

class _PendingEnrollment {
  final String username;
  final String password;
  final String centralDatabase;
  final String serverAddress;

  const _PendingEnrollment({
    required this.username,
    required this.password,
    required this.centralDatabase,
    required this.serverAddress,
  });
}

/// Carries a just-completed login from the login screen to the dashboard so
/// the "Enable biometric login?" prompt can appear after the company is chosen.
///
/// The password only lives in memory, is consumed on the first prompt, and is
/// wiped by [clear] (call it on logout too).
class BiometricEnrollment {
  BiometricEnrollment._();

  static _PendingEnrollment? _pending;
  static bool _prompting = false;

  static bool get hasPending => _pending != null;

  static void stage({
    required String username,
    required String password,
    required String centralDatabase,
    required String serverAddress,
  }) {
    _pending = _PendingEnrollment(
      username: username,
      password: password,
      centralDatabase: centralDatabase,
      serverAddress: serverAddress,
    );
  }

  static void clear() => _pending = null;

  /// Call from the dashboard's first frame. Does nothing if nothing is staged.
  static Future<void> promptIfPending(BuildContext context) async {
    final pending = _pending;
    if (pending == null || _prompting) return;

    _prompting = true;
    _pending = null; // ask once per login, whatever the answer is

    try {
      final bio = BiometricService();
      if (!await bio.isAvailable()) return;
      if (!await bio.getOfferEnabled()) return;

      // Let the dashboard finish its entrance before the sheet slides up.
      await Future.delayed(const Duration(milliseconds: 600));
      if (!context.mounted) return;

      final enable = await _askEnable(context, pending.username);
      if (enable != true || !context.mounted) return;

      final result = await bio.authenticate(reason: 'Confirm to enable biometric login');
      if (!context.mounted) return;

      if (!result.success) {
        if (!result.canceled) {
          ToastService.showError(context, result.message ?? 'Could not enable biometric login.');
        }
        return;
      }

      await bio.saveAccount(
        username: pending.username,
        password: pending.password,
        centralDatabase: pending.centralDatabase,
        serverAddress: pending.serverAddress,
      );
      if (!context.mounted) return;
      ToastService.showSuccess(context, 'Biometric login enabled');
    } catch (e) {
      debugPrint('Biometric enrollment error: $e');
    } finally {
      _prompting = false;
    }
  }

  static Future<bool?> _askEnable(BuildContext context, String username) {
    const cardBg = Color(0xFFF9F5EC);
    const btnBg = Color(0xFFE3DCC8);
    const accent = Color(0xFF9BBDE2);
    const textMain = Color(0xFF1A1B1C);
    const textMuted = Color(0xFF6B6A66);

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
            color: cardBg,
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
                  decoration: BoxDecoration(
                    color: textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.fingerprint_rounded, color: textMain, size: 36),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Enable biometric login?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textMain,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in as $username next time with your fingerprint or face. '
                'Your password is stored securely on this device.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: textMuted, fontSize: 14, height: 1.45),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnBg,
                    foregroundColor: textMain,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  ),
                  child: const Text(
                    'Enable',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Not now',
                  style: TextStyle(color: textMuted, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}