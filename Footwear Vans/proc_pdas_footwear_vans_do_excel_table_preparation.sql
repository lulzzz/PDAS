USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Creation of report table for XLSX report combo-charts
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_excel_table_preparation]
	@pdasid INT,
	@businessid INT
AS
BEGIN
	SET NOCOUNT ON;

	-- fact_demand_total without dim_demand_category_id and dim_buying_program_id
	DELETE FROM [dbo].[report_pdas_footwear_vans_xl_demand_total]
	INSERT INTO [dbo].[report_pdas_footwear_vans_xl_demand_total]
	(
		[dim_pdas_id]
		,[dim_product_id]
		,[dim_construction_type_id]
		,[dim_date_id]
		,[dim_factory_id_original]
		,[dim_factory_id_original_constrained]
		,[dim_factory_id]
		,[dim_customer_id]
		,[Order Number]
		,[Forecast - Bulk Buy]
		,[Forecast - Retail Quick Turn]
		,[Need to Buy - Bulk Buy]
		,[Need to Buy - Retail Quick Turn]
		,[Need to Buy - Scheduled Out of Sync]
		,[Need to Buy - Ad-Hoc Out of Sync]
		,[Open Order]
		,[Shipped Order]
	)
	SELECT
		[dim_pdas_id]
		,[dim_product_id]
		,[dim_construction_type_id]
		,[dim_date_id]
		,[dim_factory_id_original]
		,[dim_factory_id_original_constrained]
		,[dim_factory_id]
		,[dim_customer_id]
		,[Order Number]
		,ISNULL([Forecast - Bulk Buy], 0)
		,ISNULL([Forecast - Retail Quick Turn], 0)
		,ISNULL([Need to Buy - Bulk Buy], 0)
		,ISNULL([Need to Buy - Retail Quick Turn], 0)
		,ISNULL([Need to Buy - Scheduled Out of Sync], 0)
		,ISNULL([Need to Buy - Ad-Hoc Out of Sync], 0)
		,ISNULL([Open Order], 0)
		,ISNULL([Shipped Order], 0)
	FROM
	(
		SELECT
			[dim_pdas_id]
			,[dim_product_id]
			,[dim_construction_type_id]
			,[dim_date_id]
			,[dim_factory_id_original]
			,[dim_factory_id_original_constrained]
			,[dim_factory_id]
			,[dim_customer_id]
			,CASE
				WHEN [Demand Signal Type] NOT IN ('Need to Buy', 'Forecast') THEN [Demand Signal Type]
				ELSE [Demand Signal Type] + ' - ' + [Buying Program]
			END AS [pivot_col]
			,[Order Number]
			,SUM([quantity]) AS [quantity]
		FROM [dbo].[xl_view_pdas_footwear_vans_demand_total]
		GROUP BY
			[dim_pdas_id]
			,[dim_business_id]
			,[dim_product_id]
			,[dim_construction_type_id]
			,[dim_date_id]
			,[dim_factory_id_original]
			,[dim_factory_id_original_constrained]
			,[dim_factory_id]
			,[dim_customer_id]
			,CASE
				WHEN [Demand Signal Type] NOT IN ('Need to Buy', 'Forecast') THEN [Demand Signal Type]
				ELSE [Demand Signal Type] + ' - ' + [Buying Program]
			END
			,[Order Number]
	) src
	PIVOT
	(
		SUM([quantity])
		FOR [pivot_col] IN (
			[Forecast - Bulk Buy]
			,[Forecast - Retail Quick Turn]
			,[Need to Buy - Bulk Buy]
			,[Need to Buy - Retail Quick Turn]
			,[Need to Buy - Scheduled Out of Sync]
			,[Need to Buy - Ad-Hoc Out of Sync]
			,[Open Order]
			,[Shipped Order]
		)
	) piv


END
