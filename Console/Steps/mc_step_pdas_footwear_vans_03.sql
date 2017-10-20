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
	@mc_user_name nvarchar(100) = NULL
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @mc_system_name nvarchar(100) = 'pdas_ftw_vans'
	DECLARE @mc_proc_name nvarchar(100) = 'mc_step_pdas_footwear_vans_03'

	IF (@mc_user_name IN (SELECT [name] FROM [dbo].[mc_user]))
	BEGIN

		-- Initialize Console procedure table
		UPDATE [dbo].[mc_proc]
		SET
			[status_start] = 0
			,[status_end] = 0
		WHERE
			[mc_system_name] = @mc_system_name
			AND CONVERT(int, RIGHT([name], 2)) >= CONVERT(int, RIGHT(@mc_proc_name, 2))

		-- Update Console procedure table
		UPDATE [dbo].[mc_proc]
		SET
			[update_dt] = GETDATE()
			,[status_start] = 1
		WHERE
			[mc_system_name] = @mc_system_name
			AND [name] = @mc_proc_name

		-- Stored procedure(s) to run
		/* START */

		DECLARE	@pdasid int = (SELECT MAX([id]) FROM [dbo].[dim_pdas])
		DECLARE @dim_business_id_footwear_vans int = (SELECT [id] FROM [dbo].[dim_business] WHERE [brand] = 'Vans' and [product_line] = 'Footwear')
		DECLARE	@buying_program_id int

		-- Step 03 - Transfer raw factory capacity (weekly and monthly), NGC Orders, Need to Buys and Forecasts
		-- Capacity
		EXEC [dbo].[proc_pdas_footwear_vans_load_fact_factory_capacity]	@pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

		-- NTB
		SET @buying_program_id = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Bulk Buy')
		EXEC [dbo].[proc_pdas_footwear_vans_load_fact_order_ntb_bulk]
			@pdasid = @pdasid,
			@businessid = @dim_business_id_footwear_vans,
			@buying_program_id = @buying_program_id
		/*
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
		*/

		-- Forecast
		SET @buying_program_id = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Bulk Buy')
		EXEC [dbo].[proc_pdas_footwear_vans_load_fact_forecast_bulk]
			@pdasid = @pdasid,
			@businessid = @dim_business_id_footwear_vans,
			@buying_program_id = @buying_program_id
		/*
		SET @buying_program_id = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Retail Quick Turn')
		EXEC [dbo].[proc_pdas_footwear_vans_load_fact_forecast_rqt]
			@pdasid = @pdasid,
			@businessid = @dim_business_id_footwear_vans,
			@buying_program_id = @buying_program_id
		*/

		-- NGC
		EXEC [dbo].[proc_pdas_footwear_vans_load_fact_order_ngc] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

		-- Combine demand
		EXEC [dbo].[proc_pdas_footwear_vans_load_fact_demand_total]	@pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

		-- Decision tree algorithm
		EXEC [dbo].[proc_pdas_footwear_vans_do_allocation]	@pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

		

		-- Prepare report tables for Excel frontend
		EXEC [proc_pdas_footwear_vans_do_excel_table_preparation] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

		/* END */

		-- Update Console procedure table
		UPDATE [dbo].[mc_proc]
		SET
			[update_dt] = GETDATE()
			,[status_end] = 1
		WHERE
			[mc_system_name] = @mc_system_name
			AND [name] = @mc_proc_name

	END
	ELSE
	BEGIN

		RETURN -500

	END

END
