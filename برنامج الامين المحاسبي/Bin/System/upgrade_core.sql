#include schema.sql

#########################################################
CREATE PROCEDURE prcUpgradeDatabase
	@OldMajVer [INT], @OldMinVer [INT]
AS
/* 
This procedure:
	- is the main upgrade procedure.
	- is responsible for calling all upgrade sub-procedures.
*/
	SET NOCOUNT ON

	DECLARE
		@c CURSOR,
		@prc [VARCHAR](128),
		@StartProc [VARCHAR](128),
		@SQL [VARCHAR](255) 

	SET @StartProc = 'prcUpgradeDatabase_From' + CAST(@OldMajVer AS [VARCHAR]) + CAST(@OldMinVer AS [VARCHAR])
	
	SET @c = CURSOR SCROLL READ_ONLY  FOR 
			SELECT [SPECIFIC_NAME]
			FROM [INFORMATION_SCHEMA].[ROUTINES]
			WHERE [ROUTINE_TYPE] = 'PROCEDURE' AND [SPECIFIC_NAME] LIKE 'prcUpgradeDatabase_From%'
			ORDER BY [SPECIFIC_NAME]

	OPEN @c FETCH FROM @c INTO @prc

	SET @SQL = 'Start of Upgrade process: ' + CAST(@OldMajVer AS [VARCHAR]) + '.' + CAST(@OldMinVer AS [VARCHAR])
	EXEC [prcLog] @SQL

	-- execute procs
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @prc >= @StartProc
		BEGIN
			SET @SQL = 'EXECUTE PROC: ' + @prc
			EXEC [prcLog] @SQL
			BEGIN TRY
				EXEC (@prc)
			END TRY
			BEGIN CATCH
				SET @SQL = 'Error in ' + @SQL;
				EXEC [prcLog] @SQL;
				THROW;
			END CATCH
		END
		ELSE
		BEGIN
			SET @SQL = 'SKIPPED PROC: ' + @prc
			EXEC [prcLog] @SQL
		END
		FETCH FROM @c INTO @prc
	END

	-- drop upgrade procs
	EXEC [prcLog] 'Dropping upgrade procedures'
	FETCH FIRST FROM @c INTO @prc
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @SQL = 'DROP PROC: ' + @prc
		EXEC [prcLog] @SQL
		SET @SQL = 'DROP PROC ' + @prc
		EXEC (@SQL)
		FETCH FROM @c INTO @prc
	END

	CLOSE @c DEALLOCATE @c
	
	--EXECUTE [prcDropProcedure] 'prcConvertClassFld'
	EXECUTE [prcDropProcedure] 'prcUpgrade_AddOldFlds'
	--DELETE [mc000] WHERE [Type] = 600 
#########################################################
CREATE PROCEDURE prcLinkER
	@Table		[VARCHAR](128),
	@Fld		[VARCHAR](128),
	@DropFld	[BIT] = 1

AS
/*
This procedure:
	- inserts records in er000 to relate sides with en000
	- is usally called from prcUpgradeDatabaseMapGUID
*/
	DECLARE
		@Type	[CHAR](1),
		@SQL	[VARCHAR](8000)

	IF @Table = 'bu000'
		SET @Type = '2'

	ELSE IF @Table = 'py000'
		SET @Type = 4

	ELSE IF @Table = 'ch000' AND @Fld = 'CEntry1'
		SET @Type = 5

	ELSE IF @Table = 'ch000' AND @Fld = 'CEntry2'
		SET @Type = 6

	ELSE BEGIN
		RAISERROR('AmnE1001: Uknown ER Link ...', 16, 1)
		ROLLBACK TRANSACTION
		RETURN
	END

	SET @SQL = '
			INSERT INTO [er000] ([EntryGUID], [ParentGUID], [ParentType])
				SELECT [ce000].[GUID], ' + @Table + '.[GUID], ' + @Type + '
				FROM ' + @Table + ' INNER JOIN [ce000] ON FLOOR(' + @Table + '.' + @Fld + ') = FLOOR([ce000].[Number])'
				
	EXEC(@SQL)
	
	IF @DropFld = 1
		EXEC [prcDropFld] @Table, @Fld

#########################################################
CREATE PROCEDURE prcLinkMB
	@Table		[VARCHAR](128),
	@Fld		[VARCHAR](128),
	@DropFld	[BIT] = 1

AS
/*
This procedure:
	- related manufacturing with bill using mb000 table.
	- inserts records in mb000 to relate sides with mn000
	- is usally called from prcUpgradeDatabaseMapGUID
*/
	DECLARE
		@Type	[CHAR](1),
		@SQL	[VARCHAR](8000)

	IF @Table = 'bu000'
		SET @Type = '2'

	ELSE IF @Table = 'py000'
		SET @Type = 4

	ELSE IF @Table = 'ch000' AND @Fld = 'CEntry1'
		SET @Type = 5

	ELSE IF @Table = 'ch000' AND @Fld = 'CEntry2'
		SET @Type = 6

	ELSE BEGIN
		RAISERROR('AmnE1001: Uknown ER Link ...', 16, 1)
		ROLLBACK TRANSACTION
		RETURN
	END

	SET @SQL = '
			INSERT INTO [er000] ([EntryGUID], [ParentGUID], [ParentType])
				SELECT [ce000].[GUID], ' + @Table + '.[GUID], ' + @Type + '
				FROM ' + @Table + ' INNER JOIN [ce000] ON ' + @Table + '.' + @Fld + ' = [ce000].[Number]'
	EXEC(@SQL)
	
	IF @DropFld = 1
		EXEC [prcDropFld] @Table, @Fld

#########################################################
#END