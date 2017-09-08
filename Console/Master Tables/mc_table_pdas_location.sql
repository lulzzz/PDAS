USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to edit the location master.
-- =============================================
ALTER PROCEDURE [dbo].[mc_table_pdas_location]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_location]) > 0
	BEGIN

		-- Validate submitted data based on pre-defined business rules
		DECLARE @test nvarchar(500) =
		(
			SELECT TOP 1
				temp.[Region] + ' / ' +
				temp.[Country] + ' / ' +
				temp.[Country Code A2] + ' / ' +
				temp.[Country Code A3]
			FROM [dbo].[mc_temp_pdas_location] temp
			WHERE
			NOT
			(
				UPPER([Region]) IN ('US', 'CASA', 'EU', 'APAC')
				and LEN([Country]) > 0
				and LEN([Country Code A2]) = 2
				and LEN([Country Code A3]) = 3
			)
		)

		IF @test IS NULL
		BEGIN

			-- Remove duplicates
			DELETE x FROM (
				SELECT *, rn=row_number() OVER (PARTITION BY [Country Code A2] ORDER BY [Country Code A2])
				FROM [dbo].[mc_temp_pdas_location]
			) x
			WHERE rn > 1;

			-- Delete removed rows (secured by PK constraint)
			DELETE dim
			FROM
				[dbo].[dim_location] dim
				LEFT OUTER JOIN [dbo].[mc_temp_pdas_location] temp
					ON	dim.[id] = temp.[id]
			WHERE temp.[id] IS NULL

			-- Insert new rows
			INSERT INTO [dbo].[dim_location]
			(
				[region]
				,[country]
				,[country_code_a2]
				,[country_code_a3]
			)
			SELECT
				UPPER(temp.[Region]) AS [region]
				,temp.[Country] AS [country]
				,UPPER(temp.[Country code A2]) AS [country_code_a2]
				,UPPER(temp.[Country code A3]) AS [country_code_a3]
			FROM
				[dbo].[mc_temp_pdas_location] temp
				LEFT OUTER JOIN [dbo].[dim_location] dim
					ON temp.[Country code A2] = dim.[country_code_a2]
			WHERE dim.[country_code_a2] IS NULL

			-- Update existing rows
			UPDATE dim
			SET
				dim.[region] = dim.[region],
				dim.[country_code_a2] = temp.[Country code A2],
				dim.[country_code_a3] = temp.[Country code A3]
			FROM
				[dbo].[dim_location] dim
				INNER JOIN [dbo].[mc_temp_pdas_location] temp
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
