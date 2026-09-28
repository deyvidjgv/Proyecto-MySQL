Base de Datos de un E-commerce

Base de Datos de un E-commerce


Introducción al Sistema
El objetivo es diseñar el núcleo de una base de datos para una tienda en línea. Este sistema debe gestionar de manera eficiente y segura toda la información relacionada con los productos, el inventario, los clientes y el ciclo de vida de las ventas. La estructura debe ser robusta, escalable y garantizar la integridad de los datos en todo momento.



1. Entidades Principales y su Propósito
La base de datos se centrará en las siguientes entidades clave:

Productos: El catálogo de artículos disponibles para la venta.
Categorías: El sistema de clasificación para organizar los productos.
Proveedores: Las entidades que suministran los productos.
Clientes: Los usuarios registrados que realizan compras.
Ventas: Las transacciones comerciales que registran las compras de los clientes.
Detalle de Ventas: El desglose de los productos específicos incluidos en cada transacción.


2. Requisitos Detallados por Entidad (Atributos y Restricciones)
A continuación, se detalla la información específica que cada entidad debe almacenar.



Entidad: Productos
Debe contener toda la información descriptiva y de inventario de cada artículo.



id_producto: Identificador numérico único y autoincremental para cada producto. (Clave Primaria)
nombre: Nombre comercial del producto. Es un texto obligatorio y no puede repetirse. (Requerido, Único)
descripcion: Texto largo y opcional con detalles extensos sobre el producto.
precio: Valor monetario de venta al público. Debe ser un número decimal y siempre mayor que cero. (Requerido, > 0)
costo: Valor monetario de compra al proveedor. Es crucial para calcular márgenes de beneficio. Debe ser un número decimal y positivo. (Requerido, >= 0)
stock: Cantidad de unidades disponibles en el inventario. Debe ser un número entero y nunca negativo. Su valor por defecto al crear un producto será cero. (Requerido, >= 0)
sku: Código de Almacén (Stock Keeping Unit). Texto único que identifica el producto de forma interna. (Requerido, Único)
fecha_creacion: Registro automático de la fecha y hora en que se añade un producto al sistema.
activo: Un campo booleano (VERDADERO/FALSO) para indicar si el producto está visible en la tienda o ha sido descontinuado.


Entidad: Categorías
Debe permitir una clasificación jerárquica y organizada de los productos.



id_categoria: Identificador numérico único y autoincremental. (Clave Primaria)
nombre: Nombre de la categoría (ej. "Electrónica", "Ropa"). Es un texto obligatorio y debe ser único. (Requerido, Único)
descripcion: Texto opcional que explica qué productos contiene la categoría.


Entidad: Proveedores
Debe almacenar la información de contacto de quienes suministran los productos.



id_proveedor: Identificador numérico único y autoincremental. (Clave Primaria)
nombre: Razón social o nombre del proveedor. Es un texto obligatorio. (Requerido)
email_contacto: Correo electrónico principal del proveedor. Debe ser único. (Único)
telefono_contacto: Número de teléfono del proveedor.


Entidad: Clientes
Debe contener la información necesaria para gestionar usuarios y envíos.



id_cliente: Identificador numérico único y autoincremental. (Clave Primaria)
nombre: Nombre de pila del cliente. (Requerido)
apellido: Apellido del cliente. (Requerido)
email: Correo electrónico del cliente, que servirá como su nombre de usuario. No puede repetirse en todo el sistema. (Requerido, Único)
contraseña: Almacenamiento seguro (hash) de la contraseña del cliente. (Requerido)
direccion_envio: Texto con la dirección principal para los envíos.
fecha_registro: Registro automático de la fecha y hora de creación de la cuenta.


Entidad: Ventas (Encabezado de la Orden)
Representa la transacción global realizada por un cliente en un momento dado.



id_venta: Identificador numérico único y autoincremental. (Clave Primaria)
fecha_venta: Registro automático de la fecha y hora en que se confirma la venta.
estado: El estado actual del pedido. Debe ser un valor de una lista predefinida (ej. 'Pendiente de Pago', 'Procesando', 'Enviado', 'Entregado', 'Cancelado'). (Requerido)
total: El monto total de la venta. Este valor se calculará sumando los subtotales de todos los productos incluidos.


Entidad: Detalle de Ventas (Líneas de la Orden)
Es la tabla de unión que conecta las ventas con los productos. Sin esta entidad, no podríamos saber qué productos se incluyeron en cada venta.



id_detalle: Identificador numérico único y autoincremental. (Clave Primaria)
cantidad: El número de unidades de un producto específico que se compraron en esta transacción. Debe ser un entero mayor que cero. (Requerido, > 0)
precio_unitario_congelado: El precio del producto en el momento exacto de la compra. Este es un requisito CRÍTICO. No se puede hacer referencia directa al precio en la tabla productos, ya que ese puede cambiar en el futuro, pero el registro de la venta debe mantener el precio histórico. (Requerido)


