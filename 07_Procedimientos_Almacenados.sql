USE ecommerce_bd;

/* 10 PROCEDIMIENTOS */

DROP PROCEDURE IF EXISTS sp_RealizarNuevaVenta;
DROP PROCEDURE IF EXISTS sp_AgregarNuevoProducto;
DROP PROCEDURE IF EXISTS sp_ActualizarDireccionCliente;
DROP PROCEDURE IF EXISTS sp_ProcesarDevolucion;
DROP PROCEDURE IF EXISTS sp_ObtenerHistorialComprasCliente;
DROP PROCEDURE IF EXISTS sp_AjustarNivelStock;
DROP PROCEDURE IF EXISTS sp_EliminarClienteDeFormaSegura;
DROP PROCEDURE IF EXISTS sp_AplicarDescuentoPorCategoria;
DROP PROCEDURE IF EXISTS sp_GenerarReporteMensualVentas;
DROP PROCEDURE IF EXISTS sp_CambiarEstadoPedido;

DELIMITER //

CREATE PROCEDURE sp_RealizarNuevaVenta(
    IN p_id_cliente INT,
    IN p_id_sucursal INT,
    IN p_id_producto INT,
    IN p_cantidad INT,
    OUT p_id_venta INT
)
BEGIN
    DECLARE v_direccion VARCHAR(255);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT direccion_envio INTO v_direccion FROM clientes WHERE id_cliente = p_id_cliente AND activo = TRUE;
    IF v_direccion IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente no existe o está inactivo.';
    END IF;
    INSERT INTO ventas (id_cliente, id_sucursal, direccion_envio, estado)
    VALUES (p_id_cliente, p_id_sucursal, v_direccion, 'Pendiente de Pago');
    SET p_id_venta = LAST_INSERT_ID();
    INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario_congelado)
    VALUES (p_id_venta, p_id_producto, p_cantidad, fn_ObtenerPrecioProducto(p_id_producto));
    UPDATE ventas SET total = fn_CalcularTotalVenta(p_id_venta) WHERE id_venta = p_id_venta;
    COMMIT;
END//

CREATE PROCEDURE sp_AgregarNuevoProducto(
    IN p_nombre VARCHAR(180),
    IN p_descripcion TEXT,
    IN p_precio DECIMAL(12,2),
    IN p_costo DECIMAL(12,2),
    IN p_stock INT,
    IN p_stock_minimo INT,
    IN p_sku VARCHAR(80),
    IN p_peso_kg DECIMAL(8,3),
    IN p_id_categoria INT,
    IN p_id_proveedor INT,
    OUT p_id_producto INT
)
BEGIN
    DECLARE v_sku VARCHAR(80);
    SET v_sku = COALESCE(NULLIF(TRIM(p_sku), ''), CONCAT(UPPER(LEFT(REPLACE(TRIM(p_nombre), ' ', ''), 6)), '-', p_id_categoria, '-', UNIX_TIMESTAMP()));
    INSERT INTO productos (nombre, descripcion, precio, costo, stock, stock_minimo, sku, peso_kg, id_categoria, id_proveedor)
    VALUES (p_nombre, p_descripcion, p_precio, p_costo, p_stock, p_stock_minimo, v_sku, p_peso_kg, p_id_categoria, p_id_proveedor);
    SET p_id_producto = LAST_INSERT_ID();
END//

CREATE PROCEDURE sp_ActualizarDireccionCliente(
    IN p_id_cliente INT,
    IN p_nueva_direccion VARCHAR(255)
)
BEGIN
    UPDATE clientes SET direccion_envio = p_nueva_direccion WHERE id_cliente = p_id_cliente;
    UPDATE ventas
    SET direccion_envio = p_nueva_direccion, fecha_actualizacion = NOW()
    WHERE id_cliente = p_id_cliente
      AND estado IN ('Pendiente de Pago', 'Pagado', 'Procesando');
END//

