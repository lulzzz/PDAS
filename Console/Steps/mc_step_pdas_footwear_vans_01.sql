USE [VCDWH]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to run the PDAS Footwear Vans step 01.
-- =============================================
ALTER PROCEDURE [dbo].[mc_step_pdas_footwear_vans_01]
	@mc_user_name nvarchar(100) = NULL
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @mc_system_name nvarchar(100) = 'pdas_ftw_vans'
	DECLARE @mc_proc_name nvarchar(100) = 'mc_step_pdas_footwear_vans_01'

	IF (@mc_user_name IN (SELECT [name] FROM [dbo].[mc_user]))
	BEGIN

        -- Initialize Console procedure table (this is the 1st step for Footwear and Apparel)
        UPDATE [dbo].[mc_proc]
        SET
            [status_start] = 0
            ,[status_end] = 0
        WHERE
            [mc_system_name] = @mc_system_name

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
        -- Step 01 - Start new PDAS release
        EXEC [proc_pdas_footwear_vans_create_system_key] @mc_user_name = @mc_user_name
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
