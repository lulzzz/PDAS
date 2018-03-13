USE [VCDWH]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to run the PDAS Footwear Vans step 03.
-- =============================================
ALTER PROCEDURE [dbo].[mc_step_pdas_footwear_vans_03]
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE	@pdasid int = (SELECT MAX([id]) FROM [dbo].[dim_pdas])
	DECLARE @dim_business_id_footwear_vans int = (SELECT [id] FROM [dbo].[dim_business] WHERE [brand] = 'Vans' and [product_line] = 'Footwear')
	DECLARE @buying_program_id int = (SELECT [dim_buying_program_id] FROM [dbo].[dim_pdas] WHERE [id] = @pdasid)
	DECLARE @buying_program_forecast_id int = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Bulk Buy')

	-- Step 03 - Transfer raw factory capacity (weekly and monthly), NGC Orders, Need to Buys and Forecasts
	-- Capacity
	EXEC [dbo].[proc_pdas_footwear_vans_load_fact_factory_capacity]	@pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

	-- NTB
	EXEC [dbo].[proc_pdas_footwear_vans_load_fact_order_ntb]
		@pdasid = @pdasid,
		@businessid = @dim_business_id_footwear_vans,
		@buying_program_id = @buying_program_id

	-- Forecast
	EXEC [dbo].[proc_pdas_footwear_vans_load_fact_forecast]
		@pdasid = @pdasid,
		@businessid = @dim_business_id_footwear_vans,
		@buying_program_id = @buying_program_forecast_id

	-- NGC
	-- EXEC [dbo].[proc_pdas_footwear_vans_load_fact_order_ngc] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

	-- Prepare report tables for Excel frontend
	-- EXEC [proc_pdas_footwear_vans_do_excel_table_preparation] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

	-- Do manual overwrite
	EXEC [dbo].[proc_pdas_footwear_vans_do_overwrite] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans


END
