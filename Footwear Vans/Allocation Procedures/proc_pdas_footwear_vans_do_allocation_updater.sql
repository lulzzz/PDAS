USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 12/10/2017
-- Description:	Allocation fact_demand_total dim_factory_id_original updater
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_allocation_updater]
	@pdasid INT,
	@businessid INT,
	@dim_buying_program_id INT,
	@dim_product_id INT,
	@dim_date_id INT,
	@dim_customer_id INT,
	@dim_demand_category_id INT,
	@order_number NVARCHAR(45),
	@allocation_logic NVARCHAR(1000),
	@dim_factory_id_original INT
AS
BEGIN
	SET NOCOUNT ON;

	IF @dim_factory_id_original IS NOT NULL
	BEGIN

		/* Update the dim_factory_id_original (PDAS recommendation) and dim_factory_id (value that user can overwrite in Console) */
		UPDATE [dbo].[fact_demand_total]
		SET [dim_factory_id_original] = @dim_factory_id_original,
			[dim_factory_id] = @dim_factory_id_original,
			[allocation_logic] = @allocation_logic
		WHERE
			[dim_pdas_id] = @pdasid AND
			[dim_business_id] = @businessid AND
			[dim_buying_program_id] = @dim_buying_program_id AND
			[dim_product_id] = @dim_product_id AND
			[dim_date_id] = @dim_date_id AND
			[dim_customer_id] = @dim_customer_id AND
			[dim_demand_category_id] = @dim_demand_category_id AND
			[order_number] = @order_number AND
			[edit_dt] IS NULL
	END
END
