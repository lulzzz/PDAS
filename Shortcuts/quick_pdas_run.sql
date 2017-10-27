DECLARE	@current_date date = GETDATE()
DECLARE	@pdasid int = (SELECT MAX([id]) FROM [dbo].[dim_pdas])
DECLARE @dim_business_id_footwear_vans int = (SELECT [id] FROM [dbo].[dim_business] WHERE [brand] = 'Vans' and [product_line] = 'Footwear')
DECLARE	@buying_program_id int

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


-- Run decision tree allocation algorithm
EXEC [dbo].[proc_pdas_footwear_vans_do_allocation]	@pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans


-- Prepare report tables for Excel frontend
EXEC [proc_pdas_footwear_vans_do_excel_table_preparation] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans
