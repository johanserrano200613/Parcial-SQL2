USE ecommerce_bd;

/* 10 CONSULTAS AVANZADAS */

-- 1. Top 10 productos que han generado más ingresos.
SELECT p.id_producto, p.nombre,
       SUM(d.cantidad) AS unidades_vendidas,
       SUM(d.subtotal) AS ingresos
FROM productos p
JOIN detalle_ventas d ON d.id_producto = p.id_producto
JOIN ventas v ON v.id_venta = d.id_venta
WHERE v.estado <> 'Cancelado'
GROUP BY p.id_producto, p.nombre
ORDER BY ingresos DESC
LIMIT 10;

-- 2. Productos ubicados en el 10% inferior de ingresos.
WITH ingresos_producto AS (
    SELECT p.id_producto, p.nombre, COALESCE(SUM(CASE WHEN v.estado <> 'Cancelado' THEN d.subtotal ELSE 0 END), 0) AS ingresos
    FROM productos p
    LEFT JOIN detalle_ventas d ON d.id_producto = p.id_producto
    LEFT JOIN ventas v ON v.id_venta = d.id_venta
    GROUP BY p.id_producto, p.nombre
), ranking AS (
    SELECT ingresos_producto.*, CUME_DIST() OVER (ORDER BY ingresos ASC) AS percentil_acumulado
    FROM ingresos_producto
)
SELECT id_producto, nombre, ingresos, ROUND(percentil_acumulado * 100, 2) AS percentil
FROM ranking
WHERE percentil_acumulado <= 0.10
ORDER BY ingresos;

-- 3. Los 5 clientes con mayor valor de vida (LTV).
SELECT c.id_cliente, CONCAT(c.nombre, ' ', c.apellido) AS cliente,
       COUNT(v.id_venta) AS compras,
       COALESCE(SUM(CASE WHEN v.estado <> 'Cancelado' THEN v.total ELSE 0 END), 0) AS ltv
FROM clientes c
LEFT JOIN ventas v ON v.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombre, c.apellido
ORDER BY ltv DESC
LIMIT 5;

-- 4. Ventas totales agrupadas por mes y año.
SELECT YEAR(fecha_venta) AS anio, MONTH(fecha_venta) AS mes,
       COUNT(*) AS cantidad_ventas, SUM(total) AS total_ventas
FROM ventas
WHERE estado <> 'Cancelado'
GROUP BY YEAR(fecha_venta), MONTH(fecha_venta)
ORDER BY anio, mes;

-- 5. Nuevos clientes registrados por trimestre.
SELECT YEAR(fecha_registro) AS anio,
       QUARTER(fecha_registro) AS trimestre,
       COUNT(*) AS clientes_nuevos
FROM clientes
GROUP BY YEAR(fecha_registro), QUARTER(fecha_registro)
ORDER BY anio, trimestre;

-- 6. Porcentaje de clientes que han comprado más de una vez.
WITH compras_cliente AS (
    SELECT c.id_cliente, COUNT(v.id_venta) AS compras
    FROM clientes c
    LEFT JOIN ventas v ON v.id_cliente = c.id_cliente AND v.estado <> 'Cancelado'
    GROUP BY c.id_cliente
)
SELECT ROUND(100 * SUM(compras > 1) / NULLIF(COUNT(*), 0), 2) AS porcentaje_compra_repetida,
       SUM(compras > 1) AS clientes_recurrentes,
       COUNT(*) AS clientes_totales
FROM compras_cliente;

-- 7. Pares de productos comprados frecuentemente en la misma venta.
SELECT p1.nombre AS producto_a, p2.nombre AS producto_b,
       COUNT(*) AS compras_juntos
FROM detalle_ventas d1
JOIN detalle_ventas d2 ON d2.id_venta = d1.id_venta AND d2.id_producto > d1.id_producto
JOIN ventas v ON v.id_venta = d1.id_venta AND v.estado <> 'Cancelado'
JOIN productos p1 ON p1.id_producto = d1.id_producto
JOIN productos p2 ON p2.id_producto = d2.id_producto
GROUP BY p1.id_producto, p1.nombre, p2.id_producto, p2.nombre
ORDER BY compras_juntos DESC, producto_a, producto_b;

-- 8. Rotación de inventario aproximada por categoría.
WITH ventas_por_producto AS (
    SELECT d.id_producto,
           SUM(CASE WHEN v.estado <> 'Cancelado' THEN d.cantidad ELSE 0 END) AS unidades_vendidas
    FROM detalle_ventas d
    JOIN ventas v ON v.id_venta = d.id_venta
    GROUP BY d.id_producto
)
SELECT c.nombre AS categoria,
       COALESCE(SUM(vpp.unidades_vendidas), 0) AS unidades_vendidas,
       SUM(p.stock) AS stock_actual,
       ROUND(COALESCE(SUM(vpp.unidades_vendidas), 0) /
             NULLIF(SUM(p.stock) + COALESCE(SUM(vpp.unidades_vendidas), 0), 0), 4) AS tasa_rotacion
FROM categorias c
JOIN productos p ON p.id_categoria = c.id_categoria
LEFT JOIN ventas_por_producto vpp ON vpp.id_producto = p.id_producto
GROUP BY c.id_categoria, c.nombre
ORDER BY tasa_rotacion DESC;

-- 9. Productos cuyo stock está debajo del umbral mínimo.
SELECT id_producto, nombre, stock, stock_minimo, ubicacion
FROM productos
WHERE stock < stock_minimo AND activo = TRUE
ORDER BY stock ASC, nombre;

-- 10. Clientes con carritos abandonados en los últimos 30 días.
SELECT c.id_cliente, CONCAT(c.nombre, ' ', c.apellido) AS cliente,
       ca.id_carrito, ca.actualizado_en,
       COUNT(cd.id_producto) AS productos_en_carrito
FROM carritos ca
JOIN clientes c ON c.id_cliente = ca.id_cliente
LEFT JOIN carrito_detalles cd ON cd.id_carrito = ca.id_carrito
WHERE ca.estado = 'ABANDONADO'
  AND ca.actualizado_en >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY c.id_cliente, c.nombre, c.apellido, ca.id_carrito, ca.actualizado_en
ORDER BY ca.actualizado_en DESC;
