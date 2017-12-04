SELECT
	year(original_crd_dt) y,
	month(original_crd_dt) m,
	sum(order_qty) qty,
	count(*) c
  FROM
	[dbo].[staging_pdas_footwear_vans_ngc_po_init2017]
group by year(original_crd_dt), month(original_crd_dt)
order by y, m


SELECT
	year(convert(date, [actual_crd_dt])) y,
	month(convert(date, [actual_crd_dt])) m,
	sum(convert(int, order_qty)) qty,
	count(*) c
  FROM
	[dbo].[staging_pdas_footwear_vans_ngc_po_csv_text]
group by year(convert(date, [actual_crd_dt])), month(convert(date, [actual_crd_dt]))
order by y, m
