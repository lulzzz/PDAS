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
			AND [name] =@mc_proc_name

		-- Stored procedure(s) to run
		/* START */
		-- Step 03 - Validate source data (need to check the Vans Footwear Validation Report afterwards)
		EXEC [dbo].[proc_pdas_footwear_vans_validate_priority_list] @mc_user_name = NULL
		EXEC [dbo].[proc_pdas_footwear_vans_validate_capacity_by_week] @mc_user_name = NULL
		EXEC [dbo].[proc_pdas_footwear_vans_validate_forecast] @mc_user_name = NULL
		EXEC [dbo].[proc_pdas_footwear_vans_validate_ngc_orders] @mc_user_name = NULL
		EXEC [dbo].[proc_pdas_footwear_vans_validate_ntb] @mc_user_name = NULL
		EXEC [dbo].[proc_pdas_footwear_vans_validate_raw_capacity] @mc_user_name = NULL

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
