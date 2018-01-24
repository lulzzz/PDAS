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

    -- Set default value for run_date if the parameter is missing

	DECLARE @run_date DATE = GETDATE();
	DECLARE @run_date_id INT = (SELECT MAX([id]) FROM [dbo].[dim_date] WHERE [full_date] = @run_date)

	DECLARE	@pdasid int = (SELECT MAX([id]) FROM [dbo].[dim_pdas])
	DECLARE @pdas_d int = (SELECT [dim_date_id] FROM [dbo].[dim_pdas] WHERE [id] = @pdasid)

	DECLARE @release_name_0 nvarchar(45) = 'PDAS Release ' + CONVERT(nvarchar(8), @run_date_id)
	DECLARE @release_name_1 nvarchar(45) = 'PDAS Release ' + CONVERT(nvarchar(8), @run_date_id) + '-1'
	DECLARE @release_name_2 nvarchar(45) = 'PDAS Release ' + CONVERT(nvarchar(8), @run_date_id) + '-2'
	DECLARE @release_name nvarchar(45) = @release_name_0
	DECLARE @count int = 0

	IF @release_name_0 in (SELECT name FROM [VCDWH].[dbo].[dim_pdas])
	BEGIN
		SET @count += 1
		SET @release_name = @release_name_1
	END
	IF @release_name_1 in (SELECT name FROM [VCDWH].[dbo].[dim_pdas])
	BEGIN
		SET @count += 1
		SET @release_name = @release_name_2
	END
	IF @release_name_2 in (SELECT name FROM [VCDWH].[dbo].[dim_pdas])
	BEGIN
		SET @count += 1
	END

	IF (@count < 3)
	BEGIN

		INSERT INTO [dbo].[dim_pdas]
		(
			[name]
			,[dim_date_id]
		)
		VALUES
		(
			@release_name
			,@run_date_id
		)

	END
	ELSE
	BEGIN

		DECLARE @feedback_message NVARCHAR(500) = 'Only 3 releases allowed per day.'

		PRINT @feedback_message;
		RETURN -999

	END

END
