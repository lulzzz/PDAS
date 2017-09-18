USE [VCDWH]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 9/12/2017
-- Description:	Procedure to load the order and forecast demand in proc_pdas_footwear_vans_load_fact_demand_total.
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_load_fact_demand_total]
	@pdasid INT
AS
BEGIN

    -- Variable declarations
    DECLARE @dim_demand_category_id_forecast int = (SELECT [id] FROM [dbo].[dim_demand_category] WHERE [name] = 'Forecast')

	-- Check if the session has already been loaded
	IF EXISTS (SELECT 1 FROM [dbo].[fact_demand_total] WHERE dim_pdas_id = @pdasid)
	BEGIN
		DELETE FROM [dbo].[fact_demand_total] WHERE dim_pdas_id = @pdasid;
	END
	;

	-- Insert from staging
	INSERT INTO [dbo].[fact_demand_total]
    (
        [dim_pdas_id]
        ,[dim_business_id]
        ,[dim_buying_program_id]
        ,[dim_product_id]
        ,[dim_date_id]
        ,[dim_factory_id_original]
        ,[dim_factory_id]
        ,[dim_customer_id]
        ,[dim_demand_category_id]
        ,[order_number]
        ,[quantity_unconsumed]
        ,[quantity_consumed]
        ,[quantity]
    )
	-- fact_order
	SELECT
        [dim_pdas_id]
        ,[dim_business_id]
        ,[dim_buying_program_id]
        ,[dim_product_id]
        ,[dim_date_id]
        ,[dim_factory_id] AS [dim_factory_id_original]
        ,[dim_factory_id]
        ,[dim_customer_id]
        ,[dim_demand_category_id]
        ,[order_number]
        ,[quantity] AS [quantity_unconsumed]
        ,[quantity] AS [quantity_consumed]
        ,[quantity]
	FROM [dbo].[fact_order]
	UNION
	-- fact_forecast
	SELECT
        [dim_pdas_id]
        ,[dim_business_id]
        ,[dim_buying_program_id]
        ,[dim_product_id]
        ,[dim_date_id]
        ,[dim_factory_id] AS [dim_factory_id_original]
        ,[dim_factory_id]
        ,[dim_customer_id]
        ,@dim_demand_category_id_forecast AS [dim_demand_category_id]
        ,'UNDEFINED' AS [order_number]
        ,[quantity] AS [quantity_unconsumed]
        ,[quantity] AS [quantity_consumed]
        ,[quantity]
	FROM [dbo].[fact_forecast]
	;

END
