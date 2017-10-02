USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to edit the factory capacity adjustment table.
-- =============================================
ALTER PROCEDURE [dbo].[mc_table_pdas_footwear_vans_factory_capacity_adjustment]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_factory_capacity_adjustment]) > 0
	BEGIN

		-- Validate submitted data based on pre-defined business rules
		DECLARE @test nvarchar(500) =
		(
			SELECT TOP 1
                ISNULL([Factory], '')
			FROM [dbo].[mc_temp_pdas_footwear_vans_factory_capacity_adjustment] temp
                LEFT JOIN (SELECT DISTINCT [short_name], 1 as flag FROM [dbo].[dim_factory]) dim_f
                    ON 	UPPER(temp.[Factory]) = UPPER(dim_f.[short_name])
            WHERE
				ISNULL(dim_f.[flag], 0) = 0
        )

		IF @test IS NULL
		BEGIN

			-- Remove duplicates
            DECLARE @table_count_before int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_factory_capacity_adjustment])
			DELETE x FROM (
				SELECT *, rn=row_number() OVER (PARTITION BY [Factory] ORDER BY [Factory])
				FROM [dbo].[mc_temp_pdas_footwear_vans_factory_capacity_adjustment]
			) x
			WHERE rn > 1;
            DECLARE @table_count_after int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_factory_capacity_adjustment])

            IF @table_count_before = @table_count_after
            BEGIN

    			-- Delete removed rows (secured by PK constraint)
    			DELETE FROM [dbo].[helper_pdas_footwear_vans_factory_capacity_adjustment]

    			-- Insert new rows
    			INSERT INTO [dbo].[helper_pdas_footwear_vans_factory_capacity_adjustment]
    			SELECT * FROM [dbo].[mc_temp_pdas_footwear_vans_factory_capacity_adjustment]

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
			'Factory code not in master data.'
			RETURN -999

		END

	END
	ELSE
	BEGIN

		SET @output_param = 'Table is empty.'
		RETURN -999

	END

END
