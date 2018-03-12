select
    dim_demand_category.name,
    dd.[year_month_accounting],
	count(*),
    sum(quantity_lum)
from
    fact_demand_total as f_1
    INNER JOIN dim_demand_category
		ON f_1.dim_demand_category_id = dim_demand_category.id
    INNER JOIN [dbo].[dim_date] dd
		ON f_1.dim_date_id = dd.id
where dim_pdas_id = (select max(id) from dim_pdas)
group by
	 dim_demand_category.name,
     dd.[year_month_accounting]
