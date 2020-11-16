######################################################### 
create proc prcCheckDBProc_exec
	@codes [NVARCHAR](max) = '',
	@correct [INT] = 1 
as
/*
this procedures:
	- exec checkDB procedures in order of their Code
	- requested checkDB procedures to be executed are set in @codes. ie: '0102, 0405'
	- is should be used in SQL-Agent Jobs
*/

	-- initialize:
	exec [prcCheckDB_Initialize]

	declare
		@c cursor,
		@procName [NVARCHAR](128)

	if @codes = ''
		set @c = cursor fast_forward for
					select [procName] from [CheckDBProc] where [procName] != '' order by [code]
	else
		set @c = cursor fast_forward for
					select [procName] from [dbo].[fnTextToRows](@codes) [f] inner join [checkDBProc] [p] on [f].[data] = [p].[code] where [procName] != '' order by [code]

	open @c fetch from @c into @procName

	while @@fetch_status = 0
	begin
		exec [prcExecuteSql] '%0 %1', @procName, @correct
		fetch from @c into @procName
	end

	close @c deallocate @c

	exec [prcCheckDB_Finalize]
	

#########################################################
#end