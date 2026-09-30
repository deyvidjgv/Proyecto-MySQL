-- =============================================================================
-- PROYECTO: Base de Datos para un E-commerce
-- SCRIPT: 07_Procedimientos_Almacenados.sql
-- DESCRIPCIÓN: 20 Procedimientos almacenados (Stored Procedures) con control
--              transaccional (START TRANSACTION, COMMIT, ROLLBACK) y lógica de negocio.
-- =============================================================================

USE ecommerce_db;

-- Tabla de soporte para auditoría de ajustes manuales de inventario
CREATE TABLE IF NOT EXISTS ajustes_inventario (
    id_ajuste INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    stock_anterior INT NOT NULL,
    stock_nuevo INT NOT NULL,
    motivo VARCHAR(255) NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ajuste_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE
) ENGINE=InnoDB;

DELIMITER //

-- -----------------------------------------------------------------------------
-- 1. sp_RealizarNuevaVenta
-- Procesa una nueva orden de venta con sus detalles de forma transaccional.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_RealizarNuevaVenta //
CREATE PROCEDURE sp_RealizarNuevaVenta(
    IN p_id_cliente INT,
    IN p_id_sucursal INT,
    IN p_id_producto INT,
    IN p_cantidad INT,
    OUT p_id_venta INT
)
BEGIN
    DECLARE v_precio DECIMAL(10,2);
    DECLARE v_stock INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT precio, stock INTO v_precio, v_stock
    FROM productos
    WHERE id_producto = p_id_producto FOR UPDATE;

    IF v_stock < p_cantidad THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Inventario insuficiente para realizar la venta.';
    END IF;

    INSERT INTO ventas (id_cliente, id_sucursal, fecha_venta, estado, total)
    VALUES (p_id_cliente, p_id_sucursal, NOW(), 'Pendiente de Pago', ROUND(v_precio * p_cantidad, 2));

    SET p_id_venta = LAST_INSERT_ID();

    INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario_congelado, subtotal)
    VALUES (p_id_venta, p_id_producto, p_cantidad, v_precio, ROUND(v_precio * p_cantidad, 2));

    COMMIT;
END //

-- -----------------------------------------------------------------------------
-- 2. sp_AgregarNuevoProducto
-- Inserta un nuevo producto en catálogo con validaciones de atributos.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_AgregarNuevoProducto //
CREATE PROCEDURE sp_AgregarNuevoProducto(
    IN p_nombre VARCHAR(150),
    IN p_descripcion TEXT,
    IN p_precio DECIMAL(10,2),
    IN p_costo DECIMAL(10,2),
    IN p_stock INT,
    IN p_stock_minimo INT,
    IN p_sku VARCHAR(50),
    IN p_peso_kg DECIMAL(8,2),
    IN p_id_categoria INT,
    IN p_id_proveedor INT
)
BEGIN
    IF p_precio <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El precio debe ser mayor a cero.';
    END IF;

    INSERT INTO productos (
        nombre, descripcion, precio, costo, stock, stock_minimo, 
        sku, peso_kg, fecha_creacion, activo, id_categoria, id_proveedor
    ) VALUES (
        p_nombre, p_descripcion, p_precio, p_costo, p_stock, p_stock_minimo,
        p_sku, p_peso_kg, NOW(), TRUE, p_id_categoria, p_id_proveedor
    );
END //

-- -----------------------------------------------------------------------------
-- 3. sp_ActualizarDireccionCliente
-- Actualiza la dirección y ciudad de entrega de un cliente registrado.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ActualizarDireccionCliente //
CREATE PROCEDURE sp_ActualizarDireccionCliente(
    IN p_id_cliente INT,
    IN p_nueva_direccion TEXT,
    IN p_nueva_ciudad VARCHAR(100)
)
BEGIN
    UPDATE clientes
    SET direccion_envio = p_nueva_direccion,
        ciudad = p_nueva_ciudad
    WHERE id_cliente = p_id_cliente;
END //

