USE [VCDWH]
GO

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
VALUES
('dim_location', 'mc_temp_pdas_location', 'mc_view_pdas_location', 'Cross System: Location Master', 'mc_table_pdas_location', 'cross_system', 0)
