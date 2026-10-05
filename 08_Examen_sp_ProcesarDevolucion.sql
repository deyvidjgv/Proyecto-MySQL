-- =============================================================================
-- PROYECTO: Base de Datos para un E-commerce
-- SCRIPT: 08_Examen_sp_ProcesarDevolucion.sql
-- EXAMEN: Procedimiento Almacenado - Proceso de Devolución Completo
-- DESCRIPCIÓN: Crea la tabla devoluciones y el procedimiento
--              sp_ProcesarDevolucion, que procesa la devolución de un producto:
--                1. Valida que no se devuelva más de lo comprado en la venta.
--                2. Repone el stock del producto devuelto.
--                3. Cambia el estado de la venta a 'Devolución Parcial' o
--                   'Devuelto Totalmente' según corresponda.
--                4. Registra la operación en devoluciones para auditoría.
--                5. Todo dentro de una transacción: o se completa todo o no se
--                   modifica nada.
-- REQUISITO PREVIO: la base ecommerce_db creada con los scripts 01 al 07.
--              Este script reemplaza la tabla devoluciones creada en 01 y el
--              sp_ProcesarDevolucion de 4 parámetros creado en 07.
-- =============================================================================

USE ecommerce_db;

-- =============================================================================
-- 1. NUEVOS ESTADOS DE VENTA
-- ventas.estado es un ENUM que solo admite 5 valores. Sin este cambio, el UPDATE
-- del requisito 3 falla con "ERROR 1265: Data truncated for column 'estado'".
-- Se repiten los 5 valores originales en el mismo orden (así los datos ya
-- guardados no cambian) y se agregan los dos estados nuevos al final.
-- =============================================================================
ALTER TABLE ventas
    MODIFY estado ENUM(
        'Pendiente de Pago', 'Procesando', 'Enviado', 'Entregado', 'Cancelado',
        'Devolución Parcial', 'Devuelto Totalmente'
    ) NOT NULL DEFAULT 'Pendiente de Pago';

-- =============================================================================
-- 2. TABLA DEVOLUCIONES (requisito 4)
-- Cada fila es una devolución: qué producto, de qué venta, cuántas unidades,
-- a qué precio, cuánto se reembolsa, en qué estado quedó la venta, quién la
-- procesó y cuándo.
-- Primero se elimina la versión anterior creada en 01_Esquema_y_Datos.sql, que
-- tiene otras columnas. Re-ejecutar este script vacía la tabla.
-- =============================================================================
DROP TABLE IF EXISTS devoluciones;

CREATE TABLE devoluciones (
    id_devolucion           INT AUTO_INCREMENT PRIMARY KEY,
    id_venta                INT NOT NULL,
    id_producto             INT NOT NULL,
    cantidad_devuelta       INT NOT NULL CHECK (cantidad_devuelta > 0),
    precio_unitario         DECIMAL(10,2) NOT NULL,   -- precio al que se vendió
    monto_reembolso         DECIMAL(12,2) NOT NULL,   -- cantidad_devuelta * precio_unitario
    estado_venta_resultante VARCHAR(30) NOT NULL,     -- estado en que quedó la venta
    usuario                 VARCHAR(100) NOT NULL,    -- cuenta MySQL que hizo la devolución
    fecha_devolucion        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- Sin ON DELETE CASCADE: el historial de auditoría no debe borrarse en
    -- silencio si alguien elimina la venta o el producto.
    CONSTRAINT fk_devolucion_venta    FOREIGN KEY (id_venta)    REFERENCES ventas(id_venta),
    CONSTRAINT fk_devolucion_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
) ENGINE=InnoDB;

-- =============================================================================
-- 3. PROCEDIMIENTO sp_ProcesarDevolucion
-- Parámetros:
--   p_id_venta           venta de la que se devuelve el producto
--   p_id_producto        producto que se devuelve
--   p_cantidad_devuelta  unidades que se devuelven en esta operación
-- =============================================================================
DROP PROCEDURE IF EXISTS sp_ProcesarDevolucion;

DELIMITER //

