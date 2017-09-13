USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to edit the mapping table.
-- =============================================
ALTER PROCEDURE [dbo].[mc_table_pdas_footwear_vans_mapping]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_mapping]) > 0
	BEGIN

		-- Validate submitted data based on pre-defined business rules
		DECLARE @test nvarchar(500) =
		(
			SELECT TOP 1
				ISNULL(temp.[Type], '') + ' / ' +
				ISNULL(temp.[Parent], '') + ' / ' +
				ISNULL(temp.[Child], '') + ' / ' +
				ISNULL(temp.[Description], '')
			FROM [dbo].[mc_temp_pdas_footwear_vans_mapping] temp
			WHERE
                ([Type] = 'Factory Master' and [Parent] NOT IN (SELECT DISTINCT [short_name] FROM [dbo].[dim_factory]))
                OR
                ([Type] = 'Customer Master' and [Parent] NOT IN (SELECT DISTINCT [name] FROM [dbo].[dim_customer]))
                OR
                [Type] NOT IN (
                    'Factory Master',
                    'Customer Master'
                )
		)

		IF @test IS NULL
		BEGIN

			-- Remove duplicates
            DECLARE @table_count_before int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_mapping])
			DELETE x FROM (
				SELECT *, rn=row_number() OVER (PARTITION BY [Type], [Child] ORDER BY [Type], [Child])
				FROM [dbo].[mc_temp_pdas_footwear_vans_mapping]
			) x
			WHERE rn > 1;
            DECLARE @table_count_after int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_mapping])

            IF @table_count_before = @table_count_after
            BEGIN

    			-- Delete removed rows (secured by PK constraint)
    			DELETE dim
    			FROM
    				[dbo].[helper_pdas_footwear_vans_mapping] dim
    				LEFT JOIN [dbo].[mc_temp_pdas_footwear_vans_mapping] temp
                        ON  dim.[Type]= temp.[Type] and
                            dim.[Parent] = temp.[Parent] and
                            dim.[Child] = temp.[Child]
    			WHERE temp.[Type] IS NULL

    			-- Insert new rows
    			INSERT INTO [dbo].[helper_pdas_footwear_vans_mapping]
                SELECT t1.*
    			FROM
    				[dbo].[temp_mapping] t1
    				LEFT OUTER JOIN [dbo].[helper_mapping] t2
                        ON  dim.[Type]= temp.[Type] and
                            dim.[Parent] = temp.[Parent] and
                            dim.[Child] = temp.[Child]
    			WHERE temp.[Type] IS NULL

            END
    		ELSE
    		BEGIN

    			SET @output_param = 'Child value of same Type assigned to multiple Parent. Not allowed by PDAS.'
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
