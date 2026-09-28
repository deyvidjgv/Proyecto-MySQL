-- =============================================================================
-- PROYECTO: Base de Datos para un E-commerce
-- SCRIPT: 05_Triggers.sql
-- DESCRIPCIÓN: Creación de tabla de auditoría log_cambios_precio e 
--              implementación de 20 disparadores (triggers) de integridad y negocio.
-- =============================================================================

USE ecommerce_db;

-- =============================================================================
-- TABLA DE AUDITORÍA REQUERIDA
-- =============================================================================
CREATE TABLE IF NOT EXISTS log_cambios_precio (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    precio_anterior DECIMAL(10,2) NOT NULL,
    precio_nuevo DECIMAL(10,2) NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    fecha_cambio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_log_precio_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE
) ENGINE=InnoDB;

DELIMITER //

-- -----------------------------------------------------------------------------
-- 1. trg_audit_precio_producto_after_update
-- Guarda un registro histórico en log_cambios_precio al modificarse el precio.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_precio_producto_after_update //
CREATE TRIGGER trg_audit_precio_producto_after_update
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF OLD.precio <> NEW.precio THEN
        INSERT INTO log_cambios_precio (id_producto, precio_anterior, precio_nuevo, usuario, fecha_cambio)
        VALUES (NEW.id_producto, OLD.precio, NEW.precio, CURRENT_USER(), NOW());
    END IF;
END //

-- -----------------------------------------------------------------------------
-- 2. trg_check_stock_before_insert_venta
-- Verifica si hay stock disponible antes de registrar una línea de detalle.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_check_stock_before_insert_venta //
CREATE TRIGGER trg_check_stock_before_insert_venta
BEFORE INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    DECLARE v_stock_disponible INT DEFAULT 0;
    
    SELECT stock INTO v_stock_disponible
    FROM productos
    WHERE id_producto = NEW.id_producto;
    
    IF v_stock_disponible < NEW.cantidad THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Existencias insuficientes para surtir la cantidad solicitada.';
    END IF;
END //

-- -----------------------------------------------------------------------------
-- 3. trg_update_stock_after_insert_venta
-- Decrementa las existencias en inventario tras insertar un detalle de venta.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_update_stock_after_insert_venta //
CREATE TRIGGER trg_update_stock_after_insert_venta
AFTER INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE productos
    SET stock = stock - NEW.cantidad
    WHERE id_producto = NEW.id_producto;
END //

-- -----------------------------------------------------------------------------
-- 4. trg_prevent_delete_categoria_with_products
-- Impide borrar una categoría que posea artículos vinculados en catálogo.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_prevent_delete_categoria_with_products //
CREATE TRIGGER trg_prevent_delete_categoria_with_products
BEFORE DELETE ON categorias
FOR EACH ROW
BEGIN
    DECLARE v_conteo INT DEFAULT 0;
    
    SELECT COUNT(*) INTO v_conteo
    FROM productos
    WHERE id_categoria = OLD.id_categoria;
    
    IF v_conteo > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Restricción de integridad: no es posible eliminar categorías con productos.';
    END IF;
END //

-- -----------------------------------------------------------------------------
-- 5. trg_log_new_customer_after_insert
-- Registra en log_auditoria_clientes cada vez que se crea un nuevo cliente.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_log_new_customer_after_insert //
CREATE TRIGGER trg_log_new_customer_after_insert
AFTER INSERT ON clientes
FOR EACH ROW
BEGIN
    INSERT INTO log_auditoria_clientes (id_cliente, accion, fecha)
    VALUES (NEW.id_cliente, 'Nuevo cliente registrado', NOW());
END //

-- -----------------------------------------------------------------------------
-- 6. trg_update_total_gastado_cliente
-- Acumula el campo total_gastado en clientes tras confirmarse/entregarse la orden.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_update_total_gastado_cliente //
CREATE TRIGGER trg_update_total_gastado_cliente
AFTER UPDATE ON ventas
FOR EACH ROW
BEGIN
    IF NEW.estado = 'Entregado' AND OLD.estado <> 'Entregado' THEN
        UPDATE clientes
        SET total_gastado = total_gastado + NEW.total
        WHERE id_cliente = NEW.id_cliente;
    END IF;
