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
