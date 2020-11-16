######################################################### 
create function fnDatabase_qualifiedName()
	returns [nvarchar](128)
as begin

	return '[' + dbo.fnDatabase_serverName() + '].[' + db_name() + ']'

end

#########################################################
#END