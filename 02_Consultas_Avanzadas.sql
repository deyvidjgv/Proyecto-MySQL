-- =============================================================================
-- PROYECTO: Base de Datos para un E-commerce
-- SCRIPT: 02_Consultas_Avanzadas.sql
-- DESCRIPCIÓN: 20 Consultas analíticas y de reportería de negocio avanzadas.
-- =============================================================================

USE ecommerce_db;

-- -----------------------------------------------------------------------------
-- 1. Top 10 Productos Más Vendidos
-- Ranking con los 10 productos que han generado más ingresos brutos.
-- -----------------------------------------------------------------------------
SELECT 
    p.id_producto,
    p.nombre AS producto,
    c.nombre AS categoria,
    SUM(dv.cantidad) AS total_unidades_vendidas,
    SUM(dv.subtotal) AS total_ingresos
FROM productos p
JOIN categorias c ON p.id_categoria = c.id_categoria
JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
GROUP BY p.id_producto, p.nombre, c.nombre
ORDER BY total_ingresos DESC
LIMIT 10;

-- -----------------------------------------------------------------------------
-- 2. Productos con Bajas Ventas
-- Identificar los productos en el 10% inferior de ventas para evaluar descontinuación.
-- -----------------------------------------------------------------------------
SELECT id_producto, producto, stock_actual, total_vendido, total_ingresos
FROM (
    SELECT 
        p.id_producto,
        p.nombre AS producto,
        p.stock AS stock_actual,
        COALESCE(SUM(dv.cantidad), 0) AS total_vendido,
        COALESCE(SUM(dv.subtotal), 0.00) AS total_ingresos,
        NTILE(10) OVER (ORDER BY COALESCE(SUM(dv.cantidad), 0) ASC) AS decil_ventas
    FROM productos p
    LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
    GROUP BY p.id_producto, p.nombre, p.stock
) sub
WHERE decil_ventas = 1
ORDER BY total_vendido ASC;

-- -----------------------------------------------------------------------------
-- 3. Clientes VIP
-- Listar los 5 clientes con el mayor valor de vida (LTV), basado en gasto histórico.
-- -----------------------------------------------------------------------------
SELECT 
    c.id_cliente,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    c.email,
    c.nivel_lealtad,
    COUNT(v.id_venta) AS total_compras,
    SUM(v.total) AS ltv_historico
FROM clientes c
JOIN ventas v ON c.id_cliente = v.id_cliente
WHERE v.estado != 'Cancelado'
GROUP BY c.id_cliente, c.nombre, c.apellido, c.email, c.nivel_lealtad
ORDER BY ltv_historico DESC
LIMIT 5;

-- -----------------------------------------------------------------------------
-- 4. Análisis de Ventas Mensuales
-- Ventas totales agrupadas por año y mes para identificar tendencias temporales.
-- -----------------------------------------------------------------------------
SELECT 
    YEAR(fecha_venta) AS anio,
    MONTH(fecha_venta) AS mes,
    DATE_FORMAT(fecha_venta, '%Y-%m') AS periodo,
    COUNT(id_venta) AS total_pedidos,
    SUM(total) AS total_ventas,
    ROUND(AVG(total), 2) AS ticket_promedio
FROM ventas
WHERE estado != 'Cancelado'
GROUP BY YEAR(fecha_venta), MONTH(fecha_venta), DATE_FORMAT(fecha_venta, '%Y-%m')
ORDER BY anio DESC, mes DESC;

-- -----------------------------------------------------------------------------
-- 5. Crecimiento de Clientes
-- Número de nuevos clientes registrados por trimestre.
-- -----------------------------------------------------------------------------
SELECT 
    YEAR(fecha_registro) AS anio,
    QUARTER(fecha_registro) AS trimestre,
    CONCAT(YEAR(fecha_registro), '-Q', QUARTER(fecha_registro)) AS periodo_trimestre,
    COUNT(id_cliente) AS nuevos_clientes
