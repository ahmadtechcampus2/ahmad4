###########################################################################
CREATE PROC prcCollectCashBills
	@Src [UNIQUEIDENTIFIER], 
	@StartDate [DATETIME], 
	@EndDate [DATETIME], 
	@CustAccGuid [UNIQUEIDENTIFIER], 
	@MatAccGuid [UNIQUEIDENTIFIER], 
	@StoreGuid [UNIQUEIDENTIFIER], 
	@CostGuid [UNIQUEIDENTIFIER], 
	@CustGuid [UNIQUEIDENTIFIER], 
	@SalesManPtr [INT], 
	@Vendor [INT], 
	@ColctCustBills [INT], 
	@SecMerge [INT], 
	@MergDisc [INT], 
	@MergItem [INT]
	,@LgGuid UNIQUEIDENTIFIER=0x0
AS
	SET NOCOUNT ON
	--CREATE TABLE #T( i int, d DATETIME DEFAULT GetDate())
	--declare @item_i int 
	--set @item_i = 1
	--insert into #T(i) values( @item_i) --1
	
	CREATE TABLE [#Src]( [Type] [UNIQUEIDENTIFIER], [Sec] [INT], [ReadPrice] [INT])   
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList] @Src 
	DECLARE @Parms NVARCHAR(2000)
	EXEC  prcsetSrcStringLog @Parms OUTPUT

	SET @Parms = @Parms+ 'StartDate:' +  CAST(@StartDate AS NVARCHAR(100)) +CHAR(13)+ 'EndDate:' + CAST(@EndDate AS NVARCHAR(100)) + CHAR(13)
				+ 'CustAcc:' + ISNULL((SELECT Code + '-' + [Name] FROM ac000 WHERE  [Guid] = @CustAccGuid),'')
				+ 'MatAcc:' + ISNULL((SELECT Code + '-' + [Name] FROM ac000 WHERE  [Guid] = @MatAccGuid),'')
				+ 'Store:' + ISNULL((SELECT Code + '-' + [Name] FROM ST000 WHERE  [Guid] = @StoreGuid),'')
				+ 'Cost:' + ISNULL((SELECT Code + '-' + [Name] FROM ST000 WHERE  [Guid] = @CostGuid),'')
				+ 'Cust:'  + ISNULL((SELECT [CustomerName] FROM cu000 WHERE  [Guid] = @CostGuid),'')
				+ 'Sales:' + CAST(@SalesManPtr AS NVARCHAR(10))
				+ 'Vendor' + CAST(@Vendor AS NVARCHAR(10))
				+ 'ColctCustBi' + CAST(@ColctCustBills AS NVARCHAR(10))
				+ 'SecMerge' + CAST(@SecMerge AS NVARCHAR(10))
				+ 'MergDisc' + CAST(@MergDisc AS NVARCHAR(10))
				+ 'MergItem' + CAST(@MergItem AS NVARCHAR(10))

	--EXEC prcCreateMaintenanceLog 17,@LgGuid OUTPUT,@Parms  
	
	CREATE TABLE [#Bill](  
		[Guid] [UNIQUEIDENTIFIER],  
		[Branch] [UNIQUEIDENTIFIER], 
		[TypeGUID] [UNIQUEIDENTIFIER], 
		[CustGUID] [UNIQUEIDENTIFIER],  
		[Date] [DateTime], 
		[CustAccGuid] [UNIQUEIDENTIFIER], 
		[MatAccGuid] [UNIQUEIDENTIFIER], 
		[Vendor] [INT], 
		[SalesManPtr] [INT],  
		[CostGUID] [UNIQUEIDENTIFIER],  
		[UserGUID] [UNIQUEIDENTIFIER], 
		[StoreGUID] [UNIQUEIDENTIFIER], 
		[CurrencyGUID] [UNIQUEIDENTIFIER], 
		[CurrencyVal] [FLOAT], 
		[Security] [INT], 
		[BillNewGuid] [UNIQUEIDENTIFIER], 
		[BillCnt] [INT] DEFAULT 0) 
	INSERT INTO [#Bill]( 				 
		[Guid], 
		[Branch], 
		[TypeGUID], 
		[CustGUID], 
		[Date], 
		[CustAccGuid], 
		[MatAccGuid], 
		[Vendor], 
		[SalesManPtr], 
		[CostGUID], 
		[UserGUID], 
		[StoreGUID], 
		[CurrencyGUID], 
		[CurrencyVal], 
		[Security], 
		[BillNewGuid]) 
	SELECT 
		[bu].[Guid], 
		[bu].[Branch], 
		[bu].[TypeGUID], 
		CASE @CustGUID WHEN 0x0 THEN [bu].[CustGUID] ELSE @CustGUID END, 
		[bu].[Date], 
		CASE @CustAccGuid WHEN 0x0 THEN [bu].[CustAccGuid] ELSE @CustAccGuid END, 
		CASE @MatAccGuid WHEN 0x0 THEN [bu].[MatAccGuid] ELSE @MatAccGuid END, 
		CASE @Vendor WHEN 0 THEN [bu].[Vendor] ELSE @Vendor END, 
		CASE @SalesManPtr WHEN 0 THEN [bu].[SalesManPtr] ELSE @SalesManPtr END, 
		CASE @CostGUID WHEN 0x0 THEN [bu].[CostGUID] ELSE @CostGUID END, 
		[bu].[UserGUID], 
		CASE @StoreGUID WHEN 0x0 THEN [bu].[StoreGUID] ELSE @StoreGUID END, 
		[bu].[CurrencyGUID], 
		[bu].[CurrencyVal], 
		[bu].[Security], 
		0x0 
	FROM  
		[bu000] AS [bu]  
		INNER JOIN [#Src] AS [Src] ON [bu].[TypeGuid] = [Src].[Type] 
	WHERE 
		[bu].[Date] between @StartDate AND @EndDate 
		AND [bu].[PayType] = 0 
		AND ( ISNULL( [bu].[CustGUID], 0x0) = 0x0 OR @ColctCustBills = 1) 
	IF @@ROWCOUNT = 0  
		return 0 
	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --2

	DECLARE @Bill CURSOR, 
		@mGuid [UNIQUEIDENTIFIER],  
		@mBranch [UNIQUEIDENTIFIER], 
		@mTypeGUID [UNIQUEIDENTIFIER], 
		@mCustGUID [UNIQUEIDENTIFIER],  
		@mDate [DateTime], 
		@mCustAccGuid [UNIQUEIDENTIFIER], 
		@mMatAccGuid [UNIQUEIDENTIFIER], 
		@mVendor [INT], 
		@mSalesManPtr [INT],  
		@mCostGUID [UNIQUEIDENTIFIER],  
		@mUserGUID [UNIQUEIDENTIFIER], 
		@mStoreGUID [UNIQUEIDENTIFIER], 
		@mCurrencyGUID [UNIQUEIDENTIFIER], 
		@mCurrencyVal [FLOAT], 
		@mSecurity [INT], 
		@mType [INT], 
		@mCount [INT], 
		@mLoopRec [INT], 
		@mBillNewGuid [UNIQUEIDENTIFIER] 
	SET @mCount = 0
	SET @mLoopRec = 0
	SET @mBillNewGuid = 0x0 
	SET @Bill = CURSOR 
	FOR      
		SELECT      
			[bu].[Guid], 
			[bu].[Branch], 
			[bu].[TypeGUID], 
			[bu].[CustGUID], 
			[bu].[Date], 
			[bu].[CustAccGuid], 
			[bu].[MatAccGuid], 
			[bu].[Vendor], 
			[bu].[SalesManPtr], 
			[bu].[CostGUID], 
			[bu].[UserGUID], 
			[bu].[StoreGUID], 
			[bu].[CurrencyGUID], 
			[bu].[CurrencyVal], 
			[bu].[Security], 
			[bu].[BillNewGuid] 
		FROM      
			[#Bill] AS [bu] 
		WHERE  
			[BillNewGuid] = 0x0 
		ORDER BY 
			[bu].[Branch], 
			[bu].[TypeGUID], 
			[bu].[CustGUID], 
			[bu].[Date], 
			[bu].[CustAccGuid], 
			[bu].[MatAccGuid], 
			[bu].[Vendor], 
			[bu].[SalesManPtr], 
			[bu].[CostGUID], 
			[bu].[UserGUID], 
			[bu].[StoreGUID], 
			[bu].[CurrencyGUID], 
			[bu].[CurrencyVal], 
			[bu].[Security] 
	----------------------------------------------      
	
	OPEN @Bill FETCH NEXT FROM @Bill INTO  
			@mGuid, 
			@mBranch, 
			@mTypeGUID, 
			@mCustGUID, 
			@mDate, 
			@mCustAccGuid, 
			@mMatAccGuid, 
			@mVendor, 
			@mSalesManPtr, 
			@mCostGUID, 
			@mUserGUID, 
			@mStoreGUID, 
			@mCurrencyGUID, 
			@mCurrencyVal, 
			@mSecurity, 
			@mBillNewGuid

	SET @mCount = @@FETCH_STATUS 
		
	WHILE @mCount = 0        
	BEGIN   
		SET @mLoopRec = @mLoopRec + 1
		IF( @mBillNewGuid = 0x0) 
		BEGIN 
			SET @mBillNewGuid = @mGuid 
			UPDATE [#Bill] SET 
				[BillNewGuid] = @mBillNewGuid
			WHERE  
				[BillNewGuid] = 0x0 
				--AND Guid = @mGuid  
				AND [Branch] = @mBranch  
				AND [TypeGUID] = @mTypeGUID  
				AND [CustGUID] = @mCustGUID 
				AND [Date] = @mDate  
				AND [CustAccGuid] = @mCustAccGuid 
				AND [MatAccGuid] = @mMatAccGuid 
				AND [Vendor] = @mVendor  
				AND [SalesManPtr] = @mSalesManPtr  
				AND [CostGUID] = @mCostGUID  
				AND [UserGUID] = @mUserGUID  
				AND [StoreGUID] = @mStoreGUID  
				AND [CurrencyGUID] = @mCurrencyGUID  
				AND [CurrencyVal] = @mCurrencyVal  
				AND ( ( [Security] = @mSecurity) OR (@SecMerge = 1)) 
		END 

		FETCH NEXT FROM @Bill INTO  
					@mGuid, 
					@mBranch, 
					@mTypeGUID, 
					@mCustGUID, 
					@mDate, 
					@mCustAccGuid, 
					@mMatAccGuid, 
					@mVendor, 
					@mSalesManPtr, 
					@mCostGUID, 
					@mUserGUID, 
					@mStoreGUID, 
					@mCurrencyGUID, 
					@mCurrencyVal, 
					@mSecurity, 
					@mBillNewGuid 
		SET @mCount = @@FETCH_STATUS
	END 

	CLOSE @Bill
	DEALLOCATE @Bill

	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --3

	DECLARE @d int  
	SELECT @d = Count(*) FROM  [#Bill] Group By [BillNewGuid] HAVING Count(*)> 1 
	IF ( ISNULL( @d, 0) = 0) 
		return 0  
	
	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --4

	UPDATE [Bill] SET [Bill].[BillCnt] = [BCnt].[BillCnt]
	FROM  
		[#Bill] AS [Bill] INNER JOIN ( SELECT [BillNewGuid], COUNT( CAST([BillNewGuid] AS [NVARCHAR](100))) AS [BillCnt] FROM [#Bill] GROUP BY [BillNewGuid]) AS [BCnt] 
		ON [Bill].[BillNewGuid] = [BCnt].[BillNewGuid] 
	WHERE  
		[Bill].[Guid] = [Bill].[BillNewGuid] 

	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --5

	DELETE FROM [#Bill] WHERE [BillCnt] = 1 

	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --6

	EXEC prcDisableTriggers	'ce000'
	EXEC prcDisableTriggers	'en000'
	EXEC prcDisableTriggers	'er000'

	DELETE [en000] 
	FROM 
		[en000] as [en] 
		INNER JOIN [er000] AS [er] ON [er].[EntryGUID] = [en].[ParentGuid]
		INNER JOIN [#Bill] AS [bu] ON [bu].[Guid] = [er].[ParentGuid] 
	WHERE 
		[bu].[BillCnt] = 0

	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --7

	DELETE [ce000] 
	FROM 
		[ce000] AS [ce] 
		INNER JOIN [er000] AS [er] ON [ce].[Guid] = [er].[EntryGUID] 
		INNER JOIN [#Bill] AS [bu] ON [bu].[Guid] = [er].[ParentGuid]
	WHERE 
		[bu].[BillCnt] = 0


	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --8
	DELETE [er000] 
	FROM 
		[er000] AS [er] inner join [#Bill] AS [bu] ON [er].[ParentGuid] = [bu].[Guid]
	WHERE 
		[bu].[BillCnt] = 0

	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --9

	--EXEC prcEnableTriggers	'ce000'
	EXEC prcEnableTriggers	'en000'
	EXEC prcEnableTriggers	'er000'
	EXEC prcDisableTriggers	'bu000'
	EXEC prcDisableTriggers	'bi000'
	EXEC prcDisableTriggers	'di000'

	INSERT INTO MaintenanceLogItem000 ( GUID, ParentGUID, Severity, LogTime, ErrorSourceGUID1, ErrorSourceType1, Notes)
	SELECT NEWID(), @LgGuid, 0x0001,GETDATE(),[BillNewGuid],268500992,bt.Name +':' +CAST(bu.Number AS NVARCHAR(10)) + '-' + CAST(bu2.Number AS NVARCHAR(10)) + CAST(bu.Date AS NVARCHAR(10))  FROM [#Bill] b 
	INNER JOIN bu000 bu ON b.Guid = bu.Guid
	INNER JOIN bt000 bt on bu.TypeGuid = bt.Guid			 
	INNER JOIN bu000 bu2 ON b.[BillNewGuid] = bu2.Guid
	
		
			
	DELETE [bu000] 
	FROM 
		[bu000] AS [bu] inner join [#Bill] as [bill] on [bu].[Guid] = [bill].[Guid]
	WHERE [bill].[BillCnt] = 0

	DELETE [billrel000]
	FROM 
		[billrel000] AS [br] inner join [#Bill] as [bill] on [br].[BillGuid] = [bill].[Guid]
	WHERE [bill].[BillCnt] = 0

	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --10

	UPDATE [bu] 
	SET 
		[bu].[CustAccGuid] = [bu2].[CustAccGuid], 
		[bu].[MatAccGuid] = [bu2].[MatAccGuid], 
		[bu].[StoreGuid] = [bu2].[StoreGuid], 
		[bu].[CostGuid] = [bu2].[CostGuid], 
		[bu].[CustGuid] = [bu2].[CustGuid], 
		[bu].[SalesManPtr] = [bu2].[SalesManPtr], 
		[bu].[Vendor] = [bu2].[Vendor] 
	FROM 
		[bu000] AS [bu] INNER JOIN [#Bill] AS [bu2] 
		ON [bu].[GUID] = [bu2].[GUID] 
	WHERE 
		[bu2].[BillCnt] > 1 
			 
	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --11

	UPDATE [bi] 
	SET 
		[bi].[StoreGuid] = [bu2].[StoreGuid], 
		[bi].[CostGuid] = [bu2].[CostGuid] 
	FROM 
		[bi000] AS [bi] INNER JOIN [#Bill] AS [bu2] 
		ON [bi].[ParentGUID] = [bu2].[GUID] 
	WHERE 
		[bu2].[BillCnt] > 1 


	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --12

	IF( @SecMerge != 0) 
	BEGIN 
		UPDATE [bu] SET [Security] = [bu2].[Sec] 
		FROM  
			[bu000] AS [bu] INNER JOIN  
			( SELECT [BillNewGuid] AS [Guid], MAX( [Security]) AS [Sec] FROM [#Bill] GROUP BY [BillNewGuid]) AS [bu2] 
			ON [bu].[Guid] = [bu2].[Guid] 
	END 

	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --13
	 
	UPDATE [bi] SET [bi].[ParentGuid] = [bi2].[BillNewGuid]
	FROM 
		[bi000] AS [bi] INNER JOIN [#Bill] AS [bi2] 
		ON [bi].[ParentGuid] = [bi2].[Guid] 

	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --14

	UPDATE [di] SET [di].[ParentGuid] = [bi2].[BillNewGuid] 
	FROM
		[di000] AS [di] INNER JOIN [#Bill] AS [bi2]
		ON [di].[ParentGuid] = [bi2].[Guid]

	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --15

	IF( @MergDisc = 1) 
	BEGIN 
		UPDATE [bi] SET 
			[bi].[Discount] = ((CASE (SELECT SUM( [bimt2].[biPrice] * [bimt2].[biBillQty]) FROM [vwBiMt] AS [bimt2] WHERE [bimt2].[biParent] = [bi].[ParentGUID]) WHEN 0 THEN (CASE [bimt].[biQty] WHEN 0 THEN 0  ELSE [bimt].[biDiscount] / [bimt].[biQty] END) + [bimt].[biBonusDisc] ELSE ((CASE [bimt].[biQty] WHEN 0 THEN 0 ELSE ([bimt].[biDiscount] / [bimt].[biQty]) END) + (ISNULL((SELECT Sum([diDiscount]) FROM [vwDi] WHERE [diParent] = [bi].[ParentGUID]),0) * [bimt].[biPrice] / CASE [bimt].[mtUnitFact] WHEN 0 THEN 1 ELSE [bimt].[mtUnitFact] END) / CASE WHEN ISNULL( (SELECT SUM( [bimt].[biPrice] * [bimt].[biBillQty]) FROM [vwBiMt] AS [bimt] WHERE [bimt].[biParent] = [bi].[ParentGUID]), 0) = 0 THEN 1 ELSE (SELECT SUM( [bimt].[biPrice] * [bimt].[biBillQty]) FROM [vwBiMt] AS [bimt] WHERE [bimt].[biParent] = [bi].[ParentGUID]) END) END) + [biBonusDisc]) ,
			[bi].[Extra] = ((CASE (SELECT SUM( [bimt2].[biPrice] * [bimt2].[biBillQty]) FROM [vwBiMt] AS [bimt2] WHERE [bimt2].[biParent] = [bi].[ParentGUID]) WHEN 0 THEN (CASE [bimt].[biQty] WHEN 0 THEN 0  ELSE [bimt].[biExtra] / [bimt].[biQty] END) ELSE ((CASE [bimt].[biQty] WHEN 0 THEN 0 ELSE ([bimt].[biExtra] / [bimt].[biQty]) END) + (ISNULL((SELECT Sum([diExtra]) FROM [vwDi] WHERE [diParent] = [bi].[ParentGUID]),0) * [bimt].[biPrice] / CASE [bimt].[mtUnitFact] WHEN 0 THEN 1 ELSE [bimt].[mtUnitFact] END) / CASE WHEN ISNULL( (SELECT SUM( [bimt].[biPrice] * [bimt].[biBillQty]) FROM [vwBiMt] AS [bimt] WHERE [bimt].[biParent] = [bi].[ParentGUID]), 0) = 0 THEN 1 ELSE (SELECT SUM( [bimt].[biPrice] * [bimt].[biBillQty]) FROM [vwBiMt] AS [bimt] WHERE [bimt].[biParent] = [bi].[ParentGUID]) END) END)) 
		FROM  
			[bi000] AS [bi]  
			INNER JOIN [vwBiMt] AS [bimt] ON [bi].[Guid] = [bimt].[biGuid] 
			INNER JOIN [#Bill] AS [bu2] ON [bi].[ParentGuid] = [bu2].[BillNewGuid] 
			INNER JOIN [bt000] AS [bt] ON [bu2].[TypeGUID] = [bt].[Guid] 

		DELETE [di000] 
		FROM 
			[di000] AS [di] 
			INNER JOIN [#Bill] AS [bu2] on [di].[ParentGuid] = [bu2].[BillNewGuid]
			INNER JOIN [bt000] AS [bt] ON [bu2].[TypeGUID] = [bt].[Guid]
	END 

	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --16

	IF( @MergDisc = 2) 
	BEGIN 
		UPDATE [bi] SET 
			[bi].[Discount] = 0, 
			[bi].[Price] = [bi].[Price] + CASE [mtUnitFact] WHEN 0 THEN 0 ELSE (CASE (SELECT SUM( [bimt].[biPrice] * [bimt].[biBillQty]) FROM [vwBiMt] AS [bimt] WHERE [bimt].[biParent] = [bi].[ParentGUID]) WHEN 0 THEN [biExtra] ELSE [biExtra] + ISNULL((SELECT Sum([diExtra]) FROM [vwDi] WHERE [diParent] = [bi].[ParentGuid]),0) * [biPrice] / [mtUnitFact] / CASE WHEN ISNULL( (SELECT SUM( [bimt].[biPrice] * [bimt].[biBillQty]) FROM [vwBiMt] AS [bimt] WHERE [bimt].[biParent] = [bi].[ParentGUID]), 0) = 0 THEN 1 ELSE (SELECT SUM( [bimt].[biPrice] * [bimt].[biBillQty]) FROM [vwBiMt] AS [bimt] WHERE [bimt].[biParent] = [bi].[ParentGUID]) END END) END - ((CASE (SELECT SUM( [bimt2].[biPrice] * [bimt2].[biBillQty]) FROM [vwBiMt] AS [bimt2] WHERE [bimt2].[biParent] = [bi].[ParentGUID]) WHEN 0 THEN (CASE [bimt].[biQty] WHEN 0 THEN 0  ELSE [bimt].[biDiscount] / [bimt].[biQty] END) + [bimt].[biBonusDisc] ELSE ((CASE [bimt].[biQty] WHEN 0 THEN 0 ELSE ([bimt].[biDiscount] / [bimt].[biQty]) END) + (ISNULL((SELECT Sum([diDiscount]) FROM [vwDi] WHERE [diParent] = [bi].[ParentGUID]),0) * [bimt].[biPrice] / CASE [bimt].[mtUnitFact] WHEN 0 THEN 1 ELSE [bimt].[mtUnitFact] END) / CASE WHEN ISNULL( (SELECT SUM( [bimt].[biPrice] * [bimt].[biBillQty]) FROM [vwBiMt] AS [bimt] WHERE [bimt].[biParent] = [bi].[ParentGUID]), 0) = 0 THEN 1 ELSE (SELECT SUM( [bimt].[biPrice] * [bimt].[biBillQty]) FROM [vwBiMt] AS [bimt] WHERE [bimt].[biParent] = [bi].[ParentGUID]) END) END) + [biBonusDisc]) 
		FROM  
			[bi000] AS [bi]  
			INNER JOIN [vwBiMt] AS [bimt] ON [bi].[Guid] = [bimt].[biGuid] 
			INNER JOIN [#Bill] AS [bu2] ON [bi].[ParentGuid] = [bu2].[BillNewGuid] 

		DELETE [di000] 
		FROM 
			[di000] AS [di] inner join [#Bill] AS [bu] on [di].[ParentGuid] = [bu].[BillNewGuid]
	END 

	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --17
	--------------------------------------------------- 
	DECLARE @BillCount [INT]  
	DELETE FROM [#Bill] WHERE [BillCnt] = 0 
	SET @BillCount = @@ROWCOUNT 
	--------------------------------------------------- 
	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --18

	IF( @MergItem = 1) 
	BEGIN 
		CREATE TABLE [#BillItem]( 
			[GUID]  [uniqueidentifier] DEFAULT (newid()), 
			[Qty] [float], 
			[Unity] [float], 
			[Price] [float], 
			[BonusQnt] [float], 
			[Discount] [float], 
			[BonusDisc] [float], 
			[Extra] [float], 
			[Profits] [float], 
			[Qty2] [float], 
			[Qty3] [float], 
			[ClassPtr] [float], 
			[ExpireDate] [datetime], 
			[ProductionDate] [datetime], 
			[Length] [float], 
			[Width] [float], 
			[Height] [float], 
			[VAT] [float], 
			[VATRatio] [float], 
			[ParentGUID] [uniqueidentifier], 
			[MatGUID] [uniqueidentifier], 
			[CurrencyGUID] [uniqueidentifier], 
			[CurrencyVal] [FLOAT],  
			[StoreGUID] [uniqueidentifier], 
			[CostGUID] [uniqueidentifier]) 
		 
		INSERT INTO [#BillItem]( 
			[Qty], 
			[Unity], 
			[Price], 
			[BonusQnt], 
			[Discount], 
			[BonusDisc], 
			[Extra], 
			[Profits], 
			[Qty2], 
			[Qty3], 
			[ClassPtr], 
			[ExpireDate], 
			[ProductionDate], 
			[Length], 
			[Width], 
			[Height], 
			[VAT], 
			[VATRatio], 
			[ParentGUID], 
			[MatGUID], 
			[CurrencyGUID], 
			[CurrencyVal], 
			[StoreGUID], 
			[CostGUID]) 
		 
		SELECT 
			SUM( [bi].[Qty]),  
			[bi].[Unity],  
			[bi].[Price],  
			SUM( [bi].[BonusQnt]),  
			SUM( [bi].[Discount]),  
			SUM( [bi].[BonusDisc]),  
			SUM( [bi].[Extra]),  
			SUM( [bi].[Profits]),  
			SUM( [bi].[Qty2]),  
			SUM( [bi].[Qty3]),  
			[bi].[ClassPtr],  
			[bi].[ExpireDate],  
			[bi].[ProductionDate],  
			[bi].[Length],  
			[bi].[Width],  
			[bi].[Height],  
			SUM( [bi].[VAT]),  
			SUM( [bi].[VATRatio]),  
			[bi].[ParentGUID],  
			[bi].[MatGUID],  
			[bi].[CurrencyGUID],  
			[bi].[CurrencyVal],  
			[bi].[StoreGUID],  
			[bi].[CostGUID] 
		FROM  
			[bi000] AS [bi]  
			inner join [#Bill] AS [bu] ON [bu].[Guid] = [bi].[ParentGuid] 
			inner join [mt000] AS [mt] ON [bi].[MatGUID] = [mt].[Guid] 
		WHERE  
			[mt].[SNFlag] = 0 
		GROUP BY 
			[bi].[Unity], 
			[bi].[Price],  
			[bi].[ClassPtr],  
			[bi].[ExpireDate],  
			[bi].[ProductionDate],  
			[bi].[Length],  
			[bi].[Width],  
			[bi].[Height],  
			[bi].[ParentGUID],  
			[bi].[MatGUID],  
			[bi].[CurrencyGUID],  
			[bi].[CurrencyVal],  
			[bi].[StoreGUID],  
			[bi].[CostGUID] 

	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --19

		DELETE [bi000] 
		FROM  
			[bi000] AS [bi] inner join ( SELECT [Guid] FROM [mt000] AS [mt] WHERE [SNFlag] = 0) AS [mt] ON [bi].[MatGUID] = [mt].[Guid]
			inner join [#Bill] AS [bu] on [bi].[ParentGuid] = [bu].[Guid]

	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --20

		INSERT INTO [bi000]( 
			[GUID], 
			[Qty],  
			[Unity], 
			[Price], 
			[BonusQnt], 
			[Discount], 
			[BonusDisc], 
			[Extra], 
			[Profits], 
			[Qty2], 
			[Qty3], 
			[ClassPtr], 
			[ExpireDate], 
			[ProductionDate], 
			[Length], 
			[Width], 
			[Height], 
			[VAT], 
			[VATRatio], 
			[ParentGUID], 
			[MatGUID], 
			[CurrencyGUID], 
			[CurrencyVal], 
			[StoreGUID], 
			[CostGUID]) 
		SELECT  
			[GUID], 
			[Qty], 
			[Unity], 
			[Price], 
			[BonusQnt], 
			[Discount], 
			[BonusDisc], 
			[Extra], 
			[Profits], 
			[Qty2], 
			[Qty3], 
			[ClassPtr], 
			[ExpireDate], 
			[ProductionDate], 
			[Length], 
			[Width], 
			[Height], 
			[VAT], 
			[VATRatio], 
			[ParentGUID], 
			[MatGUID], 
			[CurrencyGUID], 
			[CurrencyVal], 
			[StoreGUID], 
			[CostGUID] 
		FROM 
			[#BillItem]
	END

	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --21

	update [bu] set 
			[Notes] = '',
			[total] = isnull((select sum([tot]) from (select [parentGuid], [qty] * [price] * (case [unity] when 2 then (select case [unit2Fact] when 0 then 1 else [unit2Fact] end from [mt000] where [guid] = [matGuid]) when 3 then (select case [unit3Fact] when 0 then 1 else [unit3Fact] end from [mt000] where [guid] = [matGuid]) else 1 end) as [tot] from [bi000]) [b] where [parentGuid] = [bu].[guid]), 0),
			[totalDisc] = isnull((select sum([discount]) from [bi000] where [parentGuid] = [bu].[guid]), 0) + isnull((select sum([discount]) from [di000] where [parentGuid] = [bu].[guid]), 0),
			[totalExtra] = isnull((select sum([extra]) from [bi000] where [parentGuid] = [bu].[guid]), 0) + isnull((select sum([extra]) from [di000] where [parentGuid] = [bu].[guid]), 0),
			[itemsDisc] = isnull((select sum([discount]) from [bi000] where [parentGuid] = [bu].[guid]), 0),
			[bonusDisc] = isnull((select sum([tot]) from (select [parentGuid], [bonusDisc] * [price] * (case [unity] when 2 then (select case [unit2Fact] when 0 then 1 else [unit2Fact] end from [mt000] where [guid] = [matGuid])  when 3 then (select case [unit3Fact] when 0 then 1 else [unit3Fact] end from [mt000] where [guid] = [matGuid]) else 1 end) as [tot] from [bi000]) [b] where [parentGuid] = [bu].[guid]), 0),
			[vat] = isnull((select sum([vat]) from [bi000] where [parentGuid] = [bu].[guid]), 0)
	from 
		[bu000] [bu] inner join [#Bill] AS [b] ON [bu].[Guid] = [b].[Guid]

	EXEC prcEnableTriggers 'bu000'
	EXEC prcEnableTriggers 'bi000'
	EXEC prcEnableTriggers 'di000'
	----------------------------------------------      
	DECLARE @BillEntry CURSOR, @billGuid [UNIQUEIDENTIFIER] 
	SET @BillEntry = CURSOR 
	FOR      
		SELECT      
			[bu].[Guid] 
		FROM      
			[bu000] AS [b] INNER JOIN [#Bill] AS [bu] 
			ON [b].[Guid] = [bu].[Guid]
		WHERE 
			[b].[total] != 0
		ORDER BY 
			[bu].[Date] 

	OPEN @BillEntry FETCH NEXT FROM @BillEntry INTO @billGuid 
	WHILE @@FETCH_STATUS = 0        
	BEGIN
		exec [prcBill_genEntry] @billGuid 
		FETCH NEXT FROM @BillEntry INTO @billGuid 
	END		 
	CLOSE @BillEntry
	DEALLOCATE @BillEntry
	--set @item_i = @item_i + 1
	--insert into #T(i) values( @item_i) --22
	EXEC prcEnableTriggers	'ce000' 
	----------------------------------------------     	 
	SELECT @BillCount AS [BillCount]
	--select * from #t
	 EXEC prcCloseMaintenanceLog @LgGuid
###########################################################################
#END