CREATE PROCEDURE sp_ProcesarDevolucion(
    IN p_id_venta          INT,
    IN p_id_producto       INT,
    IN p_cantidad_devuelta INT
)
BEGIN
    DECLARE v_estado_actual      VARCHAR(30)   DEFAULT NULL;
    DECLARE v_cantidad_comprada  INT           DEFAULT 0;
    DECLARE v_subtotal_comprado  DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_ya_devuelto        INT           DEFAULT 0;
    DECLARE v_precio_unitario    DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_monto_reembolso    DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_unidades_venta     INT           DEFAULT 0;
    DECLARE v_unidades_devueltas INT           DEFAULT 0;
    DECLARE v_nuevo_estado       VARCHAR(30)   DEFAULT NULL;

    -- REQUISITO 5 (atomicidad): si CUALQUIER sentencia falla, incluidos los
    -- SIGNAL de las validaciones, se deshace todo lo hecho dentro de la
    -- transacción (ROLLBACK) y se reenvía el error original a quien llamó
    -- al procedimiento (RESIGNAL).
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- La cantidad debe ser un número positivo.
    IF p_cantidad_devuelta IS NULL OR p_cantidad_devuelta <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: La cantidad a devolver debe ser mayor que cero.';
    END IF;

    START TRANSACTION;

    -- Se lee el estado de la venta y se BLOQUEA su fila (FOR UPDATE) hasta el
    -- COMMIT o ROLLBACK. Así dos devoluciones simultáneas de la misma venta se
    -- procesan una detrás de otra y no pueden superar juntas lo comprado.
    SELECT estado INTO v_estado_actual
    FROM ventas
    WHERE id_venta = p_id_venta
    FOR UPDATE;

    IF v_estado_actual IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: La venta indicada no existe.';
    END IF;

    -- Regla de negocio: solo se devuelve mercancía que ya llegó al cliente.
    -- Una venta pendiente, en proceso o enviada se cancela, no se devuelve; una
    -- cancelada o devuelta totalmente ya no tiene nada que devolver.
    IF v_estado_actual NOT IN ('Entregado', 'Devolución Parcial') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Solo se aceptan devoluciones de ventas Entregadas o con Devolución Parcial.';
    END IF;

    -- Cantidad comprada de este producto en esta venta. Se usa SUM porque el
    -- mismo producto podría aparecer en más de una línea del pedido.
    SELECT COALESCE(SUM(cantidad), 0), COALESCE(SUM(subtotal), 0.00)
    INTO v_cantidad_comprada, v_subtotal_comprado
    FROM detalle_ventas
    WHERE id_venta = p_id_venta
      AND id_producto = p_id_producto;

    IF v_cantidad_comprada = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: El producto indicado no forma parte de esta venta.';
    END IF;

    -- REQUISITO 1: la cantidad devuelta no puede superar la comprada.
    -- Se descuentan las devoluciones anteriores del mismo producto en la misma
    -- venta; si no, se podría devolver 1 unidad varias veces habiendo comprado 1.
    SELECT COALESCE(SUM(cantidad_devuelta), 0)
    INTO v_ya_devuelto
    FROM devoluciones
    WHERE id_venta = p_id_venta
      AND id_producto = p_id_producto;

    IF p_cantidad_devuelta > v_cantidad_comprada - v_ya_devuelto THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: La cantidad a devolver supera lo comprado en esta venta (descontando devoluciones previas).';
    END IF;

    -- Se reembolsa el precio al que se vendió (congelado en la venta), no el
    -- precio actual del catálogo, que pudo cambiar desde entonces.
    SET v_precio_unitario = ROUND(v_subtotal_comprado / v_cantidad_comprada, 2);
    SET v_monto_reembolso = ROUND(v_precio_unitario * p_cantidad_devuelta, 2);

    -- REQUISITO 2: las unidades devueltas vuelven al inventario.
    UPDATE productos
    SET stock = stock + p_cantidad_devuelta
    WHERE id_producto = p_id_producto;

    -- REQUISITO 3: nuevo estado de la venta.
    -- Se compara el total de unidades de TODA la venta (todos sus productos)
    -- con el total devuelto (devoluciones anteriores + la actual). Si ya se
    -- devolvió todo, la venta queda 'Devuelto Totalmente'; si no, 'Devolución
    -- Parcial'. Ejemplo: en una venta de laptop + audífonos, devolver solo la
    -- laptop deja la venta en 'Devolución Parcial'.
    SELECT COALESCE(SUM(cantidad), 0)
    INTO v_unidades_venta
    FROM detalle_ventas
    WHERE id_venta = p_id_venta;

    SELECT COALESCE(SUM(cantidad_devuelta), 0) + p_cantidad_devuelta
    INTO v_unidades_devueltas
    FROM devoluciones
    WHERE id_venta = p_id_venta;

    IF v_unidades_devueltas >= v_unidades_venta THEN
        SET v_nuevo_estado = 'Devuelto Totalmente';
    ELSE
        SET v_nuevo_estado = 'Devolución Parcial';
    END IF;

    -- El trigger trg_log_order_status_change (script 05) registra además este
    -- cambio de estado en historial_pedidos_estado.
    UPDATE ventas
    SET estado = v_nuevo_estado
    WHERE id_venta = p_id_venta;

    -- REQUISITO 4: registro de la operación para futuras auditorías.
    INSERT INTO devoluciones (
        id_venta, id_producto, cantidad_devuelta, precio_unitario,
        monto_reembolso, estado_venta_resultante, usuario
    )
    VALUES (
        p_id_venta, p_id_producto, p_cantidad_devuelta, v_precio_unitario,
        v_monto_reembolso, v_nuevo_estado, CURRENT_USER()
    );

    -- Todo salió bien: se confirman los cuatro cambios a la vez.
    COMMIT;

    -- Resumen de la operación para quien ejecuta el CALL.
    SELECT p_id_venta          AS id_venta,
           p_id_producto       AS id_producto,
           p_cantidad_devuelta AS cantidad_devuelta,
           v_monto_reembolso   AS monto_reembolso,
           v_nuevo_estado      AS nuevo_estado_venta;
END //

DELIMITER ;

-- =============================================================================
-- 4. PRUEBAS (comentadas: ejecutarlas a mano, una por una y en este orden,
--    justo después de cargar los scripts 01 al 08)
-- =============================================================================
-- Venta 5: 2 laptops (producto 1), estado 'Entregado'. Stock inicial: 25.
-- CALL sp_ProcesarDevolucion(5, 1, 1);   -- OK: 'Devolución Parcial', stock 26
-- CALL sp_ProcesarDevolucion(5, 1, 1);   -- OK: 'Devuelto Totalmente', stock 27
-- CALL sp_ProcesarDevolucion(5, 1, 1);   -- ERROR: la venta ya fue devuelta totalmente
--
-- Venta 1: 1 laptop (producto 1) + 1 audífonos (producto 3), 'Entregado'.
-- CALL sp_ProcesarDevolucion(1, 1, 5);   -- ERROR: compró 1, intenta devolver 5
-- CALL sp_ProcesarDevolucion(1, 20, 1);  -- ERROR: el producto 20 no está en la venta
-- CALL sp_ProcesarDevolucion(1, 3, 0);   -- ERROR: cantidad debe ser mayor que cero
-- CALL sp_ProcesarDevolucion(999, 1, 1); -- ERROR: la venta no existe
-- CALL sp_ProcesarDevolucion(30, 5, 1);  -- ERROR: la venta 30 está Cancelada
-- CALL sp_ProcesarDevolucion(1, 3, 1);   -- OK: 'Devolución Parcial' (falta la laptop)
--
-- Verificación de resultados:
-- SELECT * FROM devoluciones;
-- SELECT id_venta, estado FROM ventas WHERE id_venta IN (1, 5);
-- SELECT id_producto, stock FROM productos WHERE id_producto IN (1, 3);
-- SELECT * FROM historial_pedidos_estado WHERE id_venta IN (1, 5);
