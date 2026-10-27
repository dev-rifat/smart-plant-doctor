import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FarmerProfile {
  const FarmerProfile({
    required this.name,
    required this.district,
    required this.primaryCrop,
  });

  final String name;
  final String district;
  final String primaryCrop;
}

/// Account + profile for the voice setup: no password, the farmer is signed
/// in anonymously and the profile lives at `users/{uid}` (owner-only rules
/// in firestore.rules). A phone number can be linked later for recovery.
class FarmerProfileRepository {
  FarmerProfileRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// Reuses the existing session, otherwise creates an anonymous account.
  Future<String> ensureSignedIn() async {
    final user = _auth.currentUser ?? (await _auth.signInAnonymously()).user;
    return user!.uid;
  }

  Future<FarmerProfile?> load() async {
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

  Future<void> save(FarmerProfile p) async {
    final uid = await ensureSignedIn();
    await _db.collection('users').doc(uid).set({
      'name': p.name,
      'district': p.district,
      'primaryCrop': p.primaryCrop,
      'language': 'bn',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
