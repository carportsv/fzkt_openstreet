# Cambios para Implementar HOLD → CAPTURE en Stripe

## 📋 Resumen

Este documento lista **todos los cambios necesarios** para implementar el flujo HOLD → CAPTURE (autorizar primero, cobrar después) en lugar de cobrar inmediatamente.

---

## 🔧 CAMBIO 1: Actualizar `create-payment-intent` Edge Function

### Ubicación
`supabase/functions/create-payment-intent/index.ts` (en Supabase Dashboard)

### Cambio Necesario

**ANTES (código actual en Supabase):**
```typescript
const paymentIntent = await stripe.paymentIntents.create({
  amount: Math.round(amount),
  currency: currency.toLowerCase(),
  metadata: {
    ride_id: ride_id,
    type: 'ride_payment'
  },
  automatic_payment_methods: {
    enabled: true,
  },
})
```

**DESPUÉS (código nuevo):**
```typescript
const paymentIntent = await stripe.paymentIntents.create({
  amount: Math.round(amount), // Stripe usa centavos
  currency: currency.toLowerCase(),
  capture_method: 'manual', // ⭐ AGREGAR ESTA LÍNEA - HOLD/autorización
  metadata: {
    ride_id: ride_id,
    type: 'ride_payment'
  },
  automatic_payment_methods: {
    enabled: true,
  },
})
```

### Qué hace este cambio
- **`capture_method: 'manual'`** hace que Stripe **autorice** el pago pero **NO lo cobre** inmediatamente
- El dinero se reserva en la tarjeta del cliente
- El pago se cobrará después cuando se llame a `confirm-payment` para capturar

### Cómo aplicarlo
1. Ve a **Supabase Dashboard** > **Edge Functions** > **create-payment-intent**
2. Haz clic en **"Edit"** o **"Update"**
3. Busca la línea donde se crea el Payment Intent
4. Agrega `capture_method: 'manual',` después de `currency`
5. Guarda y despliega

---

## 🔧 CAMBIO 2: Actualizar `confirm-payment` Edge Function

### Ubicación
`supabase/functions/confirm-payment/index.ts` (en Supabase Dashboard)

### Cambio Necesario

**ANTES (código actual en Supabase):**
```typescript
// Confirm the payment intent
const paymentIntent = await stripe.paymentIntents.confirm(
  payment_intent_id,
  {
    payment_method: payment_method_id,
    return_url: 'https://your-app.com/payment-success',
  }
)
```

**DESPUÉS (código nuevo):**
```typescript
// Obtener el Payment Intent para verificar su estado
const paymentIntent = await stripe.paymentIntents.retrieve(payment_intent_id)

// Verificar que el Payment Intent está en un estado válido para capturar
if (paymentIntent.status !== 'requires_capture') {
  return new Response(
    JSON.stringify({ 
      error: `Payment Intent no puede ser capturado. Estado actual: ${paymentIntent.status}`,
      current_status: paymentIntent.status
    }),
    { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

// Capturar el pago (cobrar el dinero que fue autorizado previamente)
const capturedPaymentIntent = await stripe.paymentIntents.capture(payment_intent_id, {
  amount_to_capture: amount ? Math.round(amount) : undefined,
})
```

### Qué hace este cambio
- **Antes:** `confirm()` confirma un Payment Intent con datos de tarjeta (se usa en Flutter)
- **Después:** `capture()` cobra un Payment Intent que ya fue autorizado (HOLD)
- Verifica que el Payment Intent esté en estado `requires_capture` antes de capturar

### Cómo aplicarlo
1. Ve a **Supabase Dashboard** > **Edge Functions** > **confirm-payment**
2. Haz clic en **"Edit"** o **"Update"**
3. Reemplaza todo el bloque de `stripe.paymentIntents.confirm()` con el código nuevo
4. Guarda y despliega

**NOTA:** Puedes eliminar las actualizaciones a `payment_transactions` y `ride_requests` si no las necesitas, o mantenerlas después de capturar.

---

