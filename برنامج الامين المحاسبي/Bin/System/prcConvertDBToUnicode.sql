#########################################################
CREATE PROCEDURE prcConvertDBToUnicode
AS

	SET NOCOUNT ON

	/****************************************** Algorithm ******************************************/

	-- Get all Columns in DB that we must alter it to support unicode and store it in temp table @stringColumnsTable.
	-- Iterate over @stringColumnsTable and store default value contraints in @defaultValuesTable.
	-- Iterate over @stringColumnsTable and store indexes contraint in @indexesTable
	-- Drop all @defaultValuesTable contraints.
	-- Drop all @indexesTable.
	-- Execute Alter table to support unicode.
	-- Restore all contarints in defaultValuesTable.
	-- Restore all indexes in indexesTable.

	/**********************************************************************************************/
	
	EXEC [prcLog] 'Start of convert database to unicode process.'
	
	CREATE TABLE #TableToBeCoverted
	(
		TableName varchar(100),
		TableID bigint
	)

	INSERT #TableToBeCoverted(TableName, TableID) EXEC prcGetTablesToBeConvertedUnicode
	IF @@ROWCOUNT = 0 
	BEGIN
		EXEC [prcLog] 'End of convert database to unicode process, the database is converted previously.'
		RETURN 
	END 

	DECLARE @TableName varchar(100)
	DECLARE @TableID varchar(100)

	DECLARE tables_cursor CURSOR FOR  
	SELECT TableName, TableID
	FROM #TableToBeCoverted

	OPEN tables_cursor   
	FETCH NEXT FROM tables_cursor INTO @TableName, @TableID

	WHILE @@FETCH_STATUS = 0   
	BEGIN   
		EXECUTE prcConvertTableToUnicode @TableName, @TableID

		FETCH NEXT FROM tables_cursor INTO @TableName, @TableID
	END   

	CLOSE tables_cursor   
	DEALLOCATE tables_cursor 
	EXEC [prcLog] 'End of convert database to unicode process.'
#########################################################
#END