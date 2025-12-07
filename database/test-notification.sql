-- Script para enviar notificaciones de prueba a un driver
-- Ejecutar en Supabase Dashboard > SQL Editor
--
-- Este script automáticamente obtiene un driver_id y envía notificaciones de prueba

-- ============================================
-- OPCIÓN 1: Enviar a un driver específico
-- ============================================
-- Si quieres enviar a un driver específico, descomenta y reemplaza el UUID:
-- DO $$
-- DECLARE
--     test_driver_id UUID := '68557629-3085-4b61-acee-f3f575c1c500';  -- Reemplaza con el ID del driver
-- BEGIN
--     INSERT INTO messages (type, title, message, data, driver_id, is_read, created_at)
--     VALUES (
--         'ride_request',
--         '🚗 Viaje de Prueba',
--         'Esta es una notificación de prueba. Origen: Test Location → Destino: Test Destination',
--         '{"ride_id": "test-123", "action": "driver_accept_reject", "test": true}'::jsonb,
--         test_driver_id,
--         false,
--         NOW()
--     );
--     RAISE NOTICE 'Notificación de prueba enviada a driver %', test_driver_id;
-- END $$;

-- ============================================
-- OPCIÓN 2: Enviar a Fred (fred.wicket.us@gmail.com) - AUTOMÁTICO
-- ============================================
-- Esta opción automáticamente obtiene el driver_id de Fred y envía la notificación
DO $$
DECLARE
    test_driver_id UUID;
    driver_email TEXT;
BEGIN
    -- Obtener el driver_id de Fred por su email
    SELECT d.id, u.email INTO test_driver_id, driver_email
    FROM drivers d
    INNER JOIN users u ON d.user_id = u.id
    WHERE u.email = 'fred.wicket.us@gmail.com'
    LIMIT 1;
    
    -- Verificar que existe el driver
    IF test_driver_id IS NULL THEN
        RAISE EXCEPTION 'No se encontró el driver Fred (fred.wicket.us@gmail.com) en la base de datos';
    END IF;
    
    RAISE NOTICE 'Enviando notificación de prueba a Fred: % (driver_id: %)', driver_email, test_driver_id;
    
    -- Insertar notificación de prueba
    INSERT INTO messages (
        type,
        title,
        message,
        data,
        driver_id,
        is_read,
        created_at
    ) VALUES (
        'ride_request',
        '🚗 Viaje de Prueba',
        'Esta es una notificación de prueba. Origen: Test Location → Destino: Test Destination',
        jsonb_build_object(
            'ride_id', 'test-123',
            'action', 'driver_accept_reject',
            'test', true
        ),
        test_driver_id,
        false,
        NOW()
    );
    
    RAISE NOTICE '✅ Notificación de prueba insertada exitosamente para Fred (driver_id: %)', test_driver_id;
END $$;

-- ============================================
-- OPCIÓN 3: Enviar múltiples notificaciones a Fred (AUTOMÁTICO)
-- ============================================
-- Esto crea 3 notificaciones de prueba seguidas para Fred
DO $$
DECLARE
    test_driver_id UUID;
    driver_email TEXT;
    i INTEGER;
BEGIN
    -- Obtener el driver_id de Fred por su email
    SELECT d.id, u.email INTO test_driver_id, driver_email
    FROM drivers d
    INNER JOIN users u ON d.user_id = u.id
    WHERE u.email = 'fred.wicket.us@gmail.com'
    LIMIT 1;
    
    -- Verificar que existe el driver
    IF test_driver_id IS NULL THEN
        RAISE EXCEPTION 'No se encontró el driver Fred (fred.wicket.us@gmail.com) en la base de datos';
    END IF;
    
    RAISE NOTICE 'Enviando 3 notificaciones de prueba a Fred: % (driver_id: %)', driver_email, test_driver_id;
    
    FOR i IN 1..3 LOOP
        INSERT INTO messages (
            type,
            title,
            message,
            data,
            driver_id,
            is_read,
            created_at
        ) VALUES (
            'ride_request',
            '🚗 Viaje de Prueba #' || i,
            'Notificación de prueba número ' || i || '. Origen: Test ' || i || ' → Destino: Test Destination ' || i,
            jsonb_build_object(
                'ride_id', 'test-' || i,
                'action', 'driver_accept_reject',
                'test', true,
                'number', i
            ),
            test_driver_id,
            false,
            NOW()
        );
        
        -- Pequeño delay entre inserciones (1 segundo)
        PERFORM pg_sleep(1);
    END LOOP;
    
    RAISE NOTICE '✅ 3 notificaciones de prueba insertadas exitosamente para Fred (driver_id: %)', test_driver_id;
END $$;

-- ============================================
-- VERIFICACIÓN: Ver las notificaciones enviadas
-- ============================================
-- Ejecuta esto después de enviar las notificaciones para verificar
SELECT 
    m.id,
    m.type,
    m.title,
    m.message,
    m.driver_id,
    d.user_id,
    u.email as driver_email,
    m.is_read,
    m.created_at
FROM messages m
LEFT JOIN drivers d ON m.driver_id = d.id
LEFT JOIN users u ON d.user_id = u.id
WHERE m.type = 'ride_request'
  AND m.data->>'test' = 'true'  -- Solo notificaciones de prueba
ORDER BY m.created_at DESC
LIMIT 10;

-- ============================================
-- LIMPIAR: Eliminar notificaciones de prueba
-- ============================================
-- Si quieres eliminar todas las notificaciones de prueba, descomenta esto:
-- DELETE FROM messages WHERE data->>'test' = 'true';

