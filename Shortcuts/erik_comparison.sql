SELECT
    year(dbo.staging_pdas_footwear_vans_ngc_po.original_crd_dt) [Gregorian Year],
    month(dbo.staging_pdas_footwear_vans_ngc_po.original_crd_dt) [Gregorian Month],
    sum(dbo.staging_pdas_footwear_vans_ngc_po.order_qty) [Total Quantity],
    Count(*)  [No of Rows]
FROM
    dbo.staging_pdas_footwear_vans_ngc_po
where
[po_code_cut] is null
group by year(dbo.staging_pdas_footwear_vans_ngc_po.original_crd_dt), month(dbo.staging_pdas_footwear_vans_ngc_po.original_crd_dt)
order by year(dbo.staging_pdas_footwear_vans_ngc_po.original_crd_dt), month(dbo.staging_pdas_footwear_vans_ngc_po.original_crd_dt)




SELECT
    year(dbo.dim_date.full_date)                   [Gregorian Year],
    month(dbo.dim_date.full_date)                  [Gregorian Month],
    sum(dbo.fact_order_ngc_only.quantity_non_lum)  [Total Quantity],
    Count(*)                                      [No of Rows]
FROM
    dbo.fact_order_ngc_only
    INNER JOIN dbo.dim_date
        ON dbo.dim_date.id = dbo.fact_order_ngc_only.dim_date_id
where year(dbo.dim_date.full_date)='2017'
group by year(dbo.dim_date.full_date), month(dbo.dim_date.full_date)
order by year(dbo.dim_date.full_date), month(dbo.dim_date.full_date)
