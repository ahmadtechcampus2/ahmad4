#########################################################
CREATE PROC prcItemSecurityExtended_Optimize
AS
	DECLARE
		@c CURSOR,
		@TableName [NVARCHAR](128),
		@SortTableName [NVARCHAR](128),
		@ParentFldName [NVARCHAR](128),
		@SQL [NVARCHAR](2000),
		@EnabledItemSecurity [INT]

	SET @EnabledItemSecurity = [dbo].[fnOption_get]('EnableItemSecurity', '0')

	SET @c = CURSOR FAST_FORWARD FOR SELECT [tableName], [ParentFldName] FROM [isrt]

	OPEN @c FETCH FROM @c INTO @tableName, @ParentFldName
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @SQL = 'trg_' + @tableName + '_ise'
		EXEC [prcDropTrigger] @SQL

		IF( @EnabledItemSecurity = 1)
			EXEC [prcItemSecurityExtended_InstallTable] @tableName, @ParentFldName

		SET @SortTableName = REPLACE( @tableName, '0', '')

		-- if no branches were present, or branch system is disabled:
		IF @EnabledItemSecurity = 0
			EXEC [prcExecuteSQL] '
			ALTER VIEW [vt%0]
			AS 
				SELECT * FROM [%1]' , @SortTableName, @tableName

		ELSE
			IF @tableName = 'mt000'
			EXEC [prcExecuteSQL]'
			ALTER VIEW [vt%0]
			AS
				SELECT [%0].*  
				FROM  
					[%1] AS [%0] 
					INNER JOIN vtisx [i] ON (CASE [%0].Parent WHEN 0x0 THEN [%0].[Guid] ELSE [%0].[Parent] END) = [i].[ObjGuid] ', @SortTableName, @tableName

			 ELSE
				EXEC [prcExecuteSQL]'
				ALTER VIEW [vt%0]
				AS
					SELECT [%0].*  
					FROM  
						[%1] AS [%0] 
						INNER JOIN vtisx [i] ON [%0].[Guid] = [i].[ObjGuid] ', @SortTableName, @tableName

		FETCH FROM @c INTO @tableName, @ParentFldName
	END

	CLOSE @c DEALLOCATE @c
#########################################################
#END