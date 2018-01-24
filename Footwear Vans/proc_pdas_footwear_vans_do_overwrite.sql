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
--				Return process of vendors (update factory and comment)
--				Return process of
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_do_overwrite]
	@pdasid INT,
	@businessid INT
AS
BEGIN

	-- Declare variables
	DECLARE	@current_dt datetime = GETDATE()

	-- Update fact_demand_total based on staging_pdas_footwear_vans_allocation_report_vfa
	UPDATE target
	SET
		target.[dim_factory_id] = temp.[dim_factory_id]
		,target.[comment_vfa] = temp.[Allocation Comment (VFA)]
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
				,temp.[Allocation Comment (VFA)]
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
		target.[dim_factory_id] <> temp.[dim_factory_id]
		AND ISNULL(target.[comment_vfa], '') <> ISNULL(temp.[Allocation Comment (VFA)], '')


	-- Update fact_demand_total based on staging_pdas_footwear_vans_allocation_report_vendor
	UPDATE target
	SET
		target.[cy_csf_load] = temp.[CY / CFS Load]
		,target.[confirmed_crd_dt] = temp.[Confirmed CRD Dt (Vendor)]
		,target.[confirmed_unit_price_memo] = temp.[Confirmed Unit Price (Price Conf Memo)]
		,target.[min_surcharge] = temp.[Min Surcharge (Vendor)]
		,target.[confirmed_unit_price_vendor] = temp.[Confirmed Unit Price (Vendor)]
		,target.[nominated_supplier_name] = temp.[Nominated Supplier Name]
		,target.[comment_vendor] = temp.[Comment (Vendor)]
		,target.[confirmed_comp_eta_hk] = temp.[Confirm Comp. ETA HK]
		,target.[comment_comp_factory] = temp.[Comment (Comp. Fty)]
		,target.[buy_comment] = temp.[Buy Comment]
		,target.[status_orig_req] = temp.[Status (based on Orig Req)]
		,target.[performance_orig_req] = temp.[Performance (Orig Req Date)]
		,target.[] = [Requested CRD]
		-- ,target.[need_to_reallocate] = temp.[Need to reallocate]
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
				[id]
				,[CY / CFS Load]
				,[Confirmed CRD Dt (Vendor)]
				,[Confirmed Unit Price (Price Conf Memo)]
				,[Min Surcharge (Vendor)]
				,[Confirmed Unit Price (Vendor)]
				,[Nominated Supplier Name]
				,[Comment (Vendor)]
				,[Confirm Comp. ETA HK]
				,[Comment (Comp. Fty)]
				,[Buy Comment]
				,[Status (based on Orig Req)]
				,[Performance (Orig Req Date)]
			FROM
				[dbo].[staging_pdas_footwear_vans_allocation_report_vendor]
		) as temp
			ON	target.[id] = temp.[id]


		-- Update fact_demand_total based on mc_view_pdas_footwear_vans_allocation_report_region
		UPDATE target
		SET
			target.[remarks_region] = temp.[Remarks]
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
					[id]
					,[Remarks] as [remarks]
				FROM
					[dbo].[mc_view_pdas_footwear_vans_allocation_report_region]
			) as temp
				ON	target.[id] = temp.[id]
		WHERE
			target.[remarks] <> temp.[remarks]


END
