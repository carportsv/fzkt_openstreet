# 🔐 Configuración de GitHub Secrets

## 📋 ¿Qué son los GitHub Secrets?

Los **GitHub Secrets** son variables de entorno encriptadas que se utilizan en GitHub Actions para almacenar información sensible como:
- Claves API
- Contraseñas
- Tokens de acceso
- Números de teléfono

**Importante:** Nunca debes poner esta información directamente en tu código o archivos que se suben a git.

---

## 🎯 Secrets Requeridos para este Proyecto

### 1. WhatsApp
```
WHATSAPP_NUMBER=393921774905
```

### 2. PayPal
```
PAYPAL_CLIENT_ID=tu_client_id_de_paypal
PAYPAL_SECRET=tu_secret_de_paypal
PAYPAL_MODE=live
```
⚠️ Usa `sandbox` para pruebas, `live` para producción

### 3. Firebase (7 variables)
```
EXPO_PUBLIC_FIREBASE_API_KEY=tu_api_key
EXPO_PUBLIC_FIREBASE_APP_ID=tu_app_id
EXPO_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=tu_sender_id
EXPO_PUBLIC_FIREBASE_PROJECT_ID=tu_project_id
EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN=tu_auth_domain
EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET=tu_storage_bucket
EXPO_PUBLIC_FIREBASE_MEASUREMENT_ID=tu_measurement_id
```

### 4. Supabase (2 variables)
```
EXPO_PUBLIC_SUPABASE_URL=https://tu-proyecto.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=tu_anon_key
```

---

## 📝 Pasos para Agregar Secrets en GitHub

### Paso 1: Ir a la Configuración del Repositorio

1. Ve a tu repositorio en GitHub
2. Haz clic en **Settings** (Configuración)

```
https://github.com/tu-usuario/fzkt_openstreet/settings
```

### Paso 2: Acceder a Secrets

1. En el menú lateral izquierdo, busca **Secrets and variables**
2. Haz clic en **Actions**

```
Settings → Secrets and variables → Actions
```

### Paso 3: Agregar Cada Secret

Para **cada variable** de la lista anterior:

1. Haz clic en el botón verde **"New repository secret"**
2. Completa el formulario:
   - **Name:** El nombre exacto de la variable (ej: `WHATSAPP_NUMBER`)
   - **Secret:** El valor de la variable (ej: `393921774905`)
3. Haz clic en **"Add secret"**

---

## 🖼️ Guía Visual Paso a Paso

### 1. Settings del Repositorio
```
┌─────────────────────────────────────────────────┐
│  tu-repo                                    ★   │
├─────────────────────────────────────────────────┤
│  < > Code   Issues   Pull requests   Settings  │ ← Clic aquí
└─────────────────────────────────────────────────┘
```

### 2. Menú de Secrets
```
┌─────────────────────────────────────────┐
│  General                                │
│  Access                                 │
│  Collaborators                          │
│  ...                                    │
│  ▼ Secrets and variables                │
│    → Actions                            │ ← Clic aquí
│    → Codespaces                         │
│    → Dependabot                         │
└─────────────────────────────────────────┘
```

### 3. Agregar Secret
```
┌──────────────────────────────────────────────────┐
│  Repository secrets                              │
│                                                  │
│  [New repository secret]  ← Clic aquí           │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │ Name*                                      │ │
│  │ WHATSAPP_NUMBER                            │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │ Secret*                                    │ │
│  │ 393921774905                               │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
│  [Add secret]                                   │
└──────────────────────────────────────────────────┘
```

---

## ✅ Lista de Verificación

Marca cada variable que hayas agregado:

### WhatsApp (1)
- [ ] `WHATSAPP_NUMBER`

### PayPal (3)
- [ ] `PAYPAL_CLIENT_ID`
- [ ] `PAYPAL_SECRET`
- [ ] `PAYPAL_MODE`

