#########################################################
CREATE PROCEDURE prcExecuteSqlScript
	@path [NVARCHAR](255), 
	@fileName [NVARCHAR](255),
	@param0 [NVARCHAR](255) = null,
	@param1 [NVARCHAR](255) = null,
	@param2 [NVARCHAR](255) = null
as 
	print '[prcExecuteSqlScript] params:'
	print @path
	print @fileName
	print @param0
	print @param1
	print @param2
	print '==========='
	set nocount on 
	declare 
		@sql [NVARCHAR](max) 
	declare 
		@c cursor, 
		@statement [NVARCHAR](max), 
		@includedFile [NVARCHAR](255) 
	declare @t table([statement] [NVARCHAR](max) collate arabic_ci_ai) 
	create table [statements]([statement] [NVARCHAR](max) collate arabic_ci_ai) 
	-- set @sql = 'exec master..xp_cmdShell ''bcp tempdb..statements in "%0" -S(local) -Urpl_syncher -Prpl_syncher -CRAW -c -q -h"tablock"'', no_output' 
	set @sql = 'BULK INSERT [statements] FROM ''%0'' WITH (codepage = ''raw'')' 
	set @path = @path + case right(@path, 1) when '\' then '' else '\' end 
	set @fileName = @path + @fileName 
	exec [prcExecuteSql] @sql, @fileName
	insert into @t select * from [statements]
	-- select * from @t 
	set @sql = '' 
	set @c = cursor fast_forward for select [statement] from @t 
	open @c fetch from @c into @statement 
	while @@fetch_status = 0 
	begin 
		if @statement is not null 
		begin 
			set @statement = rtrim(ltrim(@statement)) 
			--set @statement = replace(@statement, '''', '''''') 
			if @statement like '#include %' 
			begin 
				set @includedFile = rtrim(ltrim(substring(@statement, 9, len(@statement) - 8))) 
				exec [prcExecuteSqlScript] @path, @includedFile, @param0, @param1, @param2
				set @sql = '' 
			end else if @statement = 'go' 
			begin 
				exec [prcExecuteSql] @sql, @param0, @param1, @param2
				set @sql = '' 
			end else 
				set @sql = @sql + char(10) + @statement 
		end 
		fetch from @c into @statement 
	end 
	exec [prcExecuteSql] @sql, @param0, @param1, @param2
	close @c deallocate @c 

#########################################################
#END