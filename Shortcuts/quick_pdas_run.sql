DECLARE	@current_date date = GETDATE()
DECLARE	@pdasid int = (SELECT MAX([id]) FROM [dbo].[dim_pdas])
DECLARE @dim_business_id_footwear_vans int = (SELECT [id] FROM [dbo].[dim_business] WHERE [brand] = 'Vans' and [product_line] = 'Footwear')
DECLARE	@buying_program_id int

EXEC [dbo].[proc_pdas_footwear_vans_load_dim_product] @businessid = @dim_business_id_footwear_vans
EXEC [dbo].[proc_pdas_footwear_vans_load_fact_priority_list] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

EXEC [dbo].[proc_pdas_footwear_vans_validate_priority_list] @mc_user_name = NULL
EXEC [dbo].[proc_pdas_footwear_vans_validate_capacity_by_week] @mc_user_name = NULL
EXEC [dbo].[proc_pdas_footwear_vans_validate_forecast] @mc_user_name = NULL
EXEC [dbo].[proc_pdas_footwear_vans_validate_ngc_orders] @mc_user_name = NULL
EXEC [dbo].[proc_pdas_footwear_vans_validate_ntb] @mc_user_name = NULL
EXEC [dbo].[proc_pdas_footwear_vans_validate_raw_capacity] @mc_user_name = NULL

SELECT * FROM [dbo].[system_log_file] WHERE [system] = 'pdas_ftw_vans' ORDER BY [source], [type]


-- Transfer raw factory capacity (weekly and monthly), NGC Orders, Need to Buys and Forecasts
-- Capacity
EXEC [dbo].[proc_pdas_footwear_vans_load_fact_factory_capacity]	@pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

-- NTB
SET @buying_program_id = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Bulk Buy')
EXEC [dbo].[proc_pdas_footwear_vans_load_fact_order_ntb_bulk]
    @pdasid = @pdasid,
    @businessid = @dim_business_id_footwear_vans,
    @buying_program_id = @buying_program_id

-- Forecast
SET @buying_program_id = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Bulk Buy')
EXEC [dbo].[proc_pdas_footwear_vans_load_fact_forecast_bulk]
    @pdasid = @pdasid,
    @businessid = @dim_business_id_footwear_vans,
    @buying_program_id = @buying_program_id

-- NGC
EXEC [dbo].[proc_pdas_footwear_vans_load_fact_order_ngc] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

-- Combine demand
EXEC [dbo].[proc_pdas_footwear_vans_load_fact_demand_total]	@pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

-- Consume high level demand signal with low level demand signal
EXEC [dbo].[proc_pdas_footwear_vans_do_demand_signal_netting]

-- Run decision tree allocation algorithm
EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_unconstrained] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans
EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_constrained] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

-- Include manual overwritte from VFA users
EXEC [dbo].[proc_pdas_footwear_vans_load_allocation_scenario_vfa] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

-- Adjust EMEA NTB based on cutoff days
EXEC [dbo].[proc_pdas_footwear_vans_emea_ntb_cutoff_day_adjustment] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

-- Prepare report tables for Excel frontend
EXEC [proc_pdas_footwear_vans_do_excel_table_preparation] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans
