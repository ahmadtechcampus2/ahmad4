################################################################################
CREATE PROCEDURE repGetAges_bi
	@MatPtr [UNIQUEIDENTIFIER],      
	@MatGroup [UNIQUEIDENTIFIER],      
	@StorePtr [UNIQUEIDENTIFIER],      
	@UntilDate [DATETIME],      
	@Detailed [BIT],      
	@NumOfPeriods [INT],      
	@PeriodLength [INT],      
	@ShowBonus [BIT],      
	@UseUnit [INT], -- 1 unit1 2 unit2 3 unit3 4 defunit      
	@CurrencyPtr [UNIQUEIDENTIFIER], 
	@CurrencyVal [FLOAT], 
	@Billtypes [UNIQUEIDENTIFIER],
	@ShowEmpty [BIT] = 1,
	@MatCondGuid [UNIQUEIDENTIFIER] = 0X00,
	@ProcessInBlill		BIT = 0			
AS      
	SET NOCOUNT ON 
	--SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	DECLARE @GUIDZero AS [UNIQUEIDENTIFIER]    
	SET @GUIDZero = 0X0    
	-------------------------------------------    
	CREATE TABLE [#Src] ( [Type] [UNIQUEIDENTIFIER], [Sec] [INT], [ReadPrice] [INT], [UnPostedSec] [INT])
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList2] @Billtypes    
	-------------     
	CREATE TABLE [#Mat] ( [mtNumber] [UNIQUEIDENTIFIER], [mtSecurity] [INT])     
	-------------     
	insert into #Mat EXEC [prcGetMatsList]  @MatPtr, @MatGroup,-1,@MatCondGuid  
	--CREATE CLUSTERED INDEX  matIndex ON #Mat( [mtNumber]) 
	-------------    
	CREATE TABLE [#Store] ( [Number] [UNIQUEIDENTIFIER])     
	INSERT INTO [#Store] select [Guid] from [fnGetStoresList]( @StorePtr)     
	IF @StorePtr = @GUIDZero    
		INSERT INTO [#Store] VALUES( @GUIDZero)    
	-------------
	DECLARE @Out_mt CURSOR, @mtNumber [UNIQUEIDENTIFIER], @mtSumQntOut [FLOAT],@StoreGuid UNIQUEIDENTIFIER      
	DECLARE @In_mt CURSOR, @biQnt [FLOAT],  @biDate [DATETIME], @MatUnitName [NVARCHAR](24), @BillGUID [UNIQUEIDENTIFIER], @BillType [UNIQUEIDENTIFIER], @BillNotes [NVARCHAR](256) ,@BiGuid    [UNIQUEIDENTIFIER] 
	DECLARE @Id INT ,@Id2 INT,@RQty FLOAT
	DECLARE @TGuid UNIQUEIDENTIFIER 
	SELECT @TGuid= [Guid] FROM [bt000] WHERE SortNum = 1 AND Type = 2 
	-------------
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])
	-------------
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], UserReadPriceSecurity [INTEGER])  
	CREATE TABLE [#t_Prices]  
	(  
		[mtNumber] 	[UNIQUEIDENTIFIER],  
		[APrice] 	[FLOAT]  
	)
	CREATE TABLE [#ResultMatAge] (  [ID] [INT] IDENTITY(1,1), 
				[MatPtr] [UNIQUEIDENTIFIER], 
				[Price] [FLOAT], 
				[Total] [FLOAT], 
				[Qty] [FLOAT], 
				[Date] [DATETIME], 
				[Remaining] [FLOAT], 
				[Age] [INT], 
				[MatUnitName] [NVARCHAR](256) , 
				[BillGUID] [UNIQUEIDENTIFIER],  
				[BillType] [UNIQUEIDENTIFIER], 
				[BillNotes] [NVARCHAR](MAX) , 
				[BiGuid] [UNIQUEIDENTIFIER],
				[BiNumber] [INT],
				[mtSecurity] [INT],
				[Security] [INT],
				[UserSecurity] [INT],
				[Direction] [INT],
				btBillType [INT],
				[ExpireDate] [DATETIME])
	CREATE TABLE [#In_Result] (
				[ID] INT, 
				[MatPtr] [UNIQUEIDENTIFIER], 
				[Price] [FLOAT], 
				[Total] [FLOAT], 
				[Qty] [FLOAT], 
				[Date] [DATETIME], 
				[Remaining] [FLOAT], 
				[Age] [INT], 
				[MatUnitName] [NVARCHAR](256) , 
				[BillGUID] [UNIQUEIDENTIFIER],  
				[BillType] [UNIQUEIDENTIFIER], 
				[BillNotes] [NVARCHAR](MAX) , 
				[BiGuid] [UNIQUEIDENTIFIER],
				[BiNumber] [INT],
				[ExpireDate] [DATETIME])

	CREATE TABLE [#Final_Result] 
	(			[ID] INT, 
				[MatPtr] [UNIQUEIDENTIFIER], 
				[Price] [FLOAT], 
				[Total] [FLOAT], 
				[Qty] [FLOAT], 
				[Date] [DATETIME], 
				[Remaining] [FLOAT], 
				[Age] [INT], 
				[MatUnitName] [NVARCHAR](256) , 
				[BillGUID] [UNIQUEIDENTIFIER],  
				[BillType] [UNIQUEIDENTIFIER], 
				[BillNotes] [NVARCHAR](MAX) , 
				[BiGuid] [UNIQUEIDENTIFIER],
				[BiNumber] [INT],
				[ExpireDate] [DATETIME])
	-------------
	DECLARE @StartDate date
	SELECT @StartDate = dbo.fnDate_Amn2Sql(Value) FROM op000 WHERE Name = N'AmnCfg_FPDate'; 

	--Filling temporary tables  
	INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		@MatPtr, @MatGroup, 0,@MatCondGuid  
	INSERT INTO [#BillsTypesTbl]EXEC [prcGetBillsTypesList] 0x00 

	EXEC [prcGetAvgPrice]	@StartDate,	@UntilDate, @MatPtr, @MatGroup, @StorePtr, 0x00, 0, 
				@CurrencyPtr, @CurrencyVal, 0x00, 0, 0, 0
		SELECT
			[biMatPtr],  
			[biGuid], 
			CASE WHEN ReadPrice >= BuSecurity THEN 1 ELSE 0 END * ([FixedbiUnitPrice] + [FixedbiUnitExtra] - [FixedbiUnitDiscount]) AS [biUnitPrice],
			CASE @UseUnit
				WHEN 0 THEN 1
				WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END
				WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END
				WHEN 3 THEN CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END  
			END AS UnitFact,
			CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END AS Unit2Fact,
			CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END AS Unit3Fact,
			[biQty],
			[biCalculatedQty2] AS [biQty2],
			[biCalculatedQty3] AS [biQty3],
			[buGUID],    
			[buType],    
			[biNotes], 
			[biNumber],
			[mat].[mtSecurity],
			[buSecurity],
			CASE [ExtBi].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END AS [btSec],
			[buDirection],[buDate],
			CASE @UseUnit WHEN 0 THEN [mtUnity] WHEN 1 THEN [mtUnit2] WHEN 2 THEN [mtUnit3] WHEN 3 THEN [mtDefUnitName] END AS [UnitName],[biBonusQnt],CASE [buType] WHEN @TGuid THEN 0 ELSE  btBillType end btBillType,buSortFlag,buNumber,[biExpireDate]
		INTO #bu
		FROM    
			[fnExtended_Bi_Fixed]( @CurrencyPtr)  AS [ExtBi]
			LEFT JOIN Ages000 AS MatAges ON ExtBi.biGuid = MatAges.refGuid
			INNER JOIN [#Mat] AS [mat] ON [ExtBi].[BiMatPtr] = [mat].[mtNumber]    
			INNER JOIN [#Src] AS [src] ON [ExtBi].[BuType] = [src].[Type]    
			INNER JOIN [#Store] AS [stor] ON [ExtBi].[BiStorePtr] = [stor].[Number]     
		WHERE
			(Convert(DateTime, DATEDIFF(DAY, 0, ExtBi.buDate)) <= @UntilDate
			 OR 
			Convert(DateTime, DATEDIFF(DAY, 0, MatAges.[Date])) <= @UntilDate)
			AND buIsPosted > 0
		

		IF EXISTS(SELECT * FROM [Ages000] a INNER JOIN #bu b ON b.biGuid = a.refGuid WHERE a.Type = 1)  
		BEGIN
			UPDATE [b] SET [buDate] = '1/1/1980' FROM [#bu] [b] INNER JOIN [Ages000] [a] ON b.biGuid = a.refGuid WHERE a.Type = 1
			INSERT INTO [#bu]
			SELECT 
				[biMatPtr],  
				[biGuid], 
				[biUnitPrice],
				[UnitFact],
				[Unit2Fact],
				[Unit3Fact],
				SUM(a.Val) / COUNT(a.Val) AS biQty,
			    SUM(a.Val / Unit2Fact) / COUNT(a.Val) AS biQty2,
				SUM(a.Val / Unit3Fact) / COUNT(a.Val) AS biQty3,
				[buGUID],    
				[buType],    
				[biNotes], 
				[biNumber],
				[mtSecurity],
				[buSecurity],
				[btSec],
				[buDirection],[a].[Date],
				[UnitName],0,0,buSortFlag,buNumber,[biExpireDate]
			FROM [#bu] [b] INNER JOIN [Ages000] [a] ON b.biGuid = a.refGuid 
			
			WHERE a.Type = 1 AND [buDate] = '1/1/1980' 
			GROUP BY biMatPtr,biGUID, biUnitPrice, UnitFact, Unit2Fact, Unit3Fact, buGUID, buType, biNotes, biNumber, mtSecurity, buSecurity, btSec, buDirection, a.Date
			, UnitName, buSortFlag, buNumber, biExpireDate
			DELETE [#bu] WHERE [buDate] = '1/1/1980'
		END
		

		
		INSERT INTO [#ResultMatAge] ( 	
				[MatPtr],     
				[Price],     
				[Total],
				[Qty],     
				[Date],     
				[Remaining],
				[Age],     
				[MatUnitName],     
				[BillGUID],     
				[BillType],    
				[BillNotes], 
				[BiGuid],
				[BiNumber],
				[mtSecurity],
				[Security],
				[UserSecurity],
				[Direction],
				[btBillType],
				[ExpireDate])
		SELECT
			[biMatPtr],    
			[biUnitPrice]*[UnitFact],
			0,--biQty * CASE WHEN ReadPrice >= BuSecurity THEN [FixedBiPrice] ELSE 0 END,   
			CASE @UseUnit     
				WHEN 0 THEN sales.Val
				WHEN 1 THEN sales.Val /[Unit2Fact]
				WHEN 2 THEN sales.Val /[Unit3Fact] 
				WHEN 3 THEN sales.Val / [UnitFact]  
			END,
			[buDate],
			CASE @UseUnit     
				WHEN 0 THEN  [biBonusQnt] * @ShowBonus 
				WHEN 1 THEN  ([biBonusQnt]/[Unit2Fact]) * @ShowBonus
				WHEN 2 THEN  ([biBonusQnt]/[Unit3Fact]) * @ShowBonus 
				WHEN 3 THEN  ([biBonusQnt] * @ShowBonus) / [UnitFact]  
			END,    
			DATEDIFF(d, [buDate], @UntilDate),     
			[UnitName],    
			[buGUID],    
			[buType],    
			[biNotes], 
			[biGuid],
			[biNumber],
			[mtSecurity],
			[buSecurity],
			[btSec],
			-1,
			1,
			[biExpireDate]
		FROM   [#bu] b  INNER JOIN [Ages000] sales ON b.biGuid = sales.refGuid 
			WHERE sales.Type = 2 
         ORDER BY
			[biMatPtr], [buDate],buSortFlag,buNumber, [biNumber]

		INSERT INTO [#ResultMatAge] ( 	
				[MatPtr],     
				[Price],     
				[Total],
				[Qty],     
				[Date],     
				[Remaining],
				[Age],     
				[MatUnitName],     
				[BillGUID],     
				[BillType],    
				[BillNotes], 
				[BiGuid],
				[BiNumber],
				[mtSecurity],
				[Security],
				[UserSecurity],
				[Direction],
				[btBillType],
				[ExpireDate])
		SELECT
			[biMatPtr],    
			[biUnitPrice]*[UnitFact],
			0,--biQty * CASE WHEN ReadPrice >= BuSecurity THEN [FixedBiPrice] ELSE 0 END,   
			CASE    @UseUnit     
				WHEN 0 THEN Rsales.Val
				WHEN 1 THEN Rsales.Val  /[Unit2Fact]
				WHEN 2 THEN Rsales.Val  /[Unit3Fact]
				WHEN 3 THEN Rsales.Val  / [UnitFact]  
			END,
			[buDate],
			CASE @UseUnit     
				WHEN 0 THEN  [biBonusQnt] * @ShowBonus 
				WHEN 1 THEN ( ( [biBonusQnt]/[Unit2Fact]) * @ShowBonus) 
				WHEN 2 THEN ( ( [biBonusQnt]/[Unit3Fact]) * @ShowBonus) 
				WHEN 3 THEN ([biBonusQnt] * @ShowBonus) / [UnitFact]  
			END,    
			DATEDIFF(d, [buDate], @UntilDate),     
			[UnitName],    
			[buGUID],    
			[buType],    
			[biNotes], 
			[biGuid],
			[biNumber],
			[mtSecurity],
			[buSecurity],
			[btSec],
			1,
			3,
			[biExpireDate]
		FROM   [#bu] b  INNER JOIN [Ages000] Rsales ON b.biGuid = Rsales.refGuid 
			WHERE Rsales.Type = 3 
         ORDER BY
			[biMatPtr], [buDate],buSortFlag,buNumber, [biNumber]

	
		INSERT INTO [#ResultMatAge] ( 	
			[MatPtr],     
			[Price],     
			[Total],
			[Qty],     
			[Date],     
			[Remaining],
			[Age],     
			[MatUnitName],     
			[BillGUID],     
			[BillType],    
			[BillNotes], 
			[BiGuid],
			[BiNumber],
			[mtSecurity],
			[Security],
			[UserSecurity],
			[Direction],
			[btBillType],
			[ExpireDate])
		SELECT
			[biMatPtr],    
			[biUnitPrice]*[UnitFact],
			0,--biQty * CASE WHEN ReadPrice >= BuSecurity THEN [FixedBiPrice] ELSE 0 END,   
			CASE @UseUnit
				WHEN 0 THEN ([biQty] + [biBonusQnt] * @ShowBonus) 
				WHEN 1 THEN (([biQty2]  + ( [biBonusQnt]/[Unit2Fact]) * @ShowBonus)) 
				WHEN 2 THEN (([biQty3]  + ( [biBonusQnt]/[Unit3Fact]) * @ShowBonus) ) 
				WHEN 3 THEN (([biQty]  + [biBonusQnt] * @ShowBonus) / [UnitFact])  
			END,
			[buDate],
			CASE @UseUnit
				WHEN 0 THEN [biQty] + [biBonusQnt] * @ShowBonus 
				WHEN 1 THEN [biQty2]  + ( [biBonusQnt]/[Unit2Fact]) * @ShowBonus
				WHEN 2 THEN [biQty3]  + ( [biBonusQnt]/[Unit3Fact]) * @ShowBonus
				WHEN 3 THEN ([biQty]  + [biBonusQnt] * @ShowBonus) / [UnitFact]
			END,    
			DATEDIFF(d, [buDate], @UntilDate),     
			[UnitName],    
			[buGUID],    
			[buType],    
			[biNotes], 
			[biGuid],
			[biNumber],
			[mtSecurity],
			[buSecurity],
			[btSec],
			[buDirection],
			[btBillType],
			[biExpireDate]
		FROM   [#bu] b 
		ORDER BY
			[biMatPtr], [buDate],buSortFlag,buNumber, [biNumber]
		
	    EXEC [prcCheckSecurity] @result = '#ResultMatAge'
	
		INSERT INTO [#In_Result] 
		SELECT 
			[ID],
			[MatPtr],     
			[Price], 
			[Total],
			[Qty],     
			[Date],     
			[Remaining],
			[Age],     
			[MatUnitName],     
			[BillGUID],     
			[BillType],    
			[BillNotes], 
			[BiGuid],
			[BiNumber],
			[ExpireDate]
		FROM 
			[#ResultMatAge] 
		WHERE 
		[Direction] = 1 AND   [btBillType] <> 3 AND (@ProcessInBlill = 1 OR btBillType <> 4)
		
		----------------------------------------------
		SELECT DISTINCT MatPtr,
					   (SELECT ISNULL(SUM(R2.Qty), 0) FROM #ResultMatAge R2 WHERE R2.MatPtr = R1.MatPtr AND R2.Direction = -1) AS Qty
		INTO #OUTQTY
		FROM #ResultMatAge R1
		
		UPDATE Q SET  [Qty] = Q.[Qty] - A.[Qty] FROM #OUTQTY Q INNER JOIN (SELECT  [MatPtr],SUM(QTY) QTY FROM [#ResultMatAge] WHERE [btBillType]= 3 OR   (@ProcessInBlill = 0 AND btBillType = 4) GROUP BY [MatPtr]) A ON  Q.[MatPtr] = A.[MatPtr]
		
			
		DELETE [#ResultMatAge] WHERE [btBillType]= 3  OR  (@ProcessInBlill = 0 AND btBillType = 4)
	

		
		-----------------------------------------------
		   SET @Out_mt = CURSOR FAST_FORWARD FOR    
			SELECT    
				[MatPtr],     
				SUM( [Qty])
			FROM    
				#OUTQTY    
			GROUP BY [MatPtr]
			ORDER BY    
				[MatPtr]

			
		----------------------------------------------    
		OPEN @Out_mt FETCH NEXT FROM @Out_mt INTO @mtNumber, @mtSumQntOut     
		WHILE @@FETCH_STATUS = 0      
		BEGIN      
			DECLARE @MATQTY AS [INT]    
			SET @MATQTY = 0    
			SET @In_mt = CURSOR FAST_FORWARD FOR    
			 	SELECT 
			 		[ID],     
					[Qty],     
					[Date],       
					[MatUnitName],
					[BillGUID],     
					[BillType],    
					[BiGuid],
					[BillNotes]
				FROM      
					[#In_Result]     
				WHERE      
					[MatPtr] = @mtNumber   
				ORDER BY
					[ID] 
				----------------------------------------------------------------    
				OPEN @In_mt FETCH NEXT FROM @In_mt INTO  @Id,@biQnt, @biDate, @MatUnitName, @BillGUID, @BillType, @BiGuid, @BillNotes      
				WHILE @@FETCH_STATUS = 0      
				BEGIN
				------------------------------------------------------------    
					IF @mtSumQntOut >= @biQnt    
						UPDATE    
								[#In_Result] SET [Remaining] = 0
							WHERE    
								[ID] = @Id   
			     	ELSE 
					BEGIN 
					IF( EXISTS(SELECT * FROM  AGES000 WHERE Type = 1 OR Type = 3 and RefGUID=@mtNumber))
						UPDATE [#In_Result] SET [Qty] = ( @biQnt + @mtSumQntOut) WHERE [ID] = @Id
					ELSE 
						UPDATE [#In_Result] SET [Remaining] = ( @biQnt - @mtSumQntOut) WHERE [ID] = @Id
					END
					
					SET @mtSumQntOut = @mtSumQntOut - @biQnt

					
					IF @mtSumQntOut < 0 BREAK    
					FETCH NEXT FROM @In_mt INTO @Id, @biQnt, @biDate, @MatUnitName, @BillGUID, @BillType,@BiGuid, @BillNotes    
				END      
				CLOSE @In_mt  
				DEALLOCATE @In_mt    
				FETCH NEXT FROM @Out_mt INTO @mtNumber, @mtSumQntOut       
			END    
			CLOSE @Out_mt      
			DEALLOCATE @Out_mt   
	
		IF @ShowEmpty = 0
			delete from #In_Result where Remaining = 0
		IF(@ShowEmpty=1)
			BEGIN  
				INSERT INTO [#In_Result]([MatPtr]) SELECT [mtNumber] FROM [#Mat] WHERE [mtNumber] NOT IN (SELECT [MatPtr] FROM [#In_Result])
			END
		
		IF ( NOT EXISTS( SELECT * FROM #In_Result))
			INSERT INTO #Final_Result
			(
								[MatPtr],
								[Qty] , 
								[Date] , 
								[Remaining] , 
								[Age] 
		    ) 
			SELECT
					[t].[MatPtr],     
					0 as Qty,     
					'' as Date,  
					abs([t].[Qty]) as Remaining,     
					0 as Age 
			FROM #OUTQTY [t]

			ELSE 
			BEGIN 
				INSERT INTO #Final_Result
				SELECT * FROM #In_Result
			END 

		CREATE TABLE [#t]([MatPtr] [UNIQUEIDENTIFIER], [ExpireDate] [DATETIME] )
		DECLARE     
			@PeriodCounter [INT],     
			@PeriodStart [INT],     
			@PeriodEnd [INT]    
		SET @PeriodCounter = 0         
		DECLARE @SQL AS [NVARCHAR](max)    
		DECLARE @SumSQL AS [NVARCHAR](max)   
		IF @Detailed = 0      
		BEGIN          
			SET @SumSQL = ''    
			SET @SQL = ' ALTER TABLE [#t] ADD     
					[TotalRemainingPrice] [FLOAT],      
					[TotalRemainingQnt] [FLOAT],     
					[MatUnitName] [NVARCHAR](256) COLLATE ARABIC_CI_AI'    
			WHILE @PeriodCounter < @NumOfPeriods     
			BEGIN      
				SET @SQL = @SQL + ', [Period' + CAST((@PeriodCounter+1) AS [NVARCHAR](5)) + '] [FLOAT]'       
				SET @SQL = @SQL + ', [Price' + CAST((@PeriodCounter+1) AS [NVARCHAR](5)) + '] [FLOAT]'  
				SET @SQL = @SQL + ', [Cost' + CAST((@PeriodCounter+1) AS [NVARCHAR](5)) + '] [FLOAT]'      
				    
				SET @PeriodStart = @PeriodCounter * @PeriodLength     
				SET @PeriodEnd = @PeriodStart + @PeriodLength     
				    
				IF @PeriodCounter = (@NumOfPeriods-1)
					SET @SumSQL = @SumSQL +  ', ISNULL((SELECT SUM( [Remaining])      
								FROM     
									[#In_Result] [t_inner]     
								WHERE     
									[t_inner].[MatPtr] = [t_outer].[MatPtr]     
									AND [t_inner].[Age] >' + CAST(@PeriodStart AS [NVARCHAR](5)) + '), 0)'     
	
					 			+	
								', ISNULL((SELECT SUM( [Price] * [Remaining])
								FROM     
									[#In_Result] [t_inner]     
								WHERE     
									[t_inner].[MatPtr] = [t_outer].[MatPtr]     
									AND [t_inner].[Age] > ' + CAST(@PeriodStart AS [NVARCHAR](5)) + '), 0)'  
								+
								', ISNULL((SELECT SUM([APrice] * [Remaining])
								FROM     
									[#In_Result] [t_inner] INNER JOIN [#t_Prices] [avgPrice] ON [t_inner].[MatPtr]=[avgPrice].[mtNumber]
								WHERE     
									[t_inner].[MatPtr] = [t_outer].[MatPtr]     
									AND [t_inner].[Age] > ' + CAST(@PeriodStart AS [NVARCHAR](5)) + '),0)'
									    
				ELSE     
				BEGIN     
					IF @PeriodCounter = 0     
						SET @SumSQL = @SumSQL +  ', ISNULL((SELECT SUM([Remaining])     
									FROM     
										[#In_Result] [t_inner]     
									WHERE 	[t_inner].[MatPtr] = [t_outer].[MatPtr]     
										AND ( [t_inner].[Age] = 0 OR ( [t_inner].[Age] > ' + CAST(@PeriodStart AS [NVARCHAR](5))      
										+ 'AND [t_inner].[Age] <= ' + CAST(@PeriodEnd AS [NVARCHAR](5)) + '))), 0)'     
									+ 
									', ISNULL((SELECT SUM([Price] * [Remaining])
									FROM     
										[#In_Result] [t_inner] '     
									+ ' WHERE     
										[t_inner].[MatPtr] = [t_outer].[MatPtr]'     
										+ ' AND ( [t_inner].[Age] = 0 OR ( [t_inner].[Age] > ' + CAST(@PeriodStart AS [NVARCHAR](5))      
										+ ' AND [t_inner].[Age] <= ' + CAST(@PeriodEnd AS [NVARCHAR](5)) + '))), 0)'   
										+
									', ISNULL((SELECT SUM([APrice] * [Remaining])
									FROM     
										[#In_Result] [t_inner] INNER JOIN [#t_Prices] [avgPrice] ON [t_inner].[MatPtr]=[avgPrice].[mtNumber]'     
									+ ' WHERE     
										[t_inner].[MatPtr] = [t_outer].[MatPtr]'     
										+ ' AND ( [t_inner].[Age] = 0 OR ( [t_inner].[Age] > ' + CAST(@PeriodStart AS [NVARCHAR](5))      
										+ ' AND [t_inner].[Age] <= ' + CAST(@PeriodEnd AS [NVARCHAR](5)) + '))), 0)' 
					ELSE     
						SET @SumSQL = @SumSQL +  ' , ISNULL((SELECT SUM([Remaining]) FROM [#In_Result] [t_inner] WHERE [t_inner].[MatPtr] = [t_outer].[MatPtr] AND [t_inner].[Age] > ' + CAST(@PeriodStart AS [NVARCHAR](5)) + ' AND t_inner.Age <= ' + CAST(@PeriodEnd AS [NVARCHAR](5)) + '), 0)'     
						+ ' , ISNULL((SELECT SUM([Price] * [Remaining])
						FROM [#In_Result] [t_inner] WHERE [t_inner].[MatPtr] = [t_outer].[MatPtr] AND [t_inner].[Age] > ' + CAST(@PeriodStart AS [NVARCHAR](5)) + ' AND [t_inner].[Age] <= ' + CAST(@PeriodEnd AS [NVARCHAR](5)) + '), 0)'     
						+
						  ',ISNULL((SELECT SUM([APrice] * [Remaining])
						FROM [#In_Result] [t_inner] INNER JOIN [#t_Prices] [avgPrice] ON [t_inner].[MatPtr]=[avgPrice].[mtNumber] WHERE [t_inner].[MatPtr] = [t_outer].[MatPtr] AND [t_inner].[Age] > ' + CAST(@PeriodStart AS [NVARCHAR](5)) + ' AND [t_inner].[Age] <= ' + CAST(@PeriodEnd AS [NVARCHAR](5)) + '), 0)' 
				END      
				SET @PeriodCounter = @PeriodCounter + 1    
			END      
			EXEC( @SQL) 
			DECLARE @SqlInsert AS [NVARCHAR](max)     
			SET @SqlInsert =  ' INSERT INTO [#t] SELECT [MatPtr], [ExpireDate], SUM([Price] * [Remaining]), SUM([Remaining]), [MatUnitName] ' + @SumSQL + ' FROM [#In_Result] [t_outer] GROUP BY [MatPtr], [MatUnitName], [ExpireDate]'    
			EXEC( @SqlInsert)    
			SET @SQL = 
			'SELECT 
					[mt].[barcode] mtbarcode, [mt].[barcode2] mtbarcode2, [mt].[barcode3] mtbarcode3, [mt].[VAT] mtVAT, [mt].[spec] mtspec, [mt].[qty] mtqty, [mt].[origin] mtorigin, [mt].[company] mtcompany, [mt].[type] mttype, [mt].[model] mtmodel, [mt].[quality] mtquality, [mt].[color] mtcolor, [mt].[pos] mtpos, [mt].[dim] mtdim, [mt].[Provenance] mtProvenance,
					[mt].[Code] AS [MatCode], 
					[mt].[Name] AS [MatName] , 
					[mt].[LatinName] AS [MatLatinName] , 
					[gr].[grCode] AS [grCode],
					[gr].[grName] AS [grName],
					[tb].* 
				FROM 
					[#t] AS [tb] 
					INNER JOIN [mt000] AS [mt] ON [tb].[MatPtr] = [mt].[GUID] 
					INNER JOIN [vwGr] AS [gr] ON [mt].[GroupGUID] = [gr].[grGuid] 
				ORDER BY [MatCode],'
			
			SET @SQL = @SQL + 
				'[tb].[MatPtr] '
			-- SELECT [mt].[Code] AS [MatCode], [mt].[Name] AS [MatName] , [mt].[LatinName] AS [MatLatinName] , [tb].* FROM [#t] AS [tb] INNER JOIN [mt000] AS [mt] ON [tb].[MatPtr] = [mt].[GUID] ORDER BY [tb].[MatPtr]    
		END      
		ELSE      
		BEGIN 
				SET @PeriodCounter  = 0
				EXEC('INSERT INTO [#t] SELECT [MatPtr], [ExpireDate] FROM [#In_Result] GROUP BY [MatPtr], [MatUnitName], [ExpireDate]')
				SET @SQL = 'ALTER TABLE [#t] ADD [DummyCol] [FLOAT]'    
				WHILE @PeriodCounter < @NumOfPeriods   
				BEGIN      
				SET @SQL = @SQL + ',[Period' + CAST((@PeriodCounter+1) AS [NVARCHAR](5)) +'] [FLOAT]'  
				SET @PeriodCounter = @PeriodCounter + 1    
				END    
			 EXEC( @SQL)
			SET @SQL = 
			'
			SELECT    
				[mt].[mtbarcode], [mt].[mtbarcode2], [mt].[mtbarcode3],[mt].[mtVAT], [mt].[mtspec], [mt].[mtqty], [mt].[mtorigin], [mt].[mtcompany], [mt].[mttype], [mt].[mtmodel], [mt].[mtquality], [mt].[mtcolor], [mt].[mtpos], [mt].[mtdim], [mt].[mtProvenance],     
				--t.Remaining * t.Price AS Price,
				ISNULL([t].[Price], 0) Price,
				[t].[Qty],     
				[t].[Date],  
				ISNULL([t].[Remaining], 0) Remaining,    
				[t].[Age] ,   
				[t].[MatUnitName],     
				[t].[BillGUID] AS [BillNum],     
				[t].[BillType],    
				[t].[BillNotes],
				[mt].[mtCode] AS [MatCode],     
				[mt].[mtName] AS [MtName], 
				[mt].[mtLatinName] AS [MatLatinName], 
				[gr].[grCode] AS [grCode],
				[gr].[grName] AS [grName],
				[bt].[btName] AS [BillName], 
				[bt].[btLatinName] AS [LatinBillName] ,
				ISNULL([avgPrice].[APrice], 0) AS [APrice],
				[tb].*
			FROM     
				[#Final_Result] AS [t] 				
				LEFT JOIN [#t] AS [tb]  ON [tb].[MatPtr]=[t].[MatPtr]
				LEFT JOIN [#t_Prices] AS [avgPrice] ON [avgPrice].[mtNumber] = [t].[MatPtr]
				LEFT JOIN [vwBt] AS [bt] ON [t].[BillType] = [bt].[btGuid] 		
				INNER JOIN [vwMt] AS [mt] ON [t].[MatPtr]   = [mt].[mtGUID]
				INNER JOIN [vwGr] AS [gr] ON [mt].[mtGroup] = [gr].[grGuid]

			ORDER BY  [MatCode],'
			SET @SQL = @SQL +'[MatPtr],[Date] '

		END		
		EXEC( @SQL)
		
		SELECT COUNT(*) AS ExcludedMatsCount FROM #bu WHERE biMatPtr NOT IN(SELECT MatPtr FROM #In_Result)
   		-----------------------------
		SELECT * FROM [#SecViol]
		--SET TRANSACTION ISOLATION LEVEL READ COMMITTED 
/*
prcConnections_add2 'test'
exec   [repGetAges_bi] '00000000-0000-0000-0000-000000000000', '8ca507b0-4939-4a79-b999-d0e046c7e84b', '00000000-0000-0000-0000-000000000000', '10/25/2008', 1, 3, 30, 0, 3, 'e8e66a6e-2262-4dd2-bd71-e63fe58a8eba', 1.000000, '6e7c155e-6566-4877-840e-583260d68ca4', 0, 0, 0, '00000000-0000-0000-0000-000000000000'
*/
################################################################################
#END
