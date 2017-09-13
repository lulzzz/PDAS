USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to edit the label upcharge table.
-- =============================================
ALTER PROCEDURE [dbo].[mc_table_pdas_footwear_vans_label_upcharge]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_label_upcharge]) > 0
	BEGIN

		-- Validate submitted data based on pre-defined business rules
		DECLARE @test nvarchar(500) =
		(
			SELECT TOP 1
                ISNULL([Customer], '')  + ' / ' +
                ISNULL([Product Type], '')
			FROM [dbo].[mc_temp_pdas_footwear_vans_label_upcharge]  temp
                LEFT JOIN (SELECT [name], 1 as flag FROM [dbo].[dim_customer]) dim_c
                    ON 	UPPER(temp.[Customer]) = UPPER(dim_c.[name])
            WHERE
				ISNULL(dim_c.[flag],0) = 0
                OR
                UPPER([Product Type]) NOT IN (
                    'SHOES',
                    'SANDAL',
                    'ALL'
                )
                OR
                [Label Upcharge] NOT BETWEEN 0 AND 1
        )

		IF @test IS NULL
		BEGIN

			-- Remove duplicates
            DECLARE @table_count_before int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_label_upcharge])
			DELETE x FROM (
				SELECT *, rn=row_number() OVER (PARTITION BY [Customer], [Product Type] ORDER BY [Customer], [Product Type])
				FROM [dbo].[mc_temp_pdas_footwear_vans_label_upcharge]
			) x
			WHERE rn > 1;
            DECLARE @table_count_after int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_label_upcharge])

            IF @table_count_before = @table_count_after
            BEGIN

    			-- Delete removed rows (secured by PK constraint)
    			DELETE FROM [dbo].[helper_pdas_footwear_vans_label_upcharge]

    			-- Insert new rows
    			INSERT INTO [dbo].[helper_pdas_footwear_vans_label_upcharge]
    			SELECT * FROM [dbo].[mc_temp_pdas_footwear_vans_label_upcharge]

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
