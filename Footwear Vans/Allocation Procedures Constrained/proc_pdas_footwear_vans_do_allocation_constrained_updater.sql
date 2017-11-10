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
	@allocation_logic NVARCHAR(1000),
	@dim_factory_id_original_constrained INT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @current_fill_03 int
	DECLARE @max_capacity_03 int

	IF @dim_factory_id_original_constrained IS NOT NULL AND @dim_factory_id_original <> @dim_factory_id_original_constrained
	BEGIN

		SET @current_fill_03 =
		(
			SELECT SUM([quantity_consumed])
			FROM
				[dbo].[fact_demand_total] f
				INNER JOIN (SELECT [id], [year_cw_accounting] FROM [dbo].[dim_date]) dd
					ON f.[dim_date_id] = dd.[id]
				INNER JOIN
				(
					SELECT
						f.[id]
						,f.[material_id]
						,f.[style_complexity]
						,f.[is_placeholder]
						,dl.[name] AS [dim_construction_type_name]
					FROM
						[dbo].[dim_product] f
						INNER JOIN [dbo].[dim_construction_type] dl
							ON dl.[id] = f.[dim_construction_type_id]
				) dp
					ON f.[dim_product_id] = dp.[id]
				INNER JOIN (SELECT [id], [name] FROM [dbo].[dim_demand_category]) ddc
					ON f.[dim_demand_category_id] = ddc.[id]
			WHERE
				[dim_pdas_id] = @pdasid
				and [dim_business_id] = @businessid
				and [dim_date_id] >= @pdas_release_month_date_id
				and ddc.[name] IN ('Forecast', 'Need to Buy')
			GROUP BY [dim_factory_id_original], [year_cw_accounting], [dim_construction_type_name]
			HAVING [dim_factory_id_original] = @dim_factory_id_original_constrained
				AND [year_cw_accounting] = @dim_date_year_cw_accounting
				AND [dim_construction_type_name] = @dim_construction_type_name
		)

		SET @max_capacity_03 =
		(
			SELECT SUM([Available Capacity by Week])
			FROM [VCDWH].[dbo].[xl_view_pdas_footwear_vans_factory_capacity]
			GROUP BY [dim_factory_id], [Accounting CW], [Construction Type]
			HAVING [dim_factory_id] = @dim_factory_id_original_constrained
				AND [Accounting CW] = @dim_date_year_cw_accounting
				AND [Construction Type] = @dim_construction_type_name
		)

		IF @current_fill_03 + @quantity < @max_capacity_03 OR @dim_factory_id_original_constrained = (SELECT [id] FROM [dbo].[dim_factory] WHERE [short_name] = 'SJV')
		BEGIN
			/* Update the dim_factory_id_original (PDAS recommendation) and dim_factory_id (value that user can overwrite in Console) */
			UPDATE [dbo].[fact_demand_total]
			SET [dim_factory_id_original_constrained] = @dim_factory_id_original_constrained,
				[dim_factory_id] = @dim_factory_id_original_constrained,
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
			SET @allocation_logic = @allocation_logic + ' => ' + 'Target factory full'
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