3. Requisitos de Relaciones entre Entidades
Las entidades se conectan entre sí siguiendo estas reglas de negocio:



Categorías y Productos: Una categoría puede tener muchos productos, pero un producto pertenece a una sola categoría. (Relación de uno a muchos).
Proveedores y Productos: Un proveedor puede suministrar muchos productos, pero un producto es suministrado por un solo proveedor. (Relación de uno a muchos).
Clientes y Ventas: Un cliente puede realizar muchas ventas, pero cada venta pertenece a un único cliente. (Relación de uno a muchos).
Ventas y Productos (La relación clave): Una venta puede incluir muchos productos diferentes, y un mismo producto puede estar en muchas ventas diferentes. Esta es una relación de muchos a muchos, y se resuelve a través de la tabla Detalle de Ventas. Esta tabla actúa como un puente, conectando una id_venta con una id_producto y almacenando los datos únicos de esa interacción (cantidad y precio_unitario_congelado).


4. Consultas Avanzadas (Análisis y Reporteo)
Se deben crear consultas SQL para responder a las siguientes 20 preguntas de negocio, demostrando capacidad analítica sobre los datos.



Top 10 Productos Más Vendidos: Generar un ranking con los 10 productos que han generado más ingresos.
Productos con Bajas Ventas: Identificar los productos en el 10% inferior de ventas para considerar su descontinuación.
Clientes VIP: Listar los 5 clientes con el mayor valor de vida (LTV), basado en su gasto total histórico.
Análisis de Ventas Mensuales: Mostrar las ventas totales agrupadas por mes y año.
Crecimiento de Clientes: Calcular el número de nuevos clientes registrados por trimestre.
Tasa de Compra Repetida: Determinar qué porcentaje de clientes ha realizado más de una compra.
Productos Comprados Juntos Frecuentemente: Identificar pares de productos que a menudo se compran en la misma transacción.
Rotación de Inventario: Calcular la tasa de rotación de stock para cada categoría de producto.
Productos que Necesitan Reabastecimiento: Listar productos cuyo stock actual está por debajo de su umbral mínimo.
Análisis de Carrito Abandonado (Simulado): Identificar clientes que agregaron productos pero no completaron una venta en un período determinado.
Rendimiento de Proveedores: Clasificar a los proveedores según el volumen de ventas de sus productos.
Análisis Geográfico de Ventas: Agrupar las ventas por ciudad o región del cliente.
Ventas por Hora del Día: Determinar las horas pico de compras para optimizar campañas de marketing.
Impacto de Promociones: Comparar las ventas de un producto antes, durante y después de una campaña de descuento.
Análisis de Cohort: Analizar la retención de clientes mes a mes desde su primera compra.
Margen de Beneficio por Producto: Calcular el margen de beneficio para cada producto (requiere añadir un campo costo a la tabla productos).
Tiempo Promedio Entre Compras: Calcular el tiempo medio que tarda un cliente en volver a comprar.
Productos Más Vistos vs. Comprados: Comparar los productos más visitados con los más comprados.
Segmentación de Clientes (RFM): Clasificar a los clientes en segmentos (Recencia, Frecuencia, Monetario).
Predicción de Demanda Simple: Utilizar datos de ventas pasadas para proyectar las ventas del próximo mes para una categoría específica.


5. Funciones Definidas por el Usuario (UDFs)
Se deben desarrollar 20 funciones que encapsulen lógica de negocio y cálculos reutilizables.



fn_CalcularTotalVenta: Calcula el monto total de una venta específica.
fn_VerificarDisponibilidadStock: Valida si hay stock suficiente para un producto.
fn_ObtenerPrecioProducto: Devuelve el precio actual de un producto.
fn_CalcularEdadCliente: Calcula la edad de un cliente a partir de su fecha de nacimiento.
fn_FormatearNombreCompleto: Devuelve el nombre y apellido de un cliente en un formato estandarizado.
fn_EsClienteNuevo: Devuelve VERDADERO si un cliente realizó su primera compra en los últimos 30 días.
fn_CalcularCostoEnvio: Calcula el costo de envío basado en el peso total de los productos de una venta.
fn_AplicarDescuento: Aplica un porcentaje de descuento a un monto dado.
fn_ObtenerUltimaFechaCompra: Devuelve la fecha de la última compra de un cliente.
fn_ValidarFormatoEmail: Comprueba si una cadena de texto tiene un formato de correo electrónico válido.
fn_ObtenerNombreCategoria: Devuelve el nombre de la categoría a partir del ID de un producto.
fn_ContarVentasCliente: Cuenta el número total de compras realizadas por un cliente.
fn_CalcularDiasDesdeUltimaCompra: Devuelve el número de días transcurridos desde la última compra de un cliente.
fn_DeterminarEstadoLealtad: Asigna un estado de lealtad (Bronce, Plata, Oro) a un cliente según su gasto total.
fn_GenerarSKU: Genera un código de producto (SKU) único basado en su nombre y categoría.
fn_CalcularIVA: Calcula el impuesto (IVA) sobre el total de una venta.
fn_ObtenerStockTotalPorCategoria: Suma el stock de todos los productos de una categoría.
fn_EstimarFechaEntrega: Calcula la fecha estimada de entrega de un pedido según la ubicación del cliente.
fn_ConvertirMoneda: Convierte un monto a otra moneda usando una tasa de cambio fija.
fn_ValidarComplejidadContraseña: Verifica si una contraseña cumple con los criterios de seguridad (longitud, caracteres, etc.).