FROM clientes
GROUP BY YEAR(fecha_registro), QUARTER(fecha_registro)
ORDER BY anio, trimestre;

-- -----------------------------------------------------------------------------
-- 6. Tasa de Compra Repetida
-- Determinar el porcentaje de clientes que han realizado más de una compra.
-- -----------------------------------------------------------------------------
SELECT 
    COUNT(DISTINCT c.id_cliente) AS total_clientes_con_compras,
    COUNT(DISTINCT CASE WHEN pedidos.total_pedidos > 1 THEN c.id_cliente END) AS clientes_recurrentes,
    ROUND(
        (COUNT(DISTINCT CASE WHEN pedidos.total_pedidos > 1 THEN c.id_cliente END) * 100.0) / 
        COUNT(DISTINCT c.id_cliente), 
        2
    ) AS tasa_compra_repetida_porcentaje
FROM clientes c
JOIN (
    SELECT id_cliente, COUNT(id_venta) AS total_pedidos
    FROM ventas
    WHERE estado != 'Cancelado'
    GROUP BY id_cliente
) pedidos ON c.id_cliente = pedidos.id_cliente;

-- -----------------------------------------------------------------------------
-- 7. Productos Comprados Juntos Frecuentemente
-- Pares de productos adquiridos conjuntamente en la misma orden de compra.
-- -----------------------------------------------------------------------------
SELECT 
    p1.nombre AS producto_1,
    p2.nombre AS producto_2,
    COUNT(*) AS veces_comprados_juntos
FROM detalle_ventas dv1
JOIN detalle_ventas dv2 ON dv1.id_venta = dv2.id_venta AND dv1.id_producto < dv2.id_producto
JOIN productos p1 ON dv1.id_producto = p1.id_producto
JOIN productos p2 ON dv2.id_producto = p2.id_producto
GROUP BY p1.nombre, p2.nombre
ORDER BY veces_comprados_juntos DESC
LIMIT 10;

-- -----------------------------------------------------------------------------
-- 8. Rotación de Inventario
-- Tasa de rotación de stock por categoría de producto.
-- -----------------------------------------------------------------------------
-- NOTA: el stock y las unidades vendidas se agregan en subconsultas SEPARADAS.
-- Unir productos y detalle_ventas en un solo GROUP BY duplicaría cada fila de
-- producto una vez por línea de venta e inflaría SUM(p.stock) (fan-out del JOIN).
SELECT 
    c.id_categoria,
    c.nombre AS categoria,
    COALESCE(inv.stock_actual_total, 0) AS stock_actual_total,
    COALESCE(ven.unidades_vendidas, 0) AS unidades_vendidas,
    ROUND(
        COALESCE(ven.unidades_vendidas, 0) / NULLIF(inv.stock_actual_total, 0), 
        2
    ) AS indice_rotacion
FROM categorias c
LEFT JOIN (
    SELECT id_categoria, SUM(stock) AS stock_actual_total
    FROM productos
    GROUP BY id_categoria
) inv ON c.id_categoria = inv.id_categoria
LEFT JOIN (
    SELECT p.id_categoria, SUM(dv.cantidad) AS unidades_vendidas
    FROM detalle_ventas dv
    JOIN productos p ON dv.id_producto = p.id_producto
    GROUP BY p.id_categoria
) ven ON c.id_categoria = ven.id_categoria
ORDER BY indice_rotacion DESC;

-- -----------------------------------------------------------------------------
-- 9. Productos que Necesitan Reabastecimiento
-- Productos con stock actual estrictamente por debajo de su umbral mínimo.
-- -----------------------------------------------------------------------------
SELECT 
    p.id_producto,
    p.nombre AS producto,
    p.sku,
    c.nombre AS categoria,
    p.stock AS stock_actual,
    p.stock_minimo,
    (p.stock_minimo - p.stock) AS unidades_a_reordenar,
    pr.nombre AS proveedor,
    pr.email_contacto AS email_proveedor
