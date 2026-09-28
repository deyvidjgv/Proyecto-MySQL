-- =============================================================================
-- PROYECTO: Base de Datos para un E-commerce
-- SCRIPT: 03_Funciones.sql
-- DESCRIPCIÓN: 20 Funciones definidas por el usuario (UDF) para encapsular
--              lógica de negocio y cálculos reutilizables.
-- =============================================================================

USE ecommerce_db;

DELIMITER //

-- -----------------------------------------------------------------------------
-- 1. fn_CalcularTotalVenta
-- Calcula el monto total acumulado de una venta sumando sus subtotales.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_CalcularTotalVenta //
CREATE FUNCTION fn_CalcularTotalVenta(p_id_venta INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12,2);
    SELECT COALESCE(SUM(subtotal), 0.00)
    INTO v_total
    FROM detalle_ventas
    WHERE id_venta = p_id_venta;
    RETURN v_total;
END //

-- -----------------------------------------------------------------------------
-- 2. fn_VerificarDisponibilidadStock
-- Valida si existe suficiente inventario para surtir una cantidad solicitada.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_VerificarDisponibilidadStock //
CREATE FUNCTION fn_VerificarDisponibilidadStock(p_id_producto INT, p_cantidad_requerida INT)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_stock INT DEFAULT 0;
    SELECT COALESCE(stock, 0)
    INTO v_stock
    FROM productos
    WHERE id_producto = p_id_producto;
    
    RETURN (v_stock >= p_cantidad_requerida AND p_cantidad_requerida > 0);
END //