6. Seguridad y Permisos
Se debe implementar un esquema de seguridad detallado con 20 requerimientos específicos.



Crear el rol Administrador_Sistema con todos los privilegios.
Crear el rol Gerente_Marketing con acceso de solo lectura a ventas y clientes.
Crear el rol Analista_Datos con acceso de solo lectura a todas las tablas, excepto a las de auditoría.
Crear el rol Empleado_Inventario que solo pueda modificar la tabla productos (stock y ubicación).
Crear el rol Atencion_Cliente que pueda ver clientes y ventas, pero no modificar precios.
Crear el rol Auditor_Financiero con acceso de solo lectura a ventas, productos y logs de precios.
Crear un usuario admin_user y asignarle el rol de administrador.
Crear un usuario marketing_user y asignarle el rol de marketing.
Crear un usuario inventory_user y asignarle el rol de inventario.
Crear un usuario support_user y asignarle el rol de atención al cliente.
Impedir que el rol Analista_Datos pueda ejecutar comandos DELETE o TRUNCATE.
Otorgar al rol Gerente_Marketing permiso para ejecutar procedimientos almacenados de reportes de marketing.
Crear una vista v_info_clientes_basica que oculte información sensible y dar acceso a ella al rol Atencion_Cliente.
Revocar el permiso de UPDATE sobre la columna precio de la tabla productos al rol Empleado_Inventario.
Implementar una política de contraseñas seguras para todos los usuarios.
Asegurar que el usuario root no pueda ser usado desde conexiones remotas.
Crear un rol Visitante que solo pueda ver la tabla productos.
Limitar el número de consultas por hora para el rol Analista_Datos para evitar sobrecarga.
Asegurar que los usuarios solo puedan ver las ventas de la sucursal a la que pertenecen (requiere añadir id_sucursal).
Auditar todos los intentos de inicio de sesión fallidos en la base de datos.


7. Triggers (Disparadores)
Se deben implementar 20 triggers para automatizar procesos y garantizar la integridad de los datos.



trg_audit_precio_producto_after_update: Guarda un log de cambios de precios.
trg_check_stock_before_insert_venta: Verifica el stock antes de registrar una venta.
trg_update_stock_after_insert_venta: Decrementa el stock después de una venta.
trg_prevent_delete_categoria_with_products: Impide eliminar una categoría si tiene productos asociados.
trg_log_new_customer_after_insert: Registra en una tabla de auditoría cada vez que se crea un nuevo cliente.
trg_update_total_gastado_cliente: Actualiza un campo total_gastado en la tabla clientes después de cada compra.
trg_set_fecha_modificacion_producto: Actualiza automáticamente la fecha de última modificación de un producto.
trg_prevent_negative_stock: Impide que el stock de un producto se actualice a un valor negativo.
trg_capitalize_nombre_cliente: Convierte a mayúscula la primera letra del nombre y apellido de un cliente al insertarlo.
trg_recalculate_total_venta_on_detalle_change: Recalcula el total en la tabla ventas si se modifica un detalle_venta.
trg_log_order_status_change: Audita cada cambio de estado en un pedido (ej. de 'Procesando' a 'Enviado').
trg_prevent_price_zero_or_less: Impide que el precio de un producto se establezca en cero o un valor negativo.
trg_send_stock_alert_on_low_stock: Inserta un registro en una tabla alertas si el stock baja de un umbral.
trg_archive_deleted_venta: Mueve una venta eliminada a una tabla de archivo en lugar de borrarla permanentemente.
trg_validate_email_format_on_customer: Valida el formato del email antes de insertar o actualizar un cliente.
trg_update_last_order_date_customer: Actualiza la fecha del último pedido en la tabla clientes.
trg_prevent_self_referral: Impide que un cliente se referencie a sí mismo en un programa de referidos.
trg_log_permission_changes: Audita los cambios en los permisos de los usuarios.
trg_assign_default_category_on_null: Asigna una categoría "General" si se inserta un producto sin categoría.
trg_update_producto_count_in_categoria: Mantiene un contador de cuántos productos hay en cada categoría.


