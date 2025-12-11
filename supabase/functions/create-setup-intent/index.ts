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
