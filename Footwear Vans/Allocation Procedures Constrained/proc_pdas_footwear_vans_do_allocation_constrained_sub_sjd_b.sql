USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Allocation sub procedure SJD Scnenario B
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_allocation_constrained_sub_sjd_b]
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
	@dim_date_year_cw_accounting NVARCHAR(8),
	@quantity INT,
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
	DECLARE @helper_retail_qt_rqt_vendor_02 NVARCHAR(45)
	DECLARE @dim_factory_name_priority_list_primary_02 NVARCHAR(45)
	DECLARE @dim_factory_name_priority_list_secondary_02 NVARCHAR(45)
	DECLARE @fact_priority_list_source_count_02 INT = 0

	/* Variable assignments */

	SET @helper_retail_qt_rqt_vendor_02 =
	(
		SELECT MAX([factory_short_name])
		FROM [dbo].[helper_pdas_footwear_vans_retail_qt]
		WHERE [material_id] = @dim_product_material_id
	)


	/* Sub decision tree logic */
	-- Duty Beneficial: US Direct
	IF @loop = 1
	BEGIN
		SET @allocation_logic = @allocation_logic +' => ' + '[loop: ' + CONVERT(NVARCHAR(2), @loop) + ']'

		IF @dim_customer_sold_to_party = 'US Direct'
		BEGIN
			SET @allocation_logic = @allocation_logic +' => ' + 'Duty Beneficial: ' + @dim_customer_sold_to_party
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

			ELSE
			BEGIN
				SET @dim_factory_id_original_constrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = 'SJV')
				SET @allocation_logic = @allocation_logic +' => ' + 'not RQT MTL' +' => ' + 'SJV'
			END
		END
	END

	ELSE IF @loop = 2
	BEGIN
		SET @allocation_logic = @allocation_logic +' => ' + '[loop: ' + CONVERT(NVARCHAR(2), @loop) + ']'

		IF @dim_customer_sold_to_party = 'US DC'
		BEGIN
			SET @allocation_logic = @allocation_logic +' => ' + 'Duty Beneficial: ' + @dim_customer_sold_to_party
			SET @allocation_logic = @allocation_logic +' => ' + 'not RQT MTL' +' => ' + 'SJD'
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
