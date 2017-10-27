SELECT
	year(original_crd_dt) y,
	month(original_crd_dt) m,
	sum(order_qty) qty,
	count(*) c
  FROM
	[dbo].[staging_pdas_footwear_vans_ngc_po_init2014]
group by year(original_crd_dt), month(original_crd_dt)
order by y, m