FROM productos p
JOIN categorias c ON p.id_categoria = c.id_categoria
JOIN proveedores pr ON p.id_proveedor = pr.id_proveedor
WHERE p.stock < p.stock_minimo AND p.activo = TRUE
ORDER BY p.stock ASC;

-- -----------------------------------------------------------------------------
-- 10. Análisis de Carrito Abandonado (Simulado)
-- Clientes con carritos sin compra completada en las últimas horas.
-- -----------------------------------------------------------------------------
SELECT 
    ca.id_carrito,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    c.email,
    p.nombre AS producto,
    ca.cantidad,
    p.precio,
    ca.fecha_agregado,
    TIMESTAMPDIFF(HOUR, ca.fecha_agregado, NOW()) AS horas_transcurridas
FROM carritos_abandonados ca
JOIN clientes c ON ca.id_cliente = c.id_cliente
JOIN productos p ON ca.id_producto = p.id_producto
WHERE ca.abandonado = TRUE
  AND c.id_cliente NOT IN (
      SELECT DISTINCT v.id_cliente 
      FROM ventas v 
      WHERE v.fecha_venta >= ca.fecha_agregado
  );

-- -----------------------------------------------------------------------------
-- 11. Rendimiento de Proveedores
-- Clasificación de proveedores por volumen total y unidades comercializadas.
-- -----------------------------------------------------------------------------
SELECT 
    pr.id_proveedor,
    pr.nombre AS proveedor,
    COUNT(DISTINCT p.id_producto) AS articulos_suministrados,
    COALESCE(SUM(dv.cantidad), 0) AS unidades_vendidas,
    COALESCE(SUM(dv.subtotal), 0.00) AS volumen_ventas_total
FROM proveedores pr
JOIN productos p ON pr.id_proveedor = p.id_proveedor
LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
GROUP BY pr.id_proveedor, pr.nombre
ORDER BY volumen_ventas_total DESC;

-- -----------------------------------------------------------------------------
-- 12. Análisis Geográfico de Ventas
-- Agrupación de ventas por ciudad del cliente.
-- -----------------------------------------------------------------------------
SELECT 
    COALESCE(c.ciudad, 'No especificada') AS ciudad,
    COUNT(v.id_venta) AS total_pedidos,
    SUM(v.total) AS ventas_totales,
    ROUND(AVG(v.total), 2) AS ticket_promedio
FROM ventas v
JOIN clientes c ON v.id_cliente = c.id_cliente
WHERE v.estado != 'Cancelado'
GROUP BY c.ciudad
ORDER BY ventas_totales DESC;

-- -----------------------------------------------------------------------------
-- 13. Ventas por Hora del Día
-- Identificar horas pico de compra para optimización de marketing.
-- -----------------------------------------------------------------------------
SELECT 
    HOUR(fecha_venta) AS hora_del_dia,
    COUNT(id_venta) AS transacciones_realizadas,
    SUM(total) AS ingresos_totales,
    ROUND(AVG(total), 2) AS promedio_transaccion
FROM ventas
WHERE estado != 'Cancelado'
GROUP BY HOUR(fecha_venta)
ORDER BY hora_del_dia ASC;

-- -----------------------------------------------------------------------------
-- 14. Impacto de Promociones
-- Comparación de ventas de productos antes, durante y después de promoción.
-- -----------------------------------------------------------------------------
SELECT 
    p.nombre AS producto,
    'BLACKFRIDAY (2025-11-20 al 2025-11-30)' AS campaña,
    COALESCE(SUM(CASE WHEN v.fecha_venta < '2025-11-20' THEN dv.cantidad ELSE 0 END), 0) AS unidades_antes,
    COALESCE(SUM(CASE WHEN v.fecha_venta BETWEEN '2025-11-20' AND '2025-11-30' THEN dv.cantidad ELSE 0 END), 0) AS unidades_durante,
    COALESCE(SUM(CASE WHEN v.fecha_venta > '2025-11-30' THEN dv.cantidad ELSE 0 END), 0) AS unidades_despues
