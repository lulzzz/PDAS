

SELECT
	year([revised_crd_dt]) y,
	month([revised_crd_dt]) m,
	sum([order_qty])
FROM
	[dbo].[staging_pdas_footwear_vans_ngc_po] ngc
		LEFT OUTER JOIN
		(
			SELECT [id], [material_id]
			FROM [dbo].[dim_product]
			WHERE
				[is_placeholder] = 1 AND
				[placeholder_level] = 'material_id'
		) AS dp_m
		 	ON ngc.dim_product_style_id = dp_m.material_id
		LEFT OUTER JOIN (SELECT [id], [material_id], [size] FROM [dbo].[dim_product] WHERE is_placeholder = 0) dp_ms
			ON 	ngc.dim_product_style_id = dp_ms.material_id AND
				ngc.dim_product_size = dp_ms.size
	 	LEFT OUTER JOIN [dbo].[dim_factory] df ON ngc.dim_factory_factory_code = df.short_name
		LEFT OUTER JOIN
		(
			SELECT df.id, m.child
			FROM
				[dbo].[helper_pdas_footwear_vans_mapping] m
				INNER JOIN (SELECT id, short_name FROM [dbo].[dim_factory]) df
					ON m.parent = df.short_name
			WHERE type = 'Factory Master'
		) mapping_f ON ngc.dim_factory_factory_code = mapping_f.child
		INNER JOIN [dbo].[dim_date] dd_revised_crd ON ngc.revised_crd_dt = dd_revised_crd.full_date
		INNER JOIN [dbo].[dim_date] dd_original_crd ON ngc.original_crd_dt = dd_original_crd.full_date
WHERE
		(dp_ms.id IS NOT NULL OR dp_m.id IS NOT NULL) AND
		(df.id IS NOT NULL OR mapping_f.id IS NOT NULL)
group by
year([revised_crd_dt]),
month([revised_crd_dt])
order by y, m


EXEC [dbo].[proc_pdas_footwear_vans_load_fact_order_ngc] @pdasid = 1, @businessid = 1
EXEC [dbo].[proc_pdas_footwear_vans_load_fact_demand_total]	@pdasid = 1, @businessid = 1