END //

-- -----------------------------------------------------------------------------
-- 7. trg_set_fecha_modificacion_producto
-- Actualiza automáticamente la marca temporal de modificación de producto.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_set_fecha_modificacion_producto //
CREATE TRIGGER trg_set_fecha_modificacion_producto
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    SET NEW.fecha_modificacion = NOW();
END //

-- -----------------------------------------------------------------------------
-- 8. trg_prevent_negative_stock
-- Impide que el stock de cualquier artículo pase a un valor negativo.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_prevent_negative_stock //
CREATE TRIGGER trg_prevent_negative_stock
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El nivel de stock no puede ser un valor negativo.';
    END IF;
END //

-- -----------------------------------------------------------------------------
-- 9. trg_capitalize_nombre_cliente
-- Estandariza con letra capital el nombre y apellido al registrar un cliente.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_capitalize_nombre_cliente //
CREATE TRIGGER trg_capitalize_nombre_cliente
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    IF CHAR_LENGTH(NEW.nombre) > 0 THEN
        SET NEW.nombre = CONCAT(UPPER(SUBSTRING(NEW.nombre, 1, 1)), LOWER(SUBSTRING(NEW.nombre, 2)));
    END IF;
    IF CHAR_LENGTH(NEW.apellido) > 0 THEN
        SET NEW.apellido = CONCAT(UPPER(SUBSTRING(NEW.apellido, 1, 1)), LOWER(SUBSTRING(NEW.apellido, 2)));
    END IF;
END //

-- -----------------------------------------------------------------------------
-- 10. trg_recalculate_total_venta_on_detalle_change
-- Recalcula el total de la orden si se modifica un detalle de venta.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_recalculate_total_venta_on_detalle_change //
CREATE TRIGGER trg_recalculate_total_venta_on_detalle_change
AFTER UPDATE ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE ventas
    SET total = (SELECT COALESCE(SUM(subtotal), 0.00) FROM detalle_ventas WHERE id_venta = NEW.id_venta)
    WHERE id_venta = NEW.id_venta;
END //

-- -----------------------------------------------------------------------------
-- 11. trg_log_order_status_change
-- Audita en historial_pedidos_estado cualquier cambio de estado del pedido.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_log_order_status_change //
CREATE TRIGGER trg_log_order_status_change
AFTER UPDATE ON ventas
FOR EACH ROW
BEGIN
    IF OLD.estado <> NEW.estado THEN
        INSERT INTO historial_pedidos_estado (id_venta, estado_anterior, estado_nuevo, fecha_cambio)
        VALUES (NEW.id_venta, OLD.estado, NEW.estado, NOW());
    END IF;
END //

-- -----------------------------------------------------------------------------
-- 12. trg_prevent_price_zero_or_less
-- Impide crear o asignar un precio menor o igual a cero en productos.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_prevent_price_zero_or_less //
CREATE TRIGGER trg_prevent_price_zero_or_less
BEFORE INSERT ON productos
FOR EACH ROW
BEGIN
    IF NEW.precio <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El precio del producto debe ser estrictamente mayor a 0.';
    END IF;
END //

-- -----------------------------------------------------------------------------
-- 13. trg_send_stock_alert_on_low_stock
-- Inserta registro en alertas_stock cuando el stock cae bajo el stock mínimo.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_send_stock_alert_on_low_stock //
CREATE TRIGGER trg_send_stock_alert_on_low_stock
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock <= NEW.stock_minimo AND (OLD.stock > OLD.stock_minimo OR OLD.stock <> NEW.stock) THEN
        INSERT INTO alertas_stock (id_producto, stock_actual, mensaje, fecha)
        VALUES (
            NEW.id_producto, 
            NEW.stock, 
            CONCAT('Nivel crítico: Stock actual (', NEW.stock, ') por debajo del mínimo (', NEW.stock_minimo, ')'), 
            NOW()
        );
    END IF;
