
/* PROYECTO E-COMMERCE - VERSION DE CLASE - 10 EXACTAS */

/* Ejecutar completo en DBeaver. Esta versión conserva el esquema y datos, pero deja 10 objetos exactos por grupo. */



-- Proyecto de Base de Datos para un E-commerce
-- Compatible con MySQL Community Server 8.0.46.
-- Ejecutar primero este archivo en DBeaver.

CREATE DATABASE IF NOT EXISTS ecommerce_bd
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
USE ecommerce_bd;

CREATE TABLE IF NOT EXISTS sucursales (
    id_sucursal INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    ciudad VARCHAR(80) NOT NULL,
    region VARCHAR(80) NOT NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE KEY uk_sucursal_nombre (nombre)
);

CREATE TABLE IF NOT EXISTS categorias (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    id_categoria_padre INT NULL,
    cantidad_productos INT NOT NULL DEFAULT 0,
    UNIQUE KEY uk_categoria_nombre (nombre),
    CONSTRAINT fk_categoria_padre FOREIGN KEY (id_categoria_padre) REFERENCES categorias(id_categoria),
    CONSTRAINT chk_categoria_productos CHECK (cantidad_productos >= 0)
);

CREATE TABLE IF NOT EXISTS proveedores (
    id_proveedor INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    email_contacto VARCHAR(150) UNIQUE,
    telefono_contacto VARCHAR(40),
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS clientes (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    apellido VARCHAR(80) NOT NULL,
    email VARCHAR(150) NOT NULL,
    contrasena_hash VARCHAR(255) NOT NULL,
    direccion_envio VARCHAR(255),
    ciudad VARCHAR(80),
    region VARCHAR(80),
    fecha_nacimiento DATE,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_baja DATETIME NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    total_gastado DECIMAL(14,2) NOT NULL DEFAULT 0,
    ultima_fecha_compra DATETIME NULL,
    nivel_lealtad ENUM('Bronce','Plata','Oro') NOT NULL DEFAULT 'Bronce',
    id_sucursal INT NOT NULL,
    id_cliente_referidor INT NULL,
    UNIQUE KEY uk_cliente_email (email),
    CONSTRAINT fk_cliente_sucursal FOREIGN KEY (id_sucursal) REFERENCES sucursales(id_sucursal),
    CONSTRAINT fk_cliente_referidor FOREIGN KEY (id_cliente_referidor) REFERENCES clientes(id_cliente),
    CONSTRAINT chk_cliente_gasto CHECK (total_gastado >= 0)
);

CREATE TABLE IF NOT EXISTS promociones (
    id_promocion INT AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(40) NOT NULL,
    descripcion VARCHAR(255),
    porcentaje_descuento DECIMAL(5,2) NOT NULL,
    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME NOT NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE KEY uk_promocion_codigo (codigo),
    CONSTRAINT chk_promocion_descuento CHECK (porcentaje_descuento BETWEEN 0 AND 100),
    CONSTRAINT chk_promocion_fechas CHECK (fecha_fin > fecha_inicio)
);

CREATE TABLE IF NOT EXISTS productos (
    id_producto INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(180) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(12,2) NOT NULL,
    costo DECIMAL(12,2) NOT NULL DEFAULT 0,
    stock INT NOT NULL DEFAULT 0,
    stock_minimo INT NOT NULL DEFAULT 5,
    sku VARCHAR(80) NOT NULL,
    peso_kg DECIMAL(8,3) NOT NULL DEFAULT 0.100,
    ubicacion VARCHAR(80) DEFAULT 'Bodega principal',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    id_categoria INT NULL,
    id_proveedor INT NULL,
    UNIQUE KEY uk_producto_nombre (nombre),
    UNIQUE KEY uk_producto_sku (sku),
    KEY idx_producto_categoria (id_categoria),
    KEY idx_producto_proveedor (id_proveedor),
    CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria),
    CONSTRAINT fk_producto_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedores(id_proveedor),
    CONSTRAINT chk_producto_precio CHECK (precio > 0),
    CONSTRAINT chk_producto_costo CHECK (costo >= 0),
    CONSTRAINT chk_producto_stock CHECK (stock >= 0),
    CONSTRAINT chk_producto_stock_minimo CHECK (stock_minimo >= 0),
    CONSTRAINT chk_producto_peso CHECK (peso_kg >= 0)
);

