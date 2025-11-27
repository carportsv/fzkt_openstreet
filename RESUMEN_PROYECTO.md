# Resumen del Proyecto - fzkt_openstreet

## 📋 Contexto General

Aplicación Flutter para gestión de viajes en taxi. El proyecto incluye:
- **Frontend Flutter**: Aplicación multiplataforma (web, Android, iOS)
- **Backend**: Supabase (base de datos) + Firebase (autenticación)
- **Deployment**: GitHub Pages para la versión web
- **Base URL**: `https://carportsv.github.io/fzkt_openstreet/`

---

## 🎯 Objetivos Principales Completados

### 1. Sistema de Routing Web
**Problema inicial**: Necesitábamos que `/welcome` mostrara `WelcomeScreen` (pantalla pública) y `/` mostrara `LoginScreen` (a través de `AuthGate`).

**Solución implementada**:
- **Archivo**: `lib/router/route_handler.dart`
  - Widget que detecta la URL actual usando `Uri.base.path` y `Uri.base.fragment`
  - Normaliza paths (elimina dobles barras) para prevenir `SecurityError`
  - Detecta rutas como `/welcome`, `#/welcome`, `/fzkt_openstreet/welcome`
  - Si detecta `/welcome` → muestra `WelcomeScreen`
  - Si detecta cualquier otra ruta → muestra `AuthGate` (que a su vez muestra `LoginScreen` si no hay usuario)

- **Archivo**: `web/404.html`
  - Maneja el routing client-side para GitHub Pages
  - Redirige todas las rutas 404 a `index.html` con el path como hash fragment
  - Ejemplo: `/fzkt_openstreet/welcome` → `/fzkt_openstreet/index.html#/welcome`

- **Archivo**: `lib/main.dart`
  - Configurado con `MaterialApp` (no `MaterialApp.router`)
  - `home: const RouteHandler()` para manejar routing
  - `restorationScopeId: null` para prevenir manipulación automática del historial del navegador

### 2. WelcomeScreen - Pantalla Pública de Solicitud de Viajes

**Archivo**: `lib/screens/welcome/welcome_screen.dart`

**Características implementadas**:
- ✅ **Pantalla completamente pública**: No requiere autenticación
- ✅ **Eliminada redirección automática**: Ya no redirige a `AdminHomeScreen` si hay un admin autenticado
- ✅ **Formulario completo de solicitud de viaje**:
  - **Detalles del viaje**: Origen, destino, fecha/hora, notas
  - **Detalles del vehículo**: Tipo de vehículo (Estandar, Premium, SUV, Van)
  - **Detalles del pasajero**: Número de pasajeros, asientos infantiles, equipaje de mano, equipaje de facturación
  - **Método de pago**: Efectivo, Tarjeta, Transferencia
  - **Detalles de tarjeta** (si se selecciona tarjeta):
    - Número de tarjeta (formato: XXXX XXXX XXXX XXXX)
    - Fecha de expiración (formato: MM/YY)
    - CVV (3 dígitos)
    - Nombre en la tarjeta
  - **Validación completa** de campos de tarjeta
  - **Formatters personalizados** para número de tarjeta y fecha de expiración
  - **Selección de cliente existente** (opcional) desde Supabase
  - **Cálculo y visualización de tarifa** estimada

- ✅ **Integración con Supabase**:
  - Los viajes se guardan en la tabla `ride_requests` con status `'pending'` (o `'requested'`)
  - Campos guardados: origen, destino, fecha/hora, tipo de vehículo, pasajeros, equipaje, método de pago, detalles de tarjeta (si aplica), cliente_id (si se selecciona)

### 3. Pantallas de Administración - Carga de Datos desde Supabase

**Implementadas**:
- ✅ `lib/screens/admin/bookings/bookings_pending.dart`
  - Muestra viajes con status `'requested'` sin driver asignado
  - Búsqueda, filtro por fecha, refresh, manejo de errores

- ✅ `lib/screens/admin/bookings/bookings_new_screen.dart`
  - Muestra viajes con status `'requested'` creados hoy
  - Filtro por `created_at >= hoy`

- ✅ `lib/screens/admin/bookings/bookings_accepted.dart`
  - Muestra viajes con status `'accepted'`
  - Carga desde Supabase con filtros apropiados

**Pendientes** (estructura similar ya existe):
- ⏳ `bookings_assigned.dart` - status `'accepted'` o `'assigned'` con `driver_id`
- ⏳ `bookings_completed.dart` - status `'completed'`
- ⏳ `bookings_payment_pending.dart` - pago pendiente
- ⏳ `bookings_future.dart` - `is_scheduled = true`
- ⏳ `bookings_cancelled.dart` - status `'cancelled'`

