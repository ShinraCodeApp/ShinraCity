# ShinraCity - Arquitectura Técnica

## Visión General

ShinraCity es una plataforma de geolocalización comercial construida con arquitectura Clean Architecture + BLoC.

```
┌─────────────────────────────────────────────────────────┐
│                    SHINRACITY APP                        │
├─────────────┬─────────────────┬───────────────────────── │
│  Presentation│    Domain       │      Data               │
│  (Flutter)  │   (Pure Dart)   │    (Firebase)           │
├─────────────┼─────────────────┼─────────────────────────┤
│  BLoCs      │  Entities       │  Firebase Auth          │
│  Screens    │  Repositories   │  Firestore              │
│  Widgets    │  Use Cases      │  Storage                │
│  Router     │                 │  Cloud Functions        │
│  Theme      │                 │  FCM                    │
└─────────────┴─────────────────┴─────────────────────────┘
```

## Stack Tecnológico

| Capa | Tecnología |
|------|-----------|
| Frontend | Flutter 3.x (Dart) |
| State Management | BLoC + Equatable |
| DI | GetIt + Injectable |
| Navigation | GoRouter |
| Backend | Firebase (BaaS) |
| Base de datos | Firestore (NoSQL) |
| Auth | Firebase Authentication |
| Storage | Firebase Storage |
| Cloud Functions | Node.js 18 + TypeScript |
| Notificaciones | Firebase Cloud Messaging |
| Analíticas | Firebase Analytics |
| Mapas | Google Maps Flutter |
| Pagos | Stripe + Mercado Pago |
| Seguridad | Firestore Rules + JWT + AES |

## Estructura del Proyecto

```
shinra_city/
├── lib/
│   ├── core/
│   │   ├── constants/       # Constantes globales
│   │   ├── errors/          # Failures tipados
│   │   ├── theme/           # Tema visual (dark/light)
│   │   ├── utils/           # Geo, Coupon Generator
│   │   ├── router/          # GoRouter config
│   │   └── widgets/         # Main Shell, Bottom Nav
│   │
│   ├── domain/
│   │   ├── entities/        # Modelos puros de negocio
│   │   ├── repositories/    # Interfaces abstractas
│   │   └── usecases/        # Lógica de negocio
│   │
│   ├── data/
│   │   ├── models/          # Modelos con serialización
│   │   ├── datasources/     # Acceso a Firebase
│   │   └── repositories/    # Implementaciones
│   │
│   ├── presentation/
│   │   ├── blocs/           # BLoCs (eventos/estados)
│   │   ├── screens/         # Pantallas
│   │   └── widgets/         # Componentes UI
│   │
│   ├── services/            # Notificaciones, DI
│   └── main.dart
│
├── functions/               # Firebase Cloud Functions
│   └── src/
│       ├── functions/       # Módulos por dominio
│       └── index.ts
│
├── firestore.rules          # Reglas de seguridad
├── storage.rules
└── docs/                    # Documentación
```

## Modelos de Datos (Firestore)

### users/{uid}
```json
{
  "email": "string",
  "displayName": "string",
  "photoUrl": "string?",
  "role": "user|businessOwner|employee|admin|superAdmin",
  "level": "explorer|frequent|exemplary|ambassador|lifetime",
  "totalPoints": 0,
  "availablePoints": 0,
  "totalCouponsRedeemed": 0,
  "totalSavings": 0,
  "favoriteCommerceIds": ["string"],
  "followingCategories": ["string"],
  "followingCommerceIds": ["string"],
  "badgeIds": ["string"],
  "achievementIds": ["string"],
  "lastLocation": "GeoPoint?",
  "fcmToken": "string?",
  "authProvider": "email|google|apple|facebook",
  "isActive": true,
  "isVerified": false,
  "notificationsEnabled": true,
  "referralCode": "string",
  "createdAt": "timestamp"
}
```