CREATE TABLE IF NOT EXISTS ventas (
    id_venta INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_sucursal INT NOT NULL,
    id_promocion INT NULL,
    fecha_venta DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    direccion_envio VARCHAR(255),
    estado ENUM('Pendiente de Pago','Pagado','Procesando','Enviado','Entregado','Cancelado','Devuelto') NOT NULL DEFAULT 'Pendiente de Pago',
    total DECIMAL(14,2) NOT NULL DEFAULT 0,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_venta_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    CONSTRAINT fk_venta_sucursal FOREIGN KEY (id_sucursal) REFERENCES sucursales(id_sucursal),
    CONSTRAINT fk_venta_promocion FOREIGN KEY (id_promocion) REFERENCES promociones(id_promocion),
    KEY idx_venta_fecha (fecha_venta),
    KEY idx_venta_cliente_fecha (id_cliente, fecha_venta),
    CONSTRAINT chk_venta_total CHECK (total >= 0)
);

CREATE TABLE IF NOT EXISTS detalle_ventas (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL,
    precio_unitario_congelado DECIMAL(12,2) NOT NULL,
    subtotal DECIMAL(14,2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_detalle_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta) ON DELETE CASCADE,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto),
    UNIQUE KEY uk_detalle_venta_producto (id_venta, id_producto),
    CONSTRAINT chk_detalle_cantidad CHECK (cantidad > 0),
    CONSTRAINT chk_detalle_precio CHECK (precio_unitario_congelado > 0)
);

CREATE TABLE IF NOT EXISTS carritos (
    id_carrito INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    estado ENUM('ACTIVO','ABANDONADO','CONVERTIDO','VACIADO') NOT NULL DEFAULT 'ACTIVO',
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_carrito_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
);

CREATE TABLE IF NOT EXISTS carrito_detalles (
    id_carrito INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL,
    PRIMARY KEY (id_carrito, id_producto),
    CONSTRAINT fk_carrito_detalle_carrito FOREIGN KEY (id_carrito) REFERENCES carritos(id_carrito) ON DELETE CASCADE,
    CONSTRAINT fk_carrito_detalle_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto),
    CONSTRAINT chk_carrito_cantidad CHECK (cantidad > 0)
);

CREATE TABLE IF NOT EXISTS vistas_productos (
    id_vista BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    id_cliente INT NULL,
    visto_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_vista_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto),
    CONSTRAINT fk_vista_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
);

CREATE TABLE IF NOT EXISTS resenas (
    id_resena INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    id_cliente INT NOT NULL,
    calificacion TINYINT NOT NULL,
    comentario VARCHAR(500),
    creada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_resena_cliente_producto (id_cliente, id_producto),
    CONSTRAINT fk_resena_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto),
    CONSTRAINT fk_resena_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    CONSTRAINT chk_resena_calificacion CHECK (calificacion BETWEEN 1 AND 5)
);

CREATE TABLE IF NOT EXISTS movimientos_stock (
    id_movimiento BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    tipo ENUM('VENTA','DEVOLUCION','AJUSTE','REABASTECIMIENTO') NOT NULL,
    cantidad INT NOT NULL,
    motivo VARCHAR(255) NOT NULL,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_movimiento_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

CREATE TABLE IF NOT EXISTS creditos_cliente (
    id_credito INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_venta INT NOT NULL,
    monto DECIMAL(14,2) NOT NULL,
    motivo VARCHAR(255) NOT NULL,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_credito_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    CONSTRAINT fk_credito_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta),
    CONSTRAINT chk_credito_monto CHECK (monto > 0)
);

CREATE TABLE IF NOT EXISTS notificaciones (
    id_notificacion BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NULL,
    tipo VARCHAR(80) NOT NULL,
    mensaje VARCHAR(500) NOT NULL,
    creada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    leida BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_notificacion_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
);

