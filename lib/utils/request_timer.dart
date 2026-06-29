// ════════════════════════════════════════════════════════
// ARCHIVO NUEVO: lib/utils/request_timer.dart
// Crea la carpeta "utils" dentro de "lib" si no existe.
// ════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

/// Cronómetro centralizado para medir cada etapa de una operación.
///
/// Ejemplo:
/// ```dart
/// final timer = RequestTimer('modo_conversacional');
/// timer.mark('grabacion_audio');
/// ... grabar ...
/// timer.mark('subida_stt');
/// ... transcribir ...
/// timer.mark('chat_primer_chunk');
/// ... primer chunk del chat ...
/// timer.mark('tts_primer_chunk');
/// ... primer chunk de audio ...
/// timer.done();
/// ```
class RequestTimer {
  final String name;
  final _start = DateTime.now();
  DateTime _last = DateTime.now();
  final List<(String, int)> _marks = [];

  RequestTimer(this.name) {
    _last = _start;
  }

  /// Registra una etapa. Devuelve los ms desde el mark anterior.
  int mark(String label) {
    final now     = DateTime.now();
    final elapsed = now.difference(_last).inMilliseconds;
    final total   = now.difference(_start).inMilliseconds;
    _marks.add((label, elapsed));
    _last = now;
    debugPrint('  [⏱ $name] $label: ${elapsed}ms  (total: ${total}ms)');
    return elapsed;
  }

  /// Imprime el resumen completo y devuelve el tiempo total en ms.
  int done() {
    final total = DateTime.now().difference(_start).inMilliseconds;
    final sep   = '─' * 55;

    final buf = StringBuffer();
    buf.writeln('\n$sep');
    buf.writeln('  📊 RESUMEN [$name]  TOTAL: ${total}ms');
    buf.writeln(sep);

    for (final (label, ms) in _marks) {
      final pct = total > 0 ? (ms / total * 100).round() : 0;
      final bar = '█' * (ms ~/ 100).clamp(0, 30);
      buf.writeln(
        '  ${label.padRight(30)} ${ms.toString().padLeft(6)}ms  '
        '${pct.toString().padLeft(4)}%  $bar',
      );
    }
    buf.writeln(sep);
    debugPrint(buf.toString());
    return total;
  }
}