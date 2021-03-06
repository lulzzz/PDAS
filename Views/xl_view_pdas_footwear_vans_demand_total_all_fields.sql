SELECT
	-- fact_demand_total
	f_1.[id]
	,f_1.[id] as [id_original]
	, 0 as [is_from_previous_release]
	, f_1.[dim_release_id]
	, f_1.[dim_business_id]
	, f_1.[dim_buying_program_id]
	, f_1.[dim_product_id]
	, dim_product.dim_construction_type_id as dim_construction_type_id
	, f_1.[dim_date_id]
	, f_1.[dim_date_id_original]
	, f_1.[dim_date_id_buy_month]
	, f_1.[dim_factory_id_original_unconstrained]
	, f_1.[dim_factory_id_original_constrained]
	,CASE
	   WHEN f_1.dim_factory_id_original_unconstrained = f_1.dim_factory_id_original_constrained THEN 'N'
	   ELSE 'Y'
	END AS [is_reallocated]
	, f_1.[dim_factory_id_final]
	, f_1.[dim_factory_id]
	, f_1.[dim_customer_id]
	, f_1.[dim_demand_category_id]
	, f_1.[order_number_original]
	, f_1.[order_number]
	, f_1.[order_number_cut]
	, LEFT(f_1.[order_number], 10) as [order_number_short]
	, f_1.[pr_code]
	, f_1.[pr_cut_code]
	, f_1.[po_code_customer]
	, f_1.[so_code]
	,CASE f_1.is_asap
	   WHEN 1 THEN 'ASAP'
	   ELSE ''
	END AS [is_asap]
	, f_1.[quantity_lum]
	, f_1.[quantity_non_lum]
	, f_1.[quantity_non_lum] as [quantity_unconsumed]
	, f_1.[quantity_non_lum] as [quantity]
	, f_1.[quantity_region_mtl_lvl]
	, f_1.[quantity_customer_mtl_lvl]
	, f_1.[comment_vfa_allocation]
	, f_1.[comment_vfa]
	, f_1.[edit_dt]
	, f_1.[allocation_logic_unconstrained]
	, f_1.[allocation_logic_constrained]
	, f_1.[customer_moq]
	,CASE
	   WHEN f_1.[customer_moq] >= 240 THEN '>= 240'
	   WHEN f_1.[customer_moq] BETWEEN 96 AND 239 THEN '96 - 239'
	   ELSE '< 96'
	END AS [customer_moq_label]
	,CASE f_1.[customer_below_moq]
	   WHEN 1 THEN 'Y'
	   ELSE 'N'
	END AS [customer_below_moq]
	, f_1.[region_moq]
	,CASE
	   WHEN f_1.[region_moq] >= 480 THEN '>= 480'
	   WHEN f_1.[region_moq] BETWEEN 240 AND 479 THEN '240 - 479'
	   WHEN f_1.[region_moq] BETWEEN 96 AND 239 THEN '96 - 239'
	   ELSE '< 96'
	END AS [region_moq_label]
	,CASE f_1.[region_below_moq]
	   WHEN 1 THEN 'Y'
	   ELSE 'N'
	END AS [region_below_moq]
	, f_1.[upcharge]
	,CASE f_1.is_rejected
	   WHEN 1 THEN 'Y'
	   ELSE 'N'
	END AS [is_rejected]
	,CASE dim_customer.[region]
	   WHEN 'EMEA' THEN dim_product.material_id_emea
	   ELSE f_1.[material_id_sr]
	END AS [material_id_sr]
	, f_1.[component_factory_short_name]
	, f_1.[production_lt_actual_buy]
	, f_1.[production_lt_actual_vendor]
	, f_1.[comment_region]
	, f_1.[sold_to_customer_name]
	, f_1.[mcq]
	, f_1.[musical_cnt]
	, f_1.[delivery_d]
	, f_1.[confirmed_price_in_solid_size]
	, f_1.[fabriq_moq]
	, f_1.[confirmed_crd_dt]
	, dim_date_confirmed_crd.[year_cw_accounting] as [confirmed_crd_cw]
	, f_1.[confirmed_unit_price_memo]
	, f_1.[confirmed_unit_price_po]
	, f_1.[cy_csf_load]
	, f_1.[min_surcharge]
	, CASE
		WHEN dim_customer.name = 'VF China Limited' and dim_factory_final.country = 'China' THEN 'RMB'
		ELSE 'USD'
	END as [currency]
	, f_1.[confirmed_unit_price_vendor]
	, f_1.[nominated_supplier_name]
	, f_1.[comment_vendor]
	, f_1.[confirmed_comp_eta_hk]
	, f_1.[comment_comp_factory]
	, f_1.[buy_comment]
	, f_1.[status_orig_req]
	, f_1.[performance_orig_req]
	, f_1.[smu]
	, f_1.[order_reference]
	, f_1.[sku_footlocker]
	, f_1.[prepack_code]
	, f_1.[exp_delivery_with_constraint]
	, f_1.[exp_delivery_without_constraint]
	, f_1.[coo]
	, f_1.[remarks_region]
	, f_1.[system_error]
	, f_1.[po_release_date]
	, f_1.[need_to_reallocate]
	, f_1.[comment_vfa_region]
	, f_1.[comment_vfa_vendor]
	, f_1.[colorway_name]
	, f_1.[style_description_long]
	, f_1.[single_or_dual_source]
	, f_1.[style_ranking]
	, f_1.[mtr_ranking]
	, f_1.[top_50_mtl]
	, f_1.[carton_qty]

	-- dim_release
	,'Current Release' AS [dim_pdas_name]

	,dim_release.[full_date] AS [dim_pdas_full_date]
	,dim_release.[comment] AS [dim_pdas_comment]

	-- dim_date_buy_month
	,dim_date_buy_month.[year_month_accounting] AS [dim_pdas_buy_month]

	-- dim_business
	,dim_business.[brand] AS [dim_business_brand]
	,dim_business.[product_line] AS [dim_business_product_line]

	-- dim_buying_program
	,dim_buying_program.[name] AS [dim_buying_program_name]
	,dim_buying_program.[name_short] AS [dim_buying_program_name_short]

	-- dim_product
	,dim_product.[material_id] AS [dim_product_material_id]
	,dim_product.[size] AS [dim_product_size]
	,dim_product.[style_id] AS [dim_product_style_id]
	,dim_product.[style_id_erp] AS [dim_product_style_id_erp]
	,dim_product.[color_description] AS [dim_product_color_description]
	,dim_product.[color_description_erp] AS [dim_product_color_description_erp]
	,dim_product.[style_name] AS [dim_product_style_name]
	,dim_product.[style_name_new] AS [dim_product_style_name_new]
	,dim_product.[material_description] AS [dim_product_material_description]
	,dim_product.[material_description_erp] AS [dim_product_material_description_erp]
	,dim_product.[product_type] AS [dim_product_product_type]
	,dim_product.[cat_sub_sbu] AS [dim_product_cat_sub_sbu]
	,dim_product.[type] AS [dim_product_type]
	,dim_product.[gender] AS [dim_product_gender]
	,dim_product.[gender_new] AS [dim_product_gender_new]
	,dim_product.[lifecycle] AS [dim_product_lifecycle]
	,dim_product.[product_cycle] AS [product_cycle]
	,dim_product.[style_complexity] AS [dim_product_style_complexity]
	,dim_product.[construction_type_name] AS [dim_product_construction_type_name]
	,CASE dim_customer.[region]
	   WHEN 'APAC' THEN dim_product.[sku]
	   ELSE NULL
	END AS [dim_product_sku]
	,CASE dim_product.[pre_build_mtl]
		WHEN 1 THEN 'Y'
		ELSE 'N'
	END AS [dim_product_pre_build_mtl]
	,CASE dim_product.[qt_mtl]
		WHEN 1 THEN 'Y'
		ELSE 'N'
	END AS [dim_product_qt_mtl]
	,CASE dim_product.[clk_mtl]
		WHEN 1 THEN 'Y'
		ELSE 'N'
	END AS [dim_product_clk_mtl]
	,CASE dim_product.[sjd_mtl]
		WHEN 1 THEN 'Y'
		ELSE 'N'
	END AS [dim_product_sjd_mtl]
	,CASE dim_product.[dtp_mtl]
		WHEN 1 THEN 'Y'
		ELSE 'N'
	END AS [dim_product_dtp_mtl]
	,CASE dim_product.[brt_in_house]
		WHEN 1 THEN 'Y'
		ELSE 'N'
	END AS [dim_product_brt_in_house]
	,dim_product.material_id_emea AS [dim_product_material_id_emea]
	,dim_product.start_ship_dt AS [start_ship_dt]
	,dim_product.wolverine_material AS [wolverine_material]
	,dim_product.last AS [last]
	,dim_product.costing_status AS [costing_status]
	,dim_product.confirmed_fob AS [confirmed_fob]

	-- dim_date
	,dim_date.[full_date] AS [dim_date_full_date]
	,dim_date.[season_buy] AS [dim_date_season_buy]
	,dim_date.[season_year_buy] AS [dim_date_season_year_buy]
	,dim_date.[season_year_short_buy] AS [dim_date_season_year_short_buy]
	,dim_date.[season_crd] AS [dim_date_season_crd]
	,dim_date.[season_year_crd] AS [dim_date_season_year_crd]
	,dim_date.[season_year_short_crd] AS [dim_date_season_year_short_crd]
	,dim_date.[season_intro] AS [dim_date_season_intro]
	,dim_date.[season_year_intro] AS [dim_date_season_year_intro]
	,dim_date.[season_year_short_intro] AS [dim_date_season_year_short_intro]
	,dim_date.[year_accounting] AS [dim_date_year_accounting]
	,RIGHT(dim_date.[year_cw_accounting], 4) AS [dim_date_year_cw_accounting]
	,dim_date.[month_name_short_accounting] AS [dim_date_year_month_accounting]
	,dim_date.[month_name_accounting] AS [dim_date_month_name_accounting]
	,dim_date.[month_name_short_accounting] AS [dim_date_month_name_short_accounting]

	-- dim_date_original
	,dim_date_original.[full_date] AS [dim_date_original_full_date]

	-- dim_factory_original_unconstrained
	,dim_factory_original_unconstrained.vendor_group AS [dim_factory_original_unconstrained_vendor_group]
	,dim_factory_original_unconstrained.short_name AS [dim_factory_original_unconstrained_short_name]
	,dim_factory_original_unconstrained.port AS [dim_factory_original_unconstrained_port]
	,dim_factory_original_unconstrained.region AS [dim_factory_original_unconstrained_region]
	,dim_factory_original_unconstrained.country AS [dim_factory_original_unconstrained_country]

	-- dim_factory_original_constrained
	,dim_factory_original_constrained.vendor_group AS [dim_factory_original_constrained_vendor_group]
	,dim_factory_original_constrained.short_name AS [dim_factory_original_constrained_short_name]
	,dim_factory_original_constrained.port AS [dim_factory_original_constrained_port]
	,dim_factory_original_constrained.region AS [dim_factory_original_constrained_region]
	,dim_factory_original_constrained.country AS [dim_factory_original_constrained_country]

	-- dim_factory (constrained overwritten by VFA)
	,dim_factory.vendor_group AS [dim_factory_vendor_group]
	,dim_factory.short_name AS [dim_factory_short_name]
	,dim_factory.port AS [dim_factory_port]
	,dim_factory.region AS [dim_factory_region]
	,dim_factory.country AS [dim_factory_country]

	-- dim_factory (constrained overwritten by VFA and returned by vendor)
	,dim_factory_final.vendor_group AS [dim_factory_final_vendor_group]
	,dim_factory_final.short_name AS [dim_factory_final_short_name]
	,dim_factory_final.valid_acadia_fty_plant_code AS [dim_factory_final_valid_acadia_fty_plant_code]
	,dim_factory_final.valid_acadia_vendor_code_1505_1510 AS [dim_factory_final_valid_acadia_vendor_code_1505_1510]
	,dim_factory_final.valid_acadia_vendor_code_1550_mexico AS [dim_factory_final_valid_acadia_vendor_code_1550_mexico]
	,dim_factory_final.condor_factory_code_brazil AS [dim_factory_final_condor_factory_code_brazil]
	,dim_factory_final.condor_vendor_code_brazil AS [dim_factory_final_condor_vendor_code_brazil]
	,dim_factory_final.condor_factory_code_chile AS [dim_factory_final_condor_factory_code_chile]
	,dim_factory_final.condor_vendor_code_chile AS [dim_factory_final_condor_vendor_code_chile]
	,dim_factory_final.eu_supplier_code AS [dim_factory_final_eu_supplier_code]
	,dim_factory_final.reva_vendor_fty AS [dim_factory_final_reva_vendor_fty]
	,dim_factory_final.reva_agent_vendor AS [dim_factory_final_reva_agent_vendor]
	,CASE dim_customer.[region]
	   WHEN 'APAC' THEN dim_factory_final.reva_vendor_fty
	   ELSE dim_factory_final.valid_acadia_fty_plant_code
	END AS [vendor_plnt_conf]
	,CASE dim_customer.[region]
	   WHEN 'APAC' THEN dim_factory_final.reva_agent_vendor
	   ELSE dim_factory_final.valid_acadia_vendor_code_1505_1510
	END AS [vendor_number_conf]

	-- dim_customer
	,dim_customer.[name] AS [dim_customer_name]
	,dim_customer.[market] AS [dim_customer_market]
	,dim_customer.[dc_plt] AS [dim_customer_dc_plt]
	,dim_customer.[sold_to_party] AS [dim_customer_sold_to_party]
	,dim_customer.[region] AS [dim_customer_region]
	,dim_customer.[country] AS [dim_customer_country]

	-- dim_demand_category
	,dim_demand_category.[name] AS [dim_demand_category_name]

	-- fact_priority_list
	,fact_priority_list.[factory_short_name_1] AS [fact_priority_list_factory_short_name_1]
	,fact_priority_list.[factory_short_name_2] AS [fact_priority_list_factory_short_name_2]
	,fact_priority_list.[production_lt] AS [fact_priority_list_production_lt]
	,fact_priority_list.[llt] AS [fact_priority_list_llt]
	,fact_priority_list.[co_cu_new] AS [fact_priority_list_co_cu_new]
	,fact_priority_list.[asia_development_buy_ready] AS [fact_priority_list_asia_development_buy_ready]

	-- helper_pdas_footwear_vans_fty_qt
	,helper_pdas_footwear_vans_fty_qt.dim_factory_short_name as helper_pdas_footwear_vans_fty_qt_factory_short_name

	-- helper_pdas_footwear_vans_retail_qt
	,helper_pdas_footwear_vans_retail_qt.dim_factory_short_name as helper_pdas_footwear_vans_retail_qt_factory_short_name

	-- placeholder fields
	,NULL as [placeholder_field01]
	,NULL as [placeholder_field02]
	,NULL as [placeholder_field03]

