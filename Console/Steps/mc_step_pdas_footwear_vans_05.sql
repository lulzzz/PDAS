USE [VCDWH]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to run the PDAS Footwear Vans step 05.
-- =============================================
ALTER PROCEDURE [dbo].[mc_step_pdas_footwear_vans_05]
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE	@dim_release_id int = (SELECT MAX([dim_release_id]) FROM [dbo].[helper_pdas_footwear_vans_release_current])
	DECLARE @dim_business_id_footwear_vans int = (SELECT [id] FROM [dbo].[dim_business] WHERE [brand] = 'Vans' and [product_line] = 'Footwear')
	DECLARE	@buying_program_id int


	-- Unconstrained allocation
	EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_constrained] @dim_release_id = @dim_release_id, @businessid = @dim_business_id_footwear_vans

	-- Do MOQ check
	EXEC [dbo].[proc_pdas_footwear_vans_do_moq_upcharge_adjustment] @dim_release_id = @dim_release_id, @businessid = @dim_business_id_footwear_vans

	-- Prepare report tables for Excel frontend
	EXEC [proc_pdas_footwear_vans_do_excel_table_preparation] @dim_release_id = @dim_release_id, @businessid = @dim_business_id_footwear_vans

END
