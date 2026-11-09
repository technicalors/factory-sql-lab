-- Database mau gia lap phan mem nha may + tai khoan ORS theo muc 4 de xuat
IF DB_ID('FactoryDB') IS NULL CREATE DATABASE FactoryDB;
GO
USE FactoryDB;
GO
IF OBJECT_ID('dbo.ProductionOrder') IS NULL
CREATE TABLE dbo.ProductionOrder (
    Id          int IDENTITY(1,1) PRIMARY KEY,
    OrderCode   nvarchar(50)  NOT NULL UNIQUE,
    ProductName nvarchar(200) NOT NULL,
    Qty         int           NOT NULL CHECK (Qty >= 0),
    Status      nvarchar(20)  NOT NULL DEFAULT N'NEW',
    UpdatedAt   datetime      NOT NULL DEFAULT GETDATE()
);
-- Bang KHONG cap quyen cho ORS (de kiem tra quyen toi thieu)
IF OBJECT_ID('dbo.Recipe') IS NULL
CREATE TABLE dbo.Recipe (Id int IDENTITY PRIMARY KEY, Name nvarchar(200) NOT NULL, Secret nvarchar(200));
GO
IF NOT EXISTS (SELECT 1 FROM dbo.ProductionOrder)
INSERT dbo.ProductionOrder (OrderCode, ProductName, Qty) VALUES
    (N'PO-0001', N'Thép cuộn cán nóng', 120), (N'PO-0002', N'Ống thép mạ kẽm', 80);
IF NOT EXISTS (SELECT 1 FROM dbo.Recipe)
INSERT dbo.Recipe (Name, Secret) VALUES (N'Công thức A', N'không được xem');
GO

USE master;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'ors_integration')
    CREATE LOGIN ors_integration WITH PASSWORD = '$(PW)', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF,
        DEFAULT_DATABASE = FactoryDB;
GO
USE FactoryDB;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'ors_integration')
    CREATE USER ors_integration FOR LOGIN ors_integration;
GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.ProductionOrder TO ors_integration;
GO
