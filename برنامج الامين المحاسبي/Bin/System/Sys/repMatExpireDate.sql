################################################################################
CREATE PROCEDURE repMatExpireDate
		@MatPtr [UNIQUEIDENTIFIER] ,      
		@MatGroup [UNIQUEIDENTIFIER] ,      
		@StorePtr [UNIQUEIDENTIFIER] ,      
		@FromDate [DATETIME],      
		@UntilDate [DATETIME] ,      
		@ShowBonus [BIT],      
		@UseUnit [INT], -- 1 unit1 2 unit2 3 unit3 4 defunit      
		@CurrencyPtr [UNIQUEIDENTIFIER] ,      
		@CurrencyVal [FLOAT],      
		@BillTypes [UNIQUEIDENTIFIER] ,  
		@FromDay [INT],  
		@ToDay [INT], 
		@Detail [INT], 
		@Lang	[BIT] = 0, 
		@DescOrder	[BIT] = 0, 
		@MatCondGuid [UNIQUEIDENTIFIER] = 0X00, 
		@bProcessCost 	[BIT] = 0, 
		@FilterByExpireDate BIT = 0
AS   
	SET NOCOUNT ON 
	 
	DECLARE @GUIDZero AS [UNIQUEIDENTIFIER]   
	SET @GUIDZero = 0X0  
	 
	DECLARE @bProcessClass AS INT
	DECLARE @GroupByMaterial AS INT
	SET @bProcessClass = 0
	SET @GroupByMaterial = 0

	CREATE TABLE [#RESULT](	 
				[ID]			[INT],   
				[MatPtr]		[UNIQUEIDENTIFIER] ,   
				[MatCode]		[NVARCHAR](256) COLLATE Arabic_CI_AI,   
				[MatName]		[NVARCHAR](256) COLLATE Arabic_CI_AI,   
				[Price]			[FLOAT],   
				[Qty]			[FLOAT],   
				[Qty2]			[FLOAT],   
				[Qty3]			[FLOAT],   
				[ExpireDate]	[DATETIME] ,   
				[Date]			[DATETIME] ,   
				[buStore]		[UNIQUEIDENTIFIER] ,   
				[Remaining]		[FLOAT],   
				[Remaining2]	[FLOAT],   
				[Remaining3]	[FLOAT],   
				[MatUnitName]	[NVARCHAR](256) COLLATE Arabic_CI_AI,   
				[BillType]		[UNIQUEIDENTIFIER] ,   
				[BillNum]		[UNIQUEIDENTIFIER] ,   
				[BillNotes]		[NVARCHAR](max) COLLATE Arabic_CI_AI,   
				[Age]			[INT], 
				[CLASS] 		[NVARCHAR](250) COLLATE Arabic_CI_AI, 
				[CostGuid] 		[UNIQUEIDENTIFIER])  
				 
	CREATE TABLE [#Src] ( [Type] [UNIQUEIDENTIFIER] , [Sec] [INT], [ReadPrice] [INT], [UnPostedSec] [INT]) 
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList2] @BillTypes   
	-------------    
	CREATE TABLE [#Mat] ( [mtNumber] [UNIQUEIDENTIFIER] , [mtSecurity] [INT])    
	INSERT INTO [#Mat] EXEC [prcGetMatsList]  @MatPtr, @MatGroup,-1,@MatCondGuid   
	-------------   
	CREATE TABLE [#Store] ( [Number] [UNIQUEIDENTIFIER] )    
	INSERT INTO [#Store] select [GUID] from [fnGetStoresList]( @StorePtr)    
	IF @StorePtr = @GUIDZero  
		INSERT INTO [#Store] VALUES( @GUIDZero)  
	-------------   
	 
	IF @bProcessCost = 0 
		ALTER TABLE #RESULT DROP COLUMN CostGuid  
		 
	INSERT INTO [#RESULT]EXEC [repMatExpireDate2] @UntilDate, @ShowBonus, @UseUnit, @CurrencyPtr, @CurrencyVal, @FromDate, @Detail, -1, 0X00, 1 /*@ShowPrice*/,0x00,0, @bProcessCost, @bProcessClass, @FilterByExpireDate
	ALTER TABLE #RESULT ADD GroupName NVARCHAR(256) COLLATE Arabic_CI_AI 
	Declare @S NVARCHAR(1000) 
	Set @S = ' 
	UPDATE r SET 
	r.[GroupName] = [gr].[Name] 
	FROM [#Result] As r 
	INNER JOIN [MT000] AS [mt] ON [r].[MatPtr] = [mt].[GUID] 
	INNER JOIN [GR000] AS [gr] ON [mt].[GroupGuid] = [gr].[GUID]' 
	Exec (@S) 
	 
	IF (@Lang <> 0) 
		UPDATE [r] SET [MatName] = [LatinName] 
		FROM [#RESULT] AS [r] INNER JOIN [mt000] AS [mt] ON [r].[MatPtr] = [mt].[Guid] 
		WHERE [mt].[LatinName] <> '' 
	 
	 
	DECLARE @ClassString NVARCHAR(40) 
	DECLARE @CostString NVARCHAR(40) 
	Set @CostString = '' 
	Set @ClassString = '' 
	IF @bProcessClass > 0 
		Set @ClassString = ', 
		[t].[CLASS]' 
	IF @bProcessCost > 0 
		Set @CostString = ', 
		[CO].[NAME] CostName' 
		 
	DECLARE @Sql NVARCHAR(max) 
	SET @Sql = ' 
		SELECT   
			[mt].[latinName], [mt].[barcode], [mt].[barcode2], [mt].[barcode3],[mt].[VAT], [mt].[spec], [mt].[qty] AS [qqty], [mt].[origin], [mt].[company], [mt].[type], [mt].[model], [mt].[quality], [mt].[provenance], [mt].[color], [mt].[pos], [mt].[dim], 
			[t].[ID], 
			[t].[MatPtr], 
			[t].[MatCode], 
			[t].[MatName], 
			[t].[GroupName],' 
	--IF @ShowPrice = 1 
	--BEGIN 
		IF @Detail = 1 
			SET @Sql = @Sql +	'([t].[Price] * [t].[Remaining] / CASE [t].[Qty] WHEN 0 THEN 1 ELSE [t].[Qty] END) AS [Price],' 
		ELSE 
			SET @Sql = @Sql +	'[t].[Price]  AS [Price],' 
	--END 
	 
	SET @Sql = @Sql +	'[t].[Qty], 
			[t].[Qty2], 
			[t].[Qty3], 
			[t].[ExpireDate], 
			[t].[Date], 
			[t].[buStore], 
			[stName] AS [storeName], 
			[stLatinName] AS [storeLatinName], 
			[t].[Remaining], 
			[t].[Remaining2], 
			[t].[Remaining3], 
			[t].[MatUnitName], 
			[t].[BillType],'
			IF @Detail > 0
				SET @Sql = @Sql + '[btName] AS [BillName], [btLatinName] AS [BillLatinName],'
			SET @Sql = @Sql + ' 
			[t].[BillNum], 
			[t].[BillNotes], 
			[t].[Age] 
			' + @ClassString + ' 
			' + @CostString   
			 
	IF @Detail > 0 
		SET @Sql = @Sql + ' , [cu].[CustomerName] AS [CustomerName], [cu].[Guid] AS [CustomerGUID] ' 
		 
	SET @Sql = @Sql + ' FROM  [#RESULT] AS [t] 
			INNER JOIN [Mt000] AS [mt] ON [t].[MatPtr] = [mt].[GUID] ' 
			 
	IF @Detail > 0 
		SET @Sql = @Sql + ' INNER JOIN [BU000] AS [bu] ON [t].[BillNum]   = [bu].GUID  
				            LEFT  JOIN [CU000] AS [cu] ON [bu].[CustGuid] = [cu].[GUID] ' 
			 
	IF @bProcessCost > 0 
		SET @Sql = @Sql + ' 
		LEFT JOIN CO000 AS [CO] ON [CO].GUID = [t].COSTGuid ' 
	IF @Detail > 0
		SET @Sql = @Sql + 'INNER JOIN vwbt bt ON bt.btGUID = [t].[BillType]' 
	SET @Sql = @Sql + 'INNER JOIN vwst st ON st.stGUID = [t].[buStore]' 
	DECLARE @TemDate INT 
	 
	IF (@FromDay <> 0 AND @ToDay <> 0 AND @FilterByExpireDate = 0)
	BEGIN 
		IF 	@FromDay > @ToDay 
		BEGIN 
			SET @TemDate = @ToDay 
			SET @ToDay = @FromDay 
			SET @FromDay = @TemDate 
		END  
		SET @Sql = @Sql + ' WHERE    
			DATEDIFF ( day, ' + '''' + CAST(DATEPART ( MM , @UntilDate ) AS NVARCHAR(2) )+ '/'+ CAST(DATEPART ( DD , @UntilDate ) AS NVARCHAR(2))+ '/'+ CAST(DATEPART ( YYYY , @UntilDate ) AS NVARCHAR(4))  + ''', [ExpireDate]) >= '  + CAST( @FromDay  AS NVARCHAR(10) ) +' 
			AND DATEDIFF ( day, ' + '''' + CAST(DATEPART ( MM , @UntilDate ) AS NVARCHAR(2) )+ '/'+ CAST(DATEPART ( DD , @UntilDate ) AS NVARCHAR(2))+ '/'+ CAST(DATEPART ( YYYY , @UntilDate ) AS NVARCHAR(4))  + ''', [ExpireDate]) <= ' + CAST(@ToDay AS NVARCHAR(10) )  
	END  
	 
	DECLARE @TMP NVARCHAR(200) 
	SET @TMP = '' 
	IF @bProcessCost > 0 
		SET @TMP = @TMP + ' [CO].[NAME], ' 
	IF @bProcessClass > 0 
		SET @TMP = @TMP + ' [t].[CLASS], ' 
	IF @GroupByMaterial > 0 
		SET @TMP = @TMP + ' [t].[MatCode], [t].[MatPtr], ' 
	 
	SET @Sql = @Sql + '	ORDER BY ' + @TMP + '[t].[ExpireDate]' 
	IF @DescOrder > 0 
		SET @Sql = @Sql + ' DESC' 
	 
	EXEC (@Sql)	 

################################################################################
#END