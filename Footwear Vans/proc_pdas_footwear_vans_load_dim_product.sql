-- =======================================================================================
-- Author:		ebp Global
-- Create date: 13/9/2017
-- Description:	This procedure loads the dim_product table
-- =======================================================================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_load_dim_product]
AS
BEGIN

	/*

		Incremental loading
		First we map the keys between staging table and dimension.
		If the key matched then we set the action flag to Update, otherwise flag equals Insert
		Then we insert
		Then we update

	*/



	-------------------------------------------------- INSERT -----------------------------------------------------
