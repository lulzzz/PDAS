

SELECT
	dd.year_month_accounting m
	,sum([quantity_lum]) q
  FROM
	[VCDWH].[dbo].[fact_demand_total] f
	inner join dim_date dd
		on f.dim_date_id = dd.id
	inner join  [dim_demand_category] ddc
		ON f.dim_demand_category_id = ddc.id
  where
      [dim_pdas_id] = (select max(id) from dim_pdas)
      and [dim_business_id] = 1
	  and ddc.name in ('Shipped Order', 'Open Order')
 group by
	dd.year_month_accounting
order by
	dd.year_month_accounting
