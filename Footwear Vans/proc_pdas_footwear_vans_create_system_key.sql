USE [VCDWH]
GO

-- =============================================
-- Author: ebp Global
-- Create date: 14/9/2017
-- Description:	Create PDAS system key.
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_create_system_key]
	@mc_user_name nvarchar(100) = NULL
AS
BEGIN
	SET NOCOUNT ON;

    -- Set default value for run_date if the parameter is missing

	DECLARE @run_date DATE = GETDATE();
	DECLARE @run_date_id INT = (SELECT MAX([id]) FROM [dbo].[dim_date] WHERE [full_date] = @run_date)

	DECLARE	@pdasid int = (SELECT MAX([id]) FROM [dbo].[dim_pdas])
	DECLARE @pdas_d int = (SELECT [dim_date_id] FROM [dbo].[dim_pdas] WHERE [id] = @pdasid)

	DECLARE @release_name nvarchar(45) = 'PDAS Release ' + CONVERT(nvarchar(8), @pdas_d)

	IF (
		@run_date_id > @pdas_d
		AND
		(SELECT [value] FROM [dbo].[helper_pdas_footwear_vans_configuration] WHERE [type] = 'System' AND [variable] = 'Release Locker') = 'OFF'
	)
	BEGIN

		-- Update configuration table
		UPDATE [dbo].[helper_pdas_footwear_vans_configuration]
		SET [value] =
			CASE [variable]
				WHEN 'Release Locker' THEN 'ON'
				WHEN 'Release Note' THEN ''
			END
		WHERE
			[type] = 'System'

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

		IF (@mc_user_name IS NOT NULL)
		BEGIN
			INSERT INTO [dbo].[mc_user_log]	(	[mc_user_name],	[message])
			VALUES							(	@mc_user_name,	'New PDAS system release key "' + @release_name + '" inserted successfully')
		END

	END
	ELSE
	BEGIN

		DECLARE @feedback_message NVARCHAR(500) = 'Vans Footwear Configuration parameter "Release Locker" is ON.
		To create a new release key, please change the value to OFF.
		Only 1 release allowed per day.'
		IF (@mc_user_name IS NOT NULL)
		BEGIN
			INSERT INTO [dbo].[mc_user_log]	(	[mc_user_name],	[message])
			VALUES							(	@mc_user_name,	@feedback_message)
		END

		PRINT @feedback_message;
		RETURN -999

	END

END
