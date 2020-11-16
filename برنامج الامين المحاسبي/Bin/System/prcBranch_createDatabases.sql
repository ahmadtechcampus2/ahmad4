######################################################### 
create proc prcBranch_createDatabases 
	@override [bit] = 0
as
	declare
		@c cursor,
		@guid [uniqueidentifier]
		
	set @c = cursor fast_forward for select [guid] from [br000]
	
	open @c fetch from @c into @guid
	
	while @@fetch_status = 0
	begin
		exec [prcBranch_createDatabase] @guid, @override
		fetch from @c into @guid
	end
	
	close @c deallocate @c
		
#########################################################
#end