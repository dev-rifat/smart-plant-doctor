import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  FirebaseAuthService(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  User? get currentUser => _firebaseAuth.currentUser;

  /// Accounts are keyed by phone via a synthetic email, so the phone the
  /// user signed up with can be recovered without storing it separately.
  String? get currentUserPhone {
    final email = currentUser?.email;
    if (email == null || !email.endsWith('@smartkrishi.app')) return null;
    return email.split('@').first;
  }

  Future<UserCredential> signUpWithPhonePassword({
    required String userName,
    required String phoneNumber,
    required String password,
  }) async {
    final email = _phoneToEmail(phoneNumber);
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (credential.user != null && userName.trim().isNotEmpty) {
      await credential.user!.updateDisplayName(userName.trim());
      await credential.user!.reload();
    }

    return credential;
  }

  Future<UserCredential> loginWithPhonePassword({
    required String phoneNumber,
    required String password,
  }) {
    final email = _phoneToEmail(phoneNumber);
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> logout() {
    return _firebaseAuth.signOut();
  }

  String _phoneToEmail(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return '$digits@smartkrishi.app';
  }
}
