USE [VCDWH]
GO

INSERT INTO [dbo].[dim_business]
(
    [brand]
    ,[product_line]
)
VALUES
('Vans', 'Footwear'),
('Vans', 'Apparel'),
('Timberland', 'Footwear'),
('Timberland', 'Apparel')
