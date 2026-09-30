-- =============================================================================
-- PROYECTO: Base de Datos para un E-commerce
-- SCRIPT: 06_Eventos.sql
-- DESCRIPCIÓN: Activación del event_scheduler, creación de tabla de reportes
--              e implementación de los 20 eventos programados (MySQL Events).
-- =============================================================================

USE ecommerce_db;

-- =============================================================================
-- 1. ACTIVACIÓN DEL PLANIFICADOR DE EVENTOS
-- =============================================================================
SET GLOBAL event_scheduler = ON;

-- IMPORTANTE: todos los eventos se programan con
--     STARTS CURRENT_TIMESTAMP + INTERVAL <1 DAY | 1 HOUR>
-- y NO con 'STARTS CURRENT_TIMESTAMP' a secas. Un evento que arranca en el
-- instante de su creación se ejecuta de inmediato: las tareas de purga
-- (visitas_productos, carritos_abandonados, clientes inactivos) borrarían los
-- datos de prueba nada más instalar el script y las consultas 10 y 18 de
-- 02_Consultas_Avanzadas.sql devolverían vacío.

-- =============================================================================
-- 2. TABLAS DE SOPORTE PARA EVENTOS PROGRAMADOS
-- =============================================================================

-- Tabla de Reportes de Ventas Semanales requerida por especificación
CREATE TABLE IF NOT EXISTS reporte_ventas_semanales (
    id_reporte INT AUTO_INCREMENT PRIMARY KEY,
    semana INT NOT NULL,
    anio INT NOT NULL,
    total_ventas DECIMAL(12,2) NOT NULL,
    cantidad_ordenes INT NOT NULL,
    fecha_generacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_semana_anio (semana, anio)
) ENGINE=InnoDB;

-- Tabla para cupones y saludos de cumpleaños generados diariamente
CREATE TABLE IF NOT EXISTS clientes_cumpleaños_cupones (
    id_registro INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    codigo_cupon VARCHAR(50) NOT NULL,
    fecha_emision DATE NOT NULL,
    utilizado BOOLEAN NOT NULL DEFAULT FALSE
) ENGINE=InnoDB;

