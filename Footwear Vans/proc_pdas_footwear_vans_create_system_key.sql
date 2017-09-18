
-- =============================================
-- Author: ebp Global
-- Create date: 14/9/2017
-- Description:	Create PDAS system key.
-- =============================================
ALTER PROCEDURE [dbo].[proc_pdas_footwear_vans_create_system_key]
	@run_date date = NULL,
	@mc_user_name nvarchar(100) = NULL
AS
BEGIN
	SET NOCOUNT ON;

    -- Set default value for run_date if the parameter is missing
	IF(@run_date IS NULL)
		SET @run_date = GETDATE();

	DECLARE @date_id INT = (SELECT MAX([id]) FROM [dbo].[dim_date] WHERE [full_date] = CONVERT(date, @run_date))
	DECLARE @run_date_id INT = (SELECT MAX([id]) FROM [dbo].[dim_date] WHERE [full_date] = CONVERT(date, DATEADD(month, DATEDIFF(month, 0, @run_date), 0)))

	DECLARE @release_name nvarchar(45) = 'PDAS Release ' + CONVERT(nvarchar(6), @run_date)

	IF
		NOT EXISTS (SELECT 1 FROM [dbo].[dim_planning_system] WHERE [name] = @release_name)
		AND
		(SELECT [value_string] FROM [dbo].[helper_PDAS_parameter] WHERE [type] = 'System' AND [name] = 'system_release_locker') = 'OFF'
	BEGIN

		-- Update configuration table
		UPDATE [dbo].[helper_PDAS_parameter]
		SET [value_string] = 'ON'
		WHERE
			[type] = 'System'
			AND [name] = 'Release Locker'

		INSERT INTO [dbo].[dim_planning_system]
		(
			[name]
			,[etl_date_id]
		)
		VALUES
		(
			@release_name
			,@date_id
		)

		IF (@mc_user_name IS NOT NULL)
		BEGIN
			INSERT INTO [dbo].[mc_user_log]	(	[mc_user_name],	[message])
			VALUES							(	@mc_user_name,	'New PDAS system release key "' + @release_name + '" inserted successfully')
		END

	END
	ELSE
	BEGIN

		IF (@mc_user_name IS NOT NULL)
		BEGIN
			INSERT INTO [dbo].[mc_user_log]	(	[mc_user_name],	[message])
			VALUES							(	@mc_user_name,	'PDAS Configuration system lock parameter "system_release_locker" is ON. To create a new release key, please change the value to OFF.')
		END

		PRINT 'PDAS Configuration system lock parameter "system_release_locker" is ON. To create a new release key, please change the value to OFF.';
		RETURN -999

	END

END
