##########################################################################
CREATE PROCEDURE prcDDEGetMatOutBonus
	@MatName	[NVARCHAR](256),
	@StoreName  [NVARCHAR](256),
	@StartDate	[DATETIME], 
	@EndDate	[DATETIME]
AS
	SET NOCOUNT ON
	SELECT [GUID], @StoreName AS [Name]  INTO [#STORE] FROM [st000] AS [st]  WHERE [st].[guid] in ( SELECT [st2].[GUID] FROM [st000] AS [st2] INNER JOIN [st000] AS [st1] ON [st2].[ParentGUID] = [st1].[GUID] AND [st1].[Name] = @StoreName ) OR [st].[name] = @StoreName  
	SELECT 
		SUM( [bu].[biBonusQnt])  AS [BounsQty], 
		 [mt].[name] AS [mtName]
	FROM  
		[vwExtended_bi] AS [bu]  
		INNER join [mt000] AS [mt] ON [mt].[guid] = [bu].[bimatptr]  
		INNER JOIN [#STORE] AS [st] ON [st].[guid] = [bu].[biStorePtr] 
	WHERE 
		[mt].[name] ='' OR  [mt].[name] = @MatName 
		AND [bu].[buDate] BETWEEN @StartDate AND @EndDate 
		AND [bu].[buDirection]  = -1
	GROUP BY 
		 [mt].[name] 
		
######################################################################################
#END 