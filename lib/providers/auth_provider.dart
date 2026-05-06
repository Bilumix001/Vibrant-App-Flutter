import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

// ── ESTADO ───────────────────────────────────────────
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final bool isChecking; // verificando sesión al arrancar
  final String? error;

  const AuthState({
    this.user,
    this.isLoading  = false,
    this.isChecking = true,
    this.error,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    bool? isChecking,
    Object? error = _keep,
    bool clearUser = false,
  }) {
    return AuthState(
      user:       clearUser ? null : (user ?? this.user),
      isLoading:  isLoading  ?? this.isLoading,
      isChecking: isChecking ?? this.isChecking,
      error:      error == _keep ? this.error : error as String?,
    );
  }
}

const _keep = Object();

// ── NOTIFIER ─────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final _authService = AuthService();

  AuthNotifier() : super(const AuthState()) {
    _checkSession();
  }

  // Verifica si hay token guardado al arrancar la app
  Future<void> _checkSession() async {
    try {
      final hasSession = await _authService.hasSession();
      if (hasSession) {
        final user = await _authService.getMe();
        state = state.copyWith(user: user, isChecking: false);
      } else {
        state = state.copyWith(isChecking: false);
      }
    } catch (_) {
      await _authService.clearTokens();
      state = state.copyWith(isChecking: false);
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.login(email: email, password: password);
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> register({
    required String email,
    required String name,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.register(
        email: email, name: name, password: password,
      );
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(isChecking: false);
  }

  void clearError() => state = state.copyWith(error: null);
}

// ── PROVIDER ─────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);