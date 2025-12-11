-- =====================================================
-- CONFIGURACIÓN DE BUCKETS DE STORAGE PARA DRIVER Y VEHICLE
-- =====================================================
-- Este script crea los buckets necesarios para almacenar
-- las fotos del conductor y del vehículo, y configura
-- las políticas de acceso apropiadas.
-- =====================================================
-- IMPORTANTE: Ejecutar en Supabase Dashboard > SQL Editor
-- =====================================================

-- =====================================================
-- PASO 1: CREAR BUCKET PARA FOTOS DEL CONDUCTOR
-- =====================================================
-- Verificar si el bucket ya existe
DO $$
BEGIN
  -- Intentar crear el bucket driver-photos
  IF NOT EXISTS (
    SELECT 1 FROM storage.buckets WHERE id = 'driver-photos'
  ) THEN
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES (
      'driver-photos',
      'driver-photos',
      true, -- Público para acceso directo a URLs
      5242880, -- 5MB límite de tamaño
      ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp'] -- Tipos MIME permitidos
    );
    RAISE NOTICE '✅ Bucket driver-photos creado exitosamente';
  ELSE
    RAISE NOTICE '⚠️ El bucket driver-photos ya existe';
  END IF;
END $$;

-- =====================================================
-- PASO 2: CREAR BUCKET PARA FOTOS DEL VEHÍCULO
-- =====================================================
DO $$
BEGIN
  -- Intentar crear el bucket vehicle-photos
  IF NOT EXISTS (
    SELECT 1 FROM storage.buckets WHERE id = 'vehicle-photos'
  ) THEN
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES (
      'vehicle-photos',
      'vehicle-photos',
      true, -- Público para acceso directo a URLs
      5242880, -- 5MB límite de tamaño
      ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp'] -- Tipos MIME permitidos
    );
    RAISE NOTICE '✅ Bucket vehicle-photos creado exitosamente';
  ELSE
    RAISE NOTICE '⚠️ El bucket vehicle-photos ya existe';
  END IF;
END $$;

-- =====================================================
-- PASO 3: POLÍTICAS DE ACCESO PARA driver-photos
-- =====================================================

-- Eliminar políticas existentes si existen (para evitar duplicados)
DROP POLICY IF EXISTS "Permitir lectura pública de driver-photos" ON storage.objects;
DROP POLICY IF EXISTS "Permitir escritura autenticada de driver-photos" ON storage.objects;
DROP POLICY IF EXISTS "Permitir actualización autenticada de driver-photos" ON storage.objects;
DROP POLICY IF EXISTS "Permitir eliminación autenticada de driver-photos" ON storage.objects;

-- Política 1: Lectura pública (cualquiera puede ver las fotos)
CREATE POLICY "Permitir lectura pública de driver-photos"
ON storage.objects
FOR SELECT
USING (bucket_id = 'driver-photos');

-- Política 2: Escritura autenticada (solo usuarios autenticados pueden subir)
CREATE POLICY "Permitir escritura autenticada de driver-photos"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'driver-photos' 
  AND auth.role() = 'authenticated'
);

-- Política 3: Actualización autenticada (usuarios autenticados pueden actualizar)
-- Nota: La estructura es drivers/{userId}/{filename}
-- Se puede restringir más verificando que el userId en la ruta corresponda al usuario
CREATE POLICY "Permitir actualización autenticada de driver-photos"
ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'driver-photos' 
  AND auth.role() = 'authenticated'
);

-- Política 4: Eliminación autenticada (usuarios autenticados pueden eliminar)
CREATE POLICY "Permitir eliminación autenticada de driver-photos"
ON storage.objects
FOR DELETE
USING (
  bucket_id = 'driver-photos' 
  AND auth.role() = 'authenticated'
);

DO $$
BEGIN
  RAISE NOTICE '✅ Políticas de acceso para driver-photos configuradas';
END $$;

-- =====================================================
-- PASO 4: POLÍTICAS DE ACCESO PARA vehicle-photos
-- =====================================================

-- Eliminar políticas existentes si existen (para evitar duplicados)
DROP POLICY IF EXISTS "Permitir lectura pública de vehicle-photos" ON storage.objects;
DROP POLICY IF EXISTS "Permitir escritura autenticada de vehicle-photos" ON storage.objects;
DROP POLICY IF EXISTS "Permitir actualización autenticada de vehicle-photos" ON storage.objects;
DROP POLICY IF EXISTS "Permitir eliminación autenticada de vehicle-photos" ON storage.objects;

-- Política 1: Lectura pública (cualquiera puede ver las fotos)
CREATE POLICY "Permitir lectura pública de vehicle-photos"
ON storage.objects
FOR SELECT
USING (bucket_id = 'vehicle-photos');

-- Política 2: Escritura autenticada (solo usuarios autenticados pueden subir)
CREATE POLICY "Permitir escritura autenticada de vehicle-photos"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'vehicle-photos' 
  AND auth.role() = 'authenticated'
);

-- Política 3: Actualización autenticada (usuarios autenticados pueden actualizar)
-- Nota: La estructura es vehicles/{driverId}/{filename}
CREATE POLICY "Permitir actualización autenticada de vehicle-photos"
ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'vehicle-photos' 
  AND auth.role() = 'authenticated'
);

-- Política 4: Eliminación autenticada (usuarios autenticados pueden eliminar)
CREATE POLICY "Permitir eliminación autenticada de vehicle-photos"
ON storage.objects
FOR DELETE
USING (
  bucket_id = 'vehicle-photos' 
  AND auth.role() = 'authenticated'
);

DO $$
BEGIN
  RAISE NOTICE '✅ Políticas de acceso para vehicle-photos configuradas';
END $$;

-- =====================================================
-- VERIFICACIÓN
-- =====================================================
-- Verificar que los buckets fueron creados correctamente
SELECT 
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types,
  created_at
FROM storage.buckets
WHERE id IN ('driver-photos', 'vehicle-photos')
ORDER BY id;

-- Verificar las políticas creadas
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'objects'
  AND (policyname LIKE '%driver-photos%' OR policyname LIKE '%vehicle-photos%')
ORDER BY policyname;

-- =====================================================
-- NOTAS IMPORTANTES
-- =====================================================
-- 1. Los buckets son PÚBLICOS, lo que significa que las URLs
--    de las imágenes serán accesibles sin autenticación.
--
-- 2. Solo usuarios autenticados pueden subir, actualizar o
--    eliminar imágenes.
--
-- 3. El límite de tamaño por archivo es de 5MB.
--
-- 4. Solo se permiten formatos de imagen: JPEG, JPG, PNG, WEBP.
--
-- 5. La estructura de carpetas será:
--    - driver-photos/drivers/{userId}/{filename}
--    - vehicle-photos/vehicles/{driverId}/{filename}
--
-- 6. Si necesitas cambiar las políticas, primero elimínalas
--    con DROP POLICY y luego créalas nuevamente.
-- =====================================================

