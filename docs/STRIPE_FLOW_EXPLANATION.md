# Explicación del Flujo de Stripe - Todas las Tarjetas

## 📋 Resumen General

Este documento explica cómo funciona el flujo completo de pagos con Stripe para **todas las tarjetas**, incluyendo el manejo automático de 3D Secure.

---

## 🔄 Flujo Completo de Pago

### **Paso 1: Validación Local de Tarjeta**
```dart
StripeService.validateCardData()
```
- **Qué hace:** Valida el formato de los datos de la tarjeta antes de enviarlos a Stripe
- **Valida:**
  - Número de tarjeta (13-19 dígitos)
  - Fecha de expiración (no expirada)
  - CVV (3-4 dígitos)
- **Resultado:** Si hay errores, se muestran al usuario antes de procesar

---

### **Paso 2: Crear el Viaje (Ride)**
```dart
_rideService.createRideRequest(rideData)
```
- **Qué hace:** Crea el registro del viaje en la base de datos
- **Por qué primero:** Necesitamos el `rideId` para asociarlo con el Payment Intent
- **Resultado:** Obtiene el `rideId` del viaje creado

---

### **Paso 3: Crear Payment Intent (HOLD - Autorización)**
```dart
StripeService.createPaymentIntent(rideId, amount, currency)
```
- **Qué hace:** Crea un Payment Intent en Stripe que **reserva** el monto pero **NO lo cobra**
- **Tipo:** `capture_method: 'manual'` - Esto significa que el dinero se reserva pero se cobra después
- **Llamada:** Edge Function de Supabase `create-payment-intent`
- **Resultado:** 
  - `paymentIntent.id` - ID del Payment Intent
  - `paymentIntent.clientSecret` - Secreto para confirmar el pago
  - `paymentIntent.status` - Estado inicial (generalmente `requires_payment_method`)

**Estados posibles del Payment Intent:**
- `requires_payment_method` - Necesita método de pago
- `requires_confirmation` - Necesita confirmación
- `requires_action` - Requiere acción adicional (3D Secure)
- `processing` - Procesando
- `succeeded` - Exitoso
- `canceled` - Cancelado

---

### **Paso 4: Confirmar Payment Intent con Datos de Tarjeta**
```dart
StripeService.confirmPaymentIntentWithCard(clientSecret, cardNumber, expMonth, expYear, cvc)
```

Este es el paso **más importante** y donde se maneja **3D Secure automáticamente**.

#### **4.1: Crear PaymentMethod**
```dart
Stripe.instance.createPaymentMethod()
```
- **Qué hace:** Crea un objeto PaymentMethod con los datos de la tarjeta
- **Datos incluidos:**
  - Número de tarjeta
  - Fecha de expiración
  - CVV
  - Nombre del titular (opcional)
- **Resultado:** `paymentMethod.id` - ID del método de pago creado

#### **4.2: Confirmar Payment Intent**
```dart
Stripe.instance.confirmPayment(clientSecret, paymentMethodId)
```
- **Qué hace:** Confirma el Payment Intent con el PaymentMethod creado
- **Manejo de 3D Secure:**
  - Si la tarjeta **requiere 3D Secure**, Stripe automáticamente:
    1. Detecta que se necesita autenticación
    2. Muestra el flujo de 3D Secure al usuario
    3. Espera a que el usuario complete la autenticación
    4. Retorna el resultado final
  - Si la tarjeta **NO requiere 3D Secure**, el pago se procesa directamente
- **Resultado:** `PaymentIntent` con el estado final

#### **4.3: Verificar Estado Final**
```dart
paymentIntent.status
```

**Estados y su significado:**

| Estado | Significado | Acción |
|--------|-------------|--------|
| `Succeeded` | ✅ Pago autorizado exitosamente | Continuar con el viaje |
| `RequiresAction` | 🔐 Requiere 3D Secure (ya completado) | Stripe ya manejó esto, continuar |
| `RequiresPaymentMethod` | ❌ Tarjeta rechazada | Mostrar error, pedir otra tarjeta |
| `RequiresConfirmation` | ⚠️ Necesita confirmación adicional | Mostrar error |
| `Processing` | ⏳ Procesando | Esperar o mostrar mensaje |
| `Canceled` | ❌ Cancelado | Mostrar error |

