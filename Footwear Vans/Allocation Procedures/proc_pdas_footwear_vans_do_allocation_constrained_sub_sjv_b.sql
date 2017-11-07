USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Allocation sub procedure SJV Scnenario B
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_allocation_constrained_sub_sjv_b]
	@pdasid INT,
	@businessid INT,
	@pdas_release_month_date_id INT,
	@dim_buying_program_id INT,
	@dim_factory_id_original INT,
	@dim_product_material_id NVARCHAR(45),
	@dim_product_style_complexity NVARCHAR(45),
	@dim_construction_type_name NVARCHAR(100),
	@dim_factory_original_region NVARCHAR(45),
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
	DECLARE @helper_retail_qt_rqt_vendor_02 NVARCHAR(45)
	DECLARE @dim_factory_name_priority_list_primary_02 NVARCHAR(45)

	/* Variable assignments */
	SET @helper_retail_qt_rqt_vendor_02 =
	(
		SELECT MAX([Factory])
		FROM [dbo].[helper_pdas_footwear_vans_retail_qt]
		WHERE [MTL] = @dim_product_material_id
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

	/* Sub decision tree logic */
	IF @dim_customer_sold_to_party IN ('Korea DC', 'Korea Direct', 'India DC', 'EU DC', 'EU Crossdock', 'Brazil DC', 'Chile DC', 'China DC')
	BEGIN
		IF @dim_customer_sold_to_party IN ('Korea DC', 'Korea Direct')
		BEGIN
			SET @allocation_logic = @allocation_logic +' => ' + 'Duty Beneficial: ' + @dim_customer_sold_to_party
		END
		ELSE IF @dim_customer_sold_to_party IN ('India DC', 'EU DC', 'EU Crossdock', 'Brazil DC', 'Chile DC', 'China DC')
		BEGIN
			SET @allocation_logic = @allocation_logic +' => ' + 'Non-duty Beneficial: ' + @dim_customer_sold_to_party
		END

		-- RQT MTL?
		IF @dim_product_material_id IN (SELECT [MTL] FROM [dbo].[helper_pdas_footwear_vans_retail_qt])
		BEGIN
			SET @allocation_logic = @allocation_logic +' => ' + 'RQT MTL'

			IF @dim_factory_original_region = 'EMEA'
			BEGIN
				-- Vendor = DTC or SJV?
				IF @helper_retail_qt_rqt_vendor_02 in ('DTC', 'SJV')
				BEGIN
					SET @dim_factory_id_original_constrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = 'DTC')
					SET @allocation_logic = @allocation_logic +' => ' + 'DTC'
				END
				-- Fixed Vendor
				ELSE
				BEGIN
					SET @dim_factory_id_original_constrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @helper_retail_qt_rqt_vendor_02)
					SET @allocation_logic = @allocation_logic +' => ' + @helper_retail_qt_rqt_vendor_02
				END
			END

			ELSE IF @dim_factory_original_region IN ('NORA', 'CASA')
			BEGIN
				-- Vendor = DTC or SJV?
				IF @dim_product_material_id in ('DTC', 'SJV')
				BEGIN
					SET @dim_factory_id_original_constrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = 'SJV')
					SET @allocation_logic = @allocation_logic +' => ' + 'SJV'
				END
				-- Fixed Vendor
				ELSE
				BEGIN
					SET @dim_factory_id_original_constrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @helper_retail_qt_rqt_vendor_02)
					SET @allocation_logic = @allocation_logic +' => ' + @helper_retail_qt_rqt_vendor_02
				END
			END

			ELSE IF @dim_factory_original_region IN ('APAC')
			BEGIN
				-- HSC
				IF @dim_customer_sold_to_party LIKE 'China%'
				BEGIN
					SET @dim_factory_id_original_constrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = 'HSC')
					SET @allocation_logic = @allocation_logic +' => ' + 'HSC'
				END
				-- Fixed Vendor
				ELSE
				BEGIN
					SET @dim_factory_id_original_constrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @helper_retail_qt_rqt_vendor_02)
					SET @allocation_logic = @allocation_logic +' => ' + @helper_retail_qt_rqt_vendor_02
				END
			END
		END

		-- 'Korea DC', 'Korea Direct', 'India DC', 'EU DC', 'EU Crossdock', 'Brazil DC'
		IF @dim_customer_sold_to_party IN ('Korea DC', 'Korea Direct', 'India DC', 'EU DC', 'EU Crossdock', 'Brazil DC')
		BEGIN
			-- Flex?
			IF @dim_product_style_complexity LIKE '%Flex%'
			BEGIN
				SET @allocation_logic = @allocation_logic +' => ' + 'Flex' + ' => ' + 'SJV'
			END
			ELSE
			BEGIN
				SET @dim_factory_id_original_constrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_primary_02)
				SET @allocation_logic = @allocation_logic +' => ' + 'Not Flex' +' => ' + '1st priority'
				IF @dim_factory_name_priority_list_primary_02 IS NOT NULL
				BEGIN
					SET @allocation_logic = @allocation_logic +' => ' + @dim_factory_name_priority_list_primary_02
				END
			END
		END

		-- Chile DC and China DC
		ELSE
		BEGIN
			-- Flex?
			IF @dim_product_style_complexity LIKE '%Flex%'
			BEGIN
				IF @dim_factory_name_priority_list_primary_02 = 'SJV'
				BEGIN
					SET @dim_factory_id_original_constrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = 'HSC')
					SET @allocation_logic = @allocation_logic +' => ' + '1st priority = SJV' + ' => ' + 'HSC'
				END
				ELSE
				BEGIN
					SET @dim_factory_id_original_constrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_primary_02)
					SET @allocation_logic = @allocation_logic +' => ' + '1st priority = not SJV' +' => ' + '1st priority'
					IF @dim_factory_name_priority_list_primary_02 IS NOT NULL
					BEGIN
						SET @allocation_logic = @allocation_logic +' => ' + @dim_factory_name_priority_list_primary_02
					END
				END
				SET @allocation_logic = @allocation_logic +' => ' + 'Flex' + ' => ' + 'SJV'
			END
			ELSE
			BEGIN
				SET @dim_factory_id_original_constrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_primary_02)
				SET @allocation_logic = @allocation_logic +' => ' + 'Not Flex' +' => ' + '1st priority'
				IF @dim_factory_name_priority_list_primary_02 IS NOT NULL
				BEGIN
					SET @allocation_logic = @allocation_logic +' => ' + @dim_factory_name_priority_list_primary_02
				END
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
		@dim_date_year_cw_accounting = @dim_date_year_cw_accounting,
		@dim_customer_id = @dim_customer_id,
		@dim_customer_sold_to_party = @dim_customer_sold_to_party,
		@dim_demand_category_id = @dim_demand_category_id,
		@allocation_logic = @allocation_logic,
		@dim_factory_id_original_constrained = @dim_factory_id_original_constrained_02
END
