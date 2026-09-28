-- =============================================================================
-- PROYECTO: Base de Datos para un E-commerce
-- SCRIPT: 01_Esquema_y_Datos.sql
-- DESCRIPCIÓN: Creación de base de datos, tablas principales y de soporte, 
--              e inserción de datos de prueba coherentes y estandarizados.
-- =============================================================================

DROP DATABASE IF EXISTS ecommerce_db;
CREATE DATABASE ecommerce_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ecommerce_db;

-- =============================================================================
-- 1. TABLAS PRINCIPALES DEL SISTEMA
-- =============================================================================

-- Tabla de Categorías de Productos
CREATE TABLE categorias (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT NULL,
    total_productos INT NOT NULL DEFAULT 0
) ENGINE=InnoDB;

-- Tabla de Proveedores de Mercancía
CREATE TABLE proveedores (
    id_proveedor INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    email_contacto VARCHAR(150) NOT NULL UNIQUE,
    telefono_contacto VARCHAR(50) NULL
) ENGINE=InnoDB;

-- Tabla de Sucursales Físicas / Centros de Distribución
CREATE TABLE sucursales (
    id_sucursal INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    ciudad VARCHAR(100) NOT NULL,
    direccion VARCHAR(200) NULL
) ENGINE=InnoDB;

