########################################
CREATE  PROC repDistBillDiscounts
	@StartDate 			[DATETIME],
	@EndDate 			[DATETIME],
	@AccGUID 			[UNIQUEIDENTIFIER],
	@CostGUID 			[UNIQUEIDENTIFIER],
	@GroupFlag			[INT],				-- 0 No Group, 1 Group
	@GroupType			[INT],				-- 0 Group by Cost, 1 Group by Cust, 2 Group By Bill, 3 Group By Disc, 
	@SrctypesGUID		[UNIQUEIDENTIFIER],
	@CustType			[INT] = 0,			-- 1 Contracted, 2 Not Contracted, 0 Both
	@bShowCustType		[INT] = 0,
	@IdenticalDisc		[INT] = 0			-- 0 ALL,	1 Identical,	2 UnIdentical
AS
	SET NOCOUNT ON

	CREATE TABLE [#SecViol]		( [Type] 	[INT], 		    [Cnt] 	   [INT] ) 
	CREATE TABLE [#BillsTypesTbl]	( [TypeGuid] 	[UNIQUEIDENTIFIER], [UserSecurity] [INT], [UserReadPriceSecurity] [INT] )
	CREATE TABLE [#CustTable]	( [cuGUID] 	[UNIQUEIDENTIFIER], [cuSec] 	   [INT] )
	CREATE TABLE [#CostTable]	( [GUID] 	[UNIQUEIDENTIFIER], [SalesManGuid] [UNIQUEIDENTIFIER], [DistGuid] 	[UNIQUEIDENTIFIER])

	INSERT INTO [#BillsTypesTbl] 	EXEC [prcGetBillsTypesList] @SrcTypesguid
	INSERT INTO [#CustTable] 	EXEC [prcGetCustsList] NULL, @AccGUID
	INSERT INTO [#CostTable] 
		SELECT [Co].[Guid], [Sm].[Guid], [Dr].[Guid] 
		FROM [dbo].[fnGetCostsList] (@CostGuid) AS Co
			INNER JOIN DistSalesMan000 	AS Sm ON Sm.CostGuid = Co.Guid
			INNER JOIN Distributor000 	AS Dr ON Sm.Guid = Dr.PrimSalesmanGUID -- Sm.Guid = (CASE CurrSaleMan WHEN 0 THEN Dr.PrimSalesmanGUID ELSE Dr.AssisSalesmanGUID END)

	IF ISNULL( @CostGUID, 0x0) = 0x0
		INSERT INTO [#CostTable] VALUES(0x00, 0x00, 0x00)
-----------------------------------------------------------------------    Bills
	CREATE TABLE #BillDisc 	(
					buGuid 		UNIQUEIDENTIFIER, 
					buNumber	INT,
					btAbbrev	NVARCHAR(100) COLLATE ARABIC_CI_AI,
					buDate		DATETIME,
					DistGuid 	UNIQUEIDENTIFIER, 
					CustGuid 	UNIQUEIDENTIFIER, 
					CostGuid 	UNIQUEIDENTIFIER, 
					DiscGuid	UNIQUEIDENTIFIER, 
					AccGuid		UNIQUEIDENTIFIER, 
					TotalBill	FLOAT,		-- TotalBill Used In Grouping
					buTotal		FLOAT,
					btIsOutput	FLOAT,
					RealDisc	FLOAT,		-- Real Discount In The Discount Bill
					ReqDisc		FLOAT,		-- Requierd Discount From Th DistDisc
					Flag		INT,		-- 0 BillDisc And CustDisc ,  1 ItemDisc  ,  2  BillDisc Not CustDisc
					Contracted	INT,		-- Cust State 
					CtdNumber	INT
				)

	INSERT INTO [#BillDisc]
		SELECT  DISTINCT
			[bu].[buGUID],	
			[bu].[buNumber],
			[vw].[btAbbrev],
			[bu].[buDate], 
			[Co].[DistGuid],
			ISNULL([Bu].[buCustPtr], 0X0), 
			ISNULL([Bu].[buCostPtr], 0X0),
			ISNULL([Ctd].[DiscGuid], 0x0), 
			ISNULL([di].[diAccount], 0X0),
			0,
			[bu].[buTotal],	
			[vw].[btIsOutput] ,
			CASE ISNULL([di].[diDiscount], 0) WHEN 0 THEN ISNULL([di].[diExtra], 0)*-1 ELSE [di].[diDiscount] END ,
			0,
			0,
			ISNULL([Ce].[Contracted], 0),
			ISNULL([Ctd].[CtdNumber], 0)
		FROM 
			[vwBu] 	AS	[bu]	
			INNER JOIN [vwBt] 		AS [vw]  ON [vw].[btGUID]       = [bu].[buType]
			LEFT  JOIN [vwDi]		AS [Di]	 ON [di].[diParent]     = [bu].[buGuid]
			INNER JOIN [#BillsTypesTbl] 	AS [bt]  ON [bu].[buType]       = [bt].[TypeGuid] 
			INNER JOIN [#CostTable] 	AS [co]  ON [bu].[buCostPtr]    = [co].[GUID]
			INNER JOIN [#CustTable] 	AS [cu]  ON [cu].[cuGUID]       = [bu].[buCustPtr]
			LEFT  JOIN [DistCe000] 		AS [Ce]  ON [Ce].[CustomerGuid] = [bu].[buCustPtr]
			LEFT  JOIN [vwDistCtd]		AS [Ctd] ON [Ctd].[DiscAccGuid] = [di].[diAccount] AND [Ce].[CustomerTypeGuid] = [Ctd].[CtGuid]
		WHERE 	
			[buDate] BETWEEN @StartDate AND @EndDate
			--AND buDate Between DiscStartDate AND DiscEndDate 
			AND
			( 
				(@CustType = 0) OR ((@CustType = 1) 
				AND ( ISNULL([Ce].[Contracted], 0) = 1 )
			) 
			OR 
			(
				((@CustType = 2)) 
				AND (ISNULL([Ce].[Contracted], 0) = 0))
			)
		ORDER By [bu].[buGuid]
-----------------------------------------------------------------------    CustDiscount
	CREATE TABLE #CustDisc 
		(
			CustGuid		UNIQUEIDENTIFIER,			
			CustTypeGuid		UNIQUEIDENTIFIER,			
			DiscGuid		UNIQUEIDENTIFIER,			
			PossibilityItemDisc	INT,			
			CalcType		INT,			
			DiscCode		NVARCHAR(500),			
			DiscName		NVARCHAR(500),			
			DiscLatinName		NVARCHAR(500),			
			GivingType		INT,			
			StartDate		DATETIME,			
			EndDate			DATETIME,			
			DiscAccGuid		UNIQUEIDENTIFIER,			
			OneTime			INT,			
			ChangeVal		INT,			
			DiscPercent		FLOAT,			
			DiscValue		FLOAT,			
			DiscCondValue		FLOAT,			
			DiscCondValueTo		FLOAT,				
			MatGuid			UNIQUEIDENTIFIER,			
			MatCond			UNIQUEIDENTIFIER,			
			GroupGuid		UNIQUEIDENTIFIER,
			CtdNumber		INT,
			AroundType		INT
		)

	DECLARE	@CMain			CURSOR,
		@buTotal		FLOAT,
		@btIsOutput		FLOAT,
		@RealDisc		FLOAT,
		@buDate			DATETIME,
		@buNumber		INT,	
		@btAbbrev		NVARCHAR(100) ,
		@buGuid			UNIQUEIDENTIFIER,
		@buCustPtr		UNIQUEIDENTIFIER,
		@buCostPtr		UNIQUEIDENTIFIER,
		@DistGuid		UNIQUEIDENTIFIER,
		@Contracted		INT

	DECLARE	@CDetail		CURSOR,
		@DiscGuid		UNIQUEIDENTIFIER,
		@DiscAccGuid		UNIQUEIDENTIFIER,
		@MatGuid		UNIQUEIDENTIFIER, 
		@MatCond		UNIQUEIDENTIFIER, 
		@GroupGuid		UNIQUEIDENTIFIER,
		@CalcType		INT,
		@DiscCondValue		FLOAT,
		@DiscCondValueTo	FLOAT,
		@DiscPercent		FLOAT,
		@DiscValue		FLOAT,
		@TotalReqDisc		FLOAT,
		@MatsDisc		FLOAT,
		@Disc			FLOAT,
		@Di			FLOAT,
		@DiscStartDate		DATETIME,
		@DiscEndDate		DATETIME,
		@CtdNumber		INT,
		@biQty			FLOAT,
		@biPrice		FLOAT,
		@AroundDisc		FLOAT,
		@AroundType		INT

	SET @CMain = CURSOR FAST_FORWARD FOR
		SELECT DISTINCT 
			[buGuid], [buNumber], [btAbbrev], [buDate], [DistGuid], [CustGuid], [CostGuid], [buTotal], [btIsOutput], [Contracted] 
		FROM 
			[#BillDisc] 
		ORDER BY 
			buDate, buNumber

	OPEN @CMain FETCH @CMain INTO @buGuid, @buNumber, @btAbbrev, @buDate, @DistGuid, @buCustPtr, @buCostPtr, @buTotal, @btIsOutput, @Contracted

	CREATE Table #Mats(Guid UNIQUEIDENTIFIER, Security INT)
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @TotalReqDisc = 0
		SET @MatsDisc = 0
		TRUNCATE TABLE #CustDisc
		INSERT INTO #CustDisc
			SELECT 	Ce.CustomerGuid, Ce.CustomerTypeGuid, Ctd.DiscGuid, Ctd.CtPossibilityItemDisc, Ctd.DiscCalcType, 
				Ctd.DiscCode, Ctd.DiscName, Ctd.DiscLatinName, Ctd.DiscGivingType, Ctd.DiscStartDate, 
				Ctd.DiscEndDate, Ctd.DiscAccGuid, Ctd.DiscOneTime, Ctd.DiscChangeVal, Ctd.DiscPercent, 
				Ctd.DiscValue, Ctd.DiscCondValue, Ctd.DiscCondValueTo, Ctd.DiscMatGuid, Ctd.DiscMatCondGuid, Ctd.DiscGroupGuid, Ctd.Number, AroundType		
			FROM DistCe000 	AS Ce  
				INNER JOIN vwDistCtd	AS Ctd ON (Ctd.CtGuid  = Ce.CustomerTypeGuid) -- AND (Bu.buDate BETWEEN DiscStartDate AND DiscEndDate)
			WHERE 	
				Ce.CustomerGuid = @buCustPtr	
				-- AND Ctd.CtPossibilityItemDisc = 1		
				AND Ctd.DiscGivingType = 1
				AND @StartDate <= Ctd.DiscEndDate 
				AND @EndDate >= Ctd.DiscStartDate
			ORDER By Ctd.CtdNumber
-- Select * From #CustDisc		
		-----------------------------------------------------------------------    Õ”„Ì«  ›« Ê—… «·“»Ê‰ 
-- SELECT DiscGuid, DiscAccGuid, CalcType, DiscCondValue, DiscCondValueTo, DiscPercent, DiscValue, MatGuid, GroupGuid, StartDate, EndDate, CtdNumber FROM #CustDisc
		SET @CDetail = CURSOR FAST_FORWARD FOR
			SELECT 
				DiscGuid, DiscAccGuid, CalcType, DiscCondValue, DiscCondValueTo, DiscPercent, DiscValue, 
				MatGuid, MatCond, GroupGuid, StartDate, EndDate, CtdNumber, AroundType 
			FROM 
				#CustDisc
	
		OPEN @CDetail 
		FETCH @CDetail INTO @DiscGuid, @DiscAccGuid, @CalcType, @DiscCondValue, @DiscCondValueTo, @DiscPercent, @DiscValue, 
							@MatGuid, @MatCond, @GroupGuid, @DiscStartDate, @DiscEndDate, @CtdNumber, @AroundType
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @Disc = 0
			SET @Di = 0
			SET @AroundDisc = 0
			IF 	(EXISTS (SELECT DistGuid FROM DistDiscDistributor000 WHERE ParentGuid = @DiscGuid AND DistGuid = @DistGuid And Value = 1) ) AND (@buDate BETWEEN @DiscStartDate AND @DiscEndDate)	
			BEGIN	
				IF @CalcType = 0  -- Õ”„  ÕﬁÌﬁ Âœ›
					SET @Disc = 0 
				
				IF @CalcType = 1  -- Õ”„ „‘—Êÿ »ﬁÌ„… «·›« Ê—…
				BEGIN
					IF (@buTotal BETWEEN @DiscCondValue AND @DiscCondValueTo)
						SET @Disc = @DiscPercent * (@buTotal-ISNULL(@MatsDisc,0) ) / 100 + @DiscValue 
				END

				IF @CalcType = 2 -- Õ”„ „‘—Êÿ »«·⁄ﬁœ
					SET @Disc = @DiscPercent * (@buTotal-ISNULL(@MatsDisc,0) ) / 100 + @DiscValue 	
						
				IF @CalcType = 3  -- Õ”„  Œ›Ì÷ ”⁄— „«œ…
				BEGIN
					IF (@GroupGuid <> 0x00) OR (@MatGuid <> 0x00)
					BEGIN
						SELECT @biQty = SUM(ISNULL(biQty,0)), @biPrice = SUM(ISNULL(biPrice,0)) 
						FROM 
							vwBiMt AS Bi 
							INNER JOIN fnGetGroupsList(@GroupGuid) AS Gr ON Gr.Guid = Bi.mtGroup 
				        WHERE 
							biParent = @buGuid 
							AND (biMatPtr = @MatGuid OR @MatGuid = 0x00) 
						IF (@biQty BETWEEN @DiscCondValue AND @DiscCondValueTo)
							SET @Disc = ( @DiscPercent * (@biQty*@biPrice) / 100) + (@biQty * @DiscValue )
					END
					ELSE IF @MatCond <> 0x00
					BEGIN
						INSERT INTO #Mats Exec PrcGetMatsList @MatGuid, @GroupGuid, -1, @MatCond
						SELECT @biQty = SUM(ISNULL(biQty,0)), @biPrice = SUM(ISNULL(biPrice,0)) 
						FROM 
							vwBiMt AS Bi 
							INNER JOIN #Mats AS mt ON mt.Guid = biMatPtr
						WHERE 
							biParent = @buGuid
							AND 
							(biMatPtr = @MatGuid OR @MatGuid = 0x00) 
						IF (@biQty BETWEEN @DiscCondValue AND @DiscCondValueTo)
							SET @Disc = ( @DiscPercent * (@biQty*@biPrice) / 100) + (@biQty * @DiscValue )
					END
					ELSE
						SET @Disc = 0
					SET @MatsDisc = @MatsDisc + @Disc
				END

				IF @CalcType = 4 -- Õ”„  ⁄ÊÌ÷ „Œ“Ê‰
				BEGIN
					SET @Disc = 0
					IF (@GroupGuid <> 0x00) OR (@MatGuid <> 0x00)
					BEGIN
						IF EXISTS ( SELECT * 
									FROM 
										vwBiMt AS Bi 
										INNER JOIN fnGetGroupsList(@GroupGuid) AS Gr ON Gr.Guid = Bi.mtGroup 
									WHERE 
										biPArent = @buGuid AND (biMatPtr = @MatGuid OR @MatGuid = 0x00) 
								  )	
							SET @Disc = @DiscPercent * (@buTotal-ISNULL(@MatsDisc,0) ) / 100 + @DiscValue
					END
					ELSE IF (@MatCond <> 0x0)
					BEGIN
						DELETE #Mats
						INSERT INTO #Mats Exec PrcGetMatsList @MatGuid, @GroupGuid, -1, @MatCond
						IF EXISTS ( SELECT * 
									FROM 
										vwBiMt AS Bi 
										INNER JOIN #Mats AS mt ON mt.Guid = Bi.biMatPtr
									WHERE 
										biPArent = @buGuid 
										--AND (biMatPtr = @MatGuid OR @MatGuid = 0x00) 
									)	
						BEGIN
							SET @Disc = @DiscPercent * (@buTotal-ISNULL(@MatsDisc,0) ) / 100 + @DiscValue
						END
					END
				END

				IF @CalcType = 5 --  Õ”„  ﬁ—Ì»
				BEGIN
					SELECT  @AroundDisc = ( SUM(di.Discount) - SUM(di.Extra) )
					FROM  
						Bu000 AS bu 
						INNER JOIN Di000 AS di ON di.ParentGUID = bu.GUID
					WHERE 	bu.CustGuid    = @buCustPtr	AND
						di.AccountGUID = @DiscAccGuid	AND
						bu.Date <= @buDate		AND 
						bu.Number < @buNumber

					IF ( (@buTotal - @TotalReqDisc) < 5 )
						SET @Disc = @buTotal - @TotalReqDisc
					ELSE
					BEGIN
						SET @Di =  (CAST(ROUND((@buTotal-@TotalReqDisc),0,1) AS INT) % 5) + ((@buTotal-@TotalReqDisc) - ROUND((@buTotal-@TotalReqDisc),0,1))
						-- SET @Di   = ( @buTotal - @TotalReqDisc) / 5
						-- SET @Disc = ( @buTotal - @TotalReqDisc) - @Di * 5
						SET @Disc = @Di
					END
				
					--PRINT('New   ' + CAST(@buNumber AS NVARCHAR(10)))
					--PRINT(@AroundDisc)
					--PRINT(@Disc)
					IF @AroundType = 0 -- DiscExtra --999
					BEGIN
						IF ( @Disc > 2.5 )
						BEGIN
							SET  @Di = (5 - @Disc)	
							IF ( @AroundDisc >= @Di )
								SET @Disc = @Di * -1 				
							  -- PRINT(@Disc)
						END
					END
					ELSE IF @AroundType = 1 -- Discount always
					BEGIN
						SET @Disc = ABS(@Disc)
					END
					ELSE -- Extra always
					BEGIN
						SET @Disc = ABS(@Disc) * -1
					END
				END 
				-------------------------------------------------------
				SET @TotalReqDisc = ISNULL(@TotalReqDisc,0) + ISNULL(@Disc,0)	
				IF EXISTS (SELECT AccGuid FROM #BillDisc WHERE buGuid = @buGuid AND AccGuid = @DiscAccGuid)
					-- UPDATE #BillDisc SET ReqDisc = (CASE @btIsOutput WHEN 1 THEN @Disc ELSE -1*@Disc END) 
					UPDATE 
						#BillDisc 
					SET 
						ReqDisc = @Disc 
					WHERE 
						AccGuid = @DiscAccGuid 
						AND buGuid = @buGuid
						AND @DiscGuid = DiscGuid
				ELSE
				BEGIN			
					INSERT INTO #BillDisc  -- Cust Discount Not Found In the Bill
						-- VALUES ( @buGuid, @buNumber, @btAbbrev, @buDate, @DistGuid, @buCustPtr, @buCostPtr, @DiscGuid, @DiscAccGuid, 0, @buTotal, @btIsOutput, 0, (CASE @btIsOutput WHEN 1 THEN @Disc ELSE -1*@Disc END), 2, @Contracted, @CtdNumber )
						VALUES ( @buGuid, @buNumber, @btAbbrev, @buDate, @DistGuid, @buCustPtr, @buCostPtr, @DiscGuid, @DiscAccGuid, 0, @buTotal, @btIsOutput, 0, @Disc, 2, @Contracted, @CtdNumber )
				END   
			END --  IF @buDate BETWEEN @DiscStartDate AND @DiscEndDate
			FETCH FROM @CDetail INTO @DiscGuid, @DiscAccGuid, @CalcType, @DiscCondValue, @DiscCondValueTo, @DiscPercent, @DiscValue, @MatGuid, @MatCond, @GroupGuid, @DiscStartDate, @DiscEndDate, @CtdNumber, @AroundType
		END -- WHILE @@FETCH_STATUS = 0  -- CDetail
		CLOSE @CDetail	DEALLOCATE @CDetail 	
	
		INSERT INTO #BillDisc   -- Items Discount
			-- SELECT 	@buGuid, @buNumber, bt.btAbbrev, @buDate, @DistGuid, @buCustPtr, @buCostPtr, 0x00, bt.btDefDiscAcc, @buTotal, @buTotal, @btIsOutput, CASE @btIsOutput WHEN 1 THEN buItemsDisc ELSE -1*buItemsDisc END, 0, 1, @Contracted, 0
			SELECT 	@buGuid, @buNumber, bt.btAbbrev, @buDate, @DistGuid, @buCustPtr, @buCostPtr, 0x00, bt.btDefDiscAcc, @buTotal, @buTotal, @btIsOutput, buItemsDisc, 0, 1, @Contracted, 0
				FROM vwBu AS Bu 
					INNER JOIN vwbt AS bt On bu.buType = btGuid
				WHERE buGuid = @buGuid -- AND buItemsDisc <> 0
	
		FETCH @CMain INTO @buGuid, @buNumber, @btAbbrev, @buDate, @DistGuid, @buCustPtr, @buCostPtr, @buTotal, @btIsOutput, @Contracted
	END -- WHILE @@FETCH_STATUS = 0  -- CMain
	CLOSE @CMain 	DEALLOCATE @CMain 	
---------------------------------------------------------------------------------------------------------------------------
	CREATE TABLE #Result 
			(
				buGuid 		UNIQUEIDENTIFIER, 
				buNumber	INT,
				btAbbrev	NVARCHAR(100) COLLATE ARABIC_CI_AI,
				buDate		DATETIME,
				DistGuid 	UNIQUEIDENTIFIER, 
				CustGuid 	UNIQUEIDENTIFIER, 
				CostGuid 	UNIQUEIDENTIFIER, 
				DiscGuid	UNIQUEIDENTIFIER, 
				AccGuid		UNIQUEIDENTIFIER, 
				TotalBill	FLOAT,  	-- TotalBill Used IN Grouping 
				buTotal		FLOAT,
				btIsOutput	FLOAT,
				RealDisc	FLOAT,		-- Real Discount In The Discount Bill
				ReqDisc		FLOAT,		-- Requierd Discount From Th DistDisc
				Flag		INT,		-- 0 bu Discount Detail   1 bu Discount Total
				Contracted	INT,		-- Cust State 
				DistCode	NVARCHAR(500) COLLATE ARABIC_CI_AI,
				DistName	NVARCHAR(500) COLLATE ARABIC_CI_AI,
				DistLatinName	NVARCHAR(500) COLLATE ARABIC_CI_AI,
				CustName	NVARCHAR(500) COLLATE ARABIC_CI_AI,
				CustLatinName	NVARCHAR(500) COLLATE ARABIC_CI_AI,
				CostCode	NVARCHAR(500) COLLATE ARABIC_CI_AI,
				CostName	NVARCHAR(500) COLLATE ARABIC_CI_AI,
				CostLatinName	NVARCHAR(500) COLLATE ARABIC_CI_AI,
				DiscCode	NVARCHAR(500) COLLATE ARABIC_CI_AI,
				DiscName	NVARCHAR(500) COLLATE ARABIC_CI_AI,
				DiscLatinName	NVARCHAR(500) COLLATE ARABIC_CI_AI,
				AccCode		NVARCHAR(500) COLLATE ARABIC_CI_AI,
				AccName		NVARCHAR(500) COLLATE ARABIC_CI_AI,
				AccLatinName	NVARCHAR(500) COLLATE ARABIC_CI_AI
			)

	INSERT INTO #Result 
		SELECT  bi.buGuid, bi.buNumber, bi.btAbbrev, bi.buDate, bi.DistGuid, bi.CustGuid, bi.CostGuid, bi.DiscGuid, bi.AccGuid,
			bi.TotalBill, bi.buTotal, bi.btIsOutput, bi.RealDisc, bi.ReqDisc, bi.Flag, bi.Contracted, 
			ISNULL(Dr.Code, '') AS DistCode, ISNULL(Dr.Name, '') AS DistName, ISNULL(Dr.LatinName, '') AS DistLatinName, 
			ISNULL(Cu.CustomerName, '') AS CuName, ISNULL(Cu.LatinName, '') AS CuLatinName, 
			ISNULL(Co.Code, '') AS CostCode, ISNULL(Co.Name, '') AS CostName, ISNULL(Co.LatinName, '') AS CostLatinName, 
			ISNULL(Di.Code, '') AS DiscCode, ISNULL(Di.Name, CASE bi.Flag WHEN 1 THEN 'Õ”„ «·√ﬁ·«„' ELSE '' END) AS DiscName, ISNULL(Di.LatinName, CASE bi.Flag WHEN 1 THEN 'Items Discount' ELSE '' END) AS DiscLatinName, 
			ISNULL(Ac.Code, '') AS AccCode,  ISNULL(Ac.Name, '') AS AccName,  ISNULL(Ac.LatinName, '') AS AccLatinName 
		
		FROM  #BillDisc AS Bi
			LEFT JOIN DistDisc000	 AS Di	ON Di.Guid = bi.DiscGuid
			LEFT JOIN Co000		 AS Co	ON Co.Guid = bi.CostGuid
			LEFT JOIN Distributor000 AS Dr	ON Dr.Guid = bi.DistGuid
			LEFT JOIN Ac000 	 AS Ac  ON Ac.Guid = bi.AccGuid
			LEFT JOIN Cu000 	 AS Cu  ON Cu.Guid = bi.CustGuid
	ORDER BY bi.buNumber, bi.CtdNumber --bi.DiscGuid
	
	EXEC prcCheckSecurity 

-- SELECT * FROM #Result 
	IF @GroupFlag = 0   -- No Group
	BEGIN
		SELECT * FROM #Result 
		WHERE 
			(@IdenticalDisc = 0)	OR
			(@IdenticalDisc = 1 AND ( ROUND(ISNULL(RealDisc,0)*100,0,1) =  ROUND(ISNULL(ReqDisc,0)*100,0,1)))	OR 
			(@IdenticalDisc = 2 AND ( ROUND(ISNULL(RealDisc,0)*100,0,1) <> ROUND(ISNULL(ReqDisc,0)*100,0,1)))	
	END
	ELSE	-- Group Result   
	BEGIN
		SELECT 
			(CASE @GroupType WHEN 2 THEN buGuid   ELSE 0x00 END) AS buGuid,			-- 2 Group By Bill
			(CASE @GroupType WHEN 2 THEN buNumber ELSE 0    END) AS buNumber,		
			(CASE @GroupType WHEN 2 THEN buDate   ELSE '12-31-1980' END) AS buDate,		
			(CASE @GroupType WHEN 2 THEN btAbbrev ELSE '' END) AS btAbbrev,		

			(CASE @GroupType WHEN 0 THEN DistGuid WHEN 2 THEN DistGuid ELSE 0x00 END) AS DistGuid,		-- 0 Group By Cost		
			(CASE @GroupType WHEN 1 THEN CustGuid WHEN 2 THEN CustGuid ELSE 0x00 END) AS CustGuid,		-- 1 Group By Cust		
			(CASE @GroupType WHEN 0 THEN CostGuid WHEN 2 THEN CostGuid ELSE 0x00 END) AS CostGuid,		-- 0 Group By Cost		
			(CASE @GroupType WHEN 3 THEN DiscGuid ELSE 0x00 END) AS DiscGuid,		-- 3 Group By Disc		
			(CASE @GroupType WHEN 3 THEN AccGuid  ELSE 0x00 END) AS AccGuid,		
			-- ISNULL(buTotal,0)		AS buTotal,
			(CASE @GroupType WHEN 3 THEN SUM(ISNULL(buTotal,0))ELSE SUM(ISNULL(TotalBill,0)) END)	AS buTotal,
			-- btIsOutput,
			SUM(ISNULL(RealDisc,0))		AS RealDisc,
			SUM(ISNULL(ReqDisc,0))		AS ReqDisc,
			-- Flag,	
			Contracted,	
			(CASE @GroupType WHEN 0 THEN DistCode 	   WHEN 2 THEN DistCode 	ELSE '' END) AS DistCode,		-- 0 Group By Cost	OR 2 Group By Bill		
			(CASE @GroupType WHEN 0 THEN DistName 	   WHEN 2 THEN DistName		ELSE '' END) AS DistName,		
			(CASE @GroupType WHEN 0 THEN DistLatinName WHEN 2 THEN DistLatinName	ELSE '' END) AS DistLatinName,		
			(CASE @GroupType WHEN 1 THEN CustName 	   WHEN 2 THEN CustName 	ELSE '' END) AS CustName,		-- 1 Group By Cust	OR 2 Group By Bill		
			(CASE @GroupType WHEN 1 THEN CustLatinName WHEN 2 THEN CustLatinName 	ELSE '' END) AS CustLatinName,	
			(CASE @GroupType WHEN 0 THEN CostCode 	   WHEN 2 THEN CostCode 	ELSE '' END) AS CostCode,		-- 0 Group By Cost	OR 2 Group By Bill		
			(CASE @GroupType WHEN 0 THEN CostName 	   WHEN 2 THEN CostName 	ELSE '' END) AS CostName,	
			(CASE @GroupType WHEN 0 THEN CostLatinName WHEN 2 THEN CostLatinName 	ELSE '' END) AS CostLatinName,	
			(CASE @GroupType WHEN 3 THEN DiscCode      ELSE '' END) AS DiscCode,		-- 3 Group By Disc		
			(CASE @GroupType WHEN 3 THEN DiscName 	   ELSE '' END) AS DiscName,		
			(CASE @GroupType WHEN 3 THEN DiscLatinName ELSE '' END) AS DiscLatinName,	
			(CASE @GroupType WHEN 3 THEN AccCode 	   ELSE '' END) AS AccCode,		
			(CASE @GroupType WHEN 3 THEN AccName 	   ELSE '' END) AS AccName,		
			(CASE @GroupType WHEN 3 THEN AccLatinName  ELSE '' END) AS AccLatinName		
		FROM #Result
		GROUP BY -- @Group Type 0 Group by Cost, 1 Group by Cust, 2 Group By Bill, 3 Group By Disc, 
			CASE @GroupType	WHEN 2 THEN buGuid   ELSE 0x00 END,					-- 2 Group By Bill
			CASE @GroupType	WHEN 2 THEN buNumber ELSE 0 END,		
			CASE @GroupType	WHEN 2 THEN buDate   ELSE '12-31-1980' END,	
			CASE @GroupType	WHEN 2 THEN btAbbrev ELSE '' END,	
			CASE @GroupType	WHEN 0 THEN DistGuid WHEN 2 THEN DistGuid ELSE 0x00 END,		-- 0 Group By Cost	OR 2 Group By Bill	
			CASE @GroupType	WHEN 1 THEN CustGuid WHEN 2 THEN CustGuid ELSE 0x00 END,		-- 1 Group By Cust	OR 2 Group By Bill	
			CASE @GroupType	WHEN 0 THEN CostGuid WHEN 2 THEN CostGuid ELSE 0x00 END,		
			CASE @GroupType	WHEN 3 THEN DiscGuid ELSE 0x00 END,		-- 3 Group By Disc		
			CASE @GroupType	WHEN 3 THEN AccGuid  ELSE 0x00 END,		
			-- buTotal,
			-- btIsOutput,
			-- Flag, 
			Contracted, 
			CASE @GroupType	WHEN 0 THEN DistCode 	  WHEN 2 THEN DistCode 	    ELSE '' END,	-- 0 Group By Cost	OR 2 Group By Bill	
			CASE @GroupType	WHEN 0 THEN DistName 	  WHEN 2 THEN DistName 	    ELSE '' END,	
			CASE @GroupType	WHEN 0 THEN DistLatinName WHEN 2 THEN DistLatinName ELSE '' END,	
			CASE @GroupType	WHEN 1 THEN CustName 	  WHEN 2 THEN CustName 	    ELSE '' END,	-- 1 Group By Cust	OR 2 Group By Bill	
			CASE @GroupType	WHEN 1 THEN CustLatinName WHEN 2 THEN CustLatinName ELSE '' END,	
			CASE @GroupType	WHEN 0 THEN CostCode 	  WHEN 2 THEN CostCode 	    ELSE '' END,	-- 0 Group By Cost	OR 2 Group By Bill	
			CASE @GroupType	WHEN 0 THEN CostName 	  WHEN 2 THEN CostName 	    ELSE '' END,	
			CASE @GroupType	WHEN 0 THEN CostLatinNAme WHEN 2 THEN CostLatinName ELSE '' END,	-- 0 Group By Cost	OR 2 Group By Bill	
			CASE @GroupType	WHEN 3 THEN DiscCode 	  ELSE '' END,		-- 3 Group By Disc		
			CASE @GroupType	WHEN 3 THEN DiscName 	  ELSE '' END,		
			CASE @GroupType	WHEN 3 THEN DiscLatinName ELSE '' END,		
			CASE @GroupType	WHEN 3 THEN AccCode 	  ELSE '' END,		
			CASE @GroupType	WHEN 3 THEN AccName 	  ELSE '' END,		
			CASE @GroupType	WHEN 3 THEN AccLatinName  ELSE '' END		
		HAVING 
			( @IdenticalDisc = 0 )	OR
			( @IdenticalDisc = 1 AND ( ROUND(SUM(ISNULL(RealDisc,0)),0,1) =  ROUND(SUM(ISNULL(ReqDisc,0)),0,1) ) )	OR 
			( @IdenticalDisc = 2 AND ( ROUND(SUM(ISNULL(RealDisc,0)),0,1) <> ROUND(SUM(ISNULL(ReqDisc,0)),0,1) ) )	
	END   -- Else Group Result
#############################
#END