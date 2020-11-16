###############################
CREATE procedure prcRAS_dial_Amn
	@entry nvarchar(255) = '',
	@showDlg bit = 0,
	@dlgCaption nvarchar(128) = ''
as
	declare
		@sql nvarchar(1024),
		@result int


	set @sql = 'dialentry.exe /E:' + @entry
	
	set @sql = @sql + ' /C'
	
	
	if @showDlg = 0
		set @sql = @sql + ' /S'
	
	if @dlgCaption != ''
		set @sql = @sql + ' /T:' + @dlgCaption
	
	exec @result = master..xp_cmdShell @sql, no_output

	if @result != 0
	begin
		raiserror('RASERROR0100: prcRAS_dail failed with error %d', 16, 1, @result)
		--exec prcLog_err 'RASERROR0100', @caller = 'prcRAS_dial_Amn', @exitCode = 100
	end
	
	if @result = 0
		exec prcExecuteSql 'waitfor delay ''00:00:10''', @caller = 'prcRAS_dial_Amn'
	
	return @result

##############################
#END 