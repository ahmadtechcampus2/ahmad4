############################################################## 
CREATE PROCEDURE repTrnStoreMove
	@OldStGuid	[UNIQUEIDENTIFIER],
	@NewStGuid	[UNIQUEIDENTIFIER],
	@StartDate	[DATETIME],
	@EndDate	[DATETIME],
	@SrcGuid	[UNIQUEIDENTIFIER],
	@Posted		[INT] = -1,
	@CheckPrice	[BIT] =0
AS 
	SET NOCOUNT ON
	DECLARE @TrnInCnt [INT],@TrnOutCnt [INT]

	CREATE TABLE [#BILL]
	(
		[Id] INT IDENTITY(1,1),
		[biGuid] [UNIQUEIDENTIFIER],
		[buGuid] [UNIQUEIDENTIFIER],
		[buDate] [DATETIME],
		[buType] [UNIQUEIDENTIFIER],
		[buNumber] [FLOAT],
		[isPosted] [INT],
		[biStorePtr]  [UNIQUEIDENTIFIER],
		[buStorePtr]  [UNIQUEIDENTIFIER]
	)
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER]) 
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList] @SrcGuid
	SELECT [TypeGuid] , [UserSecurity], [UserReadPriceSecurity],[bShortEntry]  INTO [#BillsTypesTbl2] FROM [#BillsTypesTbl] a INNER JOIN [bt000] b ON b.Guid = a.[TypeGuid]
	
	INSERT INTO  [#BILL] ([biGuid] ,[buGuid],[buDate],[buType],[buNumber],[isPosted],[buStorePtr],[biStorePtr] )
		SELECT [biGuid],[buGuid],[buDate],[buType],[buNumber],[buisPosted] ,[buStorePtr],[biStorePtr]
		FROM [vwbubi] AS [bu] INNER JOIN [#BillsTypesTbl2] AS [src] ON [src].[TypeGuid] = [bu].[buType]
		WHERE [buDate] BETWEEN @StartDate AND  @EndDate AND ([biStorePtr] = @OldStGuid OR [buStorePtr] = @OldStGuid)
		AND (@Posted = -1 OR [buisPosted] = @Posted)
		ORDER BY [buDate],[buSortFlag],[buNumber]
	BEGIN TRAN
	EXEC prcDisableTriggers	'bi000', 0
	UPDATE [bi] SET [StoreGuid] = @NewStGuid  FROM [bi000] AS [bi] INNER JOIN [#BILL] AS [bu] ON [bu].[biGuid] = [bi].[Guid] WHERE [biStorePtr] = @OldStGuid
	EXEC prcEnableTriggers 'bi000'
	EXEC prcDisableTriggers	'bu000', 0
	UPDATE [bu] SET [StoreGuid] = @NewStGuid  FROM [bu000] AS [bu] INNER JOIN [#BILL] AS [b] ON [b].[buGuid] = [bu].[Guid] WHERE [buStorePtr] = @OldStGuid
	EXEC prcEnableTriggers 'bu000'
	IF @CheckPrice = 1
		EXEC prcBill_rePost 1
	COMMIT	

	UPDATE MI000 SET [StoreGUID] = @NewStGuid WHERE ParentGUID = ANY (SELECT [GUID] 
																      FROM mn000 
																      WHERE [Date] BETWEEN @StartDate AND @EndDate)
											  AND StoreGUID = @OldStGuid

	UPDATE mn000 SET [inStoreGuid]  = @NewStGuid  WHERE [inStoreGuid]  = @OldStGuid AND [Date] BETWEEN @StartDate AND @EndDate
	UPDATE mn000 SET [OutStoreGUID] = @NewStGuid  WHERE [OutStoreGUID] = @OldStGuid AND [Date] BETWEEN @StartDate AND @EndDate

	SELECT  [buGuid],[buDate],[buType],[buNumber] FROM [#bill] GROUP BY [buGuid],[buDate],[buType],[buNumber] ORDER BY MAX([ID])
-- exec  [repTrnStoreMove] 'f9119615-776c-435f-8de9-c54b0f7e8e0c', '19dd8c94-94e6-4ba7-a7b1-b8fe4e3dac24', '10/31/2007', '11/1/2007', 'a5bba7b8-f3a2-4eea-81a4-62d7f29847d0', 1, 0
#################################################################
#END 