USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to edit the retail quick turn table.
-- =============================================
ALTER PROCEDURE [dbo].[mc_table_pdas_footwear_vans_cutoff]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_cutoff]) > 0
	BEGIN

		-- Validate submitted data based on pre-defined business rules
		DECLARE @test nvarchar(500) =
		(
			SELECT TOP 1
                ISNULL(temp.[Country], '')  + ' / ' +
                ISNULL(temp.[Port Code], '')  + ' / ' +
                ISNULL(temp.[Season Year], '')  + ' / ' +
                ISNULL(temp.[Cutoff Weekday], '')
			FROM [dbo].[mc_temp_pdas_footwear_vans_cutoff]  temp
                LEFT JOIN (SELECT DISTINCT [country], 1 as flag FROM [dbo].[dim_location]) dim_l
                    ON 	UPPER(temp.[Country]) = UPPER(dim_l.[country])
                LEFT JOIN (SELECT DISTINCT [season_year_accounting], 1 as flag FROM [dbo].[dim_date]) dim_d
                    ON 	UPPER(temp.[Season Year]) = UPPER(dim_d.[season_year_accounting])
                LEFT JOIN (SELECT DISTINCT [day_name_of_week], 1 as flag FROM [dbo].[dim_date]) dim_d2
                    ON 	UPPER(temp.[Cutoff Weekday]) = UPPER(dim_d2.[day_name_of_week])
            WHERE
				ISNULL(dim_l.[flag], 0) = 0 OR
                ISNULL(dim_d.[flag], 0) = 0 OR
                ISNULL(dim_d2.[flag], 0) = 0
        )

		IF @test IS NULL
		BEGIN

			-- Remove duplicates
            DECLARE @table_count_before int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_cutoff])
			DELETE x FROM (
				SELECT *, rn=row_number() OVER (PARTITION BY [Port Code], [Season Year] ORDER BY [Port Code], [Season Year])
				FROM [dbo].[mc_temp_pdas_footwear_vans_cutoff]
			) x
			WHERE rn > 1;
            DECLARE @table_count_after int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_cutoff])

            IF @table_count_before = @table_count_after
            BEGIN

    			-- Delete removed rows (secured by PK constraint)
    			DELETE dim
    			FROM
    				[dbo].[helper_pdas_footwear_vans_cutoff]

    			-- Insert new rows
    			INSERT INTO [dbo].[helper_pdas_footwear_vans_cutoff]
    			SELECT *
    			FROM
    				[dbo].[mc_temp_pdas_footwear_vans_cutoff]

            END
    		ELSE
    		BEGIN

    			SET @output_param = 'Duplicated Port Code/Season Year combinations. Not allowed by PDAS.'
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