---

## 🎯 Tarjetas de Prueba y su Comportamiento

### **1. Tarjeta Exitosa: `4242 4242 4242 4242`**
- **Comportamiento:** Pago procesado exitosamente
- **3D Secure:** ❌ No requerido
- **Flujo:**
  1. Crear Payment Intent → `requires_payment_method`
  2. Confirmar con tarjeta → `succeeded` ✅
  3. Pago autorizado, listo para cobrar al finalizar viaje

---

### **2. Tarjeta Declinada: `4000 0000 0000 0002`**
- **Comportamiento:** Tarjeta rechazada por el banco
- **3D Secure:** ❌ No requerido
- **Flujo:**
  1. Crear Payment Intent → `requires_payment_method`
  2. Confirmar con tarjeta → `requires_payment_method` ❌
  3. Error: "El método de pago fue rechazado. Intenta con otra tarjeta."

---

### **3. Tarjeta con 3D Secure: `4000 0025 0000 3155`** ⭐
- **Comportamiento:** Requiere autenticación 3D Secure
- **3D Secure:** ✅ **SÍ requerido**
- **Flujo:**
  1. Crear Payment Intent → `requires_payment_method`
  2. Confirmar con tarjeta → Stripe detecta que necesita 3D Secure
  3. **Stripe automáticamente:**
     - Muestra el modal de 3D Secure
     - Usuario ingresa código SMS o confirma en su banco
     - Usuario completa autenticación
  4. Resultado final → `succeeded` ✅
  5. Pago autorizado, listo para cobrar al finalizar viaje

**Nota importante:** El flujo de 3D Secure es **completamente automático**. No necesitas código adicional para manejarlo. Stripe se encarga de todo.

---

### **4. Tarjeta Expirada: `4000 0000 0000 0069`**
- **Comportamiento:** Tarjeta expirada
- **3D Secure:** ❌ No requerido
- **Flujo:**
  1. Validación local detecta que está expirada
  2. Error antes de crear Payment Intent: "Tarjeta expirada"

---

### **5. Fondos Insuficientes: `4000 0000 0000 9995`**
- **Comportamiento:** Tarjeta válida pero sin fondos suficientes
- **3D Secure:** ❌ No requerido
- **Flujo:**
  1. Crear Payment Intent → `requires_payment_method`
  2. Confirmar con tarjeta → `requires_payment_method` ❌
  3. Error: "Fondos insuficientes en la tarjeta."

---

### **6. Tarjeta Robada: `4000 0000 0000 9979`**
- **Comportamiento:** Tarjeta reportada como robada
- **3D Secure:** ❌ No requerido
- **Flujo:**
  1. Crear Payment Intent → `requires_payment_method`
  2. Confirmar con tarjeta → `requires_payment_method` ❌
  3. Error: "Tarjeta reportada como robada."

---

## 🔐 Cómo Funciona 3D Secure Automáticamente

### **Proceso Interno de Stripe:**

1. **Detección:**
   - Stripe analiza la tarjeta cuando se confirma el Payment Intent
   - Si la tarjeta requiere 3D Secure, Stripe lo detecta automáticamente

2. **Modal de Autenticación:**
   - Stripe muestra un modal/webview con el flujo de 3D Secure
   - El usuario ve la página de su banco
   - Usuario ingresa código SMS o confirma en su app bancaria

3. **Completación:**
   - Una vez que el usuario completa la autenticación
   - Stripe actualiza el Payment Intent a `succeeded`
   - El método `confirmPayment()` retorna con el estado final

4. **Sin Código Adicional:**
   - **No necesitas** manejar el modal de 3D Secure
   - **No necesitas** detectar si se requiere 3D Secure
   - **No necesitas** código adicional para el flujo
   - Stripe lo hace todo automáticamente

