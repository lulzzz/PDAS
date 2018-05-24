USE [VCDWH]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to run the PDAS Footwear Vans step 06.
-- =============================================
ALTER PROCEDURE [dbo].[mc_step_pdas_footwear_vans_06]
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE	@dim_release_id int = (SELECT MAX([dim_release_id]) FROM [dbo].[helper_pdas_footwear_vans_release_current])
	DECLARE @dim_business_id_footwear_vans int = (SELECT [id] FROM [dbo].[dim_business] WHERE [brand] = 'Vans' and [product_line] = 'Footwear')


	-- Do manual overwrite
	EXEC [dbo].[proc_pdas_footwear_vans_do_overwrite] @dim_release_id = @dim_release_id, @businessid = @dim_business_id_footwear_vans

	-- Adjust EMEA NTB based on cutoff days
	EXEC [dbo].[proc_pdas_footwear_vans_do_emea_ntb_cutoff_day_adjustment] @dim_release_id = @dim_release_id, @businessid = @dim_business_id_footwear_vans

	-- Prepare report tables for Excel frontend
	-- TAKES 30 MINUTES TO RUN BECAUSE OF SERVER PERFORMANCE
	-- EXEC [proc_pdas_footwear_vans_do_excel_table_preparation] @dim_release_id = @dim_release_id, @businessid = @dim_business_id_footwear_vans

	-- Validate source data (need to check the Vans Footwear Validation Report afterwards)
	EXEC [dbo].[proc_pdas_footwear_vans_validate_allocation_decision]

END