-- -----------------------------------------------------------------------------
-- 4. sp_ProcesarDevolucion
-- Registra devolución, restituye inventario y genera saldo/crédito.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ProcesarDevolucion //
CREATE PROCEDURE sp_ProcesarDevolucion(
    IN p_id_venta INT,
    IN p_id_producto INT,
    IN p_cantidad INT,
    IN p_motivo VARCHAR(255)
)
BEGIN
    DECLARE v_precio_congelado DECIMAL(10,2);
    DECLARE v_monto_credito DECIMAL(10,2);
    DECLARE v_cantidad_vendida INT DEFAULT 0;
    DECLARE v_ya_devuelto INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: La cantidad a devolver debe ser mayor a cero.';
    END IF;

    SELECT precio_unitario_congelado, cantidad
    INTO v_precio_congelado, v_cantidad_vendida
    FROM detalle_ventas
    WHERE id_venta = p_id_venta AND id_producto = p_id_producto
    LIMIT 1;

    IF v_precio_congelado IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: No se encontró la venta o producto especificado para devolución.';
    END IF;

    -- Suma de lo ya devuelto de esa linea, para no devolver mas de lo comprado.
    SELECT COALESCE(SUM(cantidad), 0) INTO v_ya_devuelto
    FROM devoluciones
    WHERE id_venta = p_id_venta AND id_producto = p_id_producto;

    IF (v_ya_devuelto + p_cantidad) > v_cantidad_vendida THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: La cantidad devuelta supera las unidades compradas en esa venta.';
    END IF;

    SET v_monto_credito = ROUND(v_precio_congelado * p_cantidad, 2);

    INSERT INTO devoluciones (id_venta, id_producto, cantidad, monto_credito, motivo, fecha)
    VALUES (p_id_venta, p_id_producto, p_cantidad, v_monto_credito, p_motivo, NOW());

    UPDATE productos
    SET stock = stock + p_cantidad
    WHERE id_producto = p_id_producto;

    COMMIT;
END //

-- -----------------------------------------------------------------------------
-- 5. sp_ObtenerHistorialComprasCliente
-- Consulta el resumen cronológico de compras realizadas por un cliente.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ObtenerHistorialComprasCliente //
CREATE PROCEDURE sp_ObtenerHistorialComprasCliente(
    IN p_id_cliente INT
)
BEGIN
    SELECT 
        v.id_venta,
        v.fecha_venta,
        v.estado,
        v.total,
        p.nombre AS producto,
        dv.cantidad,
        dv.precio_unitario_congelado,
        dv.subtotal
    FROM ventas v
    JOIN detalle_ventas dv ON v.id_venta = dv.id_venta
    JOIN productos p ON dv.id_producto = p.id_producto
    WHERE v.id_cliente = p_id_cliente
    ORDER BY v.fecha_venta DESC;
END //

-- -----------------------------------------------------------------------------
-- 6. sp_AjustarNivelStock
-- Modifica manualmente existencias registrando la justificación en auditoría.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_AjustarNivelStock //
CREATE PROCEDURE sp_AjustarNivelStock(
    IN p_id_producto INT,
    IN p_nuevo_stock INT,
    IN p_motivo VARCHAR(255)
)
BEGIN
    DECLARE v_stock_anterior INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT stock INTO v_stock_anterior
    FROM productos
    WHERE id_producto = p_id_producto FOR UPDATE;

    IF p_nuevo_stock < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El nivel de stock ajustado no puede ser negativo.';
    END IF;

    INSERT INTO ajustes_inventario (id_producto, stock_anterior, stock_nuevo, motivo, usuario, fecha)
    VALUES (p_id_producto, v_stock_anterior, p_nuevo_stock, p_motivo, CURRENT_USER(), NOW());

    UPDATE productos
    SET stock = p_nuevo_stock
    WHERE id_producto = p_id_producto;

    COMMIT;
END //

-- -----------------------------------------------------------------------------
-- 7. sp_EliminarClienteDeFormaSegura
-- Anonimiza datos personales preservando integridad referencial histórica.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_EliminarClienteDeFormaSegura //
CREATE PROCEDURE sp_EliminarClienteDeFormaSegura(
    IN p_id_cliente INT
)
BEGIN
    UPDATE clientes
    SET nombre = 'Anonimizado',
        apellido = 'Usuario',
        email = CONCAT('usuario_anonimo_', p_id_cliente, '@gdpr-deleted.com'),
        direccion_envio = 'Dirección Eliminada',
        ciudad = NULL,
        activo = FALSE
    WHERE id_cliente = p_id_cliente;
END //

-- -----------------------------------------------------------------------------
-- 8. sp_AplicarDescuentoPorCategoria
-- Modifica masivamente el precio de los productos de una categoría con descuento.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_AplicarDescuentoPorCategoria //
CREATE PROCEDURE sp_AplicarDescuentoPorCategoria(
    IN p_id_categoria INT,
    IN p_porcentaje DECIMAL(5,2)
)
BEGIN
    IF p_porcentaje <= 0 OR p_porcentaje >= 100 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Porcentaje de descuento inválido.';
    END IF;

    UPDATE productos
    SET precio = ROUND(precio * (1.0 - (p_porcentaje / 100.0)), 2)
    WHERE id_categoria = p_id_categoria AND activo = TRUE;
END //

-- -----------------------------------------------------------------------------
-- 9. sp_GenerarReporteMensualVentas
-- Genera reporte consolidado de facturación de un mes y año dados.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_GenerarReporteMensualVentas //
CREATE PROCEDURE sp_GenerarReporteMensualVentas(
    IN p_mes INT,
    IN p_anio INT
)
BEGIN
    SELECT 
        DATE_FORMAT(v.fecha_venta, '%Y-%m-%d') AS fecha,
        COUNT(DISTINCT v.id_venta) AS total_pedidos,
        SUM(dv.cantidad) AS articulos_vendidos,
        SUM(v.total) AS recaudacion_total,
        ROUND(AVG(v.total), 2) AS ticket_promedio
    FROM ventas v
    JOIN detalle_ventas dv ON v.id_venta = dv.id_venta
    WHERE MONTH(v.fecha_venta) = p_mes
      AND YEAR(v.fecha_venta) = p_anio
      AND v.estado != 'Cancelado'
    GROUP BY DATE_FORMAT(v.fecha_venta, '%Y-%m-%d')
    ORDER BY fecha ASC;
END //

-- -----------------------------------------------------------------------------
-- 10. sp_CambiarEstadoPedido
-- Actualiza estado del pedido ('Procesando', 'Enviado', 'Entregado', 'Cancelado').
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_CambiarEstadoPedido //
CREATE PROCEDURE sp_CambiarEstadoPedido(
    IN p_id_venta INT,
    IN p_nuevo_estado VARCHAR(50)
)
BEGIN
    DECLARE v_existe INT DEFAULT 0;

    IF p_nuevo_estado NOT IN ('Pendiente de Pago', 'Procesando', 'Enviado', 'Entregado', 'Cancelado') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Estado de orden de venta no válido.';
    END IF;

    -- Sin esta comprobacion un id inexistente no daba error: el UPDATE
    -- simplemente afectaba 0 filas y el llamador creia que habia funcionado.
    SELECT COUNT(*) INTO v_existe FROM ventas WHERE id_venta = p_id_venta;

    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: La orden de venta indicada no existe.';
    END IF;

    UPDATE ventas
    SET estado = p_nuevo_estado
    WHERE id_venta = p_id_venta;
END //

-- -----------------------------------------------------------------------------
-- 11. sp_RegistrarNuevoCliente
-- Registra un nuevo cliente validando unicidad de correo y requisitos.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_RegistrarNuevoCliente //
CREATE PROCEDURE sp_RegistrarNuevoCliente(
    IN p_nombre VARCHAR(100),
    IN p_apellido VARCHAR(100),
    IN p_email VARCHAR(150),
    IN p_contraseña VARCHAR(255),
    IN p_direccion TEXT,
    IN p_ciudad VARCHAR(100),
    IN p_fecha_nacimiento DATE
)
BEGIN
    DECLARE v_existe INT DEFAULT 0;

    SELECT COUNT(*) INTO v_existe
    FROM clientes
    WHERE email = p_email;

    IF v_existe > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Ya existe un cliente registrado con ese correo electrónico.';
    END IF;

    INSERT INTO clientes (
        nombre, apellido, email, `contraseña`, direccion_envio, 
        ciudad, fecha_nacimiento, fecha_registro, total_gastado, nivel_lealtad, activo
    ) VALUES (
        p_nombre, p_apellido, p_email, p_contraseña, p_direccion,
        p_ciudad, p_fecha_nacimiento, NOW(), 0.00, 'Bronce', TRUE
    );
END //

-- -----------------------------------------------------------------------------
-- 12. sp_ObtenerDetallesProductoCompleto
-- Devuelve catálogo de producto incluyendo proveedor y categoría.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ObtenerDetallesProductoCompleto //
CREATE PROCEDURE sp_ObtenerDetallesProductoCompleto(
    IN p_id_producto INT
)
BEGIN
    SELECT 
        p.id_producto,
        p.nombre AS producto,
        p.descripcion,
        p.precio,
        p.costo,
        (p.precio - p.costo) AS margen_unitario,
        p.stock,
        p.stock_minimo,
        p.sku,
        p.peso_kg,
        c.nombre AS categoria,
        pr.nombre AS proveedor,
        pr.email_contacto AS contacto_proveedor
    FROM productos p
    JOIN categorias c ON p.id_categoria = c.id_categoria
    JOIN proveedores pr ON p.id_proveedor = pr.id_proveedor
    WHERE p.id_producto = p_id_producto;
END //

-- -----------------------------------------------------------------------------
-- 13. sp_FusionarCuentasCliente
-- Fusiona dos cuentas de cliente duplicadas migrando compras de forma atómica.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_FusionarCuentasCliente //
CREATE PROCEDURE sp_FusionarCuentasCliente(
    IN p_id_cliente_origen INT,
    IN p_id_cliente_destino INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    UPDATE ventas
    SET id_cliente = p_id_cliente_destino
    WHERE id_cliente = p_id_cliente_origen;

    UPDATE carritos_abandonados
    SET id_cliente = p_id_cliente_destino
    WHERE id_cliente = p_id_cliente_origen;

    UPDATE `reseñas_productos`
    SET id_cliente = p_id_cliente_destino
    WHERE id_cliente = p_id_cliente_origen;

    -- Recalcula gasto total acumulado en la cuenta destino
    UPDATE clientes
    SET total_gastado = (
        SELECT COALESCE(SUM(total), 0.00) 
        FROM ventas 
        WHERE id_cliente = p_id_cliente_destino AND estado != 'Cancelado'
    )
    WHERE id_cliente = p_id_cliente_destino;

    -- Inhabilita la cuenta origen duplicada
    UPDATE clientes
    SET activo = FALSE,
        email = CONCAT('fusionado_', p_id_cliente_origen, '@inactivo.local')
    WHERE id_cliente = p_id_cliente_origen;

    COMMIT;
END //

-- -----------------------------------------------------------------------------
-- 14. sp_AsignarProductoAProveedor
-- Reasigna un artículo de catálogo a un nuevo proveedor registrado.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_AsignarProductoAProveedor //
CREATE PROCEDURE sp_AsignarProductoAProveedor(
    IN p_id_producto INT,
    IN p_id_proveedor INT
)
BEGIN
    UPDATE productos
    SET id_proveedor = p_id_proveedor
    WHERE id_producto = p_id_producto;
END //

-- -----------------------------------------------------------------------------
-- 15. sp_BuscarProductos
-- Búsqueda avanzada de artículos con filtros combinados por nombre, categoría y precio.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_BuscarProductos //
CREATE PROCEDURE sp_BuscarProductos(
    IN p_termino VARCHAR(100),
    IN p_id_categoria INT,
    IN p_precio_min DECIMAL(10,2),
    IN p_precio_max DECIMAL(10,2)
)
BEGIN
    SELECT 
        p.id_producto,
        p.nombre,
        p.precio,
        p.stock,
        p.sku,
        c.nombre AS categoria
    FROM productos p
    JOIN categorias c ON p.id_categoria = c.id_categoria
    WHERE (p_termino IS NULL OR p.nombre LIKE CONCAT('%', p_termino, '%') OR p.descripcion LIKE CONCAT('%', p_termino, '%'))
      AND (p_id_categoria IS NULL OR p.id_categoria = p_id_categoria)
      AND (p_precio_min IS NULL OR p.precio >= p_precio_min)
      AND (p_precio_max IS NULL OR p.precio <= p_precio_max)
      AND p.activo = TRUE
    ORDER BY p.precio ASC;
END //

-- -----------------------------------------------------------------------------
-- 16. sp_ObtenerDashboardAdmin
-- Retorna resumen ejecutivo instantáneo de KPIs para el panel de administración.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ObtenerDashboardAdmin //
CREATE PROCEDURE sp_ObtenerDashboardAdmin()
BEGIN
    SELECT 
        (SELECT COUNT(*) FROM ventas WHERE DATE(fecha_venta) = CURDATE()) AS ventas_hoy,
        (SELECT COALESCE(SUM(total), 0.00) FROM ventas WHERE DATE(fecha_venta) = CURDATE()) AS ingresos_hoy,
        (SELECT COUNT(*) FROM clientes WHERE DATE(fecha_registro) = CURDATE()) AS clientes_nuevos_hoy,
        (SELECT COUNT(*) FROM clientes WHERE activo = TRUE) AS clientes_activos,
        (SELECT COUNT(*) FROM productos WHERE stock <= stock_minimo AND activo = TRUE) AS productos_alerta_stock,
        (SELECT COUNT(*) FROM ventas WHERE estado = 'Pendiente de Pago') AS ordenes_pendientes;
END //

-- -----------------------------------------------------------------------------
-- 17. sp_ProcesarPago
-- Valida el pago y avanza el estado de la venta de Pendiente a Procesando.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ProcesarPago //
CREATE PROCEDURE sp_ProcesarPago(
    IN p_id_venta INT,
    IN p_monto_pagado DECIMAL(12,2)
)
BEGIN
    DECLARE v_total_orden DECIMAL(12,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT total INTO v_total_orden
    FROM ventas
    WHERE id_venta = p_id_venta FOR UPDATE;

    IF v_total_orden IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Orden de venta no encontrada.';
    END IF;

    IF p_monto_pagado < v_total_orden THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Monto pagado inferior al importe total de la orden.';
    END IF;

    UPDATE ventas
    SET estado = 'Procesando'
    WHERE id_venta = p_id_venta;

    COMMIT;
END //

-- -----------------------------------------------------------------------------
-- 18. sp_AñadirReseñaProducto
-- Permite reseñar un artículo validando que el cliente lo haya comprado previamente.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_AñadirReseñaProducto` //
CREATE PROCEDURE `sp_AñadirReseñaProducto`(
    IN p_id_cliente INT,
    IN p_id_producto INT,
    IN p_calificacion INT,
    IN p_comentario TEXT
)
BEGIN
    DECLARE v_ha_comprado INT DEFAULT 0;

    SELECT COUNT(*) INTO v_ha_comprado
    FROM ventas v
    JOIN detalle_ventas dv ON v.id_venta = dv.id_venta
    WHERE v.id_cliente = p_id_cliente
      AND dv.id_producto = p_id_producto
      AND v.estado = 'Entregado';

    IF v_ha_comprado = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Sólo los clientes con órdenes entregadas pueden reseñar este producto.';
    END IF;

    INSERT INTO `reseñas_productos` (id_cliente, id_producto, calificacion, comentario, fecha)
    VALUES (p_id_cliente, p_id_producto, p_calificacion, p_comentario, NOW());
END //

-- -----------------------------------------------------------------------------
-- 19. sp_ObtenerProductosRelacionados
-- Retorna artículos comprados habitualmente por clientes que ordenaron el mismo producto.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ObtenerProductosRelacionados //
CREATE PROCEDURE sp_ObtenerProductosRelacionados(
    IN p_id_producto INT
)
BEGIN
    SELECT 
        p2.id_producto,
        p2.nombre AS producto_relacionado,
        c.nombre AS categoria,
        COUNT(*) AS veces_comprados_juntos
    FROM detalle_ventas dv1
    JOIN detalle_ventas dv2 ON dv1.id_venta = dv2.id_venta AND dv1.id_producto != dv2.id_producto
    JOIN productos p2 ON dv2.id_producto = p2.id_producto
    JOIN categorias c ON p2.id_categoria = c.id_categoria
    WHERE dv1.id_producto = p_id_producto
    GROUP BY p2.id_producto, p2.nombre, c.nombre
    ORDER BY veces_comprados_juntos DESC
    LIMIT 5;
END //

-- -----------------------------------------------------------------------------
-- 20. sp_MoverProductosEntreCategorias
-- Mueve de forma segura y transaccional productos de una categoría a otra.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_MoverProductosEntreCategorias //
CREATE PROCEDURE sp_MoverProductosEntreCategorias(
    IN p_id_categoria_origen INT,
    IN p_id_categoria_destino INT
)
BEGIN
    DECLARE v_existe_destino INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT COUNT(*) INTO v_existe_destino
    FROM categorias
    WHERE id_categoria = p_id_categoria_destino;

    IF v_existe_destino = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: La categoria de destino no existe.';
    END IF;

    UPDATE productos
    SET id_categoria = p_id_categoria_destino
    WHERE id_categoria = p_id_categoria_origen;

    -- NO se ajusta 'categorias.total_productos' aqui: el trigger
    -- trg_move_producto_count_on_update (05_Triggers.sql) ya traslada el conteo
    -- de la categoria origen a la destino en cada fila actualizada. Hacerlo
    -- tambien desde el procedimiento contaria los movimientos DOS VECES.

    COMMIT;
END //

DELIMITER ;