8. Eventos Programados
Se deben crear 20 eventos para automatizar tareas de mantenimiento y negocio.



evt_generate_weekly_sales_report: Genera un reporte de ventas semanal.
evt_cleanup_temp_tables_daily: Borra tablas temporales diariamente.
evt_archive_old_logs_monthly: Archiva logs de más de 6 meses en tablas históricas.
evt_deactivate_expired_promotions_hourly: Desactiva códigos de descuento que han expirado.
evt_recalculate_customer_loyalty_tiers_nightly: Recalcula el nivel de lealtad de los clientes cada noche.
evt_generate_reorder_list_daily: Crea una lista de productos que necesitan ser reabastecidos.
evt_rebuild_indexes_weekly: Reconstruye los índices de las tablas más usadas para optimizar el rendimiento.
evt_suspend_inactive_accounts_quarterly: Desactiva cuentas de clientes sin actividad en más de un año.
evt_aggregate_daily_sales_data: Agrega los datos de ventas del día en una tabla de resumen para acelerar reportes.
evt_check_data_consistency_nightly: Busca inconsistencias en los datos (ej. ventas sin detalles).
evt_send_birthday_greetings_daily: Genera una lista de clientes que cumplen años para enviarles un cupón.
evt_update_product_rankings_hourly: Actualiza una tabla con el ranking de los productos más populares.
evt_backup_critical_tables_daily: Realiza un backup lógico de las tablas más importantes cada noche.
evt_clear_abandoned_carts_daily: Vacía los carritos de compra abandonados hace más de 72 horas.
evt_calculate_monthly_kpis: Calcula los KPIs (Key Performance Indicators) del mes y los guarda en una tabla.
evt_refresh_materialized_views_nightly: Actualiza las vistas materializadas (si se usan).
evt_log_database_size_weekly: Registra el tamaño de la base de datos para monitorear su crecimiento.
evt_detect_fraudulent_activity_hourly: Busca patrones de actividad sospechosa (ej. múltiples pedidos fallidos).
evt_generate_supplier_performance_report_monthly: Crea un reporte mensual sobre el rendimiento de los proveedores.
evt_purge_soft_deleted_records_weekly: Elimina permanentemente los registros marcados para borrado hace más de 30 días.


9. Procedimientos Almacenados
Se deben crear 20 procedimientos almacenados para ejecutar operaciones complejas y transaccionales.



sp_RealizarNuevaVenta: Procesa una nueva venta de forma transaccional.
sp_AgregarNuevoProducto: Inserta un nuevo producto y sus atributos iniciales.
sp_ActualizarDireccionCliente: Actualiza la dirección de un cliente en todas las tablas relevantes.
sp_ProcesarDevolucion: Gestiona la devolución de un producto, ajustando el stock y generando un crédito.
sp_ObtenerHistorialComprasCliente: Devuelve el historial completo de compras de un cliente.
sp_AjustarNivelStock: Permite ajustar manualmente el stock de un producto, registrando el motivo.
sp_EliminarClienteDeFormaSegura: Anonimiza los datos de un cliente en lugar de borrarlos, para mantener la integridad referencial.
sp_AplicarDescuentoPorCategoria: Aplica un descuento a todos los productos de una categoría específica.
sp_GenerarReporteMensualVentas: Genera un reporte completo de ventas para un mes y año dados.
sp_CambiarEstadoPedido: Cambia el estado de un pedido (ej. 'Procesando' a 'Enviado') y notifica a otros sistemas.
sp_RegistrarNuevoCliente: Registra un nuevo cliente validando que el email no exista.
sp_ObtenerDetallesProductoCompleto: Devuelve toda la información de un producto, incluyendo datos de su proveedor y categoría.
sp_FusionarCuentasCliente: Fusiona dos cuentas de cliente duplicadas en una sola.
sp_AsignarProductoAProveedor: Asigna o cambia el proveedor de un producto.
sp_BuscarProductos: Realiza una búsqueda avanzada de productos con filtros por nombre, categoría, rango de precios, etc.
sp_ObtenerDashboardAdmin: Devuelve un conjunto de KPIs para un panel de administración (ventas de hoy, nuevos clientes, etc.).
sp_ProcesarPago: Simula el procesamiento de un pago para una venta, actualizando su estado a "Pagado".
sp_AñadirReseñaProducto: Permite a un cliente añadir una reseña y calificación a un producto que ha comprado.
sp_ObtenerProductosRelacionados: Devuelve una lista de productos relacionados a uno dado, basándose en compras de otros clientes.
sp_MoverProductosEntreCategorias: Mueve uno o más productos de una categoría a otra de forma segura.