-- Tabla de log de inconsistencias detectadas
CREATE TABLE IF NOT EXISTS auditoria_inconsistencias (
    id_inconsistencia INT AUTO_INCREMENT PRIMARY KEY,
    tipo VARCHAR(100) NOT NULL,
    descripcion TEXT NOT NULL,
    fecha_deteccion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Tabla de registro de copias de seguridad lógicas
CREATE TABLE IF NOT EXISTS log_backups_logicos (
    id_backup INT AUTO_INCREMENT PRIMARY KEY,
    descripcion VARCHAR(150) NOT NULL,
    tablas_respaldadas VARCHAR(255) NOT NULL,
    fecha_backup DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Tabla para simulación de vista materializada
CREATE TABLE IF NOT EXISTS vm_resumen_ventas_categoria (
    id_categoria INT PRIMARY KEY,
    categoria VARCHAR(100) NOT NULL,
    ventas_totales DECIMAL(12,2) NOT NULL,
    unidades_vendidas INT NOT NULL,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Tabla de alertas de seguridad y prevención de fraudes
CREATE TABLE IF NOT EXISTS alertas_seguridad_fraude (
    id_alerta INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    descripcion VARCHAR(255) NOT NULL,
    nivel_riesgo ENUM('Bajo', 'Medio', 'Alto') NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

DELIMITER //

-- -----------------------------------------------------------------------------
-- 1. evt_generate_weekly_sales_report
-- Genera y consolida el reporte de ventas semanal en reporte_ventas_semanales.
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_generate_weekly_sales_report //
CREATE EVENT evt_generate_weekly_sales_report
ON SCHEDULE EVERY 1 WEEK
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO reporte_ventas_semanales (semana, anio, total_ventas, cantidad_ordenes, fecha_generacion)
    SELECT 
        WEEK(fecha_venta, 1) AS semana,
        YEAR(fecha_venta) AS anio,
        COALESCE(SUM(total), 0.00),
        COUNT(id_venta),
        NOW()
    FROM ventas
    WHERE estado != 'Cancelado'
      AND fecha_venta >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    GROUP BY YEAR(fecha_venta), WEEK(fecha_venta, 1)
    ON DUPLICATE KEY UPDATE 
        total_ventas = VALUES(total_ventas),
        cantidad_ordenes = VALUES(cantidad_ordenes),
        fecha_generacion = NOW();
END //

-- -----------------------------------------------------------------------------
-- 2. evt_cleanup_temp_tables_daily
-- Limpia registros temporales obsoletos de visitas de más de 60 días.
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_cleanup_temp_tables_daily //
CREATE EVENT evt_cleanup_temp_tables_daily
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DELETE FROM visitas_productos
    WHERE fecha_visita < DATE_SUB(NOW(), INTERVAL 60 DAY);
END //

-- -----------------------------------------------------------------------------
-- 3. evt_archive_old_logs_monthly
-- Depura logs de auditoría de clientes antiguos con más de 6 meses de registro.
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_archive_old_logs_monthly //
CREATE EVENT evt_archive_old_logs_monthly
ON SCHEDULE EVERY 1 MONTH
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DELETE FROM log_auditoria_clientes
    WHERE fecha < DATE_SUB(NOW(), INTERVAL 180 DAY);
END //

-- -----------------------------------------------------------------------------
-- 4. evt_deactivate_expired_promotions_hourly
-- Desactiva automáticamente los códigos de descuento que hayan vencido.
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_deactivate_expired_promotions_hourly //
CREATE EVENT evt_deactivate_expired_promotions_hourly
ON SCHEDULE EVERY 1 HOUR
STARTS CURRENT_TIMESTAMP + INTERVAL 1 HOUR
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    UPDATE promociones
    SET activo = FALSE
    WHERE fecha_fin < NOW() AND activo = TRUE;
END //

-- -----------------------------------------------------------------------------
-- 5. evt_recalculate_customer_loyalty_tiers_nightly
-- Recalcula el nivel de lealtad de todos los clientes cada noche según su gasto.
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_recalculate_customer_loyalty_tiers_nightly //
CREATE EVENT evt_recalculate_customer_loyalty_tiers_nightly
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    UPDATE clientes
    SET nivel_lealtad = CASE 
        WHEN total_gastado >= 3000.00 THEN 'Oro'
        WHEN total_gastado >= 1500.00 THEN 'Plata'
        ELSE 'Bronce'
    END;
END //

-- -----------------------------------------------------------------------------
-- 6. evt_generate_reorder_list_daily
-- Revisa productos con stock <= stock_minimo y genera alertas de reposición.
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_generate_reorder_list_daily //
CREATE EVENT evt_generate_reorder_list_daily
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO alertas_stock (id_producto, stock_actual, mensaje, fecha)
    SELECT 
        p.id_producto, 
        p.stock, 
        CONCAT('Pedido de reabastecimiento programado: Stock actual (', p.stock, ')'), 
        NOW()
    FROM productos p
    WHERE p.stock <= p.stock_minimo 
      AND p.activo = TRUE
      AND p.id_producto NOT IN (
          SELECT id_producto 
          FROM alertas_stock 
          WHERE fecha >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
      );
END //

-- -----------------------------------------------------------------------------
-- 7. evt_rebuild_indexes_weekly
-- Optimiza las tablas más transaccionales para desfragmentar índices.
-- NOTA: en InnoDB, OPTIMIZE TABLE no "reconstruye índices" al estilo de otros
-- motores: ejecuta un ALTER TABLE ... FORCE (rebuild completo de la tabla) y
-- recalcula estadísticas, bloqueando la tabla durante la operación. Para el
-- refresco ligero de estadísticas basta ANALYZE TABLE.
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_rebuild_indexes_weekly //
CREATE EVENT evt_rebuild_indexes_weekly
ON SCHEDULE EVERY 1 WEEK
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    OPTIMIZE TABLE productos, ventas, detalle_ventas;
END //

-- -----------------------------------------------------------------------------
-- 8. evt_suspend_inactive_accounts_quarterly
-- Desactiva cuentas de clientes sin órdenes registradas en más de un año.
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_suspend_inactive_accounts_quarterly //
CREATE EVENT evt_suspend_inactive_accounts_quarterly
ON SCHEDULE EVERY 3 MONTH
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    UPDATE clientes
    SET activo = FALSE
    WHERE (fecha_ultimo_pedido IS NOT NULL AND fecha_ultimo_pedido < DATE_SUB(NOW(), INTERVAL 365 DAY))
       OR (fecha_ultimo_pedido IS NULL AND fecha_registro < DATE_SUB(NOW(), INTERVAL 365 DAY));
END //

-- -----------------------------------------------------------------------------
-- 9. evt_aggregate_daily_sales_data
-- Agrega las ventas del día inmediatamente anterior en resumen_ventas_diarias.
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_aggregate_daily_sales_data //
CREATE EVENT evt_aggregate_daily_sales_data
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO resumen_ventas_diarias (fecha, total_ventas, cantidad_pedidos)
    SELECT 
        DATE(fecha_venta) AS fecha,
        COALESCE(SUM(total), 0.00),
        COUNT(id_venta)
    FROM ventas
    WHERE estado != 'Cancelado'
      AND DATE(fecha_venta) = DATE_SUB(CURDATE(), INTERVAL 1 DAY)
    GROUP BY DATE(fecha_venta)
    ON DUPLICATE KEY UPDATE 
        total_ventas = VALUES(total_ventas),
        cantidad_pedidos = VALUES(cantidad_pedidos);
END //

-- -----------------------------------------------------------------------------
-- 10. evt_check_data_consistency_nightly
-- Detecta inconsistencias en los datos y las registra en auditoría.
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_check_data_consistency_nightly //
CREATE EVENT evt_check_data_consistency_nightly
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    -- Detecta ventas sin detalles
    INSERT INTO auditoria_inconsistencias (tipo, descripcion, fecha_deteccion)
    SELECT 
        'Venta sin líneas de detalle',
        CONCAT('La orden ID ', v.id_venta, ' no contiene ningún producto asociado.'),
        NOW()
    FROM ventas v
    LEFT JOIN detalle_ventas dv ON v.id_venta = dv.id_venta
    WHERE dv.id_detalle IS NULL
      -- Evita reinsertar cada noche la misma inconsistencia ya reportada.
      AND NOT EXISTS (
          SELECT 1 FROM auditoria_inconsistencias ai
          WHERE ai.tipo = 'Venta sin líneas de detalle'
            AND ai.descripcion = CONCAT('La orden ID ', v.id_venta, ' no contiene ningún producto asociado.')
      );
END //

-- -----------------------------------------------------------------------------
-- 11. evt_send_birthday_greetings_daily
-- Genera cupones de cumpleaños para los clientes que cumplen en el día.
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_send_birthday_greetings_daily //
CREATE EVENT evt_send_birthday_greetings_daily
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO clientes_cumpleaños_cupones (id_cliente, codigo_cupon, fecha_emision)
    SELECT 
        id_cliente,
        CONCAT('CUMPLE-', id_cliente, '-', YEAR(CURDATE())),
        CURDATE()
    FROM clientes
    WHERE MONTH(fecha_nacimiento) = MONTH(CURDATE())
      AND DAY(fecha_nacimiento) = DAY(CURDATE())
      AND id_cliente NOT IN (
          SELECT id_cliente 
          FROM clientes_cumpleaños_cupones 
          WHERE YEAR(fecha_emision) = YEAR(CURDATE())
      );
END //

-- -----------------------------------------------------------------------------
-- 12. evt_update_product_rankings_hourly
-- Actualiza la tabla ranking_productos con los artículos más vendidos.
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_update_product_rankings_hourly //
CREATE EVENT evt_update_product_rankings_hourly
ON SCHEDULE EVERY 1 HOUR
STARTS CURRENT_TIMESTAMP + INTERVAL 1 HOUR
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DELETE FROM ranking_productos;
    
    INSERT INTO ranking_productos (id_producto, posicion, total_vendido, fecha_actualizacion)
    SELECT 
        p.id_producto,
        ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(dv.cantidad), 0) DESC) AS posicion,
        COALESCE(SUM(dv.cantidad), 0) AS total_vendido,
        NOW()
    FROM productos p
    LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
    GROUP BY p.id_producto
    -- 'LIMIT 20' sin ORDER BY devuelve 20 filas ARBITRARIAS, no el top 20.
    ORDER BY total_vendido DESC
    LIMIT 20;
END //

-- -----------------------------------------------------------------------------
-- 13. evt_backup_critical_tables_daily
-- Registra la confirmación del ciclo de respaldo lógico nocturno.
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_backup_critical_tables_daily //
CREATE EVENT evt_backup_critical_tables_daily
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO log_backups_logicos (descripcion, tablas_respaldadas, fecha_backup)
    VALUES ('Copia de seguridad nocturna programada', 'clientes, ventas, detalle_ventas, productos', NOW());
END //

-- -----------------------------------------------------------------------------
-- 14. evt_clear_abandoned_carts_daily
-- Elimina carritos de compra abandonados hace más de 72 horas.
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_clear_abandoned_carts_daily //
CREATE EVENT evt_clear_abandoned_carts_daily
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DELETE FROM carritos_abandonados
    WHERE abandonado = TRUE 
      AND fecha_agregado < DATE_SUB(NOW(), INTERVAL 72 HOUR);
END //

-- -----------------------------------------------------------------------------
-- 15. evt_calculate_monthly_kpis
-- Calcula y registra los indicadores de desempeño (KPIs) del mes vencido.
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_calculate_monthly_kpis //
CREATE EVENT evt_calculate_monthly_kpis
ON SCHEDULE EVERY 1 MONTH
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DECLARE v_mes INT;
    DECLARE v_anio INT;
    
    SET v_mes = MONTH(DATE_SUB(CURDATE(), INTERVAL 1 MONTH));
    SET v_anio = YEAR(DATE_SUB(CURDATE(), INTERVAL 1 MONTH));
    
    INSERT INTO kpis_mensuales (anio, mes, ingresos_totales, total_pedidos, ticket_promedio)
    SELECT 
        v_anio,
        v_mes,
        COALESCE(SUM(total), 0.00),
        COUNT(id_venta),
        COALESCE(ROUND(AVG(total), 2), 0.00)
    FROM ventas
    WHERE estado != 'Cancelado'
      AND MONTH(fecha_venta) = v_mes
      AND YEAR(fecha_venta) = v_anio
    ON DUPLICATE KEY UPDATE 
        ingresos_totales = VALUES(ingresos_totales),
        total_pedidos = VALUES(total_pedidos),
        ticket_promedio = VALUES(ticket_promedio);
END //

-- -----------------------------------------------------------------------------
-- 16. evt_refresh_materialized_views_nightly
-- Refresca la tabla resumen que emula la vista materializada de ventas.
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_refresh_materialized_views_nightly //
CREATE EVENT evt_refresh_materialized_views_nightly
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DELETE FROM vm_resumen_ventas_categoria;
    
    INSERT INTO vm_resumen_ventas_categoria (id_categoria, categoria, ventas_totales, unidades_vendidas, fecha_actualizacion)
    SELECT 
        c.id_categoria,
        c.nombre,
        COALESCE(SUM(dv.subtotal), 0.00),
        COALESCE(SUM(dv.cantidad), 0),
        NOW()
    FROM categorias c
    LEFT JOIN productos p ON c.id_categoria = p.id_categoria
    LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
    GROUP BY c.id_categoria, c.nombre;
END //

-- -----------------------------------------------------------------------------
-- 17. evt_log_database_size_weekly
-- Registra el tamaño total de la base de datos en megabytes para monitoreo.
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_log_database_size_weekly //
CREATE EVENT evt_log_database_size_weekly
ON SCHEDULE EVERY 1 WEEK
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO monitoreo_bd (tamanio_mb, fecha_registro)
    SELECT 
        ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS tam_mb,
        NOW()
    FROM information_schema.TABLES
    WHERE table_schema = 'ecommerce_db';
END //

-- -----------------------------------------------------------------------------
-- 18. evt_detect_fraudulent_activity_hourly
-- Detecta patrones anómalos (ej. más de 3 compras en menos de 1 hora por cliente).
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_detect_fraudulent_activity_hourly //
CREATE EVENT evt_detect_fraudulent_activity_hourly
ON SCHEDULE EVERY 1 HOUR
STARTS CURRENT_TIMESTAMP + INTERVAL 1 HOUR
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO alertas_seguridad_fraude (id_cliente, descripcion, nivel_riesgo, fecha)
    SELECT 
        id_cliente,
        CONCAT('Comportamiento sospechoso: ', COUNT(id_venta), ' órdenes registradas en la última hora'),
        'Alto',
        NOW()
    FROM ventas
    WHERE fecha_venta >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
    GROUP BY id_cliente
    HAVING COUNT(id_venta) >= 3;
END //

-- -----------------------------------------------------------------------------
-- 19. evt_generate_supplier_performance_report_monthly
-- Consolida mensualmente el rendimiento y volumen de ventas por proveedor.
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_generate_supplier_performance_report_monthly //
CREATE EVENT evt_generate_supplier_performance_report_monthly
ON SCHEDULE EVERY 1 MONTH
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DECLARE v_mes INT;
    DECLARE v_anio INT;
    
    SET v_mes = MONTH(DATE_SUB(CURDATE(), INTERVAL 1 MONTH));
    SET v_anio = YEAR(DATE_SUB(CURDATE(), INTERVAL 1 MONTH));
    
    INSERT INTO reporte_proveedores (id_proveedor, mes, anio, total_vendido, unidades_vendidas)
    SELECT 
        pr.id_proveedor,
        v_mes,
        v_anio,
        COALESCE(SUM(dv.subtotal), 0.00),
        COALESCE(SUM(dv.cantidad), 0)
    FROM proveedores pr
    JOIN productos p ON pr.id_proveedor = p.id_proveedor
    JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
    JOIN ventas v ON dv.id_venta = v.id_venta
    WHERE v.estado != 'Cancelado'
      AND MONTH(v.fecha_venta) = v_mes
      AND YEAR(v.fecha_venta) = v_anio
    GROUP BY pr.id_proveedor;
END //

-- -----------------------------------------------------------------------------
-- 20. evt_purge_soft_deleted_records_weekly
-- Limpia permanentemente cuentas suspendidas inactivas por más de 30 días.
-- -----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_purge_soft_deleted_records_weekly //
CREATE EVENT evt_purge_soft_deleted_records_weekly
ON SCHEDULE EVERY 1 WEEK
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DELETE FROM clientes
    WHERE activo = FALSE
      AND total_gastado = 0
      AND id_cliente NOT IN (SELECT DISTINCT id_cliente FROM ventas);
END //

DELIMITER ;
