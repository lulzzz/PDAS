USE [VCDWH]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to run the PDAS Footwear Vans step 02.
-- =============================================
ALTER PROCEDURE [dbo].[mc_step_pdas_footwear_vans_02]
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE	@dim_release_id int = (SELECT MAX([dim_release_id]) FROM [dbo].[helper_pdas_footwear_vans_release_current])
	DECLARE @dim_business_id_footwear_vans int = (SELECT [id] FROM [dbo].[dim_business] WHERE [brand] = 'Vans' and [product_line] = 'Footwear')

	-- Step 02 - Transfer product master data and Priority List
	EXEC [dbo].[proc_pdas_footwear_vans_load_dim_product] @businessid = @dim_business_id_footwear_vans
	EXEC [dbo].[proc_pdas_footwear_vans_load_fact_priority_list] @dim_release_id = @dim_release_id, @businessid = @dim_business_id_footwear_vans

	-- Step 03 - Validate source data (need to check the Vans Footwear Validation Report afterwards)
	EXEC [dbo].[proc_pdas_footwear_vans_validate_priority_list]
	EXEC [dbo].[proc_pdas_footwear_vans_validate_capacity_by_week]
	EXEC [dbo].[proc_pdas_footwear_vans_validate_forecast]
	--EXEC [dbo].[proc_pdas_footwear_vans_validate_ngc_orders]
	EXEC [dbo].[proc_pdas_footwear_vans_validate_ntb] @dim_release_id
	EXEC [dbo].[proc_pdas_footwear_vans_validate_raw_capacity]

END
