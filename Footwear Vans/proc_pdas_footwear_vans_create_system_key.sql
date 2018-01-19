USE [VCDWH]
GO

-- =============================================
-- Author: ebp Global
-- Create date: 14/9/2017
-- Description:	Create PDAS system key.
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_create_system_key]
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @run_date DATE = GETDATE();
	DECLARE @run_date_id INT = (SELECT MAX([id]) FROM [dbo].[dim_date] WHERE [full_date] = @run_date)

	DECLARE	@pdasid int = (SELECT MAX([id]) FROM [dbo].[dim_pdas])
	DECLARE @pdas_d int = (SELECT [dim_date_id] FROM [dbo].[dim_pdas] WHERE [id] = @pdasid)

	DECLARE @release_name nvarchar(45) = 'PDAS Release ' + CONVERT(nvarchar(8), @run_date_id)

	DECLARE @dim_buying_program_id int = (SELECT [id] FROM [dbo].[dim_buying_program] WHERE [name] = 'Bulk Buy')

	IF (@run_date_id > @pdas_d)
	BEGIN

		INSERT INTO [dbo].[dim_pdas]
		(
			[name]
			,[dim_date_id]
			,[dim_buying_program_id]
		)
		VALUES
		(
			@release_name
			,@run_date_id
			,@dim_buying_program_id
		)

	END
	ELSE
	BEGIN

		DECLARE @feedback_message NVARCHAR(500) = 'Only 1 release allowed per day.'

		PRINT @feedback_message;
		RETURN -999

	END

END
