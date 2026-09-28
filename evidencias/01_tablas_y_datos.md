# Evidencia de Ejecución: 01_Esquema_y_Datos.sql

**Fecha de ejecución:** 2026-09-28  
**Base de Datos:** `ecommerce_db`  
**Estado:** Ejecución exitosa (Código de salida: 0, 0 advertencias)

---

## 1. Tablas Creadas en `ecommerce_db`

| # | Nombre de la Tabla | Propósito Principal |
|---|--------------------|---------------------|
| 1 | `categorias` | Clasificación jerárquica de productos del catálogo |
| 2 | `proveedores` | Contacto de proveedores de inventario |
| 3 | `sucursales` | Sucursales físicas / centros de distribución |
| 4 | `clientes` | Información de usuarios, cuentas y niveles de lealtad |
| 5 | `productos` | Catálogo de artículos, precios, costos, stock y SKU |
| 6 | `ventas` | Encabezado de órdenes de compra y estados |
| 7 | `detalle_ventas` | Líneas de pedido con precio histórico congelado |
| 8 | `alertas_stock` | Soporte para triggers de alerta de stock mínimo |
| 9 | `historial_pedidos_estado` | Auditoría de transiciones de estados de venta |
| 10 | `ventas_archivadas` | Almacenamiento histórico de ventas eliminadas |
| 11 | `log_auditoria_clientes` | Auditoría al crear nuevos clientes |
| 12 | `log_permisos_usuarios` | Auditoría de modificaciones de permisos |
| 13 | `carritos_abandonados` | Registro de intención de compra no concretada |
| 14 | `promociones` | Cupones, descuentos activos y campañas |
| 15 | `reseñas_productos` | Calificaciones (1 a 5) y opiniones de compradores |
| 16 | `devoluciones` | Gestión de devoluciones y generación de créditos |
| 17 | `resumen_ventas_diarias` | Tabla de agregación periódica por eventos |
| 18 | `kpis_mensuales` | Resumen mensual de ingresos y métricas clave |
| 19 | `ranking_productos` | Tabla de clasificación horaria de productos |
| 20 | `monitoreo_bd` | Registro de tamaño y crecimiento de la base de datos |
| 21 | `reporte_proveedores` | Reportes de volumen y rendimiento por proveedor |
| 22 | `visitas_productos` | Métricas de navegación para análisis de conversión |

---

## 2. Resumen de Registros Poblados

| Tabla | Total Registros |
|---|---|
| `categorias` | 5 |
| `proveedores` | 5 |
| `sucursales` | 5 |
| `clientes` | 20 |
| `productos` | 20 |
| `ventas` | 30 |
| `detalle_ventas` | 60 |
| `carritos_abandonados` | 5 |
| `promociones` | 4 |
| `reseñas_productos` | 5 |
| `visitas_productos` | 24 |

---

## 3. Verificación de Integridad Referencial
- Claves primarias y foráneas (`FOREIGN KEY`) verificadas sin inconsistencias.
- Restricciones `CHECK` activas para precios (`> 0`), costos (`>= 0`), stock (`>= 0`) y calificaciones (`1 a 5`).
