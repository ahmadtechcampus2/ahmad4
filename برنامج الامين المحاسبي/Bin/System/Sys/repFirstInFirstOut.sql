############################################################################################
CREATE PROCEDURE repFirstInFirstOut
	@StartDate 	[DATETIME],
	@EndDate	[DATETIME],
	@MatGUID 	[UNIQUEIDENTIFIER],
	@GroupGUID 	[UNIQUEIDENTIFIER],
	@StoreGUID  [UNIQUEIDENTIFIER],
	@CostGUID 	[UNIQUEIDENTIFIER],
	@SrcTypesguid	[UNIQUEIDENTIFIER],
	@CurrencyGUID 	[UNIQUEIDENTIFIER],
	@UseUnit 	[INT],
	@Update		[INT] = 0,
	@Factor		[FLOAT] = 1,
	@MatType	[INT] = 1,
	@MatCondGuid	[UNIQUEIDENTIFIER] = 0X00
AS
	SET NOCOUNT ON
	--DECLARE VARIABLE
	IF @Update = 1
	BEGIN
		SET @UseUnit = 0
		SELECT @CurrencyGUID = [Guid] FROM [my000] WHERE [CurrencyVal] =1
	END
	DECLARE @biQty1 [FLOAT],@biQty2 [FLOAT],@biQty3 [FLOAT],@Qnt [FLOAT],@Qnt2 [FLOAT],@Price [FLOAT],@MatPtr [UNIQUEIDENTIFIER]
	DECLARE @Id [INT],@Id1 [INT],@Id2 [INT]
	DECLARE @UserId [UNIQUEIDENTIFIER],@Admin [INT],@InSrc [INT]
	DECLARE @BillGuid [UNIQUEIDENTIFIER],@bDate AS [DATETIME],@Unity AS [INT],@StorePtr [UNIQUEIDENTIFIER]
	DECLARE @I [INT],@BuGuid [UNIQUEIDENTIFIER],@BtGuid	[UNIQUEIDENTIFIER],@ExpireDate AS [DATETIME]
	DECLARE @CurrencyPtr [UNIQUEIDENTIFIER], @CurrencyVal [FLOAT], @CostPtr [UNIQUEIDENTIFIER]
	
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER])
	CREATE TABLE [#BillsTypesTbl2]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER])  
	CREATE TABLE [#StoreTbl](	[StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#TS] ([OutGUID] [UNIQUEIDENTIFIER],[InGUID] [UNIQUEIDENTIFIER])
	CREATE TABLE [#NEWBItem](
				[ID]			[INT] IDENTITY(1,1),
				[IID]			[INT],
				[bItemGuid]		[UNIQUEIDENTIFIER],
				[billGuid]		[UNIQUEIDENTIFIER],
				[MatPtr]		[UNIQUEIDENTIFIER],
				[Qty]			[FLOAT],
				[Price]			[FLOAT],
				[BillUnit]		[INT],
				[bDate]			[DATETIME],
				[StorePtr]		[UNIQUEIDENTIFIER],
				[ExpireDate]	[DATETIME],
				[CurrencyGuid]	[UNIQUEIDENTIFIER] ,
				[CurrencyVal]	[FLOAT],
				[biCostPtr]		[UNIQUEIDENTIFIER]
				)  
	
	
	--Filling temporary tables 
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 			@MatGUID, @GroupGUID ,@MatType,@MatCondGuid
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList] 	0X0--, @UserGuid
	INSERT INTO [#BillsTypesTbl2]	EXEC [prcGetBillsTypesList] 	@SrcTypesguid--, @UserGuid  
	
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 		@StoreGUID 
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID 
	

	CREATE TABLE [#RESULT]
	(
		[ID] 				[INT] IDENTITY(1,1),
		[buGuid]			[UNIQUEIDENTIFIER],
		[biGuid]			[UNIQUEIDENTIFIER],
		[btGuid]			[UNIQUEIDENTIFIER],
		[MatPtr] 			[UNIQUEIDENTIFIER],
		[biStorePtr]		[UNIQUEIDENTIFIER] ,
		[CurrencyGuid]		[UNIQUEIDENTIFIER] ,
		[CurrencyVal]		[FLOAT],
		[buDate]			[DATETIME],
		[biQty]				[FLOAT] DEFAULT 0,
		[biExpireDate]		[DATETIME] DEFAULT '1/1/1980',
		[biBounus]			[FLOAT] DEFAULT 0,
		[FixedBiPrice] 		[FLOAT] DEFAULT 0,
		[FixedBiDisk] 		[FLOAT] DEFAULT 0,
		[FixedBiExtra] 		[FLOAT] DEFAULT 0,
		[BuDirection]		[INT],
		[FixedBiCostPrice]	[FLOAT] DEFAULT 0,
		[MatSecurity] 		[INT],
		[Security]			[INT], 
		[UserSecurity] 		[INT],
		[NegOut]			[INT] DEFAULT 0,
		[buSortFlag]		[INT],
		[buNumber]			[FLOAT],
		[biNumber]			[FLOAT],
		[buTypeName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[biQty1] 			[FLOAT] DEFAULT 0,
		[Unity]				[INT],
		[biCostPtr]			[UNIQUEIDENTIFIER]
	)
	
	SELECT [mt].[MatGUID] AS [MatGUID],[mtdefUnitFact],[mtunit2Fact],[mtunit3Fact],[mt].[mtSecurity] AS [mtSecurity] INTO [#MatTbl2] FROM  [#MatTbl]  AS [mt] INNER JOIN [vwmt] AS [mt1] ON [mt1].[mtGUID] = [mt].[MatGUID]
	IF (@CostGUID = 0X00)
		INSERT INTO [#CostTbl] VALUES(0X00,0)
	INSERT INTO [#RESULT]
	([buGuid],[biGuid],[MatPtr],[biStorePtr],[buDate],[biQty],[biExpireDate],
	[biBounus],[FixedBiPrice],[FixedBiDisk],[FixedBiExtra],[BuDirection],
	[MatSecurity],[Security],[UserSecurity],[buSortFlag],[buNumber],[biNumber]
	,[buTypeName],[btGuid],[biQty1],[Unity],[CurrencyGuid],[CurrencyVal]
	,[biCostPtr])		
		SELECT 
			[buGuid],
			[biGuid],
			[bi].[biMatPtr],
			[bi].[biStorePtr],
			[buDate],
			CASE @UseUnit 
				WHEN 0 THEN [bi].[biQty]
				WHEN 1 THEN   [bi].[biQty] / CASE [mt].[mtunit2Fact] WHEN 0 THEN 1 ELSE [mt].[mtunit2Fact] END 
				WHEN 2 THEN [bi].[biQty] / CASE [mt].[mtunit3Fact] WHEN 0 THEN 1 ELSE [mt].[mtunit3Fact] END  
				ELSE [bi].[biQty] / [mt].[mtdefUnitFact]
			END,
			[bi].[biExpireDate],
			CASE @UseUnit 
				WHEN 0 THEN [bi].[biBonusQnt]
				WHEN 1 THEN CASE [mt].[mtunit2Fact] WHEN 0 THEN 0 ELSE [bi].[biBonusQnt]/[mt].[mtunit2Fact]  END
				WHEN 2 THEN CASE [mt].[mtunit3Fact] WHEN 0 THEN 0 ELSE [bi].[biBonusQnt]/[mt].[mtunit3Fact]  END
				ELSE [bi].[biBonusQnt]/[mt].[mtdefUnitFact] 
			END,
			CASE WHEN [bt].[UserReadPriceSecurity] >= [bi].[buSecurity] THEN 1 ELSE 0 END * CASE [bi].[btAffectCostPrice] WHEN 0 THEN 0 ELSE [FixedBiPrice]/[MtUnitFact]*([bi].[biQty] +[biBonusQnt]) END,
			CASE WHEN [bt].[UserReadPriceSecurity] >= [bi].[buSecurity] THEN 1 ELSE 0 END * CASE [bi].[btDiscAffectCost] WHEN 0 THEN 0 ELSE ([bi].[FixedBuTotalDisc] - [bi].[FixedBuItemsDisc])*([bi].[biQty] +[biBonusQnt])*  [bi].[FixedBiPrice]/[MtUnitFact] /(CASE [bi].[FixedBuTotal] WHEN 0 THEN 1 ELSE [FixedBuTotal] END) +[FixedBiDiscount] END,
			CASE WHEN [bt].[UserReadPriceSecurity] >= [bi].[buSecurity] THEN 1 ELSE 0 END * CASE [bi].[btExtraAffectCost] WHEN 0 THEN 0 ELSE [bi].[FixedBuTotalExtra]*([bi].[biQty] + [biBonusQnt])*  [bi].[FixedBiPrice]/[MtUnitFact] /(CASE [bi].[FixedBuTotal] WHEN 0 THEN 1 ELSE [FixedBuTotal] END) END,
			[buDirection],
			[mt].[mtSecurity],
			[bi].[buSecurity],
			[bt].[UserSecurity],
			[buSortFlag],
			[buNumber],
			[biNumber],
			[bi].[btAbbrev],
			[bi].[buType],
			[bi].[biQty],
			[bi].[biUnity],
			[biCurrencyPtr],
			[biCurrencyVal],
			[biCostPtr] 
			
		FROM 
			[fnExtended_bi_Fixed](@CurrencyGUID) AS [bi]
			INNER JOIN [#MatTbl2] AS [mt] ON [mt].[MatGUID] = [bi].[biMatPtr]
			INNER JOIN [#BillsTypesTbl] AS [bt] ON [bt].[TypeGuid] = [bi].[buType]
			INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [bi].[biStorePtr]	
			INNER JOIN [#CostTbl] AS [co] ON [co].[CostGUID] = [bi].[biCostPtr]
		WHERE 
				([buDate] <= @EndDate )
				AND [buIsPosted] = 1
		ORDER BY
			[biMatPtr],
			[buDate],
			[buSortFlag],
			[buNumber],
			[buGuid],
			[biNumber]
	
			
	CREATE CLUSTERED INDEX [RESULTINDEX] ON [#Result] ([ID])
	CREATE  INDEX [RESULTDIRECTION] ON [#Result] ([BuDirection])
	SELECT *,[biQty] + [biBounus] AS [biQnt]  INTO [#IN_RESULT] FROM [#Result] WHERE [BuDirection] = 1 
	CREATE  CLUSTERED INDEX [RESULTININDEX] ON [#IN_RESULT] ([ID])
		
	SET @Id = 1
	SET @Id2 = 1
	SET @BuGuid = 0X0
	WHILE @Id <> 0 
	BEGIN	
		SET @Id = 0 
		SELECT @Id =[ID] ,@Qnt2 = [biQty] + [biBounus],@MatPtr = [MatPtr]
		,@BillGuid = [buGuid],@BtGuid = [btGuid],@bDate =[BuDate],@Unity = [Unity] ,@StorePtr = [biStorePtr],@CurrencyPtr =[CurrencyGuid],@CurrencyVal = [CurrencyVal],@CostPtr = [biCostPtr]  
		FROM  [#Result] WHERE [ID] = (SELECT MIN(ID) FROM [#RESULT]  WHERE [BuDirection] = -1 AND [id] >= @Id2)  
		IF @UPDATE = 1
		BEGIN
			IF EXISTS(SELECT * FROM [#BillsTypesTbl2] WHERE [TypeGuid] = @BtGuid)
				SET @InSrc  = 1
			ELSE
				SET @InSrc  = 0
		END
		IF @Id = 0 
			BREAK
		SET @Id2 = @Id 
		IF @BuGuid <> @BillGuid
		BEGIN
			SELECT  @I = ISNULL(MAX([IID]),0) FROM [#NEWBItem] WHERE [billGuid] = @BillGuid
			SET @BuGuid = @BillGuid 
		
		END
		WHILE @Qnt2 > 0 
		BEGIN 
			SET @I =@I + 1
			SET @ID1 = 0
			SELECT  @ID1 = [ID],@biQty3 = [biQty]+ [biBounus],@biQty2 = [biQnt],@Price = [FixedBiPrice] - [FixedBiDisk] + [FixedBiExtra] ,@ExpireDate = [biExpireDate]
			FROM [#IN_RESULT]
			WHERE [ID] = (SELECT MIN([ID]) FROM [#IN_RESULT]  WHERE [MatPtr] = @MatPtr AND  [biQnt] > 0 AND @StorePtr = [biStorePtr]) 
			IF @Id1 > @Id OR @ID1 = 0
			BEGIN
				UPDATE [#Result] SET [NegOut] = 1 WHERE [ID] = @Id
				IF @UPDATE = 1 
				BEGIN
					SELECT 'NegOut' AS [NegOut]
					RETURN
				END
			END
			IF @ID1 = 0
				BREAK
			IF @Qnt2 >= @biQty2
			BEGIN
				IF @UPDATE = 1 AND @InSrc = 1 AND	@bDate BETWEEN @StartDate AND @EndDate 
					INSERT INTO [#NEWBItem] ([IID],[bItemGuid],[billGuid] ,[MatPtr],[Qty],[Price],[BillUnit],[bDate],[StorePtr],[ExpireDate],[CurrencyGuid],[CurrencyVal],[biCostPtr])  
						VALUES(@I,NEWID(),@BillGuid,@MatPtr,@biQty2,@Price/CASE @biQty3 WHEN 0 THEN 1 ELSE @biQty3 END,@Unity,@bDate,@StorePtr,@ExpireDate,@CurrencyPtr,@CurrencyVal,@CostPtr)
				SET @Qnt2 = @Qnt2 - @biQty2
				UPDATE [#Result] SET [FixedBiCostPrice] = [FixedBiCostPrice] + @Price/CASE @biQty3 WHEN 0 THEN 1 ELSE @biQty3 END * @biQty2 WHERE [ID] = @Id
				SET @Qnt = 0
			END
			ELSE
			BEGIN
				IF @UPDATE = 1 AND @InSrc = 1 AND	@bDate BETWEEN @StartDate AND @EndDate
						INSERT INTO  [#NEWBItem] ([IID],[bItemGuid],[billGuid] ,[MatPtr],[Qty],[Price],[BillUnit],[bDate],[StorePtr],[ExpireDate],[CurrencyGuid],[CurrencyVal],[biCostPtr])  
							VALUES(@I,NEWID(),@BillGuid,@MatPtr,@Qnt2,@Price/CASE @biQty3 WHEN 0 THEN 1 ELSE @biQty3 END,@Unity,@bDate,@StorePtr,@ExpireDate,@CurrencyPtr,@CurrencyVal,@CostPtr)
				UPDATE [#Result] SET [FixedBiCostPrice] = [FixedBiCostPrice] + @Price/CASE @biQty3 WHEN 0 THEN 1 ELSE @biQty3 END * @Qnt2 WHERE [ID] = @Id
				
				SET @Qnt = @biQty2 - @Qnt2
				SET @Qnt2 = 0
				
									
			END
			UPDATE [#IN_RESULT] SET [biQnt] =  @Qnt WHERE [ID] = @Id1
			
		END
		SET @Id2 = @Id + 1
		
	END
	
	IF (@Update = 1)
	BEGIN
		DECLARE @Guid1 [UNIQUEIDENTIFIER],@Guid2 [UNIQUEIDENTIFIER]
		CREATE TABLE [#TT] ([InType] [UNIQUEIDENTIFIER] ,[OutType] [UNIQUEIDENTIFIER])
		SELECT [SortNum] INTO [#BTSN] FROM [BT000] AS [bt] INNER JOIN [#BillsTypesTbl2] AS [bt2] ON [bt].[Guid] = [bt2].[TypeGuid] INNER JOIN [#RESULT] ON [btGuid] = [bt2].[TypeGuid] 
		IF EXISTS (SELECT * FROM [#BTSN] WHERE [SortNum] = 4) 
		BEGIN
			INSERT INTO [#BillsTypesTbl2] SELECT [GUID], 3, 3 FROM [BT000] WHERE [SortNum] = 3 
			SELECT @Guid1 = [GUID] FROM [BT000] WHERE [SortNum] = 3 AND [TYPE] = 2
			SELECT @Guid2 = [GUID] FROM [BT000] WHERE [SortNum] = 4 AND [TYPE] = 2
			INSERT INTO [#TT] VALUES(@Guid1,@Guid2)
		END
		IF EXISTS (SELECT * FROM [#BTSN] WHERE [SortNum] = 8) 
		BEGIN
			INSERT INTO [#BillsTypesTbl2] SELECT [GUID], 3, 3 FROM [BT000] WHERE [SortNum] = 7
			SELECT @Guid1 = [GUID] FROM [BT000] WHERE [SortNum] = 7 AND [TYPE] = 2
			SELECT @Guid2 = [GUID] FROM [BT000] WHERE [SortNum] = 8 AND [TYPE] = 2
			INSERT INTO [#TT] VALUES(@Guid1,@Guid2)
		END
		INSERT INTO [#BillsTypesTbl2] SELECT [bt].[GUID], 3, 3 FROM [BT000] AS [bt] INNER JOIN [TT000] ON [InTypeGuid] = [bt].[GUID] INNER JOIN [#BillsTypesTbl2] AS [bt2] ON [OutTypeGuid] = [bt2].[TypeGuid]
		SELECT [bu].[Guid], [bu].[Number], [bu].[Branch], [tt].[InType] 
		INTO [#TS1]
		FROM [bu000] AS [bu] INNER JOIN [#TT] AS [tt] ON  [tt].[OutType] = [bu].[TypeGuid]
		INNER JOIN [#RESULT] AS [r] ON [r].[buGuid] = [bu].[Guid]

		SELECT [bu].[Guid], [bu].[Number], [bu].[Branch], [tt].[InType]
		INTO [#TS2]
		FROM [bu000] AS [bu] INNER JOIN [#TT] AS [tt] ON  [tt].[InType] = [bu].[TypeGuid]
		INNER JOIN [#RESULT] AS [r] ON [r].[buGuid] = [bu].[Guid] 

		INSERT INTO [#TS] 
			SELECT DISTINCT [ts1].[GUID], [ts2].[Guid]
			FROM [#TS1] AS [ts1] INNER JOIN [#TS2] AS [ts2] ON  [ts1].[Number] = [ts2].[Number] AND [ts1].[Branch] = [ts2].[Branch] AND [ts1].[InType] = [ts2].[InType]
		SELECT DISTINCT [buGuid], [biStorePtr] INTO [#REULT2] FROM [#RESULT]	
		INSERT INTO [#TS] SELECT DISTINCT [OutBillGuid], [InBillGuid] FROM [TS000] INNER JOIN [#RESULT] ON [InBillGuid] = [buGuid]
		INSERT INTO [#NEWBItem] 
			SELECT distinct [IID], NewId(), [ts].[InGUID], [bi].[MatPtr], [bi].[Qty],
				[bi].[Price], [bi].[BillUnit], [bi].[bDate], [r].[biStorePtr], [bi].[ExpireDate], [bi].[CurrencyGuid], [bi].[CurrencyVal], [bi].[biCostPtr]
			FROM [#NEWBItem] AS [bi]
			INNER JOIN [#TS] AS [ts] ON [ts].[OutGuid] = [billGuid]
			INNER JOIN [#REULT2] AS [r] ON [r].[buGuid] = [ts].[InGUID]
	END 
		
	IF @Update = 1
	BEGIN
		BEGIN TRAN
		SET @UserId = [dbo].[fnGetCurrentUserGUID]()
		SELECT @Admin = [bAdmin] FROM [US000] WHERE [GUID] = @UserId
 		IF @Admin = 0
 		BEGIN
			DELETE [#Result] WHERE [Security] > [dbo].[fnGetUserBillSec](@UserId, btGuid, 2)
			DELETE [#NEWBItem] FROM  [#NEWBItem] INNER JOIN [bu000] AS [bu] ON [billGuid] = [bu].[Guid] INNER JOIN [bt000] AS [bt] ON [bu].[TypeGuid] = [bt].[GUID]
			WHERE [bu].[Security] > [dbo].[fnGetUserBillSec](@UserId, [bt].[Guid], 2) 
		END
		
		EXEC prcDisableTriggers 'bi000'	
		EXEC prcDisableTriggers 'bu000'
		select distinct [biGuid] 
		INTO [#bi]
		FROM [bi000] AS [bi] 
		INNER JOIN [#Result] AS [r] ON [bi].[Guid] = [r].[biGuid] 
		INNER JOIN [#BillsTypesTbl2] AS [bt] ON [bt].[TypeGuid] = [r].[btGuid]
		WHERE [buDate] BETWEEN @StartDate AND @EndDate  
		

		DELETE [bi000] 
			FROM [bi000] AS [bi] 
			INNER JOIN [#bi] AS [r] ON [bi].[Guid] = [r].[biGuid] 
			
		INSERT INTO [bi000] ([Guid], [ParentGuid], [MatGuid], [Number], [Qty], [Price], [Unity], [StoreGuid], [ExpireDate], [CurrencyGUID], [CurrencyVal], [CostGuid])
			SELECT [bItemGuid], [billGuid], [MatPtr],
			(SELECT ISNULL(MAX([NUMBER]),0)+[IID] FROM [bi000] AS [a] WHERE [ParentGuid] = [billGuid])
			,[N].[Qty] ,[Price]* @Factor  *  CASE [BillUnit] WHEN 1 THEN 1 WHEN 2 THEN [Unit2Fact] ELSE [Unit3Fact] END,
			[BillUnit],[StorePtr], [ExpireDate], [N].[CurrencyGUID], [N].[CurrencyVal], [N].[biCostPtr]
			FROM [#NEWBItem] AS [N] INNER JOIN [mt000] AS [mt] ON  [MatPtr] = [mt].[GUID] ORDER BY [ID]
		SELECT [BILLIN],[BILLOUT],[INP].[ManGuid] AS [ManGuid]
		INTO #MANBILL
		FROM
			(SELECT [BILLGUID] AS [BILLIN],[ManGuid] FROM [MB000] WHERE  [TYPE] = 1) AS [INP]
		INNER JOIN	
			(SELECT [BILLGUID] AS [BILLOUT],[ManGuid] FROM [MB000] WHERE  [TYPE] = 0) AS [OUTP] 
		ON [INP].[ManGuid] = [OUTP].[ManGuid]
		IF EXISTS (SELECT [buGuid] FROM [#RESULT] WHERE [buGuid] IN ( SELECT [BILLOUT] FROM [#MANBILL] ))
		BEGIN
			SELECT SUM([ni].[Qty] *[Price] / CASE [ni].[Unity] WHEN 1 THEN 1 WHEN 2 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END ELSE CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END END* @Factor) AS [TPrice],[BILLIN],[BILLOUT],[ManGuid]
			INTO #MANBILL2
			FROM [bi000] AS [ni] INNER JOIN [#MANBILL] AS mb ON [ni].[ParentGuid] = [mb].[BILLOUT]
			INNER JOIN [mt000] AS [mt] ON  [ni].[MatGuid] = [mt].[GUID]
			GROUP BY [BILLIN],[BILLOUT],[ManGuid]
			
			SELECT [TPrice] +ISNULL((SELECT SUM([Extra] -[Discount]) FROM [mx000] WHERE [ParentGuid] = [mn].[Guid]),0)  AS [TPrice] ,[MatGuid],[BILLIN],[Percentage]
			INTO #MANBILL3
			FROM [#MANBILL2] AS [mb] 
			INNER JOIN [mn000] AS [mn] ON [mn].[guid] = [mb].[ManGuid]
			INNER JOIN [mi000] AS [mi] ON [mi].[ParentGuid] = [mn].[Guid]
			WHERE [mi].[Type] = 0
			
			SELECT  [b].[MatGuid],[Percentage]*[TPrice]/(CASE [bi].[Unity] WHEN 1 THEN 1 WHEN 2 THEN CASE [mt].[Unit2Fact] WHEN 0 THEN 1 ELSE [mt].[Unit2Fact] END ELSE CASE [mt].[Unit3Fact] WHEN 0 THEN 1 ELSE [mt].[Unit3Fact] END END * 100) AS [TPrice], SUM([bi].[Qty]) AS [Qty],[BILLIN]
			INTO #BILL
			FROM [#MANBILL3] AS [b]
			INNER JOIN [bi000] AS [bi] ON [bi].[MatGuid] = [b].[MatGuid] AND [BILLIN] = [bi].[ParentGuid]
			INNER JOIN [mt000] AS [mt] ON  [bi].[MatGuid] = [mt].[GUID]
			GROUP BY  [b].[MatGuid],[BILLIN],[bi].[Unity],[mt].[Unit2Fact],[mt].[Unit3Fact],[Percentage],[TPrice]
			
			UPDATE [bi000]
			SET [price] = [TPrice]/CASE [b].[Qty] WHEN 0 THEN 1 ELSE [b].[Qty] END
			FROM [bi000] AS [bi] 
			INNER JOIN [#BILL] AS [b] ON [bi].[MatGuid] = [b].[MatGuid] AND [b].[BILLIN] = [bi].[ParentGuid]
			INSERT INTO [#BillsTypesTbl2] SELECT [GUID], 3, 3 FROM [BT000] WHERE [SortNum] = 5
		END
		--EXEC [prcCheckDB_bu_Sums] 1
			--EXEC prcBill_rePost
		IF @Admin = 0
 				DELETE [#Result] WHERE [Security] > [dbo].[fnGetUserBillSec](@UserId, [btGuid], 5) AND [buGuid] NOT IN (SELECT [ParentGuid] FROM [er000])
		EXEC [rep_FiFoGenEntry] @StartDate,@EndDate
		
		IF (@Factor <> 1)	
			UPDATE [bi000] 
				SET [profits]  = [r].[Price]*(@Factor-1)* [r].[Qty]/ CASE [BillUnit] WHEN 2 THEN [mt].[Unit2Fact] WHEN 3 THEN [mt].[Unit3Fact] ELSE 1 END
			FROM [bi000] AS [bi] 
			INNER JOIN [#NEWBItem] AS [r] ON [bi].[Guid] = [r].[bItemGuid] INNER JOIN [mt000] AS [mt] ON [mt].[Guid] = [bi].[MatGuid]
		ELSE
			UPDATE [bi000] 
				SET [profits]  = 0
			FROM [bi000] AS [bi] 
			INNER JOIN [#NEWBItem] AS [r] ON [bi].[Guid] = [r].[bItemGuid]  	

		
		
		UPDATE [bu000] 
			SET [Profits] = (SELECT Sum([Profits]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bi].[GUID])
		FROM [bu000] AS [bi] 
		INNER JOIN [#Result] AS [r] ON [bi].[Guid] = [r].[buGuid] 
		WHERE [buDate] BETWEEN @StartDate AND @EndDate AND [buDirection] = -1
		EXEC prcEnableTriggers 'bi000'
		EXEC prcEnableTriggers 'bu000'

		COMMIT
	END
	IF @Update = 0
	BEGIN
		SELECT [buGuid],[biGuid],[MatPtr],[buDate],
			[biQty],[biBounus],	[NegOut],mt.mtName,mt.mtCode,buTypeName
			,FixedBiCostPrice,buNumber
		FROM #Result AS r INNER JOIN vwMt AS mt ON MatPtr=mt.mtGuid 
		INNER JOIN #BillsTypesTbl2 AS bt ON bt.TypeGuid = r.btGuid  
		WHERE buDate BETWEEN @StartDate AND @EndDate AND BuDirection = -1 	
		ORDER BY buDate,buSortFlag,buNumber,buGuid,biNumber

		SELECT * FROM [#SecViol]
	END
	ELSE
		SELECT [buGuid],[btGuid] 
		FROM [#Result] AS [r] INNER JOIN [#BillsTypesTbl2] AS [bt] ON [bt].[TypeGuid] = [r].[btGuid] 
		WHERE [buDate] BETWEEN @StartDate AND @EndDate  
		
/*
prcConnections_add2 '„œÌ—'
*/
############################################################################################
CREATE PROCEDURE rep_FiFoGenEntry
	@StartDate 	[DATETIME],
	@EndDate	[DATETIME]
AS
	DECLARE	
		@c CURSOR,
		@g [UNIQUEIDENTIFIER],
		@n [INT]
		
	EXEC prcDisableTriggers 'ce000'
	ALTER TABLE [ce000] ENABLE TRIGGER [trg_ce000_delete] -- necessary for er000 handling
	EXEC prcDisableTriggers 'en000'
	EXEC prcDisableTriggers 'bu000'
	EXEC prcDisableTriggers 'bi000'
	EXEC prcDisableTriggers 'mt000'
	EXEC prcDisableTriggers 'ms000'
	UPDATE [bu] SET [IsPosted] = 0 
	FROM [bu000] AS [bu] INNER JOIN [#result] AS [r] ON [r].[buGUID] = [bu].[GUID] 
	INNER JOIN [#BillsTypesTbl2] AS [bt1] ON [bt1].[TypeGuid] = [r].[btGuid] AND [buDate] BETWEEN @StartDate AND @EndDate
	
	SET @c = CURSOR FAST_FORWARD FOR
	SELECT [Guid]
	FROM [bu000]  AS [bu] INNER JOIN [#result] AS [r] ON [r].[buGUID] = [bu].[GUID] 
	INNER JOIN [#BillsTypesTbl2] AS [bt1] ON [bt1].[TypeGuid] = [r].[btGuid]  AND [buDate] BETWEEN @StartDate AND @EndDate
	
	OPEN @c FETCH FROM @c INTO @g
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC [prcBill_Post]  @g,1
		FETCH FROM @c INTO @g
	END
	CLOSE @c 
	UPDATE [bu] SET [IsPosted] = 1
	FROM [bu000] AS [bu] INNER JOIN [#result] AS [r] ON [r].[buGUID] = [bu].[GUID] 
	INNER JOIN [#BillsTypesTbl2] AS [bt1] ON [bt1].[TypeGuid] = [r].[btGuid] AND [buDate] BETWEEN @StartDate AND @EndDate
	SELECT SUM([BuDirection]*[biQty]) AS [Qty] ,[MatPtr] INTO [#MMT]
	FROM [#result] AS [r]
	INNER JOIN [#BillsTypesTbl2] AS [bt1] ON [bt1].[TypeGuid] = [r].[btGuid] AND [buDate] BETWEEN @StartDate AND @EndDate
	GROUP BY [MatPtr]
	UPDATE [mt] SET [Qty] = [mt].[Qty] -  [m].[Qty] FROM [mt000] AS [mt] INNER JOIN [#MMT] AS [m] ON [mt].[Guid] = [m].[MatPtr]
	SET @c = CURSOR FAST_FORWARD FOR
		SELECT [r].[buGUID], ISNULL([bu].[ceNumber], 0)
		FROM [#Result] AS [r] LEFT JOIN [vwBuCe] AS [bu] ON [r].[buGUID] = [bu].[buGUID]
		INNER JOIN bt000 AS bt ON r.btGuid = bt.Guid
		INNER JOIN [#BillsTypesTbl2] AS [bt1] ON [bt1].[TypeGuid] = [r].[btGuid]  
		WHERE [r].[buDate] BETWEEN @startDate AND @endDate 
			AND( ([bt].[bNoEntry] = 0
			AND [bt].[bAutoEntry] = 1) OR (ISNULL([bu].[ceNumber],0)<>0))
		ORDER BY [bu].[buSortFlag], [bu].[buDate], [bu].[buNumber]
	
	OPEN @c FETCH FROM @c INTO @g, @n
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC [prcBill_GenEntry] @g, @n
		FETCH FROM @c INTO @g, @n
	END
	CLOSE @c 
	DEAllOCATE @c
	
	EXEC [prcEntry_rePost]
	--UPDATE [mt] FROM [mt000] AS [mt] INNER JOIN [bi000]
	EXEC prcEnableTriggers 'ce000'
	EXEC prcEnableTriggers 'en000'
	EXEC prcEnableTriggers 'bu000'
	EXEC prcEnableTriggers 'bi000'
	EXEC prcEnableTriggers 'ms000'
	EXEC prcEnableTriggers 'mt000'
############################################################################################
#END