### commerces/{id}
```json
{
  "ownerId": "string",
  "name": "string",
  "nameLowercase": "string",
  "description": "string",
  "logoUrl": "string?",
  "galleryUrls": ["string"],
  "category": "string",
  "plan": "free|basic|premium|enterprise",
  "status": "active|pending|suspended",
  "location": "GeoPoint",
  "geohash": "string",
  "address": "string",
  "city": "string",
  "businessHours": {"monday": {"isOpen": true, "openTime": "09:00", "closeTime": "18:00"}},
  "rating": 0.0,
  "reviewCount": 0,
  "followerCount": 0,
  "isCurrentlyOpen": false,
  "hasActivePromotion": false,
  "isVerified": false,
  "isFeatured": false,
  "searchTerms": ["string"],
  "authorizedEmployeeIds": ["string"],
  "createdAt": "timestamp"
}
```

### promotions/{id}
```json
{
  "commerceId": "string",
  "title": "string",
  "description": "string",
  "type": "hourly|daily|weekly|monthly|limited|geolocated|followers|vip",
  "status": "draft|active|paused|expired|cancelled",
  "discountType": "percentage|fixedAmount|twoForOne|freeItem",
  "discountValue": 20.0,
  "startDate": "timestamp",
  "endDate": "timestamp",
  "totalSlots": 100,
  "usedSlots": 0,
  "perUserLimit": 1,
  "isExclusiveForFollowers": false,
  "isVip": false,
  "isGeolocated": false,
  "pointsAwarded": 10,
  "viewCount": 0,
  "claimCount": 0
}
```

### coupons/{id}
```json
{
  "userId": "string",
  "commerceId": "string",
  "promotionId": "string",
  "token": "AES-encrypted-string",
  "qrData": "{\"shinra\":\"1\",\"id\":\"...\",\"t\":\"...\"}",
  "checksum": "sha256-string",
  "status": "available|reserved|used|expired|cancelled",
  "issuedAt": "timestamp",
  "expiresAt": "timestamp",
  "usedAt": "timestamp?",
  "usedByEmployeeId": "string?",
  "deviceFingerprint": "string",
  "pointsEarned": 10
}
```

## Sistema Antifraude

1. **Token AES-256**: Cada cupón tiene un token cifrado con IV aleatorio
2. **Checksum SHA-256**: Verificación de integridad del cupón
3. **Device Fingerprint**: Hash del dispositivo + usuario + promoción + fecha
4. **Transacciones Firestore**: Validación atómica para evitar race conditions
5. **Rate Limiting**: Máximo 10 cupones/hora por dispositivo
6. **Multi-cuenta**: Detección de múltiples cuentas en mismo dispositivo

## Geolocalización

- **Geohash Precision 7**: ~152m × 152m por celda
- **Consultas por prefijo**: 5 caracteres de geohash para búsqueda en radio
- **Geofencing**: Círculos de 200m por comercio para notificaciones
- **Real-time**: Stream de comercios actualizados al mover el mapa

## Sistema de Niveles

| Nivel | Puntos Requeridos | Color |
|-------|------------------|-------|
| Explorador | 0 | Gris |
| Cliente Frecuente | 500 | Azul |
| Cliente Ejemplar | 2.000 | Verde |
| Embajador | 5.000 | Naranja |
| Socio Vitalicio | 15.000 | Dorado |

## Planes Comerciales

| Plan | Promociones | Precio/mes | Features |
|------|------------|-----------|---------|
| Gratuito | 2 activas | $0 | Básico |
| Básico | Ilimitadas | $2.990 | + Estadísticas |
| Premium | Ilimitadas | $5.990 | + Visibilidad prioritaria |
| Empresarial | Ilimitadas | $14.990 | + Sucursales + API |

## Escalabilidad

| Usuarios | Estrategia |
|---------|-----------|
| 0-10K | Firebase Spark/Blaze estándar |
| 10K-100K | Índices compuestos + caching |
| 100K-1M | Sharding por ciudad + CDN |
| 1M+ | Multi-region Firestore |
