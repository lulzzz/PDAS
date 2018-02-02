USE [VCDWH]
GO

-- ==============================================================
-- Author:		ebp Global
-- Create date: 9/12/2017
-- Description:	Code to transfer the NGC data into the staging area (delta only!)
--              This procedure is meant to run on a nightly basis (SQL job agent task)
-- ==============================================================

-- Declare variables
DECLARE	@current_dt datetime = GETDATE()
DECLARE	@starting_dt_last_modified datetime = DATEADD(day, -2, GETDATE())
DECLARE	@starting_dt_rev datetime = DATEADD(day, -30, GETDATE())


-- Drop temporary table if exists
IF OBJECT_ID('tempdb..#temp_ngc') IS NOT NULL
BEGIN
	DROP TABLE #temp_ngc;
END

-- Create temp table
CREATE TABLE #temp_ngc (
    [Row #] [nvarchar](500) NULL,
	[dim_factory_vendor_code] [nvarchar](500) NULL,
	[dim_factory_factory_code] [nvarchar](500) NULL,
	[po_code_cut] [nvarchar](500) NULL,
	[dim_product_sbu] [nvarchar](500) NULL,
	[dim_product_size] [nvarchar](500) NULL,
	[dim_product_color_description] [nvarchar](500) NULL,
	[dimension] [nvarchar](500) NULL,
	[po_issue_dt] [datetime] NULL,
	[shipment_status] [nvarchar](500) NULL,
	[source] [nvarchar](500) NULL,
	[order_qty] [int] NULL,
	[shipped_qty] [int] NULL,
	[dim_product_style_id] [nvarchar](500) NULL,
	[ship_to_address] [nvarchar](500) NULL,
	[ship_to_address_bis] [nvarchar](500) NULL,
	[po_code] [nvarchar](500) NULL,
	[po_type] [nvarchar](500) NULL,
	[vf_sla] [nvarchar](500) NULL,
	[dim_customer_dc_code_brio] [nvarchar](500) NULL,
	[actual_crd_dt] [datetime] NULL,
	[revised_crd_dt] [datetime] NULL,
	[shipped_dt] [datetime] NULL,
	[delay_reason] [nvarchar](500) NULL,
	[shipment_id] [nvarchar](500) NULL,
	[lum_order_qty] [int] NULL,
	[lum_shipped_qty] [int] NULL,
	[source_system] [nvarchar](500) NULL,
	[shipment_closed_on_dt] [datetime] NULL,
	[is_po_completed] [nvarchar](500) NULL,
	[dc_name] [nvarchar](500) NULL,
	[sales_order] [nvarchar](500) NULL,
	[is_deleted] [tinyint] NULL
)

-- Create table index
CREATE INDEX idx_temp_ngc01 ON #temp_ngc
(
    [po_code_cut]
)

-- Dump data into temp table
INSERT INTO #temp_ngc
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
	,[is_deleted]
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
    LTRIM(RTRIM(Shshipto.ship_to_1)) AS [ship_to_address],
    LTRIM(RTRIM(Shshipto_2.ship_to_1)) AS [ship_to_address_bis],
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
    LTRIM(RTRIM(Prbunhea.misc27)) AS [sales_order],
	CASE
		WHEN Prbunhea.POLocation = 'CANCELED' THEN 1
		ELSE 0
	END AS [is_deleted]
FROM

	[ITGC2W000187].[ESPSODV14RPT].[dbo].Prbunhea
    LEFT OUTER JOIN [ITGC2W000187].[ESPSODV14RPT].[dbo].Nbbundet WITH (nolock)
        ON (Prbunhea.Id_Cut=Nbbundet.Id_Cut)
    LEFT OUTER JOIN [ITGC2W000187].[ESPSODV14RPT].[dbo].Shshipto WITH (nolock)
        ON (Prbunhea.Rdacode=Shshipto.Factory)
    LEFT OUTER JOIN [ITGC2W000187].[ESPSODV14RPT].[dbo].shshipto as Shshipto_2 WITH (nolock)
        ON (Prbunhea.Rfactory=Shshipto_2.Factory)
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
    Prbunhea.Modifiedon >= @starting_dt_last_modified
    AND Prbunhea.revdd >= @starting_dt_rev
    AND Prbunhea.Misc6 NOT IN ('DIRECT BRAZIL')
    AND Prbunhea.Misc1 IN ('50 VANS FOOTWEAR', '503', '503 VN_Footwear', '508', '508 VN_Snow Footwear', '56 VANS SNOWBOOTS', 'VANS Footwear', 'VANS FOOTWEAR', 'VANS Snowboots', 'VANS SNOWBOOTS', 'VF  Vans Footwear', 'VN_Footwear', 'VN_Snow Footwear', 'VS  Vans Snowboots')
    AND NOT (Prbunhea.Qtyship=0 AND Prbunhea.Done=1)
    AND NOT (Nbbundet.qty=0)


