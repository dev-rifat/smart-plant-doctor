import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:plant_health/core/utils/bangla_format.dart';
import 'package:plant_health/features/onboarding/data/farmer_profile_repository.dart';
import 'package:plant_health/features/onboarding/domain/bangla_answers.dart';

enum AccountProblem { phoneTaken, wrongLogin, network, tooManyTries, unknown }

class AccountException implements Exception {
  const AccountException(this.problem);

  final AccountProblem problem;

  /// What the assistant says about it.
  String get bangla => switch (problem) {
    AccountProblem.phoneTaken =>
      'এই নম্বরে আগেই অ্যাকাউন্ট খোলা আছে। লগইন করুন।',
    AccountProblem.wrongLogin => 'মোবাইল নম্বর বা পাসওয়ার্ড মেলেনি।',
    AccountProblem.network =>
      'ইন্টারনেট সংযোগ পাওয়া যাচ্ছে না। সংযোগ দেখে আবার চেষ্টা করুন।',
    AccountProblem.tooManyTries =>
      'অনেকবার চেষ্টা হয়েছে। কিছুক্ষণ পরে আবার চেষ্টা করুন।',
    AccountProblem.unknown => 'কিছু একটা সমস্যা হয়েছে। আবার চেষ্টা করুন।',
  };

  @override
  String toString() => bangla;
}

/// Any password works - a word, a few numbers, said or typed. It is
/// loosened first (spelling variants, Bangla digits, spaces) so a spoken
/// password gives the same result each time, then salted with the phone
/// number and hashed. Firebase only ever sees this hash, which also meets
/// its 6-character minimum however short the password is.
abstract final class PasswordHash {
  static String normalize(String password) => BanglaAnswers.normalize(
    BanglaFormat.asciiDigits(password),
  ).replaceAll(' ', '');

  static String of(String phone, String password) => sha256
      .convert(utf8.encode('krishisathi|$phone|${normalize(password)}'))
      .toString();
}

/// Mobile number + password accounts (Firebase email/password under a
/// phone-number address), with the profile kept on the phone so the same
/// farmer can log back in without internet.
class FarmerAccountRepository {
  FarmerAccountRepository(this._profiles, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FarmerProfileRepository _profiles;
  final FirebaseAuth _auth;

  /// Same address scheme as the earlier phone + password screens, so
  /// those accounts still log in.
  static String emailFor(String phone) => '$phone@smartkrishi.app';

  Future<void> signUp({
    required String name,
    required String phone,
    required String password,
    required String district,
  }) async {
    final hash = PasswordHash.of(phone, password);
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: emailFor(phone),
        password: hash,
      );
      unawaited(credential.user?.updateDisplayName(name).catchError((_) {}));
    } on FirebaseAuthException catch (e) {
      throw AccountException(_problem(e));
    }
    await _profiles.save(
      FarmerProfile(
        name: name,
        district: district,
        primaryCrop: 'ধান',
        phone: phone,
        passwordHash: hash,
      ),
    );
  }

  Future<FarmerProfile> logIn({
    required String phone,
    required String password,
  }) async {
    final hash = PasswordHash.of(phone, password);

    // Same farmer on this phone: checked here, works offline.
    final local = await _profiles.load();
    if (local != null && local.phone == phone && local.passwordHash != null) {
      if (local.passwordHash != hash) {
        throw const AccountException(AccountProblem.wrongLogin);
      }
      await _profiles.setLoggedIn(true);
      if (_auth.currentUser == null) {
        unawaited(_signIn(phone, hash, password).then((_) {}, onError: (_) {}));
      }
      return local;
    }

    // Another phone, or an account from the old screens: ask Firebase and
    // bring the profile from the cloud.
    final user = await _signIn(phone, hash, password);
    FarmerProfile? cloud;
    try {
      cloud = await _profiles.loadCloud();
    } catch (e) {
      debugPrint('👤 Cloud profile not loaded: $e');
    }
    final profile = FarmerProfile(
      name: cloud?.name ?? user.displayName ?? 'কৃষক',
      district: cloud?.district ?? '',
      primaryCrop: cloud?.primaryCrop ?? 'ধান',
      phone: phone,
      passwordHash: hash,
    );
    await _profiles.save(profile, toCloud: cloud == null);
    return profile;
  }

  Future<User> _signIn(String phone, String hash, String raw) async {
    try {
      return (await _auth.signInWithEmailAndPassword(
        email: emailFor(phone),
        password: hash,
      )).user!;
    } on FirebaseAuthException catch (e) {
      final problem = _problem(e);
      // Accounts made on the earlier screens used the password as typed.
      if (problem == AccountProblem.wrongLogin && raw.length >= 6) {
        try {
          return (await _auth.signInWithEmailAndPassword(
            email: emailFor(phone),
            password: raw,
          )).user!;
        } on FirebaseAuthException catch (_) {}
      }
      throw AccountException(problem);
    }
  }

  /// Keeps the profile on the phone for logging back in.
  Future<void> logOut() async {
    await _profiles.setLoggedIn(false);
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('👤 Sign-out failed: $e');
    }
  }

  static AccountProblem _problem(FirebaseAuthException e) {
    debugPrint('👤 Auth error: ${e.code}');
    return switch (e.code) {
      'email-already-in-use' => AccountProblem.phoneTaken,
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' ||
      'invalid-email' ||
      'INVALID_LOGIN_CREDENTIALS' => AccountProblem.wrongLogin,
      'network-request-failed' => AccountProblem.network,
      'too-many-requests' => AccountProblem.tooManyTries,
      _ => AccountProblem.unknown,
    };
  }
}
