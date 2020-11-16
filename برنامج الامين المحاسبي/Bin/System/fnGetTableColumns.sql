#########################################################
create function fnGetTableColumns (@tableName [NVARCHAR](128))
	returns @Result table ([name] [NVARCHAR](128) collate arabic_ci_ai)
as begin
	if @tableName LIKE '#%'
		insert into @Result select [name] from [tempdb]..[syscolumns] where [id] = object_id('tempdb..' + @tableName)
	else if @tableName LIKE 'tempdb..#%'
		insert into @Result select [name] from [tempdb]..[syscolumns] where [id] = object_id(@tableName)
	else
		insert into @Result select [name] from [syscolumns] where [id] = object_id(@tableName) order by [colorder]
	return
end

#########################################################
#END