USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Allocation sub procedure BRT Scnenario B
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_allocation_constrained_sub_brt_b]
	@pdasid INT,
	@businessid INT,
	@pdas_release_month_date_id INT,
	@dim_buying_program_id INT,
	@dim_factory_id_original INT,
	@dim_product_material_id NVARCHAR(45),
	@dim_product_style_complexity NVARCHAR(45),
	@dim_construction_type_name NVARCHAR(100),
	@dim_factory_original_region NVARCHAR(45),
	@quantity INT,
	@dim_date_year_cw_accounting NVARCHAR(8),
	@dim_customer_id INT,
	@dim_customer_sold_to_party NVARCHAR(100),
	@dim_demand_category_id INT,
	@allocation_logic NVARCHAR(1000)
AS
BEGIN
	SET NOCOUNT ON;

    /* Variable declarations */
	DECLARE @dim_factory_id_original_constrained_02 INT = @dim_factory_id_original
	DECLARE @dim_product_brt_in_house_02 SMALLINT
	DECLARE @dim_factory_name_priority_list_primary_02 NVARCHAR(45)
	DECLARE @dim_location_country_code_a2_02 NVARCHAR(2)

	/* Variable assignments */
	SET @dim_product_brt_in_house_02 =
	(
		SELECT ISNULL(MAX([brt_in_house]), 0)
		FROM [dbo].[dim_product]
		WHERE [material_id] = @dim_product_material_id
	)

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
	-- Duty Beneficial: Brazil DC
	IF @dim_customer_sold_to_party = 'Brazil DC'
	BEGIN
		SET @allocation_logic = @allocation_logic +' => ' + 'Duty Beneficial: ' + @dim_customer_sold_to_party
		-- BRT MTL?
		IF @dim_product_brt_in_house_02 = 1
		BEGIN
			SET @dim_factory_id_original_constrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = 'BRT')
			SET @allocation_logic = @allocation_logic +' => ' + 'BRT MTL'
		END

		-- Flex?
		ELSE IF @dim_product_style_complexity LIKE '%Flex%'
		BEGIN
			SET @dim_factory_id_original_constrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = 'SJV')
			SET @allocation_logic = @allocation_logic +' => ' + 'Flex' + ' => ' + 'SJV'
		END

		-- First priority = COO China?
		ELSE IF @dim_location_country_code_a2_02 = 'CN'
		BEGIN
			SET @dim_factory_id_original_constrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = 'BRT')
			SET @allocation_logic = @allocation_logic +' => ' + '1st priority = COO China' +' => ' +'BRT'
		END

		ELSE
		BEGIN
			SET @dim_factory_id_original_constrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_primary_02)
			SET @allocation_logic = @allocation_logic +' => ' + '1st priority = COO not China'
			IF @dim_factory_name_priority_list_primary_02 IS NOT NULL
			BEGIN
				SET @allocation_logic = @allocation_logic +' => ' + @dim_factory_name_priority_list_primary_02
			END
		END
	END

	IF @dim_factory_id_original_constrained_02 IS NULL
	BEGIN
		SET @allocation_logic = @allocation_logic +' => ' + 'Not Found'
	END

	EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_constrained_updater]
		@pdasid = @pdasid,
		@businessid = @businessid,
		@pdas_release_month_date_id = @pdas_release_month_date_id,
		@dim_buying_program_id = @dim_buying_program_id,
		@dim_factory_id_original = @dim_factory_id_original,
		@dim_product_material_id = @dim_product_material_id,
		@dim_product_style_complexity = @dim_product_style_complexity,
		@dim_construction_type_name = @dim_construction_type_name,
		@dim_factory_original_region = @dim_factory_original_region,
		@quantity = @quantity,
		@dim_date_year_cw_accounting = @dim_date_year_cw_accounting,
		@dim_customer_id = @dim_customer_id,
		@dim_customer_sold_to_party = @dim_customer_sold_to_party,
		@dim_demand_category_id = @dim_demand_category_id,
		@allocation_logic = @allocation_logic,
		@dim_factory_id_original_constrained = @dim_factory_id_original_constrained_02
END
