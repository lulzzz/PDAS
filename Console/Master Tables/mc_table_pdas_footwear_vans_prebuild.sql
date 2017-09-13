USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to edit the prebuild balance table.
-- =============================================
ALTER PROCEDURE [dbo].[mc_table_pdas_footwear_vans_prebuild]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_prebuild]) > 0
	BEGIN

		-- Validate submitted data based on pre-defined business rules
		DECLARE @test nvarchar(500) =
		(
			SELECT TOP 1
                ISNULL(temp.[Region], '')  + ' / ' +
                ISNULL(temp.[MTL], '')  + ' / ' +
                ISNULL(temp.[Size], '')  + ' / ' +
                ISNULL(temp.[Factory], '')  + ' / ' +
                ISNULL(temp.[Current Balance Date], '')  + ' / ' +
                ISNULL(temp.[Current Balance], '')  + ' / ' +
                ISNULL(temp.[Buying Program], '')  + ' / ' +
                ISNULL(temp.[Status], '')  + ' / ' +
                ISNULL(temp.[Cancellation Cost per Unit], '')
			FROM [dbo].[mc_temp_pdas_footwear_vans_prebuild]  temp
                LEFT JOIN (SELECT DISTINCT [region], 1 as flag FROM [dbo].[dim_location]) dim_l
                    ON 	UPPER(temp.[Region]) = UPPER(dim_l.[region])
				LEFT JOIN (SELECT DISTINCT [short_name], 1 as flag FROM [dbo].[dim_factory]) dim_f
                    ON 	UPPER(temp.[Factory]) = UPPER(dim_f.[short_name])
                LEFT JOIN (SELECT DISTINCT [name], 1 as flag FROM [dbo].[dim_buying_program]) dim_bp
                    ON 	UPPER(temp.[Buying Program]) = UPPER(dim_bp.[name])
                LEFT JOIN (SELECT [material_id], [size], 1 as flag FROM [dbo].[dim_product]) dim_p
                    ON 	temp.[MTL] = dim_p.[material_id]
                        AND temp.[Size] = dim_p.[size]
            WHERE
				ISNULL(dim_l.[flag], 0) = 0 OR
				ISNULL(dim_f.[flag], 0) = 0 OR
                ISNULL(dim_bp.[flag], 0) = 0 OR
                ISNULL(dim_p.[flag], 0) = 0
        )

		IF @test IS NULL
		BEGIN

			-- Remove duplicates
            DECLARE @table_count_before int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_prebuild])
			DELETE x FROM (
				SELECT *, rn=row_number() OVER (PARTITION BY [Region], [MTL], [Size], [Factory], [Buying Program] ORDER BY [Region], [MTL], [Size], [Factory], [Buying Program])
				FROM [dbo].[mc_temp_pdas_footwear_vans_prebuild]
			) x
			WHERE rn > 1;
            DECLARE @table_count_after int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_prebuild])

            IF @table_count_before = @table_count_after
            BEGIN

    			-- Delete removed rows (secured by PK constraint)
    			DELETE FROM [dbo].[helper_pdas_footwear_vans_prebuild]

    			-- Insert new rows
    			INSERT INTO [dbo].[helper_pdas_footwear_vans_prebuild]
    			SELECT * FROM [dbo].[mc_temp_pdas_footwear_vans_prebuild] temp

            END
    		ELSE
    		BEGIN

    			SET @output_param = 'Duplicated Customer/Product Type combinations. Not allowed by PDAS.'
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
