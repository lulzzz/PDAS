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
	@dim_factory_id_original_unconstrained INT,
	@dim_factory_id_original_constrained INT,
	@dim_product_material_id NVARCHAR(45),
	@dim_product_style_complexity NVARCHAR(45),
	@dim_construction_type_name NVARCHAR(100),
	@dim_factory_original_region NVARCHAR(45),
	@quantity INT,
	@dim_date_year_cw_accounting NVARCHAR(8),
	@dim_customer_id INT,
	@dim_customer_sold_to_party NVARCHAR(100),
	@dim_demand_category_id INT,
	@allocation_logic NVARCHAR(1000),
	@loop INT
AS
BEGIN
	SET NOCOUNT ON;

    /* Variable declarations */
	DECLARE @dim_factory_id_original_constrained_02 INT = @dim_factory_id_original_constrained
	DECLARE @dim_product_clk_mtl_02 SMALLINT
	DECLARE @dim_product_dtp_mtl_02 SMALLINT
	DECLARE @dim_product_sjd_mtl_02 SMALLINT
	DECLARE @mtl_factories_02 table (short_name NVARCHAR(45))
	DECLARE @helper_retail_qt_rqt_vendor_02 NVARCHAR(45)
	DECLARE @dim_factory_name_priority_list_primary_02 NVARCHAR(45)
	DECLARE @dim_factory_name_priority_list_secondary_02 NVARCHAR(45)
	DECLARE @fact_priority_list_source_count_02 INT = 0

	/* Variable assignments */
	SET @dim_product_clk_mtl_02 =
	(
		SELECT ISNULL(MAX([clk_mtl]), 0)
		FROM [dbo].[dim_product]
		WHERE [material_id] = @dim_product_material_id
	)

	SET @dim_product_dtp_mtl_02 =
	(
		SELECT ISNULL(MAX([dtp_mtl]), 0)
		FROM [dbo].[dim_product]
		WHERE [material_id] = @dim_product_material_id
	)

	SET @dim_product_sjd_mtl_02 =
	(
		SELECT ISNULL(MAX([sjd_mtl]), 0)
		FROM [dbo].[dim_product]
		WHERE [material_id] = @dim_product_material_id
	)

	INSERT @mtl_factories_02(short_name)
	VALUES (CASE WHEN @dim_product_clk_mtl_02 = 1 THEN 'CLK' ELSE '' END),
			(CASE WHEN @dim_product_dtp_mtl_02 = 1 THEN 'DTP' ELSE '' END),
			(CASE WHEN @dim_product_sjd_mtl_02 = 1 THEN 'SJD' ELSE '' END);

	SET @helper_retail_qt_rqt_vendor_02 =
	(
		SELECT MAX([factory_short_name])
		FROM [dbo].[helper_pdas_footwear_vans_retail_qt]
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
					AND [dim_pdas_id] = @pdasid
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
					AND [dim_pdas_id] = @pdasid
			) AS fpl
			INNER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory]) df
				ON fpl.[dim_factory_id_2] = df.[id]
	)

	IF @dim_factory_name_priority_list_primary_02 IS NOT NULL
	BEGIN
	SET @fact_priority_list_source_count_02 = @fact_priority_list_source_count_02 + 1
	END
	IF @dim_factory_name_priority_list_secondary_02 IS NOT NULL
	BEGIN
	SET @fact_priority_list_source_count_02 = @fact_priority_list_source_count_02 + 1
	END

	/* Sub decision tree logic */
	IF @loop < 6
	BEGIN
		SET @allocation_logic = @allocation_logic +' => ' + '[loop: ' + CONVERT(NVARCHAR(2), @loop) + ']'

		IF (@loop = 5 AND @dim_customer_sold_to_party IN ('Korea DC', 'Korea Direct'))
			OR (@loop = 4 AND @dim_customer_sold_to_party IN ('EU DC', 'EU Crossdock'))
			OR (@loop = 3 AND @dim_customer_sold_to_party IN ('India DC'))
			OR (@loop = 2 AND @dim_customer_sold_to_party IN ('China DC'))
			OR (@loop = 1 AND @dim_customer_sold_to_party IN ('Chile DC'))
		BEGIN
			IF (@loop = 5 AND @dim_customer_sold_to_party IN ('Korea DC', 'Korea Direct'))
			BEGIN
				SET @allocation_logic = @allocation_logic +' => ' + 'Duty Beneficial: ' + @dim_customer_sold_to_party
			END
			ELSE IF (@loop = 4 AND @dim_customer_sold_to_party IN ('EU DC', 'EU Crossdock'))
				OR (@loop = 3 AND @dim_customer_sold_to_party IN ('India DC'))
				OR (@loop = 2 AND @dim_customer_sold_to_party IN ('China DC'))
				OR (@loop = 1 AND @dim_customer_sold_to_party IN ('Chile DC'))
			BEGIN
				SET @allocation_logic = @allocation_logic +' => ' + 'Non-duty Beneficial: ' + @dim_customer_sold_to_party
			END

			-- RQT MTL?
			IF @dim_product_material_id IN (SELECT [material_id] FROM [dbo].[helper_pdas_footwear_vans_retail_qt])
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

			-- 'Korea DC', 'Korea Direct', 'India DC', 'EU DC', 'EU Crossdock'
			IF (@loop = 5 AND @dim_customer_sold_to_party IN ('Korea DC', 'Korea Direct'))
				OR (@loop = 4 AND @dim_customer_sold_to_party IN ('EU DC', 'EU Crossdock'))
				OR (@loop = 3 AND @dim_customer_sold_to_party IN ('India DC'))
			BEGIN
				-- Flex?
				IF @dim_product_style_complexity LIKE '%Flex%'
				BEGIN
					SET @allocation_logic = @allocation_logic +' => ' + 'Flex'
					IF @dim_customer_sold_to_party IN ( 'India DC', 'EU DC', 'EU Crossdock')
					BEGIN
						-- Dual Source?
						IF @fact_priority_list_source_count_02 = 2
								OR (@dim_product_clk_mtl_02 + @dim_product_dtp_mtl_02 + @dim_product_sjd_mtl_02) >= 2
								OR @dim_product_style_complexity LIKE '%Flex%'
								OR ((SELECT max([short_name]) from @mtl_factories_02) <> ''
									AND (SELECT (@dim_factory_name_priority_list_secondary_02)
										INTERSECT (SELECT [short_name] FROM @mtl_factories_02)) IS NULL)
						BEGIN
							SET @allocation_logic = @allocation_logic +' => ' + 'Dual Source'+' => ' + '2nd priority'
							IF @dim_factory_name_priority_list_secondary_02 IS NOT NULL
							BEGIN
								SET @dim_factory_id_original_constrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_secondary_02)
								SET @allocation_logic = @allocation_logic +' => ' + @dim_factory_name_priority_list_secondary_02
							END

							ELSE
							BEGIN
								SET @allocation_logic = @allocation_logic +' => ' + 'Not found'+' => ' + '1st priority'
								IF @dim_factory_name_priority_list_primary_02 IS NOT NULL
								BEGIN
									SET @dim_factory_id_original_constrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_primary_02)
									SET @allocation_logic = @allocation_logic +' => ' + @dim_factory_name_priority_list_primary_02
								END
								ELSE
								BEGIN
									SET @allocation_logic = @allocation_logic +' => ' + 'Not found' + ' => ' + 'SJV'
								END
							END
						END
					END
					ELSE
					BEGIN
						SET @allocation_logic = @allocation_logic +' => ' + 'SJV'
					END
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
			ELSE IF (@loop = 1 AND @dim_customer_sold_to_party = 'Chile DC')
				OR (@loop = 2 AND @dim_customer_sold_to_party = 'China DC')
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
		@dim_factory_id_original_unconstrained = @dim_factory_id_original_unconstrained,
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
