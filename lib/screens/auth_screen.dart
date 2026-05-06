import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

// ── PALETA ────────────────────────────────────────────
const _greenDark   = Color(0xFF047857);
const _greenMid    = Color(0xFF16a34a);
const _greenBright = Color(0xFF05c46b);
const _greenLight  = Color(0xFF34d399);

// Colores dinámicos según tema
Color _bg(bool d)          => d ? const Color(0xFF0A0A0A) : const Color(0xFFF5FFF9);
Color _surface(bool d)     => d ? const Color(0xFF141414) : Colors.white;
Color _fieldFill(bool d)   => d ? const Color(0xFF1E1E1E) : const Color(0xFFF0FDF4);
Color _textMain(bool d)    => d ? Colors.white             : const Color(0xFF064E3B);
Color _textSub(bool d)     => d ? Colors.white54           : Colors.black45;
Color _labelColor(bool d)  => d ? Colors.white38           : Colors.black38;
Color _borderColor(bool d) => d
    ? _greenDark.withValues(alpha: 0.3)
    : _greenDark.withValues(alpha: 0.2);

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLogin = true;

  final _emailCtrl    = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure       = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notifier = ref.read(authProvider.notifier);
    if (_isLogin) {
      await notifier.login(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    } else {
      await notifier.register(
        email:    _emailCtrl.text.trim(),
        name:     _nameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDark    = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: _bg(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: () =>
                  ref.read(themeProvider.notifier).state = !isDark,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: 50, height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: isDark
                      ? _greenDark.withValues(alpha: 0.4)
                      : _greenMid.withValues(alpha: 0.15),
                  border: Border.all(
                    color: isDark
                        ? _greenBright.withValues(alpha: 0.5)
                        : _greenDark.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment: isDark
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [_greenDark, _greenBright]
                            : [_greenLight, _greenMid],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      size: 12, color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // ── LOGO ─────────────────────────────────────
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_greenDark, _greenBright],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _greenBright.withValues(alpha: 0.4),
                        blurRadius: 20, spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.chat_bubble_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 20),

                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [_greenLight, _greenBright],
                  ).createShader(b),
                  child: const Text(
                    'Vibrant App',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  _isLogin
                      ? 'Inicia sesión para continuar'
                      : 'Crea tu cuenta',
                  style: TextStyle(
                    color: _textSub(isDark),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 36),

                // ── FORMULARIO ────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _surface(isDark),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _borderColor(isDark),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [

                      if (!_isLogin) ...[
                        _Field(
                          controller: _nameCtrl,
                          label:      'Nombre',
                          icon:       Icons.person_outline,
                          isDark:     isDark,
                        ),
                        const SizedBox(height: 14),
                      ],

                      _Field(
                        controller:   _emailCtrl,
                        label:        'Correo electrónico',
                        icon:         Icons.email_outlined,
                        isDark:       isDark,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),

                      _Field(
                        controller: _passwordCtrl,
                        label:      'Contraseña',
                        icon:       Icons.lock_outline,
                        isDark:     isDark,
                        obscure:    _obscure,
                        suffix: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: _textSub(isDark), size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),

                      // Error
                      if (authState.error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.red.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.redAccent, size: 15),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authState.error!,
                                  style: TextStyle(
                                    color: _textMain(isDark)
                                        .withValues(alpha: 0.8),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 22),

                      // Botón submit
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_greenDark, _greenMid],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: _greenBright.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: authState.isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor:     Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: authState.isLoading
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isLogin
                                        ? 'Iniciar sesión'
                                        : 'Registrarse',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Toggle login/register
                GestureDetector(
                  onTap: () {
                    ref.read(authProvider.notifier).clearError();
                    setState(() => _isLogin = !_isLogin);
                  },
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 14),
                      children: [
                        TextSpan(
                          text: _isLogin
                              ? '¿No tienes cuenta? '
                              : '¿Ya tienes cuenta? ',
                          style: TextStyle(color: _textSub(isDark)),
                        ),
                        TextSpan(
                          text: _isLogin ? 'Regístrate' : 'Inicia sesión',
                          style: const TextStyle(
                            color: _greenLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── CAMPO DE TEXTO ────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isDark;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    required this.isDark,
    this.obscure      = false,
    this.suffix,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller:   controller,
      obscureText:  obscure,
      keyboardType: keyboardType,
      style: TextStyle(color: _textMain(isDark), fontSize: 14),
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: TextStyle(color: _labelColor(isDark), fontSize: 13),
        prefixIcon: Icon(icon, color: _greenLight, size: 18),
        suffixIcon: suffix,
        filled:     true,
        fillColor:  _fieldFill(isDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: _greenDark.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
      ),
    );
  }
}