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
	@dim_release_id INT,
	@businessid INT
AS
BEGIN

	-- Declare variables
	DECLARE	@current_dt datetime = GETDATE()
	DECLARE @dim_factory_id_placeholder int = (SELECT [id] FROM [dbo].[dim_factory] WHERE [is_placeholder] = 1 AND [placeholder_level] = 'PLACEHOLDER')

	-- Update fact_demand_total based on staging_pdas_footwear_vans_allocation_report_region
	UPDATE target
	SET
		target.[remarks_region] = temp.[Remarks]
		,target.[comment_vfa_region] = temp.[Comment (VFA Region)]
		,target.[comment_region] = temp.[Comment (US/EU/APAC)]
		,target.[order_number_original] = temp.[Orig PO#]
		,target.[order_number] = temp.[PO#]
		,target.[order_number_cut] = temp.[PO/CUT#]
		,target.[pr_cut_code] = temp.[PR/CUT#]
		,target.[po_release_date] = temp.[PO release Date]
		,target.[system_error] = temp.[System Error]
		,target.[region_moq] = temp.[Regional MOQ]  
		,target.[customer_moq] = temp.[Order MOQ]        
		,target.[region_below_moq] = temp.[Below Regional Min]
		,target.[confirmed_price_in_solid_size] = temp.[Confirmed Price in Solid Size]
		,target.[upcharge] = temp.[upcharge]
		,target.[fabriq_moq] = temp.[Fabric MOQ]
		,target.[confirmed_unit_price_po] = temp.[Confirmed Unit Price (for this PO)]
	FROM
		(
			SELECT
				*
			FROM [dbo].[fact_demand_total]
			WHERE
				dim_release_id = @dim_release_id and
				dim_business_id = @businessid
		) as target
		INNER JOIN
		(
			SELECT
				[id_original]
				,[Remarks]
				,[Comment (VFA Region)]
				,[Comment (US/EU/APAC)]
				,ISNULL([Orig PO#], 'UNDEFINED') [Orig PO#]
				,ISNULL([PO#], 'UNDEFINED') [PO#]
				,[PO/CUT#]
				,[PR/CUT#]
				,[PO release Date]
				,[System Error]
				,[Regional MOQ]  
				,[Order MOQ]  
				,CASE [Below Regional Min]
				   WHEN 'Y' THEN 1
				   ELSE 0
				END as [Below Regional Min]
				,[Confirmed Price in Solid Size]
				,[upcharge]
				,[Fabric MOQ]
				,[Confirmed Unit Price (for this PO)]
			FROM
				[dbo].[staging_pdas_footwear_vans_allocation_report_region]
		) as temp
			ON
				target.[id] = temp.[id_original]
	-- WHERE
	-- 	target.[remarks_region] <> temp.[remarks]


	-- Update fact_demand_total based on staging_pdas_footwear_vans_allocation_report_vendor
	UPDATE target
	SET
		target.[cy_csf_load] = temp.[CY / CFS Load]
		,target.[confirmed_crd_dt] = temp.[Confirmed CRD Dt (Vendor)]
		,target.[confirmed_unit_price_memo] = temp.[Confirmed Unit Price (Price Conf Memo)]
		,target.[min_surcharge] = temp.[Min Surcharge (Vendor)]
		,target.[confirmed_unit_price_vendor] = temp.[Confirmed Unit Price (Vendor)]
		,target.[production_lt_actual_vendor] = DATEDIFF(DAY, target.[buy_d], temp.[Confirmed CRD Dt (Vendor)])
		,target.[nominated_supplier_name] = temp.[Nominated Supplier Name]
		,target.[comment_vendor] = temp.[Comment (Vendor)]
		,target.[confirmed_comp_eta_hk] = temp.[Confirm Comp. ETA HK]
		,target.[comment_comp_factory] = temp.[Comment (Comp. Fty)]
		,target.[buy_comment] = temp.[Buy Comment]
		,target.[status_orig_req] = temp.[status_orig_req]
		,target.[performance_orig_req] = perf.[delivery_performance]
		,target.[need_to_reallocate] = temp.[Need to reallocate]
		,target.[dim_date_id] = temp.[dim_date_id]
		,target.[dim_factory_id_final] = temp.[dim_factory_id_final]
		,target.[comment_vfa_vendor] = temp.[Comment (VFA Vendor)]
	FROM
		(
			SELECT
				f.*,
				dd.[full_date] as [buy_d]
			FROM
				[dbo].[fact_demand_total] f
				INNER JOIN [dim_release] dpdas
					ON f.[dim_release_id] = dpdas.[id]
				INNER JOIN [dim_date] dd
					ON dpdas.[dim_date_id] = dd.[id]
			WHERE
				dim_release_id = @dim_release_id and
				dim_business_id = @businessid
		) as target
		INNER JOIN
		(
			SELECT
				[id_original]
				,[CY / CFS Load]
				,CONVERT(DATE, [Confirmed CRD Dt (Vendor)]) as [Confirmed CRD Dt (Vendor)]
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
				,[Need to reallocate]
				,[PO/CUT#]
				,[Comment (VFA Vendor)]
				,DATEDIFF(DAY, [Rev. Requested CRD], [Confirmed CRD Dt (Vendor)]) as [status_orig_req]
				,dd.[id] AS [dim_date_id]
				, CASE
					WHEN ISNULL(df.[id], 0) = 0 THEN @dim_factory_id_placeholder
					ELSE df.[id]
				END AS [dim_factory_id_final]
			FROM
				[dbo].[staging_pdas_footwear_vans_allocation_report_vendor] temp
				INNER JOIN [dbo].[dim_date] dd
					ON temp.[Rev. Requested CRD] = dd.[full_date]
				LEFT OUTER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory]) df
					ON temp.[Final Factory Allocation] = df.[short_name]
		) as temp
			ON target.[id] = temp.[id_original]

		LEFT OUTER JOIN [dbo].[helper_pdas_footwear_vans_performance] perf
			ON temp.[status_orig_req] = perf.[days_delay]


	-- Update fact_demand_total based on staging_pdas_footwear_vans_allocation_report_vfa
	UPDATE target
	SET
		target.[dim_factory_id] = temp.[dim_factory_id]
		,target.[comment_vfa_allocation] = temp.[Allocation Comment (VFA)]
		,target.[comment_vfa] = temp.[Comment (VFA)]
		,target.[edit_dt] = @current_dt
		,target.[component_factory_short_name] = temp.[COMP FTY]
	FROM
		(
			SELECT
				*
			FROM [dbo].[fact_demand_total]
			WHERE
				dim_release_id = @dim_release_id and
				dim_business_id = @businessid
		) as target
		INNER JOIN
		(
			SELECT
				temp.[id_original]
				,temp.[Allocation Comment (VFA)]
				,temp.[Comment (VFA)]
				,temp.[COMP FTY]
				,df.[id] as	[dim_factory_id]
			FROM
				[dbo].[staging_pdas_footwear_vans_allocation_report_vfa] temp
				INNER JOIN (SELECT [id], [short_name] FROM [dbo].[dim_factory]) df
					ON temp.[Factory Code VFA] = df.[short_name]
		) as temp
			ON target.[id] = temp.[id_original]
	-- WHERE
	-- 	(
	-- 		target.[dim_factory_id] <> temp.[dim_factory_id]
	-- 		-- AND ISNULL(target.[comment_vfa], '') <> ISNULL(temp.[Allocation Comment (VFA)], '')
	-- 	)
	-- 	or target.[component_factory_short_name] <> temp.[COMP FTY]

END
