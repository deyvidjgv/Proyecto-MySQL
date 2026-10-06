-- =============================================================================
-- PROYECTO: Base de Datos para un E-commerce
-- SCRIPT: 08_Examen_sp_ProcesarDevolucion.sql
-- EXAMEN: Procedimiento Almacenado - Proceso de Devolución Completo
-- DESCRIPCIÓN: Crea la tabla devoluciones y el procedimiento sp_ProcesarDevolucion.
-- REQUISITO PREVIO: ejecutar antes los scripts 01 al 07 (base ecommerce_db).
-- =============================================================================

USE ecommerce_db;

-- =============================================================================
-- 1. AGREGAR LOS ESTADOS NUEVOS A LA TABLA VENTAS
-- La columna estado es un ENUM: solo acepta los valores de su lista. Si no se
-- agregan 'Devolución Parcial' y 'Devuelto Totalmente', el UPDATE del
-- procedimiento falla con "ERROR 1265: Data truncated for column 'estado'".
-- Se repiten los 5 estados que ya existían y se agregan los 2 nuevos al final.
-- =============================================================================
ALTER TABLE ventas
    MODIFY estado ENUM('Pendiente de Pago', 'Procesando', 'Enviado', 'Entregado',
                       'Cancelado', 'Devolución Parcial', 'Devuelto Totalmente')
    NOT NULL DEFAULT 'Pendiente de Pago';

-- =============================================================================
-- 2. TABLA DEVOLUCIONES (requisito 4)
-- Guarda cada devolución: de qué venta, qué producto, cuántas unidades y cuándo.
-- Se borra primero la tabla devoluciones que ya creaba el script 01.
-- =============================================================================
DROP TABLE IF EXISTS devoluciones;

CREATE TABLE devoluciones (
    id_devolucion     INT AUTO_INCREMENT PRIMARY KEY,
    id_venta          INT NOT NULL,
    id_producto       INT NOT NULL,
    cantidad_devuelta INT NOT NULL,
    fecha_devolucion  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_venta)    REFERENCES ventas(id_venta),
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

-- =============================================================================
-- 3. PROCEDIMIENTO sp_ProcesarDevolucion
-- Parámetros: la venta, el producto devuelto y la cantidad devuelta.
-- =============================================================================
DROP PROCEDURE IF EXISTS sp_ProcesarDevolucion;

DELIMITER //

CREATE PROCEDURE sp_ProcesarDevolucion(
    IN p_id_venta          INT,
    IN p_id_producto       INT,
    IN p_cantidad_devuelta INT
)
BEGIN
    DECLARE v_cantidad_comprada  INT DEFAULT 0;   -- unidades compradas del producto
    DECLARE v_unidades_venta     INT DEFAULT 0;   -- unidades de toda la venta
    DECLARE v_unidades_devueltas INT DEFAULT 0;   -- unidades devueltas de toda la venta
    DECLARE v_nuevo_estado       VARCHAR(30);

    -- REQUISITO 5: si cualquier línea falla (también los SIGNAL de abajo),
    -- MySQL salta a este bloque:
    --   ROLLBACK -> deshace todo lo que se hizo desde START TRANSACTION.
    --   RESIGNAL -> vuelve a mostrar el mismo error a quien hizo el CALL.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- REQUISITO 1: la cantidad devuelta no puede ser mayor que la comprada.
    -- Se busca cuántas unidades de ese producto se compraron en esa venta.
    -- Si el producto no está en la venta, la variable se queda en 0 y la
    -- validación también lo rechaza.
    SELECT cantidad INTO v_cantidad_comprada
    FROM detalle_ventas
    WHERE id_venta = p_id_venta
      AND id_producto = p_id_producto;

    IF p_cantidad_devuelta > v_cantidad_comprada THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: La cantidad a devolver es mayor que la cantidad comprada en esta venta.';
    END IF;

    -- REQUISITO 2: las unidades devueltas vuelven al inventario.
    UPDATE productos
    SET stock = stock + p_cantidad_devuelta
    WHERE id_producto = p_id_producto;

    -- REQUISITO 4: se registra la devolución.
    -- Se hace antes de calcular el estado para que esta devolución ya cuente.
    INSERT INTO devoluciones (id_venta, id_producto, cantidad_devuelta)
    VALUES (p_id_venta, p_id_producto, p_cantidad_devuelta);

    -- REQUISITO 3: estado de la venta.
    -- SUM() suma la columna de todas las filas que cumplen el WHERE:
    --   v_unidades_venta     = unidades compradas en TODA la venta
    --   v_unidades_devueltas = unidades devueltas de TODA la venta
    -- Si ya se devolvió todo -> 'Devuelto Totalmente'; si no -> 'Devolución Parcial'.
    -- Ejemplo: venta de 1 laptop + 1 audífonos; si solo devuelve la laptop,
    -- la venta queda en 'Devolución Parcial'.
    SELECT SUM(cantidad) INTO v_unidades_venta
    FROM detalle_ventas
    WHERE id_venta = p_id_venta;

    SELECT SUM(cantidad_devuelta) INTO v_unidades_devueltas
    FROM devoluciones
    WHERE id_venta = p_id_venta;

    IF v_unidades_devueltas >= v_unidades_venta THEN
        SET v_nuevo_estado = 'Devuelto Totalmente';
    ELSE
        SET v_nuevo_estado = 'Devolución Parcial';
    END IF;

    UPDATE ventas
    SET estado = v_nuevo_estado
    WHERE id_venta = p_id_venta;

    -- Todo salió bien: se guardan todos los cambios juntos.
    COMMIT;

    SELECT 'Devolución registrada' AS mensaje, v_nuevo_estado AS estado_venta;
END //

DELIMITER ;

-- =============================================================================
-- 4. PRUEBAS (quitar el -- y ejecutar una por una, en este orden)
-- =============================================================================
-- Venta 5: 2 laptops (producto 1). Stock inicial de la laptop: 25.
-- CALL sp_ProcesarDevolucion(5, 1, 1);   -- 'Devolución Parcial', stock 26
-- CALL sp_ProcesarDevolucion(5, 1, 1);   -- 'Devuelto Totalmente', stock 27
--
-- Venta 1: 1 laptop (producto 1) + 1 audífonos (producto 3).
-- CALL sp_ProcesarDevolucion(1, 1, 5);   -- ERROR: compró 1 y quiere devolver 5
-- CALL sp_ProcesarDevolucion(1, 3, 1);   -- 'Devolución Parcial' (falta la laptop)
--
-- Ver los resultados:
-- SELECT * FROM devoluciones;
-- SELECT id_venta, estado FROM ventas WHERE id_venta IN (1, 5);
-- SELECT id_producto, stock FROM productos WHERE id_producto IN (1, 3);
