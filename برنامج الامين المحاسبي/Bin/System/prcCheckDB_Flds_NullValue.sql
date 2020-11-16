######################################################################################
CREATE PROC prcCheckDB_Flds_NullValue
			@Correct [INT] = 0
AS
	DECLARE @Tbl TABLE ( [FldName] [NVARCHAR](255),[UsName] [NVARCHAR](255))
	INSERT INTO @Tbl 
		SELECT [Tbl].[Name],[Us].[Name] FROM [dbo].[sysobjects] As [Tbl] INNER JOIN [sysusers] AS [US] on [US].[uid] = [Tbl].[uid]  WHERE [Tbl].[xtype] = 'u' AND [Tbl].[status] > 0

	DECLARE @c_Tbl CURSOR, 		
		@TblName [NVARCHAR](1000),
		@UsName [NVARCHAR](128)


	SET @c_Tbl = CURSOR FAST_FORWARD FOR 
		SELECT [FldName],[UsName] FROM @Tbl
	
	OPEN @c_Tbl FETCH NEXT FROM @c_Tbl INTO @TblName,@UsName
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		EXEC [prcUpdateTblFldsNullValue] @TblName, @Correct,@UsName
		FETCH NEXT FROM @c_Tbl INTO @TblName,@UsName
	END
	CLOSE @c_tbl
	DEALLOCATE @c_tbl
#######################################################################################
#END