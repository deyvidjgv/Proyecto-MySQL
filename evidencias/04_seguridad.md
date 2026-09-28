# Evidencia de Ejecución: 04_Seguridad.sql

**Fecha de ejecución:** 2026-09-28  
**Base de Datos:** `ecommerce_db`  
**Estado:** 20 de 20 requerimientos de seguridad configurados y verificados.

---

## 1. Roles Creados y Asignación de Privilegios

| Rol | Privilegios Principales |
|---|---|
| `Administrador_Sistema` | `ALL PRIVILEGES` con `GRANT OPTION` sobre `ecommerce_db.*` |
| `Gerente_Marketing` | `SELECT` sobre `ventas`, `detalle_ventas`, `clientes` y `EXECUTE` |
| `Analista_Datos` | `SELECT` sobre tablas de negocio (restringido de tablas de auditoría/logs) |
| `Empleado_Inventario` | `SELECT` sobre `productos`, `UPDATE (stock)` (restringido de `precio`) |
| `Atencion_Cliente` | `SELECT` sobre `clientes`, `ventas` y vista protegida |
| `Auditor_Financiero` | `SELECT` sobre `ventas`, `detalle_ventas`, `productos`, `historial_pedidos_estado` |
| `Visitante` | `SELECT` sobre columnas públicas de `productos` |

---

## 2. Usuarios Creados y Roles Asignados

| Usuario | Host | Rol por Defecto | Política de Seguridad |
|---|---|---|---|
| `admin_user` | `localhost` | `Administrador_Sistema` | Expiración de contraseña cada 90 días |
| `marketing_user` | `localhost` | `Gerente_Marketing` | Expiración de contraseña cada 90 días |
| `inventory_user` | `localhost` | `Empleado_Inventario` | Expiración de contraseña cada 90 días |
| `support_user` | `localhost` | `Atencion_Cliente` | Expiración de contraseña cada 90 días |
| `analyst_user` | `localhost` | `Analista_Datos` | Límite de 500 consultas por hora (`MAX_QUERIES_PER_HOUR 500`) |

---

## 3. Vistas y Mecanismos de Seguridad Implementados
- **`v_info_clientes_basica`**: Vista que excluye datos confidenciales (contraseñas/hashes).
- **`v_ventas_sucursal_usuario`**: Seguridad a nivel de filas (RLS) para aislar ventas por sucursal de cada usuario.
- **Acceso Remoto de `root`**: Restringido exclusivamente a conexiones locales (`localhost` / `127.0.0.1`).
- **Tabla de Auditoría de Intentos Fallidos**: `auditoria_accesos_fallidos` configurada con variable de servidor `log_warnings = 2`.
