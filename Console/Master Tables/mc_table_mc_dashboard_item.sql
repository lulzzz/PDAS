USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to configure the Console.
-- =============================================
ALTER PROCEDURE [dbo].[mc_table_mc_dashboard_item]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_mc_dashboard_item]) > 0
	BEGIN

		-- Remove duplicates
		DELETE x FROM (
			SELECT *, rn=row_number() OVER (PARTITION BY [name] ORDER BY [name])
			FROM [dbo].[mc_temp_mc_dashboard_item]
		) x
		WHERE rn > 1;

        -- Delete removed rows (secured by PK constraint)
        DELETE mc
        FROM
            [dbo].[mc_dashboard_item] mc
            LEFT OUTER JOIN [dbo].[mc_temp_mc_dashboard_item] temp
                ON	mc.[name] = temp.[name]
        WHERE temp.[name] IS NULL

		-- Insert new rows
		INSERT INTO [dbo].[mc_dashboard_item]
		(
            [name]
            ,[label]
            ,[grid_position]
            ,[format]
            ,[query]
            ,[mc_dashboard_name]
            ,[mc_dashboard_mc_system_name]
		)
		SELECT
            temp.[name]
            ,temp.[label]
            ,temp.[grid_position]
            ,temp.[format]
            ,temp.[query]
            ,temp.[mc_dashboard_name]
            ,temp.[mc_dashboard_mc_system_name]
		FROM
			[dbo].[mc_temp_mc_dashboard_item] temp
			LEFT JOIN [dbo].[mc_dashboard_item] mc
				ON temp.[name] = mc.[name]
		WHERE mc.[name] IS NULL

		-- Update existing rows
		UPDATE mc
		SET
            mc.[name] = temp.[name]
            ,mc.[label] = temp.[label]
            ,mc.[grid_position] = temp.[grid_position]
            ,mc.[format] = temp.[format]
            ,mc.[query] = temp.[query]
            ,mc.[mc_dashboard_name] = temp.[mc_dashboard_name]
            ,mc.[mc_dashboard_mc_system_name] = temp.[mc_dashboard_mc_system_name]
		FROM
			[dbo].[mc_dashboard_item] mc
			INNER JOIN [dbo].[mc_temp_mc_dashboard_item] temp
				ON	mc.[name] = temp.[name]

	END
	ELSE
	BEGIN

		SET @output_param = 'Table is empty.'
		RETURN -999

	END

END
