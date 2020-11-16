#########################################################
CREATE PROCEDURE prcGetCostsList
	@StartGUID [UNIQUEIDENTIFIER] = NULL,
	@CostCond  [UNIQUEIDENTIFIER] = 0x00
AS
/*
This procedure:
	- returns Costs numbers and security according to a given @GostPtr
	- rerurns all Costs if @CostPtr is not specified.
*/
	SET NOCOUNT ON
	DECLARE @Sql NVARCHAR(4000), @Criteria NVARCHAR(2000)
	SET @Sql = 'SELECT 
		--co.coNumber AS Number,
		[fn].[GUID],
		[co].[coSecurity] AS [Security]	  
	FROM
		[dbo].[fnGetCostsList](''' + CAST(@StartGUID AS NVARCHAR(36)) + ''') AS [fn] INNER JOIN [vwco] AS [co]
		ON [fn].[GUID] = [co].[coGUID] '
		
		IF @CostCond <> 0x00
		BEGIN
			SET @Criteria = [dbo].[fnGetCostConditionStr]('', @CostCond) 
			IF @Criteria <> ''   -- For Cost Custom Filed
			BEGIN
				IF RIGHT ( RTRIM (@Criteria) , 4 ) ='<<>>'
				BEGIN	
				SET @Criteria = REPLACE(@Criteria ,'<<>>','')		
					DECLARE @CFTableName NVARCHAR(255)
					Set @CFTableName = (SELECT CFGroup_Table From CFMapping000 Where Orginal_Table = 'co000' )
					SET @SQL = @SQL + ' INNER JOIN ['+ @CFTableName +'] ON [b].[Guid] = ['+ @CFTableName +'].[Orginal_Guid] '		
				END
				SET @Criteria = ' WHERE (' + @Criteria + ')' 
				SET @Sql = @Sql + @Criteria
			END
		END
		EXECUTE sp_executesql @Sql

#########################################################
CREATE PROCEDURE prcGetCostsListWithLevel
	@StartGUID [UNIQUEIDENTIFIER] = NULL,
	@Sorted [INT] = 0,
	@Level [INT] = 0
AS
/*
This procedure:
	- returns Costs numbers and security according to a given @GostPtr With Level And Path
	- rerurns all Costs if @CostPtr is not specified.
*/
	SET NOCOUNT ON
	
	SELECT 
		--co.coNumber AS Number,
		[fn].[GUID],
		[fn].[Level],
		[fn].[Path],
		[co].[coSecurity] AS [Security]	  
	FROM
		[dbo].[fnGetCostsListWithLevel](@StartGUID,@Sorted) AS [fn] INNER JOIN [vwco] AS [co]
		ON [fn].[GUID] = [co].[coGUID]
	WHERE @Level = 0 OR [fn].[Level] < @Level

#########################################################
#END