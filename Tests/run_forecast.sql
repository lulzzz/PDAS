
DECLARE	@current_date date = GETDATE()
DECLARE	@pdasid int = (SELECT MAX([id]) FROM [dbo].[dim_pdas])
DECLARE @dim_business_id_footwear_vans int = (SELECT [id] FROM [dbo].[dim_business] WHERE [brand] = 'Vans' and [product_line] = 'Footwear')
DECLARE	@buying_program_id int

SET @buying_program_id = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Bulk Buy')
EXEC [dbo].[proc_pdas_footwear_vans_load_fact_forecast]
    @pdasid = @pdasid,
    @businessid = @dim_business_id_footwear_vans,
    @buying_program_id = @buying_program_id,
    @buying_program_ref = 'bulk'
SET @buying_program_id = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Retail Quick Turn')
EXEC [dbo].[proc_pdas_footwear_vans_load_fact_forecast]
    @pdasid = @pdasid,
    @businessid = @dim_business_id_footwear_vans,
    @buying_program_id = @buying_program_id,
    @buying_program_ref = 'rqt'
