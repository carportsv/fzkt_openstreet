# Script de Verificación de Edge Functions de Stripe

## 🔍 Cómo Verificar que las Edge Functions Están Funcionando

### Paso 1: Verificar en Supabase Dashboard

1. Ve a **Supabase Dashboard** > **Edge Functions**
2. Debes ver estas funciones:
   - ✅ `create-payment-intent`
   - ✅ `confirm-payment`
   - ✅ `create-setup-intent`

### Paso 2: Probar `create-payment-intent`

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
4. **Resultado esperado:**
   ```json
   {
     "id": "pi_...",
     "client_secret": "pi_..._secret_...",
     "amount": 5000,
     "currency": "usd",
     "status": "requires_payment_method"
   }
   ```

### Paso 3: Verificar Logs

1. Ve a **Supabase Dashboard** > **Edge Functions** > **create-payment-intent** > **Logs**
2. Debes ver logs como:
   ```
   ✅ Payment Intent creado: pi_... para ride: test-ride-123
   ```

### Paso 4: Verificar Secret

1. Ve a **Supabase Dashboard** > **Project Settings** > **Edge Functions** > **Secrets**
2. Debes ver:
   - ✅ `STRIPE_SECRET_KEY` (con SHA256 digest visible)

### Paso 5: Probar desde Flutter

1. Ejecuta la app Flutter
2. Intenta crear un viaje con pago con tarjeta
3. Verifica en los logs de Supabase que se llama a `create-payment-intent`
4. Verifica que recibes un `client_secret` en la respuesta

---

## ❌ Si Algo No Funciona

### Error: "Function not found"
- Verifica que la función esté desplegada
- Verifica el nombre exacto de la función
- Espera unos minutos después del despliegue

### Error: "STRIPE_SECRET_KEY is not defined"
- Ve a Secrets y agrega `STRIPE_SECRET_KEY`
- Verifica que el nombre sea exactamente `STRIPE_SECRET_KEY`

### Error: "Invalid API Key"
- Verifica que la clave secreta sea válida
- Verifica que empiece con `sk_test_` o `sk_live_`
- Verifica que no esté expirada

### No hay logs
- Verifica que la función esté desplegada
- Verifica que se esté llamando desde Flutter
- Revisa los logs de la app Flutter para ver errores

