#########################################################
CREATE PROC prcEntry_assignContraAcc
	@correct [INT] = 0,
	@GUID [UNIQUEIDENTIFIER] = 0x0,
	@forced [BIT] = 0
AS 
/* 
This procedure: 
	- automatically assignes ContraAccGUID for single-sided entries.
	- deals only with user entered entries. thus, never deals with auto-generated entries.
	- work on a given ce.GUID, or for all entries, depending on @GUID, as 0x0 means all entries.
	- depending on @Forced:
		- when 0, only empty contraAccountGUIDs are auto-assigned.
		- when 1, auto-assignment is forced on all possible entries.

algorithm: 
	- two passes approach: one for fixing single-debitors entries, and another for single-creditors entries. 
	- in the first pass, a variable table is filled with the type, parent and MainDebitor of each possible entry 
	  then a single update statement will update contra AccountGUIDs for after joining with this table. 
	- this will be repeated to include single-creditors entries. 
	- smart-match debit = credit:
		for remaining empty contras, link depending on debit = credit approach

*/ 
	SET NOCOUNT ON 

/*
	-- if related or auto-generated, then exit
	IF EXISTS(SELECT * FROM er000 WHERE EntryGUID = @GUID)
		RETURN
*/

	BEGIN TRAN

	SET @GUID = ISNULL(@GUID, 0x0) 
	DECLARE @t TABLE([ParentGUID] [UNIQUEIDENTIFIER], [MainAcc] [UNIQUEIDENTIFIER]) 

	-- get single-sided MainDebitors:  
	IF @GUID = 0x0 
		INSERT INTO @t  
			SELECT [ParentGUID], (SELECT TOP 1 [AccountGUID] FROM [en000] WHERE [ParentGUID] = [en].[ParentGUID] AND [Credit] = 0) 
			FROM [en000] en 
			WHERE [Credit] = 0 
			GROUP BY [ParentGUID] 
			HAVING COUNT(*) = 1 
	ELSE 
		INSERT INTO @t 
			SELECT [ParentGUID], (SELECT TOP 1 [AccountGUID] FROM [en000] WHERE [ParentGUID] = [en].[ParentGUID] AND [Credit] = 0) 
			FROM [en000] [en] 
			WHERE [Credit] = 0 AND [ParentGUID] = @GUID 
			GROUP BY [ParentGUID] 
			HAVING COUNT(*) = 1 

	-- update contra acc for creditors to MainDebitors: 
	IF @Forced = 1 
		UPDATE [en000] SET [ContraAccGUID] = [t].[MainAcc] 
		FROM [en000] INNER JOIN @t [t] ON [en000].[ParentGUID] = [t].[ParentGUID] 
		WHERE [Debit] = 0 
	ELSE 
		UPDATE [en000] SET [ContraAccGUID] = [t].[MainAcc] 
		FROM [en000] INNER JOIN  @t [t] ON [en000].[ParentGUID] = [t].[ParentGUID] 
		WHERE [Debit] = 0 AND [ContraAccGUID] = 0x0 

	-- prepare single-sided creditors: 
	DELETE @t 
	IF @GUID = 0x0 
		INSERT INTO @t  
			SELECT [ParentGUID], (SELECT TOP 1 [AccountGUID] FROM [en000] WHERE ParentGUID = en.ParentGUID AND Debit = 0)  
			FROM [en000] en 
			WHERE [Debit] = 0 
			GROUP BY [ParentGUID] 
			HAVING COUNT(*) = 1 
	ELSE 
		INSERT INTO @t 
			SELECT ParentGUID, (SELECT TOP 1 [AccountGUID] FROM [en000] WHERE [ParentGUID] = [en].[ParentGUID] AND [Debit] = 0) 
			FROM en000 en 
			WHERE [Debit] = 0 AND [ParentGUID] = @GUID 
			GROUP BY ParentGUID 
			HAVING COUNT(*) = 1 

	-- update contra acc for debitors from main creditor: 
	IF @Forced = 1  
		UPDATE [en000] SET [ContraAccGUID] = [t].[MainAcc] 
		FROM [en000] INNER JOIN  @t [t] ON [en000].[ParentGUID] = [t].[ParentGUID] 
		WHERE [Credit] = 0 
	ELSE 
		UPDATE [en000] SET [ContraAccGUID] = [t].[MainAcc] 
		FROM [en000] INNER JOIN  @t [t] ON [en000].[ParentGUID] = [t].[ParentGUID] 
		WHERE [Credit] = 0 AND [ContraAccGUID] = 0x0

	create table [#En_tbl]( [guid] [uniqueidentifier], [Value] [float], [ContraAccGuid] [uniqueidentifier], [AccountGuid] [uniqueidentifier]) 
	-- smart-match: debit = credit:

	insert into [#En_tbl]
	select [ed].[guid],	[ed].[debit], [ed].[contraAccGuid], [ec].[accountGuid]
	from [en000] [ed] inner join [en000] [ec] on [ed].[debit] = [ec].[credit]
	where [ed].[parentGuid] = @GUID and [ec].[parentGuid] = @GUID /*and [ed].[contraAccGuid] = 0x0*/ and [ed].[debit] != 0

	delete [#En_tbl]
	from ( select [Value] as [Val] from [#En_tbl] group by [Value] having count(*) > 1) as [c]
	where [Value] = [c].[Val]

	update [en000] 
	set [contraAccGuid] = [t].[accountGuid] 
	from [en000] [en] inner join [#En_tbl] [t] on [t].[guid] = [en].[guid]
	--where [en].[contraAccGuid] = 0x0

	delete [#En_tbl]

	insert into [#En_tbl]
	select [ec].[guid], [ec].[credit], [ec].[contraAccGuid], [ed].[accountGuid]
	from [en000] [ed] inner join [en000] [ec] on [ed].[debit] = [ec].[credit]
	where [ed].[parentGuid] = @GUID and [ec].[parentGuid] = @GUID /*and [ec].[contraAccGuid] = 0x0*/ and [ec].[credit] != 0

	delete [#En_tbl] 
	from ( select [Value] as [Val] from [#En_tbl] group by [Value] having count(*) > 1) as [c]
	where [Value] = [c].[Val]

	update [en000] 
	set [contraAccGuid] = [t].[accountGuid]
	from [en000] [en] inner join [#En_tbl] [t] on [t].[guid] = [en].[guid]
	--where [en].[contraAccGuid] = 0x0

	COMMIT TRAN

#########################################################
#END
