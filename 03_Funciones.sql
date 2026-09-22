USE ecommerce_bd;

/* 10 FUNCIONES */

DELIMITER //

DROP FUNCTION IF EXISTS fn_CalcularTotalVenta//

CREATE FUNCTION fn_CalcularTotalVenta(p_id_venta INT)
RETURNS DECIMAL(14,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(14,2);
    SELECT COALESCE(SUM(subtotal), 0) INTO v_total
    FROM detalle_ventas
    WHERE id_venta = p_id_venta;
    RETURN v_total;
END//

DROP FUNCTION IF EXISTS fn_VerificarDisponibilidadStock//

CREATE FUNCTION fn_VerificarDisponibilidadStock(p_id_producto INT, p_cantidad INT)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_stock INT DEFAULT 0;
    SELECT stock INTO v_stock FROM productos WHERE id_producto = p_id_producto;
    RETURN IFNULL(v_stock >= p_cantidad, FALSE);
END//

DROP FUNCTION IF EXISTS fn_ObtenerPrecioProducto//

CREATE FUNCTION fn_ObtenerPrecioProducto(p_id_producto INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_precio DECIMAL(12,2);
    SELECT precio INTO v_precio FROM productos WHERE id_producto = p_id_producto AND activo = TRUE;
    RETURN v_precio;
END//

DROP FUNCTION IF EXISTS fn_CalcularEdadCliente//

CREATE FUNCTION fn_CalcularEdadCliente(p_fecha_nacimiento DATE)
RETURNS INT
DETERMINISTIC
BEGIN
    IF p_fecha_nacimiento IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN TIMESTAMPDIFF(YEAR, p_fecha_nacimiento, CURDATE());
END//

DROP FUNCTION IF EXISTS fn_FormatearNombreCompleto//

CREATE FUNCTION fn_FormatearNombreCompleto(p_nombre VARCHAR(80), p_apellido VARCHAR(80))
RETURNS VARCHAR(170)
DETERMINISTIC
BEGIN
    RETURN CONCAT(
        UPPER(LEFT(TRIM(p_nombre), 1)), LOWER(SUBSTRING(TRIM(p_nombre), 2)),
        ' ',
        UPPER(LEFT(TRIM(p_apellido), 1)), LOWER(SUBSTRING(TRIM(p_apellido), 2))
    );
END//

DROP FUNCTION IF EXISTS fn_EsClienteNuevo//

CREATE FUNCTION fn_EsClienteNuevo(p_id_cliente INT)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_primera_compra DATETIME;
    SELECT MIN(fecha_venta) INTO v_primera_compra
    FROM ventas
    WHERE id_cliente = p_id_cliente AND estado <> 'Cancelado';
    RETURN IF(v_primera_compra IS NOT NULL AND v_primera_compra >= DATE_SUB(NOW(), INTERVAL 30 DAY), TRUE, FALSE);
END//

DROP FUNCTION IF EXISTS fn_CalcularCostoEnvio//

CREATE FUNCTION fn_CalcularCostoEnvio(p_id_venta INT)
RETURNS DECIMAL(14,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_peso DECIMAL(14,3) DEFAULT 0;
    SELECT COALESCE(SUM(d.cantidad * p.peso_kg), 0) INTO v_peso
    FROM detalle_ventas d
    JOIN productos p ON p.id_producto = d.id_producto
    WHERE d.id_venta = p_id_venta;
    RETURN ROUND(10000 + (v_peso * 5000), 2);
END//

DROP FUNCTION IF EXISTS fn_AplicarDescuento//

CREATE FUNCTION fn_AplicarDescuento(p_monto DECIMAL(14,2), p_porcentaje DECIMAL(5,2))
RETURNS DECIMAL(14,2)
DETERMINISTIC
BEGIN
    RETURN ROUND(p_monto * (1 - LEAST(GREATEST(p_porcentaje, 0), 100) / 100), 2);
END//

DROP FUNCTION IF EXISTS fn_ObtenerUltimaFechaCompra//

CREATE FUNCTION fn_ObtenerUltimaFechaCompra(p_id_cliente INT)
RETURNS DATETIME
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_fecha DATETIME;
    SELECT MAX(fecha_venta) INTO v_fecha
    FROM ventas
    WHERE id_cliente = p_id_cliente AND estado <> 'Cancelado';
    RETURN v_fecha;
END//

DROP FUNCTION IF EXISTS fn_ValidarFormatoEmail//

CREATE FUNCTION fn_ValidarFormatoEmail(p_email VARCHAR(150))
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    RETURN IF(COALESCE(p_email, '') REGEXP '^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$', TRUE, FALSE);
END//

DELIMITER ;
