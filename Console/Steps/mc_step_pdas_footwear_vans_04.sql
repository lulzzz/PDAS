USE [VCDWH]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to run the PDAS Footwear Vans step 04.
-- =============================================
ALTER PROCEDURE [dbo].[mc_step_pdas_footwear_vans_04]
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE	@pdasid int = (SELECT MAX([id]) FROM [dbo].[dim_pdas])
	DECLARE @dim_business_id_footwear_vans int = (SELECT [id] FROM [dbo].[dim_business] WHERE [brand] = 'Vans' and [product_line] = 'Footwear')
	DECLARE	@buying_program_id int


	-- Unconstrained allocation
	EXEC [dbo].[proc_pdas_footwear_vans_do_allocation_unconstrained] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

	-- Do MOQ check
	EXEC [dbo].[proc_pdas_footwear_vans_do_moq_upcharge_adjustment] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

	-- Prepare report tables for Excel frontend
	EXEC [proc_pdas_footwear_vans_do_excel_table_preparation] @pdasid = @pdasid, @businessid = @dim_business_id_footwear_vans

END
