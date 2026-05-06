import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _greenDark   = Color(0xFF047857);
const _greenBright = Color(0xFF05c46b);
const _greenLight  = Color(0xFF34d399);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ── CONTROLLERS ───────────────────────────────────────
  late final AnimationController _entryCtrl;  // entrada inicial (900ms)
  late final AnimationController _barsCtrl;   // barras loop (700ms)
  late final AnimationController _pulseCtrl;  // pulso del logo loop (1800ms)
  late final AnimationController _exitCtrl;   // fade-out (500ms)

  // Entrada
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<Offset>  _logoSlide;
  late final Animation<double> _textFade;
  late final Animation<Offset>  _textSlide;
  late final Animation<double> _barsFade;

  // Loop logo — pulso suave
  late final Animation<double> _logoPulse;

  // Barras — cada una animada de arriba hacia abajo con fases distintas
  // El valor representa la altura DESDE ARRIBA (1.0 = tope, 0.0 = base)
  // Usamos una secuencia: la barra "cae" de alto a bajo y sube de nuevo
  late final List<Animation<double>> _bars;

  // Salida
  late final Animation<double> _exitFade;

  // Alturas máximas de cada barra (relativas, 0..1)
  static const _maxHeights = [0.55, 1.0, 0.72, 1.0, 0.55];
  // Fases de desfase entre barras (0..1 dentro del loop)
  static const _phases     = [0.0, 0.15, 0.30, 0.45, 0.60];

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarBrightness:     Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ));

    // ── ENTRADA 900ms ────────────────────────────────────
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    _logoScale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutBack),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    ));

    _barsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    // ── BARRAS loop 700ms ────────────────────────────────
    // Cada barra va de su altura máxima a mínima (arriba→abajo) y regresa.
    // La curva easeInOut + reverse:true crea el efecto de caída y rebote.
    _barsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _bars = List.generate(5, (i) {
      final phase = _phases[i];
      final max   = _maxHeights[i];
      // Cada barra usa un Interval desfasado para que no se muevan sincronizadas
      return Tween<double>(begin: max, end: 0.18).animate(
        CurvedAnimation(
          parent: _barsCtrl,
          curve: Interval(
            phase,
            (phase + 0.6).clamp(0.0, 1.0),
            curve: Curves.easeInOut,
          ),
        ),
      );
    });

    // ── PULSO LOGO loop 1800ms ───────────────────────────
    // Crece suavemente de 1.0 a 1.06 y regresa — respira con el ritmo de las barras
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _logoPulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // ── SALIDA 500ms ─────────────────────────────────────
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInCubic),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    // 1. Entrada del logo + texto
    await _entryCtrl.forward();
    if (!mounted) return;

    // 2. Arrancan los loops: barras + pulso del logo
    _barsCtrl.repeat(reverse: true);
    _pulseCtrl.repeat(reverse: true);

    // 3. Espera — ajusta aquí la duración total visible
    await Future.delayed(const Duration(milliseconds: 8100));
    if (!mounted) return;

    // 4. Detener loops
    _barsCtrl.stop();
    _pulseCtrl.stop();

    // 5. Fade-out y main.dart toma el control del routing
    await _exitCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _barsCtrl.dispose();
    _pulseCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _exitFade,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_entryCtrl, _barsCtrl, _pulseCtrl]),
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ── LOGO CON PULSO ──────────────────────────
                  FadeTransition(
                    opacity: _logoFade,
                    child: SlideTransition(
                      position: _logoSlide,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Transform.scale(
                          // Pulso en loop sobre la escala de entrada
                          scale: _pulseCtrl.isAnimating
                              ? _logoPulse.value
                              : 1.0,
                          child: Image.asset(
                            'assets/images/LogoVibrantApp.png',
                            width: 140,
                            height: 140,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── NOMBRE ─────────────────────────────────
                  FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(
                      position: _textSlide,
                      child: const Text(
                        'Vibrant App',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF064E3B),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── BARRAS ECUALIZADOR ──────────────────────
                  // SizedBox fija la altura máxima del contenedor.
                  // Cada barra crece/decrece desde ARRIBA hacia abajo
                  // usando Align + FractionallySizedBox.
                  Opacity(
                    opacity: _barsFade.value,
                    child: SizedBox(
                      height: 32,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List.generate(5, (i) {
                          final color = i == 1 || i == 3
                              ? _greenBright
                              : i == 2
                                  ? _greenDark
                                  : _greenLight;

                          return Padding(
                            padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: FractionallySizedBox(
                                heightFactor: _bars[i].value,
                                child: Container(
                                  width: 4.5,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                ],
              );
            },
          ),
        ),
      ),
    );
  }
}