### 4. Configuración de Entorno

**Archivo**: `lib/main.dart`
- ✅ Carga de `.env` desde la raíz del proyecto (no desde `web/.env`)
- ✅ Inicialización de Firebase y Supabase
- ✅ Manejo de errores en inicialización

**Archivo**: `pubspec.yaml`
- ✅ `.env` incluido en `assets:` para que Flutter web pueda accederlo

### 5. Git y Deployment

**Configuración**:
- ✅ `.gitignore` actualizado para excluir `backups/` y `expo/`
- ✅ Script de backup: `scripts/backup-project.ps1`
  - Crea backups timestamped
  - Excluye build artifacts
  - Opción de compresión ZIP

**GitHub Actions**:
- ✅ Workflow automático para build y deploy a GitHub Pages
- ✅ Base-href configurado: `/fzkt_openstreet/`

---

## 🏗️ Arquitectura Actual

### Flujo de Autenticación y Routing

```
main.dart
  └─> RouteHandler (solo web)
      ├─> Si URL contiene '/welcome' → WelcomeScreen (pública)
      └─> Si URL es '/' u otra → AuthGate
          ├─> Si NO hay usuario → LoginScreen
          └─> Si HAY usuario → RoutingScreen
              ├─> Si rol = 'admin' → AdminHomeScreen
              ├─> Si rol = 'driver' → DriverHomeScreen
              └─> Si rol = 'user' → UserHomeScreen
```

### Estructura de Archivos Clave

```
lib/
├── main.dart                    # Punto de entrada, carga .env, inicializa Firebase/Supabase
├── router/
│   └── route_handler.dart       # Maneja routing web basado en URL
├── auth/
│   ├── auth_gate.dart          # Verifica autenticación, muestra LoginScreen o RoutingScreen
│   ├── login_screen.dart        # Pantalla de login (Firebase Google Sign-In)
│   └── routing_screen.dart      # Redirige según rol del usuario
└── screens/
    ├── welcome/
    │   └── welcome_screen.dart  # Pantalla pública para solicitar viajes
    └── admin/
        └── bookings/
            ├── bookings_pending.dart      # ✅ Implementado
            ├── bookings_new_screen.dart   # ✅ Implementado
            ├── bookings_accepted.dart     # ✅ Implementado
            ├── bookings_assigned.dart     # ⏳ Pendiente
            ├── bookings_completed.dart    # ⏳ Pendiente
            ├── bookings_payment_pending.dart # ⏳ Pendiente
            ├── bookings_future.dart       # ⏳ Pendiente
            └── bookings_cancelled.dart    # ⏳ Pendiente

web/
└── 404.html                     # Redirige rutas 404 a index.html#/ruta para SPA

scripts/
└── backup-project.ps1          # Script PowerShell para backups
```

---

## 🔧 Problemas Resueltos

### 1. Routing Web
- **Problema**: `/welcome` no mostraba `WelcomeScreen`
- **Causa**: `AuthGate` siempre mostraba `LoginScreen` por defecto
- **Solución**: Crear `RouteHandler` que verifica la URL antes de `AuthGate`

### 2. SecurityError en Navegador
- **Problema**: `SecurityError` al acceder a `//welcome` (doble slash)
- **Causa**: Flutter intentaba manipular historial con URL inválida
- **Solución**: 
  - Normalizar paths en `RouteHandler` (eliminar dobles slashes)
  - Agregar `restorationScopeId: null` en `MaterialApp`

### 3. GitHub Pages 404
- **Problema**: `carportsv.github.io/fzkt_openstreet/welcome` daba 404
- **Causa**: GitHub Pages no entiende routing client-side
- **Solución**: Crear `web/404.html` que redirige a `index.html#/welcome`

### 4. Carga de .env en Web
- **Problema**: `.env` no se cargaba en Flutter web
- **Causa**: Código intentaba cargar desde `web/.env`
- **Solución**: Cargar siempre desde raíz, asegurar que está en `pubspec.yaml`

### 5. Deprecation Warnings
- **Problema**: `RadioListTile` y `DropdownButtonFormField` con propiedades deprecadas
- **Solución**: 
  - Reemplazar `RadioListTile` con `SegmentedButton` (moderno)
  - Cambiar `value` a `initialValue` en `DropdownButtonFormField`

### 6. dart:html Deprecated
- **Problema**: Uso de `dart:html` en `RouteHandler`
- **Solución**: Usar `Uri.base.fragment` (platform-agnostic)

---

## 📊 Estado de la Base de Datos