-- Tabla de Clientes Registrados
CREATE TABLE clientes (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    `contraseña` VARCHAR(255) NOT NULL,
    direccion_envio TEXT NULL,
    ciudad VARCHAR(100) NULL,
    fecha_nacimiento DATE NULL,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_gastado DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    nivel_lealtad ENUM('Bronce', 'Plata', 'Oro') NOT NULL DEFAULT 'Bronce',
    id_referido_por INT NULL,
    fecha_ultimo_pedido DATETIME NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_cliente_referido FOREIGN KEY (id_referido_por) REFERENCES clientes(id_cliente) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Tabla de Catálogo de Productos
CREATE TABLE productos (
    id_producto INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL UNIQUE,
    descripcion TEXT NULL,
    precio DECIMAL(10,2) NOT NULL CHECK (precio > 0),
    costo DECIMAL(10,2) NOT NULL DEFAULT 0.00 CHECK (costo >= 0),
    stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    stock_minimo INT NOT NULL DEFAULT 5 CHECK (stock_minimo >= 0),
    sku VARCHAR(50) NOT NULL UNIQUE,
    peso_kg DECIMAL(8,2) NOT NULL DEFAULT 1.00 CHECK (peso_kg > 0),
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion DATETIME NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    id_categoria INT NULL,
    id_proveedor INT NOT NULL,
    CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria) ON DELETE RESTRICT,
    CONSTRAINT fk_producto_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedores(id_proveedor) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Tabla de Encabezado de Ventas / Órdenes
CREATE TABLE ventas (
    id_venta INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_sucursal INT NOT NULL DEFAULT 1,
    fecha_venta DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('Pendiente de Pago', 'Procesando', 'Enviado', 'Entregado', 'Cancelado') NOT NULL DEFAULT 'Pendiente de Pago',
    total DECIMAL(12,2) NOT NULL DEFAULT 0.00 CHECK (total >= 0),
    CONSTRAINT fk_venta_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE RESTRICT,
    CONSTRAINT fk_venta_sucursal FOREIGN KEY (id_sucursal) REFERENCES sucursales(id_sucursal) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Tabla de Líneas / Detalle de Ventas
CREATE TABLE detalle_ventas (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario_congelado DECIMAL(10,2) NOT NULL CHECK (precio_unitario_congelado >= 0),
    subtotal DECIMAL(12,2) NOT NULL DEFAULT 0.00 CHECK (subtotal >= 0),
    CONSTRAINT fk_detalle_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta) ON DELETE CASCADE,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- =============================================================================
-- 2. TABLAS DE SOPORTE (AUDITORÍA, LOGS, EVENTOS Y PROCEDIMIENTOS)
-- =============================================================================

-- Alertas de Stock Bajo
CREATE TABLE alertas_stock (
    id_alerta INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    stock_actual INT NOT NULL,
    mensaje VARCHAR(255) NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_alerta_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Historial de Cambios de Estado de Pedidos
CREATE TABLE historial_pedidos_estado (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT NOT NULL,
    estado_anterior VARCHAR(50) NOT NULL,
    estado_nuevo VARCHAR(50) NOT NULL,
    fecha_cambio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_log_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Archivo Histórico de Ventas Eliminadas
CREATE TABLE ventas_archivadas (
    id_archivo INT AUTO_INCREMENT PRIMARY KEY,
    id_venta_original INT NOT NULL,
    id_cliente INT NOT NULL,
    fecha_venta DATETIME NOT NULL,
    total DECIMAL(12,2) NOT NULL,
    fecha_archivo DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Auditoría de Nuevos Clientes
CREATE TABLE log_auditoria_clientes (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    accion VARCHAR(50) NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Auditoría de Permisos de Usuarios
CREATE TABLE log_permisos_usuarios (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    usuario VARCHAR(100) NOT NULL,
    accion VARCHAR(100) NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Carritos de Compra (Simulación de Carrito Abandonado)
CREATE TABLE carritos_abandonados (
    id_carrito INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL DEFAULT 1,
    fecha_agregado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    abandonado BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_carrito_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE CASCADE,
    CONSTRAINT fk_carrito_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Campañas Promocionales y Descuentos
CREATE TABLE promociones (
    id_promocion INT AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL UNIQUE,
    porcentaje_descuento DECIMAL(5,2) NOT NULL,
    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

-- Reseñas y Calificaciones de Productos
CREATE TABLE `reseñas_productos` (
    `id_reseña` INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_producto INT NOT NULL,
    calificacion INT NOT NULL CHECK (calificacion BETWEEN 1 AND 5),
    comentario TEXT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_reseña_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE CASCADE,
    CONSTRAINT fk_reseña_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Gestión de Devoluciones y Créditos
CREATE TABLE devoluciones (
    id_devolucion INT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL,
    monto_credito DECIMAL(10,2) NOT NULL,
    motivo VARCHAR(255) NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_devolucion_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta) ON DELETE CASCADE,
    CONSTRAINT fk_devolucion_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Resumen de Ventas Diarias (Agregación por Evento)
CREATE TABLE resumen_ventas_diarias (
    fecha DATE PRIMARY KEY,
    total_ventas DECIMAL(12,2) NOT NULL,
    cantidad_pedidos INT NOT NULL
) ENGINE=InnoDB;

-- KPIs Mensuales (Cálculo por Evento)
CREATE TABLE kpis_mensuales (
    id_kpi INT AUTO_INCREMENT PRIMARY KEY,
    anio INT NOT NULL,
    mes INT NOT NULL,
    ingresos_totales DECIMAL(14,2) NOT NULL,
    total_pedidos INT NOT NULL,
    ticket_promedio DECIMAL(10,2) NOT NULL,
    UNIQUE KEY uk_anio_mes (anio, mes)
) ENGINE=InnoDB;

-- Ranking de Productos (Actualización por Evento)
CREATE TABLE ranking_productos (
    id_ranking INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    posicion INT NOT NULL,
    total_vendido INT NOT NULL,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ranking_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Monitoreo de Tamaño de Base de Datos
CREATE TABLE monitoreo_bd (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    tamanio_mb DECIMAL(10,2) NOT NULL,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Reporte de Rendimiento de Proveedores
CREATE TABLE reporte_proveedores (
    id_reporte INT AUTO_INCREMENT PRIMARY KEY,
    id_proveedor INT NOT NULL,
    mes INT NOT NULL,
    anio INT NOT NULL,
    total_vendido DECIMAL(12,2) NOT NULL,
    unidades_vendidas INT NOT NULL,
    CONSTRAINT fk_reporte_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedores(id_proveedor) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Registro de Visitas a Productos (Para análisis Vistos vs Comprados)
CREATE TABLE visitas_productos (
    id_visita INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    fecha_visita DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_visitas_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =============================================================================
-- 3. INSERCIÓN DE DATOS DE PRUEBA (POBLADO INICIAL)
-- =============================================================================

-- Sucursales
INSERT INTO sucursales (id_sucursal, nombre, ciudad, direccion) VALUES
(1, 'Sucursal Central', 'Bogotá', 'Cra 7 # 72-41'),
(2, 'Sucursal Norte', 'Medellín', 'Calle 10 # 43E-12'),
(3, 'Sucursal Occidente', 'Cali', 'Av. San Joaquín # 14-25'),
(4, 'Sucursal Costa', 'Barranquilla', 'Cra 53 # 82-86'),
(5, 'Sucursal Santander', 'Bucaramanga', 'Cra 27 # 36-14');

-- Categorías
INSERT INTO categorias (id_categoria, nombre, descripcion, total_productos) VALUES
(1, 'Electrónica', 'Dispositivos tecnológicos, computadores y audio', 5),
(2, 'Ropa y Calzado', 'Prendas de vestir para damas, caballeros y calzado', 4),
(3, 'Hogar y Cocina', 'Muebles, electrodomésticos y decoración del hogar', 4),
(4, 'Deportes y Fitness', 'Equipos de ejercicio, accesorios y suplementos', 4),
(5, 'Libros y Papelería', 'Literatura, textos de estudio y útiles de oficina', 3);

-- Proveedores
INSERT INTO proveedores (id_proveedor, nombre, email_contacto, telefono_contacto) VALUES
(1, 'TechGlobal S.A.', 'ventas@techglobal.com', '+57 300 1112233'),
(2, 'ModaTextil Corp', 'contacto@modatextil.co', '+57 311 2223344'),
(3, 'HomeStyle Ltda', 'info@homestyle.com', '+57 315 3334455'),
(4, 'SportPro Distribuciones', 'pedidos@sportpro.com', '+57 320 4445566'),
(5, 'Editorial Mundo Letras', 'comercial@mundoletras.com', '+57 318 5556677');

-- Clientes
INSERT INTO clientes (id_cliente, nombre, apellido, email, contraseña, direccion_envio, ciudad, fecha_nacimiento, fecha_registro, total_gastado, nivel_lealtad, id_referido_por, fecha_ultimo_pedido, activo) VALUES
(1, 'Carlos', 'Gómez', 'carlos.gomez@email.com', '$2y$10$abcdef1234567890dummyhash1', 'Calle 100 # 15-20', 'Bogotá', '1985-04-12', '2025-01-15 10:30:00', 3450.00, 'Oro', NULL, '2026-03-10 14:20:00', TRUE),
(2, 'María', 'Rodríguez', 'maria.rodriguez@email.com', '$2y$10$abcdef1234567890dummyhash2', 'Cra 43A # 1-50', 'Medellín', '1990-08-23', '2025-02-10 11:15:00', 1820.00, 'Plata', 1, '2026-03-12 16:45:00', TRUE),
(3, 'Andrés', 'López', 'andres.lopez@email.com', '$2y$10$abcdef1234567890dummyhash3', 'Av. 6N # 22-04', 'Cali', '1982-12-05', '2025-03-05 09:00:00', 890.00, 'Bronce', 1, '2026-02-18 10:00:00', TRUE),
(4, 'Laura', 'Martínez', 'laura.martinez@email.com', '$2y$10$abcdef1234567890dummyhash4', 'Calle 84 # 51B-32', 'Barranquilla', '1995-03-30', '2025-04-20 15:40:00', 4200.00, 'Oro', 2, '2026-03-15 18:30:00', TRUE),
(5, 'Felipe', 'Hernández', 'felipe.hernandez@email.com', '$2y$10$abcdef1234567890dummyhash5', 'Cra 33 # 48-110', 'Bucaramanga', '1988-11-14', '2025-05-12 14:10:00', 650.00, 'Bronce', NULL, '2026-01-20 11:30:00', TRUE),
(6, 'Diana', 'Torres', 'diana.torres@email.com', '$2y$10$abcdef1234567890dummyhash6', 'Calle 127 # 19-45', 'Bogotá', '1992-07-19', '2025-06-01 16:20:00', 2150.00, 'Plata', 4, '2026-03-08 12:15:00', TRUE),
(7, 'Javier', 'Ramírez', 'javier.ramirez@email.com', '$2y$10$abcdef1234567890dummyhash7', 'Circular 4 # 73-10', 'Medellín', '1979-01-28', '2025-07-18 08:50:00', 5100.00, 'Oro', NULL, '2026-03-20 17:00:00', TRUE),
(8, 'Camila', 'Vargas', 'camila.vargas@email.com', '$2y$10$abcdef1234567890dummyhash8', 'Calle 9 # 38-21', 'Cali', '1998-09-09', '2025-08-22 13:00:00', 320.00, 'Bronce', 6, '2025-11-15 15:10:00', TRUE),
(9, 'Esteban', 'Morales', 'esteban.morales@email.com', '$2y$10$abcdef1234567890dummyhash9', 'Cra 58 # 70-15', 'Barranquilla', '1984-06-17', '2025-09-14 17:35:00', 1450.00, 'Plata', NULL, '2026-02-25 19:40:00', TRUE),
(10, 'Valentina', 'Castillo', 'valentina.castillo@email.com', '$2y$10$abcdef1234567890dummyhash10', 'Calle 56 # 28-30', 'Bucaramanga', '2001-02-14', '2025-10-05 12:00:00', 980.00, 'Bronce', 7, '2026-03-01 14:50:00', TRUE),
(11, 'Santiago', 'Ríos', 'santiago.rios@email.com', '$2y$10$abcdef1234567890dummyhash11', 'Calle 140 # 11-20', 'Bogotá', '1993-05-25', '2025-11-19 10:20:00', 290.00, 'Bronce', NULL, '2025-12-10 16:00:00', TRUE),
(12, 'Paula', 'Ortiz', 'paula.ortiz@email.com', '$2y$10$abcdef1234567890dummyhash12', 'Cra 70 # 44A-12', 'Medellín', '1987-10-31', '2025-12-01 11:45:00', 1780.00, 'Plata', NULL, '2026-03-14 13:20:00', TRUE),
(13, 'Alejandro', 'Paredes', 'alejandro.paredes@email.com', '$2y$10$abcdef1234567890dummyhash13', 'Av. Roosevelt # 34-10', 'Cali', '1991-03-15', '2026-01-08 14:15:00', 3100.00, 'Oro', 4, '2026-03-18 11:30:00', TRUE),
(14, 'Daniela', 'Herrera', 'daniela.herrera@email.com', '$2y$10$abcdef1234567890dummyhash14', 'Calle 76 # 49B-18', 'Barranquilla', '1996-12-08', '2026-01-20 18:00:00', 450.00, 'Bronce', NULL, '2026-02-14 16:40:00', TRUE),
(15, 'Mateo', 'Jiménez', 'mateo.jimenez@email.com', '$2y$10$abcdef1234567890dummyhash15', 'Cra 35A # 52-90', 'Bucaramanga', '1989-08-04', '2026-02-01 09:30:00', 1250.00, 'Plata', 13, '2026-03-21 15:10:00', TRUE),
(16, 'Natalia', 'Guerrero', 'natalia.guerrero@email.com', '$2y$10$abcdef1234567890dummyhash16', 'Calle 80 # 68-15', 'Bogotá', '1994-09-29', '2026-02-15 15:00:00', 780.00, 'Bronce', NULL, '2026-03-05 10:20:00', TRUE),
(17, 'Sebastián', 'Muñoz', 'sebastian.munoz@email.com', '$2y$10$abcdef1234567890dummyhash17', 'Cra 65 # 80-20', 'Medellín', '1986-07-07', '2026-03-01 10:00:00', 2100.00, 'Plata', 7, '2026-03-22 18:00:00', TRUE),
(18, 'Juliana', 'Mendoza', 'juliana.mendoza@email.com', '$2y$10$abcdef1234567890dummyhash18', 'Calle 5 # 66-30', 'Cali', '1997-11-20', '2026-03-05 11:30:00', 150.00, 'Bronce', NULL, '2026-03-19 12:45:00', TRUE),
(19, 'David', 'Suárez', 'david.suarez@email.com', '$2y$10$abcdef1234567890dummyhash19', 'Cra 46 # 90-12', 'Barranquilla', '1983-04-18', '2026-03-10 16:45:00', 0.00, 'Bronce', NULL, NULL, TRUE),
(20, 'Andrea', 'Cruz', 'andrea.cruz@email.com', '$2y$10$abcdef1234567890dummyhash20', 'Calle 45 # 19-10', 'Bucaramanga', '1999-06-25', '2026-03-12 17:15:00', 0.00, 'Bronce', NULL, NULL, TRUE);

-- Productos
INSERT INTO productos (id_producto, nombre, descripcion, precio, costo, stock, stock_minimo, sku, peso_kg, fecha_creacion, activo, id_categoria, id_proveedor) VALUES
(1, 'Laptop UltraPro 15"', 'Portátil 16GB RAM SSD 512GB Intel Core i7', 1200.00, 850.00, 25, 5, 'ELEC-LAP-001', 2.10, '2025-01-10 08:00:00', TRUE, 1, 1),
(2, 'Smartphone Galaxy X', 'Teléfono inteligente 128GB cámara 108MP', 800.00, 520.00, 40, 8, 'ELEC-TEL-002', 0.45, '2025-01-10 08:30:00', TRUE, 1, 1),
(3, 'Auriculares NoiseCancel Pro', 'Audífonos Bluetooth con cancelación activa', 150.00, 85.00, 60, 10, 'ELEC-AUD-003', 0.35, '2025-01-12 09:00:00', TRUE, 1, 1),
(4, 'Smartwatch Fit Pulse', 'Reloj inteligente con monitor cardíaco y GPS', 120.00, 70.00, 3, 10, 'ELEC-WAT-004', 0.20, '2025-01-15 10:00:00', TRUE, 1, 1),
(5, 'Monitor Gamer 27" 144Hz', 'Pantalla IPS QHD tiempo respuesta 1ms', 300.00, 195.00, 15, 4, 'ELEC-MON-005', 4.50, '2025-01-20 11:00:00', TRUE, 1, 1),
(6, 'Camisa Formal Algodón', 'Camisa clásica manga larga 100% algodón', 45.00, 22.00, 80, 15, 'ROPA-CAM-006', 0.30, '2025-01-15 14:00:00', TRUE, 2, 2),
(7, 'Pantalón Jean Slim Fit', 'Jean mezclilla stretch resistente', 60.00, 30.00, 70, 12, 'ROPA-PAN-007', 0.60, '2025-01-16 15:00:00', TRUE, 2, 2),
(8, 'Zapatillas Running Pro', 'Calzado deportivo ergonómico suela amortiguada', 95.00, 50.00, 35, 8, 'ROPA-ZAP-008', 0.85, '2025-01-18 16:00:00', TRUE, 2, 2),
(9, 'Chaqueta Impermeable', 'Chaqueta cortavientos térmica unisex', 85.00, 42.00, 2, 8, 'ROPA-CHA-009', 0.70, '2025-01-20 17:00:00', TRUE, 2, 2),
(10, 'Cafetera Expreso Barista', 'Máquina de café 15 bares con vaporizador', 220.00, 130.00, 18, 5, 'HOG-CAF-010', 3.80, '2025-02-01 09:00:00', TRUE, 3, 3),
(11, 'Licuadora de Alta Potencia', 'Vaso de vidrio 1.5L motor 1000W 6 velocidades', 80.00, 45.00, 22, 6, 'HOG-LIC-011', 2.50, '2025-02-05 10:00:00', TRUE, 3, 3),
(12, 'Aspiradora Robot Inteligente', 'Navegación láser sensor anticaída WiFi', 280.00, 175.00, 12, 4, 'HOG-ASP-012', 3.20, '2025-02-10 11:30:00', TRUE, 3, 3),
(13, 'Juego Sartenes Cerámica', 'Set de 3 sartenes antiadherentes libre tóxicos', 75.00, 38.00, 4, 6, 'HOG-SAR-013', 2.00, '2025-02-12 12:00:00', TRUE, 3, 3),
(14, 'Bicicleta Estática Magnética', 'Resistencia ajustable monitor digital', 350.00, 210.00, 8, 3, 'DEP-BIC-014', 18.50, '2025-02-15 14:00:00', TRUE, 4, 4),
(15, 'Mancuernas Ajustables 20kg', 'Par de pesas intercambiables con barra', 90.00, 52.00, 20, 5, 'DEP-MAN-015', 20.00, '2025-02-18 15:00:00', TRUE, 4, 4),
(16, 'Tapete Yoga Antideslizante', 'Colchoneta ecológico TPE 6mm con correa', 30.00, 14.00, 50, 10, 'DEP-YOG-016', 0.90, '2025-02-20 16:00:00', TRUE, 4, 4),
(17, 'Proteína Whey Isolate 2kg', 'Suplemento proteico sabor vainilla', 65.00, 38.00, 30, 8, 'DEP-PRO-017', 2.20, '2025-02-22 17:00:00', TRUE, 4, 4),
(18, 'Libro: Diseño de Bases de Datos', 'Guía profesional de modelado y optimización SQL', 40.00, 20.00, 45, 8, 'LIB-BDD-018', 0.75, '2025-03-01 09:00:00', TRUE, 5, 5),
(19, 'Libro: Algoritmos y Estructuras', 'Fundamentos teóricos y ejercicios prácticos', 45.00, 24.00, 35, 8, 'LIB-ALG-019', 0.85, '2025-03-02 10:00:00', TRUE, 5, 5),
(20, 'Set Cuadernos Profesionales', 'Pack de 3 libretas pasta dura rayadas', 20.00, 9.00, 1, 10, 'LIB-CUA-020', 1.10, '2025-03-05 11:00:00', TRUE, 5, 5);

-- Ventas
INSERT INTO ventas (id_venta, id_cliente, id_sucursal, fecha_venta, estado, total) VALUES
(1, 1, 1, '2025-02-15 14:30:00', 'Entregado', 1350.00),
(2, 2, 2, '2025-03-10 11:00:00', 'Entregado', 845.00),
(3, 4, 4, '2025-05-18 16:20:00', 'Entregado', 2100.00),
(4, 3, 3, '2025-06-25 10:15:00', 'Entregado', 890.00),
(5, 7, 2, '2025-08-14 17:45:00', 'Entregado', 2400.00),
(6, 6, 1, '2025-09-05 13:30:00', 'Entregado', 1150.00),
(7, 1, 1, '2025-10-12 15:10:00', 'Entregado', 900.00),
(8, 5, 5, '2025-11-20 18:00:00', 'Entregado', 650.00),
(9, 8, 3, '2025-11-28 11:20:00', 'Entregado', 320.00),
(10, 9, 4, '2025-12-05 16:40:00', 'Entregado', 850.00),
(11, 2, 2, '2025-12-18 14:15:00', 'Entregado', 975.00),
(12, 11, 1, '2025-12-22 10:50:00', 'Entregado', 290.00),
(13, 7, 2, '2026-01-10 12:00:00', 'Entregado', 1500.00),
(14, 10, 5, '2026-01-15 15:30:00', 'Entregado', 580.00),
(15, 4, 4, '2026-01-22 17:10:00', 'Entregado', 2100.00),
(16, 12, 2, '2026-02-02 11:25:00', 'Entregado', 950.00),
(17, 13, 3, '2026-02-10 16:00:00', 'Entregado', 1600.00),
(18, 14, 4, '2026-02-14 13:45:00', 'Entregado', 450.00),
(19, 1, 1, '2026-02-20 14:50:00', 'Entregado', 1200.00),
(20, 9, 4, '2026-02-25 19:40:00', 'Entregado', 600.00),
(21, 10, 5, '2026-03-01 14:50:00', 'Entregado', 400.00),
(22, 16, 1, '2026-03-05 10:20:00', 'Entregado', 780.00),
(23, 6, 1, '2026-03-08 12:15:00', 'Entregado', 1000.00),
(24, 15, 5, '2026-03-12 15:10:00', 'Enviado', 1250.00),
(25, 12, 2, '2026-03-14 13:20:00', 'Enviado', 830.00),
(26, 17, 2, '2026-03-18 11:00:00', 'Procesando', 2100.00),
(27, 13, 3, '2026-03-18 11:30:00', 'Procesando', 1500.00),
(28, 18, 3, '2026-03-19 12:45:00', 'Procesando', 150.00),
(29, 7, 2, '2026-03-20 17:00:00', 'Pendiente de Pago', 1200.00),
(30, 15, 5, '2026-03-21 16:30:00', 'Cancelado', 300.00);

-- Detalle de Ventas
INSERT INTO detalle_ventas (id_detalle, id_venta, id_producto, cantidad, precio_unitario_congelado, subtotal) VALUES
(1, 1, 1, 1, 1200.00, 1200.00),
(2, 1, 3, 1, 150.00, 150.00),
(3, 2, 2, 1, 800.00, 800.00),
(4, 2, 6, 1, 45.00, 45.00),
(5, 3, 1, 1, 1200.00, 1200.00),
(6, 3, 2, 1, 800.00, 800.00),
(7, 3, 4, 1, 100.00, 100.00),
(8, 4, 2, 1, 800.00, 800.00),
(9, 4, 8, 1, 90.00, 90.00),
(10, 5, 1, 2, 1200.00, 2400.00),
(11, 6, 2, 1, 800.00, 800.00),
(12, 6, 14, 1, 350.00, 350.00),
(13, 7, 2, 1, 800.00, 800.00),
(14, 7, 3, 1, 100.00, 100.00),
(15, 8, 14, 1, 350.00, 350.00),
(16, 8, 5, 1, 300.00, 300.00),
(17, 9, 10, 1, 220.00, 220.00),
(18, 9, 3, 1, 100.00, 100.00),
(19, 10, 2, 1, 800.00, 800.00),
(20, 10, 6, 1, 50.00, 50.00),
(21, 11, 2, 1, 800.00, 800.00),
(22, 11, 13, 1, 75.00, 75.00),
(23, 11, 4, 1, 100.00, 100.00),
(24, 12, 10, 1, 220.00, 220.00),
(25, 12, 13, 1, 70.00, 70.00),
(26, 13, 1, 1, 1200.00, 1200.00),
(27, 13, 5, 1, 300.00, 300.00),
(28, 14, 12, 2, 280.00, 560.00),
(29, 14, 20, 1, 20.00, 20.00),
(30, 15, 1, 1, 1200.00, 1200.00),
(31, 15, 2, 1, 800.00, 800.00),
(32, 15, 4, 1, 100.00, 100.00),
(33, 16, 2, 1, 800.00, 800.00),
(34, 16, 3, 1, 150.00, 150.00),
(35, 17, 1, 1, 1200.00, 1200.00),
(36, 17, 5, 1, 300.00, 300.00),
(37, 17, 4, 1, 100.00, 100.00),
(38, 18, 11, 5, 80.00, 400.00),
(39, 18, 6, 1, 50.00, 50.00),
(40, 19, 1, 1, 1200.00, 1200.00),
(41, 20, 5, 2, 300.00, 600.00),
(42, 21, 18, 5, 40.00, 200.00),
(43, 21, 19, 4, 45.00, 180.00),
(44, 21, 20, 1, 20.00, 20.00),
(45, 22, 14, 2, 350.00, 700.00),
(46, 22, 11, 1, 80.00, 80.00),
(47, 23, 2, 1, 800.00, 800.00),
(48, 23, 10, 1, 200.00, 200.00),
(49, 24, 1, 1, 1200.00, 1200.00),
(50, 24, 6, 1, 50.00, 50.00),
(51, 25, 2, 1, 800.00, 800.00),
(52, 25, 16, 1, 30.00, 30.00),
(53, 26, 1, 1, 1200.00, 1200.00),
(54, 26, 2, 1, 800.00, 800.00),
(55, 26, 4, 1, 100.00, 100.00),
(56, 27, 1, 1, 1200.00, 1200.00),
(57, 27, 5, 1, 300.00, 300.00),
(58, 28, 3, 1, 150.00, 150.00),
(59, 29, 1, 1, 1200.00, 1200.00),
(60, 30, 5, 1, 300.00, 300.00);

-- Carritos Abandonados (Datos para análisis)
INSERT INTO carritos_abandonados (id_carrito, id_cliente, id_producto, cantidad, fecha_agregado, abandonado) VALUES
(1, 19, 1, 1, '2026-03-24 10:00:00', TRUE),
(2, 19, 3, 2, '2026-03-24 10:05:00', TRUE),
(3, 20, 2, 1, '2026-03-23 15:30:00', TRUE),
(4, 5, 10, 1, '2026-03-22 18:20:00', TRUE),
(5, 8, 14, 1, '2026-03-21 09:15:00', TRUE);

-- Promociones
INSERT INTO promociones (id_promocion, codigo, porcentaje_descuento, fecha_inicio, fecha_fin, activo) VALUES
(1, 'TECH2025', 10.00, '2025-05-01 00:00:00', '2025-05-31 23:59:59', FALSE),
(2, 'BLACKFRIDAY', 20.00, '2025-11-20 00:00:00', '2025-11-30 23:59:59', FALSE),
(3, 'VERANO2026', 15.00, '2026-06-01 00:00:00', '2026-06-30 23:59:59', TRUE),
(4, 'BIENVENIDA', 5.00, '2026-01-01 00:00:00', '2026-12-31 23:59:59', TRUE);

-- Reseñas de Productos
INSERT INTO `reseñas_productos` (`id_reseña`, id_cliente, id_producto, calificacion, comentario, fecha) VALUES
(1, 1, 1, 5, 'Excelente portátil, rápido y de gran rendimiento para trabajo pesado.', '2025-02-20 10:00:00'),
(2, 2, 2, 4, 'Gran teléfono, la cámara es muy buena pero la batería dura un día normal.', '2025-03-15 14:30:00'),
(3, 3, 2, 5, 'Muy satisfecho con la fluidez y la pantalla AMOLED.', '2025-07-01 09:20:00'),
(4, 4, 1, 5, 'Calidad insuperable, totalmente recomendado.', '2025-06-01 11:10:00'),
(5, 7, 14, 4, 'Bicicleta robusta y silenciosa, fácil de armar.', '2025-08-20 18:00:00');

-- Visitas a Productos (Métricas de Tráfico para Productos Más Vistos)
INSERT INTO visitas_productos (id_producto, fecha_visita) VALUES
(1, '2026-03-01 10:00:00'), (1, '2026-03-02 11:00:00'), (1, '2026-03-03 12:00:00'),
(1, '2026-03-04 14:00:00'), (1, '2026-03-05 16:00:00'), (1, '2026-03-06 18:00:00'),
(2, '2026-03-01 09:00:00'), (2, '2026-03-02 10:30:00'), (2, '2026-03-03 14:15:00'),
(2, '2026-03-04 15:45:00'), (2, '2026-03-05 17:00:00'),
(3, '2026-03-01 08:30:00'), (3, '2026-03-02 12:45:00'), (3, '2026-03-03 16:20:00'),
(4, '2026-03-01 11:00:00'), (4, '2026-03-02 14:00:00'),
(10, '2026-03-01 13:00:00'), (10, '2026-03-03 15:00:00'), (10, '2026-03-04 17:00:00'),
(14, '2026-03-02 10:00:00'), (14, '2026-03-03 11:30:00'), (14, '2026-03-05 15:00:00'),
(18, '2026-03-01 09:30:00'), (19, '2026-03-02 11:45:00');
