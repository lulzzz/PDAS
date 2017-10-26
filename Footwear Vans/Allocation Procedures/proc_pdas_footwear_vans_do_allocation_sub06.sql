USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 13/10/2017
-- Description:	Allocation sub procedure Korea DC (W300) + Direct (W302)
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_allocation_sub06]
	@pdasid INT,
	@businessid INT,
	@dim_buying_program_id INT,
	@dim_product_id INT,
	@dim_date_id INT,
	@dim_customer_id INT,
	@dim_demand_category_id INT,
	@order_number NVARCHAR(45),
	@allocation_logic NVARCHAR(1000)
AS
BEGIN
	SET NOCOUNT ON;

    /* Variable declarations */
	DECLARE @dim_factory_id_original_02 INT = NULL
	DECLARE @dim_factory_name_priority_list_primary_02 NVARCHAR(45)
	DECLARE @dim_product_style_complexity_02 NVARCHAR(45)
	DECLARE @helper_retail_qt_rqt_vendor_02 NVARCHAR(45)
	DECLARE @dim_product_material_id_02 NVARCHAR(45)
	DECLARE @fact_priority_list_source_count_02 INT = 0
	DECLARE @dim_location_country_code_a2_primary_02 NVARCHAR(2)
	DECLARE @dim_location_country_code_a2_secondary_02 NVARCHAR(2)
	DECLARE @dim_factory_name_priority_list_secondary_02 NVARCHAR(45)

	/* Variable assignments */

	SET @dim_factory_name_priority_list_primary_02 =
	(
		SELECT df.[short_name]
		FROM
			(
				SELECT [dim_factory_id_1]
				FROM [dbo].[fact_priority_list]
				WHERE [dim_product_id] = @dim_product_id
			) fpl
			INNER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory]) df
				ON fpl.[dim_factory_id_1] = df.[id]
	)

	SET @dim_product_style_complexity_02 = (SELECT [style_complexity] FROM [dbo].[dim_product] WHERE [id] = @dim_product_id)

	SET @dim_product_material_id_02 = (SELECT [material_id] FROM [dbo].[dim_product] WHERE [id] = @dim_product_id)

	SET @helper_retail_qt_rqt_vendor_02 =
	(
		SELECT [Factory]
		FROM [dbo].[helper_pdas_footwear_vans_retail_qt]
		WHERE [MTL] = @dim_product_material_id_02
	)

	IF (SELECT [dim_factory_id_1] FROM [dbo].[fact_priority_list] WHERE [dim_product_id] = @dim_product_id) IS NOT NULL
	BEGIN
		SET @fact_priority_list_source_count_02 = @fact_priority_list_source_count_02 + 1
	END
	IF (SELECT [dim_factory_id_2] FROM [dbo].[fact_priority_list] WHERE [dim_product_id] = @dim_product_id) IS NOT NULL
	BEGIN
		SET @fact_priority_list_source_count_02 = @fact_priority_list_source_count_02 + 1
	END

	SET @dim_location_country_code_a2_primary_02 =
	(
		SELECT dfl.[dim_location_country_code_a2]
		FROM
			(
				SELECT [dim_factory_id_1]
				FROM [dbo].[fact_priority_list]
				WHERE [dim_product_id] = @dim_product_id
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

	SET @dim_factory_name_priority_list_secondary_02 =
	(
		SELECT df.[short_name]
		FROM
			(
				SELECT [dim_factory_id_2]
				FROM [dbo].[fact_priority_list]
				WHERE [dim_product_id] = @dim_product_id
			) AS fpl
			INNER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory]) df
				ON fpl.[dim_factory_id_2] = df.[id]
	)

	SET @dim_location_country_code_a2_secondary_02 =
	(
		SELECT dfl.[dim_location_country_code_a2]
		FROM
			(
				SELECT [dim_factory_id_2]
				FROM [dbo].[fact_priority_list]
				WHERE [dim_product_id] = @dim_product_id
			) AS fpl
			INNER JOIN
			(
				SELECT df.[id], dl.[country_code_a2] AS [dim_location_country_code_a2]
				FROM [dbo].[dim_factory] df
				INNER JOIN [dbo].[dim_location] dl
					ON df.[dim_location_id] = dl.[id]
			) dfl
				ON fpl.[dim_factory_id_2] = dfl.[id]
	)

	IF @dim_factory_name_priority_list_primary_02 IS NULL
	BEGIN
		SET @allocation_logic = @allocation_logic +' => ' + 'Product ID not in priority list'
	END

	/* Sub decision tree logic */

	-- Flex?
	IF @dim_product_style_complexity_02 LIKE '%Flex%'
	BEGIN
		SET @dim_factory_id_original_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = 'SJV')
		SET @allocation_logic = @allocation_logic +' => ' + 'Flex'
	END

	-- RQT MTL?
	ELSE IF @dim_product_material_id_02 IN (SELECT [MTL] FROM [dbo].[helper_pdas_footwear_vans_retail_qt])
	BEGIN
		SET @dim_factory_id_original_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @helper_retail_qt_rqt_vendor_02)
		SET @allocation_logic = @allocation_logic +' => ' + 'RQT MTL'
	END

	-- DTP MTL?
	ELSE IF @dim_factory_name_priority_list_primary_02 = 'DTP'
	BEGIN
		SET @dim_factory_id_original_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_primary_02)
		SET @allocation_logic = @allocation_logic +' => ' + @dim_factory_name_priority_list_primary_02 + ' MTL'
	END

	-- CLK MTL?
	ELSE IF @dim_factory_name_priority_list_primary_02 = 'CLK'
	BEGIN
		SET @dim_factory_id_original_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_primary_02)
		SET @allocation_logic = @allocation_logic +' => ' + @dim_factory_name_priority_list_primary_02 + ' MTL'
	END

	-- Single Source?
	ELSE IF @fact_priority_list_source_count_02 = 1
	BEGIN
		SET @dim_factory_id_original_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_primary_02)
		SET @allocation_logic = @allocation_logic +' => ' + 'Single Source'
	END

	-- 1st priority = COO China?
	ELSE IF @dim_location_country_code_a2_primary_02 <> 'CN'
	BEGIN
		SET @dim_factory_id_original_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_primary_02)
		SET @allocation_logic = @allocation_logic +' => ' + @dim_factory_name_priority_list_secondary_02 + ' 1st priority = COO China'
	END

	-- 2nd priority = COO China?
	ELSE IF @dim_location_country_code_a2_secondary_02 = 'CN'
	BEGIN
		SET @dim_factory_id_original_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_primary_02)
		SET @allocation_logic = @allocation_logic +' => ' + @dim_factory_name_priority_list_secondary_02 + ' 2nd priority = COO China'
	END

	ELSE
	BEGIN
		SET @dim_factory_id_original_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_secondary_02)
		SET @allocation_logic = @allocation_logic +' => ' + @dim_factory_name_priority_list_primary_02 + ' 2nd priority = COO not China'
	END

	EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_updater]
		@pdasid = @pdasid,
		@businessid = @businessid,
		@dim_buying_program_id = @dim_buying_program_id,
		@dim_product_id = @dim_product_id,
		@dim_date_id = @dim_date_id,
		@dim_customer_id = @dim_customer_id,
		@dim_demand_category_id = @dim_demand_category_id,
		@order_number = @order_number,
		@allocation_logic = @allocation_logic,
		@dim_factory_id_original = @dim_factory_id_original_02
END
