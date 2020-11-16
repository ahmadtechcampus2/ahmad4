#########################################################
CREATE  VIEW vwNgNiMt
AS 
	SELECT 
		[ng].[ngGUID], 
		[ng].[ngNumber], 
		[ng].[ngMatGUID], 
		[ng].[ngStoreGUID],		 
		[ng].[ngPrice], 
		[ng].[ngNotes], 
		[ng].[ngPrepareTime],
		[ni].[niNumber], 
		[ni].[niGUID], 
		[ni].[niParent], 
		[ni].[niMatGUID], 
		[ni].[niQty], 
		[ni].[niUnity], 
		[ni].[niNotes], 
		[mt].[mtName], 
		[mt].[mtLatinName], 
		[mt].[mtCode], 
		[mt].[mtAvgPrice], 
		[mt].[mtLastPrice], 
		[mt].[mtGroup] 
	FROM  
		[vwNg] AS [ng] INNER JOIN [vwNi] AS [ni] ON [ng].[ngGUID] = [ni].[niParent] 
		INNER Join [vwMt] AS [mt] ON [ni].[niMatGUID] = [mt].[mtGUID] 

#########################################################
#END