## 🔧 CAMBIO 3: Actualizar Flutter para usar Payment Sheet

### Ubicación
`lib/services/stripe_service.dart` - Método `confirmPaymentIntentWithCard`

### Cambio Necesario

**ANTES (código actual):**
```dart
// Confirmar el Payment Intent con los datos de la tarjeta
final paymentIntent = await Stripe.instance.confirmPayment(
  paymentIntentClientSecret: clientSecret,
  data: PaymentMethodParams.card(
    paymentMethodData: PaymentMethodData(
      billingDetails: cardholderName != null ? BillingDetails(name: cardholderName) : null,
    ),
  ),
);
```

**PROBLEMA:** `PaymentMethodParams.card` no acepta los datos de la tarjeta directamente.

**DESPUÉS (usando Payment Sheet):**
```dart
// 1. Inicializar Payment Sheet
await Stripe.instance.initPaymentSheet(
  paymentSheetParameters: SetupPaymentSheetParameters(
    merchantDisplayName: 'ZKT Taxi',
    paymentIntentClientSecret: clientSecret,
    customerId: null, // Opcional: ID del cliente en Stripe
    style: ThemeMode.light,
    currencyCode: currency.toUpperCase(),
    allowsDelayedPaymentMethods: true,
    billingDetails: cardholderName != null 
        ? BillingDetails(name: cardholderName) 
        : null,
  ),
);

// 2. Presentar Payment Sheet al usuario
final paymentSheetResult = await Stripe.instance.presentPaymentSheet();

// 3. Verificar resultado
if (paymentSheetResult.error != null) {
  if (paymentSheetResult.error!.code == PaymentSheetError.Canceled) {
    return {
      'success': false,
      'status': 'canceled',
      'error': 'Pago cancelado por el usuario.',
    };
  }
  return {
    'success': false,
    'status': 'failed',
    'error': StripeErrorMessages.getErrorMessage(paymentSheetResult.error!.code.toString()),
  };
}

// 4. Obtener el Payment Intent actualizado para verificar estado
final paymentIntent = await Stripe.instance.retrievePaymentIntent(clientSecret);

// 5. Verificar estado final
final status = paymentIntent.status.toString().toLowerCase();
if (status == 'succeeded' || status == 'requires_capture') {
  return {'success': true, 'status': status, 'error': null};
} else {
  return {
    'success': false,
    'status': status,
    'error': 'El pago no se completó correctamente.',
  };
}
```

### Qué hace este cambio
- **Payment Sheet** es la UI de Stripe que maneja la entrada de datos de tarjeta
- El usuario ingresa los datos en el modal de Stripe (más seguro)
- Stripe maneja automáticamente 3D Secure si es requerido
- Funciona con todas las tarjetas, incluyendo `4000002500003155`

### Cómo aplicarlo
1. Abre `lib/services/stripe_service.dart`
2. Busca el método `confirmPaymentIntentWithCard`
3. Reemplaza todo el bloque de `confirmPayment` con el código del Payment Sheet
4. Asegúrate de importar `PaymentSheetError` y `SetupPaymentSheetParameters`

---

## 🔧 CAMBIO 4: Actualizar llamada en `payment_confirmation_screen.dart`

### Ubicación
`lib/screens/welcome/booking/payment_confirmation_screen.dart`

### Cambio Necesario

**ANTES:**
```dart
final confirmationResult = await StripeService.confirmPaymentIntentWithCard(
  clientSecret: paymentIntent.clientSecret,
  cardNumber: _cardNumberController.text.trim().replaceAll(RegExp(r'\s'), ''),
  expMonth: expMonth,
  expYear: expYear,
  cvc: _cardCvvController.text.trim(),
  cardholderName: _cardNameController.text.trim().isNotEmpty
      ? _cardNameController.text.trim()
      : null,
);
```

**DESPUÉS:**
```dart
// Con Payment Sheet, solo necesitamos el clientSecret y el nombre
final confirmationResult = await StripeService.confirmPaymentIntentWithCard(
  clientSecret: paymentIntent.clientSecret,
  currency: paymentIntent.currency,
  cardholderName: _cardNameController.text.trim().isNotEmpty
      ? _cardNameController.text.trim()
      : null,
);
```

