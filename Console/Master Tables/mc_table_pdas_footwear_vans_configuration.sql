USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to edit the PDAS configuration table (fact table).
-- =============================================
ALTER PROCEDURE [dbo].[mc_table_pdas_footwear_vans_configuration]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_configuration]) > 0
	BEGIN

		-- Validate submitted data based on pre-defined business rules
		DECLARE @test nvarchar(500) =
		(
			SELECT TOP 1
				ISNULL([type], '')  + ' / ' +
				ISNULL([variable], '')
			FROM [dbo].[mc_temp_pdas_footwear_vans_configuration]  temp
			WHERE
				[type] NOT IN (
					'System'
				) OR
				[variable] NOT IN (
					'Release Locker',
					'Release Note',
					'Buying Program Name',
					'Buy Month'
				)
				OR
				([variable] = 'Release Locker' AND [value] NOT IN ('ON', 'OFF'))
				OR
				([variable] = 'Buying Program Name' AND [value] NOT IN (SELECT DISTINCT [name] FROM [dbo].[dim_buying_program]))
				OR
				(
					[variable] = 'Buy Month' AND [value] NOT IN
					(
						SELECT DISTINCT [year_month_accounting]
						FROM [dbo].[dim_date]
					)
				)
		)

		IF @test IS NULL
		BEGIN

			DECLARE @dim_pdas_id int = (SELECT MAX([id]) FROM [dbo].[dim_pdas])

			-- Remove duplicates
            DECLARE @table_count_before int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_configuration])
			DELETE x FROM (
				SELECT *, rn=row_number() OVER (PARTITION BY [type], [variable] ORDER BY [type], [variable])
				FROM [dbo].[mc_temp_pdas_footwear_vans_configuration]
			) x
			WHERE rn > 1;
            DECLARE @table_count_after int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_configuration])

            IF @table_count_before = @table_count_after
            BEGIN

    			-- Delete removed rows (secured by PK constraint)
    			DELETE FROM [dbo].[helper_pdas_footwear_vans_configuration]

    			-- Insert new rows
    			INSERT INTO [dbo].[helper_pdas_footwear_vans_configuration]
				(
					[type],
					[variable],
					[value]
				)
    			SELECT
					[type],
					[variable],
					[value]
    			FROM [dbo].[mc_temp_pdas_footwear_vans_configuration]

				UPDATE [dbo].[dim_pdas]
				SET
					[comment] =
						(
							SELECT TOP 1 [value]
							FROM [dbo].[mc_temp_pdas_footwear_vans_configuration]
							WHERE [type] = 'System' AND [variable] = 'Release Note'
						)
					,[buy_month] =
						(
							SELECT TOP 1 [value]
							FROM [dbo].[mc_temp_pdas_footwear_vans_configuration]
							WHERE [type] = 'System' AND [variable] = 'Buy Month'
						)
					,[dim_buying_program_id] =
						(
							SELECT TOP 1 dbp.[id]
							FROM
								[dbo].[mc_temp_pdas_footwear_vans_configuration] temp
								INNER JOIN [dbo].[dim_buying_program] dbp
									ON temp.[value] = dbp.[name]
							WHERE [type] = 'System' AND [variable] = 'Buying Program Name'
						)
				WHERE [id] = @dim_pdas_id

            END
    		ELSE
    		BEGIN

    			SET @output_param = 'Duplicated variables found. Not allowed by PDAS.'
    			RETURN -999

    		END

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
