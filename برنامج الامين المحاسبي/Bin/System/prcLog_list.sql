#########################################################
CREATE PROC prcLog_list
	@all [bit] = 0,
	@spid [int] = 0,
	@caller [nvarchar](128) = ''
as
	set nocount on 
	if  exists (select * from [amnconfig].[dbo].[sysobjects] where [id] = object_id(N'[amnconfig]..[msglog]'))
	begin
		select * 
		from [amnConfig]..[msgLog] with (readuncommitted)
		where
			([dbName] = db_name() or @all != 0)
			and ([spid] = @spid or @spid = 0)
			and ([caller] = @caller or @caller = '')
	end 
#########################################################
#END
