USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 12/10/2017
-- Description:	Allocation sub procedure Canada DC (1004) + Direct (1014)
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_allocation_sub02]
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
	DECLARE @dim_factory_id_original_02 INT = NULL
	DECLARE @dim_factory_name_priority_list_primary_02 NVARCHAR(45)
	DECLARE @helper_retail_qt_rqt_vendor_02 NVARCHAR(45)
	DECLARE @dim_product_clk_mtl SMALLINT

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

	SET @dim_product_clk_mtl =
	(
		SELECT ISNULL([clk_mtl], 0)
		FROM [dbo].[dim_product]
		WHERE [id] = @dim_product_id
	)

	SET @helper_retail_qt_rqt_vendor_02 =
	(
		SELECT MAX([Factory])
		FROM [dbo].[helper_pdas_footwear_vans_retail_qt]
		WHERE [MTL] = @dim_product_material_id
	)

	/* Sub decision tree logic */

	-- CLK MTL?
	IF @dim_product_clk_mtl = 1
	BEGIN
		SET @dim_factory_id_original_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = 'CLK')
		SET @allocation_logic = @allocation_logic +' => ' + 'CLK MTL'
	END

	-- RQT MTL?
	ELSE IF @dim_product_material_id IN (SELECT [MTL] FROM [dbo].[helper_pdas_footwear_vans_retail_qt])
	BEGIN
		-- Vendor = DTC or SJV?
		IF @helper_retail_qt_rqt_vendor_02 in ('DTC', 'SJV')
		BEGIN
			SET @dim_factory_id_original_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = 'SJV')
			SET @allocation_logic = @allocation_logic +' => ' + @helper_retail_qt_rqt_vendor_02 + ' RQT MTL'
		END
		ELSE
		BEGIN
			SET @dim_factory_id_original_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @helper_retail_qt_rqt_vendor_02)
			SET @allocation_logic = @allocation_logic +' => ' + @helper_retail_qt_rqt_vendor_02 + ' RQT MTL'
		END
	END

	ELSE
	BEGIN
		SET @dim_factory_id_original_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_primary_02)
		SET @allocation_logic = @allocation_logic +' => ' + 'not RQT MTL'
		IF @dim_factory_name_priority_list_primary_02 IS NOT NULL
		BEGIN
			SET @allocation_logic = @allocation_logic +' => ' + @dim_factory_name_priority_list_primary_02
		END
	END

	IF @dim_factory_id_original_02 IS NULL
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
		@dim_factory_id_original = @dim_factory_id_original_02
END