### Firebase (7)
- [ ] `EXPO_PUBLIC_FIREBASE_API_KEY`
- [ ] `EXPO_PUBLIC_FIREBASE_APP_ID`
- [ ] `EXPO_PUBLIC_FIREBASE_MESSAGING_SENDER_ID`
- [ ] `EXPO_PUBLIC_FIREBASE_PROJECT_ID`
- [ ] `EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN`
- [ ] `EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET`
- [ ] `EXPO_PUBLIC_FIREBASE_MEASUREMENT_ID`

### Supabase (2)
- [ ] `EXPO_PUBLIC_SUPABASE_URL`
- [ ] `EXPO_PUBLIC_SUPABASE_ANON_KEY`

**Total: 13 secrets** ✓

---

## 🔍 Verificar que Funcionan los Secrets

### Método 1: Revisar el Workflow

1. Ve a la pestaña **Actions** de tu repositorio
2. Busca el último workflow ejecutado
3. Haz clic en el job **"build-and-deploy"**
4. Expande el paso **"Create env file from secrets"**
5. Deberías ver algo como:
   ```
   WHATSAPP_NUMBER=***
   PAYPAL_CLIENT_ID=***
   ```
   (Los valores aparecen ocultos por seguridad)

### Método 2: Forzar un Nuevo Deployment

1. Ve a **Actions**
2. Haz clic en **"Deploy Flutter Web to GitHub Pages"**
3. Haz clic en **"Run workflow"** (a la derecha)
4. Selecciona la rama **main**
5. Haz clic en **"Run workflow"**

Esto ejecutará el deployment manualmente y creará el archivo `env` con todos tus secrets.

---

## ⚠️ Problemas Comunes

### ❌ "Secret not found"

**Causa:** El nombre del secret está mal escrito

**Solución:** 
- Los nombres deben ser **exactamente** iguales
- Son **case-sensitive** (distinguen mayúsculas/minúsculas)
- No uses espacios ni caracteres especiales

### ❌ El workflow falla en "Create env file"

**Causa:** Falta algún secret

**Solución:**
1. Revisa el log del workflow
2. Busca qué variable está vacía
3. Agrégala en Settings → Secrets

### ❌ El botón de WhatsApp sigue sin funcionar

**Causa:** El workflow no se ha ejecutado después de agregar los secrets

**Solución:**
1. Haz un commit y push
2. O ejecuta el workflow manualmente (método 2 arriba)
3. Espera a que termine el deployment

---

## 🔒 Seguridad de los Secrets

### ✅ Buenas Prácticas

1. **Nunca** compartas tus secrets públicamente
2. **Nunca** los pongas en el código o commits
3. **Cambia** los secrets si sospechas que fueron comprometidos
4. **Usa** secrets de Sandbox/Desarrollo para pruebas
5. **Limita** el acceso al repositorio solo a personas de confianza

### 🚨 Si un Secret se Compromete

1. Ve inmediatamente a GitHub Settings → Secrets
2. Elimina el secret comprometido
3. Genera un nuevo valor (ej: nueva API key)
4. Agrega el nuevo secret
5. Ejecuta el workflow de nuevo

---

## 📚 Referencias

- **GitHub Secrets Docs:** https://docs.github.com/en/actions/security-guides/encrypted-secrets
- **GitHub Actions:** https://docs.github.com/en/actions
- **PayPal Developer:** https://developer.paypal.com/
- **Firebase Console:** https://console.firebase.google.com/
- **Supabase Dashboard:** https://app.supabase.com/

---

## 🆘 ¿Necesitas Ayuda?

Si tienes problemas configurando los secrets:

1. Verifica que seguiste todos los pasos
2. Revisa los logs del workflow en Actions
3. Consulta la documentación oficial de GitHub
4. Contacta al equipo: info@lasiciliatour.com

---

**Última actualización:** 4 Diciembre 2025, 22:30 hrs

