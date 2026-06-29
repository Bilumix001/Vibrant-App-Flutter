# Guía de Despliegue

## Arquitectura de producción

```
Internet
    │
    ▼
┌─────────┐
│  Nginx  │  ← proxy inverso, SSL, archivos estáticos
└────┬────┘
     │
     ▼
┌──────────────────────────────┐
│  Gunicorn + Uvicorn Workers  │  ← servidor ASGI (necesario para SSE)
│  python manage.py ...        │
└──────────────────────────────┘
     │
     ▼
┌─────────┐    ┌─────────┐
│  Django │    │ Qdrant  │
│  + DB   │    │         │
└─────────┘    └─────────┘
```

---

## Frontend Flutter

### Build del APK

**Debug (pruebas internas):**
```bash
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

**Release (distribución):**
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Configurar URL de producción

Antes de buildear para release, actualiza `lib/config/app_config.dart`:

```dart
class AppConfig {
  static const String baseUrl = 'https://tu-dominio.com';
}
```

### Firmar el APK para release

1. Genera el keystore:
```bash
keytool -genkey -v -keystore vibrant.keystore \
    -alias vibrant -keyalg RSA -keysize 2048 -validity 10000
```

2. Configura `android/key.properties`:
```properties
storePassword=tu_password
keyPassword=tu_password
keyAlias=vibrant
storeFile=../vibrant.keystore
```

3. Build release firmado:
```bash
flutter build apk --release
```

---

## Checklist de despliegue

- [ ] Variables de entorno configuradas en el servidor
- [ ] `DEBUG=False` en producción
- [ ] `ALLOWED_HOSTS` configurado con el dominio real
- [ ] Migraciones aplicadas
- [ ] `collectstatic` ejecutado
- [ ] SSL configurado (Let's Encrypt recomendado)
- [ ] Nginx configurado con `proxy_buffering off` para SSE y TTS
- [ ] Servicio systemd activo y habilitado
- [ ] Qdrant corriendo y accesible desde el servidor
- [ ] `AppConfig.baseUrl` apuntando al dominio de producción en Flutter
- [ ] APK firmado con keystore de producción