CREATE PROCEDURE sp_ProcesarDevolucion(
    IN p_id_venta INT,
    IN p_motivo VARCHAR(255)
)
BEGIN
    DECLARE v_id_cliente INT;
    DECLARE v_total DECIMAL(14,2);
    DECLARE v_estado VARCHAR(40);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT id_cliente, total, estado INTO v_id_cliente, v_total, v_estado FROM ventas WHERE id_venta = p_id_venta FOR UPDATE;
    IF v_id_cliente IS NULL OR v_estado IN ('Cancelado', 'Devuelto') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La venta no puede procesarse como devolución.';
    END IF;
    UPDATE productos p
    JOIN detalle_ventas d ON d.id_producto = p.id_producto
    SET p.stock = p.stock + d.cantidad
    WHERE d.id_venta = p_id_venta;
    INSERT INTO movimientos_stock (id_producto, tipo, cantidad, motivo)
    SELECT id_producto, 'DEVOLUCION', cantidad, CONCAT('Devolución venta #', p_id_venta, ': ', p_motivo)
    FROM detalle_ventas WHERE id_venta = p_id_venta;
    UPDATE ventas SET estado = 'Devuelto', fecha_actualizacion = NOW() WHERE id_venta = p_id_venta;
    INSERT INTO creditos_cliente (id_cliente, id_venta, monto, motivo)
    VALUES (v_id_cliente, p_id_venta, v_total, p_motivo);
    COMMIT;
END//

CREATE PROCEDURE sp_ObtenerHistorialComprasCliente(IN p_id_cliente INT)
BEGIN
    SELECT v.id_venta, v.fecha_venta, v.estado, v.total, v.direccion_envio,
           p.nombre AS producto, d.cantidad, d.precio_unitario_congelado, d.subtotal
    FROM ventas v
    JOIN detalle_ventas d ON d.id_venta = v.id_venta
    JOIN productos p ON p.id_producto = d.id_producto
    WHERE v.id_cliente = p_id_cliente
    ORDER BY v.fecha_venta DESC, v.id_venta DESC;
END//

CREATE PROCEDURE sp_AjustarNivelStock(
    IN p_id_producto INT,
    IN p_nuevo_stock INT,
    IN p_motivo VARCHAR(255)
)
BEGIN
    DECLARE v_stock_actual INT;
    DECLARE v_diferencia INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT stock INTO v_stock_actual FROM productos WHERE id_producto = p_id_producto FOR UPDATE;
    IF v_stock_actual IS NULL OR p_nuevo_stock < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Producto inexistente o stock inválido.';
    END IF;
    SET v_diferencia = p_nuevo_stock - v_stock_actual;
    UPDATE productos SET stock = p_nuevo_stock WHERE id_producto = p_id_producto;
    INSERT INTO movimientos_stock (id_producto, tipo, cantidad, motivo)
    VALUES (p_id_producto, 'AJUSTE', v_diferencia, p_motivo);
    COMMIT;
END//

CREATE PROCEDURE sp_EliminarClienteDeFormaSegura(IN p_id_cliente INT)
BEGIN
    UPDATE clientes
    SET nombre = 'Cliente',
        apellido = 'Anonimizado',
        email = CONCAT('anonimo.', id_cliente, '@invalid.local'),
        contrasena_hash = SHA2(CONCAT('anonimo-', id_cliente), 256),
        direccion_envio = NULL,
        activo = FALSE,
        fecha_baja = NOW()
    WHERE id_cliente = p_id_cliente;
END//

CREATE PROCEDURE sp_AplicarDescuentoPorCategoria(
    IN p_id_categoria INT,
    IN p_porcentaje DECIMAL(5,2)
)
BEGIN
    IF p_porcentaje < 0 OR p_porcentaje > 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El descuento debe estar entre 0 y 100.';
    END IF;
    UPDATE productos
    SET precio = fn_AplicarDescuento(precio, p_porcentaje)
    WHERE id_categoria = p_id_categoria AND activo = TRUE;
END//

CREATE PROCEDURE sp_GenerarReporteMensualVentas(IN p_anio INT, IN p_mes INT)
BEGIN
    SELECT DATE_FORMAT(v.fecha_venta, '%Y-%m') AS periodo,
           COUNT(DISTINCT v.id_venta) AS cantidad_ventas,
           SUM(v.total) AS ingresos,
           AVG(v.total) AS ticket_promedio
    FROM ventas v
    WHERE YEAR(v.fecha_venta) = p_anio
      AND MONTH(v.fecha_venta) = p_mes
      AND v.estado <> 'Cancelado'
    GROUP BY DATE_FORMAT(v.fecha_venta, '%Y-%m');
END//

CREATE PROCEDURE sp_CambiarEstadoPedido(IN p_id_venta INT, IN p_nuevo_estado VARCHAR(40))
BEGIN
    IF p_nuevo_estado NOT IN ('Pendiente de Pago','Pagado','Procesando','Enviado','Entregado','Cancelado','Devuelto') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Estado de pedido no permitido.';
    END IF;
    UPDATE ventas SET estado = p_nuevo_estado, fecha_actualizacion = NOW() WHERE id_venta = p_id_venta;
END//

DELIMITER ;
