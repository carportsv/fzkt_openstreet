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
