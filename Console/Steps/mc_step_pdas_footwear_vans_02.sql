USE [VCDWH]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to run the PDAS Footwear Vans step 02.
-- =============================================
ALTER PROCEDURE [dbo].[mc_step_pdas_footwear_vans_02]
	@mc_user_name nvarchar(100) = NULL
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @mc_system_name nvarchar(100) = 'pdas_ftw_vans'
	DECLARE @mc_proc_name nvarchar(100) = 'mc_step_pdas_footwear_vans_02'

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

		-- Step 02 - Transfer product master data and Priority List
		EXEC [dbo].[proc_pdas_footwear_vans_load_dim_product] @businessid = @dim_business_id_footwear_vans
		EXEC [dbo].[proc_pdas_footwear_vans_load_fact_priority_list] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

		-- Step 03 - Validate source data (need to check the Vans Footwear Validation Report afterwards)
		EXEC [dbo].[proc_pdas_footwear_vans_validate_priority_list] @mc_user_name = @mc_user_name
		EXEC [dbo].[proc_pdas_footwear_vans_validate_capacity_by_week] @mc_user_name = @mc_user_name
		EXEC [dbo].[proc_pdas_footwear_vans_validate_forecast] @mc_user_name = @mc_user_name
		EXEC [dbo].[proc_pdas_footwear_vans_validate_ngc_orders] @mc_user_name = @mc_user_name
		EXEC [dbo].[proc_pdas_footwear_vans_validate_ntb] @mc_user_name = @mc_user_name
		EXEC [dbo].[proc_pdas_footwear_vans_validate_raw_capacity] @mc_user_name = @mc_user_name

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
