# 🔧 Configuración de Variables de Entorno

## ⚠️ IMPORTANTE: Configuración Requerida

Este proyecto requiere un archivo de variables de entorno para funcionar correctamente. **Sin este archivo, algunas funcionalidades no estarán disponibles**, incluyendo:

- ❌ Botón flotante de WhatsApp
- ❌ Integración con PayPal
- ❌ Conexión con Supabase
- ❌ Autenticación con Firebase

---

## 📝 Pasos para Configurar

### 1. Crear el Archivo de Variables

En la **raíz del proyecto**, crea un archivo llamado exactamente `env` (sin extensión, sin punto):

```
D:\carposv\apps\taxi\fzkt_openstreet\env
```

### 2. Copiar el Contenido de Ejemplo

Puedes usar el archivo `env.example` como base:

```bash
# En PowerShell (Windows)
Copy-Item env.example env

# En bash/terminal (Linux/Mac)
cp env.example env
```

### 3. Configurar las Variables

Abre el archivo `env` y completa los valores:

#### 📱 WhatsApp

```env
WHATSAPP_NUMBER=393921774905
```

- **Formato:** Código de país + número (sin +, sin espacios)
- **Ejemplo Italia:** `393921774905` 
- **Ejemplo España:** `34612345678`

#### 💳 PayPal

```env
PAYPAL_CLIENT_ID=tu_client_id_de_paypal
PAYPAL_SECRET=tu_secret_de_paypal
PAYPAL_MODE=sandbox
```

- **Para pruebas:** Usar `PAYPAL_MODE=sandbox` y credenciales de Sandbox
- **Para producción:** Usar `PAYPAL_MODE=live` y credenciales de producción
- **Obtener credenciales:** https://developer.paypal.com/

#### 🗄️ Supabase

```env
EXPO_PUBLIC_SUPABASE_URL=https://tu-proyecto.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=tu_anon_key_aqui
```

- **Obtener credenciales:** Panel de Supabase → Settings → API

#### 🔐 Firebase

```env
EXPO_PUBLIC_FIREBASE_API_KEY=tu_api_key
EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN=tu-proyecto.firebaseapp.com
EXPO_PUBLIC_FIREBASE_PROJECT_ID=tu-proyecto-id
EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET=tu-proyecto.appspot.com
EXPO_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=123456789
EXPO_PUBLIC_FIREBASE_APP_ID=1:123456789:web:abcdef
EXPO_PUBLIC_FIREBASE_MEASUREMENT_ID=G-XXXXXXXXXX
```

- **Obtener credenciales:** Firebase Console → Project Settings → General → Your apps

---

## ✅ Verificar la Configuración

### Método 1: Ejecutar la App

1. Ejecuta `flutter run` o inicia la app
2. Busca en la consola el mensaje: `✅ Variables de entorno cargadas exitosamente desde env`
3. Prueba el botón flotante de WhatsApp

### Método 2: Revisar el Código

En `lib/main.dart` línea ~25, verifica que se carga correctamente:

```dart
await dotenv.load(fileName: "env");
```

---

## 🚨 Solución de Problemas

### ❌ "Variables de entorno no cargadas"

**Causa:** El archivo `env` no existe o está mal ubicado

**Solución:**
1. Verifica que el archivo se llama exactamente `env` (sin `.txt` ni `.env`)
2. Verifica que está en la raíz del proyecto (mismo nivel que `pubspec.yaml`)
3. Reinicia la aplicación completamente

### ❌ "Número de WhatsApp no configurado"

**Causa:** La variable `WHATSAPP_NUMBER` está vacía o no existe

**Solución:**
1. Abre el archivo `env`
2. Verifica que existe la línea: `WHATSAPP_NUMBER=393921774905`
3. No uses comillas, no dejes espacios
4. Guarda el archivo y reinicia la app

### ❌ El botón de WhatsApp no hace nada

**Causa:** El número de WhatsApp está mal formateado

**Solución:**
1. Verifica que el formato sea: `CodigoPais + Numero` (sin +, sin espacios)
2. Ejemplo correcto: `393921774905`
3. Ejemplo incorrecto: `+39 392 1774905` ❌

---

## 🔒 Seguridad

### ⚠️ NUNCA subas el archivo `env` a git

El archivo `env` ya está en `.gitignore` para evitar que se suba accidentalmente.

### ✅ Solo sube `env.example`

El archivo `env.example` es seguro de subir porque:
- No contiene valores reales
- Sirve como referencia para otros desarrolladores
- Tiene valores de ejemplo o placeholders

---

## 📚 Referencias

- **Flutter DotEnv:** https://pub.dev/packages/flutter_dotenv
- **PayPal Developer:** https://developer.paypal.com/
- **Supabase Docs:** https://supabase.com/docs
- **Firebase Console:** https://console.firebase.google.com/

---

## 🆘 ¿Necesitas Ayuda?

Si tienes problemas con la configuración:

1. Verifica que seguiste todos los pasos
2. Revisa los logs en la consola de Flutter
3. Contacta al equipo de desarrollo: info@lasiciliatour.com

---

**Última actualización:** 4 Diciembre 2025

