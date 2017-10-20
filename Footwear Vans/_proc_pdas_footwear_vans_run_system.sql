USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 9/12/2017
-- Description:	Procedure for GBT to run the PDAS from the backend
-- ==============================================================
ALTER PROCEDURE [dbo].[_proc_pdas_footwear_vans_run_system]
AS
BEGIN
	SET NOCOUNT ON;

	--DECLARE	@current_date date = '2014-12-10';
	DECLARE	@current_date date = GETDATE()
	DECLARE	@pdasid int = (SELECT MAX([id]) FROM [dbo].[dim_pdas])
	DECLARE @dim_business_id_footwear_vans int = (SELECT [id] FROM [dbo].[dim_business] WHERE [brand] = 'Vans' and [product_line] = 'Footwear')
	DECLARE	@buying_program_id int

	-- Step 01 - Start new PDAS release
	-- EXEC [dbo].[proc_pdas_footwear_vans_create_system_key]

	SELECT * FROM [dbo].[dim_pdas] ORDER BY [id] DESC


	-- Step 02 - Transfer product master data and Priority List and Validate source data (need to check the Vans Footwear Validation Report afterwards)
	EXEC [dbo].[proc_pdas_footwear_vans_load_dim_product] @businessid = @dim_business_id_footwear_vans
	EXEC [dbo].[proc_pdas_footwear_vans_load_fact_priority_list] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

	EXEC [dbo].[proc_pdas_footwear_vans_validate_priority_list] @mc_user_name = NULL
	EXEC [dbo].[proc_pdas_footwear_vans_validate_capacity_by_week] @mc_user_name = NULL
	EXEC [dbo].[proc_pdas_footwear_vans_validate_forecast] @mc_user_name = NULL
	EXEC [dbo].[proc_pdas_footwear_vans_validate_ngc_orders] @mc_user_name = NULL
	EXEC [dbo].[proc_pdas_footwear_vans_validate_ntb] @mc_user_name = NULL
	EXEC [dbo].[proc_pdas_footwear_vans_validate_raw_capacity] @mc_user_name = NULL

	SELECT * FROM [dbo].[system_log_file] WHERE [system] = 'pdas_ftw_vans' ORDER BY [source], [type]


	-- Step 04 - Transfer raw factory capacity (weekly and monthly), NGC Orders, Need to Buys and Forecasts
	-- Capacity
	EXEC [dbo].[proc_pdas_footwear_vans_load_fact_factory_capacity]	@pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

	-- NTB
	SET @buying_program_id = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Bulk Buy')
	EXEC [dbo].[proc_pdas_footwear_vans_load_fact_order_ntb_bulk]
		@pdasid = @pdasid,
		@businessid = @dim_business_id_footwear_vans,
		@buying_program_id = @buying_program_id
	SET @buying_program_id = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Retail Quick Turn')
	EXEC [dbo].[proc_pdas_footwear_vans_load_fact_order_ntb_rqt]
		@pdasid = @pdasid,
		@businessid = @dim_business_id_footwear_vans,
		@buying_program_id = @buying_program_id
	SET @buying_program_id = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Scheduled Out of Sync')
	EXEC [dbo].[proc_pdas_footwear_vans_load_fact_order_ntb_oos_scheduled]
		@pdasid = @pdasid,
		@businessid = @dim_business_id_footwear_vans,
		@buying_program_id = @buying_program_id
	SET @buying_program_id = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Ad-Hoc Out of Sync')
	EXEC [dbo].[proc_pdas_footwear_vans_load_fact_order_ntb_oos_adhoc]
		@pdasid = @pdasid,
		@businessid = @dim_business_id_footwear_vans,
		@buying_program_id = @buying_program_id

	-- Forecast
	SET @buying_program_id = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Bulk Buy')
	EXEC [dbo].[proc_pdas_footwear_vans_load_fact_forecast_bulk]
		@pdasid = @pdasid,
		@businessid = @dim_business_id_footwear_vans,
		@buying_program_id = @buying_program_id
	SET @buying_program_id = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Retail Quick Turn')
	EXEC [dbo].[proc_pdas_footwear_vans_load_fact_forecast_rqt]
		@pdasid = @pdasid,
		@businessid = @dim_business_id_footwear_vans,
		@buying_program_id = @buying_program_id

	-- NGC
	EXEC [dbo].[proc_pdas_footwear_vans_load_fact_order_ngc] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

	-- Combine demand
	EXEC [dbo].[proc_pdas_footwear_vans_load_fact_demand_total]	@pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

	-- Step 05 - Run decision tree allocation algorithm and adjust EMEA NTB based on Cutoff days
	EXEC [dbo].[proc_pdas_footwear_vans_do_allocation]	@pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans
	EXEC [dbo].[proc_pdas_footwear_vans_emea_ntb_cutoff_day_adjustment] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

	-- Prepare report tables for Excel frontend
	EXEC [proc_pdas_footwear_vans_do_excel_table_preparation] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

END
