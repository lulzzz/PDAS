USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 9/12/2017
-- Update date: 6/4/2018
-- Description:	Code to transfer the NGC data into the staging area (delta only!)
--              This procedure is meant to run on a nightly basis (SQL job agent task)
-- ==============================================================

-- Declare variables
DECLARE	@current_dt datetime = GETDATE()
DECLARE	@starting_dt_rev datetime = DATEADD(month, -1, @current_dt)


-- Delete latest delta
DELETE FROM [dbo].[staging_pdas_footwear_vans_ngc_po_delta]

-- Dump data into temp table
INSERT INTO [dbo].[staging_pdas_footwear_vans_ngc_po_delta]
(
    [Row #]
    ,[dim_factory_vendor_code]
    ,[dim_factory_factory_code]
    ,[po_code_cut]
    ,[dim_product_sbu]
    ,[dim_product_size]
    ,[dim_product_color_description]
    ,[dimension]
    ,[po_issue_dt]
    ,[shipment_status]
    ,[source]
    ,[order_qty]
    ,[shipped_qty]
    ,[dim_product_style_id]
    ,[ship_to_address]
    ,[ship_to_address_bis]
    ,[po_code]
    ,[po_type]
    ,[vf_sla]
    ,[dim_customer_dc_code_brio]
    ,[actual_crd_dt]
    ,[revised_crd_dt]
    ,[shipped_dt]
    ,[delay_reason]
    ,[shipment_id]
    ,[lum_order_qty]
    ,[lum_shipped_qty]
    ,[source_system]
    ,[shipment_closed_on_dt]
    ,[is_po_completed]
    ,[dc_name]
    ,[sales_order]
)

SELECT
	NULL as [Row #],
    LTRIM(RTRIM(Prbunhea.rdacode)) AS [dim_factory_vendor_code],
    LTRIM(RTRIM(Prbunhea.rfactory)) AS [dim_factory_factory_code],
    LTRIM(RTRIM(Prbunhea.lot)) AS [po_code_cut],
    LTRIM(RTRIM(Prbunhea.misc1)) AS [dim_product_sbu],
    LTRIM(RTRIM(Nbbundet.size)) AS [dim_product_size],
    LTRIM(RTRIM(Nbbundet.color)) AS [dim_product_color_description],
    LTRIM(RTRIM(Nbbundet.dimension)) AS [dimension],
    LTRIM(RTRIM(Prbunhea.plan_date)) AS [po_issue_dt],
    LTRIM(RTRIM(Shipment.closed)) AS [shipment_status],
    LTRIM(RTRIM(Prbunhea.misc6)) AS [source],
    LTRIM(RTRIM(Nbbundet.qty)) AS [order_qty],
    LTRIM(RTRIM(Shipped.unitship)) AS [shipped_qty],
    LTRIM(RTRIM(Prbunhea.style)) AS [dim_product_style_id],
    NULL AS [ship_to_address],
    NULL AS [ship_to_address_bis],
    LTRIM(RTRIM(Prbunhea.ship_no)) AS [po_code],
    LTRIM(RTRIM(Prbunhea.misc25)) AS [po_type],
    LTRIM(RTRIM(Prbunhea.misc41)) AS [vf_sla],
    LTRIM(RTRIM(Prbunhea.store_no)) AS [dim_customer_dc_code_brio],
    LTRIM(RTRIM(Shipped.Actual_CRD)) AS [actual_crd_dt],
    LTRIM(RTRIM(Prbunhea.revdd)) AS [revised_crd_dt],
    LTRIM(RTRIM(Shipped.shipdate)) AS [shipped_dt],
    LTRIM(RTRIM(Prbunhea.misc18)) AS [delay_reason],
    LTRIM(RTRIM(Shipped.shipment)) AS [shipment_ID],
    CASE
        WHEN ISNULL(prscale.desce, 0) = 0 THEN Nbbundet.qty
        ELSE LTRIM(RTRIM(Nbbundet.qty*prscale.desce))
    END AS [lum_order_qty],
    CASE
        WHEN ISNULL(prscale.desce, 0) = 0 THEN shipped.unitship
        ELSE LTRIM(RTRIM(shipped.unitship*prscale.desce))
    END AS [lum_shipped_qty],
    LTRIM(RTRIM( Prbunhea.misc21)) AS [source_system],
    LTRIM(RTRIM(Shipment.firstclosedon)) AS [shipment_closed_on_dt],
    LTRIM(RTRIM(Prbunhea.done)) AS [is_po_completed],
    LTRIM(RTRIM(Shipmast.shipname)) AS [dc_name],
    LTRIM(RTRIM(Prbunhea.misc27)) AS [sales_order]
FROM

	[ITGC2W000187].[ESPSODV14RPT].[dbo].Prbunhea
    LEFT OUTER JOIN [ITGC2W000187].[ESPSODV14RPT].[dbo].Nbbundet WITH (nolock)
        ON (Prbunhea.Id_Cut=Nbbundet.Id_Cut)
    LEFT OUTER JOIN [ITGC2W000187].[ESPSODV14RPT].[dbo].Shipped WITH (nolock)
        ON
        (
            Prbunhea.Season=Shipped.Season AND
            Prbunhea.Style=Shipped.Style AND
            Prbunhea.Lot=Shipped.Cut AND
            Nbbundet.Color=Shipped.Color AND
            Nbbundet.Size=Shipped.Size AND
            Nbbundet.Dimension=Shipped.Dimension
        )
    LEFT OUTER JOIN [ITGC2W000187].[ESPSODV14RPT].[dbo].Shipment WITH (nolock)
        ON (Shipped.Shipment=Shipment.Shipment)
    LEFT OUTER JOIN [ITGC2W000187].[ESPSODV14RPT].[dbo].Shipmast WITH (nolock)
        ON (Shipmast.shipno=Prbunhea.Store_No)
    LEFT OUTER JOIN [ITGC2W000187].[ESPSODV14RPT].[dbo].prscale WITH (nolock)
        ON (nbbundet.size=prscale.scale)

WHERE
    Prbunhea.revdd >= @starting_dt_rev
    AND Prbunhea.Misc6 NOT IN ('DIRECT BRAZIL')
    AND Prbunhea.Misc1 IN ('50 VANS FOOTWEAR', '503', '503 VN_Footwear', '508', '508 VN_Snow Footwear', '56 VANS SNOWBOOTS', 'VANS Footwear', 'VANS FOOTWEAR', 'VANS Snowboots', 'VANS SNOWBOOTS', 'VF  Vans Footwear', 'VN_Footwear', 'VN_Snow Footwear', 'VS  Vans Snowboots')
    AND NOT (Prbunhea.Qtyship=0 AND Prbunhea.Done=1)
    AND NOT (Nbbundet.qty=0)
	AND Prbunhea.POLocation <> 'CANCELED'
    AND Prbunhea.Misc25 IN ('DS', 'DYO', 'PG', 'REGULAR', 'ZCS', 'ZCUS', 'ZDIR', 'ZFGP', 'ZOT', 'ZRDS', 'ZTP', 'ZVFL','ZVFS','Z002','Z003','Z004')
    AND Prbunhea.store_no NOT IN (
        'DP0NS','DP1D','DPBO','DPBS','DPCH1','DPDEN','DPFIN','DPK3','DPN7','DPN8','DPNNS','DPNO1','DPNS','DPNU3','DPR1D','DPSEV','DPSWE','DPSWV','DPTB','DPTD','DPTE','DPTF1','DPTF2','DPTI','DPTK','DPTS','DPTU1','DPTU2','DPTU3','DPTU4','DPTZ','DPU3','DPVA1','DPVB2','DPVB3','DPVC0','DPVC1','DPVC2','DPVE1','DPVE2','DPVE3','DPVE4','DPVE5','DPVE6','DPVF1','DPVF2','DPVF3','DPVF4','DPVF5','DPVG1','DPVG2','DPVG3','DPVG4','DPVG5','DPVG6','DPVG7','DPVI0','DPVI1','DPVI2','DPVI3','DPVI4','DPVI5','DPVI6','DPVI7','DPVI8','DPVI9','DPVN1','DPVS0','DPVU1','DPVU2','DPVU3','DPVU4','DPVU5','DPVU6','DPVU7','DPXX','VE1D','VEHP','VX1D','VX1W','VX22','VX4S','VXU3','DPVCD','DPEJP','DPEJ7','DPEST','DPDZ','DPR1','DP1P','DPAW','DPF1','DPF2','DPU1','DPF3','DPN1','DPH6'
    )



-- Update timestamp of NGC load in metadata table
UPDATE [dbo].[pdas_metadata]
SET
	[state] = 'OK',
	[timestamp_file] = @current_dt
WHERE
	[table_name] = 'staging_pdas_footwear_vans_ngc_po_delta'
