USE [VCDWH]

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


	-- Step 01 - Start new PDAS release
	-- EXEC [dbo].[proc_pdas_footwear_vans_create_system_key]

	SELECT * FROM [dbo].[dim_pdas] ORDER BY [id] DESC

	-- Step 02 - Transfer product master data and Priority List
	EXEC [dbo].[proc_pdas_footwear_vans_load_dim_product]
	EXEC [dbo].[proc_pdas_footwear_vans_load_fact_priority_list]

	-- Step 03 - Validate source data (need to check the Vans Footwear Validation Report afterwards)
	EXEC [dbo].[proc_pdas_footwear_vans_validate_priority_list]
	EXEC [dbo].[]
	EXEC [dbo].[]
	EXEC [dbo].[]
	EXEC [dbo].[]
	EXEC [dbo].[]
	EXEC [dbo].[]
	EXEC [dbo].[]

	-- Step 04 - Transfer raw factory capacity (weekly and monthly), NGC Orders, Need to Buys and Forecasts
	EXEC [dbo].[proc_pdas_footwear_vans_load_fact_demand_total]	@pdasid = @pdasid

	-- Step 05 - Run decision tree allocation algorithm


	/* CHECK [dbo].[system_log_file] */
	SELECT * FROM [dbo].[system_log_file] WHERE [system] = 'pdas_ftw_vans' ORDER BY [source], [type]

	-- Step 04a: Transfer factory capacity
	EXEC [proc_rccp_footwear_load_factory_capacity]


END