-- -----------------------------------------------------------------------------
-- 3. fn_ObtenerPrecioProducto
-- Devuelve el precio comercial vigente de un producto dado su identificador.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ObtenerPrecioProducto //
CREATE FUNCTION fn_ObtenerPrecioProducto(p_id_producto INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_precio DECIMAL(10,2) DEFAULT 0.00;
    SELECT COALESCE(precio, 0.00)
    INTO v_precio
    FROM productos
    WHERE id_producto = p_id_producto;
    RETURN v_precio;
END //

-- -----------------------------------------------------------------------------
-- 4. fn_CalcularEdadCliente
-- Calcula la edad exacta de un cliente a partir de su fecha de nacimiento.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_CalcularEdadCliente //
CREATE FUNCTION fn_CalcularEdadCliente(p_id_cliente INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_nacimiento DATE;
    SELECT fecha_nacimiento
    INTO v_nacimiento
    FROM clientes
    WHERE id_cliente = p_id_cliente;
    
    IF v_nacimiento IS NULL THEN
        RETURN NULL;
    END IF;
    
    RETURN TIMESTAMPDIFF(YEAR, v_nacimiento, CURDATE());
END //

-- -----------------------------------------------------------------------------
-- 5. fn_FormatearNombreCompleto
-- Devuelve el nombre y apellido en formato estandarizado 'Apellido, Nombre'.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_FormatearNombreCompleto //
CREATE FUNCTION fn_FormatearNombreCompleto(p_nombre VARCHAR(100), p_apellido VARCHAR(100))
RETURNS VARCHAR(250)
DETERMINISTIC
NO SQL
BEGIN
    RETURN CONCAT(TRIM(p_apellido), ', ', TRIM(p_nombre));
END //

-- -----------------------------------------------------------------------------
-- 6. fn_EsClienteNuevo
-- Devuelve VERDADERO si la primera compra del cliente fue en los últimos 30 días.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_EsClienteNuevo //
CREATE FUNCTION fn_EsClienteNuevo(p_id_cliente INT)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_primer_pedido DATETIME;
    SELECT MIN(fecha_venta)
    INTO v_primer_pedido
    FROM ventas
    WHERE id_cliente = p_id_cliente AND estado != 'Cancelado';
    
    IF v_primer_pedido IS NULL THEN
        RETURN FALSE;
    END IF;
    
    RETURN (DATEDIFF(NOW(), v_primer_pedido) <= 30);
END //

-- -----------------------------------------------------------------------------
-- 7. fn_CalcularCostoEnvio
-- Calcula el costo de envío con base en el peso total de los productos de la venta.
-- Tarifa: Base de $5.00 + $2.50 por cada kilogramo.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_CalcularCostoEnvio //
CREATE FUNCTION fn_CalcularCostoEnvio(p_id_venta INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_peso_total DECIMAL(10,2) DEFAULT 0.00;
    
    SELECT COALESCE(SUM(dv.cantidad * p.peso_kg), 0.00)
    INTO v_peso_total
    FROM detalle_ventas dv
    JOIN productos p ON dv.id_producto = p.id_producto
    WHERE dv.id_venta = p_id_venta;
    
    IF v_peso_total = 0 THEN
        RETURN 0.00;
    END IF;
    
    RETURN ROUND(5.00 + (v_peso_total * 2.50), 2);
END //

-- -----------------------------------------------------------------------------
-- 8. fn_AplicarDescuento
-- Aplica un porcentaje de descuento a un monto base dado.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_AplicarDescuento //
CREATE FUNCTION fn_AplicarDescuento(p_monto DECIMAL(12,2), p_porcentaje DECIMAL(5,2))
RETURNS DECIMAL(12,2)
DETERMINISTIC
NO SQL
BEGIN
    IF p_porcentaje <= 0 THEN
        RETURN p_monto;
    ELSEIF p_porcentaje >= 100 THEN
        RETURN 0.00;
    END IF;
    
    RETURN ROUND(p_monto - (p_monto * (p_porcentaje / 100.0)), 2);
END //

-- -----------------------------------------------------------------------------
-- 9. fn_ObtenerUltimaFechaCompra
-- Devuelve la fecha y hora de la última compra registrada de un cliente.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ObtenerUltimaFechaCompra //
CREATE FUNCTION fn_ObtenerUltimaFechaCompra(p_id_cliente INT)
RETURNS DATETIME
READS SQL DATA
BEGIN
    DECLARE v_fecha DATETIME;
    SELECT MAX(fecha_venta)
    INTO v_fecha
    FROM ventas
    WHERE id_cliente = p_id_cliente AND estado != 'Cancelado';
    RETURN v_fecha;
END //

-- -----------------------------------------------------------------------------
-- 10. fn_ValidarFormatoEmail
-- Comprueba si una cadena posee estructura válida de correo electrónico.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ValidarFormatoEmail //
CREATE FUNCTION fn_ValidarFormatoEmail(p_email VARCHAR(150))
RETURNS BOOLEAN
DETERMINISTIC
NO SQL
BEGIN
    RETURN (p_email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$');
END //

-- -----------------------------------------------------------------------------
-- 11. fn_ObtenerNombreCategoria
-- Devuelve el nombre de la categoría a partir del ID de un producto.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ObtenerNombreCategoria //
CREATE FUNCTION fn_ObtenerNombreCategoria(p_id_producto INT)
RETURNS VARCHAR(100)
READS SQL DATA
BEGIN
    DECLARE v_nombre_cat VARCHAR(100);
    SELECT c.nombre
    INTO v_nombre_cat
    FROM categorias c
    JOIN productos p ON c.id_categoria = p.id_categoria
    WHERE p.id_producto = p_id_producto;
    RETURN COALESCE(v_nombre_cat, 'Sin Categoría');
END //

-- -----------------------------------------------------------------------------
-- 12. fn_ContarVentasCliente
-- Cuenta el número total de compras válidas realizadas por un cliente.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ContarVentasCliente //
CREATE FUNCTION fn_ContarVentasCliente(p_id_cliente INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_total_compras INT DEFAULT 0;
    SELECT COUNT(*)
    INTO v_total_compras
    FROM ventas
    WHERE id_cliente = p_id_cliente AND estado != 'Cancelado';
    RETURN v_total_compras;
END //

-- -----------------------------------------------------------------------------
-- 13. fn_CalcularDiasDesdeUltimaCompra
-- Devuelve los días transcurridos desde la última transacción de un cliente.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_CalcularDiasDesdeUltimaCompra //
CREATE FUNCTION fn_CalcularDiasDesdeUltimaCompra(p_id_cliente INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_ultima_fecha DATETIME;
    SELECT MAX(fecha_venta)
    INTO v_ultima_fecha
    FROM ventas
    WHERE id_cliente = p_id_cliente AND estado != 'Cancelado';
    
    IF v_ultima_fecha IS NULL THEN
        RETURN NULL;
    END IF;
    
    RETURN DATEDIFF(NOW(), v_ultima_fecha);
END //

-- -----------------------------------------------------------------------------
-- 14. fn_DeterminarEstadoLealtad
-- Clasifica el nivel de lealtad (Bronce, Plata, Oro) de acuerdo con el gasto total.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_DeterminarEstadoLealtad //
CREATE FUNCTION fn_DeterminarEstadoLealtad(p_gasto_total DECIMAL(12,2))
RETURNS VARCHAR(20)
DETERMINISTIC
NO SQL
BEGIN
    IF p_gasto_total >= 3000.00 THEN
        RETURN 'Oro';
    ELSEIF p_gasto_total >= 1500.00 THEN
        RETURN 'Plata';
    ELSE
        RETURN 'Bronce';
    END IF;
END //

-- -----------------------------------------------------------------------------
-- 15. fn_GenerarSKU
-- Genera un código SKU estructurado combinando categoría, nombre e ID.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_GenerarSKU //
CREATE FUNCTION fn_GenerarSKU(p_nombre_producto VARCHAR(150), p_nombre_categoria VARCHAR(100), p_id INT)
RETURNS VARCHAR(50)
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_prefijo_cat VARCHAR(3);
    DECLARE v_prefijo_prod VARCHAR(3);
    
    SET v_prefijo_cat = UPPER(SUBSTRING(REPLACE(p_nombre_categoria, ' ', ''), 1, 3));
    SET v_prefijo_prod = UPPER(SUBSTRING(REPLACE(p_nombre_producto, ' ', ''), 1, 3));
    
    RETURN CONCAT(v_prefijo_cat, '-', v_prefijo_prod, '-', LPAD(p_id, 3, '0'));
END //

-- -----------------------------------------------------------------------------
-- 16. fn_CalcularIVA
-- Calcula el monto del impuesto al valor agregado (IVA) sobre una base imponible.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_CalcularIVA //
CREATE FUNCTION fn_CalcularIVA(p_total DECIMAL(12,2), p_tasa_iva DECIMAL(5,2))
RETURNS DECIMAL(12,2)
DETERMINISTIC
NO SQL
BEGIN
    IF p_total <= 0 OR p_tasa_iva <= 0 THEN
        RETURN 0.00;
    END IF;
    RETURN ROUND(p_total * (p_tasa_iva / 100.0), 2);
END //

-- -----------------------------------------------------------------------------
-- 17. fn_ObtenerStockTotalPorCategoria
-- Suma las existencias en inventario de todos los artículos de una categoría.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ObtenerStockTotalPorCategoria //
CREATE FUNCTION fn_ObtenerStockTotalPorCategoria(p_id_categoria INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_stock_total INT DEFAULT 0;
    SELECT COALESCE(SUM(stock), 0)
    INTO v_stock_total
    FROM productos
    WHERE id_categoria = p_id_categoria;
    RETURN v_stock_total;
END //

-- -----------------------------------------------------------------------------
-- 18. fn_EstimarFechaEntrega
-- Calcula la fecha de entrega estimada según la ciudad de destino.
-- Bogotá: 2 días | Medellín/Cali: 3 días | Otras: 5 días hábiles.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_EstimarFechaEntrega //
CREATE FUNCTION fn_EstimarFechaEntrega(p_ciudad VARCHAR(100), p_fecha_pedido DATETIME)
RETURNS DATE
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_dias INT DEFAULT 5;
    
    IF p_ciudad = 'Bogotá' THEN
        SET v_dias = 2;
    ELSEIF p_ciudad IN ('Medellín', 'Cali') THEN
        SET v_dias = 3;
    ELSEIF p_ciudad IN ('Barranquilla', 'Bucaramanga') THEN
        SET v_dias = 4;
    END IF;
    
    RETURN DATE(DATE_ADD(p_fecha_pedido, INTERVAL v_dias DAY));
END //

-- -----------------------------------------------------------------------------
-- 19. fn_ConvertirMoneda
-- Convierte un monto en moneda base a otra divisa usando una tasa de cambio.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ConvertirMoneda //
CREATE FUNCTION fn_ConvertirMoneda(p_monto DECIMAL(12,2), p_tasa_cambio DECIMAL(10,4))
RETURNS DECIMAL(12,2)
DETERMINISTIC
NO SQL
BEGIN
    IF p_monto <= 0 OR p_tasa_cambio <= 0 THEN
        RETURN 0.00;
    END IF;
    RETURN ROUND(p_monto * p_tasa_cambio, 2);
END //

-- -----------------------------------------------------------------------------
-- 20. fn_ValidarComplejidadContraseña
-- Valida que una clave tenga al menos 8 caracteres, una mayúscula y un número.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS `fn_ValidarComplejidadContraseña` //
CREATE FUNCTION `fn_ValidarComplejidadContraseña`(p_password VARCHAR(255))
RETURNS BOOLEAN
DETERMINISTIC
NO SQL
BEGIN
    IF CHAR_LENGTH(p_password) < 8 THEN
        RETURN FALSE;
    END IF;
    
    -- Valida que contenga al menos una mayúscula y al menos un dígito
    RETURN (p_password REGEXP '[A-Z]' AND p_password REGEXP '[0-9]');
END //

DELIMITER ;
