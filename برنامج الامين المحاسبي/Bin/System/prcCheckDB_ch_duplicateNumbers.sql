############################################################################################
CREATE PROCEDURE prcCheckDB_ch_duplicateNumbers
	@correct [INT] = 0
AS
	-- ignore @correct:
	INSERT INTO [ErrorLog]([Type], [g1])
		select 0x702, [guid] from [ch000] [c] inner join 
		(select [number], [typeGuid], [branchGuid] from [ch000] group by [number], [typeGuid], [branchGuid] having count(*) > 1) as [e]
		on [c].[typeGuid] = [e].[typeGuid] and [c].[branchGuid] = [e].[branchGuid] and [c].[number] = [e].[number]

	-- correct if necessary:
	if (@@rowcount * @correct) <> 0
	begin
		declare
			@c cursor,
			@guid [uniqueidentifier],
			@maxNum [int]

		set @maxNum = isnull((select max([number]) from [ch000]), 0)
		
		set @c = cursor dynamic for select [guid] from [ch000] [c] inner join [ErrorLog] [e] on [c].[guid] = [e].[g1]
		open @c fetch from @c into @guid

		while @@fetch_status = 0
		begin
			set @maxNum = @maxNum + 1
			update [ch000] set [number] = @maxNum where current of @c
			fetch from @c into @guid
		end
		close @c deallocate @c
		
	end


############################################################################################
#END  