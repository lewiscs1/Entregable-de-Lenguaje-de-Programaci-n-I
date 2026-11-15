USE TechSolutions;
GO
-- ===== Procedimientos almacenados para los reportes (Semana 11 · Sesión 1) =====

-- 1) Reporte de clientes. @Nombre = '' -> todos
CREATE OR ALTER PROCEDURE dbo.usp_ReporteClientes
    @Nombre VARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Dni, Nombres, ISNULL(Telefono, '') AS Telefono
    FROM dbo.Cliente
    WHERE Nombres LIKE '%' + @Nombre + '%'
    ORDER BY Nombres;
END
GO

-- 2) Reporte de productos (inventario). @Nombre = '' -> todos
CREATE OR ALTER PROCEDURE dbo.usp_ReporteProductos
    @Nombre VARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Nombre, Stock, PrecioUnitario
    FROM dbo.Producto
    WHERE Nombre LIKE '%' + @Nombre + '%'
    ORDER BY Nombre;
END
GO

-- 3) Reporte de ventas entre dos fechas (incluye el día @Hasta completo)
CREATE OR ALTER PROCEDURE dbo.usp_ReporteVentas
    @Desde DATE,
    @Hasta DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.IdVenta,
           v.Fecha,
           c.Nombres AS Cliente,
           u.Login   AS Vendedor,
           v.Total
    FROM dbo.Venta AS v
    INNER JOIN dbo.Cliente AS c ON c.IdCliente = v.IdCliente
    INNER JOIN dbo.Usuario AS u ON u.IdUsuario = v.IdUsuario
    WHERE v.Fecha >= @Desde
      AND v.Fecha <  DATEADD(DAY, 1, CAST(@Hasta AS DATETIME2(0)))
    ORDER BY v.Fecha, v.IdVenta;
END
GO

-- Pruebas en SSMS
EXEC dbo.usp_ReporteClientes;                         -- todos los clientes
EXEC dbo.usp_ReporteClientes @Nombre = 'car';         -- Carlos y Carmen (si existen)
EXEC dbo.usp_ReporteProductos;                        -- todos los productos
EXEC dbo.usp_ReporteVentas @Desde = '2026-01-01', @Hasta = '2026-12-31';
GO
