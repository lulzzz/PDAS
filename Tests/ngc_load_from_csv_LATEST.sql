SELECT
	year(convert(date, [actual_crd_dt])) y,
	month(convert(date, [actual_crd_dt])) m,
	sum(convert(int, order_qty)) qty,
	count(*) c
  FROM
	[dbo].[staging_pdas_footwear_vans_ngc_po]
group by year(convert(date, [actual_crd_dt])), month(convert(date, [actual_crd_dt]))
order by y, m


delete from [staging_pdas_footwear_vans_ngc_po]
where
year(convert(date, revised_crd_dt)) >= 2018