CREATE TABLE IF NOT EXISTS auditoria_clientes (
    id_auditoria BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    accion VARCHAR(40) NOT NULL,
    detalle VARCHAR(500),
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS log_cambios_precio (
    id_log BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    precio_anterior DECIMAL(12,2) NOT NULL,
    precio_nuevo DECIMAL(12,2) NOT NULL,
    cambiado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usuario_bd VARCHAR(255) NOT NULL
);

CREATE TABLE IF NOT EXISTS log_cambios_precio_historico (
    id_log BIGINT PRIMARY KEY,
    id_producto INT NOT NULL,
    precio_anterior DECIMAL(12,2) NOT NULL,
    precio_nuevo DECIMAL(12,2) NOT NULL,
    cambiado_en DATETIME NOT NULL,
    usuario_bd VARCHAR(255) NOT NULL
);

CREATE TABLE IF NOT EXISTS log_estados_venta (
    id_log BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT NOT NULL,
    estado_anterior VARCHAR(40) NOT NULL,
    estado_nuevo VARCHAR(40) NOT NULL,
    cambiado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usuario_bd VARCHAR(255) NOT NULL
);

CREATE TABLE IF NOT EXISTS alertas_stock (
    id_alerta BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    stock_actual INT NOT NULL,
    stock_minimo INT NOT NULL,
    creada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atendida BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_alerta_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

CREATE TABLE IF NOT EXISTS ventas_archivadas (
    id_archivo BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT NOT NULL,
    id_cliente INT NOT NULL,
    id_sucursal INT NOT NULL,
    fecha_venta DATETIME NOT NULL,
    estado VARCHAR(40) NOT NULL,
    total DECIMAL(14,2) NOT NULL,
    archivada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cambios_permisos (
    id_cambio BIGINT AUTO_INCREMENT PRIMARY KEY,
    usuario_afectado VARCHAR(255) NOT NULL,
    descripcion VARCHAR(500) NOT NULL,
    realizado_por VARCHAR(255) NOT NULL,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS auditoria_permisos (
    id_auditoria BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_cambio BIGINT NOT NULL,
    usuario_afectado VARCHAR(255) NOT NULL,
    descripcion VARCHAR(500) NOT NULL,
    realizado_por VARCHAR(255) NOT NULL,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS auditoria_login_fallido (
    id_intento BIGINT AUTO_INCREMENT PRIMARY KEY,
    usuario_intentado VARCHAR(255) NOT NULL,
    origen VARCHAR(255),
    motivo VARCHAR(500),
    intentado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reporte_ventas_semanales (
    id_reporte BIGINT AUTO_INCREMENT PRIMARY KEY,
    semana_inicio DATE NOT NULL,
    semana_fin DATE NOT NULL,
    cantidad_ventas INT NOT NULL,
    total_ventas DECIMAL(14,2) NOT NULL,
    generado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_reporte_semana (semana_inicio, semana_fin)
);

CREATE TABLE IF NOT EXISTS listas_reabastecimiento (
    id_lista BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    stock_actual INT NOT NULL,
    stock_minimo INT NOT NULL,
    generada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atendida BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_reabastecimiento_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

CREATE TABLE IF NOT EXISTS resumen_ventas_diarias (
    fecha DATE PRIMARY KEY,
    cantidad_ventas INT NOT NULL,
    total_ventas DECIMAL(14,2) NOT NULL,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS inconsistencias_datos (
    id_inconsistencia BIGINT AUTO_INCREMENT PRIMARY KEY,
    tipo VARCHAR(100) NOT NULL,
    referencia VARCHAR(255) NOT NULL,
    detalle VARCHAR(500) NOT NULL,
    detectada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resuelta BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS cupones_clientes (
    id_cupon BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    codigo VARCHAR(80) NOT NULL,
    motivo VARCHAR(255) NOT NULL,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usado BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE KEY uk_cupon_cliente_codigo (id_cliente, codigo),
    CONSTRAINT fk_cupon_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
);

CREATE TABLE IF NOT EXISTS ranking_productos (
    id_producto INT PRIMARY KEY,
    unidades_vendidas BIGINT NOT NULL,
    ingresos DECIMAL(14,2) NOT NULL,
    posicion INT NOT NULL,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ranking_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

CREATE TABLE IF NOT EXISTS backups_log (
    id_backup BIGINT AUTO_INCREMENT PRIMARY KEY,
    alcance VARCHAR(255) NOT NULL,
    estado VARCHAR(40) NOT NULL,
    detalle VARCHAR(500) NOT NULL,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS kpis_mensuales (
    periodo CHAR(7) PRIMARY KEY,
    ventas INT NOT NULL,
    clientes_nuevos INT NOT NULL,
    ingresos DECIMAL(14,2) NOT NULL,
    ticket_promedio DECIMAL(14,2) NOT NULL,
    calculado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tamanos_bd_log (
    id_log BIGINT AUTO_INCREMENT PRIMARY KEY,
    tamano_mb DECIMAL(14,2) NOT NULL,
    medido_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS actividad_fraudulenta (
    id_alerta BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NULL,
    tipo VARCHAR(100) NOT NULL,
    detalle VARCHAR(500) NOT NULL,
    detectada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_fraude_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
);

CREATE TABLE IF NOT EXISTS reporte_proveedores_mensual (
    periodo CHAR(7) NOT NULL,
    id_proveedor INT NOT NULL,
    unidades_vendidas BIGINT NOT NULL,
    ingresos DECIMAL(14,2) NOT NULL,
    generado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (periodo, id_proveedor),
    CONSTRAINT fk_reporte_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedores(id_proveedor)
);

CREATE TABLE IF NOT EXISTS tmp_eventos_proceso (
    id_tmp BIGINT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT IGNORE INTO sucursales (id_sucursal, nombre, ciudad, region) VALUES
    (1, 'Sucursal Centro', 'Bogotá', 'Cundinamarca'),
    (2, 'Sucursal Norte', 'Medellín', 'Antioquia');

INSERT IGNORE INTO categorias (id_categoria, nombre, descripcion) VALUES
    (1, 'Electrónica', 'Tecnología y accesorios electrónicos.'),
    (2, 'Hogar', 'Artículos útiles para el hogar.'),
    (3, 'Oficina', 'Productos para estudio y trabajo.'),
    (4, 'Ropa', 'Prendas y accesorios.'),
    (5, 'General', 'Categoría predeterminada para productos sin clasificación.');

INSERT IGNORE INTO proveedores (id_proveedor, nombre, email_contacto, telefono_contacto) VALUES
    (1, 'TecnoDistribuciones SAS', 'ventas@tecnodistribuciones.co', '6015551001'),
    (2, 'Hogar y Más Ltda.', 'contacto@hogarymas.co', '6045552002'),
    (3, 'OfiSupply Colombia', 'comercial@ofisupply.co', '6015553003');

INSERT IGNORE INTO clientes
    (id_cliente, nombre, apellido, email, contrasena_hash, direccion_envio, ciudad, region, fecha_nacimiento, fecha_registro, id_sucursal, id_cliente_referidor)
VALUES
    (1, 'Ana', 'García', 'ana.garcia@example.com', SHA2('Ana#2026Segura', 256), 'Cra 10 # 20-30', 'Bogotá', 'Cundinamarca', '1995-04-12', DATE_SUB(NOW(), INTERVAL 380 DAY), 1, NULL),
    (2, 'Carlos', 'Pérez', 'carlos.perez@example.com', SHA2('Carlos#2026Segura', 256), 'Calle 50 # 10-20', 'Medellín', 'Antioquia', '1988-09-21', DATE_SUB(NOW(), INTERVAL 300 DAY), 2, 1),
    (3, 'Luisa', 'Martínez', 'luisa.martinez@example.com', SHA2('Luisa#2026Segura', 256), 'Cra 7 # 80-15', 'Bogotá', 'Cundinamarca', '2001-01-05', DATE_SUB(NOW(), INTERVAL 210 DAY), 1, 1),
    (4, 'Miguel', 'Rodríguez', 'miguel.rodriguez@example.com', SHA2('Miguel#2026Segura', 256), 'Calle 33 # 45-12', 'Cali', 'Valle del Cauca', '1992-06-18', DATE_SUB(NOW(), INTERVAL 120 DAY), 1, NULL),
    (5, 'Sofía', 'López', 'sofia.lopez@example.com', SHA2('Sofia#2026Segura', 256), 'Carrera 43 # 12-18', 'Medellín', 'Antioquia', '1998-11-30', DATE_SUB(NOW(), INTERVAL 45 DAY), 2, 2),
    (6, 'Diego', 'Torres', 'diego.torres@example.com', SHA2('Diego#2026Segura', 256), 'Calle 9 # 4-55', 'Bogotá', 'Cundinamarca', '1985-02-14', DATE_SUB(NOW(), INTERVAL 20 DAY), 1, NULL);

INSERT IGNORE INTO promociones (id_promocion, codigo, descripcion, porcentaje_descuento, fecha_inicio, fecha_fin, activa) VALUES
    (1, 'TECNO10', 'Descuento de tecnología', 10.00, DATE_SUB(NOW(), INTERVAL 90 DAY), DATE_ADD(NOW(), INTERVAL 90 DAY), TRUE),
    (2, 'HOGAR15', 'Promoción de hogar', 15.00, DATE_SUB(NOW(), INTERVAL 180 DAY), DATE_SUB(NOW(), INTERVAL 120 DAY), FALSE);

INSERT IGNORE INTO productos
    (id_producto, nombre, descripcion, precio, costo, stock, stock_minimo, sku, peso_kg, ubicacion, id_categoria, id_proveedor)
VALUES
    (1, 'Portátil básico 14', 'Equipo para estudio y oficina.', 1850000.00, 1400000.00, 8, 3, 'PORTATIL-14', 1.800, 'Estante A1', 1, 1),
    (2, 'Mouse inalámbrico', 'Mouse ergonómico con receptor USB.', 85000.00, 42000.00, 35, 10, 'MOUSE-INAL', 0.120, 'Estante A2', 1, 1),
    (3, 'Teclado mecánico', 'Teclado mecánico compacto.', 240000.00, 130000.00, 14, 5, 'TECLADO-MEC', 0.750, 'Estante A3', 1, 1),
    (4, 'Monitor 24 pulgadas', 'Monitor Full HD para trabajo.', 780000.00, 510000.00, 6, 3, 'MONITOR-24', 3.200, 'Estante A4', 1, 1),
    (5, 'Lámpara de escritorio', 'Lámpara LED regulable.', 120000.00, 65000.00, 18, 5, 'LAMPARA-LED', 0.900, 'Estante B1', 2, 2),
    (6, 'Organizador de cables', 'Accesorio para escritorio.', 35000.00, 12000.00, 50, 12, 'ORGAN-CABLE', 0.080, 'Estante B2', 3, 3),
    (7, 'Silla ergonómica', 'Silla con soporte lumbar.', 950000.00, 650000.00, 4, 2, 'SILLA-ERG', 12.000, 'Estante B3', 2, 2),
    (8, 'Cuaderno universitario', 'Cuaderno de 100 hojas.', 22000.00, 9000.00, 60, 15, 'CUADERNO-UNI', 0.350, 'Estante C1', 3, 3),
    (9, 'Camiseta básica', 'Camiseta de algodón.', 60000.00, 25000.00, 25, 8, 'CAMISETA-BAS', 0.250, 'Estante D1', 4, 2),
    (10, 'Audífonos Bluetooth', 'Audífonos inalámbricos.', 210000.00, 120000.00, 9, 4, 'AUDIF-BT', 0.300, 'Estante A5', 1, 1),
    (11, 'Taza térmica', 'Taza reutilizable para bebidas.', 75000.00, 30000.00, 20, 5, 'TAZA-TERM', 0.400, 'Estante B4', 2, 2),
    (12, 'Agenda semanal', 'Agenda para planificación.', 45000.00, 18000.00, 3, 6, 'AGENDA-SEM', 0.300, 'Estante C2', 3, 3);

INSERT IGNORE INTO ventas
    (id_venta, id_cliente, id_sucursal, id_promocion, fecha_venta, direccion_envio, estado, total)
VALUES
    (1, 1, 1, 1, DATE_SUB(NOW(), INTERVAL 360 DAY), 'Cra 10 # 20-30', 'Entregado', 1935000.00),
    (2, 1, 1, NULL, DATE_SUB(NOW(), INTERVAL 210 DAY), 'Cra 10 # 20-30', 'Entregado', 325000.00),
    (3, 2, 2, NULL, DATE_SUB(NOW(), INTERVAL 160 DAY), 'Calle 50 # 10-20', 'Entregado', 780000.00),
    (4, 2, 2, 2, DATE_SUB(NOW(), INTERVAL 100 DAY), 'Calle 50 # 10-20', 'Entregado', 907500.00),
    (5, 3, 1, 1, DATE_SUB(NOW(), INTERVAL 70 DAY), 'Cra 7 # 80-15', 'Enviado', 240000.00),
    (6, 3, 1, NULL, DATE_SUB(NOW(), INTERVAL 35 DAY), 'Cra 7 # 80-15', 'Procesando', 287000.00),
    (7, 4, 1, NULL, DATE_SUB(NOW(), INTERVAL 12 DAY), 'Calle 33 # 45-12', 'Pagado', 950000.00),
    (8, 5, 2, 1, DATE_SUB(NOW(), INTERVAL 5 DAY), 'Carrera 43 # 12-18', 'Pendiente de Pago', 210000.00),
    (9, 6, 1, NULL, DATE_SUB(NOW(), INTERVAL 2 DAY), 'Calle 9 # 4-55', 'Cancelado', 75000.00);

INSERT IGNORE INTO detalle_ventas (id_detalle, id_venta, id_producto, cantidad, precio_unitario_congelado, subtotal) VALUES
    (1, 1, 1, 1, 1850000.00, 1850000.00), (2, 1, 2, 1, 85000.00, 85000.00),
    (3, 2, 3, 1, 240000.00, 240000.00), (4, 2, 2, 1, 85000.00, 85000.00),
    (5, 3, 4, 1, 780000.00, 780000.00),
    (6, 4, 5, 2, 102000.00, 204000.00), (7, 4, 7, 1, 703500.00, 703500.00),
    (8, 5, 3, 1, 240000.00, 240000.00),
    (9, 6, 2, 2, 85000.00, 170000.00), (10, 6, 10, 1, 117000.00, 117000.00),
    (11, 7, 7, 1, 950000.00, 950000.00),
    (12, 8, 10, 1, 210000.00, 210000.00),
    (13, 9, 11, 1, 75000.00, 75000.00);

INSERT IGNORE INTO carritos (id_carrito, id_cliente, estado, creado_en, actualizado_en) VALUES
    (1, 6, 'ABANDONADO', DATE_SUB(NOW(), INTERVAL 5 DAY), DATE_SUB(NOW(), INTERVAL 4 DAY)),
    (2, 5, 'ACTIVO', DATE_SUB(NOW(), INTERVAL 1 DAY), DATE_SUB(NOW(), INTERVAL 1 HOUR));

INSERT IGNORE INTO carrito_detalles (id_carrito, id_producto, cantidad) VALUES
    (1, 12, 1), (1, 4, 1), (2, 5, 1);

INSERT IGNORE INTO vistas_productos (id_producto, id_cliente, visto_en) VALUES
    (1, 1, DATE_SUB(NOW(), INTERVAL 20 DAY)), (1, 2, DATE_SUB(NOW(), INTERVAL 19 DAY)),
    (2, 1, DATE_SUB(NOW(), INTERVAL 18 DAY)), (2, 3, DATE_SUB(NOW(), INTERVAL 17 DAY)),
    (2, 4, DATE_SUB(NOW(), INTERVAL 16 DAY)), (3, 2, DATE_SUB(NOW(), INTERVAL 15 DAY)),
    (4, 2, DATE_SUB(NOW(), INTERVAL 14 DAY)), (5, 3, DATE_SUB(NOW(), INTERVAL 13 DAY)),
    (10, 5, DATE_SUB(NOW(), INTERVAL 4 DAY));

INSERT IGNORE INTO resenas (id_producto, id_cliente, calificacion, comentario) VALUES
    (1, 1, 5, 'Buen equipo para estudiar.'),
    (4, 2, 4, 'Buena imagen y tamaño.'),
    (3, 3, 5, 'Cómodo para programar.');

UPDATE clientes c
LEFT JOIN (
    SELECT id_cliente, SUM(total) AS gasto, MAX(fecha_venta) AS ultima
    FROM ventas
    WHERE estado <> 'Cancelado'
    GROUP BY id_cliente
) v ON v.id_cliente = c.id_cliente
SET c.total_gastado = COALESCE(v.gasto, 0),
    c.ultima_fecha_compra = v.ultima,
    c.nivel_lealtad = CASE
        WHEN COALESCE(v.gasto, 0) >= 3000000 THEN 'Oro'
        WHEN COALESCE(v.gasto, 0) >= 1000000 THEN 'Plata'
        ELSE 'Bronce'
    END;

UPDATE categorias c
LEFT JOIN (
    SELECT id_categoria, COUNT(*) AS total
    FROM productos
    GROUP BY id_categoria
) p ON p.id_categoria = c.id_categoria
SET c.cantidad_productos = COALESCE(p.total, 0);

-- Consultas rápidas para comprobar que la carga inicial terminó correctamente.
SELECT 'Carga inicial completada' AS mensaje, COUNT(*) AS productos FROM productos;
SELECT 'Ventas cargadas' AS mensaje, COUNT(*) AS ventas, COALESCE(SUM(total), 0) AS ingresos FROM ventas;
