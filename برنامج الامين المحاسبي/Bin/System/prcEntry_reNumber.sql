#########################################################
CREATE PROC prcEntry_reNumber
	@reNumberManualEntry BIT,
	@EntrySrcGuid UNIQUEIDENTIFIER,
	@FromDate DATE
	,@LgGuid UNIQUEIDENTIFIER=0x0
AS  
/*
this procedure
*/
	BEGIN TRAN

	DECLARE
		@ManualEntryCursor CURSOR,
		@EntryTypesCursor CURSOR,
		@branch [UNIQUEIDENTIFIER],
		@EntryType [UNIQUEIDENTIFIER],
		@Replication [BIT],
		@MaxNumber [INT]
	
	EXEC prcDisableTriggers 'ce000', 0
	EXEC prcDisableTriggers 'py000', 0
	EXEC prcDisableTriggers 'er000', 0
	
	DECLARE @Parms NVARCHAR(2000)
	SET @Parms = ''
	--EXEC prcCreateMaintenanceLog 16,@LgGuid OUTPUT,@Parms 

	CREATE TABLE [#ce]( [GUID] [UNIQUEIDENTIFIER], [NewNumber] [INT] IDENTITY (1,1) NOT NULL PRIMARY KEY)
	CREATE TABLE [#PY]( [GUID] [UNIQUEIDENTIFIER], [NewNumber] [INT] IDENTITY (1,1) NOT NULL PRIMARY KEY)
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @EntrySrcGuid

	SET @ManualEntryCursor = CURSOR FAST_FORWARD FOR SELECT DISTINCT [branch] FROM [ce000]
	SET @EntryTypesCursor = CURSOR FAST_FORWARD FOR SELECT DISTINCT [Type] FROM [#EntryTbl]

	OPEN @ManualEntryCursor FETCH FROM @ManualEntryCursor INTO @branch

	WHILE @@FETCH_STATUS = 0
	BEGIN
	---------------------------------------------------------------------
		IF(@reNumberManualEntry = 1)
		BEGIN
			-- insert records guids of current branch:
			INSERT INTO [#ce]([GUID]) SELECT [GUID] FROM [ce000] 
			WHERE [branch] = @branch AND Date >= @FromDate
			ORDER BY [Date], [Number]

			-- select max number to start num with it form specific date
			SET @MaxNumber = ISNULL((SELECT MAX ([Number]) FROM [ce000] WHERE Date < @FromDate), 0)

			-- update related ce with new numbers from #ce:
			UPDATE [ce000] SET [ce000].[Number] = [ce].[NewNumber] + @MaxNumber
				FROM [#ce] AS [ce] INNER JOIN [ce000] ON [ce].[GUID] = [ce000].[GUID]
		
			-- re-prepare #ce for a new branch:
			TRUNCATE TABLE [#ce]
		END
		-----------------------------------------------------------------
		-----------------------------------------------------------------
		OPEN @EntryTypesCursor 
		FETCH FROM @EntryTypesCursor INTO @EntryType

		WHILE @@FETCH_STATUS = 0
		BEGIN
			INSERT INTO [#PY]([GUID]) SELECT [GUID] FROM [py000] 
			WHERE [BranchGUID] = @branch AND  [TypeGUID] = @EntryType AND Date >= @FromDate
			ORDER BY [Date], [Number]

			SET @MaxNumber = ISNULL((SELECT MAX ([Number]) FROM [py000] WHERE TypeGUID = @EntryType AND Date < @FromDate), 0)

			UPDATE [py000] SET [py000].[Number] = [TPY].[NewNumber] + @MaxNumber
			FROM [#PY] AS [TPY] INNER JOIN [py000] ON [TPY].[GUID] = [py000].[GUID]
			
			UPDATE [er000] SET ParentNumber = [PY].Number
			FROM py000 [PY] WHERE [er000].ParentGUID = PY.GUID

			FETCH FROM @EntryTypesCursor INTO @EntryType
			TRUNCATE TABLE [#PY]
		END
		CLOSE @EntryTypesCursor 
		-----------------------------------------------------------------

		FETCH FROM @ManualEntryCursor INTO @branch
	END

	EXEC prcEnableTriggers 'ce000'
	EXEC prcEnableTriggers 'py000'
	EXEC prcEnableTriggers 'er000'

	CLOSE @ManualEntryCursor 
	DEALLOCATE @ManualEntryCursor	
	DEALLOCATE @EntryTypesCursor 	
	EXEC prcCloseMaintenanceLog @LgGuid
	COMMIT TRAN
#########################################################
#END