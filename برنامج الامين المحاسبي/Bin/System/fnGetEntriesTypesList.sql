################################################################################
CREATE FUNCTION fnGetEntriesTypesList(
	@SrcGuid [UNIQUEIDENTIFIER] = 0x0, 
	@UserGUID [UNIQUEIDENTIFIER] = 0x0)
	RETURNS @Result TABLE( [GUID] [UNIQUEIDENTIFIER], [Security] [INT])
AS  
/*  
This function:  
	- returns the Type, Security of provided @SrcGuid. 
	- returns all types when @Source is NULL.  
	- can get the UserID if not specified.  
*/  
BEGIN
	IF(ISNULL(@UserGUID, 0x0) = 0x0)
		SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()

	IF( ISNULL(@SrcGuid, 0x0) = 0x0)
		INSERT INTO @Result 
			SELECT 
				[GUID],
				[BrowseSec]
			FROM 
				[fnGetUserEntriesSec]( @UserGUID) AS [fn]
	ELSE
		INSERT INTO @Result 
			SELECT 
				[IdType],
				[dbo].[fnGetUserEntrySec_Browse](@UserGUID, [IdType])
			FROM 
				[dbo].[RepSrcs] 
			WHERE 
				[IdTbl] = @SrcGuid AND [IdSubType] IN (0, 4)
	RETURN
END
################################################################################
CREATE PROCEDURE prcGetEntriesList
	@CondGuid UNIQUEIDENTIFIER = 0x00   
AS
	SET NOCOUNT ON    
	    
	DECLARE    
		@HasCond INT,    
		@Criteria NVARCHAR(max),    
		@SQL NVARCHAR(max),    
		@HaveCFldCondition	BIT -- to check existing Custom Fields , it must = 1 
	  
	SET @SQL = ' SELECT py.[ceGuid] AS [Guid], py.[ceSecurity] AS [Security] '   
	SET @SQL = @SQL + ' FROM [vwPyCe] py INNER JOIN er000 er ON er.ParentGuid = py.pyGuid AND er.ParentType = 4 ' 	  
   
	IF ISNULL(@CondGUID, 0X00) <> 0X00    
	BEGIN    
		DECLARE @CurrencyGUID UNIQUEIDENTIFIER  
		SET @CurrencyGUID = (SELECT TOP 1 guid FROM my000 WHERE CurrencyVal = 1)  
		SET @Criteria = dbo.fnGetEntryConditionStr('py', @CondGUID, @CurrencyGUID)  
    
		IF @Criteria <> ''    
		BEGIN    
			IF (RIGHT(@Criteria,4) = '<<>>')-- <<>> to Aknowledge Existing Custom Fields
			BEGIN
				SET @HaveCFldCondition = 1
				SET @Criteria = REPLACE(@Criteria, '<<>>', '')   
			END
				
			SET @Criteria = '(' + @Criteria + ')' 
		END  
	END    
	ELSE    
		SET @Criteria = ''    

	IF @HaveCFldCondition > 0    
	Begin    
		Declare @CF_Table NVARCHAR(255)    
		SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'py000') 	   
		SET @SQL = @SQL + ' INNER JOIN ' + @CF_Table + ' ON py.pyGuid = ' + @CF_Table + '.Orginal_Guid '    
	End

	SET @SQL = @SQL + '	WHERE 1 = 1 '    
	IF @Criteria <> ''    
		SET @SQL = @SQL + ' AND (' + @Criteria + ')'
		  
	EXEC (@SQL)  
################################################################################
#END

