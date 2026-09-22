USE ecommerce_bd;

/* 10 EVENTOS */

SET GLOBAL event_scheduler = ON;

DROP EVENT IF EXISTS evt_generate_weekly_sales_report;
DROP EVENT IF EXISTS evt_cleanup_temp_tables_daily;
DROP EVENT IF EXISTS evt_archive_old_logs_monthly;
DROP EVENT IF EXISTS evt_deactivate_expired_promotions_hourly;
DROP EVENT IF EXISTS evt_recalculate_customer_loyalty_tiers_nightly;
DROP EVENT IF EXISTS evt_generate_reorder_list_daily;
DROP EVENT IF EXISTS evt_rebuild_indexes_weekly;
DROP EVENT IF EXISTS evt_suspend_inactive_accounts_quarterly;
DROP EVENT IF EXISTS evt_aggregate_daily_sales_data;
DROP EVENT IF EXISTS evt_check_data_consistency_nightly;

DELIMITER //

CREATE EVENT evt_generate_weekly_sales_report
ON SCHEDULE EVERY 1 WEEK STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE ENABLE
DO
BEGIN
    INSERT INTO reporte_ventas_semanales (semana_inicio, semana_fin, cantidad_ventas, total_ventas)
    SELECT DATE_SUB(DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY), INTERVAL 7 DAY),
           DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY),
           COUNT(*), COALESCE(SUM(total), 0)
    FROM ventas
    WHERE fecha_venta >= DATE_SUB(DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY), INTERVAL 7 DAY)
      AND fecha_venta < DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY)
      AND estado <> 'Cancelado'
    ON DUPLICATE KEY UPDATE cantidad_ventas = VALUES(cantidad_ventas),
                            total_ventas = VALUES(total_ventas),
                            generado_en = NOW();
END//

CREATE EVENT evt_cleanup_temp_tables_daily
ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE ENABLE
DO
    DELETE FROM tmp_eventos_proceso WHERE creado_en < DATE_SUB(NOW(), INTERVAL 1 DAY)//

CREATE EVENT evt_archive_old_logs_monthly
ON SCHEDULE EVERY 1 MONTH STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE ENABLE
DO
BEGIN
    INSERT IGNORE INTO log_cambios_precio_historico
        (id_log, id_producto, precio_anterior, precio_nuevo, cambiado_en, usuario_bd)
    SELECT id_log, id_producto, precio_anterior, precio_nuevo, cambiado_en, usuario_bd
    FROM log_cambios_precio
    WHERE cambiado_en < DATE_SUB(NOW(), INTERVAL 6 MONTH);
    DELETE FROM log_cambios_precio WHERE cambiado_en < DATE_SUB(NOW(), INTERVAL 6 MONTH);
END//

CREATE EVENT evt_deactivate_expired_promotions_hourly
ON SCHEDULE EVERY 1 HOUR STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE ENABLE
DO
    UPDATE promociones SET activa = FALSE
    WHERE activa = TRUE AND fecha_fin < NOW()//

CREATE EVENT evt_recalculate_customer_loyalty_tiers_nightly
ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE ENABLE
DO
    UPDATE clientes
    SET nivel_lealtad = CASE
        WHEN total_gastado >= 3000000 THEN 'Oro'
        WHEN total_gastado >= 1000000 THEN 'Plata'
        ELSE 'Bronce'
    END//

CREATE EVENT evt_generate_reorder_list_daily
ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE ENABLE
DO
BEGIN
    DELETE FROM listas_reabastecimiento WHERE atendida = FALSE;
    INSERT INTO listas_reabastecimiento (id_producto, stock_actual, stock_minimo)
    SELECT id_producto, stock, stock_minimo
    FROM productos
    WHERE activo = TRUE AND stock < stock_minimo;
END//

CREATE EVENT evt_rebuild_indexes_weekly
ON SCHEDULE EVERY 1 WEEK STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE ENABLE
DO
    INSERT INTO backups_log (alcance, estado, detalle)
    VALUES ('Índices de tablas operativas', 'REGISTRADO',
            'La reconstrucción física debe ejecutarse en una ventana de mantenimiento con OPTIMIZE TABLE.')//

CREATE EVENT evt_suspend_inactive_accounts_quarterly
ON SCHEDULE EVERY 3 MONTH STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE ENABLE
DO
    UPDATE clientes
    SET activo = FALSE, fecha_baja = NOW()
    WHERE activo = TRUE
      AND COALESCE(ultima_fecha_compra, fecha_registro) < DATE_SUB(NOW(), INTERVAL 1 YEAR)//

CREATE EVENT evt_aggregate_daily_sales_data
ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE ENABLE
DO
    INSERT INTO resumen_ventas_diarias (fecha, cantidad_ventas, total_ventas, actualizado_en)
    SELECT DATE_SUB(CURDATE(), INTERVAL 1 DAY), COUNT(*), COALESCE(SUM(total), 0), NOW()
    FROM ventas
    WHERE DATE(fecha_venta) = DATE_SUB(CURDATE(), INTERVAL 1 DAY)
      AND estado <> 'Cancelado'
    ON DUPLICATE KEY UPDATE cantidad_ventas = VALUES(cantidad_ventas),
                            total_ventas = VALUES(total_ventas),
                            actualizado_en = NOW()//

CREATE EVENT evt_check_data_consistency_nightly
ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE ENABLE
DO
    INSERT INTO inconsistencias_datos (tipo, referencia, detalle)
    SELECT 'VENTA_SIN_DETALLE', CAST(v.id_venta AS CHAR), 'Venta sin líneas de detalle'
    FROM ventas v
    WHERE NOT EXISTS (SELECT 1 FROM detalle_ventas d WHERE d.id_venta = v.id_venta)
      AND NOT EXISTS (
          SELECT 1 FROM inconsistencias_datos i
          WHERE i.tipo = 'VENTA_SIN_DETALLE' AND i.referencia = CAST(v.id_venta AS CHAR) AND i.resuelta = FALSE
      )//

DELIMITER ;
