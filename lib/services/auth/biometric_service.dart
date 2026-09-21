import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// A login the user has enabled biometric sign-in for.
class SavedBiometricAccount {
  final String id;
  final String username;
  final String centralDatabase; // 'SmAkountMaster' or 'SASBillingMaster'
  final String serverAddress; // normalized, e.g. http://163.61.41.109:5000

  const SavedBiometricAccount({
    required this.id,
    required this.username,
    required this.centralDatabase,
    required this.serverAddress,
  });

  bool get isAkount => centralDatabase == 'SmAkountMaster';
  String get databaseLabel => isAkount ? 'Akount' : 'Billing';

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'centralDatabase': centralDatabase,
        'serverAddress': serverAddress,
      };

  factory SavedBiometricAccount.fromJson(Map<String, dynamic> json) {
    return SavedBiometricAccount(
      id: json['id'] as String,
      username: json['username'] as String,
      centralDatabase: json['centralDatabase'] as String,
      serverAddress: json['serverAddress'] as String,
    );
  }
}

/// Result of a biometric prompt.
class BiometricResult {
  final bool success;
  final bool canceled;
  final String? message;

  const BiometricResult({
    required this.success,
    this.canceled = false,
    this.message,
  });
}

enum BiometricDeviceState { ready, notEnrolled, unsupported }

/// What this device can do right now.
class BiometricDeviceStatus {
  final BiometricDeviceState state;

  /// 'Fingerprint', 'Face', 'Fingerprint or face' or 'Biometrics'.
  final String label;

  const BiometricDeviceStatus(this.state, {this.label = 'Biometrics'});

  bool get isReady => state == BiometricDeviceState.ready;
}

class BiometricService {
  static const _kAccountsKey = 'biometric_accounts';
  static const _kPasswordPrefix = 'biometric_pw_';
  static const _kLastUsedPrefix = 'biometric_last_used_';
  static const _kOfferKey = 'biometric_offer_enabled';
  static const _kAutoPromptKey = 'biometric_auto_prompt';
  static const _kAutoAccountKey = 'biometric_auto_prompt_account';

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Stable id for a username + database + server combination.
  static String accountId({
    required String username,
    required String centralDatabase,
    required String serverAddress,
  }) {
    final raw =
        '${username.trim().toLowerCase()}|$centralDatabase|${serverAddress.trim().toLowerCase()}';
    return base64Url.encode(utf8.encode(raw));
  }

  // ── Device ───────────────────────────────────────────────────────────────

  Future<BiometricDeviceStatus> getDeviceStatus() async {
    // local_auth has no web support, and we never keep passwords in a browser.
    if (kIsWeb) return const BiometricDeviceStatus(BiometricDeviceState.unsupported);

    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!supported || !canCheck) {
        return const BiometricDeviceStatus(BiometricDeviceState.unsupported);
      }

      final types = (await _auth.getAvailableBiometrics()).map((t) => t.name).toSet();
      if (types.isEmpty) {
        return const BiometricDeviceStatus(BiometricDeviceState.notEnrolled);
      }

