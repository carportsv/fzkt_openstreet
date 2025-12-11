# Cómo Corregir Errores TypeScript en Archivos de Supabase

## ⚠️ Errores que Aparecen

Si ves estos errores en los archivos `.ts` de Supabase:

```
Cannot find module 'https://deno.land/std@0.168.0/http/server.ts'
Cannot find module 'https://esm.sh/stripe@14.21.0?target=deno'
Cannot find name 'Deno'
```

## ✅ Solución: Configurar Deno en el IDE

### Opción 1: Instalar Extensión Deno (Recomendado)

1. **Instalar extensión Deno:**
   - Abre VS Code/Cursor
   - Ve a Extensions (Ctrl+Shift+X)
   - Busca "Deno" (por Deno Land)
   - Instala la extensión

2. **La configuración ya está lista:**
   - He creado `.vscode/settings.json` con la configuración de Deno
   - Solo necesitas instalar la extensión
   - Los errores desaparecerán automáticamente

### Opción 2: Ignorar los Errores (Si no quieres instalar Deno)

**Los errores NO afectan el funcionamiento:**
- ✅ Solo aparecen en el IDE
- ✅ NO afectan el despliegue en Supabase
- ✅ NO afectan la ejecución de las Edge Functions
- ✅ Puedes ignorarlos si todo funciona en Supabase

---

## 📝 Configuración Creada

He agregado a `.vscode/settings.json`:

```json
{
  "deno.enable": true,
  "deno.enablePaths": [
    "./supabase/functions"
  ],
  "deno.lint": true,
  "deno.unstable": false,
  "[typescript]": {
    "editor.defaultFormatter": "denoland.vscode-deno"
  }
}
```

Esto le dice al IDE que:
- Use Deno para los archivos en `supabase/functions`
- Reconozca las importaciones desde URLs
- Reconozca el objeto global `Deno`

---

## 🔄 Después de Instalar la Extensión

1. **Recarga el IDE:**
   - Cierra y abre VS Code/Cursor
   - O usa: Ctrl+Shift+P > "Reload Window"

2. **Verifica que funcionó:**
   - Los errores TypeScript deberían desaparecer
   - El IDE reconocerá las importaciones de Deno

3. **Si aún aparecen errores:**
   - Espera unos segundos (el IDE necesita descargar tipos)
   - Recarga el IDE nuevamente
   - Verifica que la extensión Deno esté activada

---

## ❓ ¿Afecta el Código en Supabase?

**NO.** Estos errores:
- Son solo del IDE (TypeScript local)
- NO afectan el código en Supabase
- Supabase usa Deno, que SÍ entiende estas importaciones
- Las funciones funcionarán perfectamente

---

## 📚 Resumen

- ✅ Configuración de Deno agregada a `.vscode/settings.json`
- ✅ Instala la extensión "Deno" en VS Code/Cursor
- ✅ Los errores desaparecerán automáticamente
- ✅ Si no instalas la extensión, puedes ignorar los errores (no afectan)

