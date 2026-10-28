import 'dart:convert';

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
    this.face,
  });

  final String name;
  final String district;
  final String primaryCrop;

  /// Mobile number for logging in when the face doesn't match.
  final String? phone;

  /// Face embedding from the signup photo. Stays on this phone only - it is
  /// biometric data and is never sent to the cloud.
  final List<double>? face;
}

/// Profile from the voice setup. Saved on the phone first so setup always
/// finishes (no internet, or anonymous sign-in not enabled in Firebase), and
/// copied to `users/{uid}` (owner-only rules) whenever an account exists.
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
  static const _kFace = 'profile.face';
  static const _kLoggedIn = 'profile.loggedIn';

  /// Reuses the existing session, otherwise creates an anonymous account.
  /// Returns null when no account can be made; the app still works.
  Future<String?> ensureSignedIn() async {
    if (_auth.currentUser != null) return _auth.currentUser!.uid;
    try {
      return (await _auth.signInAnonymously()).user?.uid;
    } on FirebaseAuthException catch (e) {
      debugPrint('👤 Anonymous sign-in failed: ${e.code}');
      return null;
    }
  }

  Future<FarmerProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kName);
    if (name != null) {
      final face = prefs.getString(_kFace);
      return FarmerProfile(
        name: name,
        district: prefs.getString(_kDistrict) ?? '',
        primaryCrop: prefs.getString(_kCrop) ?? '',
        phone: prefs.getString(_kPhone),
        face: face == null
            ? null
            : (jsonDecode(face) as List)
                  .cast<num>()
                  .map((v) => v.toDouble())
                  .toList(),
      );
    }
    // Reinstalled app with a cloud copy.
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final data = (await _db.collection('users').doc(uid).get()).data();
    if (data == null || data['name'] == null) return null;
    return FarmerProfile(
      name: data['name'] as String,
      district: data['district'] as String? ?? '',
      primaryCrop: data['primaryCrop'] as String? ?? '',
    );
  }

  /// Stays logged in until the farmer logs out; profiles saved before
  /// login existed count as logged in.
  Future<bool> isLoggedIn() async =>
      (await SharedPreferences.getInstance()).getBool(_kLoggedIn) ?? true;

  /// Logout keeps the profile, so the farmer can log back in by face or
  /// phone number.
  Future<void> setLoggedIn(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_kLoggedIn, value);

  /// Forgets the farmer on this phone ("new farmer"); the cloud copy stays
  /// with the account.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait(
      [
        _kName,
        _kDistrict,
        _kCrop,
        _kPhone,
        _kFace,
        _kLoggedIn,
      ].map(prefs.remove),
    );
  }

  /// Always saves on the phone; the cloud copy is best effort.
  Future<void> save(FarmerProfile p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, p.name);
    await prefs.setString(_kDistrict, p.district);
    await prefs.setString(_kCrop, p.primaryCrop);
    if (p.phone != null) await prefs.setString(_kPhone, p.phone!);
    if (p.face != null) await prefs.setString(_kFace, jsonEncode(p.face));
    await prefs.setBool(_kLoggedIn, true);

    final uid = await ensureSignedIn();
    if (uid == null) return;
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
