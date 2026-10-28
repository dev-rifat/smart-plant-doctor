import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FarmerProfile {
  const FarmerProfile({
    required this.name,
    required this.district,
    required this.primaryCrop,
    this.phone,
    this.passwordHash,
  });

  final String name;
  final String district;
  final String primaryCrop;

  /// The login id: an 11-digit Bangladeshi mobile number.
  final String? phone;

  /// Salted SHA-256 of the password ([PasswordHash]), so this phone can
  /// check a login without internet. Never the password itself; never
  /// sent to the cloud.
  final String? passwordHash;
}

/// The farmer's profile: kept on the phone (works offline) and copied to
/// `users/{uid}` (owner-only rules) for the signed-in Firebase account, so
/// logging in on another phone brings it back.
class FarmerProfileRepository {
  FarmerProfileRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  static const _kName = 'profile.name';
  static const _kDistrict = 'profile.district';
  static const _kCrop = 'profile.primaryCrop';
  static const _kPhone = 'profile.phone';
  static const _kPasswordHash = 'profile.passwordHash';
  static const _kLoggedIn = 'profile.loggedIn';

  /// The profile on this phone, or null.
  Future<FarmerProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kName);
    if (name == null) return null;
    return FarmerProfile(
      name: name,
      district: prefs.getString(_kDistrict) ?? '',
      primaryCrop: prefs.getString(_kCrop) ?? '',
      phone: prefs.getString(_kPhone),
      passwordHash: prefs.getString(_kPasswordHash),
    );
  }

  /// The cloud copy for the signed-in account (login on a new phone).
  Future<FarmerProfile?> loadCloud() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    // Bounded: an unreachable or disabled Firestore must not hold up login.
    final data =
        (await _db
                .collection('users')
                .doc(uid)
                .get()
                .timeout(const Duration(seconds: 6)))
            .data();
    if (data == null || data['name'] == null) return null;
    return FarmerProfile(
      name: data['name'] as String,
      district: data['district'] as String? ?? '',
      primaryCrop: data['primaryCrop'] as String? ?? 'ধান',
    );
  }

  /// Stays logged in until the farmer logs out; profiles saved before
  /// login existed count as logged in.
  Future<bool> isLoggedIn() async =>
      (await SharedPreferences.getInstance()).getBool(_kLoggedIn) ?? true;

  /// Logout keeps the profile, so the same farmer can log back in offline.
  Future<void> setLoggedIn(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_kLoggedIn, value);

  /// Forgets the farmer on this phone; the account and cloud copy stay.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait(
      [
        _kName,
        _kDistrict,
        _kCrop,
        _kPhone,
        _kPasswordHash,
        _kLoggedIn,
      ].map(prefs.remove),
    );
  }

  /// Saves on the phone and marks the farmer logged in; [toCloud] also
  /// copies it to the signed-in account in the background (best effort:
  /// Firestore waits for the server, which may be offline or disabled).
  Future<void> save(FarmerProfile p, {bool toCloud = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, p.name);
    await prefs.setString(_kDistrict, p.district);
    await prefs.setString(_kCrop, p.primaryCrop);
    if (p.phone != null) await prefs.setString(_kPhone, p.phone!);
    if (p.passwordHash != null) {
      await prefs.setString(_kPasswordHash, p.passwordHash!);
    }
    await prefs.setBool(_kLoggedIn, true);

    final uid = _auth.currentUser?.uid;
    if (!toCloud || uid == null) return;
    unawaited(_saveCloud(uid, p));
  }

  Future<void> _saveCloud(String uid, FarmerProfile p) async {
    try {
      await _db.collection('users').doc(uid).set({
        'name': p.name,
        'district': p.district,
        'primaryCrop': p.primaryCrop,
        'language': 'bn',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('👤 Cloud profile save failed (kept on phone): $e');
    }
  }
}
