#########################################################
CREATE PROCEDURE prcDeleteCheckConstraints 
AS
	DECLARE @TblName [NVARCHAR](256),@ChcName [NVARCHAR](256),@c CURSOR, @Sql NVARCHAR(2000)
	SET @c = CURSOR FAST_FORWARD FOR  
	SELECT [chk].[Name] ,[tbl].[Name] FROM [dbo].[SYSOBJECTS] AS [chk] INNER JOIN [dbo].[SYSOBJECTS] AS [tbl] ON [tbl].[Id] = [chk].[parent_obj] WHERE [chk].[XType] = 'C'
	OPEN @c FETCH FROM @c INTO @ChcName,@TblName
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		SET @Sql = ' ALTER TABLE ' + @TblName + ' DROP CONSTRAINT ' + @ChcName
		EXEC (@Sql) 
		FETCH FROM @c INTO @ChcName,@TblName
	END
	CLOSE @c
	DEALLOCATE @c
#########################################################
#END 