      final hasFace = types.contains('face');
      final hasFingerprint = types.contains('fingerprint');
      final label = hasFace && hasFingerprint
          ? 'Fingerprint or face'
          : hasFace
              ? 'Face'
              : hasFingerprint
                  ? 'Fingerprint'
                  : 'Biometrics';
      return BiometricDeviceStatus(BiometricDeviceState.ready, label: label);
    } catch (e) {
      debugPrint('Biometric device status failed: $e');
      return const BiometricDeviceStatus(BiometricDeviceState.unsupported);
    }
  }

  Future<bool> isAvailable() async => (await getDeviceStatus()).isReady;

  Future<BiometricResult> authenticate({required String reason}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return BiometricResult(success: ok, canceled: !ok);
    } on LocalAuthException catch (e) {
      switch (e.code.name) {
        case 'userCanceled':
        case 'systemCanceled':
        case 'userRequestedFallback':
          return const BiometricResult(success: false, canceled: true);
        case 'noBiometricHardware':
        case 'noBiometricsEnrolled':
        case 'noCredentialsSet':
          return const BiometricResult(
            success: false,
            message: 'Biometric authentication is not set up on this device.',
          );
        case 'temporaryLockout':
        case 'biometricLockout':
          return const BiometricResult(
            success: false,
            message: 'Too many attempts. Try again later or use your password.',
          );
        case 'timeout':
          return const BiometricResult(
            success: false,
            message: 'Authentication timed out. Please try again.',
          );
        default:
          return BiometricResult(
            success: false,
            message: e.description ?? 'Biometric authentication failed.',
          );
      }
    } catch (e) {
      debugPrint('Biometric authenticate error: $e');
      return const BiometricResult(
        success: false,
        message: 'Biometric authentication failed.',
      );
    }
  }

  // ── Accounts ─────────────────────────────────────────────────────────────

  /// Only returns accounts that still have a stored password, so a half-saved
  /// or orphaned entry never shows up as a biometric login.
  Future<List<SavedBiometricAccount>> getAccounts() async {
    try {
      final raw = await _storage.read(key: _kAccountsKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      final accounts = list
          .map((e) => SavedBiometricAccount.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      final valid = <SavedBiometricAccount>[];
      for (final a in accounts) {
        final pw = await _storage.read(key: '$_kPasswordPrefix${a.id}');
        if (pw != null && pw.isNotEmpty) valid.add(a);
      }
      if (valid.length != accounts.length) await _writeAccounts(valid);
      return valid;
    } catch (e) {
      debugPrint('Failed to read biometric accounts: $e');
      return [];
    }
  }

  Future<void> _writeAccounts(List<SavedBiometricAccount> accounts) {
    return _storage.write(
      key: _kAccountsKey,
      value: jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }

  Future<bool> hasAccount(String id) async {
    final accounts = await getAccounts();
    return accounts.any((a) => a.id == id);
  }

  /// Adds the account, or updates its stored password if it already exists.
  /// Also stamps it as used now.
  Future<void> saveAccount({
    required String username,
    required String password,
    required String centralDatabase,
    required String serverAddress,
  }) async {
    final id = accountId(
      username: username,
      centralDatabase: centralDatabase,
      serverAddress: serverAddress,
    );

    await _storage.write(key: '$_kPasswordPrefix$id', value: password);

    final accounts = await getAccounts();
    if (!accounts.any((a) => a.id == id)) {
      accounts.add(SavedBiometricAccount(
        id: id,
        username: username,
        centralDatabase: centralDatabase,
        serverAddress: serverAddress,
      ));
      await _writeAccounts(accounts);
    }

    await markUsed(id);
  }

  Future<String?> readPassword(String id) {
    return _storage.read(key: '$_kPasswordPrefix$id');
  }

  Future<void> removeAccount(String id) async {
    final accounts = await getAccounts();
    accounts.removeWhere((a) => a.id == id);
    await _writeAccounts(accounts);
    await _storage.delete(key: '$_kPasswordPrefix$id');
    await _storage.delete(key: '$_kLastUsedPrefix$id');

    if (await _storage.read(key: _kAutoAccountKey) == id) {
      await _storage.delete(key: _kAutoAccountKey);
    }
  }

  /// Removes every saved account and its stored password from this device.
  Future<void> removeAll() async {
    final accounts = await getAccounts();
    for (final a in accounts) {
      await _storage.delete(key: '$_kPasswordPrefix${a.id}');
      await _storage.delete(key: '$_kLastUsedPrefix${a.id}');
    }
    await _storage.delete(key: _kAccountsKey);
    await _storage.delete(key: _kAutoAccountKey);
  }

  // ── Last used ────────────────────────────────────────────────────────────

  Future<void> markUsed(String id) {
    return _storage.write(
      key: '$_kLastUsedPrefix$id',
      value: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<DateTime?> getLastUsed(String id) async {
    final raw = await _storage.read(key: '$_kLastUsedPrefix$id');
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  // ── Preferences ──────────────────────────────────────────────────────────

  /// Whether the dashboard should offer to enable biometric login after a
  /// password sign-in. On by default.
  Future<bool> getOfferEnabled() async {
    return (await _storage.read(key: _kOfferKey)) != 'false';
  }

  Future<void> setOfferEnabled(bool value) {
    return _storage.write(key: _kOfferKey, value: value.toString());
  }

  /// Whether the login screen starts the biometric prompt when the app opens.
  /// Off by default.
  Future<bool> getAutoPrompt() async {
    return (await _storage.read(key: _kAutoPromptKey)) == 'true';
  }

  Future<void> setAutoPrompt(bool value) {
    return _storage.write(key: _kAutoPromptKey, value: value.toString());
  }

  /// Which saved account the auto-prompt signs in to when several are saved.
  /// Null means "ask me each time" (show the account list).
  Future<String?> getAutoPromptAccountId() async {
    final id = await _storage.read(key: _kAutoAccountKey);
    return (id == null || id.isEmpty) ? null : id;
  }

  Future<void> setAutoPromptAccountId(String? id) {
    if (id == null) return _storage.delete(key: _kAutoAccountKey);
    return _storage.write(key: _kAutoAccountKey, value: id);
  }
}