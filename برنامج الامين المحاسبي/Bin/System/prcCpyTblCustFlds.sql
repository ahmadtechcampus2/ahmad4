########################################################
CREATE PROCEDURE prcCpyTblCustFlds
	@DestDate NVARCHAR(100)
AS
	EXEC [dbo].[prcCopyTbl] @DestDate,'CFFlds000'
	EXEC [dbo].[prcCopyTbl] @DestDate,'CFGroup000'
	EXEC [dbo].[prcCopyTbl] @DestDate,'CFMapping000'
	EXEC [dbo].[prcCopyTbl] @DestDate,'CFMultiVal000'

	DECLARE @c CURSOR ,@C2 CURSOR,@GGUID UNIQUEIDENTIFIER,@TblName NVARCHAR(max),
	@FldType INT ,@ColumnName NVARCHAR(100),@TextDefaultValue NVARCHAR(100),@IntDefaultValue INT ,@FloatDefaultValue FLOAT
	DECLARE @Sql NVARCHAR(max),@I INT ,@Fech INT
	SET @C = CURSOR FAST_FORWARD FOR SELECT GUID ,TableName FROM CFGroup000
	OPEN @C FETCH FROM @c INTO @GGUID,@TblName
	SET @Fech = @@FETCH_STATUS
	WHILE @Fech = 0
	BEGIN
		EXEC [dbo].[prcCopyTbl] @DestDate,@TblName
	/*	SET @Sql = 'CREATE TABLE ' + @DestDate + '.DBO.' + @TblName + CHAR(13) + '(' + CHAR(13)
		SET @I = 0
		SET @C2 = CURSOR FAST_FORWARD FOR SELECT ColumnName,FldType,TextDefaultValue,IntDefaultValue,FloatDefaultValue FROM CFFlds000
		WHERE GGuid = @GGUID
		SET @Sql = @Sql + '[Guid] UNIQUEIDENTIFIER ,Orginal_Guid UNIQUEIDENTIFIER, Orginal_Table NVARCHAR(256)'
		OPEN @C2
		FETCH FROM @c2 INTO @ColumnName,@FldType,@TextDefaultValue,@IntDefaultValue,@FloatDefaultValue
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @Sql = @Sql + ',' + CHAR(13)
			
			SET @Sql = @Sql + @ColumnName + ' ' 
			+ CASE @FldType WHEN 0 THEN 'NVARCHAR(256) COLLATE ARABIC_CI_AI ' WHEN 1 THEN ' INT ' WHEN 2 THEN ' FLOAT ' WHEN 3 THEN ' FLOAT ' WHEN 4 THEN ' DATETIME ' ELSE ' NVARCHAR(255) COLLATE ARABIC_CI_AI ' END
			+ CASE WHEN @FldType = 1 AND @IntDefaultValue IS NOT NULL THEN  ' DEFAULT ' + CAST (@IntDefaultValue AS NVARCHAR(256))
				WHEN (@FldType = 3 OR  @FldType = 2) AND @FloatDefaultValue IS NOT NULL THEN  ' DEFAULT ' + CAST (@FloatDefaultValue AS NVARCHAR(256))
				WHEN (@FldType = 0 OR  @FldType = 5) AND @TextDefaultValue 	IS NOT NULL THEN  ' DEFAULT ' + '''' + @TextDefaultValue + '''' ELSE '' END
			FETCH FROM @c2 INTO @ColumnName,@FldType,@TextDefaultValue,@IntDefaultValue,@FloatDefaultValue
		END
		SET @Sql = @Sql + ')'

		EXEC (@Sql)
		
		CLOSE @c2
		DEALLOCATE @C2*/
		FETCH FROM @c INTO @GGUID,@TblName
		SET @Fech = @@FETCH_STATUS
	END
	CLOSE @c 
	DEALLOCATE @c
########################################################
#END  
	
	 
