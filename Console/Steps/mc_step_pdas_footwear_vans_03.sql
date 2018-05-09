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

	DECLARE	@dim_release_id int = (SELECT MAX([dim_release_id]) FROM [dbo].[helper_pdas_footwear_vans_release_current])
	DECLARE @dim_business_id_footwear_vans int = (SELECT [id] FROM [dbo].[dim_business] WHERE [brand] = 'Vans' and [product_line] = 'Footwear')
	DECLARE @buying_program_id int = (SELECT [dim_buying_program_id] FROM [dbo].[dim_pdas] WHERE [id] = @dim_release_id)
	DECLARE @buying_program_forecast_id int = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Bulk Buy')

	-- Step 03 - Transfer raw factory capacity (weekly and monthly), NGC Orders, Need to Buys and Forecasts
	-- Capacity
	EXEC [dbo].[proc_pdas_footwear_vans_load_fact_factory_capacity]	@dim_release_id = @dim_release_id, @businessid = @dim_business_id_footwear_vans

	-- NTB
	EXEC [dbo].[proc_pdas_footwear_vans_load_fact_order_ntb]
		@dim_release_id = @dim_release_id,
		@businessid = @dim_business_id_footwear_vans,
		@buying_program_id = @buying_program_id

	-- NGC
	-- EXEC [dbo].[proc_pdas_footwear_vans_load_fact_order_ngc] @dim_release_id = @dim_release_id, @businessid = @dim_business_id_footwear_vans

	-- Forecast
	EXEC [dbo].[proc_pdas_footwear_vans_load_fact_forecast]
		@dim_release_id = @dim_release_id,
		@businessid = @dim_business_id_footwear_vans,
		@buying_program_id = @buying_program_forecast_id

	-- Do MOQ check
	EXEC [dbo].[proc_pdas_footwear_vans_do_moq_upcharge_adjustment] @dim_release_id = @dim_release_id, @businessid = @dim_business_id_footwear_vans

	-- Update id_original
	UPDATE [fact_demand_total]
	SET [id_original] = [id]
	WHERE
		[dim_pdas_id] = @dim_release_id
		and [dim_business_id] = @dim_business_id_footwear_vans
		and [is_from_previous_release] = 0
		and ISNULL([id_original], 0) = 0

	-- Update dim_date_id_original
	UPDATE [fact_demand_total]
	SET [dim_date_id_original] = [dim_date_id]
	WHERE
		[dim_pdas_id] = @dim_release_id
		and [dim_business_id] = @dim_business_id_footwear_vans
		and ISNULL([dim_date_id_original], 0) = 0

END
