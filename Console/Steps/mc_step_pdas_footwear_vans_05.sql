USE [VCDWH]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to run the PDAS Footwear Vans step 05.
-- =============================================
ALTER PROCEDURE [dbo].[mc_step_pdas_footwear_vans_05]
	@mc_user_name nvarchar(100) = NULL
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @mc_system_name nvarchar(100) = 'pdas_ftw_vans'
	DECLARE @mc_proc_name nvarchar(100) = 'mc_step_pdas_footwear_vans_05'

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
		-- Step 05 - Transfer product master data

		-- EXEC [proc_rccp_footwear_load_factory_ranking] @mc_user_name = @mc_user_name
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
