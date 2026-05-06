// lib/features/conversational/conversational_state.dart

enum ConversationalStatus {
  idle,        // modo chat normal, overlay oculto
  listening,   // grabando voz del usuario
  processing,  // enviando a STT + Gemini + TTS
  speaking,    // reproduciendo respuesta
}

class ConversationalState {
  final ConversationalStatus status;
  final String? error;

  const ConversationalState({
    this.status = ConversationalStatus.idle,
    this.error,
  });

  bool get isActive => status != ConversationalStatus.idle;

  ConversationalState copyWith({
    ConversationalStatus? status,
    Object? error = _keep,
  }) {
    return ConversationalState(
      status: status ?? this.status,
      error:  error == _keep ? this.error : error as String?,
    );
  }
}

const _keep = Object();