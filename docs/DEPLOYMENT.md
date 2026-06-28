# ShinraCity - Guía de Despliegue

## Pre-requisitos

- Flutter SDK 3.x instalado
- Node.js 18+ instalado
- Firebase CLI instalado (`npm install -g firebase-tools`)
- Cuenta de Firebase (plan Blaze para Cloud Functions)
- Cuenta de Google Cloud (Google Maps API)
- Cuenta de Stripe
- Cuenta de Mercado Pago (para LATAM)

---

## 1. Configuración de Firebase

### 1.1 Crear Proyecto Firebase
```bash
# Login Firebase
firebase login

# Crear proyecto (o usar existente)
firebase projects:create shinra-city-prod

# Inicializar en directorio
firebase init
# Seleccionar: Firestore, Functions, Storage, Hosting
```

### 1.2 Habilitar Servicios
En Firebase Console habilitar:
- Authentication (Email, Google, Apple)
- Firestore (modo producción)
- Storage
- Cloud Functions (requiere plan Blaze)
- FCM (automático)
- Analytics (automático)

### 1.3 Configurar google-services.json (Android)
```bash
# Descargar google-services.json de Firebase Console
# Colocar en: android/app/google-services.json
```

### 1.4 Configurar GoogleService-Info.plist (iOS)
```bash
# Descargar GoogleService-Info.plist de Firebase Console
# Colocar en: ios/Runner/GoogleService-Info.plist
```

---

## 2. Configuración de Google Maps

### 2.1 Obtener API Key
1. Ir a Google Cloud Console
2. Habilitar Maps SDK for Android / iOS
3. Crear API Key con restricciones

### 2.2 Android
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<meta-data
  android:name="com.google.android.geo.API_KEY"
  android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

### 2.3 iOS
```swift
// ios/Runner/AppDelegate.swift
import GoogleMaps
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
```

---

## 3. Variables de Entorno (Firebase Functions)

```bash
# Configurar secrets de Cloud Functions
firebase functions:config:set \
  stripe.secret_key="sk_live_XXXX" \
  stripe.webhook_secret="whsec_XXXX" \
  mercadopago.access_token="APP_USR-XXXX"

# Para desarrollo local
firebase functions:config:get > functions/.runtimeconfig.json
```

---

## 4. Despliegue de Cloud Functions

```bash
cd functions
npm install
npm run build

# Deploy todas las funciones
firebase deploy --only functions

# Deploy función específica
firebase deploy --only functions:validateQRScan
```

---

## 5. Despliegue de Reglas de Seguridad

```bash
# Desplegar reglas Firestore
firebase deploy --only firestore:rules

# Desplegar reglas Storage
firebase deploy --only storage

# Desplegar índices
firebase deploy --only firestore:indexes
```

---

## 6. Índices Firestore Requeridos

Crear en `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "commerces",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "status", "order": "ASCENDING"},
        {"fieldPath": "geohash", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "promotions",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "commerceId", "order": "ASCENDING"},
        {"fieldPath": "status", "order": "ASCENDING"},
        {"fieldPath": "endDate", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "coupons",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "userId", "order": "ASCENDING"},
        {"fieldPath": "status", "order": "ASCENDING"},
        {"fieldPath": "issuedAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "coupons",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "commerceId", "order": "ASCENDING"},
        {"fieldPath": "status", "order": "ASCENDING"},
        {"fieldPath": "usedAt", "order": "DESCENDING"}
      ]
    }
  ]
}
```

---

## 7. Build Flutter

### Android
```bash
# Release APK
flutter build apk --release

# Release App Bundle (recomendado para Play Store)
flutter build appbundle --release

# Con obfuscation
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/debug-info
```

### iOS
```bash
# Release IPA
flutter build ipa --release

# Abrir Xcode para configurar signing
open ios/Runner.xcworkspace
```

---

## 8. Configuración de Stripe (Producción)

1. Crear cuenta en stripe.com
2. Obtener claves de API (live)
3. Configurar webhooks:
   - Endpoint: `https://us-central1-{project}.cloudfunctions.net/stripeWebhook`
   - Eventos: `payment_intent.succeeded`, `payment_intent.payment_failed`, `customer.subscription.*`
4. Crear productos y precios en Stripe Dashboard

---

## 9. Configuración Mercado Pago (LATAM)

1. Crear aplicación en developers.mercadopago.com
2. Obtener Access Token de producción
3. Configurar notificaciones IPN:
   - URL: `https://us-central1-{project}.cloudfunctions.net/mercadoPagoWebhook`

---

## 10. Monitoreo en Producción

### Firebase Crashlytics
- Automático al agregar dependencia
- Ver crashes en Firebase Console > Crashlytics

### Firebase Performance
- Monitorea tiempos de respuesta automáticamente
- Agregar traces personalizados con `FirebasePerformance`

### Firebase Analytics
- Dashboard automático de usuarios y eventos
- Crear eventos personalizados para métricas de negocio

---

## 11. Checklist de Lanzamiento

- [ ] google-services.json configurado (Android)
- [ ] GoogleService-Info.plist configurado (iOS)
- [ ] Google Maps API Key configurada
- [ ] Firebase Authentication habilitada (Email, Google, Apple)
- [ ] Firestore reglas desplegadas
- [ ] Storage reglas desplegadas
- [ ] Firestore índices creados
- [ ] Cloud Functions desplegadas
- [ ] Stripe webhooks configurados
- [ ] Mercado Pago webhooks configurados
- [ ] FCM configurado
- [ ] Privacy Policy y Terms of Service publicados
- [ ] App revisada en Google Play / App Store
- [ ] Crashlytics habilitado
- [ ] Performance monitoring habilitado
- [ ] Analytics habilitado
- [ ] Backup automático Firestore configurado

---

## 12. Variables de Entorno Flutter

Crear archivo `lib/core/constants/env_constants.dart`:

```dart
class EnvConstants {
  static const String googleMapsApiKey = String.fromEnvironment('MAPS_API_KEY');
  static const String stripePublishableKey = String.fromEnvironment('STRIPE_PK');
}
```

Build con variables:
```bash
flutter build apk --dart-define=MAPS_API_KEY=xxx --dart-define=STRIPE_PK=xxx
```
