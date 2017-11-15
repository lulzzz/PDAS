declare @user nvarchar(100) = 'FGAMPER'

/*
delete from [mc_user_table_perm] where [mc_user_name] = @user
delete from [mc_user_proc_perm] where [mc_user_name] = @user
delete from [mc_user_report_perm] where [mc_user_name] = @user
delete from [mc_user_system_perm] where [mc_user_name] = @user
*/

insert into [dbo].[mc_user_proc_perm]
([permission_type]
  ,[mc_user_name]
  ,[mc_proc_name])
select 'RW', @user, [name]
from [dbo].[mc_proc]
where name NOT IN (select mc_proc_name from [dbo].[mc_user_proc_perm] where mc_user_name = @user)
-- and left(name, 3) <> 'mc_'

insert into [dbo].[mc_user_report_perm]
([permission_type]
  ,[mc_user_name]
  ,[mc_report_name])
select 'RW', @user, [name]
from [dbo].[mc_report]
where name NOT IN (select mc_report_name from [dbo].[mc_user_report_perm] where mc_user_name = @user)
-- and left(name, 3) <> 'mc_'

insert into [dbo].[mc_user_system_perm]
([permission_type]
  ,[mc_user_name]
  ,[mc_system_name])
select 'RW', @user, [name]
from [dbo].[mc_system]
where name NOT IN (select mc_system_name from [dbo].[mc_user_system_perm] where mc_user_name = @user)
-- and left(name, 3) <> 'mc_'

insert into [dbo].[mc_user_table_perm]
([permission_type]
  ,[mc_user_name]
  ,[mc_table_name])
select 'RW', @user, [name]
from [dbo].[mc_table]
where name NOT IN (select mc_table_name from [dbo].[mc_user_table_perm] where mc_user_name = @user)
-- and left(name, 3) <> 'mc_'
