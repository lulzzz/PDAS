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
ALTER PROCEDURE [dbo].[mc_table_pdas_footwear_vans_retail_qt]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_retail_qt]) > 0
	BEGIN

		-- Update buying program name in case user used short name
		UPDATE temp
		SET temp.[Buying Program] = dim_bp.[name]
		FROM
			[dbo].[mc_temp_pdas_footwear_vans_retail_qt] temp
			INNER JOIN [dbo].[dim_buying_program] dim_bp
				ON LTRIM(RTRIM(temp.[Buying Program])) = dim_bp.[name_short]

		-- Validate submitted data based on pre-defined business rules
		DECLARE @test nvarchar(500) =
		(
			SELECT TOP 1
                ISNULL([Status], '')  + ' / ' +
                ISNULL([MTL], '')  + ' / ' +
                ISNULL([Factory], '')  + ' / ' +
                ISNULL([Buying Program], '')
			FROM [dbo].[mc_temp_pdas_footwear_vans_retail_qt]  temp
                LEFT JOIN (SELECT DISTINCT [material_id], 1 as flag FROM [dbo].[dim_product]) dim_p
                    ON 	temp.[MTL] = dim_p.[material_id]
                LEFT JOIN (SELECT DISTINCT [short_name], 1 as flag FROM [dbo].[dim_factory]) dim_f
                    ON 	UPPER(temp.[Factory]) = UPPER(dim_f.[short_name])
                LEFT JOIN (SELECT DISTINCT [name], 1 as flag FROM [dbo].[dim_buying_program]) dim_bp
                    ON 	UPPER(temp.[Buying Program]) = UPPER(dim_bp.[name])
            WHERE
				ISNULL(dim_f.[flag], 0) = 0 OR
                ISNULL(dim_p.[flag], 0) = 0 OR
                ISNULL(dim_bp.[flag], 0) = 0 OR
                UPPER([Status]) NOT IN (
                    'DROPPED',
                    'ACTIVE',
                    'REJECTED'
                )
        )

		IF @test IS NULL
		BEGIN

			-- Remove duplicates
            DECLARE @table_count_before int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_retail_qt])
			DELETE x FROM (
				SELECT *, rn=row_number() OVER (PARTITION BY [MTL], [Factory], [Buying Program] ORDER BY [MTL], [Factory], [Buying Program])
				FROM [dbo].[mc_temp_pdas_footwear_vans_retail_qt]
			) x
			WHERE rn > 1;
            DECLARE @table_count_after int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_retail_qt])

            IF @table_count_before = @table_count_after
            BEGIN

    			-- Delete removed rows (secured by PK constraint)
    			DELETE FROM [dbo].[helper_pdas_footwear_vans_retail_qt]

    			-- Insert new rows
    			INSERT INTO [dbo].[helper_pdas_footwear_vans_retail_qt]
    			SELECT * FROM [dbo].[mc_temp_pdas_footwear_vans_retail_qt]

            END
    		ELSE
    		BEGIN

    			SET @output_param = 'Duplicated MTL/Factory/Buying Program combinations. Not allowed by PDAS.'
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
