#########################################################
CREATE PROC prcDatabase_compareSchema
	@targetDB [NVARCHAR](128) = '',
	@originDB [NVARCHAR](128) = '',
	@table [NVARCHAR](128) = ''
AS
	DECLARE @SQL [NVARCHAR](2000)

	CREATE TABLE [#origin] (
		[tableName] [NVARCHAR](128)  COLLATE ARABIC_CI_AI, 
		[columnID] [INT], 
		[columnName] [NVARCHAR](128) COLLATE ARABIC_CI_AI, 
		[columnType] [NVARCHAR](128) COLLATE ARABIC_CI_AI, 
		[columnLength] [INT]
	)
	CREATE TABLE [#target] (
		tableName [NVARCHAR](128) COLLATE ARABIC_CI_AI,
		columnID [INT], 
		columnName [NVARCHAR](128) COLLATE ARABIC_CI_AI, 
		columnType [NVARCHAR](128) COLLATE ARABIC_CI_AI, 
		columnLength [INT]
	)


	SET @SQL = '
		SELECT [o].[name], [c].[colid], [c].[name], [t].[name], [c].[length]
		FROM %0..[syscolumns] [c] INNER JOIN %0..[sysobjects] [o] ON [c].[id] = [o].[id] INNER JOIN [master]..[systypes] [t] ON [c].[xtype] = [t].[xtype]
		WHERE [o].[xtype] = ''U''
		ORDER BY [o].[id], [c].[colid]'

	IF ISNULL(@originDB, '') = ''
		SET @originDB = db_name()

	INSERT INTO [#origin] EXEC [prcExecuteSQL] @SQL, @originDB

	IF ISNULL(@targetDB, '') = ''
	BEGIN
		SELECT * FROM [#origin] ORDER BY [tableName], columnID
		RETURN
	END

	INSERT INTO [#target] EXEC [prcExecuteSQL] @SQL, @targetDB

	SELECT [o].*
	FROM [#origin] AS [o] LEFT JOIN [#target] AS [t] 
		ON [o].[tableName] = [t].[tableName]
		AND [o].[columnID] = [t].[columnID]
		AND [o].[columnType] = [t].[columnType]
		AND [o].[columnLength] = [t].[columnLength]
	WHERE [t].[tableName] IS NULL AND (@table = '' OR [o].[tableName] = @table)

	ORDER BY [o].[tableName], [o].[columnID]

	SELECT [t].*
	FROM [#origin] AS [o] RIGHT JOIN [#target] AS [t]
		ON [o].[tableName] = [t].[tableName]
		AND [o].[columnID] = [t].[columnID]
		AND [o].[columnType] = [t].[columnType]
		AND [o].[columnLength] = [t].[columnLength]
	WHERE [o].[tableName] IS NULL AND (@table = '' OR [t].[tableName] = @table)
	ORDER BY [t].[tableName], [t].[columnID]

#########################################################
#END