### Tabla: `ride_requests`
Campos relevantes para los viajes:
- `id` (UUID)
- `origin` (texto)
- `destination` (texto)
- `scheduled_date` (timestamp)
- `scheduled_time` (texto)
- `status` (texto): `'requested'`, `'pending'`, `'accepted'`, `'assigned'`, `'completed'`, `'cancelled'`
- `vehicle_type` (texto): `'standard'`, `'premium'`, `'suv'`, `'van'`
- `passenger_count` (integer)
- `child_seats` (integer)
- `hand_luggage` (integer)
- `check_in_luggage` (integer)
- `payment_method` (texto): `'cash'`, `'card'`, `'transfer'`
- `card_number` (texto, nullable)
- `card_expiry` (texto, nullable)
- `card_cvv` (texto, nullable)
- `card_name` (texto, nullable)
- `customer_id` (UUID, nullable) - referencia a tabla `users`
- `driver_id` (UUID, nullable) - referencia a tabla `users`
- `is_scheduled` (boolean)
- `created_at` (timestamp)
- `updated_at` (timestamp)

### Tabla: `users`
- `id` (UUID) - coincide con Firebase UID
- `email` (texto)
- `role` (texto): `'admin'`, `'driver'`, `'user'`
- `name` (texto)
- Otros campos de perfil...

---

## 🚀 Comandos Útiles

### Desarrollo
```bash
# Limpiar y obtener dependencias
flutter clean
flutter pub get

# Ejecutar en web
flutter run -d chrome --web-renderer html

# Build para GitHub Pages
flutter build web --base-href /fzkt_openstreet/
```

### Git
```bash
# Ver estado
git status

# Agregar cambios (excluye backups/ y expo/)
git add .

# Commit
git commit -m "Descripción del cambio"

# Push
git push origin main
```

### Backup
```powershell
# Ejecutar script de backup
.\scripts\backup-project.ps1
```

---

## 📝 Notas Importantes

1. **WelcomeScreen es pública**: No requiere autenticación, cualquiera puede solicitar un viaje.

2. **Routing solo funciona en web**: En móvil, siempre se muestra `AuthGate`.

3. **Base-href**: Todas las URLs deben considerar `/fzkt_openstreet/` como base.

4. **404.html**: Es crítico para que GitHub Pages funcione con routing client-side.

5. **Status de viajes**: Los viajes creados desde `WelcomeScreen` se guardan con status `'pending'` o `'requested'`.

6. **Validación de tarjeta**: Solo se valida si el método de pago es `'card'`.

---

## ✅ Tareas Completadas

- [x] Implementar routing web para `/welcome` y `/`
- [x] Hacer `WelcomeScreen` completamente pública
- [x] Agregar campos de pago con tarjeta en `WelcomeScreen`
- [x] Implementar validación y formatters para tarjeta
- [x] Guardar viajes en Supabase desde `WelcomeScreen`
- [x] Implementar carga de datos en `bookings_pending.dart`
- [x] Implementar carga de datos en `bookings_new_screen.dart`
- [x] Implementar carga de datos en `bookings_accepted.dart`
- [x] Crear `404.html` para GitHub Pages
- [x] Configurar `.gitignore` para excluir backups
- [x] Corregir warnings de deprecation
- [x] Resolver `SecurityError` en routing

---

## ⏳ Tareas Pendientes

- [ ] Implementar carga de datos en `bookings_assigned.dart`
- [ ] Implementar carga de datos en `bookings_completed.dart`
- [ ] Implementar carga de datos en `bookings_payment_pending.dart`
- [ ] Implementar carga de datos en `bookings_future.dart`
- [ ] Implementar carga de datos en `bookings_cancelled.dart`
- [ ] (Opcional) Agregar más validaciones en `WelcomeScreen`
- [ ] (Opcional) Mejorar UI/UX de las pantallas de bookings

---

## 🔗 URLs Importantes

- **Producción Web**: https://carportsv.github.io/fzkt_openstreet/
- **Welcome Screen**: https://carportsv.github.io/fzkt_openstreet/welcome
- **Login Screen**: https://carportsv.github.io/fzkt_openstreet/
- **Repositorio**: https://github.com/carportsv/fzkt_openstreet

---

## 📞 Información de Contacto/Configuración

- **Proyecto**: fzkt_openstreet
- **Workspace**: `D:\carposv\apps\taxi\fzkt_openstreet`
- **Base de datos**: Supabase
- **Autenticación**: Firebase (Google Sign-In)
- **Deployment**: GitHub Pages (GitHub Actions)

---

**Última actualización**: Diciembre 2024
**Estado del proyecto**: ✅ Funcional - Routing web implementado, WelcomeScreen pública con formulario completo, integración con Supabase funcionando

