-- =====================================================
-- AGREGAR COLUMNA notifications_enabled A TABLA drivers
-- =====================================================
-- Este script agrega la columna notifications_enabled
-- para permitir a los drivers activar/desactivar notificaciones
-- =====================================================

-- Agregar columna notifications_enabled (default: true)
ALTER TABLE drivers 
ADD COLUMN IF NOT EXISTS notifications_enabled BOOLEAN DEFAULT true;

-- Actualizar todos los drivers existentes a true (por defecto)
UPDATE drivers 
SET notifications_enabled = true 
WHERE notifications_enabled IS NULL;

-- Comentario en la columna
COMMENT ON COLUMN drivers.notifications_enabled IS 'Permite al driver activar/desactivar notificaciones push. true = activadas, false = desactivadas';

-- =====================================================
-- VERIFICACIÓN
-- =====================================================
-- Verificar que la columna se creó correctamente:
SELECT 
  column_name,
  data_type,
  column_default,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'drivers' 
  AND column_name = 'notifications_enabled';

-- Verificar drivers con notificaciones activadas/desactivadas:
SELECT 
  COUNT(*) FILTER (WHERE notifications_enabled = true) as activadas,
  COUNT(*) FILTER (WHERE notifications_enabled = false) as desactivadas,
  COUNT(*) FILTER (WHERE notifications_enabled IS NULL) as sin_configurar
FROM drivers;

