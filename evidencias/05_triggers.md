# Evidencia de Ejecución: 05_Triggers.sql

**Fecha de ejecución:** 2026-09-28  
**Base de Datos:** `ecommerce_db`  
**Estado:** Tabla `log_cambios_precio` y 20 disparadores (triggers) creados y probados satisfactoriamente.

---

## 1. Listado de Triggers Implementados

| # | Nombre del Disparador | Evento / Timing | Tabla Objetivo | Propósito de Negocio |
|---|---|---|---|---|
| 1 | `trg_audit_precio_producto_after_update` | AFTER UPDATE | `productos` | Registra auditoría de cambios de precios |
| 2 | `trg_check_stock_before_insert_venta` | BEFORE INSERT | `detalle_ventas` | Bloquea la inserción si el stock es insuficiente |
| 3 | `trg_update_stock_after_insert_venta` | AFTER INSERT | `detalle_ventas` | Reduce automáticamente el stock tras vender |
| 4 | `trg_prevent_delete_categoria_with_products` | BEFORE DELETE | `categorias` | Impide borrar categorías con productos |
| 5 | `trg_log_new_customer_after_insert` | AFTER INSERT | `clientes` | Registra creación de nuevos clientes en log |
| 6 | `trg_update_total_gastado_cliente` | AFTER UPDATE | `ventas` | Acumula gasto total al entregar la orden |
| 7 | `trg_set_fecha_modificacion_producto` | BEFORE UPDATE | `productos` | Actualiza timestamp de última modificación |
| 8 | `trg_prevent_negative_stock` | BEFORE UPDATE | `productos` | Rechaza valores negativos en existencias |
| 9 | `trg_capitalize_nombre_cliente` | BEFORE INSERT | `clientes` | Formatea nombre y apellido con inicial mayúscula |
| 10 | `trg_recalculate_total_venta_on_detalle_change` | AFTER UPDATE | `detalle_ventas` | Recalcula total de venta si cambia un ítem |
| 11 | `trg_log_order_status_change` | AFTER UPDATE | `ventas` | Registra historial de cambios de estado |
| 12 | `trg_prevent_price_zero_or_less` | BEFORE INSERT | `productos` | Valida que el precio sea mayor que cero |
| 13 | `trg_send_stock_alert_on_low_stock` | AFTER UPDATE | `productos` | Genera alerta cuando cae bajo el stock mínimo |
| 14 | `trg_archive_deleted_venta` | BEFORE DELETE | `ventas` | Archiva ventas eliminadas antes de su borrado |
| 15 | `trg_validate_email_format_on_customer` | BEFORE UPDATE | `clientes` | Valida expresión regular de email en clientes |
| 16 | `trg_update_last_order_date_customer` | AFTER INSERT | `ventas` | Actualiza fecha de última compra en cliente |
| 17 | `trg_prevent_self_referral` | BEFORE UPDATE | `clientes` | Impide autoreferencia en programa de referidos |
| 18 | `trg_log_permission_changes` | AFTER INSERT | `asignacion_usuario_sucursal` | Audita cambios en permisos y sucursales |
| 19 | `trg_assign_default_category_on_null` | BEFORE INSERT | `productos` | Asigna categoría por defecto si llega nula |
| 20 | `trg_update_producto_count_in_categoria` | AFTER INSERT | `productos` | Mantiene contador `total_productos` en categoría |

---

## 2. Prueba de Disparo en Vivo (Evidencia de Auditoría)

Al actualizar el precio del producto 3 de `$150.00` a `$165.00`, el disparador `trg_audit_precio_producto_after_update` generó de forma automática el siguiente registro en `log_cambios_precio`:

```text
id_log: 1
id_producto: 3
precio_anterior: 150.00
precio_nuevo: 165.00
usuario: root@localhost
fecha_cambio: 2026-09-28 01:09:21
```
