USE [VCDWH]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ebp Global
-- Create date: 9/6/2017
-- Description:	Console procedure to configure the Console.
-- =============================================
ALTER PROCEDURE [dbo].[mc_table_mc_table]
	@output_param nvarchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- Check if data was submitted from frontend
	IF (SELECT COUNT(*) FROM [dbo].[mc_temp_mc_table]) > 0
	BEGIN

		-- Remove duplicates
		DELETE x FROM (
			SELECT *, rn=row_number() OVER (PARTITION BY [name] ORDER BY [name])
			FROM [dbo].[mc_temp_mc_table]
		) x
		WHERE rn > 1;

        -- Delete removed rows (secured by PK constraint)
        DELETE mc
        FROM
            [dbo].[mc_table] mc
            LEFT OUTER JOIN [dbo].[mc_temp_mc_table] temp
                ON	mc.[name] = temp.[name]
        WHERE temp.[name] IS NULL

		-- Insert new rows
		INSERT INTO [dbo].[mc_table]
		(
            [name]
            ,[name_temp]
            ,[name_view]
            ,[label]
            ,[mc_proc_name_write]
            ,[mc_system_name]
            ,[has_delete_button]
		)
		SELECT
            temp.[name]
            ,temp.[name_temp]
            ,temp.[name_view]
            ,temp.[label]
            ,temp.[mc_proc_name_write]
            ,temp.[mc_system_name]
            ,temp.[has_delete_button]
		FROM
			[dbo].[mc_temp_mc_table] temp
			LEFT JOIN [dbo].[mc_table] mc
				ON temp.[name] = mc.[name]
		WHERE mc.[name] IS NULL

		-- Update existing rows
		UPDATE mc
		SET
            mc.[name] = temp.[name]
            ,mc.[name_temp] = temp.[name_temp]
            ,mc.[name_view] = temp.[name_view]
            ,mc.[label] = temp.[label]
            ,mc.[mc_proc_name_write] = temp.[mc_proc_name_write]
            ,mc.[mc_system_name] = temp.[mc_system_name]
            ,mc.[has_delete_button] = temp.[has_delete_button]
		FROM
			[dbo].[mc_table] mc
			INNER JOIN [dbo].[mc_temp_mc_table] temp
				ON	mc.[name] = temp.[name]

	END
	ELSE
	BEGIN

		SET @output_param = 'Table is empty.'
		RETURN -999

	END

END