FROM
	(
		SELECT *
		FROM fact_demand_total
		WHERE
			dim_release_id = (SELECT MAX([dim_release_id]) FROM [dbo].[helper_pdas_footwear_vans_release_current]) AND
			dim_business_id = (SELECT id FROM dim_business WHERE (brand = 'Vans') AND (product_line = 'Footwear'))
	) AS f_1

	INNER JOIN
	(
		SELECT dim_release.*, dd.[full_date]
		FROM
			dim_release
			INNER JOIN (SELECT [id], [full_date] FROM [dbo].[dim_date]) dd
				ON dim_release.dim_date_id = dd.[id]
	) dim_release
		ON f_1.dim_release_id = dim_release.id

	INNER JOIN
	(
		SELECT *
		FROM [dbo].[dim_date]
	) dim_date_buy_month
		ON f_1.dim_date_id_buy_month = dim_date_buy_month.id

	INNER JOIN dim_business
		ON f_1.dim_business_id = dim_business.id

	INNER JOIN dim_buying_program
		ON f_1.dim_buying_program_id = dim_buying_program.id

	INNER JOIN
	(
		SELECT dp.*, dct.[name] AS [construction_type_name]
		FROM
			dim_product dp
			INNER JOIN dim_construction_type dct
			 ON dp.dim_construction_type_id = dct.[id]
	) dim_product
		ON f_1.dim_product_id = dim_product.id

	INNER JOIN dim_date
		ON f_1.dim_date_id = dim_date.id

	INNER JOIN dim_date as dim_date_original
		ON f_1.dim_date_id_original = dim_date_original.id

	INNER JOIN
	(
		SELECT df.*, dl.[region], dl.[country]
		FROM
			dim_factory df
			INNER JOIN dim_location dl
			 ON df.dim_location_id = dl.[id]
	) dim_factory_original_unconstrained
		ON f_1.dim_factory_id_original_unconstrained = dim_factory_original_unconstrained.id

	INNER JOIN
	(
		SELECT df.*, dl.[region], dl.[country]
		FROM
			dim_factory df
			INNER JOIN dim_location dl
			 ON df.dim_location_id = dl.[id]
	) dim_factory_original_constrained
		ON f_1.dim_factory_id_original_constrained = dim_factory_original_constrained.id

	INNER JOIN
	(
		SELECT df.*, dl.[region], dl.[country]
		FROM
			dim_factory df
			INNER JOIN dim_location dl
			 ON df.dim_location_id = dl.[id]
	) dim_factory_final
		ON f_1.dim_factory_id_final = dim_factory_final.id

	INNER JOIN
	(
		SELECT df.*, dl.[region], dl.[country]
		FROM
			dim_factory df
			INNER JOIN dim_location dl
			 ON df.dim_location_id = dl.[id]
	) dim_factory
		ON f_1.dim_factory_id = dim_factory.id

	INNER JOIN
	(
		SELECT dc.*, dl.[region], dl.[country]
		FROM
			dim_customer dc
			INNER JOIN dim_location dl
			 ON dc.dim_location_id = dl.[id]
	) dim_customer
		ON f_1.dim_customer_id = dim_customer.id

	INNER JOIN dim_demand_category
		ON f_1.dim_demand_category_id = dim_demand_category.id

	LEFT OUTER JOIN
	(
		SELECT
			dp.[material_id] AS [dim_product_material_id]
			,df1.[short_name] AS [factory_short_name_1]
			,df2.[short_name] AS [factory_short_name_2]
			,[production_lt]
			,[llt]
			,[co_cu_new]
			,[asia_development_buy_ready]
		FROM
			fact_priority_list f
			INNER JOIN (SELECT [id], [material_id] FROM [dbo].[dim_product] WHERE [is_placeholder] = 1) dp
                ON f.[dim_product_id] = dp.[id]
			INNER JOIN dim_factory AS df1
				ON f.dim_factory_id_1 = df1.id
			LEFT OUTER JOIN dim_factory AS df2
				ON f.dim_factory_id_2 = df2.id
		WHERE
			dim_release_id = (SELECT MAX([dim_release_id]) FROM [dbo].[helper_pdas_footwear_vans_release_current])
	) AS fact_priority_list
		ON dim_product.material_id = fact_priority_list.[dim_product_material_id]

	LEFT OUTER JOIN
	(
		SELECT
			[material_id] as dim_product_material_id
			,MAX([qt_leadtime]) as qt_leadtime
			,MAX([factory_short_name]) as dim_factory_short_name
		FROM
			[helper_pdas_footwear_vans_fty_qt]
		GROUP BY
			[material_id]
	) helper_pdas_footwear_vans_fty_qt
		ON helper_pdas_footwear_vans_fty_qt.dim_product_material_id = dim_product.material_id

	LEFT OUTER JOIN
	(
		SELECT
			[material_id] as dim_product_material_id
      		,[buying_program_name] as dim_buying_program_name
      		,[region] as dim_customer_region
      		,[sold_to_party] as dim_customer_sold_to_party
			,MAX([factory_short_name]) as dim_factory_short_name
		FROM
			[helper_pdas_footwear_vans_retail_qt]
		GROUP BY
			[material_id]
			,[buying_program_name]
			,[region]
			,[sold_to_party]
	) helper_pdas_footwear_vans_retail_qt
		ON
			helper_pdas_footwear_vans_retail_qt.dim_product_material_id = dim_product.material_id
			and helper_pdas_footwear_vans_retail_qt.dim_buying_program_name = dim_buying_program.name
			and helper_pdas_footwear_vans_retail_qt.dim_customer_region = dim_customer.region
			and helper_pdas_footwear_vans_retail_qt.dim_customer_sold_to_party = dim_customer.sold_to_party

	LEFT OUTER JOIN dim_date AS dim_date_confirmed_crd
		ON f_1.[confirmed_crd_dt] = dim_date_confirmed_crd.full_date
