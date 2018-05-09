


insert into [fact_demand_total_bkp_20180502]
select * from [fact_demand_total]

-- Remove duplicates
DELETE x FROM (
	SELECT *, rn=row_number() OVER (PARTITION BY
		[dim_pdas_id]
		,[dim_buying_program_id]
		,[dim_product_id]
		,[dim_date_id]
		,[dim_date_id_buy_month]
		,[dim_customer_id]
		,[dim_demand_category_id]
		,[pr_code]
		,[pr_cut_code]
	ORDER BY
		[dim_pdas_id]
		,[dim_buying_program_id]
		,[dim_product_id]
		,[dim_date_id]
		,[dim_date_id_buy_month]
		,[dim_customer_id]
		,[dim_demand_category_id]
		,[pr_code]
		,[pr_cut_code]
	)
	FROM [dbo].[fact_demand_total]
	WHERE
		[dim_demand_category_id] in (21, 22)
		and [dim_pdas_id] >
) x
WHERE rn > 1;
