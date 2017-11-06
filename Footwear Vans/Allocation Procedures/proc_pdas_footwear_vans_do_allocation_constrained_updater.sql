USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 12/10/2017
-- Description:	Allocation fact_demand_total dim_factory_id_original_constrained updater
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_allocation_constrained_updater]
	@pdasid INT,
	@businessid INT,
	@dim_buying_program_id INT,
	@dim_factory_id_original INT,
	@dim_product_material_id NVARCHAR(45),
	@dim_product_style_complexity NVARCHAR(45),
	@dim_date_year_cw_accounting NVARCHAR(8),
	@dim_customer_id INT,
	@dim_customer_sold_to_party NVARCHAR(100),
	@dim_demand_category_id INT,
	@allocation_logic NVARCHAR(1000),
	@dim_factory_id_original_constrained INT
AS
BEGIN
	SET NOCOUNT ON;

	IF @dim_factory_id_original_constrained IS NOT NULL
	BEGIN

		/* Update the dim_factory_id_original (PDAS recommendation) and dim_factory_id (value that user can overwrite in Console) */
		UPDATE [dbo].[fact_demand_total]
		SET [dim_factory_id_original_constrained] = @dim_factory_id_original_constrained,
			[allocation_logic_constrained] = @allocation_logic
		WHERE
			[dim_pdas_id] = @pdasid AND
			[dim_business_id] = @businessid AND
			[dim_buying_program_id] = @dim_buying_program_id AND
			[dim_product_id] IN (SELECT [id] FROM [dbo].[dim_product] WHERE [material_id] = @dim_product_material_id) AND
			[dim_date_id] IN (SELECT [id] FROM [dbo].[dim_date] WHERE [year_cw_accounting] = @dim_date_year_cw_accounting) AND
			[dim_customer_id] = @dim_customer_id AND
			[dim_demand_category_id] = @dim_demand_category_id
	END

	ELSE
	BEGIN
		/*Update allocation logic only */
		UPDATE [dbo].[fact_demand_total]
		SET [allocation_logic_constrained] = @allocation_logic
		WHERE
			[dim_pdas_id] = @pdasid AND
			[dim_business_id] = @businessid AND
			[dim_buying_program_id] = @dim_buying_program_id AND
			[dim_product_id] IN (SELECT [id] FROM [dbo].[dim_product] WHERE [material_id] = @dim_product_material_id) AND
			[dim_date_id] IN (SELECT [id] FROM [dbo].[dim_date] WHERE [year_cw_accounting] = @dim_date_year_cw_accounting) AND
			[dim_customer_id] = @dim_customer_id AND
			[dim_demand_category_id] = @dim_demand_category_id
	END
END
