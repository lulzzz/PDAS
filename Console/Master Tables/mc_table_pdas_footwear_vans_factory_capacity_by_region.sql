USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to edit the factory capacity by region table.
-- =============================================
ALTER PROCEDURE [dbo].[mc_table_pdas_footwear_vans_factory_capacity_by_region]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_factory_capacity_by_region]) > 0
	BEGIN

		-- Validate submitted data based on pre-defined business rules
		DECLARE @test nvarchar(500) =
		(
			SELECT TOP 1
                ISNULL([Factory], '')
			FROM [dbo].[mc_temp_pdas_footwear_vans_factory_capacity_by_region] temp
                LEFT JOIN (SELECT DISTINCT [short_name], 1 as flag FROM [dbo].[dim_factory]) dim_f
                    ON 	UPPER(temp.[Factory]) = UPPER(dim_f.[short_name])
            WHERE
				ISNULL(dim_f.[flag], 0) = 0 OR
                (ISNULL([EMEA], 0) + ISNULL([NORA], 0) + ISNULL([CASA], 0) + ISNULL([APAC], 0) <> 1)
        )

		IF @test IS NULL
		BEGIN

			-- Remove duplicates
            DECLARE @table_count_before int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_factory_capacity_by_region])
			DELETE x FROM (
				SELECT *, rn=row_number() OVER (PARTITION BY [Factory] ORDER BY [Factory])
				FROM [dbo].[mc_temp_pdas_footwear_vans_factory_capacity_by_region]
			) x
			WHERE rn > 1;
            DECLARE @table_count_after int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_factory_capacity_by_region])

            IF @table_count_before = @table_count_after
            BEGIN

    			-- Delete removed rows (secured by PK constraint)
    			DELETE FROM [dbo].[helper_pdas_footwear_vans_factory_capacity_by_region]

    			-- Insert new rows
    			INSERT INTO [dbo].[helper_pdas_footwear_vans_factory_capacity_by_region]
    			SELECT * FROM [dbo].[mc_temp_pdas_footwear_vans_factory_capacity_by_region]

            END
    		ELSE
    		BEGIN

    			SET @output_param = 'Duplicated factory. Not allowed by PDAS.'
    			RETURN -999

    		END

		END
		ELSE
		BEGIN

			SET @output_param = 'Row ' + @test + ' is invalid.' + '<br />' +
			'Either factory code not in master data or sum of percentages not equal to 1.'
			RETURN -999

		END

	END
	ELSE
	BEGIN

		SET @output_param = 'Table is empty.'
		RETURN -999

	END

END
