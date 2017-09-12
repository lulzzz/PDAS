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
ALTER PROCEDURE [dbo].[mc_table_mc_dashboard]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_mc_dashboard]) > 0
	BEGIN

		-- Remove duplicates
		DELETE x FROM (
			SELECT *, rn=row_number() OVER (PARTITION BY [name] ORDER BY [name])
			FROM [dbo].[mc_temp_mc_dashboard]
		) x
		WHERE rn > 1;

        -- Delete removed rows (secured by PK constraint)
        DELETE mc
        FROM
            [dbo].[mc_dashboard] mc
            LEFT OUTER JOIN [dbo].[mc_temp_mc_dashboard] temp
                ON	mc.[name] = temp.[name]
        WHERE temp.[name] IS NULL

		-- Insert new rows
		INSERT INTO [dbo].[mc_dashboard]
		(
            [name]
            ,[label]
            ,[position]
            ,[mc_system_name]
		)
		SELECT
            temp.[name]
            ,temp.[label]
            ,temp.[position]
            ,temp.[mc_system_name]
		FROM
			[dbo].[mc_temp_mc_dashboard] temp
			LEFT JOIN [dbo].[mc_dashboard] mc
				ON temp.[name] = mc.[name]
		WHERE mc.[name] IS NULL

		-- Update existing rows
		UPDATE mc
		SET
            mc.[name] = temp.[name]
            ,mc.[label] = temp.[label]
            ,mc.[position] = temp.[position]
            ,mc.[mc_system_name] = temp.[mc_system_name]
		FROM
			[dbo].[mc_dashboard] mc
			INNER JOIN [dbo].[mc_temp_mc_dashboard] temp
				ON	mc.[name] = temp.[name]

	END
	ELSE
	BEGIN

		SET @output_param = 'Table is empty.'
		RETURN -999

	END

END
