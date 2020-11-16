##############################################################
CREATE PROCEDURE prcCheckAllowNegativeOut
AS
	SET NOCOUNT ON;
	CREATE TABLE [#Mat] ( [mtGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	INSERT INTO [#Mat] EXEC [prcGetMatsList]  NULL, null,-1, null

	CREATE TABLE [#Temp](   
		[biNumber] [INT],  
		[mtGUID] [UNIQUEIDENTIFIER],  
		[biQty] [FLOAT],  
		[biBonusQnt] [FLOAT],  
		[btIsInput] [INT],   
		[btIsOutput] [INT],  
		[buIsPosted] [INT],
		[branchGuid] [UNIQUEIDENTIFIER],
		[biStoreGUID][UNIQUEIDENTIFIER]
		)
	INSERT INTO [#Temp]  
	SELECT  
		[Bill].[BiNumber],  
		[Bill].[biMatPtr],  
		[Bill].[biQty],  
		[Bill].[biBonusQnt],      
		[Bill].[btIsInput],  
		[Bill].[btIsOutput],  
		[Bill].[buIsPosted],
		[Bill].[buBranch],
		[Bill].[biStorePtr]
	FROM  
		[vwExtended_bi] AS [Bill]   
		INNER JOIN [#Mat] AS [mt] ON [Bill].[biMatPtr] = [mt].[mtGUID]  
 
	SELECT [mt].[mtGuid],  
				[mtName],  
				[mtCode],    
				[grName],  
				[mtUnity] [mtDefUnitName],  
				[mt].[mtDefUnitFact] [mtDefUnitFact]  
				INTO [#Mat2]  
				FROM [vwMtGr] mt INNER JOIN [#Mat] m ON m.[mtGUID] = mt.[mtGuid]  
	--//////////////////////////////////////////////////////////////////////////////
	SELECT
	[Bill].[mtGuid],
	[Bill].[branchGuid],
	SUM( [Bill].[btIsInput] * (( [biQty] + [biBonusQnt]) /  [mt].[mtDefUnitFact])) -
	SUM( [Bill].[btIsOutput] * (( [biQty] + [biBonusQnt]) / [mt].[mtDefUnitFact])) Balance
	FROM [#Temp] as [Bill]
	INNER JOIN [#Mat2]  [mt]  ON [Bill].[mtGuid] = [mt].[mtGUID] 
	WHERE [Bill].[buIsPosted] =1
	GROUP BY 
	[Bill].[mtguid], 
	[Bill].[biStoreGUID],
	[Bill].[branchGuid]
###########################################################
#END