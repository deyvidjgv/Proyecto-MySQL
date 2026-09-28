-- =============================================================================
-- PROYECTO: Base de Datos para un E-commerce
-- SCRIPT: 04_Seguridad.sql
-- DESCRIPCIÓN: Implementación de 20 requerimientos de seguridad, roles, 
--              usuarios, permisos granulares, vistas seguras y auditoría.
-- =============================================================================

USE ecommerce_db;

-- -----------------------------------------------------------------------------
-- 1. Crear el rol Administrador_Sistema con todos los privilegios.
-- -----------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS 'Administrador_Sistema';
GRANT ALL PRIVILEGES ON ecommerce_db.* TO 'Administrador_Sistema' WITH GRANT OPTION;

-- -----------------------------------------------------------------------------
-- 2. Crear el rol Gerente_Marketing con acceso de solo lectura a ventas y clientes.
-- -----------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.ventas TO 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.detalle_ventas TO 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.clientes TO 'Gerente_Marketing';

-- -----------------------------------------------------------------------------
-- 3. Crear el rol Analista_Datos con acceso de solo lectura a tablas de negocio.
--    (Excluyendo explícitamente las tablas de auditoría y logs del sistema).
-- -----------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS 'Analista_Datos';
GRANT SELECT ON ecommerce_db.categorias TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.proveedores TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.sucursales TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.productos TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.clientes TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.ventas TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.detalle_ventas TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.promociones TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.carritos_abandonados TO 'Analista_Datos';
GRANT SELECT ON ecommerce_db.visitas_productos TO 'Analista_Datos';

-- -----------------------------------------------------------------------------
-- 4. Crear el rol Empleado_Inventario que solo pueda modificar productos (stock).
-- -----------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS 'Empleado_Inventario';
GRANT SELECT ON ecommerce_db.productos TO 'Empleado_Inventario';
GRANT UPDATE (stock) ON ecommerce_db.productos TO 'Empleado_Inventario';

-- -----------------------------------------------------------------------------
-- 5. Crear el rol Atencion_Cliente que pueda ver clientes y ventas, sin precios.
-- -----------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS 'Atencion_Cliente';
GRANT SELECT ON ecommerce_db.clientes TO 'Atencion_Cliente';
GRANT SELECT ON ecommerce_db.ventas TO 'Atencion_Cliente';
GRANT SELECT (id_detalle, id_venta, id_producto, cantidad) ON ecommerce_db.detalle_ventas TO 'Atencion_Cliente';
GRANT SELECT (id_producto, nombre, descripcion, stock, sku, activo) ON ecommerce_db.productos TO 'Atencion_Cliente';

-- -----------------------------------------------------------------------------
-- 6. Crear el rol Auditor_Financiero con acceso a ventas, productos y logs.
-- -----------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.ventas TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.detalle_ventas TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.productos TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.historial_pedidos_estado TO 'Auditor_Financiero';

-- -----------------------------------------------------------------------------
-- 7. Crear usuario admin_user y asignarle el rol de administrador.
-- -----------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'admin_user'@'localhost' IDENTIFIED BY 'Admin2026!SecureKey';
GRANT 'Administrador_Sistema' TO 'admin_user'@'localhost';
SET DEFAULT ROLE 'Administrador_Sistema' FOR 'admin_user'@'localhost';

-- -----------------------------------------------------------------------------
-- 8. Crear usuario marketing_user y asignarle el rol de marketing.
-- -----------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'marketing_user'@'localhost' IDENTIFIED BY 'Market2026!PromoPass';
GRANT 'Gerente_Marketing' TO 'marketing_user'@'localhost';
SET DEFAULT ROLE 'Gerente_Marketing' FOR 'marketing_user'@'localhost';

-- -----------------------------------------------------------------------------
-- 9. Crear usuario inventory_user y asignarle el rol de inventario.
-- -----------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'inventory_user'@'localhost' IDENTIFIED BY 'Inven2026!StockKey';
GRANT 'Empleado_Inventario' TO 'inventory_user'@'localhost';
SET DEFAULT ROLE 'Empleado_Inventario' FOR 'inventory_user'@'localhost';

-- -----------------------------------------------------------------------------
-- 10. Crear usuario support_user y asignarle el rol de atención al cliente.
-- -----------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'support_user'@'localhost' IDENTIFIED BY 'Supp2026!ClientPass';
GRANT 'Atencion_Cliente' TO 'support_user'@'localhost';
SET DEFAULT ROLE 'Atencion_Cliente' FOR 'support_user'@'localhost';

-- -----------------------------------------------------------------------------
-- 11. Impedir que el rol Analista_Datos pueda ejecutar comandos DELETE o TRUNCATE.
-- En MySQL/MariaDB, la restricción de DELETE y TRUNCATE (que requiere DROP) se 
-- garantiza al aplicar el principio de menor privilegio: sólo se otorgan 
-- permisos SELECT sobre las tablas autorizadas, excluyendo DELETE y DROP.
-- -----------------------------------------------------------------------------
-- (Garantizado por diseño: 'Analista_Datos' no posee permisos DELETE ni DROP)

