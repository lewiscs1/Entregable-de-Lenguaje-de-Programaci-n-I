IF DB_ID('TechSolutions') IS NULL CREATE DATABASE TechSolutions;
GO
USE TechSolutions;
GO
IF OBJECT_ID('dbo.Cliente') IS NULL
CREATE TABLE dbo.Cliente (
    IdCliente  INT IDENTITY(1,1) PRIMARY KEY,
    Dni        CHAR(8)       NOT NULL UNIQUE,
    Nombres    VARCHAR(100)  NOT NULL,
    Telefono   VARCHAR(15)   NULL
);
GO
IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE Dni = '45781236')
    INSERT INTO dbo.Cliente (Dni, Nombres, Telefono) VALUES ('45781236', 'Ana Torres Ríos', '987654321');
IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE Dni = '70125489')
    INSERT INTO dbo.Cliente (Dni, Nombres, Telefono) VALUES ('70125489', 'Luis Quispe Mamani', '912345678');
GO
SELECT * FROM dbo.Cliente;   -- resultado esperado: al menos 2 clientes (Id 1 y 2)

GO

USE TechSolutions;
GO

-- ===== 1. Reinicio ordenado (primero las tablas hijas por las llaves foráneas) =====
IF OBJECT_ID('dbo.DetalleVenta') IS NOT NULL DROP TABLE dbo.DetalleVenta;
IF OBJECT_ID('dbo.Venta')        IS NOT NULL DROP TABLE dbo.Venta;
IF OBJECT_ID('dbo.Usuario')      IS NOT NULL DROP TABLE dbo.Usuario;
GO

-- ===== 2. Tabla Usuario =====
CREATE TABLE dbo.Usuario (
    IdUsuario        INT IDENTITY(1,1) PRIMARY KEY,   -- número automático (1, 2, 3...)
    Login            VARCHAR(30)  NOT NULL UNIQUE,     -- nombre de usuario: obligatorio y sin repetirse
    ClaveHash        VARCHAR(100) NOT NULL,            -- hash PBKDF2-HMAC-SHA256 (Base64); nunca la contraseña
    Sal              VARCHAR(50)  NOT NULL,            -- sal aleatoria de 16 bytes (Base64) del usuario
    Rol              VARCHAR(20)  NOT NULL
                     CHECK (Rol IN ('Administrador','Vendedor','Almacenero')),   -- nivel de acceso
    IntentosFallidos INT          NOT NULL DEFAULT 0,  -- errores de contraseña seguidos
    Bloqueado        BIT          NOT NULL DEFAULT 0   -- 1 = cuenta bloqueada (3 intentos fallidos)
);
GO
-- Los usuarios NO se insertan aquí: los crea la aplicación, que genera la sal y calcula el hash.
-- La primera vez que se ejecuta, la aplicación pide crear el Administrador.

-- ===== 3. Tablas comerciales =====
IF OBJECT_ID('dbo.Producto') IS NULL
CREATE TABLE dbo.Producto (
    IdProducto     INT IDENTITY(1,1) PRIMARY KEY,
    Nombre         VARCHAR(100) NOT NULL UNIQUE,
    Stock          INT          NOT NULL CONSTRAINT CK_Producto_Stock  CHECK (Stock >= 0),          -- nunca negativo
    PrecioUnitario DECIMAL(10,2) NOT NULL CONSTRAINT CK_Producto_Precio CHECK (PrecioUnitario > 0)
);
GO

CREATE TABLE dbo.Venta (
    IdVenta   INT IDENTITY(1,1) PRIMARY KEY,
    Fecha     DATETIME2(0) NOT NULL CONSTRAINT DF_Venta_Fecha DEFAULT SYSDATETIME(),
    IdUsuario INT          NOT NULL CONSTRAINT FK_Venta_Usuario FOREIGN KEY REFERENCES dbo.Usuario(IdUsuario),   -- vendedor
    IdCliente INT          NOT NULL CONSTRAINT FK_Venta_Cliente FOREIGN KEY REFERENCES dbo.Cliente(IdCliente),
    Total     DECIMAL(12,2) NOT NULL
);
GO

CREATE TABLE dbo.DetalleVenta (
    IdDetalle      INT IDENTITY(1,1) PRIMARY KEY,
    IdVenta        INT NOT NULL CONSTRAINT FK_DetalleVenta_Venta    FOREIGN KEY REFERENCES dbo.Venta(IdVenta),
    IdProducto     INT NOT NULL CONSTRAINT FK_DetalleVenta_Producto FOREIGN KEY REFERENCES dbo.Producto(IdProducto),
    Cantidad       INT NOT NULL CONSTRAINT CK_DetalleVenta_Cantidad CHECK (Cantidad > 0),
    PrecioUnitario DECIMAL(10,2) NOT NULL,
    Subtotal       DECIMAL(12,2) NOT NULL
);
GO

