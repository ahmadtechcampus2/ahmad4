############################################################## 
CREATE PROCEDURE repTrnMatMove
	@OldMatGuid	[UNIQUEIDENTIFIER],
	@NewMatGuid	[UNIQUEIDENTIFIER],
	@StartDate	[DATETIME],
	@EndDate	[DATETIME],
	@SrcGuid	[UNIQUEIDENTIFIER],
	@Posted		[INT] = -1,
	@CheckPrice	[BIT] =0,
	@RegenerateBillEntries	[BIT]
AS 
	SET NOCOUNT ON
	DECLARE @Guid [UNIQUEIDENTIFIER], @Num [FLOAT], @TrnInCnt [INT], @TrnOutCnt [INT],	@mtUnit2Fact [FLOAT], @mtUnit3Fact [FLOAT], @mtOldUnit2Fact [FLOAT], @mtOldUnit3Fact [FLOAT], @SnFlag1 [BIT], @SnFlag2 [BIT], @ExpireFlag1 [BIT], @ExpireFlag2 [BIT]
	SELECT @SnFlag1 = [SnFlag],@ExpireFlag1 = [ExpireFlag], @mtOldUnit2Fact = [Unit2Fact], @mtOldUnit3Fact = [Unit3Fact] FROM [mt000] WHERE [Guid] = @OldMatGuid
	SELECT @mtUnit2Fact = [Unit2Fact], @mtUnit3Fact = [Unit3Fact],@SnFlag2 = [SnFlag],@ExpireFlag2 = [ExpireFlag] FROM [mt000] WHERE [Guid] = @NewMatGuid
	
	IF(@CheckPrice = 0 OR @RegenerateBillEntries = 1)
		BEGIN
			DECLARE	@c CURSOR
		END

	IF @ExpireFlag1 <> @ExpireFlag2
	BEGIN
		SELECT   -1 AS [buNumber] 
		RETURN
	END
	IF @SnFlag1= 1 OR @SnFlag2 = 1
	BEGIN
		SELECT   -2 AS [buNumber] 
		RETURN
	END
	CREATE TABLE [#BILL]
	(
		[Id] INT IDENTITY(1,1),
		[biGuid] [UNIQUEIDENTIFIER],
		[buGuid] [UNIQUEIDENTIFIER],
		[buDate] [DATETIME],
		[buType] [UNIQUEIDENTIFIER],
		[buNumber] [FLOAT],
		[isPosted] [INT],
		[State] [BIT],
		[bShortEntry]  [BIT]
	)
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER]) 
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList] @SrcGuid
	SELECT [TypeGuid] , [UserSecurity], [UserReadPriceSecurity],[bShortEntry]  INTO [#BillsTypesTbl2] FROM [#BillsTypesTbl] a INNER JOIN [bt000] b ON b.Guid = a.[TypeGuid]
	SELECT @TrnInCnt = COUNT(*) FROM [BT000] AS [tt] INNER JOIN [#BillsTypesTbl] AS [src] ON [src].[TypeGuid] = [tt].[GUID] WHERE TT.TYPE = 3
	SELECT @TrnOutCnt = COUNT(*) FROM [BT000] AS [tt] INNER JOIN [#BillsTypesTbl] AS [src] ON [src].[TypeGuid] = [tt].[GUID]  WHERE TT.TYPE = 4
	IF ( @TrnInCnt <> @TrnOutCnt)
	BEGIN
		SELECT   -3 AS [buNumber] 
		RETURN
	END
	INSERT INTO  [#BILL] ([biGuid] ,[buGuid],[buDate],[buType],[buNumber],[isPosted],[State],[bShortEntry] )
		SELECT [biGuid],[buGuid],[buDate],[buType],[buNumber],[buisPosted] ,CASE WHEN [biUnity] = 1 THEN 1 WHEN [biUnity] = 2 AND @mtUnit2Fact <> 0 THEN 1 WHEN [biUnity] = 3 AND @mtUnit3Fact <> 0 THEN 1 ELSE 0 END,[bShortEntry]
		FROM [vwbubi] AS [bu] INNER JOIN [#BillsTypesTbl2] AS [src] ON [src].[TypeGuid] = [bu].[buType]
		WHERE [buDate] BETWEEN @StartDate AND  @EndDate AND [biMatPtr] = @OldMatGuid
		AND (@Posted = -1 OR [buisPosted] = @Posted)
		ORDER BY [buDate],[buSortFlag],[buNumber]
	BEGIN TRAN
	EXEC prcDisableTriggers	'bi000', 0
	EXEC prcDisableTriggers	'ce000', 0
	UPDATE [bi] SET [MatGuid] = @NewMatGuid,
					[Price] = CASE	[Unity] WHEN 1 THEN Price
											WHEN 2 THEN Price / (CASE (@mtOldUnit2Fact * @mtUnit2Fact) WHEN 0 THEN 1 ELSE (@mtOldUnit2Fact * @mtUnit2Fact) END )
											ELSE Price / (CASE (@mtOldUnit3Fact * @mtUnit3Fact) WHEN 0 THEN 1 ELSE (@mtOldUnit3Fact * @mtUnit3Fact) END )
							  END 
	FROM [bi000] AS [bi] INNER JOIN [#BILL] AS [bu] ON [bu].[biGuid] = [bi].[Guid] WHERE [State] = 1
	EXEC prcEnableTriggers 'bi000'
	EXEC prcDisableTriggers	'mn000', 0
	UPDATE A SET matguid =@NewMatGuid
	FROM MI000 A INNER JOIN MN000 B ON A.PARENTGUID = B.GUID INNER JOIN MB000 C ON C.MANGUID = B.GUID
	INNER JOIN [#BILL] D ON [buGuid] = BILLGUID
	WHERE matguid = @OldMatGuid
	IF EXISTS( SELECT * FROM Repsrcs where IdTbl = @SrcGuid AND IdType = '5463594E-9AEE-4A01-841C-B3E67FEB51CC')
		UPDATE A SET matguid =@NewMatGuid
		FROM MI000 A INNER JOIN MN000 B ON A.PARENTGUID = B.GUID
		WHERE matguid = @OldMatGuid AND b.Type = 0
	EXEC prcEnableTriggers 'mn000'
	
	SELECT [EntryGuid], [buGuid], [Number]
	INTO [#er] 
	FROM [er000] AS [er] 
	INNER JOIN [#BILL] AS [bu] ON [bu].[buGuid] = [er].[ParentGuid] 
	INNER JOIN [ce000] AS [ce] ON [ce].[Guid] = [er].[EntryGuid] 
	WHERE [bu].[State] = 1 AND [bShortEntry] = 0 
	ORDER BY [ID]

	IF @RegenerateBillEntries = 1
		BEGIN
			UPDATE [ce] SET [isposted] = 0 FROM [CE000] AS [ce] INNER JOIN [#er] AS [er] ON [er].[entryGuid] = [ce].[Guid]
			DELETE [ce] FROM [CE000] AS [ce] INNER JOIN [#er] AS [er] ON [er].[entryGuid] = [ce].[Guid]
			DELETE [ce] FROM [ER000] AS [ce] INNER JOIN [#er] AS [er] ON [er].[entryGuid] = [ce].[entryGuid]
		END

	IF @CheckPrice = 1
		EXEC prcBill_rePost 1
	ELSE
	BEGIN
		EXEC prcDisableTriggers	'mt000', 0
		EXEC prcDisableTriggers	'ms000', 0
		SET @c = CURSOR FAST_FORWARD FOR
			SELECT [buGuid] FROM [#Bill] WHERE [isPosted] = 1 AND [State] = 1 ORDER BY [id]
		OPEN @c  FETCH FROM @c INTO @Guid
		WHILE @@FETCH_STATUS =0
		BEGIN
			EXEC [prcBill_post] @Guid,1  
		--	UPDATE [bu000] SET [isPosted] = 1 WHERE [GUID] = @Guid
			FETCH FROM @c INTO @Guid
		END
		CLOSE @c
		EXEC prcEnableTriggers 'mt000'
		EXEC prcEnableTriggers 'ms000'
	END

	IF @RegenerateBillEntries = 1
		BEGIN
			SET @c = CURSOR FAST_FORWARD FOR
			SELECT [buGuid], [Number] FROM [#er]  
			
			OPEN @c  FETCH FROM @c INTO @Guid, @Num
			WHILE @@FETCH_STATUS = 0
			BEGIN
				EXEC [prcBill_genEntry] @Guid, @Num
				FETCH FROM @c INTO @Guid, @Num
			END
			CLOSE @c
		END

		IF(@CheckPrice = 0 OR @RegenerateBillEntries = 1)
		BEGIN
				DEALLOCATE @c
		END
	EXEC prcEnableTriggers 'ce000' 
	COMMIT
	DELETE [#bill] WHERE [id] IN (SELECT MAX([ID]) FROM [#bill] GROUP BY [buGuid],[buDate],[buType],[buNumber],[State] HAVING COUNT(*) > 1) 
	SELECT [buGuid],[buDate],[buType],[buNumber],[State] FROM [#bill] ORDER BY [id]
	
/*
	prcConnections_add2 '„œÌ—'
 [repTrnMatMove] '9c721389-1154-44bb-9e5c-6dc66064bb76', '7ab14dd6-dc10-4294-9f64-0295f68d22f6', '1/1/2004', '12/31/2004', '1fd3e954-87d7-4769-9143-b151a51f95ac', 1, 0
*/
#################################################################
#END 