-- -----------------------------------------------------------------------------
-- 12. Otorgar al rol Gerente_Marketing permiso de ejecución de procedimientos.
-- -----------------------------------------------------------------------------
GRANT EXECUTE ON ecommerce_db.* TO 'Gerente_Marketing';

-- -----------------------------------------------------------------------------
-- 13. Crear vista v_info_clientes_basica (oculta contraseñas y datos sensibles)
--     y otorgar acceso a ella al rol Atencion_Cliente.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_info_clientes_basica AS
SELECT 
    id_cliente,
    nombre,
    apellido,
    email,
    ciudad,
    nivel_lealtad,
    fecha_registro
FROM clientes;

GRANT SELECT ON ecommerce_db.v_info_clientes_basica TO 'Atencion_Cliente';

-- -----------------------------------------------------------------------------
-- 14. Revocar el permiso de UPDATE sobre la columna precio al rol Empleado_Inventario.
-- -----------------------------------------------------------------------------
GRANT UPDATE (stock, precio) ON ecommerce_db.productos TO 'Empleado_Inventario';
REVOKE UPDATE (precio) ON ecommerce_db.productos FROM 'Empleado_Inventario';

-- -----------------------------------------------------------------------------
-- 15. Implementar política de contraseñas seguras y expiración periódica.
-- -----------------------------------------------------------------------------
ALTER USER 'admin_user'@'localhost' PASSWORD EXPIRE INTERVAL 90 DAY;
ALTER USER 'marketing_user'@'localhost' PASSWORD EXPIRE INTERVAL 90 DAY;
ALTER USER 'inventory_user'@'localhost' PASSWORD EXPIRE INTERVAL 90 DAY;
ALTER USER 'support_user'@'localhost' PASSWORD EXPIRE INTERVAL 90 DAY;

-- -----------------------------------------------------------------------------
-- 16. Asegurar que el usuario root no pueda ser usado desde conexiones remotas.
-- -----------------------------------------------------------------------------
DROP USER IF EXISTS 'root'@'%';
DELETE FROM mysql.user WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
FLUSH PRIVILEGES;

-- -----------------------------------------------------------------------------
-- 17. Crear un rol Visitante que solo pueda consultar el catálogo de productos.
-- -----------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS 'Visitante';
GRANT SELECT (id_producto, nombre, descripcion, precio, sku, activo, id_categoria) 
ON ecommerce_db.productos TO 'Visitante';

-- -----------------------------------------------------------------------------
-- 18. Limitar el número de consultas por hora para el usuario analista.
-- -----------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'analyst_user'@'localhost' 
IDENTIFIED BY 'Analyst2026!QueryLimit' 
WITH MAX_QUERIES_PER_HOUR 500;

GRANT 'Analista_Datos' TO 'analyst_user'@'localhost';
SET DEFAULT ROLE 'Analista_Datos' FOR 'analyst_user'@'localhost';

-- -----------------------------------------------------------------------------
-- 19. Asegurar que los usuarios solo vean ventas de su sucursal correspondiente.
--     (Filtro de seguridad a nivel de filas mediante vista contextual).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS asignacion_usuario_sucursal (
    usuario_bd VARCHAR(100) PRIMARY KEY,
    id_sucursal INT NOT NULL,
    CONSTRAINT fk_asig_sucursal FOREIGN KEY (id_sucursal) REFERENCES sucursales(id_sucursal)
) ENGINE=InnoDB;

INSERT INTO asignacion_usuario_sucursal (usuario_bd, id_sucursal) VALUES
('marketing_user@localhost', 1),
('support_user@localhost', 2),
('inventory_user@localhost', 1)
ON DUPLICATE KEY UPDATE id_sucursal = VALUES(id_sucursal);

CREATE OR REPLACE VIEW v_ventas_sucursal_usuario AS
SELECT v.*
FROM ventas v
JOIN asignacion_usuario_sucursal aus ON v.id_sucursal = aus.id_sucursal
WHERE aus.usuario_bd = CURRENT_USER()
   OR CURRENT_USER() LIKE 'root@%'
   OR CURRENT_USER() LIKE 'admin_user@%';

GRANT SELECT ON ecommerce_db.v_ventas_sucursal_usuario TO 'Atencion_Cliente';
GRANT SELECT ON ecommerce_db.v_ventas_sucursal_usuario TO 'Gerente_Marketing';

-- -----------------------------------------------------------------------------
-- 20. Auditar intentos de inicio de sesión fallidos en la base de datos.
-- -----------------------------------------------------------------------------
SET GLOBAL log_warnings = 2;

CREATE TABLE IF NOT EXISTS auditoria_accesos_fallidos (
    id_auditoria INT AUTO_INCREMENT PRIMARY KEY,
    usuario_intentado VARCHAR(100) NOT NULL,
    ip_origen VARCHAR(50) NOT NULL,
    fecha_intento DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    motivo VARCHAR(255) DEFAULT 'Credenciales incorrectas o rechazo de autenticación'
) ENGINE=InnoDB;

FLUSH PRIVILEGES;
