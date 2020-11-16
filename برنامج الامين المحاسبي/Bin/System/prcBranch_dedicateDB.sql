#########################################################
create proc prcBranch_dedicateDB
	@branchGuid [uniqueidentifier]
as
/*
This procedure:
	- dedicate current database for the given branch @guid by deleting anything that doesn't relate to that branch
	- SHOULD BE USED CARFULY, AS IT DELETES LIVE DATA.
*/


	declare
		@c cursor,
		@className [NVARCHAR](128),
		@tableName [NVARCHAR](128),
		@singleBranch [bit],
		@singleBranchFldName [NVARCHAR](128),
		@branchMask [bigint],
		@sql [NVARCHAR](max)
		
	set nocount on

	set @branchMask = (select [branchMask] from [vtBr] where [guid] = @branchGuid)

	set @c = cursor fast_forward for 
		select [className], [tableName], [singleBranch], [singleBranchFldName] from [brt] 
		where [tableName] not like 'Hos%' and [tableName] not like 'Trn%' 

	open @c fetch from @c into @className, @tableName, @singleBranch, @singleBranchFldName

	while @@fetch_status = 0
	begin
		declare @b [bit]
	
		if exists(select * from [sys].[objects] where [name] = 'trg_' + @tableName + '_checkConstraints' and [type] = 'tr')
			set @b = 1
		else
			set @b = 0
	
		set @sql = '
			declare
				@c cursor,
				@g [uniqueidentifier]'

		if @b = 1
			set @sql = @sql + '
			alter table [%1] disable trigger [trg_%1_checkConstraints]'
		
		set @sql = @sql + '
			set @c = cursor fast_forward for select [guid] from [%1] where '

		if @singleBranch = 1
			set @sql = @sql + @singleBranchFldName + ' != ''{' + cast(@branchGuid as [NVARCHAR](128)) + '}'''
		else
			set @sql = @sql + ' [branchMask] & cast(' + cast(@branchMask as [NVARCHAR](128)) + ' as [bigint]) = 0'

		set @sql = @sql + '
	
			open @c fetch from @c into @g
			while @@fetch_status = 0
			begin
				exec [prc%0_delete] @g
				fetch from @c into @g
			end
		
			close @c deallocate @c'
	
	
		if @b = 1
			set @sql = @sql + '
			alter table [%1] enable trigger [trg_%1_checkConstraints]'

		exec [prcExecuteSql] @sql, @className, @tableName
	
		fetch from @c into @className, @tableName, @singleBranch, @singleBranchFldName
	end
	
	close @c deallocate @c

	-- users:
	delete [us000] where [guid] not in (select [userGuid] from [ui000] where [reportid] = 268562432 and [subID] = @branchGuid and [permission] = 1) and [bAdmin] = 0

	EXEC prcDisableTriggers 'br000'
	delete [br000] where [guid] != @branchGuid
	alter table [br000] enable trigger all
#########################################################
#END