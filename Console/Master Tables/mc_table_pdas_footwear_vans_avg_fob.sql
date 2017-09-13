USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to edit the average FOB table.
-- =============================================
ALTER PROCEDURE [dbo].[mc_table_pdas_footwear_vans_moq_policy]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_avg_fob]) > 0
	BEGIN

		-- Validate submitted data based on pre-defined business rules
		DECLARE @test nvarchar(500) =
		(
			SELECT TOP 1
                ISNULL([MTL], '')
			FROM [dbo].[mc_temp_pdas_footwear_vans_avg_fob]  temp
                LEFT JOIN (SELECT DISTINCT [material_id], 1 as flag FROM [dbo].[dim_product]) dim_p
                    ON 	temp.[MTL] = dim_p.[material_id]
            WHERE
                ISNULL(dim_p.[flag], 0) = 0
        )

		IF @test IS NULL
		BEGIN

			-- Remove duplicates
            DECLARE @table_count_before int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_avg_fob])
			DELETE x FROM (
				SELECT *, rn=row_number() OVER (PARTITION BY [MTL] ORDER BY [MTL])
				FROM [dbo].[mc_temp_pdas_footwear_vans_avg_fob]
			) x
			WHERE rn > 1;
            DECLARE @table_count_after int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_avg_fob])

            IF @table_count_before = @table_count_after
            BEGIN

    			-- Delete removed rows (secured by PK constraint)
    			DELETE FROM [dbo].[helper_pdas_footwear_vans_avg_fob]

    			-- Insert new rows
    			INSERT INTO [dbo].[helper_pdas_footwear_vans_avg_fob]
    			SELECT * FROM [dbo].[mc_temp_pdas_footwear_vans_avg_fob]

            END
    		ELSE
    		BEGIN

    			SET @output_param = 'Duplicated MTL found. Not allowed by PDAS.'
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
