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
