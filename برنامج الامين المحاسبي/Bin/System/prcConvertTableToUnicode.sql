#########################################################
CREATE PROCEDURE prcConvertTableToUnicode
	@TableName VARCHAR(100),
	@TableID BIGINT
AS
	SET NOCOUNT ON
	
	CREATE TABLE #stringColumns
	(
		ColumnID int,
		ColumnName varchar(100),
		[ISNULL] BIT,
		SourceType varchar(100),
		UnicodeType varchar(100)
	)

	DECLARE @LogText varchar(500)
	SET @LogText = 'Start of convert table ' + @TableName + ' to unicode.'
	EXEC [prcLog] @LogText

	INSERT INTO #stringColumns (ColumnID, ColumnName, [ISNULL], SourceType, UnicodeType) EXEC prcGetTableStringColumns @TableID
	IF @@ROWCOUNT = 0 
	BEGIN
		SET @LogText = 'End of convert table ' + @TableName + ' to unicode, no need to convert.'
		EXEC [prcLog] @LogText
		 
		RETURN 
	END 
	CREATE TABLE #defaultValuesConstraints
	(
		ContraintID bigint,
		ContraintName varchar(100),
		ColumnName varchar(100),
		DefaultValue varchar(100)
	)

	CREATE TABLE #Indexes
	( 
	  TableName VARCHAR(100) NOT NULL
	 ,IndexName VARCHAR(100) NOT NULL
	 ,IsClustered BIT NOT NULL
	 ,IsPrimaryKey BIT NOT NULL
	 ,IndexCreateSQL VARCHAR(max) NOT NULL
	 ,IndexDropSQL VARCHAR(max) NOT NULL
	)

	INSERT INTO #defaultValuesConstraints (ContraintID, ContraintName, ColumnName, DefaultValue) EXEC prcGetTableDefaultValueConstraints @TableID
	INSERT INTO #Indexes(TableName, IndexName, IsClustered, IsPrimaryKey, IndexCreateSQL, IndexDropSQL) EXEC prcGetTableIndexes @TableID

	SET @LogText = 'Drop default value constraints for table ' + @TableName + '.'
	EXEC [prcLog] @LogText
	EXEC prcDeleteTableDefaultValueConstraints @TableName

	SET @LogText = 'Drop indexes for table ' + @TableName + '.'
	EXEC [prcLog] @LogText
	EXEC prcDeleteTableIndexes
	-- Convert Table Column To Unicode Support

	DECLARE @AlterTypeCommand varchar(300)
	DECLARE @ColumnName varchar(100)
	DECLARE @UnicodeType varchar(50)
	DECLARE @ISNull BIT
	DECLARE stringColumns_cursor CURSOR FOR  
	SELECT  ColumnName, UnicodeType, [ISNULL]
	FROM #stringColumns
	OPEN stringColumns_cursor   
	FETCH NEXT FROM stringColumns_cursor INTO @ColumnName, @UnicodeType, @ISNull
	WHILE @@FETCH_STATUS = 0   
	BEGIN   
		SET @LogText = 'Start of convert column ' + @ColumnName + ' in table ' + @TableName + ' to unicode.'
		EXEC [prcLog] @LogText

		SET @AlterTypeCommand = 'ALTER TABLE ' + @TableName + ' ALTER COLUMN [' + @ColumnName + '] ' + @UnicodeType
		IF @ISNull = 0
		BEGIN
			SET @AlterTypeCommand = @AlterTypeCommand + ' NOT NULL'
		END
	
		execute (@AlterTypeCommand)

		EXEC [prcLog] @AlterTypeCommand
		SET @LogText = 'End of convert column ' + @ColumnName + ' in table ' + @TableName + ' to unicode.'
		EXEC [prcLog] @LogText
	
		FETCH NEXT FROM stringColumns_cursor INTO @ColumnName, @UnicodeType, @ISNull
	END   
	CLOSE stringColumns_cursor   
	DEALLOCATE stringColumns_cursor 
	--End Conversion

	SET @LogText = 'Restore default value constraints for table ' + @TableName + '.'
	EXEC [prcLog] @LogText
	EXEC prcRestoreTableDefaultValueConstraints @TableName

	SET @LogText = 'Restore indexes for table ' + @TableName + '.'
	EXEC [prcLog] @LogText
	EXEC prcRestoreTableIndexes

	SET @LogText = 'End of convert table ' + @TableName + ' to unicode.'
	EXEC [prcLog] @LogText
#########################################################
#END