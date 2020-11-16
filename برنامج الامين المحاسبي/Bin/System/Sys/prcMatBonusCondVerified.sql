#######################################################################################
CREATE PROCEDURE prcIsMatCondVerified
	@CondGUID UNIQUEIDENTIFIER, 
	@mtGUID UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 
	DECLARE @result INT 
	SET @result = 0	
	DECLARE 
		@sql NVARCHAR(max),
		@Cond NVARCHAR(max)
	
	SET @Cond = 	dbo.fnGetConditionStr2( NULL , @CondGUID)
	IF ISNULL( @Cond, '') != ''
	BEGIN 
		CREATE TABLE [#R]( [found] BIT)
		SET @sql = ' 
			SET NOCOUNT ON 
			IF EXISTS ( SELECT * FROM [vwMtGr]'
			IF CHARINDEX( '<<>>', @Cond) > 0
			BEGIN
				Declare @CF_Table NVARCHAR(255) 
				SELECT @CF_Table = CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'mt000'
				SET @sql = @sql +'  LEFT JOIN '+@CF_Table+' ON vwmtgr.mtGUID = '+@CF_Table+'.orginal_guid'
				SET @Cond = REPLACE(@Cond,'<<>>','')
			END
			DECLARE @MaterialsSegmentsCount [INT]
			SET @MaterialsSegmentsCount = 0
			SELECT @MaterialsSegmentsCount = COUNT(*) FROM [dbo].[vwConditions] WHERE [cndGUID] = @CondGUID AND [cndType] = 17 AND [FieldNum] >= 3000 AND [FieldNum] < 4000 
			IF @MaterialsSegmentsCount > 0
			Begin
					DECLARE @CNT INT,
					@CNT_STR NVARCHAR(MAX)
					SET @CNT = 0
					SET @CNT_STR = N''
					WHILE @CNT < @MaterialsSegmentsCount
					BEGIN
						SET @CNT = @CNT + 1;
						SET @CNT_STR = CONVERT(NVARCHAR, @CNT) 
						SET @SQL = @SQL + ' CROSS APPLY dbo.fnSEG_GetMaterialElements([vwMtGr].[mtGUID]) s' + @CNT_STR + CHAR(10)
					END;
			End
			SET @Sql = @Sql +' WHERE ((' + @Cond + ') AND ([mtGuid] = ''' + CAST( @mtGUID AS NVARCHAR(250)) + ''')))
				INSERT INTO [#R] SELECT 1
			ELSE 
				INSERT INTO [#R] SELECT 0 '
		EXEC (@sql)
		IF EXISTS ( SELECT * FROM [#R] WHERE [found] = 1)
			SET @result = 1
	END 
	RETURN @result

#######################################################################################
CREATE PROCEDURE prcIsCustCondVerified
	@CondGUID UNIQUEIDENTIFIER, 
	@cuGUID UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 
	DECLARE @result INT 
	SET @result = 0	
	DECLARE @sql NVARCHAR(max)
	SET @sql = 	dbo.fnGetCustConditionStr( @CondGUID)
	IF ISNULL( @sql, '') != ''
	BEGIN 
		CREATE TABLE [#R]( [found] BIT)

		SET @sql = ' 
			SET NOCOUNT ON 

			IF EXISTS ( SELECT * FROM [vwCu] WHERE ((' + @sql + ') AND ([cuGuid] = ''' + CAST( @cuGUID AS NVARCHAR(250)) + ''')))
				INSERT INTO [#R] SELECT 1
			ELSE 
				INSERT INTO [#R] SELECT 0 '
		EXEC (@sql)
		IF EXISTS ( SELECT * FROM [#R] WHERE [found] = 1)
			SET @result = 1
	END 
	RETURN @result
#######################################################################################
#END
