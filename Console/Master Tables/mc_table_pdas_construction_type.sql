USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to edit the construction type master.
-- =============================================
ALTER PROCEDURE [dbo].[mc_table_pdas_construction_type]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_construction_type]) > 0
	BEGIN

		-- Validate submitted data based on pre-defined business rules
		DECLARE @test nvarchar(500) =
		(
			SELECT TOP 1
				ISNULL(temp.[Name], '')
			FROM [dbo].[mc_temp_pdas_construction_type] temp
			WHERE LEN([Name]) < 2
		)

		IF @test IS NULL
		BEGIN

			-- Remove duplicates
			DELETE x FROM (
				SELECT *, rn=row_number() OVER (PARTITION BY [Name] ORDER BY [Name])
				FROM [dbo].[mc_temp_pdas_construction_type]
			) x
			WHERE rn > 1;

			-- Delete removed rows (secured by PK constraint)
			DELETE dim
			FROM
				[dbo].[dim_construction_type] dim
				LEFT OUTER JOIN [dbo].[mc_temp_pdas_construction_type] temp
					ON	dim.[id] = temp.[id]
			WHERE temp.[id] IS NULL

			-- Insert new rows
			INSERT INTO [dbo].[dim_construction_type]
            (
                [name]
            )
			SELECT
                temp.[Name]
			FROM
				[dbo].[mc_temp_pdas_construction_type] temp
                LEFT OUTER JOIN [dbo].[dim_construction_type] dim
                    ON temp.[id] = dim.[id]
			WHERE dim.[id] IS NULL

			-- Update existing rows
			UPDATE dim
			SET
				dim.[name] = temp.[Name]
			FROM
				[dbo].[dim_construction_type] dim
				INNER JOIN [dbo].[mc_temp_pdas_construction_type] temp
					ON	dim.[id] = temp.[id]

		END
		ELSE
		BEGIN

			SET @output_param = 'Row ' + @test + ' is invalid.' + '<br />' +
			'Please review the business rules of this table for more details.'
			RETURN -999

		END

	END
	ELSE
	BEGIN

		SET @output_param = 'Table is empty.'
		RETURN -999

	END

END
