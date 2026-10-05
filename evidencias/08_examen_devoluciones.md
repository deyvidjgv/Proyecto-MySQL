# Evidencia de Ejecución: 08_Examen_sp_ProcesarDevolucion.sql

**Fecha de ejecución:** 2026-10-05  
**Servidor:** MySQL 8.0.46 (Ubuntu)  
**Base de Datos:** `ecommerce_db`, creada desde cero con los scripts 01 al 07  
**Estado:** el script se ejecuta sin errores y los 14 casos de prueba dan el resultado esperado.

---

## 1. Objetos creados

| Objeto | Detalle |
|---|---|
| `ventas.estado` | `ENUM` ampliado con `'Devolución Parcial'` y `'Devuelto Totalmente'` |
| Tabla `devoluciones` | `id_devolucion, id_venta, id_producto, cantidad_devuelta, precio_unitario, monto_reembolso, estado_venta_resultante, usuario, fecha_devolucion` |
| Procedimiento `sp_ProcesarDevolucion` | Parámetros `p_id_venta, p_id_producto, p_cantidad_devuelta` |

---

## 2. Casos de prueba

Datos de partida: la venta 5 tiene 2 laptops (producto 1); la venta 1 tiene 1 laptop (producto 1) y 1 par de audífonos (producto 3). Stock inicial: laptop 25, audífonos 60.

| # | Llamada | Resultado obtenido |
|---|---|---|
| 1 | `CALL sp_ProcesarDevolucion(5, 1, 1);` | OK: venta 5 → `Devolución Parcial`, reembolso 1200.00 |
| 2 | `CALL sp_ProcesarDevolucion(5, 1, 1);` | OK: venta 5 → `Devuelto Totalmente`, reembolso 1200.00 |
| 3 | `CALL sp_ProcesarDevolucion(5, 1, 1);` | ERROR: Solo se aceptan devoluciones de ventas Entregadas o con Devolución Parcial. |
| 4 | `CALL sp_ProcesarDevolucion(1, 1, 5);` | ERROR: La cantidad a devolver supera lo comprado en esta venta (descontando devoluciones previas). |
| 5 | `CALL sp_ProcesarDevolucion(1, 20, 1);` | ERROR: El producto indicado no forma parte de esta venta. |
| 6 | `CALL sp_ProcesarDevolucion(1, 3, 0);` | ERROR: La cantidad a devolver debe ser mayor que cero. |
| 7 | `CALL sp_ProcesarDevolucion(1, 3, NULL);` | ERROR: La cantidad a devolver debe ser mayor que cero. |
| 8 | `CALL sp_ProcesarDevolucion(999, 1, 1);` | ERROR: La venta indicada no existe. |
| 9 | `CALL sp_ProcesarDevolucion(30, 5, 1);` (Cancelada) | ERROR: Solo se aceptan devoluciones de ventas Entregadas o con Devolución Parcial. |
| 10 | `CALL sp_ProcesarDevolucion(24, 1, 1);` (Enviada) | ERROR: Solo se aceptan devoluciones de ventas Entregadas o con Devolución Parcial. |
| 11 | `CALL sp_ProcesarDevolucion(1, 3, 1);` | OK: venta 1 → `Devolución Parcial` (aún falta la laptop), reembolso 150.00 |
| 12 | Fallo simulado en el `INSERT` (ver sección 4) | ERROR y **nada modificado** |
| 13 | `CALL sp_ProcesarDevolucion(1, 3, 1);` (de nuevo) | ERROR: La cantidad a devolver supera lo comprado en esta venta (descontando devoluciones previas). |
| 14 | `CALL sp_ProcesarDevolucion(1, 1, 1);` | OK: venta 1 → `Devuelto Totalmente` |

---

## 3. Estado de las tablas tras los casos 1 a 11

```text
devoluciones
+---------------+----------+-------------+-------------------+-----------------+-----------------+-------------------------+----------------+
| id_devolucion | id_venta | id_producto | cantidad_devuelta | precio_unitario | monto_reembolso | estado_venta_resultante | usuario        |
+---------------+----------+-------------+-------------------+-----------------+-----------------+-------------------------+----------------+
|             1 |        5 |           1 |                 1 |         1200.00 |         1200.00 | Devolución Parcial      | root@localhost |
|             2 |        5 |           1 |                 1 |         1200.00 |         1200.00 | Devuelto Totalmente     | root@localhost |
|             3 |        1 |           3 |                 1 |          150.00 |          150.00 | Devolución Parcial      | root@localhost |
+---------------+----------+-------------+-------------------+-----------------+-----------------+-------------------------+----------------+

ventas                               productos (stock)
+----------+---------------------+    +-------------+-------+
| id_venta | estado              |    | id_producto | stock |
+----------+---------------------+    +-------------+-------+
|        1 | Devolución Parcial  |    |           1 |    27 |   (25 + 2)
|        5 | Devuelto Totalmente |    |           3 |    61 |   (60 + 1)
|       24 | Enviado             |    +-------------+-------+
|       30 | Cancelado           |
+----------+---------------------+

historial_pedidos_estado (registrado automáticamente por trg_log_order_status_change)
+----------+---------------------+---------------------+
| id_venta | estado_anterior     | estado_nuevo        |
+----------+---------------------+---------------------+
|        1 | Entregado           | Devolución Parcial  |
|        5 | Entregado           | Devolución Parcial  |
|        5 | Devolución Parcial  | Devuelto Totalmente |
+----------+---------------------+---------------------+
```

Los casos con error (3 a 10) no modificaron ninguna tabla.

---

## 4. Prueba de atomicidad (requisito 5)

Para comprobar que un fallo **a mitad del proceso** deshace también los pasos ya ejecutados, se creó un trigger temporal que hace fallar el `INSERT` en `devoluciones`. Ese `INSERT` es el último paso, cuando el stock y el estado de la venta ya se habían modificado. El trigger se eliminó al terminar la prueba.

```text
ANTES:   stock_laptop = 27 | estado_venta1 = Devolución Parcial | filas_devoluciones = 3
CALL sp_ProcesarDevolucion(1, 1, 1);
ERROR 1644 (45000): Fallo simulado al guardar la devolucion
DESPUÉS: stock_laptop = 27 | estado_venta1 = Devolución Parcial | filas_devoluciones = 3
```

El stock no quedó en 28 y el estado no cambió: el `ROLLBACK` deshizo los dos `UPDATE` anteriores.

---

## 5. Compatibilidad con el resto del proyecto

- El script se puede re-ejecutar sin errores (vacía la tabla `devoluciones`).
- Tras ejecutarlo, las 20 consultas de `02_Consultas_Avanzadas.sql` siguen devolviendo resultados.
