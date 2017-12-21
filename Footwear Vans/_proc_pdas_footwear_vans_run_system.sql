USE [VCDWH]


--DECLARE	@current_date date = '2014-12-10';
DECLARE	@current_date date = GETDATE()
DECLARE	@pdasid int = (SELECT MAX([id]) FROM [dbo].[dim_pdas])
DECLARE @dim_business_id_footwear_vans int = (SELECT [id] FROM [dbo].[dim_business] WHERE [brand] = 'Vans' and [product_line] = 'Footwear')
DECLARE	@buying_program_id int
SET @buying_program_id = (SELECT [dim_buying_program_id] FROM [dbo].[dim_pdas] WHERE [id] = @pdasid)

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

SELECT * FROM [dbo].[system_log_file] WHERE [system] = 'pdas_ftw_vans' ORDER BY [source], [category]


-- Transfer raw factory capacity (weekly and monthly), NGC Orders, Need to Buys and Forecasts
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
	@buying_program_id = @buying_program_id

-- NGC
EXEC [dbo].[proc_pdas_footwear_vans_load_fact_order_ngc] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans


-- Consume high level demand signal with low level demand signal
--EXEC [dbo].[proc_pdas_footwear_vans_do_demand_signal_netting]

-- Run decision tree allocation algorithm
EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_unconstrained] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans
EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_constrained] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

-- Include manual overwritte from VFA users
EXEC [dbo].[proc_pdas_footwear_vans_do_overwrite] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

-- Adjust EMEA NTB based on cutoff days
EXEC [dbo].[proc_pdas_footwear_vans_do_emea_ntb_cutoff_day_adjustment] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

-- Do MOQ check
EXEC [dbo].[proc_pdas_footwear_vans_do_moq_upcharge_adjustment] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

-- Prepare report tables for Excel frontend
EXEC [proc_pdas_footwear_vans_do_excel_table_preparation] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans
