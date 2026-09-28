# Evidencia de Ejecución: 03_Funciones.sql

**Fecha de ejecución:** 2026-09-28  
**Base de Datos:** `ecommerce_db`  
**Estado:** 20 de 20 funciones UDF creadas exitosamente en el catálogo de MySQL.

---

## 1. Listado de Funciones Registradas

| # | Nombre de la Función | Tipo | Propósito |
|---|---|---|---|
| 1 | `fn_CalcularTotalVenta` | READS SQL DATA | Suma subtotales de una venta específica |
| 2 | `fn_VerificarDisponibilidadStock` | READS SQL DATA | Valida existencias frente a cantidad requerida |
| 3 | `fn_ObtenerPrecioProducto` | READS SQL DATA | Consulta el precio de lista de un producto |
| 4 | `fn_CalcularEdadCliente` | READS SQL DATA | Calcula la edad a partir de la fecha de nacimiento |
| 5 | `fn_FormatearNombreCompleto` | DETERMINISTIC | Formato estándar 'Apellido, Nombre' |
| 6 | `fn_EsClienteNuevo` | READS SQL DATA | Valida si su primera orden fue en últimos 30 días |
| 7 | `fn_CalcularCostoEnvio` | READS SQL DATA | Costo con base en peso volumétrico ($5 + $2.50/kg) |
| 8 | `fn_AplicarDescuento` | DETERMINISTIC | Aplica un porcentaje de descuento a un monto |
| 9 | `fn_ObtenerUltimaFechaCompra` | READS SQL DATA | Retorna la fecha del último pedido del cliente |
| 10 | `fn_ValidarFormatoEmail` | DETERMINISTIC | Comprueba sintaxis RFC de correo con regex |
| 11 | `fn_ObtenerNombreCategoria` | READS SQL DATA | Obtiene la categoría a partir del ID de producto |
| 12 | `fn_ContarVentasCliente` | READS SQL DATA | Cuenta órdenes válidas de un cliente |
| 13 | `fn_CalcularDiasDesdeUltimaCompra`| READS SQL DATA | Días transcurridos desde última compra |
| 14 | `fn_DeterminarEstadoLealtad` | DETERMINISTIC | Asigna nivel Bronce, Plata u Oro por gasto |
| 15 | `fn_GenerarSKU` | DETERMINISTIC | Genera código estructurado CAT-PROD-ID |
| 16 | `fn_CalcularIVA` | DETERMINISTIC | Calcula el impuesto IVA sobre un valor base |
| 17 | `fn_ObtenerStockTotalPorCategoria`| READS SQL DATA | Suma el stock de toda una categoría |
| 18 | `fn_EstimarFechaEntrega` | DETERMINISTIC | Estima fecha de llegada según ciudad destino |
| 19 | `fn_ConvertirMoneda` | DETERMINISTIC | Conversión a divisa extranjera con tasa de cambio |
| 20 | `fn_ValidarComplejidadContraseña` | DETERMINISTIC | Verifica seguridad (longitud >= 8, mayúscula, dígito) |

---

## 2. Prueba de Ejecución de Muestra

| Prueba | Entrada | Resultado Obtenido |
|---|---|---|
| `fn_CalcularTotalVenta(1)` | Venta ID 1 | `$1,350.00` |
| `fn_VerificarDisponibilidadStock(1, 10)` | Producto 1, Cantidad 10 | `1 (Disponible)` |
| `fn_ObtenerPrecioProducto(1)` | Producto 1 | `$1,200.00` |
| `fn_CalcularEdadCliente(1)` | Cliente 1 (Nacimiento 1985-04-12) | `41 años` |
| `fn_FormatearNombreCompleto('Carlos', 'Gómez')` | 'Carlos', 'Gómez' | `'Gómez, Carlos'` |
| `fn_AplicarDescuento(1000, 15)` | $1,000 al 15% | `$850.00` |
| `fn_DeterminarEstadoLealtad(3500)` | $3,500 gastados | `'Oro'` |
| `fn_GenerarSKU('Teclado', 'Accesorios', 45)` | Categoría, Producto, ID | `'ACC-TEC-045'` |
| `fn_CalcularIVA(1000, 19)` | $1,000 con 19% IVA | `$190.00` |
| `fn_ValidarFormatoEmail('test@dominio.com')` | Correo de prueba | `1 (Válido)` |
