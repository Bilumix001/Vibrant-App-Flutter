# Vibrant App

> Guía turística virtual inteligente de **Vibrant Perú**

Vibrant App es una aplicación móvil que simula el trabajo de un guía turístico digital. Permite a los usuarios consultar información sobre los destinos turísticos de Vibrant Perú mediante conversación en texto o por voz, respondiendo exclusivamente con la información oficial de la agencia.

---

## Características principales

- **Modo chat** — conversación por texto con el asistente virtual
- **Modo conversacional** — conversación por voz en tiempo real, similar a un asistente de voz
- **RAG (Retrieval-Augmented Generation)** — las respuestas se basan únicamente en la base de conocimiento de Vibrant Perú almacenada en Qdrant
- **Autenticación** — sistema de registro e inicio de sesión por usuario
- **Historial de conversaciones** — cada usuario puede acceder a sus conversaciones anteriores
- **Text-to-Speech** — las respuestas del asistente se reproducen en voz natural (Edge TTS, voz Camila — Perú)
- **Speech-to-Text** — el audio del usuario se transcribe automáticamente (Google Speech Recognition)

---

## Stack tecnológico

|       Capa         |                Tecnología                |
|--------------------|------------------------------------------|
|     Frontend       |              Flutter (Dart)              |
|     Backend        |      Django + Django REST Framework      |
|  Base de datos     |           SQLite (desarrollo)            |
|   Vector database  |                 Qdrant                   |
| Modelo de lenguaje |          Google Gemini 2.5 Flash         |
|     Embeddings     | `sentence-transformers/all-MiniLM-L6-v2` |
|   Text-to-Speech   |      Edge TTS — `es-PE-CamilaNeural`     |
|   Speech-to-Text   |         Google Speech Recognition        |
|    Streaming       |          Server-Sent Events (SSE)        |

---

## Estructura del repositorio

```
demo/                    # Frontend Flutter
├── lib/
│   ├── features/        # Módulos de funcionalidad
│   │   └── conversational/  # Modo conversacional
│   ├── models/          # Modelos de datos
│   ├── providers/       # Estado global (Riverpod)
│   ├── screens/         # Pantallas
│   ├── services/        # Servicios HTTP
│   ├── utils/           # Utilidades
│   └── widgets/         # Widgets reutilizables
├── pubspec.yaml
├── docs/                # Carpeta de documentacion
└── README.md
```

---

## Documentación

| Documento                                          | Descripción                           |
|----------------------------------------------------|---------------------------------------|
| [Arquitectura](docs/arquitectura.md)               | Diagrama y descripción del sistema    |
| [Instalación](docs/instalacion.md)                 | Cómo correr el proyecto en desarrollo |
| [API](docs/api.md)                                 | Referencia completa de endpoints      |
| [Despliegue](docs/despliegue.md)                   | Guía para producción                  |

---

## Inicio rápido

### Backend
```bash
cd back-django-va
pipenv install
pipenv shell
python manage.py migrate
python manage.py runserver
```

### Frontend
```bash
cd demo
flutter pub get
flutter run
```

> Ver [docs/instalacion.md](docs/instalacion.md) para la configuración completa.

---

## Autor

**Patrick Michael**  
Desarrollador — Vibrant Perú  

---

## Licencia

Proyecto privado — © 2026 Vibrant Perú. Todos los derechos reservados.
