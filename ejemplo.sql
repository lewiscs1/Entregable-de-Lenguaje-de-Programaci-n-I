USE TechSolutions;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE Dni = '44789632')
    INSERT INTO dbo.Cliente (Dni, Nombres, Telefono) VALUES ('44789632', 'Jorge Salazar Díaz', '987111222');
IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE Dni = '45123678')
    INSERT INTO dbo.Cliente (Dni, Nombres, Telefono) VALUES ('45123678', 'Carmen Flores Huamán', NULL);
IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE Dni = '47112233')
    INSERT INTO dbo.Cliente (Dni, Nombres, Telefono) VALUES ('47112233', 'Carlos Mendoza Rojas', '956123456');
IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE Dni = '46778899')
    INSERT INTO dbo.Cliente (Dni, Nombres, Telefono) VALUES ('46778899', 'María López Vega', NULL);
GO
SELECT * FROM dbo.Cliente ORDER BY Nombres;   -- resultado esperado: 6 clientes (2 sin teléfono)
