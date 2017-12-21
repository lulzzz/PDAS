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
-- Description:	Allocation sub procedure under RQT Program branch
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_allocation_sub_rqt]
	@pdasid INT,
	@businessid INT,
	@dim_buying_program_id INT,
	@dim_product_id INT,
	@dim_product_material_id NVARCHAR(45),
	@dim_product_style_complexity NVARCHAR(45),
	@dim_date_id INT,
	@dim_customer_id INT,
	@dim_customer_sold_to_party NVARCHAR(100),
	@dim_customer_country_region NVARCHAR(100),
	@dim_demand_category_id INT,
	@order_number NVARCHAR(45),
	@allocation_logic NVARCHAR(1000)
AS
BEGIN
	SET NOCOUNT ON;

    /* Variable declarations */
	DECLARE @dim_factory_id_original_unconstrained_02 INT = NULL
	DECLARE @helper_retail_qt_rqt_vendor_02 NVARCHAR(45)

	/* Variable assignments */
	SET @helper_retail_qt_rqt_vendor_02 =
	(
		SELECT MAX([factory_short_name])
		FROM [dbo].[helper_pdas_footwear_vans_retail_qt]
		WHERE [material_id] = @dim_product_material_id
			AND [region] = @dim_customer_country_region
			AND [sold_to_party] = @dim_customer_sold_to_party
	)

	/* Sub decision tree logic */
	SET @dim_factory_id_original_unconstrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @helper_retail_qt_rqt_vendor_02)
	IF @dim_factory_id_original_unconstrained_02 IS NOT NULL
	BEGIN
		SET @allocation_logic = @allocation_logic +' => ' + @helper_retail_qt_rqt_vendor_02 + ' RQT MTL'
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
		@dim_factory_id_original_unconstrained = @dim_factory_id_original_unconstrained_02,
		@component_factory_short_name = NULL
END
