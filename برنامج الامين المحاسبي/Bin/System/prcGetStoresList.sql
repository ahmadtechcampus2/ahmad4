#########################################################
CREATE PROCEDURE prcGetStoresList
	@StoreGUID UNIQUEIDENTIFIER,
	@ConditionGUID UNIQUEIDENTIFIER = 0x0
AS
	SET NOCOUNT ON
	DECLARE @Sql NVARCHAR(max),
			@Criteria NVARCHAR(max)
			
	SET @Sql = ' SELECT	[fn].[GUID],
						[st].[stSecurity] AS [Security]
				 FROM
				 [dbo].[fnGetStoresList]( ''' +  + CAST(@StoreGUID AS NVARCHAR(50)) + ''' ) AS [fn] 
				 INNER JOIN [vwst] AS [st] ON [fn].[GUID] = [st].[stGUID] 
				 LEFT JOIN [vwst] AS [Parent] ON [Parent].[stGuid] = [st].[stParent] '
	
	IF ISNULL(@ConditionGUID,0X0) <> 0X0
	BEGIN  
		SET @Criteria = [dbo].fnGetStoreConditionString(@ConditionGUID, '')
		IF @Criteria <> ''  
			SET @Criteria = '(' + @Criteria + ')'  
	END
	ELSE  
		SET @Criteria = '' 
	
	SET @SQL = @SQL + ' WHERE 1 = 1 '  
	IF @Criteria <> ''  
		SET @SQL = @SQL + 'AND ' + '(' + @Criteria + ')'   
	
	EXEC (@Sql)
#########################################################
#END