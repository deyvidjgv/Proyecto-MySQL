# Evidencia de Ejecución: 07_Procedimientos_Almacenados.sql

**Fecha de ejecución:** 2026-09-28  
**Base de Datos:** `ecommerce_db`  
**Estado:** 20 de 20 procedimientos almacenados transaccionales creados y probados con éxito.

---

## 1. Listado de los 20 Procedimientos Almacenados

| # | Procedimiento | Parámetros Clave | Tipo / Control Transaccional | Propósito de Negocio |
|---|---|---|---|---|
| 1 | `sp_RealizarNuevaVenta` | `id_cliente, id_sucursal, id_producto, cantidad, OUT id_venta` | Transaccional (`START TRANSACTION`, `COMMIT`, `ROLLBACK`) | Venta completa con bloqueo de stock y detalle |
| 2 | `sp_AgregarNuevoProducto` | Datos del producto, precios, stock, SKU | DDL / Inserción con validaciones | Alta de artículo en catálogo con verificación de precio |
| 3 | `sp_ActualizarDireccionCliente` | `id_cliente, nueva_direccion, ciudad` | DML Directo | Actualiza destino de despacho del cliente |
| 4 | `sp_ProcesarDevolucion` | `id_venta, id_producto, cantidad, motivo` | Transaccional | Registra devolución, repone stock y genera crédito |
| 5 | `sp_ObtenerHistorialComprasCliente` | `id_cliente` | Consulta estructurada | Historial cronológico con desglose de productos |
| 6 | `sp_AjustarNivelStock` | `id_producto, nuevo_stock, motivo` | Transaccional con Auditoría | Ajuste físico con registro en `ajustes_inventario` |
| 7 | `sp_EliminarClienteDeFormaSegura` | `id_cliente` | Anonimización GDPR | Elimina datos sensibles sin romper integridad referencial |
| 8 | `sp_AplicarDescuentoPorCategoria` | `id_categoria, porcentaje` | DML Masivo | Actualiza precios de toda una categoría |
| 9 | `sp_GenerarReporteMensualVentas` | `mes, anio` | Reporte Analítico | Desglose diario de facturación, pedidos y ticket |
| 10 | `sp_CambiarEstadoPedido` | `id_venta, nuevo_estado` | Validación de estados | Transición de estado (`Procesando`, `Enviado`, etc.) |
| 11 | `sp_RegistrarNuevoCliente` | Datos de cliente y contraseña | Validación previa | Alta de cliente con verificación de email duplicado |
| 12 | `sp_ObtenerDetallesProductoCompleto` | `id_producto` | JOIN Multitabla | Ficha técnica con proveedor, categoría y márgenes |
| 13 | `sp_FusionarCuentasCliente` | `id_cliente_origen, id_cliente_destino` | Transaccional atómico | Reasigna compras y reseñas a una cuenta principal |
| 14 | `sp_AsignarProductoAProveedor` | `id_producto, id_proveedor` | DML Directo | Cambia el proveedor asignado al producto |
| 15 | `sp_BuscarProductos` | `termino, id_categoria, precio_min, precio_max` | Búsqueda multicriterio | Filtro dinámico por catálogo, descripción y precios |
| 16 | `sp_ObtenerDashboardAdmin` | Ninguno | Agregaciones simultáneas | Métricas ejecutivas en tiempo real |
| 17 | `sp_ProcesarPago` | `id_venta, monto_pagado` | Transaccional | Valida pago y avanza orden a 'Procesando' |
| 18 | `sp_AñadirReseñaProducto` | `id_cliente, id_producto, calificacion, comentario` | Verificación de compra | Valida compra previa antes de admitir reseña |
| 19 | `sp_ObtenerProductosRelacionados` | `id_producto` | Market Basket Analysis | Artículos comúnmente adquiridos en conjunto |
| 20 | `sp_MoverProductosEntreCategorias` | `id_categoria_origen, id_categoria_destino` | Transaccional | Traslado masivo y actualización de contadores |

---

## 2. Prueba de Ejecución de Muestra

### Ejecución de `sp_ObtenerDashboardAdmin()`:
```text
ventas_hoy: 0
ingresos_hoy: $0.00
clientes_activos: 20
productos_alerta_stock: 4
ordenes_pendientes: 1
```

### Ejecución de `sp_BuscarProductos('Laptop', NULL, NULL, NULL)`:
```text
id_producto: 1
nombre: Laptop UltraPro 15"
precio: $1,200.00
stock: 25
sku: ELEC-LAP-001
categoria: Electrónica
```
