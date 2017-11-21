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
-- Description:	Allocation sub procedure under RQT Program branch (DTC priority)
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_allocation_sub_rqt_dtc]
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
	DECLARE @helper_retail_qt_rqt_vendor_02 NVARCHAR(45)

	/* Variable assignments */
	SET @helper_retail_qt_rqt_vendor_02 =
	(
		SELECT MAX([Factory])
		FROM [dbo].[helper_pdas_footwear_vans_retail_qt]
		WHERE [MTL] = @dim_product_material_id
	)

	/* Sub decision tree logic */

	-- Vendor = DTC or SJV?
	IF @helper_retail_qt_rqt_vendor_02 in ('DTC', 'SJV')
	BEGIN
		SET @dim_factory_id_original_unconstrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = 'DTC')
		SET @allocation_logic = @allocation_logic +' => ' + 'DTC RQT MTL'
	END

	ELSE
	BEGIN
		SET @dim_factory_id_original_unconstrained_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @helper_retail_qt_rqt_vendor_02)
		SET @allocation_logic = @allocation_logic +' => ' + @dim_factory_id_original_unconstrained_02 + ' RQT MTL'
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
