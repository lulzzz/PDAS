USE [VCDWH]
GO
/****** Object:  StoredProcedure [dbo].[proc_pdas_footwear_vans_do_overwrite]    Script Date: 4/12/2017 4:15:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ==============================================================
-- Author:		ebp Global
-- Create date: 15/9/2017
-- Description:	Procedure to load the decisions of the VFA team to overwritte the PDAS recommendations.
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_overwrite]
	@pdasid INT,
	@businessid INT
AS
BEGIN

	-- Declare variables
	DECLARE	@current_dt datetime = GETDATE()

	-- Update fact_demand_total
	UPDATE target
	SET
		target.[dim_factory_id] = temp.[dim_factory_id]
		,target.[comment_vfa] = temp.[Comment (VFA)]
		,target.[edit_dt] = @current_dt
	FROM
		(
			SELECT
				*
				,CONVERT(NVARCHAR(100), CONVERT(NVARCHAR(10), dim_pdas_id) + '-' + CONVERT(NVARCHAR(10), dim_business_id) + '-' + CONVERT(NVARCHAR(10), dim_buying_program_id) + '-' + CONVERT(NVARCHAR(10), dim_demand_category_id) + '-' + CONVERT(NVARCHAR(10), dim_product_id) + '-' + CONVERT(NVARCHAR(10), dim_date_id) + '-' + CONVERT(NVARCHAR(10), dim_customer_id) + '-' + [order_number]) AS id
			FROM [dbo].[fact_demand_total]
			WHERE
				dim_pdas_id = @pdasid and
				dim_business_id = @businessid
		) as target
		INNER JOIN
		(
			SELECT
				temp.[id]
				,temp.[Comment (VFA)]
				,df.[id] as	[dim_factory_id]
			FROM
				[dbo].[staging_pdas_footwear_vans_allocation_report_vfa] temp
				INNER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory]) df
					ON temp.[Factory Code VFA] = df.[short_name]
			WHERE
				[Factory Code VFA] <> [Factory Code (Constrained)]
		) as temp
			ON	target.[id] = temp.[id]
	WHERE
		target.[dim_factory_id] <> temp.[dim_factory_id] AND
		target.[comment_vfa] <> temp.[Comment (VFA)]

END
