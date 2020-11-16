##########################################################################
CREATE PROCEDURE prcDDEGetMatQntCost
	@MatName	[NVARCHAR](256),
	@CostCenterName	[NVARCHAR](256), 
	@StartDate	[DATETIME], 
	@EndDate	[DATETIME]
AS
	SET NOCOUNT ON	
	SELECT [GUID], @CostCenterName AS [Name]  INTO [#COST] FROM [co000] AS [co]  WHERE [co].[guid] in ( SELECT [co2].[GUID] FROM [CO000] AS [co2] INNER JOIN [CO000] AS [co1] ON [co2].[ParentGUID] = [co1].[GUID] AND [co1].[Name] = @CostCenterName ) OR [co].[name] = @CostCenterName  
	SELECT 
		SUM(([bu].[biQty] + [bu].[biBonusQnt]) * [bu].[buDirection] ) AS [Qty], 
		[mt].[name] AS [mtName], 
		[co].[name] AS [coName] 
	FROM  
		[vwExtended_bi] AS [bu]  
		INNER join [mt000] AS [mt] ON [mt].[guid] = [bu].[bimatptr]  
		INNER JOIN [#COST] AS [co] ON [co].[guid] = [bu].[biCostPtr] 
	WHERE 
		[mt].[name] = @MatName 
		AND [bu].[buDate] BETWEEN @StartDate AND @EndDate 
	GROUP BY 
		[mt].[name], 
		[co].[name]
		
######################################################################################
#END  
