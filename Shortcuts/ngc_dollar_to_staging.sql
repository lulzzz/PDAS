delete from [staging_pdas_footwear_vans_ngc_po_201710_future]
insert into [dbo].[staging_pdas_footwear_vans_ngc_po_201710_future]
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
select
[shipment]
,[dim_factory_vendor_code]
,[dim_factory_factory_code]
,[po_code_cut]
,[dim_product_sbu]
,[dim_product_size]
,[dim_product_color_description]
,[dimension]
, [po_issue_dt]
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
,NULL as [shipment_closed_on_dt]
,[is_po_completed]
,[dc_name ]
from [dbo].['NGC_Data_2017_10_onwards(2)$']
