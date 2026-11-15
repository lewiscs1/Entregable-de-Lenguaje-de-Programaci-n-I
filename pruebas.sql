USE TechSolutions;
GO
-- ===== 1. Hash con sal: las contraseñas NO se guardan =====
SELECT Login, Rol, Sal, ClaveHash, IntentosFallidos, Bloqueado FROM dbo.Usuario;
-- Si dos usuarios tienen la misma contraseña, su ClaveHash es distinto porque su Sal es distinta.
GO
-- ===== 2. Inyección SQL: consulta concatenada (MAL) vs. parametrizada (BIEN) =====
DECLARE @login VARCHAR(30) = ''' OR 1=1 --';     -- lo que escribe el atacante en "Usuario"

-- MAL: se arma el texto de la consulta pegando lo que escribió el usuario
DECLARE @sql NVARCHAR(400) = N'SELECT Login, Rol FROM dbo.Usuario WHERE Login = ''' + @login + N'''';
PRINT @sql;          -- la consulta que llega:  ... WHERE Login = '' OR 1=1 --'
EXEC (@sql);         -- resultado: TODOS los usuarios (OR 1=1 siempre es verdadero; -- comenta el resto)

-- BIEN: el valor viaja como parámetro, con el mismo tipo que la columna (VARCHAR(30))
EXEC sp_executesql N'SELECT Login, Rol FROM dbo.Usuario WHERE Login = @l',
                   N'@l VARCHAR(30)', @l = @login;   -- resultado: ninguna fila
GO
-- ===== 3. Niveles de acceso: usuarios por rol =====
SELECT Rol, COUNT(*) AS Usuarios FROM dbo.Usuario GROUP BY Rol;
GO
-- ===== 4. Desbloquear una cuenta (tras 3 intentos fallidos) =====
-- UPDATE dbo.Usuario SET IntentosFallidos = 0, Bloqueado = 0 WHERE Login = 'vend1';
GO
-- ===== 5. Reiniciar (la aplicación volverá a pedir el primer Administrador) =====
-- DELETE FROM dbo.Usuario;
GO
-- ===== 6. Transacción ACID: sp_RegistrarVentaConStock (requiere al menos 1 usuario creado desde la aplicación) =====
-- 6.a) Venta correcta: se registra la venta y se descuenta el stock (COMMIT)
SELECT Nombre, Stock FROM dbo.Producto;                          -- stock ANTES
DECLARE @idUsuario INT = (SELECT TOP 1 IdUsuario FROM dbo.Usuario ORDER BY IdUsuario);
DECLARE @idCliente INT = (SELECT TOP 1 IdCliente FROM dbo.Cliente ORDER BY IdCliente);
DECLARE @idVenta INT;
DECLARE @det dbo.TipoDetalleVenta;
INSERT INTO @det (IdProducto, Cantidad)
SELECT IdProducto, 2 FROM dbo.Producto WHERE Nombre = 'Laptop Core i5';
INSERT INTO @det (IdProducto, Cantidad)
SELECT IdProducto, 3 FROM dbo.Producto WHERE Nombre = 'Mouse inalámbrico';
EXEC dbo.sp_RegistrarVentaConStock @IdUsuario = @idUsuario, @IdCliente = @idCliente, @Detalle = @det, @IdVenta = @idVenta OUTPUT;
SELECT @idVenta AS IdVentaGenerada;
SELECT Nombre, Stock FROM dbo.Producto;                          -- stock DESPUÉS (2 laptops y 3 mouse menos)
SELECT v.IdVenta, v.Fecha, u.Login AS Vendedor, c.Nombres AS Cliente, v.Total
  FROM dbo.Venta v JOIN dbo.Usuario u ON u.IdUsuario = v.IdUsuario JOIN dbo.Cliente c ON c.IdCliente = v.IdCliente;
SELECT * FROM dbo.DetalleVenta;
GO
-- 6.b) Venta con falla: el Mouse alcanza pero el Teclado NO (stock 5, se piden 999) -> ROLLBACK total
DECLARE @idUsuario INT = (SELECT TOP 1 IdUsuario FROM dbo.Usuario ORDER BY IdUsuario);
DECLARE @idCliente INT = (SELECT TOP 1 IdCliente FROM dbo.Cliente ORDER BY IdCliente);
DECLARE @idVenta INT;
DECLARE @det dbo.TipoDetalleVenta;
INSERT INTO @det (IdProducto, Cantidad)
SELECT IdProducto, 1 FROM dbo.Producto WHERE Nombre = 'Mouse inalámbrico';
INSERT INTO @det (IdProducto, Cantidad)
SELECT IdProducto, 999 FROM dbo.Producto WHERE Nombre = 'Teclado mecánico';
BEGIN TRY
    EXEC dbo.sp_RegistrarVentaConStock @IdUsuario = @idUsuario, @IdCliente = @idCliente, @Detalle = @det, @IdVenta = @idVenta OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Numero, ERROR_MESSAGE() AS Mensaje;   -- 50003: stock insuficiente
END CATCH
SELECT Nombre, Stock FROM dbo.Producto;                          -- el Mouse NO bajó: se revirtió todo
SELECT COUNT(*) AS VentasRegistradas FROM dbo.Venta;             -- no aumentó
SELECT @@TRANCOUNT AS TransaccionesAbiertas;                     -- debe ser 0
GO