### Qué hace este cambio
- Ya no necesitas pasar los datos de la tarjeta (número, exp, CVV)
- Payment Sheet maneja la entrada de datos
- Solo necesitas el `clientSecret` y opcionalmente el nombre del titular

### Cómo aplicarlo
1. Abre `lib/screens/welcome/booking/payment_confirmation_screen.dart`
2. Busca la llamada a `StripeService.confirmPaymentIntentWithCard`
3. Elimina los parámetros `cardNumber`, `expMonth`, `expYear`, `cvc`
4. Agrega `currency: paymentIntent.currency`
5. Mantén solo `clientSecret` y `cardholderName`

---

## 🔧 CAMBIO 5: Actualizar firma del método en `stripe_service.dart`

### Ubicación
`lib/services/stripe_service.dart` - Método `confirmPaymentIntentWithCard`

### Cambio Necesario

**ANTES:**
```dart
static Future<Map<String, dynamic>> confirmPaymentIntentWithCard({
  required String clientSecret,
  required String cardNumber,
  required int expMonth,
  required int expYear,
  required String cvc,
  String? cardholderName,
}) async {
```

**DESPUÉS:**
```dart
static Future<Map<String, dynamic>> confirmPaymentIntentWithCard({
  required String clientSecret,
  required String currency,
  String? cardholderName,
}) async {
```

### Qué hace este cambio
- Simplifica la firma del método
- Ya no necesitas los datos de la tarjeta como parámetros
- Payment Sheet los maneja internamente

### Cómo aplicarlo
1. Abre `lib/services/stripe_service.dart`
2. Busca la firma del método `confirmPaymentIntentWithCard`
3. Elimina los parámetros `cardNumber`, `expMonth`, `expYear`, `cvc`
4. Agrega `required String currency`
5. Actualiza el cuerpo del método con el código del Payment Sheet (CAMBIO 3)

---

## 📝 Resumen de Cambios

| # | Archivo/Ubicación | Cambio Principal | Impacto |
|---|-------------------|------------------|---------|
| 1 | `create-payment-intent` (Supabase) | Agregar `capture_method: 'manual'` | HOLD/autorización |
| 2 | `confirm-payment` (Supabase) | Cambiar `confirm()` a `capture()` | Capturar pago autorizado |
| 3 | `stripe_service.dart` | Usar Payment Sheet en lugar de datos directos | Maneja 3D Secure automáticamente |
| 4 | `payment_confirmation_screen.dart` | Simplificar llamada al método | Menos parámetros |
| 5 | `stripe_service.dart` | Actualizar firma del método | Método más simple |

---

## ✅ Orden de Aplicación Recomendado

1. **Primero:** Cambio 1 (Edge Function `create-payment-intent`)
2. **Segundo:** Cambio 2 (Edge Function `confirm-payment`)
3. **Tercero:** Cambio 5 (Actualizar firma del método)
4. **Cuarto:** Cambio 3 (Implementar Payment Sheet)
5. **Quinto:** Cambio 4 (Actualizar llamada en pantalla)

---

## 🧪 Pruebas Después de los Cambios

1. **Probar con tarjeta exitosa:** `4242 4242 4242 4242`
2. **Probar con 3D Secure:** `4000002500003155` (debe mostrar modal de autenticación)
3. **Probar con tarjeta declinada:** `4000000000000002`
4. **Verificar que el pago se autoriza pero no se cobra** (estado `requires_capture`)
5. **Verificar que al finalizar el viaje se captura el pago** (estado `succeeded`)

---

## 🔄 Si Quieres Cambiar a Cobrar Inmediatamente Después

Solo necesitas:
1. Quitar `capture_method: 'manual'` de `create-payment-intent`
2. Eliminar la llamada a `confirm-payment` para capturar
3. El pago se cobrará automáticamente al confirmar

**Tiempo estimado:** 5-10 minutos

