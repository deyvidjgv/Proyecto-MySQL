# Evidencia de Ejecución: 02_Consultas_Avanzadas.sql

**Fecha de ejecución:** 2026-09-28  
**Base de Datos:** `ecommerce_db`  
**Estado:** 20 de 20 consultas ejecutadas exitosamente (Código de salida: 0).

---

## 1. Top 5 Productos Más Vendidos por Ingresos (Consulta #1)

| ID | Producto | Categoría | Unidades Vendidas | Ingresos Totales |
|---|---|---|---|---|
| 1 | Laptop UltraPro 15" | Electrónica | 12 | $14,400.00 |
| 2 | Smartphone Galaxy X | Electrónica | 12 | $9,600.00 |
| 5 | Monitor Gamer 27" 144Hz | Electrónica | 7 | $2,100.00 |
| 14 | Bicicleta Estática Magnética | Deportes y Fitness | 4 | $1,400.00 |
| 3 | Auriculares NoiseCancel Pro | Electrónica | 5 | $650.00 |

---

## 2. Clientes VIP por Valor Histórico (LTV) (Consulta #3)

| ID | Cliente | Correo Electrónico | Nivel | Total Compras | LTV Histórico |
|---|---|---|---|---|---|
| 7 | Javier Ramírez | `javier.ramirez@email.com` | Oro | 3 | $5,100.00 |
| 4 | Laura Martínez | `laura.martinez@email.com` | Oro | 2 | $4,200.00 |
| 1 | Carlos Gómez | `carlos.gomez@email.com` | Oro | 3 | $3,450.00 |
| 13 | Alejandro Paredes | `alejandro.paredes@email.com` | Oro | 2 | $3,100.00 |
| 6 | Diana Torres | `diana.torres@email.com` | Plata | 2 | $2,150.00 |

---

## 3. Tasa de Compra Repetida (Consulta #6)

| Clientes Totales con Compras | Clientes Recurrentes (2+ compras) | Tasa de Compra Repetida |
|---|---|---|
| 18 | 9 | **50.00%** |

---

## 4. Productos que Requieren Reabastecimiento (Consulta #9)

| ID | Producto | SKU | Stock Actual | Stock Mínimo | Unidades a Reordenar | Proveedor |
|---|---|---|---|---|---|---|
| 20 | Set Cuadernos Profesionales | LIB-CUA-020 | 1 | 10 | 9 | Editorial Mundo Letras |
| 9 | Chaqueta Impermeable | ROPA-CHA-009 | 2 | 8 | 6 | ModaTextil Corp |
| 4 | Smartwatch Fit Pulse | ELEC-WAT-004 | 3 | 10 | 7 | TechGlobal S.A. |
| 13 | Juego Sartenes Cerámica | HOG-SAR-013 | 4 | 6 | 2 | HomeStyle Ltda |

---

## 5. Análisis Geográfico de Ventas (Consulta #12)

| Ciudad | Total Pedidos | Ventas Totales | Ticket Promedio |
|---|---|---|---|
| Medellín | 8 | $10,800.00 | $1,350.00 |
| Bogotá | 7 | $6,670.00 | $952.86 |
| Barranquilla | 5 | $6,100.00 | $1,220.00 |
| Cali | 5 | $4,460.00 | $892.00 |
| Bucaramanga | 4 | $2,880.00 | $720.00 |
