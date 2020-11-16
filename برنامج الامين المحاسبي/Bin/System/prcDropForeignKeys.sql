############################################################
CREATE PROCEDURE prcDropForeignKeys
	@Tbl_Name	NVARCHAR(100) = ''
AS

	DECLARE @Sql AS NVARCHAR(max)
	SET @Sql =  'prcDropForeignKeys ' + @Tbl_Name
	EXECUTE [prcLog] @Sql
	DECLARE @C CURSOR,
			@fkName NVARCHAR(100),
			@tblName NVARCHAR(100)
		SET @c = CURSOR  FAST_FORWARD FOR 
			 SELECT o1.Name fkName,o2.Name tblName from sysforeignkeys f 
			 INNER JOIN sysobjects o1 ON f.constid = o1.Id INNER JOIN sysobjects o2 ON f.fKeyid = o2.Id 
			 INNER JOIN sysobjects o3 ON f.RKeyid = o3.Id 
			 WHERE o2.Name LIKE '%000' AND (@Tbl_Name = '' OR o3.Name = @Tbl_Name)
	OPEN @c FETCH NEXT FROM @c INTO @fkName,@tblName
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		SET @Sql = 'ALTER TABLE ' + @tblName + ' DROP CONSTRAINT ' + @fkName
		EXEC(@Sql) 
		FETCH NEXT FROM @c INTO @fkName,@tblName
	END
	CLOSE @c DEALLOCATE @c
############################################################
#END  