-- Insert new rows
INSERT INTO [dbo].[staging_pdas_footwear_vans_ngc_po]
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
	temp.[Row #]
	,temp.[dim_factory_vendor_code]
	,temp.[dim_factory_factory_code]
	,temp.[po_code_cut]
	,temp.[dim_product_sbu]
	,temp.[dim_product_size]
	,temp.[dim_product_color_description]
	,temp.[dimension]
	,temp.[po_issue_dt]
	,temp.[shipment_status]
	,temp.[source]
	,temp.[order_qty]
	,temp.[shipped_qty]
	,temp.[dim_product_style_id]
	,temp.[ship_to_address]
	,temp.[ship_to_address_bis]
	,temp.[po_code]
	,temp.[po_type]
	,temp.[vf_sla]
	,temp.[dim_customer_dc_code_brio]
	,temp.[actual_crd_dt]
	,temp.[revised_crd_dt]
	,temp.[shipped_dt]
	,temp.[delay_reason]
	,temp.[shipment_id]
	,temp.[lum_order_qty]
	,temp.[lum_shipped_qty]
	,temp.[source_system]
	,temp.[shipment_closed_on_dt]
	,temp.[is_po_completed]
	,temp.[dc_name]
	,temp.[sales_order]
FROM
    #temp_ngc temp
    LEFT OUTER JOIN
    (
        SELECT
            [po_code_cut]
            ,[dim_product_style_id]
            ,[dim_product_size]
			,[dim_product_color_description]
			,[dimension]
			,[shipment_id]
        FROM [dbo].[staging_pdas_footwear_vans_ngc_po]
    ) as staging
        ON
            staging.[po_code_cut] = temp.[po_code_cut]
			and staging.[dim_product_style_id] = temp.[dim_product_style_id]
			and staging.[dim_product_color_description] = temp.[dim_product_color_description]
            and staging.[dim_product_size] = temp.[dim_product_size]
			and staging.[dimension] = temp.[dimension]
			and staging.[shipment_id] = temp.[shipment_id]
WHERE
	temp.[is_deleted] = 0 and
    staging.[po_code_cut] IS NULL

-- Update existing rows
UPDATE staging
SET
    staging.[dim_factory_vendor_code] 	= temp.[dim_factory_vendor_code]
    ,staging.[dim_factory_factory_code]	= temp.[dim_factory_factory_code]
    ,staging.[dim_product_sbu]	= temp.[dim_product_sbu]
    ,staging.[dim_product_color_description]	= temp.[dim_product_color_description]
    ,staging.[dimension]	= temp.[dimension]
    ,staging.[po_issue_dt]	= temp.[po_issue_dt]
    ,staging.[shipment_status]	= temp.[shipment_status]
    ,staging.[source]	= temp.[source]
    ,staging.[order_qty]	= temp.[order_qty]
    ,staging.[shipped_qty]	= temp.[shipped_qty]
    ,staging.[ship_to_address]	= temp.[ship_to_address]
    ,staging.[ship_to_address_bis]	= temp.[ship_to_address_bis]
    ,staging.[po_code]	= temp.[po_code]
    ,staging.[po_type]	= temp.[po_type]
    ,staging.[vf_sla]	= temp.[vf_sla]
    ,staging.[dim_customer_dc_code_brio]	= temp.[dim_customer_dc_code_brio]
    ,staging.[actual_crd_dt]	= temp.[actual_crd_dt]
    ,staging.[revised_crd_dt]	= temp.[revised_crd_dt]
    ,staging.[shipped_dt]	= temp.[shipped_dt]
    ,staging.[delay_reason]	= temp.[delay_reason]
    ,staging.[shipment_id]	= temp.[shipment_id]
    ,staging.[lum_order_qty]	= temp.[lum_order_qty]
    ,staging.[lum_shipped_qty]	= temp.[lum_shipped_qty]
    ,staging.[source_system]	= temp.[source_system]
    ,staging.[shipment_closed_on_dt]	= temp.[shipment_closed_on_dt]
    ,staging.[is_po_completed]	= temp.[is_po_completed]
    ,staging.[dc_name]	= temp.[dc_name]
    ,staging.[sales_order]	= temp.[sales_order]
FROM
    [dbo].[staging_pdas_footwear_vans_ngc_po] as staging
    INNER JOIN #temp_ngc temp
        ON
            staging.[po_code_cut] = temp.[po_code_cut]
            and staging.[dim_product_style_id] = temp.[dim_product_style_id]
			and staging.[dim_product_color_description] = temp.[dim_product_color_description]
            and staging.[dim_product_size] = temp.[dim_product_size]
			and staging.[dimension] = temp.[dimension]
			and staging.[shipment_id] = temp.[shipment_id]
WHERE
	temp.[is_deleted] = 0


-- Delete canceled orders
DELETE staging
FROM
	[dbo].[staging_pdas_footwear_vans_ngc_po] as staging
	INNER JOIN #temp_ngc temp
		ON
			staging.[po_code_cut] = temp.[po_code_cut]
			and staging.[dim_product_style_id] = temp.[dim_product_style_id]
			and staging.[dim_product_color_description] = temp.[dim_product_color_description]
			and staging.[dim_product_size] = temp.[dim_product_size]
			and staging.[dimension] = temp.[dimension]
			and staging.[shipment_id] = temp.[shipment_id]
WHERE
	temp.[is_deleted] = 1


-- Update timestamp of NGC load in metadata table
UPDATE [dbo].[pdas_metadata]
SET
	[state] = 'OK',
	[timestamp_file] = @current_dt
WHERE
	[table_name] = 'staging_pdas_footwear_vans_ngc_po'
