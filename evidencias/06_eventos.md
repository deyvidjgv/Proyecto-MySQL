# Evidencia de Ejecución: 06_Eventos.sql

**Fecha de ejecución:** 2026-09-28  
**Base de Datos:** `ecommerce_db`  
**Estado:** `event_scheduler` activo, tabla `reporte_ventas_semanales` creada y 20 de 20 eventos programados registrados.

---

## 1. Planificador de Eventos (Event Scheduler)

- **Parámetro Global:** `SET GLOBAL event_scheduler = ON;`
- **Estado en Servidor:** `ENABLED / RUNNING`

---

## 2. Listado de los 20 Eventos Programados

| # | Nombre del Evento | Frecuencia | Estado | Propósito Automatizado |
|---|---|---|---|---|
| 1 | `evt_generate_weekly_sales_report` | Cada 1 Semana | ENABLED | Consolida ventas en `reporte_ventas_semanales` |
| 2 | `evt_cleanup_temp_tables_daily` | Cada 1 Día | ENABLED | Purga visitas y datos temporales de más de 60 días |
| 3 | `evt_archive_old_logs_monthly` | Cada 1 Mes | ENABLED | Depura logs de auditoría antiguos |
| 4 | `evt_deactivate_expired_promotions_hourly` | Cada 1 Hora | ENABLED | Desactiva códigos de descuento vencidos |
| 5 | `evt_recalculate_customer_loyalty_tiers_nightly` | Cada 1 Día | ENABLED | Recalcula nivel de lealtad (Bronce, Plata, Oro) |
| 6 | `evt_generate_reorder_list_daily` | Cada 1 Día | ENABLED | Genera alertas para artículos bajo stock mínimo |
| 7 | `evt_rebuild_indexes_weekly` | Cada 1 Semana | ENABLED | Optimiza y desfragmenta tablas críticas |
| 8 | `evt_suspend_inactive_accounts_quarterly` | Cada 3 Meses | ENABLED | Desactiva cuentas sin pedidos en más de un año |
| 9 | `evt_aggregate_daily_sales_data` | Cada 1 Día | ENABLED | Agrega ventas diarias en `resumen_ventas_diarias` |
| 10 | `evt_check_data_consistency_nightly` | Cada 1 Día | ENABLED | Audita inconsistencias referenciales |
| 11 | `evt_send_birthday_greetings_daily` | Cada 1 Día | ENABLED | Genera cupones para cumpleañeros del día |
| 12 | `evt_update_product_rankings_hourly` | Cada 1 Hora | ENABLED | Actualiza ranking de productos más vendidos |
| 13 | `evt_backup_critical_tables_daily` | Cada 1 Día | ENABLED | Registra confirmación de ciclo de respaldo lógico |
| 14 | `evt_clear_abandoned_carts_daily` | Cada 1 Día | ENABLED | Vacía carritos abandonados hace más de 72 horas |
| 15 | `evt_calculate_monthly_kpis` | Cada 1 Mes | ENABLED | Calcula métricas clave (ingresos, pedidos, ticket) |
| 16 | `evt_refresh_materialized_views_nightly` | Cada 1 Día | ENABLED | Actualiza tabla de vista materializada |
| 17 | `evt_log_database_size_weekly` | Cada 1 Semana | ENABLED | Monitorea el tamaño y crecimiento de la BD |
| 18 | `evt_detect_fraudulent_activity_hourly` | Cada 1 Hora | ENABLED | Detecta pedidos repetitivos o sospechosos |
| 19 | `evt_generate_supplier_performance_report_monthly` | Cada 1 Mes | ENABLED | Consolida desempeño mensual de proveedores |
| 20 | `evt_purge_soft_deleted_records_weekly` | Cada 1 Semana | ENABLED | Limpia clientes inactivos sin historial |