END //

-- -----------------------------------------------------------------------------
-- 14. trg_archive_deleted_venta
-- Guarda una copia histórica en ventas_archivadas antes de borrar una orden.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_archive_deleted_venta //
CREATE TRIGGER trg_archive_deleted_venta
BEFORE DELETE ON ventas
FOR EACH ROW
BEGIN
    INSERT INTO ventas_archivadas (id_venta_original, id_cliente, fecha_venta, total, fecha_archivo)
    VALUES (OLD.id_venta, OLD.id_cliente, OLD.fecha_venta, OLD.total, NOW());
END //

-- -----------------------------------------------------------------------------
-- 15. trg_validate_email_format_on_customer
-- Valida que el email cumpla sintaxis correcta antes de actualizar cliente.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_validate_email_format_on_customer //
CREATE TRIGGER trg_validate_email_format_on_customer
BEFORE UPDATE ON clientes
FOR EACH ROW
BEGIN
    IF NEW.email NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El formato del correo electrónico proporcionado no es válido.';
    END IF;
END //

-- -----------------------------------------------------------------------------
-- 16. trg_update_last_order_date_customer
-- Actualiza la fecha de último pedido del cliente al registrar una nueva venta.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_update_last_order_date_customer //
CREATE TRIGGER trg_update_last_order_date_customer
AFTER INSERT ON ventas
FOR EACH ROW
BEGIN
    UPDATE clientes
    SET fecha_ultimo_pedido = NEW.fecha_venta
    WHERE id_cliente = NEW.id_cliente;
END //

-- -----------------------------------------------------------------------------
-- 17. trg_prevent_self_referral
-- Impide que un cliente se referencie a sí mismo como referido.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_prevent_self_referral //
CREATE TRIGGER trg_prevent_self_referral
BEFORE UPDATE ON clientes
FOR EACH ROW
BEGIN
    IF NEW.id_referido_por IS NOT NULL AND NEW.id_referido_por = OLD.id_cliente THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Un cliente no puede ser su propio referido.';
    END IF;
END //

-- -----------------------------------------------------------------------------
-- 18. trg_log_permission_changes
-- Audita en log_permisos_usuarios los cambios de asignación y privilegios.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_log_permission_changes //
CREATE TRIGGER trg_log_permission_changes
AFTER INSERT ON asignacion_usuario_sucursal
FOR EACH ROW
BEGIN
    INSERT INTO log_permisos_usuarios (usuario, accion, fecha)
    VALUES (NEW.usuario_bd, CONCAT('Asignación de acceso a sucursal ID ', NEW.id_sucursal), NOW());
END //

-- -----------------------------------------------------------------------------
-- 19. trg_assign_default_category_on_null
-- Asigna la categoría 'General' (o predeterminada) si se inserta sin categoría.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_assign_default_category_on_null //
CREATE TRIGGER trg_assign_default_category_on_null
BEFORE INSERT ON productos
FOR EACH ROW
BEGIN
    IF NEW.id_categoria IS NULL THEN
        -- Asigna categoría 1 por defecto si no se especificó ninguna
        SET NEW.id_categoria = 1;
    END IF;
END //

-- -----------------------------------------------------------------------------
-- 20. trg_update_producto_count_in_categoria
-- Mantiene actualizado el contador total_productos de la categoría al agregar ítems.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_update_producto_count_in_categoria //
CREATE TRIGGER trg_update_producto_count_in_categoria
AFTER INSERT ON productos
FOR EACH ROW
BEGIN
    IF NEW.id_categoria IS NOT NULL THEN
        UPDATE categorias
        SET total_productos = total_productos + 1
        WHERE id_categoria = NEW.id_categoria;
    END IF;
END //

DELIMITER ;
