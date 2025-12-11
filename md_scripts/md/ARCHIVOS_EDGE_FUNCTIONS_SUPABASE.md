# Archivos Completos de Edge Functions para Supabase

## 📋 Instrucciones

Copia y pega el contenido completo de cada archivo en Supabase Dashboard > Edge Functions.

---

## 🔧 ARCHIVO 1: `create-payment-intent`

### Ubicación en Supabase
**Supabase Dashboard** > **Edge Functions** > **create-payment-intent** > **Edit**

### Código Completo

```typescript
// Edge Function: create-payment-intent
// Crea un Payment Intent en Stripe con capture_method: 'manual' (HOLD/autorización)
// El pago se capturará después cuando se confirme al finalizar el viaje

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
})

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Manejar CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { ride_id, amount, currency = 'usd' } = await req.json()

    // Validar parámetros requeridos
    if (!ride_id) {
      return new Response(
        JSON.stringify({ error: 'ride_id es requerido' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!amount || amount <= 0) {
      return new Response(
        JSON.stringify({ error: 'amount debe ser mayor a 0' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Crear Payment Intent en Stripe
    // capture_method: 'manual' significa que solo se autoriza, no se cobra
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount), // Stripe usa centavos
      currency: currency.toLowerCase(),
      capture_method: 'manual', // ⭐ HOLD - solo autorizar, no cobrar
      metadata: {
        ride_id: ride_id,
        type: 'ride_payment'
      },
      automatic_payment_methods: {
        enabled: true,
      },
    })

    console.log(`✅ Payment Intent creado: ${paymentIntent.id} para ride: ${ride_id}`)

    return new Response(
      JSON.stringify({
        id: paymentIntent.id,
        client_secret: paymentIntent.client_secret,
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
        status: paymentIntent.status,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('❌ Error creando Payment Intent:', error)
    return new Response(
      JSON.stringify({ 
        error: error.message || 'Error al crear Payment Intent',
        details: error.toString()
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

### Cambio Principal
- **Agregado:** `capture_method: 'manual'` en la línea donde se crea el Payment Intent
- **Efecto:** Hace HOLD/autorización en lugar de cobrar inmediatamente

---

## 🔧 ARCHIVO 2: `confirm-payment`

### Ubicación en Supabase
**Supabase Dashboard** > **Edge Functions** > **confirm-payment** > **Edit**

### Código Completo

```typescript
// Edge Function: confirm-payment
// Captura (cobra) un Payment Intent que fue autorizado previamente
// Se llama cuando el viaje termina para procesar el pago final

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
})

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Manejar CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { payment_intent_id, ride_id, user_id, driver_id, amount } = await req.json()

    // Validar parámetros requeridos
    if (!payment_intent_id) {
      return new Response(
        JSON.stringify({ error: 'payment_intent_id es requerido' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!ride_id) {
      return new Response(
        JSON.stringify({ error: 'ride_id es requerido' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

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
      amount_to_capture: amount ? Math.round(amount) : undefined, // Si se especifica, capturar ese monto específico
    })

    console.log(`✅ Pago capturado: ${capturedPaymentIntent.id} para ride: ${ride_id}`)

    // Actualizar el estado en la base de datos si se proporcionan los IDs
    if (user_id && driver_id) {
      try {
        const supabaseClient = createClient(
          Deno.env.get('SUPABASE_URL') ?? '',
          Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // Actualizar el estado del viaje
        const { error: rideError } = await supabaseClient
          .from('ride_requests')
          .update({
            payment_status: 'paid',
            updated_at: new Date().toISOString()
          })
          .eq('id', ride_id)

        if (rideError) {
          console.error('⚠️ Error actualizando ride_requests:', rideError)
          // No fallar la respuesta si la actualización de BD falla
        } else {
          console.log(`✅ Estado del viaje actualizado: ${ride_id}`)
        }
      } catch (dbError) {
        console.error('⚠️ Error actualizando base de datos:', dbError)
        // No fallar la respuesta si la actualización de BD falla
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        payment_intent_id: capturedPaymentIntent.id,
        status: capturedPaymentIntent.status,
        amount_captured: capturedPaymentIntent.amount_received,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('❌ Error capturando pago:', error)
    return new Response(
      JSON.stringify({ 
        error: error.message || 'Error al capturar el pago',
        details: error.toString()
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

### Cambio Principal
- **Cambiado:** De `stripe.paymentIntents.confirm()` a `stripe.paymentIntents.capture()`
- **Agregado:** Verificación de estado `requires_capture` antes de capturar
- **Efecto:** Captura un pago ya autorizado en lugar de confirmar con datos de tarjeta

---

## 🔧 ARCHIVO 3: `create-setup-intent` (Opcional)

### Ubicación en Supabase
**Supabase Dashboard** > **Edge Functions** > **create-setup-intent** > **Edit**

### Código Completo

```typescript
// Edge Function: create-setup-intent
// Crea un Setup Intent en Stripe para guardar métodos de pago
// Permite guardar tarjetas para pagos futuros sin procesar un pago inmediato

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
})

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Manejar CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Crear Setup Intent en Stripe
    const setupIntent = await stripe.setupIntents.create({
      payment_method_types: ['card'],
      usage: 'off_session', // Permite usar la tarjeta guardada para pagos futuros
    })

    console.log(`✅ Setup Intent creado: ${setupIntent.id}`)

    return new Response(
      JSON.stringify({
        id: setupIntent.id,
        client_secret: setupIntent.client_secret,
        status: setupIntent.status,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('❌ Error creando Setup Intent:', error)
    return new Response(
      JSON.stringify({ 
        error: error.message || 'Error al crear Setup Intent',
        details: error.toString()
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

### Cambio Principal
- **Agregado:** `usage: 'off_session'` para permitir pagos futuros
- **Efecto:** Permite guardar tarjetas para uso posterior

---

## ✅ Pasos para Aplicar en Supabase

1. **Ve a Supabase Dashboard** > **Edge Functions**

2. **Para `create-payment-intent`:**
   - Haz clic en **create-payment-intent**
   - Haz clic en **"Edit"** o **"Update"**
   - Reemplaza TODO el código con el código del ARCHIVO 1
   - Haz clic en **"Deploy"** o **"Save"**

3. **Para `confirm-payment`:**
   - Haz clic en **confirm-payment**
   - Haz clic en **"Edit"** o **"Update"**
   - Reemplaza TODO el código con el código del ARCHIVO 2
   - Haz clic en **"Deploy"** o **"Save"**

4. **Para `create-setup-intent` (opcional):**
   - Haz clic en **create-setup-intent**
   - Haz clic en **"Edit"** o **"Update"**
   - Reemplaza TODO el código con el código del ARCHIVO 3
   - Haz clic en **"Deploy"** o **"Save"**

---

## 🧪 Verificar que Funciona

1. **Probar `create-payment-intent`:**
   - Ve a la función en Supabase Dashboard
   - Haz clic en **"Invoke"** o **"Test"**
   - Usa este payload:
     ```json
     {
       "ride_id": "test-123",
       "amount": 5000,
       "currency": "usd"
     }
     ```
   - Debe retornar un `client_secret` y `status: "requires_payment_method"`

2. **Verificar logs:**
   - Ve a **Logs** de cada función
   - Debes ver mensajes como `✅ Payment Intent creado: pi_...`

3. **Probar desde Flutter:**
   - Ejecuta la app
   - Intenta crear un viaje con pago con tarjeta
   - Debe mostrar el Payment Sheet de Stripe
   - Debe funcionar con la tarjeta `4000002500003155` (3D Secure)

---

## 📝 Notas Importantes

- **Versión de Stripe:** Se actualizó a `14.21.0` (la actual usa `12.0.0`, ambas funcionan)
- **CORS:** Ya está configurado en todas las funciones
- **Errores:** Todas las funciones tienen manejo de errores completo
- **Logs:** Todas las funciones tienen `console.log` para debugging

