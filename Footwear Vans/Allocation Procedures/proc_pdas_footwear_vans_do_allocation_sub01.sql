USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Allocation sub procedure EU DC (T902) and EU Cross Dock (T902)
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_allocation_sub01]
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
	DECLARE @dim_factory_id_original_02 int = NULL
	DECLARE @dim_factory_name_priority_list_primary_02 NVARCHAR(45)

	print('sub proc')
	/* Variable assignments */

	SET @dim_factory_name_priority_list_primary_02 =
	(
		SELECT df.[short_name]
		FROM
			(
				SELECT [dim_factory_id_1]
				FROM [dbo].[fact_priority_list]
				WHERE [dim_product_id] = @dim_product_id
			) AS fpl
			INNER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory]) df
				ON fpl.[dim_factory_id_1] = df.[id]
	)


	/* Sub decision tree logic */

	-- CLK MTL?
	IF @dim_factory_name_priority_list_primary_02 = 'CLK'
	BEGIN
		SET @dim_factory_id_original_02 = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = @dim_factory_name_priority_list_primary_02)
		SET @allocation_logic = @allocation_logic +'\n' + @dim_factory_name_priority_list_primary_02 + ' MTL'
	END

	-- DTP MTL?


	IF @dim_factory_id_original_02 IS NOT NULL
	BEGIN

		/* Update the dim_factory_id_original (PDAS recommendation) and dim_factory_id (value that user can overwrite in Console) */
		UPDATE [dbo].[fact_demand_total]
		SET [dim_factory_id_original] = @dim_factory_id_original_02,
			[dim_factory_id] = @dim_factory_id_original_02,
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
