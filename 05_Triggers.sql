USE ecommerce_bd;

/* 10 TRIGGERS */

DROP TRIGGER IF EXISTS trg_check_stock_before_insert_venta;
DROP TRIGGER IF EXISTS trg_update_stock_after_insert_venta;
DROP TRIGGER IF EXISTS trg_update_total_gastado_cliente;
DROP TRIGGER IF EXISTS trg_update_last_order_date_customer;
DROP TRIGGER IF EXISTS trg_prevent_delete_categoria_with_products;
DROP TRIGGER IF EXISTS trg_validate_email_format_on_customer;
DROP TRIGGER IF EXISTS trg_capitalize_nombre_cliente;
DROP TRIGGER IF EXISTS trg_prevent_self_referral;
DROP TRIGGER IF EXISTS trg_validate_email_format_on_customer_update;
DROP TRIGGER IF EXISTS trg_log_new_customer_after_insert;

DELIMITER //

CREATE TRIGGER trg_check_stock_before_insert_venta
BEFORE INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    DECLARE v_stock INT;
    SELECT stock INTO v_stock
    FROM productos
    WHERE id_producto = NEW.id_producto
    FOR UPDATE;
    IF v_stock IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El producto no existe.';
    END IF;
    IF v_stock < NEW.cantidad THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock insuficiente para la línea de venta.';
    END IF;
    SET NEW.subtotal = NEW.cantidad * NEW.precio_unitario_congelado;
END//

CREATE TRIGGER trg_update_stock_after_insert_venta
AFTER INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE productos
    SET stock = stock - NEW.cantidad
    WHERE id_producto = NEW.id_producto;

    UPDATE ventas v
    SET total = (
        SELECT COALESCE(SUM(d.subtotal), 0)
        FROM detalle_ventas d
        WHERE d.id_venta = NEW.id_venta
    ),
    fecha_actualizacion = NOW()
    WHERE v.id_venta = NEW.id_venta;

    INSERT INTO movimientos_stock (id_producto, tipo, cantidad, motivo)
    VALUES (NEW.id_producto, 'VENTA', -NEW.cantidad, CONCAT('Venta #', NEW.id_venta));
END//

CREATE TRIGGER trg_update_total_gastado_cliente
AFTER INSERT ON detalle_ventas
FOR EACH ROW
FOLLOWS trg_update_stock_after_insert_venta
BEGIN
    UPDATE clientes c
    JOIN ventas v ON v.id_cliente = c.id_cliente
    SET c.total_gastado = (
            SELECT COALESCE(SUM(v2.total), 0)
            FROM ventas v2
            WHERE v2.id_cliente = c.id_cliente AND v2.estado <> 'Cancelado'
        )
    WHERE v.id_venta = NEW.id_venta;
END//

CREATE TRIGGER trg_update_last_order_date_customer
AFTER INSERT ON detalle_ventas
FOR EACH ROW
FOLLOWS trg_update_total_gastado_cliente
BEGIN
    UPDATE clientes c
    JOIN ventas v ON v.id_cliente = c.id_cliente
    SET c.ultima_fecha_compra = (
            SELECT MAX(v2.fecha_venta)
            FROM ventas v2
            WHERE v2.id_cliente = c.id_cliente AND v2.estado <> 'Cancelado'
        )
    WHERE v.id_venta = NEW.id_venta;
END//

CREATE TRIGGER trg_prevent_delete_categoria_with_products
BEFORE DELETE ON categorias
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM productos WHERE id_categoria = OLD.id_categoria) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede eliminar una categoría con productos.';
    END IF;
END//

CREATE TRIGGER trg_validate_email_format_on_customer
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    IF NEW.email IS NULL OR NEW.email NOT REGEXP '^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El formato del correo del cliente no es válido.';
    END IF;
END//

CREATE TRIGGER trg_capitalize_nombre_cliente
BEFORE INSERT ON clientes
FOR EACH ROW
FOLLOWS trg_validate_email_format_on_customer
BEGIN
    SET NEW.nombre = CONCAT(UPPER(LEFT(TRIM(NEW.nombre), 1)), LOWER(SUBSTRING(TRIM(NEW.nombre), 2)));
    SET NEW.apellido = CONCAT(UPPER(LEFT(TRIM(NEW.apellido), 1)), LOWER(SUBSTRING(TRIM(NEW.apellido), 2)));
END//

CREATE TRIGGER trg_prevent_self_referral
BEFORE INSERT ON clientes
FOR EACH ROW
FOLLOWS trg_capitalize_nombre_cliente
BEGIN
    IF NEW.id_cliente_referidor IS NOT NULL AND NEW.id_cliente_referidor = NEW.id_cliente THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un cliente no puede referenciarse a sí mismo.';
    END IF;
END//

CREATE TRIGGER trg_validate_email_format_on_customer_update
BEFORE UPDATE ON clientes
FOR EACH ROW
BEGIN
    IF NEW.email IS NULL OR NEW.email NOT REGEXP '^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El formato del correo actualizado no es válido.';
    END IF;
    IF NEW.id_cliente_referidor IS NOT NULL AND NEW.id_cliente_referidor = NEW.id_cliente THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un cliente no puede referenciarse a sí mismo.';
    END IF;
END//

CREATE TRIGGER trg_log_new_customer_after_insert
AFTER INSERT ON clientes
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_clientes (id_cliente, accion, detalle)
    VALUES (NEW.id_cliente, 'INSERT', CONCAT('Cliente creado: ', NEW.email));
END//

DELIMITER ;