FROM productos p
JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
JOIN ventas v ON dv.id_venta = v.id_venta
WHERE p.id_producto IN (1, 2, 5, 14)
GROUP BY p.nombre;

-- -----------------------------------------------------------------------------
-- 15. Análisis de Cohort
-- Retención de clientes mes a mes desde su primera fecha de compra.
-- -----------------------------------------------------------------------------
WITH primer_compra AS (
    SELECT 
        id_cliente, 
        DATE_FORMAT(MIN(fecha_venta), '%Y-%m') AS cohorte
    FROM ventas
    WHERE estado != 'Cancelado'
    GROUP BY id_cliente
),
compras_cliente AS (
    SELECT 
        v.id_cliente,
        pc.cohorte,
        PERIOD_DIFF(
            EXTRACT(YEAR_MONTH FROM v.fecha_venta), 
            EXTRACT(YEAR_MONTH FROM STR_TO_DATE(CONCAT(pc.cohorte, '-01'), '%Y-%m-%d'))
        ) AS mes_diferencia
    FROM ventas v
    JOIN primer_compra pc ON v.id_cliente = pc.id_cliente
    WHERE v.estado != 'Cancelado'
)
SELECT 
    cohorte,
    COUNT(DISTINCT CASE WHEN mes_diferencia = 0 THEN id_cliente END) AS mes_0,
    COUNT(DISTINCT CASE WHEN mes_diferencia = 1 THEN id_cliente END) AS mes_1,
    COUNT(DISTINCT CASE WHEN mes_diferencia = 2 THEN id_cliente END) AS mes_2,
    COUNT(DISTINCT CASE WHEN mes_diferencia >= 3 THEN id_cliente END) AS mes_3_o_mas
FROM compras_cliente
GROUP BY cohorte
ORDER BY cohorte;

-- -----------------------------------------------------------------------------
-- 16. Margen de Beneficio por Producto
-- Cálculo de margen bruto unitario, porcentaje y utilidad total generada.
-- -----------------------------------------------------------------------------
SELECT 
    p.id_producto,
    p.nombre AS producto,
    p.precio AS precio_venta,
    p.costo AS costo_unitario,
    (p.precio - p.costo) AS margen_bruto_unitario,
    ROUND(((p.precio - p.costo) / p.precio) * 100, 2) AS margen_porcentaje,
    COALESCE(SUM(dv.cantidad), 0) AS unidades_vendidas,
    COALESCE(SUM(dv.cantidad * (p.precio - p.costo)), 0.00) AS utilidad_total_acumulada
FROM productos p
LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
GROUP BY p.id_producto, p.nombre, p.precio, p.costo
ORDER BY utilidad_total_acumulada DESC;

-- -----------------------------------------------------------------------------
-- 17. Tiempo Promedio Entre Compras
-- Promedio de días que tarda un cliente recurrente entre compras sucesivas.
-- -----------------------------------------------------------------------------
WITH compras_ordenadas AS (
    SELECT 
        id_cliente,
        fecha_venta,
        LAG(fecha_venta) OVER (PARTITION BY id_cliente ORDER BY fecha_venta) AS compra_anterior
    FROM ventas
    WHERE estado != 'Cancelado'
)
SELECT 
    c.id_cliente,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    COUNT(co.compra_anterior) AS intervalos_evaluados,
    ROUND(AVG(DATEDIFF(co.fecha_venta, co.compra_anterior)), 1) AS dias_promedio_entre_compras
FROM compras_ordenadas co
JOIN clientes c ON co.id_cliente = c.id_cliente
WHERE co.compra_anterior IS NOT NULL
GROUP BY c.id_cliente, c.nombre, c.apellido
ORDER BY dias_promedio_entre_compras ASC;

