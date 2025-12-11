# Configuración de Edge Functions de Stripe

## 📋 Resumen

Este documento explica cómo crear y desplegar las Edge Functions de Stripe necesarias para procesar pagos.

## 🔧 Edge Functions Requeridas

1. **`create-payment-intent`** - Crea un Payment Intent (HOLD/autorización)
2. **`confirm-payment`** - Captura el pago al finalizar el viaje
3. **`create-setup-intent`** - Crea un Setup Intent para guardar tarjetas (opcional)

---

## 📦 Opción 1: Desplegar desde Supabase Dashboard (Recomendado)

### Paso 1: Verificar que STRIPE_SECRET_KEY está configurado

1. Ve a **Supabase Dashboard** > **Project Settings** > **Edge Functions** > **Secrets**
2. Verifica que existe `STRIPE_SECRET_KEY` con tu clave secreta de Stripe
3. Si no existe, agrega:
   - **Nombre:** `STRIPE_SECRET_KEY`
   - **Valor:** Tu clave secreta de Stripe (empieza con `sk_test_` o `sk_live_`)

### Paso 2: Crear Edge Function `create-payment-intent`

1. Ve a **Supabase Dashboard** > **Edge Functions**
2. Haz clic en **"Create a new function"**
3. **Nombre:** `create-payment-intent`
4. **Código:** Copia el contenido de `supabase/functions/create-payment-intent/index.ts`
5. Haz clic en **"Deploy"**

### Paso 3: Crear Edge Function `confirm-payment`

1. Ve a **Supabase Dashboard** > **Edge Functions**
2. Haz clic en **"Create a new function"**
3. **Nombre:** `confirm-payment`
4. **Código:** Copia el contenido de `supabase/functions/confirm-payment/index.ts`
5. Haz clic en **"Deploy"**

### Paso 4: Crear Edge Function `create-setup-intent` (Opcional)

1. Ve a **Supabase Dashboard** > **Edge Functions**
2. Haz clic en **"Create a new function"**
3. **Nombre:** `create-setup-intent`
4. **Código:** Copia el contenido de `supabase/functions/create-setup-intent/index.ts`
5. Haz clic en **"Deploy"**

---

## 🚀 Opción 2: Desplegar usando Supabase CLI

### Requisitos Previos

1. Instalar Supabase CLI:
   ```bash
   npm install -g supabase
   ```

2. Iniciar sesión:
   ```bash
   supabase login
   ```

3. Vincular tu proyecto:
   ```bash
   supabase link --project-ref tu-project-ref
   ```
   (Encuentra tu `project-ref` en Supabase Dashboard > Project Settings > General)

### Desplegar las Funciones

```bash
# Desplegar create-payment-intent
supabase functions deploy create-payment-intent

# Desplegar confirm-payment
supabase functions deploy confirm-payment

# Desplegar create-setup-intent (opcional)
supabase functions deploy create-setup-intent
```

### Configurar Secret

```bash
# Configurar STRIPE_SECRET_KEY
supabase secrets set STRIPE_SECRET_KEY=sk_test_tu_clave_secreta_aqui
```

---

## ✅ Verificación

### 1. Verificar que las funciones están desplegadas

1. Ve a **Supabase Dashboard** > **Edge Functions**
2. Debes ver las 3 funciones listadas:
   - ✅ `create-payment-intent`
   - ✅ `confirm-payment`
   - ✅ `create-setup-intent`

### 2. Probar `create-payment-intent` manualmente

1. Ve a **Supabase Dashboard** > **Edge Functions** > **create-payment-intent**
2. Haz clic en **"Invoke"** o **"Test"**
3. Usa este payload:
   ```json
   {
     "ride_id": "test-ride-123",
     "amount": 5000,
     "currency": "usd"
   }
   ```
4. Debes recibir una respuesta con `client_secret` y `id`

### 3. Verificar los logs

1. Ve a **Supabase Dashboard** > **Edge Functions** > **create-payment-intent** > **Logs**
2. Debes ver logs cuando se invoca la función
3. Si hay errores, revisa:
   - Que `STRIPE_SECRET_KEY` esté configurado correctamente
   - Que la clave secreta sea válida (no esté expirada)
   - Que tengas permisos en tu cuenta de Stripe

---

## 🔍 Troubleshooting

### Error: "STRIPE_SECRET_KEY is not defined"

**Solución:**
1. Ve a **Supabase Dashboard** > **Project Settings** > **Edge Functions** > **Secrets**
2. Agrega `STRIPE_SECRET_KEY` con tu clave secreta de Stripe

### Error: "Invalid API Key"

**Solución:**
1. Verifica que estás usando la clave secreta correcta (empieza con `sk_test_` o `sk_live_`)
2. Verifica que la clave no esté expirada
3. En modo prueba, usa `sk_test_...`
4. En producción, usa `sk_live_...`

### Error: "Function not found"

**Solución:**
1. Verifica que la función esté desplegada
2. Verifica que el nombre de la función sea exactamente `create-payment-intent`, `confirm-payment`, o `create-setup-intent`
3. Espera unos minutos después del despliegue para que esté disponible

### Error: CORS

**Solución:**
Las funciones ya incluyen headers CORS. Si aún tienes problemas:
1. Verifica que estás llamando desde un origen permitido
2. Verifica que los headers CORS estén en la respuesta

---

## 📝 Notas Importantes

1. **Modo de Prueba vs Producción:**
   - En desarrollo, usa `sk_test_...`
   - En producción, usa `sk_live_...`
   - Cambia el secret en Supabase según el entorno

2. **Seguridad:**
   - **NUNCA** expongas `STRIPE_SECRET_KEY` en el código del cliente
   - Solo úsalo en Edge Functions (servidor)
   - Las Edge Functions ya están configuradas para usar el secret de forma segura

3. **Monitoreo:**
   - Revisa los logs regularmente en Supabase Dashboard
   - Configura alertas en Stripe Dashboard para errores de pago
   - Monitorea el uso de las Edge Functions

4. **Límites:**
   - Las Edge Functions de Supabase tienen límites de tiempo de ejecución
   - Las llamadas a Stripe son rápidas, así que no deberías tener problemas
   - Si tienes muchos pagos simultáneos, considera usar colas

---

## 🎯 Próximos Pasos

Después de desplegar las Edge Functions:

1. ✅ Verifica que funcionan con las pruebas manuales
2. ✅ Actualiza el código Flutter para usar Payment Sheet
3. ✅ Prueba con tarjetas de prueba de Stripe
4. ✅ Verifica que 3D Secure funciona correctamente
5. ✅ Prueba el flujo completo: crear viaje → autorizar pago → finalizar viaje → capturar pago

---

## 📚 Referencias

- [Documentación de Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [Documentación de Stripe API](https://stripe.com/docs/api)
- [Stripe Payment Intents](https://stripe.com/docs/payments/payment-intents)
- [Stripe Test Cards](https://stripe.com/docs/testing)

