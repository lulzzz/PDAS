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

			DECLARE @dim_pdas_id int
			SELECT @dim_pdas_id = MAX([id]) FROM [dbo].[dim_pdas]

			-- Remove duplicates
            DECLARE @table_count_before int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_configuration])
			DELETE x FROM (
				SELECT *, rn=row_number() OVER (PARTITION BY [variable] ORDER BY [variable])
				FROM [dbo].[mc_temp_pdas_footwear_vans_configuration]
			) x
			WHERE rn > 1;
            DECLARE @table_count_after int = (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_configuration])

            IF @table_count_before = @table_count_after
            BEGIN

    			-- Delete removed rows (secured by PK constraint)
    			DELETE FROM [dbo].[fact_configuration]
				WHERE [dim_pdas_id] = @dim_pdas_id

    			-- Insert new rows
    			INSERT INTO [dbo].[fact_configuration]
				(
					[dim_pdas_id],
					[type],
					[variable],
					[value]
				)
    			SELECT
					@dim_pdas_id,
					[type],
					[variable],
					[value]
    			FROM [dbo].[mc_temp_pdas_footwear_vans_configuration]

            END
    		ELSE
    		BEGIN

    			SET @output_param = 'Duplicated variables found. Not allowed by PDAS.'
    			RETURN -999

    		END

	END
	ELSE
	BEGIN

		SET @output_param = 'Table is empty.'
		RETURN -999

	END

END
