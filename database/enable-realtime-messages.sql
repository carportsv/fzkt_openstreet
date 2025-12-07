-- Script para habilitar Realtime en la tabla messages de Supabase
-- Ejecutar en Supabase Dashboard > SQL Editor
--
-- IMPORTANTE: Esto es necesario para que las notificaciones en tiempo real funcionen
-- en la aplicación Flutter cuando se asignan viajes a los drivers

-- 1. Verificar si la publicación de Realtime existe
SELECT * FROM pg_publication WHERE pubname = 'supabase_realtime';

-- 2. Verificar si messages ya está en la publicación (antes de agregar)
SELECT 
    schemaname,
    tablename,
    pubname
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime' 
AND tablename = 'messages';

-- 3. Agregar la tabla messages a la publicación de Realtime
-- Si ya existe, esto dará un error pero no es crítico
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE messages;
        RAISE NOTICE 'Tabla messages agregada a Realtime';
    ELSE
        RAISE NOTICE 'Tabla messages ya está en Realtime';
    END IF;
END $$;

-- 4. Verificar que la tabla fue agregada correctamente
SELECT 
    schemaname,
    tablename,
    pubname
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime' 
AND tablename = 'messages';

-- Si esta consulta NO retorna ninguna fila, significa que Realtime NO está habilitado

-- 4. Verificar todas las tablas en la publicación (para referencia)
SELECT 
    schemaname,
    tablename,
    pubname
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime'
ORDER BY tablename;

-- 5. Verificar configuración de la tabla messages
SELECT 
    table_name,
    table_type,
    table_schema
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name = 'messages';

-- NOTA: Si la tabla messages no aparece en pg_publication_tables después de ejecutar
-- el ALTER PUBLICATION, verifica que:
-- 1. La tabla messages existe en el esquema public
-- 2. Tienes permisos de administrador en Supabase
-- 3. La publicación supabase_realtime existe

