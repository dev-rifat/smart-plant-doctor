import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/features/auth/data/services/firebase_auth_service.dart';
import 'package:plant_health/features/auth/presentation/cubit/auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({required FirebaseAuthService authService})
    : _authService = authService,
      super(const AuthInitial());

  final FirebaseAuthService _authService;

  Future<void> login({
    required String phoneNumber,
    required String password,
  }) async {
    emit(const AuthLoading());

    try {
      await _authService.loginWithPhonePassword(
        phoneNumber: phoneNumber,
        password: password,
      );
      emit(const AuthSuccess());
    } on FirebaseAuthException catch (e) {
      emit(AuthFailure(_mapAuthError(e)));
    } catch (_) {
      emit(const AuthFailure('Login failed. Please try again.'));
    }
  }

  Future<void> signup({
    required String userName,
    required String phoneNumber,
    required String password,
  }) async {
    emit(const AuthLoading());

    try {
      await _authService.signUpWithPhonePassword(
        userName: userName,
        phoneNumber: phoneNumber,
        password: password,
      );
      emit(const AuthSuccess());
    } on FirebaseAuthException catch (e) {
      emit(AuthFailure(_mapAuthError(e)));
    } catch (_) {
      emit(const AuthFailure('Signup failed. Please try again.'));
    }
  }

  Future<void> logout() async {
    emit(const AuthLoading());

    try {
      await _authService.logout();
      emit(const AuthLoggedOut());
    } catch (_) {
      emit(const AuthFailure('Logout failed. Please try again.'));
    }
  }

  void reset() => emit(const AuthInitial());

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Phone number is already registered.';
      case 'invalid-email':
        return 'Invalid phone number.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid phone number or password.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}
