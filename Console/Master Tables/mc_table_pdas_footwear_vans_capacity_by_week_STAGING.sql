USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to edit the weekly factory capacity.
-- =============================================
ALTER PROCEDURE [dbo].[mc_table_pdas_footwear_vans_capacity_by_week]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_pdas_footwear_vans_capacity_by_week]) > 0
	BEGIN

		-- Validate submitted data based on pre-defined business rules
		DECLARE @test nvarchar(500) =
		(
			SELECT TOP 1
				ISNULL(temp.[Construction Type], '') + ' / ' +
				ISNULL(temp.[Factory Code], '') + ' / ' +
				ISNULL(temp.[Year], '')
			FROM
				[dbo].[mc_temp_pdas_footwear_vans_capacity_by_week] temp
				LEFT JOIN (SELECT DISTINCT [name], 1 as flag FROM [dbo].[dim_construction_type]) dim_ct
					ON 	UPPER(temp.[Construction Type]) = UPPER(dim_ct.[name])
				LEFT JOIN (SELECT DISTINCT [short_name], 1 as flag FROM [dbo].[dim_factory]) dim_f
					ON 	UPPER(temp.[Factory Code]) = UPPER(dim_f.[short_name])
			WHERE
				ISNULL(dim_ct.[flag],0) = 0 OR
				ISNULL(dim_f.[flag],0) = 0 OR
				temp.[Year] BETWEEN 2010 AND 2050
		)

		IF @test IS NULL
		BEGIN

			-- Remove duplicates
			DELETE x FROM (
				SELECT *, rn=row_number() OVER (PARTITION BY [Construction Type], [Factory Code], [Year] ORDER BY [Construction Type], [Factory Code], [Year])
				FROM [dbo].[mc_temp_pdas_footwear_vans_capacity_by_week]
			) x
			WHERE rn > 1;

			-- Delete removed rows (secured by PK constraint)
			DELETE dim
			FROM
				[dbo].[helper_pdas_footwear_vans_capacity_by_week] dim
				INNER JOIN [dbo].[mc_temp_pdas_footwear_vans_capacity_by_week] temp
					ON	dim.[Construction Type] = temp.[Construction Type]
						and dim.[Factory Code] = temp.[Factory Code]
						and dim.[Year] = temp.[Year]
			WHERE temp.[Factory Code] IS NULL

			-- Insert new rows
			INSERT INTO [dbo].[helper_pdas_footwear_vans_capacity_by_week]
			SELECT temp.*
			FROM
				[dbo].[mc_temp_pdas_footwear_vans_capacity_by_week] temp
				LEFT JOIN [dbo].[helper_pdas_footwear_vans_capacity_by_week] dim
					ON	temp.[Construction Type] = dim.[Construction Type]
						and temp.[Factory Code] = dim.[Factory Code]
						and temp.[Year] = dim.[Year]
			WHERE dim.[Factory Code] IS NULL

			-- Update existing rows
			UPDATE dim
			SET
				 dim.[Total Available Capacity WK01] = temp.[Total Available Capacity WK01]
				,dim.[Total Available Capacity WK02] = temp.[Total Available Capacity WK02]
				,dim.[Total Available Capacity WK03] = temp.[Total Available Capacity WK03]
				,dim.[Total Available Capacity WK04] = temp.[Total Available Capacity WK04]
				,dim.[Total Available Capacity WK05] = temp.[Total Available Capacity WK05]
				,dim.[Total Available Capacity WK06] = temp.[Total Available Capacity WK06]
				,dim.[Total Available Capacity WK07] = temp.[Total Available Capacity WK07]
				,dim.[Total Available Capacity WK08] = temp.[Total Available Capacity WK08]
				,dim.[Total Available Capacity WK09] = temp.[Total Available Capacity WK09]
				,dim.[Total Available Capacity WK10] = temp.[Total Available Capacity WK10]
				,dim.[Total Available Capacity WK11] = temp.[Total Available Capacity WK11]
				,dim.[Total Available Capacity WK12] = temp.[Total Available Capacity WK12]
				,dim.[Total Available Capacity WK13] = temp.[Total Available Capacity WK13]
				,dim.[Total Available Capacity WK14] = temp.[Total Available Capacity WK14]
				,dim.[Total Available Capacity WK15] = temp.[Total Available Capacity WK15]
				,dim.[Total Available Capacity WK16] = temp.[Total Available Capacity WK16]
				,dim.[Total Available Capacity WK17] = temp.[Total Available Capacity WK17]
				,dim.[Total Available Capacity WK18] = temp.[Total Available Capacity WK18]
				,dim.[Total Available Capacity WK19] = temp.[Total Available Capacity WK19]
				,dim.[Total Available Capacity WK20] = temp.[Total Available Capacity WK20]
				,dim.[Total Available Capacity WK21] = temp.[Total Available Capacity WK21]
				,dim.[Total Available Capacity WK22] = temp.[Total Available Capacity WK22]
				,dim.[Total Available Capacity WK23] = temp.[Total Available Capacity WK23]
				,dim.[Total Available Capacity WK24] = temp.[Total Available Capacity WK24]
				,dim.[Total Available Capacity WK25] = temp.[Total Available Capacity WK25]
				,dim.[Total Available Capacity WK26] = temp.[Total Available Capacity WK26]
				,dim.[Total Available Capacity WK27] = temp.[Total Available Capacity WK27]
				,dim.[Total Available Capacity WK28] = temp.[Total Available Capacity WK28]
				,dim.[Total Available Capacity WK29] = temp.[Total Available Capacity WK29]
				,dim.[Total Available Capacity WK30] = temp.[Total Available Capacity WK30]
				,dim.[Total Available Capacity WK31] = temp.[Total Available Capacity WK31]
				,dim.[Total Available Capacity WK32] = temp.[Total Available Capacity WK32]
				,dim.[Total Available Capacity WK33] = temp.[Total Available Capacity WK33]
				,dim.[Total Available Capacity WK34] = temp.[Total Available Capacity WK34]
				,dim.[Total Available Capacity WK35] = temp.[Total Available Capacity WK35]
				,dim.[Total Available Capacity WK36] = temp.[Total Available Capacity WK36]
				,dim.[Total Available Capacity WK37] = temp.[Total Available Capacity WK37]
				,dim.[Total Available Capacity WK38] = temp.[Total Available Capacity WK38]
				,dim.[Total Available Capacity WK39] = temp.[Total Available Capacity WK39]
				,dim.[Total Available Capacity WK40] = temp.[Total Available Capacity WK40]
				,dim.[Total Available Capacity WK41] = temp.[Total Available Capacity WK41]
				,dim.[Total Available Capacity WK42] = temp.[Total Available Capacity WK42]
				,dim.[Total Available Capacity WK43] = temp.[Total Available Capacity WK43]
				,dim.[Total Available Capacity WK44] = temp.[Total Available Capacity WK44]
				,dim.[Total Available Capacity WK45] = temp.[Total Available Capacity WK45]
				,dim.[Total Available Capacity WK46] = temp.[Total Available Capacity WK46]
				,dim.[Total Available Capacity WK47] = temp.[Total Available Capacity WK47]
				,dim.[Total Available Capacity WK48] = temp.[Total Available Capacity WK48]
				,dim.[Total Available Capacity WK49] = temp.[Total Available Capacity WK49]
				,dim.[Total Available Capacity WK50] = temp.[Total Available Capacity WK50]
				,dim.[Total Available Capacity WK51] = temp.[Total Available Capacity WK51]
				,dim.[Total Available Capacity WK52] = temp.[Total Available Capacity WK52]
			FROM
				[dbo].[helper_pdas_footwear_vans_capacity_by_week] dim
				INNER JOIN [dbo].[mc_temp_pdas_footwear_vans_capacity_by_week] temp
					ON	dim.[Construction Type] = temp.[Construction Type]
						and dim.[Factory Code] = temp.[Factory Code]
						and dim.[Year] = temp.[Year]

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
