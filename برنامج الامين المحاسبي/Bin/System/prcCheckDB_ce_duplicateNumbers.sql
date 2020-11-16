############################################################################################
CREATE PROCEDURE prcCheckDB_ce_duplicateNumbers
	@Correct [INT] = 0
AS
	-- ignore @correct:
	INSERT INTO [ErrorLog]([Type], [g1])
		select 0x50B, [guid] from [ce000] [c] inner join 
		(select [number], [typeGuid], [branch] from [ce000] group by [number], [typeGuid], [branch] having count(*) > 1) as [e]
		on [c].[typeGuid] = [e].[typeGuid] and [c].[branch] = [e].[branch] and [c].[number] = [e].[number]

	-- correct if necessary:
	if (@@rowcount * @correct) <> 0
	begin
		declare
			@c cursor,
			@guid [uniqueidentifier],
			@maxNum [int]

		set @maxNum = isnull((select max([number]) from [ce000]), 0)
		
		set @c = cursor dynamic for select [guid] from [ce000] [c] inner join [ErrorLog] [e] on [c].[guid] = [e].[g1]
		open @c fetch from @c into @guid

		while @@fetch_status = 0
		begin
			set @maxNum = @maxNum + 1
			update [ce000] set [number] = @maxNum where current of @c
			fetch from @c into @guid
		end
		close @c deallocate @c
		
	end


############################################################################################
#END 