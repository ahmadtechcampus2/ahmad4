#########################################################
CREATE PROCEDURE prcDropFldIndex
	@Table [NVARCHAR](128),
	@Column [NVARCHAR](128)
AS
	SET NOCOUNT ON 
	
	DECLARE @Sql NVARCHAR(200)
	SET @Sql = 'prcDropFldIndex ' + @Table + '.' + @Column
	EXECUTE [prcLog] @Sql
	
	DECLARE
		@c CURSOR,
		@Name [NVARCHAR](128)

	CREATE table [#i](
		[Name] [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
		[Notes] [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
		[Keys] [NVARCHAR](2078) COLLATE ARABIC_CI_AI)
	INSERT INTO [#i] EXEC [sp_helpindex] @Table

	IF SUBSTRING(@Column, 1, 1) = '['
		SET @Column = SUBSTRING(@Column, 2, LEN(@Column) - 2)

	SET @c = CURSOR FAST_FORWARD FOR SELECT [Name] FROM [#i] WHERE [Keys] LIKE '%' + @Column + '%'
	OPEN @c FETCH FROM @c INTO @Name

	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @Name LIKE 'PK%'
			EXEC ('ALTER TABLE ' + @Table + ' DROP CONSTRAINT ' + @Name)
		ELSE
			EXEC ('DROP INDEX ' + @Table + '.' + @Name)

		FETCH FROM @c INTO @Name
	END

	DROP TABLE [#i]
	CLOSE @c DEALLOCATE @c
#########################################################
CREATE PROCEDURE prcDropAllIndexes
	@TblName NVARCHAR(100)
AS
	SET NOCOUNT ON 

	DECLARE @Sql NVARCHAR(200)
	SET @Sql = 'prcDropAllIndexes ' + @TblName
	EXECUTE [prcLog] @Sql
	DECLARE
		@c CURSOR

	IF SUBSTRING(@TblName,1,1) = ']'
		SET @TblName = SUBSTRING(@TblName,2,LEN(@TblName) - 2)
	CREATE table [#i](
		[Name] [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
		[Notes] [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
		[Keys] [NVARCHAR](2078) COLLATE ARABIC_CI_AI)
	
	INSERT INTO #i EXEC  SP_HELPINDEX @TBLNAME

	SET @C = CURSOR FAST_FORWARD FOR SELECT DISTINCT CASE 
			WHEN CHARINDEX('primary key',[Notes],0) > 0 THEN 'ALTER TABLE ' + @TblName + ' DROP CONSTRAINT ' + [name] 
			ELSE 'DROP INDEX ' + @TblName + '.' + [name] END
		FROM 
		[#i]

	OPEN @c FETCH FROM @c INTO @Sql

	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC (@Sql)
		FETCH FROM @c INTO @Sql
	END
	CLOSE @c DEALLOCATE @c
#########################################################
#END