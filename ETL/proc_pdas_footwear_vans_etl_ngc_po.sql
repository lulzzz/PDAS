USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 9/12/2017
-- Description:	Procedure to transfer the NGC data into the staging area
--              This procedure is ment to run on a nightly basis (SQL job agent task)
-- ==============================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_load_fact_demand_total]
	@pdasid INT,
	@businessid INT
AS
BEGIN

    INSERT INTO [dbo].[staging_pdas_footwear_vans_ngc_po]
    (
        [shipment]
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
        ,[original_crd_dt]
        ,[revised_crd_dt]
        ,[shipped_dt]
        ,[notes]
        ,[delay_reason]
        ,[discharge_port]
        ,[lum_qty]
        ,[source_system]
        ,[shipment_closed_on_dt]
        ,[is_po_completed]
        ,[dc_name]
    )
    SELECT
        Prbunhea.rdacode,
        Prbunhea.rfactory,
        Prbunhea.lot,
        Prbunhea.misc1,
        Nbbundet.size,
        Nbbundet.color,
        Nbbundet.dimension,
        Prbunhea.plan_date,
        Prbunhea.misc6,
        Prbunhea.style,
        Shshipto.ship_to_1,
        Shshipto_2.ship_to_1,
        Prbunhea.ship_no,
        Prbunhea.misc25,
        Prbunhea.misc41,
        Prbunhea.store_no,
        Prbunhea.origdd,
        Prbunhea.revdd,
        Prbunhea.misc18,
        Prbunhea.misc21,
        Prbunhea.done,
        Shipped.shipment,
        Shipped.shipdate,Shipment.closed,Shipment.misc2,Shipment.firstclosedon,
        Shipmast.shipname,
        Prscale.desce,
        sum(nbbundet.qty) as Quantity,
        SUM(Shipped.unitship) as UnitsShipped
    FROM
        [ITGC2W000187].[ESPSODV14RPT].[dbo].Prbunhea
        LEFT OUTER JOIN Nbbundet WITH (nolock)
            ON (Prbunhea.Id_Cut=Nbbundet.Id_Cut)
        LEFT OUTER JOIN Shshipto WITH (nolock)
            ON (Prbunhea.Rdacode=Shshipto.Factory)
        LEFT OUTER JOIN shshipto as Shshipto_2 WITH (nolock)
            ON (Prbunhea.Rfactory=Shshipto_2.Factory)
        LEFT OUTER JOIN Shipped WITH (nolock)
            ON
            (
                Prbunhea.Season=Shipped.Season AND
                Prbunhea.Style=Shipped.Style AND
                Prbunhea.Lot=Shipped.Cut AND
                Nbbundet.Color=Shipped.Color AND
                Nbbundet.Size=Shipped.Size AND
                Nbbundet.Dimension=Shipped.Dimension
            )
        LEFT OUTER JOIN Shipment WITH (nolock)
            ON (Shipped.Shipment=Shipment.Shipment)
        LEFT OUTER JOIN Shipmast WITH (nolock)
            ON (Shipmast.shipno=Prbunhea.Store_No)
        LEFT OUTER JOIN prscale WITH (nolock)
            ON (nbbundet.size=prscale.scale)

    WHERE
           Prbunhea.ModifiedOn >= '2017-01-01'
           AND Prbunhea.Misc21 IN ('CONDOR', 'JBA-VF', 'JBA-VS', 'REVA', 'S65')
           AND Prbunhea.Misc6 IN ('OCN', 'OIN', 'OSA', 'VF ASIA', 'VF INDIA', 'VF Thailand', 'VFA', 'VFA Bangladesh', 'VFA Guangzhou', 'VFA HongKong', 'VFA India', 'VFA Indonesia', 'VFA Qingdao', 'VFA Shanghai', 'VFA Vietnam', 'VFA Zhuhai', 'VFI')
           AND Prbunhea.Misc1 IN ('50 VANS FOOTWEAR', '503', '503 VN_Footwear', '508', '508 VN_Snow Footwear', '56 VANS SNOWBOOTS', 'VANS Footwear', 'VANS FOOTWEAR', 'VANS Snowboots', 'VANS SNOWBOOTS', 'VF  Vans Footwear', 'VN_Footwear', 'VN_Snow Footwear', 'VS  Vans Snowboots')
           AND Prbunhea.Misc25 IN ('DS', 'DYO', 'PG', 'REGULAR', 'ZCS', 'ZCUS', 'ZDIR', 'ZFGP', 'ZOT', 'ZRDS', 'ZTP', 'ZVFL', 'ZVFS')
           AND NOT (Prbunhea.Qtyship=0 AND Prbunhea.Done=1)
           AND Prbunhea.POLocation NOT IN('CANCELED')
           AND NOT (Nbbundet.qty=0)

    GROUP BY
        Prbunhea.rdacode,
        Prbunhea.rfactory,
        Prbunhea.lot,
        Prbunhea.misc1,
        Nbbundet.size,
        Nbbundet.color,
        Nbbundet.dimension,
        Prbunhea.plan_date,
        Prbunhea.misc6,
        Prbunhea.style,
        Shshipto.ship_to_1,
        Shshipto_2.ship_to_1,
        Prbunhea.ship_no,
        Prbunhea.misc25,
        Prbunhea.misc41,
        Prbunhea.store_no,
        Prbunhea.origdd,
        Prbunhea.revdd,
        Prbunhea.misc18,
        Prbunhea.misc21,
        Prbunhea.done,
        Shipped.shipment,
        Shipped.shipdate,
        Shipment.closed,
        Shipment.misc2,
        Shipment.firstclosedon,
        Shipmast.shipname,
        Prscale.desce


END
