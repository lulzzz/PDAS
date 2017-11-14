USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_WARNINGS OFF
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 13/10/2017
-- Description:	Allocation sub procedure China DC (W100)
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_allocation_sub07]
	@pdasid INT,
	@businessid INT,
	@dim_buying_program_id INT,
	@dim_product_id INT,
	@dim_product_material_id NVARCHAR(45),
	@dim_product_style_complexity NVARCHAR(45),
	@dim_date_id INT,
	@dim_customer_id INT,
	@dim_demand_category_id INT,
	@order_number NVARCHAR(45),
	@allocation_logic NVARCHAR(1000)
AS
BEGIN
	SET NOCOUNT ON;

    /* Variable declarations */
	DECLARE @dim_factory_id_original_unconstrained_02 INT = NULL
	DECLARE @dim_factory_name_priority_list_primary_02 NVARCHAR(45)
	DECLARE @helper_retail_qt_rqt_vendor_02 NVARCHAR(45)
	DECLARE @fact_priority_list_source_count_02 INT = 0
	DECLARE @dim_location_country_code_a2_02 NVARCHAR(2)
	DECLARE @dim_factory_name_priority_list_secondary_02 NVARCHAR(45)
	DECLARE @dim_product_clk_mtl SMALLINT
	DECLARE @dim_product_dtp_mtl SMALLINT
	DECLARE @dim_product_sjd_mtl SMALLINT

	/* Variable assignments */

	SET @dim_factory_name_priority_list_primary_02 =
	(
		SELECT df.[short_name]
		FROM
			(
				SELECT [dim_factory_id_1]
				FROM [dbo].[fact_priority_list] f
					INNER JOIN (SELECT [id], [material_id] FROM [dbo].[dim_product] WHERE [is_placeholder] = 1) dp
	                	ON f.[dim_product_id] = dp.[id]
				WHERE [material_id] = @dim_product_material_id
			) fpl
			INNER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory]) df
				ON fpl.[dim_factory_id_1] = df.[id]
	)

	SET @dim_factory_name_priority_list_secondary_02 =
	(
		SELECT df.[short_name]
		FROM
			(
				SELECT [dim_factory_id_2]
				FROM [dbo].[fact_priority_list] f
					INNER JOIN (SELECT [id], [material_id] FROM [dbo].[dim_product] WHERE [is_placeholder] = 1) dp
	                	ON f.[dim_product_id] = dp.[id]
				WHERE [material_id] = @dim_product_material_id
			) AS fpl
			INNER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory]) df
				ON fpl.[dim_factory_id_2] = df.[id]
	)

	SET @dim_product_clk_mtl =
	(
		SELECT ISNULL([clk_mtl], 0)
		FROM [dbo].[dim_product]
		WHERE [id] = @dim_product_id
	)

	SET @dim_product_dtp_mtl =
	(
		SELECT ISNULL([dtp_mtl], 0)
		FROM [dbo].[dim_product]
		WHERE [id] = @dim_product_id
	)

	SET @dim_product_sjd_mtl =
	(
		SELECT ISNULL([sjd_mtl], 0)
		FROM [dbo].[dim_product]
		WHERE [id] = @dim_product_id
	)

	SET @helper_retail_qt_rqt_vendor_02 =
	(
		SELECT MAX([Factory])
		FROM [dbo].[helper_pdas_footwear_vans_retail_qt]
		WHERE [MTL] = @dim_product_material_id
	)

	IF @dim_factory_name_priority_list_primary_02 IS NOT NULL
	BEGIN
		SET @fact_priority_list_source_count_02 = @fact_priority_list_source_count_02 + 1
	END
	IF @dim_factory_name_priority_list_secondary_02 IS NOT NULL
	BEGIN
		SET @fact_priority_list_source_count_02 = @fact_priority_list_source_count_02 + 1
	END

	SET @dim_location_country_code_a2_02 =
	(
		SELECT dfl.[dim_location_country_code_a2]
		FROM
			(
				SELECT [dim_factory_id_1]
				FROM [dbo].[fact_priority_list] f
					INNER JOIN (SELECT [id], [material_id] FROM [dbo].[dim_product] WHERE [is_placeholder] = 1) dp
	                	ON f.[dim_product_id] = dp.[id]
				WHERE [material_id] = @dim_product_material_id
			) AS fpl
			INNER JOIN
			(
				SELECT df.[id], dl.[country_code_a2] AS [dim_location_country_code_a2]
				FROM [dbo].[dim_factory] df
				INNER JOIN [dbo].[dim_location] dl
					ON df.[dim_location_id] = dl.[id]
			) dfl
				ON fpl.[dim_factory_id_1] = dfl.[id]
	)

	/* Sub decision tree logic */

	-- Flex?
	IF @dim_product_style_complexity LIKE '%Flex%' AND @dim_factory_name_priority_list_primary_02 = 'ICC'
	BEGIN
		SET @dim_factory_id_original_unconstrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_primary_02)
		SET @allocation_logic = @allocation_logic +' => ' + 'Flex'
	END

	ELSE IF @dim_product_style_complexity LIKE '%Flex%' AND @dim_factory_name_priority_list_primary_02 = 'DTC'
	BEGIN
		SET @dim_factory_id_original_unconstrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_primary_02)
		SET @allocation_logic = @allocation_logic +' => ' + 'Flex'
	END

	ELSE IF @dim_product_style_complexity LIKE '%Flex%' AND @dim_factory_name_priority_list_primary_02 = 'SJV'
	BEGIN
		SET @dim_factory_id_original_unconstrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = 'HSC')
		SET @allocation_logic = @allocation_logic +' => ' + 'Flex'
	END

	-- RQT MTL?
	ELSE IF @dim_product_material_id IN (SELECT [MTL] FROM [dbo].[helper_pdas_footwear_vans_retail_qt])
	BEGIN
		SET @dim_factory_id_original_unconstrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = 'HSC')
		SET @allocation_logic = @allocation_logic +' => ' + @helper_retail_qt_rqt_vendor_02 + ' RQT MTL'
	END

	-- Single Source?
	ELSE IF @fact_priority_list_source_count_02 = 1 AND (@dim_product_clk_mtl + @dim_product_dtp_mtl + @dim_product_sjd_mtl) <= 1
	BEGIN
		SET @dim_factory_id_original_unconstrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_primary_02)
		SET @allocation_logic = @allocation_logic +' => ' + 'Single Source'
	END

	-- 1st priority = COO China?
	ELSE IF @dim_location_country_code_a2_02 = 'CN'
	BEGIN
		SET @dim_factory_id_original_unconstrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_primary_02)
		SET @allocation_logic = @allocation_logic +' => ' + '1st priority = COO China' +' => ' +'First priority'
		IF @dim_factory_name_priority_list_primary_02 IS NOT NULL
		BEGIN
			SET @allocation_logic = @allocation_logic +' => ' + @dim_factory_name_priority_list_primary_02
		END
	END

	-- 2nd priority = CLK?
	ELSE IF @dim_factory_name_priority_list_secondary_02 = 'CLK'
	BEGIN
		SET @dim_factory_id_original_unconstrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_secondary_02)
		SET @allocation_logic = @allocation_logic +' => ' + '2nd priority = CLK' +' => ' +'Second priority'
		IF @dim_factory_name_priority_list_secondary_02 IS NOT NULL
		BEGIN
			SET @allocation_logic = @allocation_logic +' => ' + @dim_factory_name_priority_list_secondary_02
		END
	END

	ELSE
	BEGIN
		SET @dim_factory_id_original_unconstrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_primary_02)
		SET @allocation_logic = @allocation_logic +' => ' + '2nd priority = not CLK' +' => ' +'First priority'
		IF @dim_factory_name_priority_list_primary_02 IS NOT NULL
		BEGIN
			SET @allocation_logic = @allocation_logic +' => ' + @dim_factory_name_priority_list_primary_02
		END
	END

	IF @dim_factory_id_original_unconstrained_02 IS NULL
	BEGIN
		SET @allocation_logic = @allocation_logic +' => ' + 'Not found'
	END

	EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_updater]
		@pdasid = @pdasid,
		@businessid = @businessid,
		@dim_buying_program_id = @dim_buying_program_id,
		@dim_product_id = @dim_product_id,
		@dim_product_material_id = @dim_product_material_id,
		@dim_product_style_complexity = @dim_product_style_complexity,
		@dim_date_id = @dim_date_id,
		@dim_customer_id = @dim_customer_id,
		@dim_demand_category_id = @dim_demand_category_id,
		@order_number = @order_number,
		@allocation_logic = @allocation_logic,
		@dim_factory_id_original_unconstrained = @dim_factory_id_original_unconstrained_02
END
