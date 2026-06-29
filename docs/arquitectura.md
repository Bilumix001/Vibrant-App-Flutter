# Arquitectura del Sistema

## Visión general

Vibrant App sigue una arquitectura cliente-servidor donde el frontend móvil (Flutter) se comunica con un backend REST (Django) que orquesta los servicios de inteligencia artificial.

```
┌──────────────────────────────────────────────────────────────┐
│                        CLIENTE (Flutter)                     │
│                                                              │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────────────┐    │
│  │  Chat    │  │    Modo      │  │   Historial de       │    │
│  │  Screen  │  │Conversacional│  │   Conversaciones     │    │
│  └────┬─────┘  └──────┬───────┘  └──────────┬───────────┘    │
│       │               │                      │               │
│  ┌────▼───────────────▼──────────────────────▼────────────┐  │
│  │              Riverpod (Estado global)                  │  │
│  │   ChatProvider │ ConversationalProvider │ ThemeProvider│  │
│  └────┬───────────────────────────────────────────────────┘  │
│       │                                                      │
│  ┌────▼────────────────────────────────────────────────────┐ │
│  │                    Services (HTTP)                      │ │
│  │  ChatService │ TtsService │ SttService │ AuthService    │ │
│  └────┬────────────────────────────────────────────────────┘ │
└───────┼──────────────────────────────────────────────────────┘
        │ HTTP / SSE
        ▼
┌───────────────────────────────────────────────────────────┐
│                      BACKEND (Django)                     │
│                                                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
│  │  /chat/  │  │  /stt/   │  │  /tts/   │  │  /auth/   │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └───────────┘  │
│       │             │              │                      │
│  ┌────▼─────┐  ┌────▼──────┐ ┌────▼──────┐                │
│  │LLMService│  │STTService │ │TTSService │                │
│  │EmbeddSvc │  │  (Google  │ │ (Edge TTS │                │
│  │QdrantSvc │  │  Speech)  │ │  Camila)  │                │
│  └────┬─────┘  └───────────┘ └───────────┘                │
│       │                                                   │
└───────┼───────────────────────────────────────────────────┘
        │
   ┌────┴──────────────────────────┐
   │                               │
   ▼                               ▼
┌──────────────┐          ┌────────────────┐
│    Gemini    │          │    Qdrant      │
│  2.5 Flash   │          │ (Vector DB)    │
│   (Google)   │          │ Destinos Perú  │
└──────────────┘          └────────────────┘
```

---

## Flujo del modo chat

```
Usuario escribe mensaje
        │
        ▼
ChatProvider.sendMessage()
        │
        ▼
ChatService.sendMessageStream() ──► POST /api/chat/stream/
        │                                    │
        │                           ┌────────▼────────┐
        │                           │ es_pregunta_    │
        │                           │ informativa()   │
        │                           └────────┬────────┘
        │                                    │
        │                           ┌────────▼────────┐
        │                           │ EmbeddingService│
        │                           │ get_embedding() │
        │                           └────────┬────────┘
        │                                    │
        │                           ┌────────▼────────┐
        │                           │  QdrantService  │
        │                           │  search()       │
        │                           └────────┬────────┘
        │                                    │
        │                           ┌────────▼────────┐
        │                           │   LLMService    │
        │                           │  generar_stream │
        │                           └────────┬────────┘
        │                                    │
        ◄──── SSE chunks ────────────────────┘
        │
        ▼
Texto aparece en pantalla (token a token)
        │
        ▼
TtsService.getAudioPath() ──► POST /api/tts/?stream=true
        │
        ▼
Audio se reproduce (Edge TTS — Camila)
```

---

## Flujo del modo conversacional

```
Usuario mantiene presionado el micrófono
        │
        ▼
ConversationalController.start()
        │
        ▼
┌─────────────────────────────────────┐
│              LOOP                   │
│                                     │
│  1. _listen()                       │
│     - Graba audio con detección     │
│       automática de silencio (2s)   │
│     - Límite máximo: 20s            │
│                                     │
│  2. SttService.transcribe()         │
│     POST /api/stt/                  │
│     Google Speech Recognition       │
│                                     │
│  3. chatProvider.sendMessage()      │
│     (playTts: false)                │
│                                     │
│  4. _speak()                        │
│     Edge TTS → just_audio           │
│     Detección de interrupción       │
│     por voz del usuario             │
│                                     │
│  5. Volver a 1                      │
└─────────────────────────────────────┘
        │
        ▼ (usuario presiona X)
ConversationalController.stop()
        │
        ▼
Modo chat normal — historial visible
```

---
## Módulos del frontend

### providers/
Estado global con Riverpod.

| Provider | Responsabilidad |
|----------|----------------|
| `chat_provider.dart` | Estado del chat, envío de mensajes, STT, TTS |
| `conversation_provider.dart` | Lista y gestión de conversaciones |
| `auth_provider.dart` | Estado de autenticación |
| `theme_provider.dart` | Tema claro/oscuro |
| `onboarding_provider.dart` | Control del tooltip de onboarding |

### features/conversational/
Modo conversacional completo.

| Archivo | Responsabilidad |
|---------|----------------|
| `conversational_controller.dart` | Loop escuchar→transcribir→responder→hablar |
| `conversational_overlay.dart` | UI tipo Gemini (botón mic + X) |
| `conversational_state.dart` | Estados: idle, listening, processing, speaking |
| `message_audio_button.dart` | Botón de reproducción por mensaje |

---
