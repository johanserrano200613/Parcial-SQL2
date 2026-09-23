USE ecommerce_bd;

-- Se añade el campo solicitado para guardar la fecha de la última compra del cliente.
ALTER TABLE clientes
ADD COLUMN fecha_ultima_compra DATETIME NULL;

-- El campo activo ya existe en el proyecto base y se mantiene como booleano con valor verdadero por defecto.
ALTER TABLE clientes
MODIFY COLUMN activo BOOLEAN NOT NULL DEFAULT TRUE;

-- Se copian las fechas existentes para que los clientes actuales conserven su última compra registrada.
UPDATE clientes
SET fecha_ultima_compra = ultima_fecha_compra;

-- Se elimina el trigger si ya existe para permitir volver a ejecutar este script.
DROP TRIGGER IF EXISTS trg_actualizar_fecha_ultima_compra;

DELIMITER //

-- Cada vez que se agrega un producto a una venta, se actualiza la fecha de la última compra del cliente.
CREATE TRIGGER trg_actualizar_fecha_ultima_compra
AFTER INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE clientes c
    JOIN ventas v ON v.id_cliente = c.id_cliente
    SET c.fecha_ultima_compra = (
        SELECT MAX(v2.fecha_venta)
        FROM ventas v2
        WHERE v2.id_cliente = c.id_cliente
          AND v2.estado <> 'Cancelado'
    )
    WHERE v.id_venta = NEW.id_venta;
END//

DELIMITER ;

-- Se activa el planificador de eventos de MySQL para permitir la ejecución automática del evento.
SET GLOBAL event_scheduler = ON;

-- Se elimina el evento si ya existe para permitir volver a ejecutar este script.
DROP EVENT IF EXISTS evt_desactivar_cuentas_inactivas;

DELIMITER //

-- El evento inicia un mes después de su creación y luego se ejecuta una vez al mes.
-- Si el cliente nunca ha comprado, se toma su fecha de registro para comprobar si lleva más de dos años inactivo.
CREATE EVENT evt_desactivar_cuentas_inactivas
ON SCHEDULE EVERY 1 MONTH
STARTS CURRENT_TIMESTAMP + INTERVAL 1 MONTH
ON COMPLETION PRESERVE ENABLE
DO
BEGIN
    UPDATE clientes
    SET activo = FALSE
    WHERE activo = TRUE
      AND COALESCE(fecha_ultima_compra, fecha_registro) < DATE_SUB(NOW(), INTERVAL 2 YEAR);
END//

DELIMITER ;

-- El evento puede deshabilitarse temporalmente si se necesita detener su ejecución.
-- ALTER EVENT evt_desactivar_cuentas_inactivas DISABLE;

-- El evento puede habilitarse nuevamente cuando se requiera continuar con la ejecución mensual.
-- ALTER EVENT evt_desactivar_cuentas_inactivas ENABLE;
