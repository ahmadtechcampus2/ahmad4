######################################################### 
create function fnGetCurrentUserGuid_table()
	returns table
as
	return
	select [dbo].[fnGetCurrentUserGuid]() as [guid]

#########################################################
#END