---

## 📊 Diagrama de Flujo

```
Usuario ingresa datos de tarjeta
         ↓
Validación local (formato)
         ↓
Crear viaje en BD → Obtener rideId
         ↓
Crear Payment Intent (HOLD) → Obtener clientSecret
         ↓
Crear PaymentMethod con datos de tarjeta
         ↓
Confirmar Payment Intent
         ↓
    ┌────┴────┐
    │         │
¿Requiere   No requiere
3D Secure?   3D Secure
    │         │
    │         ↓
    │    succeeded ✅
    │         │
    ↓         │
Stripe muestra
modal 3D Secure
    │
Usuario completa
autenticación
    │
    ↓
succeeded ✅
    │
    └─────→ Pago autorizado
            Listo para cobrar
            al finalizar viaje
```

---

## ⚠️ Manejo de Errores

### **Errores de Validación Local:**
- Se muestran antes de crear el Payment Intent
- Ejemplos: "Número de tarjeta inválido", "Tarjeta expirada"

### **Errores de Stripe:**
- Se capturan con `StripeException`
- Se convierten a mensajes amigables usando `StripeErrorMessages`
- Ejemplos: "Tarjeta declinada", "Fondos insuficientes"

### **Errores de Red/API:**
- Se capturan con `catch (e)`
- Mensaje genérico: "Error al procesar el pago. Intenta nuevamente."

---

## ✅ Ventajas de este Flujo

1. **3D Secure Automático:** No necesitas código adicional
2. **Manejo de Todos los Casos:** Todas las tarjetas funcionan igual
3. **Seguridad:** Los datos de tarjeta nunca tocan tu servidor
4. **UX Mejorada:** Stripe maneja la UI de 3D Secure
5. **Compatibilidad:** Funciona con todas las tarjetas de prueba

---

## 🎯 Resumen por Tarjeta

| Tarjeta | 3D Secure | Resultado | Mensaje |
|---------|-----------|-----------|---------|
| `4242...4242` | ❌ | ✅ Éxito | Pago autorizado |
| `4000...0002` | ❌ | ❌ Rechazado | Tarjeta declinada |
| `4000...3155` | ✅ | ✅ Éxito | Pago autorizado (después de 3D Secure) |
| `4000...0069` | ❌ | ❌ Error | Tarjeta expirada (validación local) |
| `4000...9995` | ❌ | ❌ Rechazado | Fondos insuficientes |
| `4000...9979` | ❌ | ❌ Rechazado | Tarjeta reportada como robada |

---

## 🔧 Configuración Necesaria

1. **Inicializar Stripe en `main.dart`:**
   ```dart
   Stripe.publishableKey = StripeConfig.publishableKey;
   ```

2. **Edge Functions de Supabase:**
   - `create-payment-intent` - Crea el Payment Intent
   - `confirm-payment` - Cobra el pago al finalizar viaje

3. **Variables de Entorno:**
   - `EXPO_PUBLIC_STRIPE_PUBLISHABLE_KEY` - Clave pública de Stripe

---

## 📝 Notas Importantes

- **HOLD vs CAPTURE:**
  - **HOLD (ahora):** Reserva el dinero, no lo cobra
  - **CAPTURE (después):** Cobra el dinero cuando el viaje termina

- **3D Secure es Transparente:**
  - El usuario ve el modal de Stripe
  - No necesitas código adicional
  - Funciona automáticamente para todas las tarjetas que lo requieren

- **Seguridad:**
  - Los datos de tarjeta nunca se envían a tu servidor
  - Stripe maneja todo el procesamiento
  - Solo recibes el `paymentIntentId` para referencia

---

## 🚀 Próximos Pasos

1. Verificar que las Edge Functions estén configuradas
2. Probar con todas las tarjetas de prueba
3. Verificar que 3D Secure funcione correctamente
4. Implementar el CAPTURE cuando el viaje termine

