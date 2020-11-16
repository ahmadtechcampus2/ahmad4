############################################################################################
CREATE PROCEDURE prcCheckDB_bu_duplicateNumbers
	@Correct [INT] = 0
AS
	-- ignore @correct:
	INSERT INTO [ErrorLog]([Type], [g1])
		select 0x310, [guid] from [bu000] [b] inner join 
		(select [number], [typeGuid], [branch] from [bu000] group by [number], [typeGuid], [branch] having count(*) > 1) as [e]
		on [b].[typeGuid] = [e].[typeGuid] and [b].[branch] = [e].[branch] and [b].[number] = [e].[number]

	-- correct if necessary:
	if (@@rowcount * @correct) <> 0
	begin
		declare
			@c cursor,
			@guid [uniqueidentifier],
			@maxNum [int]

		set @maxNum = isnull((select max([number]) from [bu000]), 0)
		
		set @c = cursor dynamic for select [guid] from [bu000] [b] inner join [ErrorLog] [e] on [b].[guid] = [e].[g1]
		open @c fetch from @c into @guid

		while @@fetch_status = 0
		begin
			set @maxNum = @maxNum + 1
			update [bu000] set [number] = @maxNum where current of @c
			fetch from @c into @guid
		end
		close @c deallocate @c
		
	end

############################################################################################
#END 