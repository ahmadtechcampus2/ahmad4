#########################################################
create proc prcDatabase_exportToDB @dbName [NVARCHAR](128)
as
	declare
		@c cursor,
		@tableName [NVARCHAR](128),
		@sql [NVARCHAR](512)
	
	set @sql = '
			if exists(select * from %0.[sys].[objects] where [name] = ''%1'' and [type] = ''U'')
			begin
				alter table %0..%1 disable trigger all
				delete %0..%1
				insert into %0..%1 select * from %1
				alter table %0..%1 enable trigger all
			end'
	
	set @c = cursor fast_forward for select [name] from [sys].[objects] where [type] = 'U'
	
	open @c fetch from @c into @tableName

	while @@fetch_status = 0
	begin
		exec [prcExecuteSql] @sql, @dbName, @tableName
		fetch from @c into @tableName
	end

	close @c deallocate @c

#########################################################
#END