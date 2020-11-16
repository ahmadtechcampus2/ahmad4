#########################################################
create proc prcBranch_createDatabase
	@branchGuid [uniqueidentifier],
	@override [bit] = 0
as
/*
This procedure:
	creates a copy of current db by calling prcDatabase_copy,
	then it dedicates the newly database to the branch by calling prcBranch_dedicate
*/
	declare @branchDB [nvarchar](128)

	set @branchDB = db_name() + '_' + (select [prefix] from [br000] where [guid] = @branchGuid)

	exec [prcDatabase_copyTo] @branchDB, @override

	exec [prcExecuteSQL] '%0.[dbo].[prcBranch_dedicateDB] ''{%1}''', @branchDB, @branchGuid

#########################################################
#end