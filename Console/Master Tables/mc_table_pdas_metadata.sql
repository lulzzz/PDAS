USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/21/2017
-- Description:	Console procedure to configure the source tables to be loaded into the PDAS via ETL.
-- =============================================
ALTER PROCEDURE [dbo].[mc_table_pdas_metadata]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_metadata]) > 0
	BEGIN

		-- Remove duplicates
		DELETE x FROM (
			SELECT *, rn=row_number() OVER (PARTITION BY [table_name] ORDER BY [table_name])
			FROM [dbo].[mc_temp_pdas_metadata]
		) x
		WHERE rn > 1;

        -- Delete removed rows (secured by PK constraint)
        DELETE mc
        FROM
            [dbo].[pdas_metadata] mc
            LEFT OUTER JOIN [dbo].[mc_temp_pdas_metadata] temp
                ON	mc.[table_name] = temp.[table_name]
        WHERE temp.[table_name] IS NULL

		-- Insert new rows
		INSERT INTO [dbo].[pdas_metadata]
		SELECT temp.*
		FROM
			[dbo].[mc_temp_pdas_metadata] temp
			LEFT JOIN [dbo].[pdas_metadata] mc
				ON temp.[table_name] = mc.[table_name]
		WHERE mc.[table_name] IS NULL

		-- Update existing rows
		UPDATE mc
		SET
			mc.[table_name] = temp.[table_name]
			,mc.[etl_type] = temp.[etl_type]
			,mc.[src_name] = temp.[src_name]
			,mc.[timestamp_file] = temp.[timestamp_file]
			,mc.[state] = temp.[state]

		FROM
			[dbo].[pdas_metadata] mc
			INNER JOIN [dbo].[mc_temp_pdas_metadata] temp
				ON	mc.[table_name] = temp.[table_name]

	END
	ELSE
	BEGIN

		SET @output_param = 'Table is empty.'
		RETURN -999

	END

END