-- -----------------------------------------------------------------------------
-- 18. Productos Más Vistos vs. Comprados
-- Comparativa de vistas de producto contra compras efectivas y tasa de conversión.
-- -----------------------------------------------------------------------------
-- NOTA: visitas y compras son dos ramas de detalle independientes. Unirlas con
-- dos LEFT JOIN en el mismo GROUP BY genera producto cartesiano y multiplica las
-- unidades compradas por el número de visitas. Cada métrica se agrega por separado.
SELECT 
    p.id_producto,
    p.nombre AS producto,
    COALESCE(vis.total_visitas, 0) AS total_visitas,
    COALESCE(com.total_unidades_compradas, 0) AS total_unidades_compradas,
    ROUND(
        (COALESCE(com.total_unidades_compradas, 0) * 100.0) / NULLIF(vis.total_visitas, 0), 
        2
    ) AS tasa_conversion_porcentaje
FROM productos p
LEFT JOIN (
    SELECT id_producto, COUNT(*) AS total_visitas
    FROM visitas_productos
    GROUP BY id_producto
) vis ON p.id_producto = vis.id_producto
LEFT JOIN (
    SELECT id_producto, SUM(cantidad) AS total_unidades_compradas
    FROM detalle_ventas
    GROUP BY id_producto
) com ON p.id_producto = com.id_producto
ORDER BY total_visitas DESC, total_unidades_compradas DESC;

-- -----------------------------------------------------------------------------
-- 19. Segmentación de Clientes (RFM)
-- Clasificación basada en Recencia, Frecuencia y Valor Monetario.
-- -----------------------------------------------------------------------------
SELECT 
    c.id_cliente,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    DATEDIFF(CURDATE(), MAX(v.fecha_venta)) AS recencia_dias,
    COUNT(v.id_venta) AS frecuencia_pedidos,
    SUM(v.total) AS valor_monetario,
    CASE 
        WHEN DATEDIFF(CURDATE(), MAX(v.fecha_venta)) <= 45 AND COUNT(v.id_venta) >= 3 THEN 'VIP / Campeón'
        WHEN DATEDIFF(CURDATE(), MAX(v.fecha_venta)) <= 60 AND COUNT(v.id_venta) >= 2 THEN 'Cliente Fiel'
        WHEN DATEDIFF(CURDATE(), MAX(v.fecha_venta)) <= 60 THEN 'Cliente Reciente'
        WHEN DATEDIFF(CURDATE(), MAX(v.fecha_venta)) > 90 AND COUNT(v.id_venta) >= 2 THEN 'En Riesgo de Fuga'
        ELSE 'Inactivo / Ocasional'
    END AS segmento_rfm
FROM clientes c
JOIN ventas v ON c.id_cliente = v.id_cliente
WHERE v.estado != 'Cancelado'
GROUP BY c.id_cliente, c.nombre, c.apellido
ORDER BY valor_monetario DESC;

-- -----------------------------------------------------------------------------
-- 20. Predicción de Demanda Simple
-- Proyección estimada de demanda mensual para la categoría 'Electrónica'.
-- -----------------------------------------------------------------------------
SELECT 
    c.id_categoria,
    c.nombre AS categoria,
    ROUND(AVG(sub.ventas_mensuales), 2) AS promedio_mensual_historico,
    ROUND(AVG(sub.ventas_mensuales) * 1.08, 2) AS demanda_proyectada_proximo_mes
FROM categorias c
JOIN productos p ON c.id_categoria = p.id_categoria
JOIN (
    SELECT 
        dv.id_producto,
        YEAR(v.fecha_venta) AS anio,
        MONTH(v.fecha_venta) AS mes,
        SUM(dv.cantidad) AS ventas_mensuales
    FROM detalle_ventas dv
    JOIN ventas v ON dv.id_venta = v.id_venta
    WHERE v.estado != 'Cancelado'
    GROUP BY dv.id_producto, YEAR(v.fecha_venta), MONTH(v.fecha_venta)
) sub ON p.id_producto = sub.id_producto
WHERE c.id_categoria = 1
GROUP BY c.id_categoria, c.nombre;
