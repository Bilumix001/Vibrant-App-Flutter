// lib/features/conversational/message_audio_button.dart

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/tts_service.dart';

const _greenBright = Color(0xFF05c46b);
const _greenDark   = Color(0xFF047857);

/// Botón de reproducción de audio para un mensaje individual.
/// Se instancia con el texto del mensaje; maneja su propio AudioPlayer.
class MessageAudioButton extends StatefulWidget {
  final String text;
  final bool isDark;

  const MessageAudioButton({
    super.key,
    required this.text,
    required this.isDark,
  });

  @override
  State<MessageAudioButton> createState() => _MessageAudioButtonState();
}

class _MessageAudioButtonState extends State<MessageAudioButton> {
  final _ttsService  = TtsService();
  final _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final path = await _ttsService.getAudioPath(widget.text);
      await _audioPlayer.setFilePath(path);
      setState(() {
        _isLoading = false;
        _isPlaying = true;
      });
      await _audioPlayer.play();
      // Escucha el fin de la reproducción
      await _audioPlayer.playerStateStream.firstWhere(
        (s) =>
            s.processingState == ProcessingState.completed ||
            s.processingState == ProcessingState.idle,
      );
    } catch (e) {
      debugPrint('MessageAudioButton error: $e');
    } finally {
      if (mounted) setState(() {
        _isPlaying = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isPlaying
              ? _greenBright.withValues(alpha: 0.18)
              : Colors.transparent,
          border: Border.all(
            color: _isPlaying
                ? _greenBright
                : (widget.isDark
                    ? Colors.white24
                    : _greenDark.withValues(alpha: 0.35)),
            width: 1,
          ),
        ),
        child: Center(
          child: _isLoading
              ? SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: widget.isDark ? _greenBright : _greenDark,
                  ),
                )
              : Icon(
                  _isPlaying
                      ? Icons.stop_rounded
                      : Icons.volume_up_rounded,
                  size: 15,
                  color: _isPlaying
                      ? _greenBright
                      : (widget.isDark ? Colors.white54 : _greenDark),
                ),
        ),
      ),
    );
  }
}