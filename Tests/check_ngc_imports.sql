SELECT
	year(convert(date, [actual_crd_dt])) y,
	month(convert(date, [actual_crd_dt])) m,
	sum(convert(int, order_qty)) qty,
	count(*) c
  FROM
	[dbo].[staging_pdas_footwear_vans_ngc_po]
group by year(convert(date, [actual_crd_dt])), month(convert(date, [actual_crd_dt]))
order by y, m


select
    year(convert(date, dd.full_date)) y,
	month(convert(date, dd.full_date)) m,
	sum(quantity)
from
  fact_demand_total as f_1
  INNER JOIN dim_demand_category
       ON f_1.dim_demand_category_id = dim_demand_category.id
   INNER JOIN dim_date dd
       ON f_1.dim_date_id = dd.id
where
   dim_pdas_id = (select max(id) from dim_pdas)
   and dim_demand_category.name in (
       'Open Order',
       'Shipped Order'
   )
group by
    year(convert(date, dd.full_date)) y,
	month(convert(date, dd.full_date)) m
order by
    year(convert(date, dd.full_date)) y,
	month(convert(date, dd.full_date)) m
