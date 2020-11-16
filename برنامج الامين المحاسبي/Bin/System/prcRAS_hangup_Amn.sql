####################### 
create procedure prcRAS_hangup_Amn
	@entry nvarchar(255) = ''

as
	declare
		@sql nvarchar(1024),
		@result int
	
	set @sql = 'dialentry.exe /E:' + @entry +' /H'

	exec @result = master..xp_cmdShell @sql, no_output

	
	if @result != 0
	begin
		raiserror('RASERROR010: prcRAS_hangup_Amn failed with error %d', 16, 1, @result)
		--exec prcLog_err 'RASERROR0101', @caller = 'prcRAS_hangup_Amn', @error = 101
	end
	return @result

#######################
#END