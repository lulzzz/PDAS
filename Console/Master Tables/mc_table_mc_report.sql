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
ALTER PROCEDURE [dbo].[mc_table_mc_report]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_mc_report]) > 0
	BEGIN

		-- Remove duplicates
		DELETE x FROM (
			SELECT *, rn=row_number() OVER (PARTITION BY [name] ORDER BY [name])
			FROM [dbo].[mc_temp_mc_report]
		) x
		WHERE rn > 1;

        -- Delete removed rows (secured by PK constraint)
        DELETE mc
        FROM
            [dbo].[mc_report] mc
            LEFT OUTER JOIN [dbo].[mc_temp_mc_report] temp
                ON	mc.[name] = temp.[name]
        WHERE temp.[name] IS NULL

		-- Insert new rows
		INSERT INTO [dbo].[mc_report]
		(
            [name]
            ,[label]
            ,[query]
            ,[mc_system_name]
		)
		SELECT
            temp.[name]
            ,temp.[label]
            ,temp.[query]
            ,temp.[mc_system_name]
		FROM
			[dbo].[mc_temp_mc_report] temp
			LEFT JOIN [dbo].[mc_report] mc
				ON temp.[name] = mc.[name]
		WHERE mc.[name] IS NULL

		-- Update existing rows
		UPDATE mc
		SET
            mc.[name] = temp.[name]
            ,mc.[label] = temp.[label]
            ,mc.[query] = temp.[query]
            ,mc.[mc_system_name] = temp.[mc_system_name]
		FROM
			[dbo].[mc_report] mc
			INNER JOIN [dbo].[mc_temp_mc_report] temp
				ON	mc.[name] = temp.[name]

	END
	ELSE
	BEGIN

		SET @output_param = 'Table is empty.'
		RETURN -999

	END

END
