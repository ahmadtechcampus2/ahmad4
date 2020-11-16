############################################################################################
CREATE PROCEDURE prcCheckDB_et_duplicateNumbers
	@Correct [INT] = 0
AS
	-- ignore @correct:
	INSERT INTO [ErrorLog]([Type], [g1])
		select 0x311, [guid] from [py000] [p] inner join 
		(select [number], [typeGuid], [branchGuid] from [py000] group by [number], [typeGuid], [branchGuid] having count(*) > 1) as [e]
		on [p].[typeGuid] = [e].[typeGuid] and [p].[branchGuid] = [e].[branchGuid] and [p].[number] = [e].[number]

	-- correct if necessary:
	IF @Correct <> 0
	BEGIN
		declare
			@c cursor,
			@guid [uniqueidentifier],
			@maxNum [int]

		set @maxNum = isnull((select max([number]) from [py000]), 0)
		
		set @c = cursor dynamic for select [guid] from [py000] [p] inner join [ErrorLog] [e] on [p].[guid] = [e].[g1]
		open @c fetch from @c into @guid

		while @@fetch_status = 0
		begin
			set @maxNum = @maxNum + 1
			update [py000] set [number] = @maxNum where current of @c
			fetch from @c into @guid
		end
		close @c deallocate @c
		
	end

############################################################################################
#END  