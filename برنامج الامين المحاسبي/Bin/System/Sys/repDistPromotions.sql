##############################################
CREATE PROCEDURE repDistPromotions
	@SalesManGuid		[UNIQUEIDENTIFIER],
	@StartDate		[DATETIME],
	@EndDate		[DATETIME],
	@Cond 			[INT] = -1, 	-- -1 NONE 0 Sure      1 NotSure
	@Order			[INT] =  0, 	-- -1 NONE 0 PROMOTION 1 SALES MAN
	@HiGuid			[UNIQUEIDENTIFIER] = 0X0,
	@Promotion		[UNIQUEIDENTIFIER] = 0X0
AS 
	SET NOCOUNT ON
	CREATE TABLE [#SecViol] ( [Type] 	[INT], 		    [Cnt] 	 [INT] ) 
	CREATE TABLE [#Mat]	( [MatGUID] 	[UNIQUEIDENTIFIER], [mtSecurity] [INT] ) 
	CREATE TABLE [#BillType]( [Type] 	[UNIQUEIDENTIFIER], [Security]   [INT], [ReadPriceSecurity] 	[INT], 		    [UnPostedSecurity] 	[INT] )     
	CREATE TABLE [#Cost]	( [CostGUID] 	[UNIQUEIDENTIFIER], [Security]   [INT], [SalesManGuid] 		[UNIQUEIDENTIFIER], [DistGuid] 		[UNIQUEIDENTIFIER])

	INSERT INTO [#Mat]	EXEC [prcGetMatsList] 0X0, 0X0 
	INSERT INTO [#BillType]	EXEC [prcGetBillsTypesList2] 0X0 	
	INSERT INTO [#Cost]
		SELECT [co].[Guid], [co].[Security], [sm].[Guid], [d].[Guid]
		FROM [Co000]	AS [Co]
			INNER JOIN [DistSalesman000] 	AS [sm] ON [co].[Guid] = [sm].[CostGUID]
			INNER JOIN [Distributor000] 	AS [D]  ON [sm].[Guid] = CASE [d].[CurrSaleMan] WHEN 1 THEN [d].[PrimSalesmanGUID] ELSE [d].[AssisSalesmanGUID] END
			INNER JOIN dbo.fnGetHierarchyList (@HiGuid, 0) AS [Hi] On [Hi].[Guid] = [d].[HierarchyGuid]
		WHERE 	([hi].[Guid] = @HiGuid OR @HiGuid = 0x00) 	AND
			([sm].[Guid] = @SalesManGuid OR @SalesManGuid = 0x00)

	CREATE TABLE [#Cust]( [Guid] 	[UNIQUEIDENTIFIER], [Security]   [INT], [FromDate] [DATETIME], [CustTypeGuid] [UNIQUEIDENTIFIER], [TradeChannelGuid] [UNIQUEIDENTIFIER] )
	INSERT INTO [#Cust] ( [Guid], [Security]) EXEC prcGetDistGustsList 0X0, 0X0, 0x00, @HiGuid    
	UPDATE [#Cust] 
		SET 	[CustTypeGuid]     = [Ce].[CustomerTypeGuid],
			[TradeChannelGuid] = [Ce].[TradeChannelGuid]
	FROM [#Cust] AS [Cu] INNER JOIN [DistCe000] AS [Ce] ON [Cu].[Guid] = [Ce].[CustomerGuid]
------------------------------------------------------------------------------------------
	CREATE TABLE [#Bill] 
			( 
				[buGuid] 		[UNIQUEIDENTIFIER],
				[buDate] 		[DATETIME],
				[buNumber]		[INT],
				[buFormatedNumber] 	[NVARCHAR](100) COLLATE ARABIC_CI_AI,
				[Security] 		[INT], 
				[TotalQty] 		[FLOAT], 
				[TotalBonusQnt] 	[FLOAT],
				[CustGuid]		[UNIQUEIDENTIFIER],
				[CostGuid]		[UNIQUEIDENTIFIER],
				[DistGuid]		[UNIQUEIDENTIFIER]
			)
	-- THIS TABLE INCLUDES THE BILLS THAT ARE WITHIN THE DEFINED RANGE OF DATE
	-- AND HAVE BONUS
	INSERT INTO [#Bill]	
		SELECT  DISTINCT
			[bu].[buGuid], [bu].[buDate], [bu].[buNumber], [bu].[buFormatedNumber], [bu].[buSecurity], 0, 0,	
			ISNULL([bu].[buCustPtr], 0x00),  ISNULL([bu].[buCostPtr], 0x00),  ISNULL([Co].[DistGuid], 0x00)
		FROM [vwBuBi] AS [bu]
			LEFT JOIN [#Cost] AS [Co] ON [Co].[CostGuid] = [bu].[buCostPtr]
		WHERE 
			( [buDate] BETWEEN @StartDate AND @EndDate )	AND 
			( [Co].[SalesManGuid] = @SalesManGuid OR @SalesManGuid = 0x00)	AND
			( [btIsOutput] = 1) 	AND 
			( [biBonusQnt] > 0)
		GROUP By 
			[buGuid], [buDate], [buNumber], [buFormatedNumber], [buSecurity], 
			[buCustPtr], [buCostPtr], [DistGuid]
	-- THIS UPDATE FILLS THE BILL TOTAL BONUS QUANTITY AND TOTAL PURCHASED QUANTITY
	UPDATE [bi] SET [TotalQty] = [s].[TotalQty], [TotalBonusQnt] = [s].[TotalBonusQnt]
	FROM [#Bill] AS [bi] 
		INNER JOIN (SELECT SUM([biQty]) AS [TotalQty], SUM([biBonusQnt]) AS [TotalBonusQnt], [buGuid] FROM [vwbubi] GROUP By [buGuid]) AS [s] ON [s].[buGuid] = [bi].[buGuid]
	-- NOW #BILL CONTAINS ALL THE BILL THAT HAVE BONUS ALONG WITH THEIR TOTAL QUANTITY
	-- AND THEIR TOTAL BONUS QUANTITY
------------------------------------------------------------------------------------------
	CREATE TABLE #BillPromotions			-- Promotions 
			(
				[buGuid]		[UNIQUEIDENTIFIER], 
				[ReqProGuid]		[UNIQUEIDENTIFIER],    	-- Promotion Requierd Guid
				[ReqCondQty]		[FLOAT],
				[ReqFreeQty]		[FLOAT],
				[ReqProTotal]		[FLOAT],
				[GivenProGuid]		[UNIQUEIDENTIFIER],    	-- Promotion Requierd Guid
				[GivenCondQty]		[FLOAT],
				[GivenFreeQty]		[FLOAT],
				[GivenProTotal]		[FLOAT],
				[ProResProKind]		[BIT],			-- Promotion Result: Promotion Kind			 
				[ProResDate]		[BIT],			
				[ProResCondQty]		[BIT],
				[ProResFreeQty]		[BIT],
				[ProResCustType]	[BIT],
				[ProResDistBudg]	[BIT],
				ReqQuantityUnit		int,
				ReqBonusUnit		int
			)
	CREATE TABLE #BillDetail
			(
				[buGuid] 		[UNIQUEIDENTIFIER], 
				[mtGuid]		[UNIQUEIDENTIFIER], 
				[biQty]			[FLOAT],
				[biBonusQnt]		[FLOAT],
				[Type]			[INT]		-- 0 mt With Qty , 1 mt With Bonus
			)

	DECLARE	@CBill			CURSOR,
		@buGuid			UNIQUEIDENTIFIER,
		@CustGuid		UNIQUEIDENTIFIER,
		@DistGuid		UNIQUEIDENTIFIER,
		@buDate			DATETIME,
		@buTotalQty		FLOAT,
		@buTotalBonusQnt	FLOAT
	DECLARE @CPro			CURSOR,
		@PrGuid			UNIQUEIDENTIFIER,
		@FDate			DATETIME,
		@LDate			DATETIME,
		@CondQty		FLOAT,
		@FreeQty		FLOAT,
		@biQty			FLOAT,
		@prQty			FLOAT,
		@CondType		INT,
		@FreeType		INT,
		@QuantityUnit	INT,
		@BonusUnit		INT
	DECLARE	@TotalQty		FLOAT,
		@TotalBonusQnt		FLOAT,
		@TotalProCount		INT,	
		@ProCount		INT,	
		@Count1			INT,	
		@Count2			INT,
		@GivenProState		BIT,
		@ReqProState		BIT,
		@GivenProNumber		FLOAT,
		@ReqProNumber		FLOAT,
		@ProResProKind		BIT,			-- Promotion Result: Promotion Kind			 
		@ProResDate		BIT,			
		@ProResCondQty		BIT,
		@ProResFreeQty		BIT,
		@ProResCustType		BIT,
		@ProResDistBudg		BIT

-----------------------------------------------------------------------------------------
	EXEC [prcCheckSecurity] @result = '#Bill'
	SET @CBill = CURSOR FAST_FORWARD FOR
		SELECT [buGuid], [buDate], [CustGuid], [DistGuid], [TotalQty], [TotalBonusQnt] 	FROM #Bill
	OPEN @CBill FETCH @CBill INTO @buGuid, @buDate, @CustGuid, @DistGuid, @buTotalQty, @buTotalBonusQnt
	-- THIS WHILE MEANS FOR EACH RECORD (WHICH IS A BILL) FROM #BILL DO
	WHILE @@FETCH_STATUS = 0
	BEGIN
		TRUNCATE TABLE [#BillDetail]
		
		INSERT INTO [#BillDetail]
			SELECT [buGuid], [biMatPtr], [biQty], 0, 0 FROM [vwBuBi] WHERE [buGuid] = @buGuid AND [biQty] > 0

		INSERT INTO [#BillDetail]
			SELECT [buGuid], [biMatPtr], 0, [biBonusQnt], 1 FROM [vwBuBi] AS [bu]	WHERE [buGuid] = @buGuid AND [biBonusQnt] > 0
		-- #BILLDETAIL HOLDS THE DETAILS OF THE BILL BEING ITERATED 
		-- THE DETAILS ARE: BILLGUID, PURCHASED MATERIALS AND PROMOTION MATERIALS GUIDS, MATERIAL, PURCHASED MATERIAL QUANTITY, BONUS MATERIAL QUANTITY, TYPE
		-- FIELD [#BILLDETAIL].[TYPE] = 0 IF THE RECEORD REFERS TO A PURCHASED MATERIAL AND = 1 IF THE RECORD REFERS TO A PROMOTION MATERIAL
	--------------------------------------------------------------------------
		IF NOT EXISTS (	SELECT [Guid], [FDate], [LDate], [CondQty], [FreeQty] FROM [DistPromotions000] 	WHERE @buDate BETWEEN [FDate] AND [LDate] )
		BEGIN
			INSERT INTO [#BillPromotions] ( buGuid, ReqProGuid, ReqCondQty, ReqFreeQty, ReqProTotal, GivenProGuid, GivenCondQty, GivenFreeQty, GivenProTotal, ProResProKind, ProResDate, ProResCondQty, ProResFreeQty, ProResCustType, ProResDistBudg, ReqQuantityUnit, ReqBonusUnit)
					       VALUES (	@buGuid, 0x00, 0, 0, 0,	0x00 , @buTotalQty, @buTotalBonusQnt, 1, 0, 0, 0, 0, 0, 0, 0, 0)
		END
		ELSE
		BEGIN
			-- @TotalProCount IS THE NUMBER PROMOTIONS THAT ARE DEFINED WITHIN THE DATE RANGE
			SELECT @TotalProCount = COUNT([Number]) FROM DistPromotions000 WHERE @buDate BETWEEN [FDate] AND [LDate]
			SET @ProCount = 0
			SET @CPro = CURSOR FAST_FORWARD FOR 
				SELECT Guid, FDate, LDate, CondQty, FreeQty, CondType, FreeType, CondUnity, FreeUnity
				FROM DistPromotions000 
				WHERE @buDate BETWEEN FDate AND LDate
				ORDER BY Number
			OPEN @CPro FETCH @CPro INTO @PrGuid, @FDate, @LDate, @CondQty, @FreeQty , @CondType , @FreeType, @QuantityUnit, @BonusUnit
			-- THIS WHILE MEANS FOR EACH RECORD (WHICH IS A PROMOTION WITH DATE INTERSECTS WITH THE DATE OF THE BILL BEING ITERATED ) FROM DistPromotions000 DO
			WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @TotalQty		= 0
				SET @TotalBonusQnt	= 0
				SET @GivenProState 	= 0
				SET @ReqProState 	= 0
				SET @ProResProKind 	= 0		
				SET @ProResDate		= 0
				SET @ProResCondQty	= 0	
				SET @ProResFreeQty	= 0
				SET @ProResCustType	= 0
				SET @ProResDistBudg	= 0
	
				SET @ProCount = @ProCount + 1
				SELECT @Count1 = COUNT([Type]) FROM [#BillDetail] WHERE [Type] = 1
				-- @COUNT1 NOW HOLDS THE NUMBER OF RECORDS THAT REFER TO PROMOTION MATERIALS 
				-- OF THE CURRENT BILL BEING ITERATED
				IF @Count1 > 0 
				BEGIN   
					----------------------------   «· Õﬁﬁ „‰ ‘—Êÿ «·⁄—÷
					-- @Count1 HOLDS THE COUNT OF RECORDS THAT ARE RECEORDED AS BONUS ( [pr].[Type] = 1 )AND SHARED IN BOTH
					-- THE BILL AND THE PROMOTION. @TotalBonusQnt HOLDS THE BONUS MATERIAL QUANTITY SUM OF THESE RECEORDS
					SELECT @Count1 = COUNT([bi].[Type]), 
						   @TotalBonusQnt = ISNULL(SUM(CASE @FreeType WHEN 0 THEN biBonusQnt 
																	  ELSE CASE @BonusUnit WHEN 2 THEN biBonusQnt / CASE WHEN ISNULL(mt.Unit2Fact, 0) <> 0 THEN mt.Unit2Fact ELSE 1 END 
																						   WHEN 3 THEN biBonusQnt / CASE WHEN ISNULL(mt.Unit3Fact, 0) <> 0 THEN mt.Unit2Fact ELSE 1 END 
																						   ELSE biBonusQnt
																		   END				
														END), 0)
					FROM [#BillDetail] AS [bi] 
						INNER JOIN [DistPromotionsDetail000] AS [pr] ON	(([pr].MatType = 0 AND [pr].[matGuid] = [bi].[mtGuid]) OR ([pr].MatType = 1 AND [bi].[mtGuid] IN (SELECT GUID FROM mt000 WHERE GroupGUID = [pr].[matGuid])))
																		 AND [pr].[Type] = [bi].[Type] AND ((@FreeType = 0 And [pr].MatType = 0 AND [biBonusQnt] > = [pr].[Qty]) OR (@FreeType = 0 And [pr].MatType = 1) OR (@FreeType = 1))
						INNER JOIN mt000 as mt ON mt.GUID = bi.mtGuid
					WHERE 	
						[pr].[ParentGuid] = @PrGuid AND [pr].[Type] = 1

					-- @Count2 HOLDS THE TOTAL COUNT OF RECORDS THAT ARE RECEORDED AS BONUS IN THE PROMOTION.
					SELECT @Count2 = COUNT([Number]) FROM [DistPromotionsDetail000] WHERE [Type] = 1 AND [Qty] > 0 AND [ParentGuid] = @PrGuid

					--IF (@Count1 >= @Count2) AND (@TotalBonusQnt >= @FreeQty)
					IF ((@TotalBonusQnt >= @FreeQty AND @Count1 >= @Count2 AND @FreeType = 0) OR (@TotalBonusQnt >= @FreeQty AND @FreeType = 1))
					BEGIN
						SET @GivenProState = 1		-- l «·Õ”„ «·„⁄ÿÏ
						-- @GivenProNumber HOLDS HOW MANY PROMOTION OF THIS TYPE THIS BILL CONTAINS
						SET @GivenProNumber = @TotalBonusQnt / @FreeQty
						
						-- @Count1 HOLDS THE COUNT OF RECORDS THAT ARE RECEORDED AS CONDITIONAL ( [pr].[Type] = 0 )AND SHARED IN BOTH
						-- THE BILL AND THE PROMOTION. @TotalQty HOLDS THE CONDITIONAL MATERIAL QUANTITY SUM OF THESE RECEORDS
						SELECT @Count1 = COUNT([bi].[Type]), 
							   @TotalQty = ISNULL(SUM(CASE @CondType WHEN 0 THEN biQty
																	 ELSE CASE @QuantityUnit WHEN 1 THEN biQty / CASE WHEN ISNULL(mt.Unit2Fact, 0) <> 0 THEN mt.Unit2Fact ELSE 1 END 
																							 WHEN 2 THEN biQty / CASE WHEN ISNULL(mt.Unit3Fact, 0) <> 0 THEN mt.Unit2Fact ELSE 1 END 
																							 ELSE biQty
												  END				
											 END), 0) 
						FROM [#BillDetail] AS [bi] 
							INNER JOIN [DistPromotionsDetail000] AS [pr] ON	(([pr].MatType = 0 AND [pr].[matGuid] = [bi].[mtGuid]) OR ([pr].MatType = 1 AND [bi].[mtGuid] IN (SELECT GUID FROM mt000 WHERE GroupGUID = [pr].[matGuid]))) 
																			AND [pr].[Type] = [bi].[Type] AND ((@CondType = 0 AND [pr].MatType = 0 AND [biQty] > = [pr].[Qty]) OR (@CondType = 0 And [pr].MatType = 1) OR (@CondType = 1))
							INNER JOIN mt000 as mt ON mt.GUID = bi.mtGuid
						WHERE 	
							[pr].[ParentGuid] = @PrGuid AND [pr].[Type] = 0

		                -- @Count2 HOLDS THE TOTAL COUNT OF RECORDS THAT ARE RECEORDED AS CONDITIONAL IN THE PROMOTION. 
						SELECT @Count2 = COUNT([Number]) FROM [DistPromotionsDetail000] WHERE [Type] = 0 AND [Qty] > 0 AND [ParentGuid] = @PrGuid
	
						--IF (@Count1 >= @Count2 ) AND (@TotalQty >= @CondQty)
						IF ((@TotalQty >= @CondQty AND @Count1 >= @Count2 AND @CondType = 0) OR (@TotalQty >= @CondQty AND @CondType = 1))
						BEGIN
							SET @ReqProState = 1 		
							SET @ReqProNumber = @TotalQty / @CondQty
						END
						ELSE
						BEGIN
							SET @ReqProState = 0
							SET @ReqProNumber = 0
						END
					END
					--ELSE
					--BEGIN
					--	SET @GivenProState = 0
					--	SET @GivenProNumber = 0
					--END
					
					IF @GivenProState = 1
					BEGIN
						-- NOW DELETNIG THE RECORDS TO NOT COUNT THEM AGAIN
						DELETE FROM [#BillDetail] 
						WHERE [mtGuid] IN 
							(	SELECT [MatGuid] FROM [DistPromotionsDetail000] AS [pr] 
								WHERE [pr].[MatGuid] = [mtGuid] AND [pr].[Type] = 1  AND [ParentGuid] = @PrGuid
							)
							AND Type = 1
						DELETE FROM [#BillDetail] 
						WHERE [mtGuid] IN 
							(	SELECT [MatGuid] FROM [DistPromotionsDetail000] AS [pr] 
								WHERE [pr].[MatGuid] = [mtGuid] AND [pr].[Type] = 0  AND [ParentGuid] = @PrGuid
							)
							AND Type = 0
	
						IF @buDate BETWEEN @FDate AND @LDate 
							SET @ProResDate	= 1 
	
						IF @ReqProState = 1 
						BEGIN 
							SET @ProResCondQty = 1 
							-- IF ROUND(@GivenProNumber, 0, 1) = ROUND(@ReqProNumber, 0, 1) 
							IF @GivenProNumber = @ReqProNumber
								SET @ProResFreeQty = 1 
							ELSE
							BEGIN
								IF ROUND(@GivenProNumber, 0, 1) = ROUND(@ReqProNumber, 0, 1) 	
								BEGIN
									IF @GivenProNumber < @ReqProNumber	
										SET @ProResFreeQty = 1 
									ELSE
										SET @ProResFreeQty = 0		
								END
								ELSE
									SET @ProResFreeQty = 0		
							END
						END 
											
						IF EXISTS (SELECT [Cu].[Guid] FROM [#Cust] AS [Cu] INNER JOIN [DistPromotionsCustType000] AS [pr] ON [pr].[CustTypeGuid] = [Cu].[CustTypeGuid] OR [pr].[CustTypeGuid] = [Cu].[TradeChannelGuid] WHERE [Cu].[Guid] = @CustGuid AND [pr].[ParentGuid] = @prGuid)
							SET @ProResCustType = 1
						IF EXISTS (SELECT [Guid] FROM [DistPromotionsBudget000] WHERE [ParentGuid] = @PrGuid AND [DistributorGuid] = @DistGuid)
							SET @ProResDistBudg = 1
	
						SET @ProResProKind = (@ProResCondQty & @ProResFreeQty & @ProResCustType ) -- & @ProResDate & @ProResDistBudg)
					END
					
					IF (@GivenProState = 1) OR (@ProCount = @TotalProCount)
					BEGIN						
						
						IF (@ProCount = @TotalProCount) AND (@TotalBonusQnt = 0)
							SELECT @TotalBonusQnt = ISNULL(SUM([biBonusQnt]),0) FROM [#BillDetail] AS [bi] 
	
						INSERT INTO [#BillPromotions] ( buGuid, 
										ReqProGuid, 
										ReqCondQty, 
										ReqFreeQty, 
										ReqProTotal, 
										GivenProGuid, 
										GivenCondQty, 
										GivenFreeQty, 
										GivenProTotal,	
										ProResProKind, 
										ProResDate, 
										ProResCondQty, 
										ProResFreeQty, 
										ProResCustType, 
										ProResDistBudg 
									    )			
								VALUES      (	@buGuid,       
										CASE @ReqProState WHEN 1 THEN @PrGuid 		ELSE 0x00 END,
										CASE @ReqProState WHEN 1 THEN @CondQty 		ELSE 0 END,
										CASE @ReqProState WHEN 1 THEN @FreeQty 		ELSE 0 END,
										CASE @ReqProState WHEN 1 THEN @ReqProNumber	ELSE 0 END,
										CASE @GivenProState WHEN 1 THEN @PrGuid ELSE 0x00 END,
									        @TotalQty, 
										@TotalBonusQnt,           
										CASE @GivenProNumber WHEN 0 THEN 1 ELSE @GivenProNumber END,
									        @ProResProKind,          
										@ProResDate,             
										@ProResCondQty,             
										@ProResFreeQty,              
										@ProResCustType,
										@ProResDistBudg
									     ) 
					END
					--------------------------------------------------------------
				END  -- IF @Count > 0 
				FETCH @CPro INTO @PrGuid, @FDate, @LDate, @CondQty, @FreeQty , @CondType , @FreeType, @QuantityUnit, @BonusUnit
			END  -- WHILE @@FETCH_STATUS = 0
			CLOSE @CPro DEALLOCATE @CPro 
		END -- ELSE IF NOT EXISTS  
	--------------------------------------------------------------------------
		FETCH @CBill INTO @buGuid, @buDate, @CustGuid, @DistGuid, @buTotalQty, @buTotalBonusQnt
	END		 
	CLOSE @CBill DEALLOCATE @CBill

-- select * from #BillPromotions
	SELECT  
		[bu].[buGuid],
		[bu].[buDate],
		[bu].[buNumber], 	
		[bu].[buFormatedNumber],
		ISNULL([bu].[CustGuid], 0x00)	AS CustGuid,
		ISNULL([Cu].[CustomerName], '')	AS CustName,
		ISNULL([Cu].[LatinName], '')	AS CustLatinName,
		ISNULL([bu].[CostGuid], 0x00)	AS CostGuid,
		ISNULL([Co].[Code], '')		AS CostCode,
		ISNULL([Co].[Name], '')		AS CostName,
		ISNULL([Co].[LatinName], '')	AS CostLatinName,
		ISNULL([bu].[DistGuid], 0x00)	AS DistGuid,
		ISNULL([D].[Code], '')		AS DistCode,
		ISNULL([D].[Name], '')		AS DistName,
		ISNULL([D].[LatinName], '')	AS DistLatinName,
		ISNULL([S].[Guid], 0x00)	AS SalesManGuid,
		ISNULL([S].[Code], '')		AS SalesManCode,
		ISNULL([S].[Name], '')		AS SalesManName,
		ISNULL([S].[LatinName], '')	AS SalesManLatinName,
		[bipr].[ReqProGuid],
		[bipr].[ReqCondQty],
		[bipr].[ReqFreeQty],
		[bipr].[ReqProTotal],
		ISNULL([ReqPro].[Name], '')	AS ReqProName,		
		[bipr].[GivenProGuid],
		[bipr].[GivenCondQty],
		[bipr].[GivenFreeQty],
		[bipr].[GivenProTotal],
		ISNULL([GivPro].[Name], '')	AS GivenProName,
		[bipr].[ProResProKind],
		[bipr].[ProResDate],
		[bipr].[ProResCondQty],
		[bipr].[ProResFreeQty],
		[bipr].[ProResCustType],
		[bipr].[ProResDistBudg]
	FROM [#BillPromotions] 	AS [bipr]
		INNER JOIN [#Bill]		AS [bu] ON [bu].[buGuid] = [bipr].[buGuid]
		LEFT  JOIN [Cu000]		AS [Cu] ON [cu].[Guid] = [bu].[CustGuid]
		LEFT  JOIN [Co000]		AS [Co] ON [Co].[Guid] = [bu].[CostGuid]		
		LEFT  JOIN [#Cost]		AS [C]  ON [C].[CostGuid] = [Co].[Guid]	
		LEFT  JOIN [Distributor000] 	AS [D]  ON [D].[Guid] = [bu].[DistGuid]
		LEFT  JOIN [DistSalesman000]  	AS [S]  ON [S].[Guid] = [C].[SalesManGuid]
		LEFT  JOIN [DistPromotions000] 	AS [ReqPro]   ON [ReqPro].[Guid] = [bipr].[ReqProGuid]
		LEFT  JOIN [DistPromotions000] 	AS [GivPro]   ON [GivPro].[Guid] = [bipr].[GivenProGuid]
	WHERE 
		( (@Cond = -1 ) OR (@Cond = 0 AND [bipr].[ProResProKind] = 1) OR (@Cond = 1 AND [bipr].[ProResProKind] = 0) )	AND
		( (@Promotion = 0x00) OR ([bipr].[ReqProGuid] = @Promotion) OR ([bipr].[GivenProGuid] = @Promotion) )
	ORDER BY 
		buNumber

		
	SELECT * FROM [#SecViol]


/*			
prcConnections_Add2 '„œÌ—'
EXECUTE [repDistPromotions] '00000000-0000-0000-0000-000000000000', '1/1/2007', '12/31/2007', 0, 2, '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000'
*/
##############################################
CREATE PROCEDURE repDistPromotionsList 
      @StartDate        [DATETIME] = '01/01/1980',
      @EndDate          [DATETIME] = '01/01/1980',
      @DistributorGUID  [UNIQUEIDENTIFIER] = 0X0,
      @CustsCT          [UNIQUEIDENTIFIER] = 0x0,
      @MatGUID          [UNIQUEIDENTIFIER] = 0X0,
      @MatGrpGUID       [UNIQUEIDENTIFIER] = 0X0,
      @Active                 [INT] = -1        -- -1 Active&notactive, 1 Active, 0 Notactive
AS  
      SET NOCOUNT ON
      
      CREATE TABLE #Promotions
      (
            PromotionGUID           [UNIQUEIDENTIFIER],
            Code        [INT],
            FDate       [DATETIME],
            LDate       [DATETIME],
            Name        [NVARCHAR](100),
            CondQty           [FLOAT],
            FreeQty           [FLOAT],
            CondType    [INT],
            FreeType    [INT],
            IsActive    [INT],
            ChkExactlyQty [INT]
      )

      INSERT INTO #Promotions
            SELECT      DISTINCT 
                        dp.GUID AS ProGUID,
                        dp.Code,
                        dp.Fdate,
                        dp.LDate,
                        dp.Name,
                        dp.CondQty,
                        dp.FreeQty,
                        dp.CondType,
                        dp.FreeType,
                        dp.IsActive,
                        dp.ChkExactlyQty
            FROM  DistPromotions000 AS dp
            INNER JOIN  DistPromotionsDetail000 AS dpd
                        ON    dp.GUID = dpd.ParentGUID
                        AND	((@MatGUID <> 0x0 AND (dpd.MatGUID = @MatGUID OR @MatGUID IN (SELECT GUID FROM mt000
																							 WHERE GroupGUID = dpd.MatGUID)))
						OR	(@MatGrpGUID <> 0x0 AND (dpd.MatGUID = @MatGrpGUID OR dpd.MatGUID IN (SELECT GUID FROM mt000
																									WHERE GroupGUID = @MatGrpGUID)))
						OR	(@MatGUID = 0x0 AND @MatGrpGUID = 0x0))
            INNER JOIN  DistPromotionsBudget000 AS dpb
                        ON    dp.GUID = dpb.ParentGUID
                        AND (dpb.DistributorGUID = @DistributorGUID AND dpb.RealPromQty < dpb.Qty)
						OR @DistributorGUID = 0x0 
            INNER JOIN  DistPromotionsCustType000 AS dpc ON dpc.ParentGUID = dp.GUID 
            INNER JOIN RepSrcs AS rs ON rs.IdType = dpc.CustTypeGUID AND rs.IdTbl = @CustsCT      
            WHERE 
                        ( @Active = dp.IsActive OR @Active = -1 )
                        AND ((dp.FDate BETWEEN @StartDate AND @EndDate) OR (dp.LDate BETWEEN @StartDate AND @EndDate))

      SELECT * FROM #Promotions ORDER BY Code

################################################################################
#END