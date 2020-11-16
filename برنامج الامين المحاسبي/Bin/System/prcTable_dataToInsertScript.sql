#########################################################
create proc prcTable_dataToInsertScript
	@tableName [NVARCHAR](128)
as

	declare
		@c cursor,
		@fieldName [NVARCHAR](128),
		@xtype [int],
		@sql [NVARCHAR](max),
		@sql_declare [NVARCHAR](max),
		@sql_cols [NVARCHAR](max),
		@sql_cols2 [NVARCHAR](max),
		@colName [NVARCHAR](max),
		@n [int]

	set @c = cursor fast_forward for select [name], [xtype] from [syscolumns] where [id] = object_id(@tableName) order by [colorder]

	open @c fetch from @c into @fieldName, @xtype

	set @sql_declare = '
		declare
			@s [NVARCHAR](max),
			@c cursor,'

	select
		@n = 0,
		@sql_cols = '',
		@sql_cols2 = ''

	while @@fetch_status = 0
	begin
		set @colName = '@col' + cast(@n as NVARCHAR)

		set @sql_declare = @sql_declare + '
			' + @colName + ' NVARCHAR(2000), '

		set @sql_cols =  @sql_cols + @colName + ', '
		set @sql_cols2 = @sql_cols2 + ''''''' + @col' + cast(@n as NVARCHAR) + ' + '''''','

		set @n = @n + 1

		fetch from @c into @fieldName, @xtype
	end

	close @c deallocate @c

	set @sql_declare = left(@sql_declare, len(@sql_declare) - 1)
	set @sql_cols = left(@sql_cols, len(@sql_cols) - 1)
	set @sql_cols2 = left(@sql_cols2, len(@sql_cols2) - 1) + ''''

	set @sql = @sql_declare + '
		
		set @c = cursor fast_forward for select * from ' + @tableName + '
		open @c fetch from @c into ' + @sql_cols + '
		
		while @@fetch_status = 0
		begin
			set @s = ''insert into ' + @tableName + ' select '''''' + @col0 + '''''',''
			set @s = ''insert into ' + @tableName + ' select ' + @sql_cols2 + '
			print @s
			fetch from @c into ' + @sql_cols + '
		end

		close @c deallocate @c'

	exec (@sql)


-- prcTable_dataToInsertScript 'ac000' 

#########################################################
#END