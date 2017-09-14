USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to edit the MOQ policy table.
-- =============================================
ALTER PROCEDURE [dbo].[mc_table_pdas_footwear_vans_moq_policy]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_moq_policy]) > 0
	BEGIN

		-- Validate submitted data based on pre-defined business rules
		DECLARE @test nvarchar(500) =
		(
			SELECT TOP 1
                ISNULL([Product Type], '')
			FROM [dbo].[mc_temp_pdas_footwear_vans_moq_policy]  temp
                LEFT JOIN (SELECT DISTINCT [type], 1 as flag FROM [dbo].[dim_product]) dim_p
                    ON 	temp.[Product Type] = dim_p.[type]
            WHERE
                (
					ISNULL(dim_p.[flag], 0) = 0
					AND
					UPPER([Product Type]) NOT IN ('REGULAR', 'VAULT')
				)
        )

		IF @test IS NULL
		BEGIN

			-- Remove duplicates
            DECLARE @table_count_before int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_moq_policy])
			DELETE x FROM (
				SELECT *, rn=row_number() OVER (PARTITION BY [Product Type], [From by Region], [To by Region], [From by Customer], [To by Customer] ORDER BY [Product Type], [From by Region], [To by Region], [From by Customer], [To by Customer])
				FROM [dbo].[mc_temp_pdas_footwear_vans_moq_policy]
			) x
			WHERE rn > 1;
            DECLARE @table_count_after int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_moq_policy])

            IF @table_count_before = @table_count_after
            BEGIN

    			-- Delete removed rows (secured by PK constraint)
    			DELETE FROM [dbo].[helper_pdas_footwear_vans_moq_policy]

    			-- Insert new rows
    			INSERT INTO [dbo].[helper_pdas_footwear_vans_moq_policy]
    			SELECT * FROM [dbo].[mc_temp_pdas_footwear_vans_moq_policy]

            END
    		ELSE
    		BEGIN

    			SET @output_param = 'Duplicated combinations found. Not allowed by PDAS.'
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