-- Productos de ejemplo (solo si todavía no existen)
IF NOT EXISTS (SELECT 1 FROM dbo.Producto WHERE Nombre = 'Laptop Core i5')
    INSERT INTO dbo.Producto (Nombre, Stock, PrecioUnitario) VALUES ('Laptop Core i5', 10, 2500.00);
IF NOT EXISTS (SELECT 1 FROM dbo.Producto WHERE Nombre = 'Mouse inalámbrico')
    INSERT INTO dbo.Producto (Nombre, Stock, PrecioUnitario) VALUES ('Mouse inalámbrico', 50, 45.00);
IF NOT EXISTS (SELECT 1 FROM dbo.Producto WHERE Nombre = 'Teclado mecánico')
    INSERT INTO dbo.Producto (Nombre, Stock, PrecioUnitario) VALUES ('Teclado mecánico', 5, 180.00);
GO

-- ===== 4. Tipo de tabla: el detalle de la venta (varias líneas en una sola llamada) =====
IF TYPE_ID('dbo.TipoDetalleVenta') IS NULL
    CREATE TYPE dbo.TipoDetalleVenta AS TABLE (
        IdProducto INT NOT NULL PRIMARY KEY,
        Cantidad   INT NOT NULL CHECK (Cantidad > 0)
    );
GO

-- ===== 5. Procedimiento transaccional: registrar venta + descontar stock =====
-- ACID:
--   Atomicidad    -> BEGIN TRANSACTION ... COMMIT; ante cualquier error, ROLLBACK de TODO (todo o nada).
--   Consistencia  -> restricciones CHECK / FOREIGN KEY y validaciones antes de confirmar.
--   Aislamiento   -> el UPDATE descuenta el stock de forma condicional y atómica (bloquea las filas
--                    mientras dura la transacción); dos ventas simultáneas no pueden vender el mismo stock dos veces.
--   Durabilidad   -> tras el COMMIT los cambios quedan en el registro de transacciones de SQL Server.
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarVentaConStock
    @IdUsuario INT,
    @IdCliente INT,
    @Detalle   dbo.TipoDetalleVenta READONLY,
    @IdVenta   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;      -- cualquier error de ejecución deja la transacción lista para ROLLBACK

    DECLARE @Lineas INT;
    DECLARE @Total  DECIMAL(12,2);

    SET @IdVenta = NULL;

    BEGIN TRY
        SELECT @Lineas = COUNT(*) FROM @Detalle;
        IF @Lineas = 0
            THROW 50001, 'La venta debe incluir al menos un producto.', 1;

        BEGIN TRANSACTION;

            IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE IdUsuario = @IdUsuario)
                THROW 50002, 'El usuario que registra la venta no existe.', 1;

            IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE IdCliente = @IdCliente)
                THROW 50004, 'El cliente de la venta no existe.', 1;

            -- Descuenta el stock SOLO si alcanza. Si falta un producto o su stock es menor, esa fila no se actualiza.
            UPDATE p
               SET p.Stock = p.Stock - d.Cantidad
              FROM dbo.Producto AS p
             INNER JOIN @Detalle AS d ON d.IdProducto = p.IdProducto
             WHERE p.Stock >= d.Cantidad;

            -- Si se actualizaron menos filas que líneas, hubo producto inexistente o stock insuficiente.
            IF @@ROWCOUNT <> @Lineas
                THROW 50003, 'Producto inexistente o stock insuficiente. La venta no se registró.', 1;

            SELECT @Total = SUM(d.Cantidad * p.PrecioUnitario)
              FROM @Detalle AS d
             INNER JOIN dbo.Producto AS p ON p.IdProducto = d.IdProducto;

            INSERT INTO dbo.Venta (IdUsuario, IdCliente, Total) VALUES (@IdUsuario, @IdCliente, @Total);
            SET @IdVenta = SCOPE_IDENTITY();

            INSERT INTO dbo.DetalleVenta (IdVenta, IdProducto, Cantidad, PrecioUnitario, Subtotal)
            SELECT @IdVenta, d.IdProducto, d.Cantidad, p.PrecioUnitario, d.Cantidad * p.PrecioUnitario
              FROM @Detalle AS d
             INNER JOIN dbo.Producto AS p ON p.IdProducto = d.IdProducto;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;   -- reversión total: ni stock descontado ni venta a medias

        SET @IdVenta = NULL;
        THROW;                      -- vuelve a lanzar el error original al llamador (C#, SSMS)
    END CATCH
END
GO

SELECT * FROM dbo.Usuario;
SELECT * FROM dbo.Producto;
GO
