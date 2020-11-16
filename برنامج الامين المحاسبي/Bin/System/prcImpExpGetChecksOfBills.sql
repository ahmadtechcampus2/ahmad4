################################################
CREATE PROCEDURE prcImpExpGetChecksOfBills
	@SrcGuid	[UNIQUEIDENTIFIER],
	@buDate		[BIT],
	@StartDate	[DATETIME],
	@EndDate	[DATETIME]
AS
	SELECT DISTINCT [nt].[Guid], [nt].[Name], [nt].[DefPayAccGuid], [nt].[DefRecAccGuid]--, [ch].[ParentGuid]
	FROM [nt000] AS [nt] 
	INNER JOIN [ch000] AS [ch] ON [nt].[Guid] = [ch].[TypeGuid]
	INNER JOIN [vwbu] AS [bu] ON  [ch].[ParentGuid]= [bu].[buGuid]
	INNER JOIN [RepSrcs] AS [r] ON [bu].[buType] = [r].[IdType]
	WHERE 
		(((@buDate = 0) AND ([buNumber] BETWEEN [r].[StartNum] AND [r].[EndNum])) OR ((@buDate = 1) AND ([buDate] BETWEEN @StartDate AND @EndDate)))
		AND (([r].[IdTbl] = @SrcGuid) OR ( ISNULL([r].[IdTbl],0X0) = 0X0))

################################################
#END