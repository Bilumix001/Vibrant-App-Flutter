# Guía de Instalación

## Requisitos previos

### Frontend
- Flutter SDK 3.x+
- Android Studio o VS Code con extensión Flutter
- Dispositivo Android o emulador

### Servicios externos
- Cuenta Google AI Studio con API Key (Gemini)
- Qdrant con la colección de destinos de Vibrant Perú cargada

---

## Frontend (Flutter)

### 1. Instalar dependencias

```bash
cd demo
flutter pub get
```

### 2. Configurar URL del backend

Edita `lib/config/app_config.dart`:

```dart
class AppConfig {
  // Emulador Android
  static const String baseUrl = 'http://10.0.2.2:8000';

  // Dispositivo físico (usa la IP de tu PC)
  // static const String baseUrl = 'http://192.168.1.XX:8000';

  // Producción
  // static const String baseUrl = 'https://tu-dominio.com';
}
```

### 3. Permisos Android

El archivo `android/app/src/main/AndroidManifest.xml` debe incluir:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

### 4. Correr la app

```bash
# En emulador
flutter run

# En dispositivo físico conectado por USB
flutter run -d <device-id>

# Ver dispositivos disponibles
flutter devices
```

---

## Qdrant

### Correr Qdrant localmente con Docker

```bash
docker run -p 6333:6333 qdrant/qdrant
```

### Verificar que está corriendo

```bash
curl http://localhost:6333/collections
```

> La colección con los destinos turísticos de Vibrant Perú debe estar cargada previamente. Consulta con el equipo de datos para obtener el dump de la colección.

---

## Verificar instalación completa

1. Backend corriendo → abre `http://localhost:8000/api/docs/` en el navegador
2. Qdrant corriendo → abre `http://localhost:6333/dashboard`
3. App Flutter corriendo → inicia sesión con una cuenta de prueba
4. Envía un mensaje de prueba: "¿Qué destinos tienen disponibles?"

Si el asistente responde con información de Vibrant Perú, todo está funcionando correctamente.

---

## Problemas comunes

| Problema | Causa probable | Solución |
|----------|---------------|----------|
| `Connection timed out` en el teléfono | Firewall bloqueando puerto 8000 | `netsh advfirewall firewall add rule name="Django 8000" dir=in action=allow protocol=TCP localport=8000` |
| `401 Unauthorized` en todos los endpoints | Token expirado o no enviado | Cerrar sesión y volver a iniciar |
| `Model not found` en embeddings | Modelo no descargado aún | Se descarga automáticamente en el primer arranque |
| Audio no se reproduce | Formato de audio incorrecto | Verificar que `just_audio` acepta MP3 en el dispositivo |
