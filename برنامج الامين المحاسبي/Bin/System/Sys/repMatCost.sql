###########################################################################
###«‰Õ—«›  ﬂ«·Ì› «·„Ê«œ «·Ã«Â“…
###########################################################################
CREATE PROCEDURE repMatCost
	@StartDate DATETIME,				-- FromDate  
	@EndDate DATETIME,					-- ToDate  
	@CostGUID UNIQUEIDENTIFIER,			-- 0 all costs so don't Check cost or list of costs    
	@CurrencyGUID UNIQUEIDENTIFIER,		-- CurrencyGUID 
	@CurrencyVal FLOAT,					-- CurrencyVal  
	@UserId UNIQUEIDENTIFIER,			-- UserId  
	@Unit	 INT,						-- 1 Unit1, 2 Unit2, 3 Unit3, 4 DefUnit  
	@CustAccGUID UNIQUEIDENTIFIER = null,					-- AccNumber For Customer Account In Bills	  
	@AccGUID UNIQUEIDENTIFIER = null,	-- 0 all acounts or one cust when @ForCustomer not 0 or AccNumber   
	@UseUnPostedEntry int = 1
	--, @X INT 
AS     
SET NOCOUNT ON    
--------------------------------------------------------
DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();
----------------------------------------------------
--	Create SecViol table  
CREATE TABLE #SecViol( Type INT, Cnt INT)      
--	Create Result table  
CREATE TABLE #Result  
(  
	GUID UNIQUEIDENTIFIER,  
	Qty	FLOAT,  
	AvgPrice FLOAT,  
	MaxPrice FLOAT,  
	LastPrice FLOAT,  
	LastPriceDate DATETIME, 
	UnitName NVARCHAR(255) COLLATE ARABIC_CI_AI 
)  
--	Declare And Fill AccountPtr Table And CostTable  
CREATE TABLE #Accs( Number UNIQUEIDENTIFIER, Security INT, Lvl INT)    
CREATE TABLE #Costs( Number UNIQUEIDENTIFIER, Security INT)    
INSERT INTO #Accs EXEC prcGetAccountsList @AccGUID   
INSERT INTO #Costs EXEC prcGetCostsList @CostGUID   
CREATE TABLE #CustAccs( GUID UNIQUEIDENTIFIER, Security INT, Lvl INT)    
INSERT INTO #CustAccs EXEC prcGetAccountsList @CustAccGUID   
SET @CostGUID = ISNULL(@CostGUID, 0x0)  
IF @CostGUID = 0x0  
	INSERT INTO #Costs VALUES(@CostGUID, 1)	  
--	Declare Temp Variables  
DECLARE      
	@mtPtr uniqueidentifier,  
	@mtQty FLOAT,  
	@UnitFact FLOAT,  
	@mtAvgPrice FLOAT,  
	@mtMaxPrice FLOAT,  
	@mtLastPrice FLOAT,  
	@mtLastPriceDate DATETIME,  
	@mtValue FLOAT,  
	@MatBrowseSec	INT  
--	Set Security VAriable  
SET @MatBrowseSec = dbo.fnGetUserMaterialSec_Browse(@UserId)  
--	Decleare Cursor  
DECLARE @c_bi CURSOR  
-- bi cursor input variables declarations:      
DECLARE       
		@buType uniqueidentifier,      
		@buNumber float,      
		@buDate DATETIME,      
		@buDirection INT,      
		@biNumber INT,      
		@biMatPtr uniqueidentifier,      
		@biQty FLOAT,  
		@mtUnitFact FLOAT,  
		@biBonusQty FLOAT,      
		@biUnitPrice FLOAT,      
		@biUnitDiscount FLOAT,      
		@biUnitExtra FLOAT,      
		@biAffectsLastPrice BIT,      
		@biAffectsCostPrice BIT,     
		@biAffectsProfit BIT,      
		@biExtraAffectsCostPrice BIT,      
		@biDiscountAffectsCostPrice BIT,      
		@biExtraAffectsProfit BIT,      
		@biDiscountAffectsProfit BIT,  
		@mtMame NVARCHAR(500), 
		@UnitName NVARCHAR(255) 
--	helpfull vars:      
DECLARE      
		@Tmp FLOAT      
--	Setup bi cursor:      
--//////////////////////////////////////////////////////
	/*
	SELECT      
		buType,      
		buNumber,      
		buDate,    
		buDirection,     
		biNumber,      
		biMatPtr,      
		biQty,  
		CASE @Unit 
			WHEN 1 THEN 1  
			WHEN 2 THEN   
					CASE mtUnit2Fact  
						WHEN 0 THEN mtDefUnitFact  
						ELSE  mtUnit2Fact  
					END  
			WHEN 3 THEN   
					CASE mtUnit3Fact  
						WHEN 0 THEN mtDefUnitFact  
						ELSE mtUnit3Fact  
					END  
			WHEN 4 THEN mtDefUnitFact  
		END,		  
		biBonusQnt,  
		FixedBiPrice / mtUnitFact,  
		((CASE buTotal  
			WHEN 0 THEN (CASE biQty WHEN 0 THEN 0  ELSE biDiscount / biQty END) + biBonusDisc     
			ELSE ((CASE biQty WHEN 0 THEN 0 ELSE (biDiscount / biQty) END) + (ISNULL((SELECT Sum(diDiscount) FROM vwDi WHERE vwDi.diParent = buGUID),0) * FixedBiPrice / mtUnitFact) / buTotal)     
			END) + biBonusDisc) * btDiscAffectCost,  
		(CASE buTotal WHEN 0 THEN biExtra ELSE biExtra + buTotalExtra * FixedBiPrice / mtUnitFact / buTotal END) * btExtraAffectCost,  
		btAffectLastPrice,  
		btAffectCostPrice,  
		btAffectProfit,  
		btDiscAffectCost,  
		btExtraAffectCost,  
		btDiscAffectProfit,  
		btExtraAffectProfit,  
		mtName, 
		CASE @Unit 
			WHEN 1 THEN mtUnity  
			WHEN 2 THEN mtUnit2 
			WHEN 3 THEN mtUnit3 
			WHEN 4 THEN mtDefUnitName 
		END AS UnitName	 
-----------------------------  
	FROM     
		fnExtended_Bi_Fixed(@CurrencyGUID) 
		INNER JOIN #CustAccs AS ac ON ac.GUID = buCustAcc 
-----------------------------  
	WHERE     
		buIsPosted <> 0 AND  
		(buDate BETWEEN @StartDate AND @EndDate) AND  
		biCostPtr IN(SELECT Number FROM #Costs) AND  
		--buCustAcc = @CustAccGUID AND  
		buSecurity <= dbo.fnGetUserBillSec_Browse(@UserId, buType) AND  
		mtSecurity <= @MatBrowseSec --AND   
		--buCustAcc IN (SELECT Number FROM  #Accs)  
-----------------------------  
	ORDER BY  
		biMatPtr, biStorePtr, buDate, buSortFlag, buNumber  
	*/
--//////////////////////////////////////////////////////
SET @c_bi = CURSOR FAST_FORWARD FOR      
	SELECT      
		buType,      
		buNumber,      
		buDate,    
		buDirection,     
		biNumber,      
		biMatPtr,      
		biQty,  
		CASE @Unit 
			WHEN 1 THEN 1  
			WHEN 2 THEN   
					CASE mtUnit2Fact  
						WHEN 0 THEN mtDefUnitFact  
						ELSE  mtUnit2Fact  
					END  
			WHEN 3 THEN   
					CASE mtUnit3Fact  
						WHEN 0 THEN mtDefUnitFact  
						ELSE mtUnit3Fact  
					END  
			WHEN 4 THEN mtDefUnitFact  
		END,		  
		biBonusQnt,  
		FixedBiPrice / mtUnitFact,  
		((CASE buTotal  
			WHEN 0 THEN (CASE biQty WHEN 0 THEN 0  ELSE biDiscount / biQty END) + biBonusDisc     
			ELSE ((CASE biQty WHEN 0 THEN 0 ELSE (biDiscount / biQty) END) + (ISNULL((SELECT Sum(diDiscount) FROM vwDi WHERE vwDi.diParent = buGUID),0) * FixedBiPrice / mtUnitFact) / buTotal)     
			END) + biBonusDisc) * btDiscAffectCost,  
		(CASE buTotal WHEN 0 THEN biExtra ELSE biExtra + buTotalExtra * FixedBiPrice / mtUnitFact / buTotal END) * btExtraAffectCost,  
		btAffectLastPrice,  
		btAffectCostPrice,  
		btAffectProfit,  
		btDiscAffectCost,  
		btExtraAffectCost,  
		btDiscAffectProfit,  
		btExtraAffectProfit,  
		mtName, 
		CASE @Unit 
			WHEN 1 THEN mtUnity  
			WHEN 2 THEN
					CASE mtUnit2Fact
						WHEN 0 THEN mtDefUnitName
						ELSE  mtUnit2
					END  
			WHEN 3 THEN 
					CASE mtUnit3Fact
						WHEN 0 THEN mtDefUnitName
						ELSE  mtUnit3
					END  
			WHEN 4 THEN mtDefUnitName 
		END AS UnitName	 
-----------------------------  
	FROM     
		fnExtended_Bi_Fixed(@CurrencyGUID) 
		INNER JOIN #CustAccs AS ac ON ac.GUID = buCustAcc 
-----------------------------  
	WHERE     
		buIsPosted <> 0 AND  
		(buDate BETWEEN @StartDate AND @EndDate) AND  
		biCostPtr IN(SELECT Number FROM #Costs) AND  
		--buCustAcc = @CustAccGUID AND  
		buSecurity <= dbo.fnGetUserBillSec_Browse(@UserId, buType) AND  
		mtSecurity <= @MatBrowseSec --AND   
		--buCustAcc IN (SELECT Number FROM  #Accs)  
-----------------------------  
	ORDER BY  
		biMatPtr, biStorePtr, buDate, buSortFlag, buNumber  
----------------------------  
	OPEN @c_bi  
	 
	FETCH FROM @c_bi INTO  
		@buType,   
		@buNumber,   
		@buDate,   
		@buDirection,     
		@biNumber,   
		@biMatPtr,   
		@biQty,   
		@mtUnitFact,   
		@biBonusQty,   
		@biUnitPrice,   
		@biUnitDiscount,   
		@biUnitExtra,     
		@biAffectsLastPrice,   
		@biAffectsCostPrice,   
		@biAffectsProfit,     
		@biDiscountAffectsCostPrice,   
		@biExtraAffectsCostPrice,   
		@biDiscountAffectsProfit,   
		@biExtraAffectsProfit   ,  
		@mtMame, 
		@UnitName 

		--PRINT @UnitName
		
--	Get the first material      
	SET @mtPtr = @biMatPtr  
	-- reset variables:      
	SET @mtQty = 0  
	SET @mtAvgPrice = 0      
	SET @mtMaxPrice = 0      
	SET @mtLastPrice = 0      
	SET @mtLastPriceDate = 0      
	-- start @c_bi loop      
	DECLARE @i AS int 
	DECLARE @ProcessUnitName NVARCHAR(100) 
	--SET @ProcessUnitName = @UnitName 
	SET @i = 0 
	WHILE @@FETCH_STATUS = 0      
	BEGIN 
		SET @i = @i + 1 
		--print Cast(@i AS NVARCHAR(10)) + '  ' + CAST(@mtPtr  AS NVARCHAR(100)) + '  ' + CAST(@bimatPtr  AS NVARCHAR(100))
		--	Is this a new material ?      
		--PRINT 1 
		IF @mtPtr <> @biMatPtr  
		BEGIN      
			-- Insert the material record:      
			--PRINT @i 
			--print @ProcessUnitName
			INSERT INTO #Result VALUES(      
				@mtPtr,      
				@mtQty/@UnitFact,  
				@mtAvgPrice*@UnitFact,  
				@mtMaxPrice*@UnitFact,  
				@mtLastPrice*@UnitFact,  
				@mtLastPriceDate, 
				@ProcessUnitName)      
			-- reset mt variables:      
			SET @mtPtr = @biMatPtr      
			SET @mtQty = 0  
			SET @mtAvgPrice = 0      
			SET @mtMaxPrice = 0      
			SET @mtLastPrice = 0      
			SET @mtLastPriceDate = 0      
			--SET	@mtMame = ''
			SET	@ProcessUnitName = ''
		END
		--	Calc UnitFact  
		SET @ProcessUnitName = @UnitName 
		SET @UnitFact = @mtUnitFact  
		--	Calc Prices  
		IF @biAffectsCostPrice = 0      
		BEGIN      
			SET @mtQty = @mtQty + @buDirection * (@biQty + @biBonusQty) 
		END      
		ELSE      
		BEGIN      
			------  
			IF @mtQty > 0      
			BEGIN      
				SET @mtValue = @mtAvgPrice * @mtQty + @buDirection * @biQty * (@biUnitPrice + (@biUnitExtra * @biExtraAffectsCostPrice) - (@biUnitDiscount * @biDiscountAffectsCostPrice))      
				SET @mtQty = @mtQty + @buDirection * (@biQty + @biBonusQty)      
				IF @mtValue > 0 AND @mtQty > 0      
					SET @mtAvgPrice = @mtValue / @mtQty      
			END      
			----  
			ELSE -- @mtQty is <= 0:      
			BEGIN      
				SET @mtValue = @biQty * (@biUnitPrice + @biUnitExtra * @biExtraAffectsCostPrice - @biUnitDiscount * @biDiscountAffectsCostPrice)  
				SET @Tmp = @buDirection * (@biQty + @biBonusQty)      
				SET @mtQty = @mtQty + @Tmp      
				IF @Tmp > 0 AND @mtValue > 0      
					SET @mtAvgPrice =  @mtValue / @Tmp      
			END      
			-----  
		END  
		--	Calc Last And Max Price  
		--PRINT @biAffectsLastPrice 
		IF @biAffectsLastPrice <> 0 -- c_bi is sorted by date:      
		BEGIN      
			SET @mtLastPrice = @biUnitPrice  
			SET @mtLastPriceDate = @buDate      
			IF @mtMaxPrice < @biUnitPrice  
				SET @mtMaxPrice = @biUnitPrice      
		END  
		--	End Clac Prices  
		--	Fetch Next Record  
		FETCH NEXT FROM @c_bi INTO      
			@buType,   
			@buNumber,   
			@buDate,   
			@buDirection,     
			@biNumber,   
			@biMatPtr,   
			@biQty,   
			@mtUnitFact,   
			@biBonusQty,   
			@biUnitPrice,   
			@biUnitDiscount,   
			@biUnitExtra,     
			@biAffectsLastPrice,   
			@biAffectsCostPrice,   
			@biAffectsProfit,     
			@biDiscountAffectsCostPrice,   
			@biExtraAffectsCostPrice,   
			@biDiscountAffectsProfit,   
			@biExtraAffectsProfit,  
			@mtMame, 
			@UnitName 
		--IF @mtPtr = @biMatPtr  
		--	SET @CurrentUnitName = @UnitName 
	END 
	--SELECT * FROM #Result
	--print 'end wHILE ' 
	--	Insert the last mt statistics:      
	IF @mtPtr IS NOT NULL 
	BEGIN 
		--PRINT @mtPtr 
		--print @UnitName 
			INSERT INTO #Result VALUES(      
				@mtPtr,      
				@mtQty/@UnitFact,  
				@mtAvgPrice*@UnitFact,  
				@mtMaxPrice*@UnitFact,  
				@mtLastPrice*@UnitFact,  
				@mtLastPriceDate, 
				@UnitName) 
	END 
	--	Free the bi cursor:      
	CLOSE @c_bi DEALLOCATE @c_bi      
-------------------------------------------------------------------------------------------------------------  
--	Calc Account Balance  
--	  
-------------------------------------------------------------------------------------------------------------  
DECLARE @AccBalanceTbl TABLE  
	(      
		Number UNIQUEIDENTIFIER,  
		SumDebit FLOAT,  
		SumCredit FLOAT,  
		DebitBalance FLOAT,  
		CreditBalance FLOAT  
	)      

DECLARE @IsPostedTbl TABLE (Value int)
INSERT INTO @IsPostedTbl VALUES(1)
IF (@UseUnPostedEntry = 1)
	INSERT INTO @IsPostedTbl VALUES(0)

INSERT INTO   
	@AccBalanceTbl  
SELECT   
	en.enAccount AS Number,  
	SUM(enDebit) AS SumDebit,  
	SUM(enCredit) AS SumCredit,  
	CASE  
		WHEN ( SUM(enDebit) - SUM(enCredit) )>0 THEN ( SUM(enDebit - enCredit) )  
		WHEN ( SUM(enDebit) - SUM(enCredit) )<=0 THEN 0  
	END	 AS DebitBalance,  
	CASE  
		WHEN ( SUM(enCredit) - SUM(enDebit) )>0 THEN ( SUM(enCredit - enDebit) )  
		WHEN ( SUM(enCredit) - SUM(enDebit) )<=0 THEN 0  
	END	 AS CreditBalance  
FROM   
	dbo.fnCeEn_Fixed(@CurrencyGUID) AS en   
		INNER JOIN #Accs AS ac  
		ON en.enAccount = ac.Number  
			INNER JOIN #Costs AS co  
			ON en.enCostPoint = co.Number  
			  
WHERE  
	en.enDate BETWEEN @StartDate AND @EndDate AND
	en.ceIsPosted IN (SELECT Value FROM @IsPostedTbl)
	
GROUP BY  
	en.enAccount   
-----------------------------------------------------------------------------------------  
--	Return Results Set  
--  
-----------------------------------------------------------------------------------------  
------------------------ 1 --------  
SELECT   
	SUM(SumDebit) AS Debit,  
	SUM(SumCredit) AS Credit,  
	SUM(DebitBalance) AS DebitBalance,  
	SUM(CreditBalance) AS CreditBalance  
FROM   
	@AccBalanceTbl  
------------------------ 2 --------  
SELECT   
	t_r.* , 
	mt.mtCode, CASE WHEN @Lang >0 THEN  CASE WHEN mt.mtLatinName = ''  THEN mt.mtName ELSE mt.mtLatinName END ELSE  mt.mtName END AS mtName
FROM   
	#Result AS t_r INNER JOIN vwMt AS mt  
		ON t_r.GUID = mt.mtGUID  
################################################################################
CREATE PROCEDURE repReadyMaterialsCostTuning
	( 
		@AccountGuid					UNIQUEIDENTIFIER = 0x0
		,@InsertionAccountGuid				UNIQUEIDENTIFIER = 0x0 
		,@CostGUID						UNIQUEIDENTIFIER = 0x0 
		,@StoreGuid							UNIQUEIDENTIFIER = 0x0 
		,@RepSrc							UNIQUEIDENTIFIER = 0x0 
		,@DistributionType					INT				 = 0
		,@FromDate							DATETIME		 = '1-1-1980'
		,@ToDate							DATETIME		 = '1-1-2100'
		,@IsSingl							INT
	
	) 
	AS 
	SET NOCOUNT ON  
	
	DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();

  CREATE TABLE #Cost_Tbl ( [GUID] [UNIQUEIDENTIFIER])   
	INSERT INTO #Cost_Tbl  SELECT [GUID] FROM [dbo].[fnGetCostsList]( @CostGUID)    
	IF ISNULL( @CostGUID, 0x0) = 0x0     
		INSERT INTO #Cost_Tbl VALUES(0x00) 



		-------------------------
		CREATE TABLE #Account_Tbl  ( [GUID] [UNIQUEIDENTIFIER], [Level] [INT] , CheckDate [DATETIME], [Path] [VARCHAR](4000) COLLATE ARABIC_CI_AI,acCode [VARCHAR](250) COLLATE ARABIC_CI_AI,[acName] [VARCHAR](250) COLLATE ARABIC_CI_AI,[acLatinName] [VARCHAR](250) COLLATE ARABIC_CI_AI, [acSecurity] INT)      
	IF( @IsSingl <> 1)  
		INSERT INTO #Account_Tbl 
		SELECT [fn].[GUID], [fn].[Level], '1-1-1980', [fn].[Path],[Code],[Name],[LatinName],[Security] 
		FROM [dbo].[fnGetAccountsList]( @AccountGuid, 1) AS [Fn] INNER JOIN [ac000] AS [ac] ON [Fn].[GUID] = [ac].[GUID]  
	ELSE  
		INSERT INTO #Account_Tbl SELECT [acGUID], 0, '1-1-1980', '',[acCode],[acName],[acLatinName], [acSecurity]  FROM [vwAc] WHERE [acGUID] = @AccountGuid  

		UPDATE Acc SET CheckDate = ch.CheckedToDate  
		FROM   
			#Account_Tbl Acc  
			INNER JOIN (   
				SELECT AccGUID, MAX( CheckedToDate) CheckedToDate   
				FROM checkAcc000   
				WHERE CheckedToDate BETWEEN @FromDate AND @ToDate GROUP BY AccGUID) ch  
			ON Acc.Guid = ch.AccGUID  
		
		------------------------------------------------------------------------

		---------------------------------------------------------------------------------------------------------------   
	--  1 - Get the balance of Accounts     
	--  2 - Get the Previos balance of Accounts (option)      
	------------------------------------------------------------------------------------------------------------------------      
	-- STEP 1    
	 
	CREATE TABLE [#Result] (      
			[CeGUID] [UNIQUEIDENTIFIER],      
			
			[AccGUID] [UNIQUEIDENTIFIER],      
			
			[acName] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
			
			[enDebit]	[FLOAT],      
			[enCredit] [FLOAT],      
			[enFixDebit] [FLOAT],      
			[enFixCredit] [FLOAT],      
			
			[CostGUID] [UNIQUEIDENTIFIER],      
			
			[Type] [INT]     
			
			)     
	---------------------------------------------------------------------------------------------  
	
	 
	INSERT INTO [#Result]      
		SELECT      
			[ceGUID],       
			[enAccount],      
			
			[ac].[acName],  
			
			SUM( [enDebit]),      
			SUM( [enCredit]),      
			SUM( [EnDebit] ),      
			SUM( [EnCredit] ),      
			[enCostPoint],  
			1 		-- 0 Main Account 1 Sub Account      
		FROM     
			(SELECT *  FROM vwceen e) AS [CE]  
			INNER JOIN #Account_Tbl AS [AC] ON [CE].[enAccount] = [AC].[GUID]      
			INNER JOIN #Cost_Tbl AS [Cost] ON [CE].[enCostPoint] = [Cost].[GUID]    
			LEFT JOIN ER000 er ON er.EntryGuid = ceGuid    
		WHERE      
            CE.enDate BETWEEN DATEADD(dd,1,AC.CheckDate) AND @ToDate 
		GROUP BY     
			[ceGUID],       
			[enAccount],      
			[ac].[acName],  
			[enCostPoint]      
			
			 
DECLARE @BalanceTbl TABLE(      
				[AccGUID] [UNIQUEIDENTIFIER],      
				[AccParent] [UNIQUEIDENTIFIER],      
				[FixDebit] [FLOAT],      
				[FixCredit] [FLOAT],      
				--[PrevBalance] [FLOAT],     
				[Lv] [INT] DEFAULT 0     
				)    
				
		

	-- create initial balance for the result table  
	INSERT INTO @BalanceTbl     
		SELECT     
			[AC].[GUID],      
			[acParent],     
			SUM( ISNULL([Res].[enFixDebit],0)),     
			SUM( ISNULL([Res].[enFixCredit],0)),     
			--0 AS [PrevBal],     
			0 AS [Lv]     
		FROM  
		    #Result Res  INNER JOIN   
			#Account_Tbl AS [AC] 
			ON [AC].[GUID] = [Res].[AccGUID]     
			INNER JOIN [vwAc]  
			ON [vwAc].[acGUID] = [AC].[GUID]     
			--LEFT JOIN [#Result] AS [Res]      
		--WHERE Lv =0 
		GROUP BY     
			[AC].[GUID],      
			[acParent]     
	-------------------------------------------------------------------------------------------      
	-- C O L L E C T  B A L A N C E   O F  A C C O U N T S     
	-------------------------------------------------------------------------     
	IF( @IsSingl <> 1) -- is this a general account (has sons)  
	BEGIN  
		-- calc balance by adding balances of sons (and previous balance)  
		DECLARE @Continue [INT], @Lv [INT]     
		SET @Continue = 1     
		SET @Lv = 0     
		WHILE @Continue <> 0   
		BEGIN     
			SET @Lv = @Lv + 1     
			INSERT INTO @BalanceTbl  
				SELECT     
					[Bal].[AccParent],      
					[acParent],     
					SUM( [Bal].[FixDebit]),     
					SUM( [Bal].[FixCredit]),     
					@Lv     
				FROM     
					@BalanceTbl AS [Bal]     
					INNER JOIN #Account_Tbl AS [AC]      
					ON [AC].[GUID] = [Bal].[AccParent]     
					INNER JOIN [vwAc]     
					ON [vwAc].[acGUID] = [AC].[GUID]     
				WHERE     
					[Lv] = @Lv - 1     
				GROUP BY     
					[Bal].[AccParent],     
					[acParent]     
			SET @Continue = @@ROWCOUNT      
		END	   
		 
		IF EXISTS(SELECT * from ac000 WHERE GUID = @AccountGuid AND Type = 4)  
		BEGIN  
			INSERT INTO @BalanceTbl  
				SELECT @AccountGuid,0X00,  
					SUM( [Bal].[FixDebit]),    
					SUM( [Bal].[FixCredit]),     
					-1  
					FROM     
					@BalanceTbl AS [Bal]    INNER JOIN ci000 CI ON ci.SonGUID = [Bal].[AccGUID]  
							WHERE ci.ParentGUID =   @AccountGuid   
					  
					  
		END    
	END  
	
	
	
	DECLARE @Debit FLOAT
	DECLARE @Credit  FLOAT 
	  
	SELECT 				   
		 @Debit = SUM( [FixDebit]) 
   FROM    
		@BalanceTbl  bal INNER JOIN ac000 ac ON ac.GUID = bal.AccGUID  
	WHERE    
		[Lv] = 0 and ac.NSons =0 
		

   SELECT 				   
		
		@Credit = SUM( [FixCredit])
		
	FROM    
		@BalanceTbl  bal INNER JOIN ac000 ac ON ac.GUID = bal.AccGUID  
	WHERE    
		[Lv] = 0 and ac.NSons =0 
		 
		   		
	SELECT 
		Mt.Guid
		,CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = '' THEN Mt.Name ELSE mt.LatinName END ELSE Mt.Name END AS Name
		,Mt.Code
		,SUM( CASE BT.BILLTYPE WHEN 0 THEN BI.QTY WHEN 3 THEN BI.QTY WHEN 4 THEN BI.QTY WHEN 1 THEN -BI.QTY WHEN 2 THEN -BI.QTY WHEN 5 THEN -BI.QTY END) Qty
		,SUM( CASE BT.BILLTYPE WHEN 0 THEN BI.QTY WHEN 3 THEN BI.QTY WHEN 4 THEN BI.QTY WHEN 1 THEN -BI.QTY WHEN 2 THEN -BI.QTY WHEN 5 THEN -BI.QTY END) * CASE @DistributionType WHEN 0 THEN 1 WHEN 1 THEN Mt.AvgPrice WHEN 2 THEN AVG(Mt.Whole) WHEN 3 THEN AVG(Mt.Half) WHEN 4 THEN AVG(Mt.Vendor) WHEN 5 THEN AVG(Mt.Export) WHEN 6 THEN AVG(Mt.Retail) WHEN 7 THEN AVG(Mt.EndUser) WHEN 8 THEN Mt.Dim WHEN 9 THEN Mt.Origin WHEN 10 THEN Mt.Pos WHEN 11 THEN Mt.Company WHEN 12 THEN Mt.Color WHEN 13 THEN Mt.Provenance WHEN 14 THEN Mt.Quality WHEN 15 THEN Mt.Model END DistributionVal
		--,Mt.AvgPrice
		, [dbo].[fnMaterial_GetPrice](Mt.Guid, 1, @ToDate) AS AvgPrice 
		,@Debit AS Debit
		,@Credit AS Credit
		,Stock.Qty Stock
	FROM Bu000 Bu
		INNER JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid
		INNER JOIN Bi000 Bi ON Bi.ParentGuid = Bu.Guid
		INNER JOIN Mt000 Mt ON Mt.Guid = Bi.MatGuid
		INNER JOIN RepSrcs rs ON rs.idType = bu.TypeGuid
		LEFT JOIN
		(
			SELECT BI.MatGuid, SUM( CASE BT.BILLTYPE WHEN 0 THEN 1 WHEN 3 THEN 1 WHEN 4 THEN 1 WHEN 1 THEN -1 WHEN 2 THEN -1 WHEN 5 THEN -1 END * ( BI.QTY + BI.BonusQnt ) ) AS Qty
			FROM  BI000 BI 
				INNER JOIN BU000 BU ON BI.ParentGuid = BU.GUID 
				INNER JOIN BT000 BT ON BU.TypeGUID = BT.GUID 
			WHERE BU.isposted = 1 
				AND Bi.StoreGuid IN ( SELECT * FROM dbo.fnGetStoresList(@StoreGuid) )	
				
			GROUP BY BI.MatGuid
			
		)Stock ON Stock.MatGuid = Mt.Guid
	WHERE BU.isposted = 1 
		  AND rs.IdTbl = @RepSrc
		  AND Bu.Date >= @FromDate
		  AND Bu.Date <= @ToDate
		  AND (Bu.CostGuid IN ( SELECT Guid FROM dbo.fnGetCostsList(@CostGuid))  
		  OR Bi.CostGuid IN ( SELECT Guid FROM dbo.fnGetCostsList(@CostGuid)) OR ISNULL(@CostGuid, 0x0) = 0x0) 
	GROUP BY 
		Mt.Guid
		,CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = '' THEN Mt.Name ELSE mt.LatinName END ELSE Mt.Name END
		,Mt.Code
		,Mt.AvgPrice
		,Mt.Dim
		,Mt.Origin
		,Mt.Pos
		,Mt.Company
		,Mt.Color
		,Mt.Provenance
		,Mt.Quality
		,Mt.Model
		,Stock.Qty
################################################################################
CREATE PROC repManCostAccCross_GenEn
(
	@AccountGuid		UNIQUEIDENTIFIER   = '798EFE9A-B1D5-4587-87B9-343603E7F886' ,  
	@CostGuid			UNIQUEIDENTIFIER   = 0x0,
	@DistributionType   INT				   = 1, --  1-«·“„‰ «·„⁄Ì«—Ì , 2-«·“„‰ «·›⁄·Ì, 3-‰”»… À«» …, 4-Õ—ﬂ… Õ”«», 5-’—› «·„Ê«œ
	@SrcTypesguid		UNIQUEIDENTIFIER   = 0x0 ,
	@MatGuid			UNIQUEIDENTIFIER   = 0x0 , 
	@GrpGuid			UNIQUEIDENTIFIER   = 0x0 ,
	@MatCalcType		INT				   = 1   ,
	@RelatedAccGuid		UNIQUEIDENTIFIER   = 0x0 , 
	@FromDate			DATETIME		   = '1-1-1980'      , 
	@ToDate				DATETIME		   = '1-1-2070'
)
AS

CREATE TABLE #hsh
		(Number INT IDENTITY(1,1) ,CostGuid [UNIQUEIDENTIFIER],AccountGuid [UNIQUEIDENTIFIER], CostName [NVARCHAR](100),AccountName [NVARCHAR](100), DistributionRate [FLOAT], AccountBalance [FLOAT], Value [FLOAT], DistributedValue [FLOAT])
CREATE TABLE #accTbl
		(AccountGuid [UNIQUEIDENTIFIER])

INSERT INTO #hsh 
		(CostGuid, AccountGuid, CostName, AccountName, DistributionRate, AccountBalance, Value, DistributedValue)
	 EXEC repManufCostAccCross @AccountGuid, @CostGuid, @DistributionType, @SrcTypesguid, @MatGuid, @GrpGuid, @MatCalcType, @RelatedAccGuid, @FromDate, @ToDate

INSERT INTO #accTbl (AccountGuid)
(  SELECT distinct ac.Guid
			from vwAcCu ac 
			INNER JOIN #hsh  h on h.AccountGuid = ac.GUID
			WHERE ac.CustomersCount > 1)
DELETE h
	FROM #hsh h
	INNER JOIN vwAcCu ac on ac.GUID = h.AccountGuid
	WHERE ac.CustomersCount > 1

CREATE TABLE #GroupByAccount_hsh
		(Number INT IDENTITY(1,1) ,CeGUID [UNIQUEIDENTIFIER],AccountGuid [UNIQUEIDENTIFIER],  DistributedValue [FLOAT]) 

INSERT INTO #GroupByAccount_hsh
SELECT  
		NEWID() AS CeGUID
		, AccountGuid 
		, SUM(DistributedValue) AS DistributedValue  
 FROM #hsh 
 WHERE AccountGuid <> 0x0
 GROUP BY AccountGuid
 HAVING SUM(DistributedValue) <> 0
 
DECLARE @Dt DATETIME , @Number INT , @Cur UNIQUEIDENTIFIER
SET @Dt     =  CAST( MONTH( GetDate() ) AS NVARCHAR(2) ) + '-' + CAST ( DAY( GetDate() ) AS NVARCHAR(2) ) + '-' + CAST ( YEAR( GetDate() ) AS NVARCHAR(4) )
SET @Number = (SELECT MAX(Number) From [ce000])
SET @Cur    = (SELECT TOP 1 Guid FROM my000 WHERE [CurrencyVal] = 1)

SELECT * FROM #accTbl

INSERT INTO [ce000] (							 [typeGUID], 
                                                 [Type], 
                                                 [Number], 
                                                 [Date]  ,
												 [PostDate], 
                                                 [Notes] , 
                                                 [CurrencyVal], 
                                                 [IsPosted], 
                                                 [Security], 
                                                 [Branch], 
                                                 [GUID]  , 
                                                 [CurrencyGUID], 
                                                 Debit, 
                                                 Credit)          
SELECT											 0x0				 typeGUID, 
                                                 1    					 Type, 
                                                 (@Number + Number)    Number, 
                                                 @ToDate				 Date, 
												 @Dt				     Date,
                                                 [dbo].[fnStrings_get]('SalaryDistributionEntry', DEFAULT)  Notes, 
                                                 1			   CurrencyVal	, 
                                                 0			   IsPosted		, 
                                                 1			   [Security]	, 
                                                 0X0		   Branch		, --  --
                                                 CeGUID		   GUID			, 
                                                 @Cur         [CurrencyGUID], -- -- 
                                                 DistributedValue	  Debit			, 
                                                 DistributedValue   Credit
FROM #GroupByAccount_hsh

INSERT INTO en000     
            ([number], [accountGUID], [Date], [Debit], [Credit], [Notes], [CurrencyGUID],[CurrencyVal], [ParentGUID], [ContraAccGUID],[CustomerGUID])                 
SELECT  
                                    1                             number		 ,        
                                    hsh.AccountGuid				 accountGUID	 ,       
                                    @ToDate							 Date		 ,        
                                    CASE WHEN grp.DistributedValue > 0 THEN 0 ELSE -grp.DistributedValue END						  	 Debit		 ,         
                                    CASE WHEN grp.DistributedValue > 0 THEN grp.DistributedValue ELSE 0 END    Credit       ,         
                                    '  '                         Notes		 ,    
                                    @Cur						[CurrencyGUID]   ,         
                                    1							[CurrencyVal]	 ,         
                                    CeGuid   as ParentGuid						 ,         
                                    hsh.AccountGuid     as ContraAccGUID         ,
									dbo.fnGetAccountTopCustomer(hsh.AccountGuid)   
FROM #hsh hsh 
INNER JOIN  #GroupByAccount_hsh grp on hsh.AccountGuid = grp.AccountGuid
GROUP BY hsh.AccountGuid , grp.DistributedValue ,CeGuid

INSERT INTO en000     
            ([number], [accountGUID], [Date], [Debit], [Credit], [Notes], [CurrencyGUID],[CurrencyVal], [ParentGUID], [ContraAccGUID],[CostGuid],[CustomerGUID])                 
SELECT  
                                    1                               number		 ,        
                                    hsh.AccountGuid					accountGUID	 ,       
                                    @ToDate								Date ,        
                                    CASE WHEN hsh.DistributedValue > 0 THEN hsh.DistributedValue ELSE 0 END		Debit		 ,         
                                    CASE WHEN hsh.DistributedValue > 0 THEN 0 ELSE -hsh.DistributedValue END		Credit       ,         
                                    '   '                          Notes		 ,    
                                    @Cur						[CurrencyGUID]   ,         
                                    1							[CurrencyVal]	 ,         
                                    CeGuid   as ParentGuid						 ,         
                                    hsh.AccountGuid				ContraAccGUID    ,
                                    CostGuid									 ,
									dbo.fnGetAccountTopCustomer(hsh.AccountGuid) 			
FROM #hsh hsh 
INNER JOIN  #GroupByAccount_hsh grp on hsh.AccountGuid = grp.AccountGuid
GROUP BY hsh.AccountGuid , hsh.DistributedValue ,CeGuid ,CostGuid

UPDATE ce000 SET IsPosted = 1 WHERE Guid IN (SELECT CeGuid FROM #GroupByAccount_hsh)
################################################################################
CREATE PROC repManCostAccCross
(
	@GrpGuid UNIQUEIDENTIFIER      = 0x0 ,
	@CostGuid UNIQUEIDENTIFIER     = 0x0 ,
	@SrcTypesguid UNIQUEIDENTIFIER = 0x0 ,
	@FromDate DATETIME = '1-1-1980'      ,
	@ToDate DATETIME   = '1-1-2070'      
)
AS 	
	IF EXISTS ( SELECT * FROM tempdb..sysobjects WHERE name = '##repManCostAccCross_Params')
		DROP TABLE ##repManCostAccCross_Params

	CREATE TABLE ##repManCostAccCross_Params ( GROUPGUID UNIQUEIDENTIFIER, COSTGUID UNIQUEIDENTIFIER,SRCGUID UNIQUEIDENTIFIER,FRMDATE DATETIME,TODATE DATETIME)		
	
	INSERT INTO ##repManCostAccCross_Params
	SELECT @GrpGuid AS GROUPGUID , @CostGuid AS COSTGUID, @SrcTypesguid AS SRCGUID , @FromDate AS FRMDATE, @ToDate AS TODATE
	
	SELECT 
			co.Guid CostGuid,
			co.Name CostName,
			a.CostConsume,
			CAST(0 AS FLOAT) AS ConsumePercentage              ,
			CAST(0 AS FLOAT) AS TotalConsume
	INTO #CONSUME
	FROM(
			SELECT
					[bi].[CostGuid]					    AS CostGUID    ,
					CAST (SUM(bi.price * bi.Qty)  AS FLOAT) AS CostConsume     --,
			FROM [bu000] bu
			INNER JOIN [RepSrcs]                      bt0 ON  [bt0].[idType]     = [bu].[TypeGUID]
			INNER JOIN bi000                          bi  ON  [bi].[ParentGUID]  = [bu].[GUID]
			INNER JOIN mt000                          mt  ON  [mt].[GUID]	     = [bi].[MatGUID]  
			INNER JOIN dbo.fnGetGroupsList (@GrpGuid) gr  ON  [gr].[GUID]		 = [mt].[GroupGUID]
			INNER JOIN dbo.fnGetCostsList(@CostGuid)  co0 ON  [co0].[GUID]		 = [bi].[CostGUID]
			INNER JOIN bt000						  bt1 ON  [bt1].[GUID]       = [bt0].[idType]
			WHERE [bu].[Date] >= @FromDate  AND [bu].[Date] <= @ToDate  AND [bt0].IdTbl = @SrcTypesguid --AND [bt1].[BillType] = 5  
			GROUP BY [bi].[CostGuid]
	)a
	INNER JOIN co000 co ON co.Guid = a.CostGUID	
	
	--SELECT * FROM #CONSUME
	
	UPDATE #CONSUME 
	SET TotalConsume      = CAST((SELECT SUM(CostConsume) FROM #CONSUME) AS FLOAT)
	
	UPDATE #CONSUME 
	SET ConsumePercentage = ROUND((CostConsume / TotalConsume),3)
		
	SELECT 
		ac.[Name] As AccountName ,
		ac.[GUID] AS AccountGUID ,
		SUM(en.[Debit])- SUM(en.[Credit]) AS AccountBalance 
	INTO #ACCOUNTCONSUME
	FROM MAN_ACTUALSTDACC000 manac
	INNER JOIN ac000 ac ON [ac].[GUID] = [manac].[ActualAccountGuid]
	INNER JOIN en000 en ON  [en].[AccountGUID] = [manac].[ActualAccountGuid]
	WHERE en.[CostGUID] = 0x0 AND en.[Date] >= @FromDate AND en.[Date] <= @ToDate
	GROUP BY ac.[Name],ac.[GUID]	
	
	
	SELECT con.CostGuid,
		   ac.AccountGUID,
		   CostName,
	       AccountName,
	       ISNULL(AccountBalance * ConsumePercentage,0) AS CrossValue,
	       CostConsume,
	       ConsumePercentage
	INTO #Result
	FROM #CONSUME con
	Cross JOIN #ACCOUNTCONSUME ac 
	ORDER BY ac.AccountGUID , con.CostName
	
	INSERT INTO #Result
	SELECT 0x0,
		   0x0,
		   CostName,
		   '1- «·„Ê«œ «·„” Â·ﬂ…',
		   ISNULL(CostConsume,0) AS CrossValue,
		   NULL,
		   NULL
	FROM #Result
	GROUP BY CostName,CostConsume
	
	INSERT INTO #Result
	SELECT 0x0,
		   0x0,
		   CostName,
		   '2- ‰”»… «· Ê“Ì⁄',
		   (ISNULL(ConsumePercentage,0) * 100) AS CrossValue,
		   NULL,
		   NULL
	FROM #Result
	GROUP BY CostName,ConsumePercentage
		
	SELECT 
		  CostGuid,
		  AccountGuid,
		  CostName,
		  AccountName,
		  CrossValue
	FROM #Result 
	WHERE CrossValue <> 0
	ORDER BY AccountName
################################################################################
CREATE PROC repManCostMatCostCross
(
	@GrpGuid UNIQUEIDENTIFIER = 0x0      ,
	@CostGuid UNIQUEIDENTIFIER = 0x0	 ,
	@SrcTypesguid UNIQUEIDENTIFIER = 0x0 ,
	@FromDate DATETIME = '1-1-1980'      ,
	@ToDate DATETIME   = '1-1-2070'      
)
AS
	--›⁄·Ì
	SELECT 
			  a.CostGuid
			, a.MatGuid
			, a.[CostName]
			, a.[MatName]
			, a.Ac_Qty
			, (a.Ac_Total / a.Ac_Qty) as Ac_Price
			, a.Ac_Total
	INTO #ACTUAL_HSH
	FROM
	(
		SELECT co.GUID AS CostGuid 
			 , mt.Guid AS MatGuid
			 , co1.Name AS CostName
			 , mt.Name AS MatName
			 , Sum(bi.Qty) as Ac_Qty
			 , Sum(bi.Qty) * SUM(bi.Price) as Ac_Total
		FROM bt000 billTypes
		INNER JOIN bu000 bu						      ON bu.[TypeGUID]   = billTypes.[GUID]
		INNER JOIN bi000 bi						      ON bi.[ParentGUID] = bu.[GUID]
		INNER JOIN dbo.fnGetCostsList(@CostGuid)  co  ON co.[GUID]  = bu.[CostGUID]
		INNER JOIN co000						  co1 ON co1.[GUID] = co.[Guid]
		INNER JOIN mt000 mt						      ON mt.[GUID]  = bi.[MatGUID]
		INNER JOIN dbo.fnGetGroupsList (@GrpGuid)  gr ON gr.[GUID]  = mt.[GroupGUID]
		INNER JOIN [RepSrcs] bt ON bt.[idType] = bu.[TypeGUID]
		WHERE	
			billTypes.BillType = 5 AND billTypes.[Type] = 1 AND bu.[Date] >= @FromDate AND bu.[Date] <= @ToDate AND [bt].IdTbl = @SrcTypesguid
		GROUP BY co.[GUID] , mt.[GUID] , co1.Name , mt.Name
	) a

	--„⁄Ì«—Ì
	SELECT 
			  a.CostGuid
			, a.MatGuid
			, a.[CostName]
			, a.[MatName]
			, a.STNDR_Qty
			, (a.STNDR_Total / a.STNDR_Qty) as STNDR_Price
			, a.STNDR_Total
	INTO #STANDARD_HSH
	FROM
	(
		SELECT co.GUID AS CostGuid 
			 , mt.Guid AS MatGuid
			 , co1.Name AS CostName
			 , mt.Name AS MatName
			 , Sum(bi.Qty) as STNDR_Qty
			 , Sum(bi.Qty) * SUM(bi.Price) as STNDR_Total
		FROM bt000 billTypes
		INNER JOIN bu000 bu						      ON bu.[TypeGUID] = billTypes.[GUID]
		INNER JOIN bi000 bi						      ON bi.[ParentGUID] = bu.[GUID]
		INNER JOIN dbo.fnGetCostsList(@CostGuid)  co  ON co.[GUID]  = bu.[CostGUID]
		INNER JOIN co000						  co1 ON co1.[GUID] = co.[Guid]
		INNER JOIN mt000 mt						      ON mt.[GUID] = bi.[MatGUID]
		INNER JOIN dbo.fnGetGroupsList (@GrpGuid)  gr ON gr.[GUID] = mt.[GroupGUID]
		INNER JOIN [RepSrcs] bt ON bt.[idType] = bu.[TypeGUID]
		WHERE	
			billTypes.BillType = 5 AND billTypes.[Type] = 2 AND bu.[Date] >= @FromDate AND bu.[Date] <= @ToDate AND [bt].IdTbl = @SrcTypesguid
		GROUP BY co.[GUID] , mt.[GUID] , co1.Name , mt.Name
	) a
	
	
	SELECT  
			 Ac.CostName,
			 Ac.MatName,
			 '1 - „⁄Ì«—Ì' as [Type],
			 '«·”⁄—' as [type1],
			 STNDR.STNDR_Price AS Value
	INTO #RESULT
	FROM #ACTUAL_HSH AC
	INNER JOIN #STANDARD_HSH STNDR ON STNDR.CostGuid = AC.CostGuid AND STNDR.MatGuid = AC.MatGuid
	UNION 
	SELECT  
			 Ac.CostName,
			 Ac.MatName,
			 '1 - „⁄Ì«—Ì' as [Type],
			 '«·ﬂ„Ì…' as [type1],
			 STNDR.STNDR_Qty
	FROM #ACTUAL_HSH AC
	INNER JOIN #STANDARD_HSH STNDR ON STNDR.CostGuid = AC.CostGuid AND STNDR.MatGuid = AC.MatGuid
	UNION 
	SELECT  
			 Ac.CostName,
			 Ac.MatName,
			 '1 - „⁄Ì«—Ì' as [Type],
			 'ﬁÌ„…' as [type1],
			 STNDR.STNDR_Total
	FROM #ACTUAL_HSH AC
	INNER JOIN #STANDARD_HSH STNDR ON STNDR.CostGuid = AC.CostGuid AND STNDR.MatGuid = AC.MatGuid
	UNION 
	SELECT  
			 Ac.CostName,
			 Ac.MatName,
			 '2 - ›⁄·Ì' as [Type],
			 '«·ﬂ„Ì…' as [type1],
			 Ac.Ac_Qty
	FROM #ACTUAL_HSH AC
	INNER JOIN #STANDARD_HSH STNDR ON STNDR.CostGuid = AC.CostGuid AND STNDR.MatGuid = AC.MatGuid
	UNION 
	SELECT  
			 Ac.CostName,
			 Ac.MatName,
			 '2 - ›⁄·Ì' as [Type],
			 '«·”⁄—' as [type1],
			 Ac.Ac_Price
	FROM #ACTUAL_HSH AC
	INNER JOIN #STANDARD_HSH STNDR ON STNDR.CostGuid = AC.CostGuid AND STNDR.MatGuid = AC.MatGuid
	UNION 
	SELECT  
			 Ac.CostName,
			 Ac.MatName,
			 '2 - ›⁄·Ì' as [Type],
			 'ﬁÌ„…' as [type1],
			 Ac.Ac_Total
	FROM #ACTUAL_HSH AC
	INNER JOIN #STANDARD_HSH STNDR ON STNDR.CostGuid = AC.CostGuid AND STNDR.MatGuid = AC.MatGuid
	UNION 
	SELECT  
			 Ac.CostName,
			 Ac.MatName,
			 '3 - «‰Õ—«›' as [Type],
			 '›—ﬁ ﬂ„Ì…' as [type1],
			 Ac.Ac_Qty - STNDR.STNDR_Qty
	FROM #ACTUAL_HSH AC
	INNER JOIN #STANDARD_HSH STNDR ON STNDR.CostGuid = AC.CostGuid AND STNDR.MatGuid = AC.MatGuid
	UNION 
	SELECT  
			 Ac.CostName,
			 Ac.MatName,
			 '3 - «‰Õ—«›' as [Type],
			 '«‰Õ—«› «·‰« Ã ⁄‰ «‰Õ—«› «·ﬂ„Ì…' as [type1],
			 (Ac.Ac_Qty - STNDR.STNDR_Qty) *  STNDR.STNDR_Price
	FROM #ACTUAL_HSH AC
	INNER JOIN #STANDARD_HSH STNDR ON STNDR.CostGuid = AC.CostGuid AND STNDR.MatGuid = AC.MatGuid
	UNION 
	SELECT  
			 Ac.CostName,
			 Ac.MatName,
			 '3 - «‰Õ—«›' as [Type],
			 '›—ﬁ ”⁄—' as [type1],
			 (Ac.Ac_Price - STNDR.STNDR_Price)
	FROM #ACTUAL_HSH AC
	INNER JOIN #STANDARD_HSH STNDR ON STNDR.CostGuid = AC.CostGuid AND STNDR.MatGuid = AC.MatGuid
	UNION 
	SELECT  
			 Ac.CostName,
			 Ac.MatName,
			 '3 - «‰Õ—«›' as [Type],
			 '«‰Õ—«› «·‰« Ã ⁄‰ «‰Õ—«› «·”⁄—' as [type1],
			 (Ac.Ac_Price - STNDR.STNDR_Price) *  Ac.Ac_Qty
	FROM #ACTUAL_HSH AC
	INNER JOIN #STANDARD_HSH STNDR ON STNDR.CostGuid = AC.CostGuid AND STNDR.MatGuid = AC.MatGuid
	UNION 
	SELECT  
			 Ac.CostName,
			 Ac.MatName,
			 '3 - «‰Õ—«›' as [Type],
			 '«‰Õ—«› ﬁÌ„…' as [type1],
			 (Ac.Ac_Total - STNDR.STNDR_Total)
	FROM #ACTUAL_HSH AC
	INNER JOIN #STANDARD_HSH STNDR ON STNDR.CostGuid = AC.CostGuid AND STNDR.MatGuid = AC.MatGuid
	
	SELECT * FROM #RESULT
	UNION
	SELECT  
			 '0-«·„Ã„Ê⁄' CostName,
			 MatName,
			 '1 - „⁄Ì«—Ì' as [Type],
			 '«·”⁄—' as [type1],
			 Sum(res.Value) AS Value
	FROM #RESULT res
	WHERE [Type] = '1 - „⁄Ì«—Ì' AND [type1] = '«·”⁄—'
	GROUP BY MatName, [Type], [type1]
	UNION
	SELECT  
			 '0-«·„Ã„Ê⁄' CostName,
			 MatName,
			 '1 - „⁄Ì«—Ì' as [Type],
			 '«·ﬂ„Ì…' as [type1],
			 Sum(res.Value) AS Value
	FROM #RESULT res
	WHERE [Type] = '1 - „⁄Ì«—Ì' AND [type1] = '«·ﬂ„Ì…'
	GROUP BY MatName, [Type], [type1]
	UNION
	SELECT  
			 '0-«·„Ã„Ê⁄' CostName,
			 MatName,
			 '1 - „⁄Ì«—Ì' as [Type],
			 'ﬁÌ„…' as [type1],
			 Sum(res.Value) AS Value
	FROM #RESULT res
	WHERE [Type] = '1 - „⁄Ì«—Ì' AND [type1] = 'ﬁÌ„…'
	GROUP BY MatName, [Type], [type1]
	UNION
	SELECT  
			 '0-«·„Ã„Ê⁄' CostName,
			 MatName,
			 '2 - ›⁄·Ì' as [Type],
			 '«·ﬂ„Ì…' as [type1],
			 Sum(res.Value) AS Value
	FROM #RESULT res
	WHERE [Type] = '2 - ›⁄·Ì' AND [type1] = '«·ﬂ„Ì…'
	GROUP BY MatName, [Type], [type1]
	UNION
	SELECT  
			 '0-«·„Ã„Ê⁄' CostName,
			 MatName,
			 '2 - ›⁄·Ì' as [Type],
			 '«·”⁄—' as [type1],
			 Sum(res.Value) AS Value
	FROM #RESULT res
	WHERE [Type] = '2 - ›⁄·Ì' AND [type1] = '«·”⁄—'
	GROUP BY MatName, [Type], [type1]
	UNION
	SELECT  
			 '0-«·„Ã„Ê⁄' CostName,
			 MatName,
			 '2 - ›⁄·Ì' as [Type],
			 'ﬁÌ„…' as [type1],
			 Sum(res.Value) AS Value
	FROM #RESULT res
	WHERE [Type] = '2 - ›⁄·Ì' AND [type1] = 'ﬁÌ„…'
	GROUP BY MatName, [Type], [type1]
	UNION
	SELECT  
			 '0-«·„Ã„Ê⁄' CostName,
			 MatName,
			 '3 - «‰Õ—«›' as [Type],
			 '›—ﬁ ﬂ„Ì…' as [type1],
			 Sum(res.Value) AS Value
	FROM #RESULT res
	WHERE [Type] = '3 - «‰Õ—«›' AND [type1] = '›—ﬁ ﬂ„Ì…'
	GROUP BY MatName, [Type], [type1]
	UNION
	SELECT  
			 '0-«·„Ã„Ê⁄' CostName,
			 MatName,
			 '3 - «‰Õ—«›' as [Type],
			 '«‰Õ—«› «·‰« Ã ⁄‰ «‰Õ—«› «·ﬂ„Ì…' as [type1],
			 Sum(res.Value) AS Value
	FROM #RESULT res
	WHERE [Type] = '3 - «‰Õ—«›' AND [type1] = '«‰Õ—«› «·‰« Ã ⁄‰ «‰Õ—«› «·ﬂ„Ì…'
	GROUP BY MatName, [Type], [type1]
	UNION
	SELECT  
			 '0-«·„Ã„Ê⁄' CostName,
			 MatName,
			 '3 - «‰Õ—«›' as [Type],
			 '›—ﬁ ”⁄—' as [type1],
			 Sum(res.Value) AS Value
	FROM #RESULT res
	WHERE [Type] = '3 - «‰Õ—«›' AND [type1] = '›—ﬁ ”⁄—'
	GROUP BY MatName, [Type], [type1]
	UNION
	SELECT  
			 '0-«·„Ã„Ê⁄' CostName,
			 MatName,
			 '3 - «‰Õ—«›' as [Type],
			 '«‰Õ—«› «·‰« Ã ⁄‰ «‰Õ—«› «·”⁄—' as [type1],
			 Sum(res.Value) AS Value
	FROM #RESULT res
	WHERE [Type] = '3 - «‰Õ—«›' AND [type1] = '«‰Õ—«› «·‰« Ã ⁄‰ «‰Õ—«› «·”⁄—'
	GROUP BY MatName, [Type], [type1]
	UNION
	SELECT  
			 '0-«·„Ã„Ê⁄' CostName,
			 MatName,
			 '3 - «‰Õ—«›' as [Type],
			 '«‰Õ—«› ﬁÌ„…' as [type1],
			 Sum(res.Value) AS Value
	FROM #RESULT res
	WHERE [Type] = '3 - «‰Õ—«›' AND [type1] = '«‰Õ—«› ﬁÌ„…'
	GROUP BY MatName, [Type], [type1]
################################################################################
CREATE PROC repManCostByLevel
(
	@AcGuid UNIQUEIDENTIFIER = 0x0      ,
	@CostGuid UNIQUEIDENTIFIER = 0x0	 ,
	@FromDate DATETIME = '1-1-1980'      ,
	@ToDate DATETIME   = '1-1-2070'      
)
AS

SELECT 
		en.[AccountGUID]                 AS AccountGUID,
		en.[CostGUID]                    AS CostGUID, 
		(  
		   SELECT SUM(Debit) - SUM([Credit])
		   FROM en000
		   WHERE AccountGUID = en.[AccountGUID] AND [CostGUID] = en.[CostGUID] AND [Date] >= @FromDate AND [Date] <= @ToDate)  AS Balance,
		ac.Name 			 AS AccountName
INTO #Actual
FROM (
	SELECT en.Guid
		FROM ce000 ce 
			INNER JOIN en000                                en        ON en.ParentGuid            =    ce.Guid  
			INNER JOIN MAN_ACTUALSTDACC000                ac_list0    ON en.[AccountGUID]         =    ac_list0.[ActualAccountGuid]
			INNER JOIN [dbo].[fnGetAccountsList](@AcGuid,1) ac        ON ac.Guid                  =    ac_list0.[ActualAccountGuid]         -- OR ac.Guid = ac_list0.[StandardAccountGuid]
			INNER JOIN [dbo].[fnGetCostsList](@CostGuid)    co0       ON co0.[GUID]               =    en.[CostGUID]
			INNER JOIN co000                                co        ON co.[GUID]                =    co.[GUID]
	WHERE en.[Date] >= @FromDate       AND en.[Date] <= @ToDate
) a
INNER JOIN en000 en ON en.Guid = a.Guid
INNER JOIN ac000 ac ON ac.Guid = en.AccountGuid
GROUP BY en.[AccountGUID], en.[CostGUID] , ac.[Name]

INSERT INTO #Actual
SELECT DISTINCT	stnd.AccountGUID,
		co1.[GUID] as CostGUID,
		(SELECT SUM(Balance) 
		 FROM #Actual stndr1 
		 INNER JOIN co000 co00 ON co00.[GUID] = stndr1.CostGUID 
		 WHERE  co00.[ParentGUID] = co1.[GUID] and stndr1.AccountGuid = stnd.AccountGuid ) AS Balance,
		stnd.AccountName
FROM #Actual stnd
INNER JOIN co000 co0 ON co0.[GUID] = stnd.CostGUID
INNER JOIN co000 co1 ON co1.[GUID] = co0.[ParentGUID]

SELECT 
		en.[AccountGUID]                 AS AccountGUID,
		en.[CostGUID]                    AS CostGUID, 
		(SELECT SUM(Debit) - SUM([Credit])
		 FROM en000 
		 WHERE AccountGUID = en.[AccountGUID] AND [CostGUID] = en.[CostGUID] AND [Date] >= @FromDate AND [Date] <= @ToDate)  AS Balance,
		ac.Name 			 AS AccountName
INTO #Standard
FROM (
		SELECT en.Guid
		FROM ce000 ce 
			INNER JOIN en000                                en        ON en.ParentGuid            =    ce.Guid  
			INNER JOIN MAN_ACTUALSTDACC000                ac_list0    ON en.[AccountGUID]         =    ac_list0.[StandardAccountGuid]
			INNER JOIN [dbo].[fnGetAccountsList](@AcGuid,1) ac        ON ac.Guid                  =    ac_list0.[StandardAccountGuid]         -- OR ac.Guid = ac_list0.[StandardAccountGuid]
			INNER JOIN [dbo].[fnGetCostsList](@CostGuid)    co0       ON co0.[GUID]               =    en.[CostGUID]
			INNER JOIN co000                                co        ON co.[GUID]                =    co.[GUID]
		WHERE en.[Date] >= @FromDate                        AND en.[Date] <= @ToDate
) a
INNER JOIN en000 en ON en.Guid = a.Guid
INNER JOIN ac000 ac ON ac.Guid = en.AccountGuid
GROUP BY en.[AccountGUID], en.[CostGUID] , ac.[Name]

INSERT INTO #Standard
SELECT DISTINCT	stnd.AccountGUID,
		co1.[GUID] as CostGUID,
		(SELECT SUM(Balance) 
		FROM #Standard stndr1 
		INNER JOIN co000 co00 ON co00.[GUID] = stndr1.CostGUID 
		WHERE  co00.[ParentGUID] = co1.[GUID] and stndr1.AccountGuid = stnd.AccountGuid ) AS Balance,
		stnd.AccountName
FROM #Standard stnd
INNER JOIN co000 co0 ON co0.[GUID] = stnd.CostGUID
INNER JOIN co000 co1 ON co1.[GUID] = co0.[ParentGUID]

SELECT DISTINCT
		co.Name CostName,
		CAST (man_ac.AccountName as NVARCHAR(100)) as AccountName,
		'›⁄·Ì' AS [TYPE],
		ISNULL(ac.Balance   , 0) AS VALUE
INTO #RESULT
FROM #Actual ac
INNER JOIN #Standard stndr             ON  ac.CostGuid = stndr.CostGuid
INNER JOIN co000    co                ON co.Guid = ac.CostGuid    OR  co.Guid = stndr.CostGuid
INNER JOIN MAN_ACTUALSTDACC000 man_ac ON ac.AccountGuid = man_ac.[ActualAccountGuid]
UNION
SELECT 
		ISNULL(co.Name,'') CostName,
		ISNULL(CAST (man_ac.AccountName as NVARCHAR(100)),'') as AccountName,
		'„⁄Ì«—Ì' AS [TYPE],	
		ISNULL(stndr.Balance, 0) AS VALUE
FROM #Actual ac
INNER JOIN #Standard stndr ON  ac.CostGuid = stndr.CostGuid
INNER JOIN co000     co   ON co.Guid = ac.CostGuid              OR  co.Guid = stndr.CostGuid
INNER JOIN MAN_ACTUALSTDACC000 man_ac ON stndr.AccountGuid = man_ac.[StandardAccountGuid]

INSERT INTO #RESULT
SELECT  DISTINCT
		ISNULL(res.CostName,'') CostName,
		CAST (res.AccountName as NVARCHAR(100)) as AccountName,
		'«‰Õ—«›' AS [TYPE],	
		SUM(res.VALUE) AS VALUE
FROM #RESULT res
GROUP BY res.CostName , res.AccountName


SELECT * FROM #RESULT
UNION
SELECT DISTINCT
		ISNULL(res.CostName,'') CostName,
		'0-«·„Ã„Ê⁄' AccountName,
		'›⁄·Ì' AS [TYPE],
		SUM(res.VALUE) AS VALUE
FROM #RESULT res
WHERE [TYPE] = '›⁄·Ì' 
GROUP BY res.CostName , res.AccountName , res.[TYPE]
UNION
SELECT 
		ISNULL(res.CostName,'') CostName,
		'0-«·„Ã„Ê⁄' AccountName,
		'„⁄Ì«—Ì' AS [TYPE],	
		SUM(res.VALUE) AS VALUE
FROM #RESULT res
WHERE [TYPE] = '„⁄Ì«—Ì' 
GROUP BY res.CostName , res.AccountName , res.[TYPE]
UNION
SELECT 
		ISNULL(res.CostName,'') CostName,
		'0-«·„Ã„Ê⁄' AccountName,
		'«‰Õ—«›' AS [TYPE],	
		SUM(res.VALUE) AS VALUE
FROM #RESULT res
WHERE [TYPE] = '«‰Õ—«›' 
GROUP BY res.CostName  , res.[TYPE]
################################################################################
CREATE PROC repDefManPlan
(
		@FormGuid   UNIQUEIDENTIFIER = 0x0		  ,
		@CostCenter UNIQUEIDENTIFIER = 0x0		  ,
		@StartDate  DATETIME         = '1-1-1890' ,
		@EndDate    DATETIME         = '1-1-2010'
)		
AS

SELECT 
		mn.CostGuid    CostGuid	   ,
		ISNULL(CAST((SELECT Number FROM co000 WHERE GUID = co.[ParentGUID]) as NVARCHAR(10)),'') + '-' +  ISNULL(CAST(co.[Number] as NVARCHAR(10)),'')+ '            ' + co.Name        CostName	   ,
		co.ParentGuid			   ,
		mn.FormGuid	   FormGuid	   ,
		p.[Qty]        PlanQty     ,
		mn.[Qty]       ManQty      ,
	   (mn.[QTY] - p.[QTY]) as def ,
	   CASE p.[Qty] WHEN 0 THEN 0 ELSE ROUND((mn.[Qty]     / p.[Qty]), 2) * 100		END AS UsePerc,
	   CASE p.[Qty] WHEN 0 THEN 0 ELSE ROUND(1 - (mn.[Qty] / p.[Qty]), 2) * 100     END AS LostPerc
INTO #LIST
FROM 
(
	SELECT FORMGUID , SUM(QTY) QTY 
	FROM [PSI000] 
	WHERE [StartDate] >= @StartDate
	  AND [EndDate]   <= @EndDate
	GROUP BY [FormGuid]
)p 
INNER JOIN 
(
	SELECT ISNULL(FORMGUID,0x0) as FormGuid , co.Guid CostGuid , SUM(QTY) QTY 
	FROM [MN000] MN
	INNER JOIN fnGetCostsList(@CostCenter) co ON co.[Guid] = mn.[OutCostGUID]
	WHERE  [OutDate] >= @StartDate
	   AND [OutDate] <= @EndDate
	GROUP BY [FormGuid] ,co.Guid
) mn ON   mn.FormGuid = p.FormGuid
INNER JOIN co000 co ON co.[GUID] = mn.[CostGuid]

IF(@FormGuid <> 0x0)
	DELETE FROM #LIST WHERE FormGuid <> @FormGuid

INSERT INTO #LIST
SELECT DISTINCT
	   co.Guid CostGuid ,
	   CAST(co.[Number] as NVARCHAR(10)) + '            ' + co.Name CostName ,
	   0x0  ParentGuid  ,
	   0x0  FormGuid    ,
	   (SELECT SUM(PlanQty) FROM #LIST WHERE ParentGuid = Guid )  as PlanQty          ,
	   (SELECT SUM(ManQty)  FROM #LIST WHERE ParentGuid = Guid )  as ManQty           ,
	   (SELECT SUM(ManQty) - SUM(PlanQty) FROM #List WHERE ParentGuid = Guid ) as def,
	   0 UsePerc,
	   0 LostPerc
FROM #LIST lst
INNER JOIN co000 co ON co.Guid = lst.ParentGuid


UPDATE #LIST SET 
	UsePerc  =  (CASE PlanQty WHEN 0 THEN 0 ELSE ROUND((ManQty     / PlanQty), 2) * 100	END), 
	LostPerc =  (CASE PlanQty WHEN 0 THEN 0 ELSE ROUND(1 - (ManQty / PlanQty), 2) * 100 END)
FROM #LIST
WHERE PARENTGUID = 0x0

SELECT COSTNAME AS CostName,
	   '«·Œÿ…' AS Type,
	   PlanQty AS Value
FROM #LIST
UNION
SELECT COSTNAME AS CostName,
	   '«·ﬂ„Ì… «·„‰ Ã…' AS Type,
	   ManQty AS Value
FROM #LIST
UNION
SELECT COSTNAME AS CostName,
	   '«·«‰Õ—«›' AS Type,
	   def AS Value
FROM #LIST
UNION
SELECT COSTNAME AS CostName,
	   '‰”»… «·«” €·«·' AS Type,
	   UsePerc AS Value
FROM #LIST
UNION
SELECT COSTNAME AS CostName,
	   '‰”»… «·Âœ—' AS Type,
	   LostPerc AS Value
FROM #LIST
################################################################################
CREATE PROC repManCostDefBySpend
(
	@FormGuid   UNIQUEIDENTIFIER = 0x0	 ,
	@AcGuid UNIQUEIDENTIFIER = 0x0       ,
	@CostGuid UNIQUEIDENTIFIER = 0x0	 ,
	@FromDate DATETIME = '1-1-1980'      ,
	@ToDate DATETIME   = '1-1-2070'      
)
AS

SELECT 
		en.[AccountGUID]                 AS AccountGUID,
		en.[CostGUID]                    AS CostGUID, 
		(  
		   SELECT SUM(Debit) - SUM([Credit])
		   FROM en000
		   WHERE AccountGUID = en.[AccountGUID] AND [CostGUID] = en.[CostGUID])  AS Balance,
		ac.Name 			 AS AccountName
INTO #Actual
FROM (
	SELECT en.Guid
		FROM ce000 ce 
			INNER JOIN en000                                en        ON en.ParentGuid            =    ce.Guid  
			INNER JOIN MAN_ACTUALSTDACC000                ac_list0    ON en.[AccountGUID]         =    ac_list0.[ActualAccountGuid]
			INNER JOIN [dbo].[fnGetAccountsList](@AcGuid,1) ac        ON ac.Guid                  =    ac_list0.[ActualAccountGuid]         -- OR ac.Guid = ac_list0.[StandardAccountGuid]
			INNER JOIN [dbo].[fnGetCostsList](@CostGuid)    co0       ON co0.[GUID]               =    en.[CostGUID]
			INNER JOIN co000                                co        ON co.[GUID]                =    co.[GUID]
	WHERE en.[Date] >= @FromDate       AND en.[Date] <= @ToDate
) a
INNER JOIN en000 en ON en.Guid = a.Guid
INNER JOIN ac000 ac ON ac.Guid = en.AccountGuid
GROUP BY en.[AccountGUID], en.[CostGUID] , ac.[Name]

INSERT INTO #Actual
SELECT DISTINCT	stnd.AccountGUID,
		co1.[GUID] as CostGUID,
		(SELECT SUM(Balance) FROM #Actual stndr1 INNER JOIN co000 co00 ON co00.[GUID] = stndr1.CostGUID WHERE  co00.[ParentGUID] = co1.[GUID] and stndr1.AccountGuid = stnd.AccountGuid ) AS Balance,
		stnd.AccountName
FROM #Actual stnd
INNER JOIN co000 co0 ON co0.[GUID] = stnd.CostGUID
INNER JOIN co000 co1 ON co1.[GUID] = co0.[ParentGUID]

SELECT 
		en.[AccountGUID]                 AS AccountGUID,
		en.[CostGUID]                    AS CostGUID, 
		(SELECT SUM(Debit) - SUM([Credit])
		 FROM en000 WHERE AccountGUID = en.[AccountGUID] AND [CostGUID] = en.[CostGUID])  AS Balance,
		ac.Name 			 AS AccountName
INTO #Standard
FROM (
		SELECT en.Guid
		FROM ce000 ce 
			INNER JOIN en000                                en        ON en.ParentGuid            =    ce.Guid  
			INNER JOIN MAN_ACTUALSTDACC000                ac_list0    ON en.[AccountGUID]         =    ac_list0.[StandardAccountGuid]
			INNER JOIN [dbo].[fnGetAccountsList](@AcGuid,1) ac        ON ac.Guid                  =    ac_list0.[StandardAccountGuid]         -- OR ac.Guid = ac_list0.[StandardAccountGuid]
			INNER JOIN [dbo].[fnGetCostsList](@CostGuid)    co0       ON co0.[GUID]               =    en.[CostGUID]
			INNER JOIN co000                                co        ON co.[GUID]                =    co.[GUID]
		WHERE en.[Date] >= @FromDate                        AND en.[Date] <= @ToDate
) a
INNER JOIN en000 en ON en.Guid = a.Guid
INNER JOIN ac000 ac ON ac.Guid = en.AccountGuid
GROUP BY en.[AccountGUID], en.[CostGUID] , ac.[Name]

INSERT INTO #Standard
SELECT DISTINCT	stnd.AccountGUID,
		co1.[GUID] as CostGUID,
		(SELECT SUM(Balance) FROM #Standard stndr1 INNER JOIN co000 co00 ON co00.[GUID] = stndr1.CostGUID WHERE  co00.[ParentGUID] = co1.[GUID] and stndr1.AccountGuid = stnd.AccountGuid ) AS Balance,
		stnd.AccountName
FROM #Standard stnd
INNER JOIN co000 co0 ON co0.[GUID] = stnd.CostGUID
INNER JOIN co000 co1 ON co1.[GUID] = co0.[ParentGUID]

SELECT DISTINCT
		co.Guid As CostGuid,--ISNULL(CAST((SELECT Number FROM co000 WHERE GUID = co.[ParentGUID]) as NVARCHAR(10)),'') + '-' +  ISNULL(CAST(co.[Number] as NVARCHAR(10)),'')+ '            ' + co.Name        CostName	   ,
		CAST (man_ac.AccountName as NVARCHAR(100)) as AccountName,
		'›⁄·Ì' AS [TYPE],
		ISNULL(ac.Balance   , 0) AS VALUE
INTO #RESULT
FROM #Actual ac
INNER JOIN #Standard stndr             ON  ac.CostGuid = stndr.CostGuid
INNER JOIN co000    co                ON co.Guid = ac.CostGuid    OR  co.Guid = stndr.CostGuid
INNER JOIN MAN_ACTUALSTDACC000 man_ac ON ac.AccountGuid = man_ac.[ActualAccountGuid]
UNION
SELECT 
		co.Guid As CostGuid,--ISNULL(CAST((SELECT Number FROM co000 WHERE GUID = co.[ParentGUID]) as NVARCHAR(10)),'') + '-' +  ISNULL(CAST(co.[Number] as NVARCHAR(10)),'')+ '            ' + co.Name        CostName	   ,
		ISNULL(CAST (man_ac.AccountName as NVARCHAR(100)),'') as AccountName,
		'„⁄Ì«—Ì' AS [TYPE],	
		ISNULL(stndr.Balance, 0) AS VALUE
FROM #Actual ac
INNER JOIN #Standard stndr ON  ac.CostGuid = stndr.CostGuid
INNER JOIN co000     co   ON co.Guid = ac.CostGuid              OR  co.Guid = stndr.CostGuid
INNER JOIN MAN_ACTUALSTDACC000 man_ac ON stndr.AccountGuid = man_ac.[StandardAccountGuid]

SELECT 
		mn.CostGuid    CostGuid	   ,
		ISNULL(CAST((SELECT Number FROM co000 WHERE GUID = co.[ParentGUID]) as NVARCHAR(10)),'') + '-' +  ISNULL(CAST(co.[Number] as NVARCHAR(10)),'')+ '            ' + co.Name        CostName	   ,
		co.ParentGuid			   ,
		mn.FormGuid	   FormGuid	   ,
		p.[Qty]        PlanQty     ,
		mn.[Qty]       ManQty      ,
	   (mn.[QTY] - p.[QTY]) as def ,
	   CASE p.[Qty] WHEN 0 THEN 0 ELSE ROUND((mn.[Qty]     / p.[Qty]), 2) * 100		END AS UsePerc,
	   CASE p.[Qty] WHEN 0 THEN 0 ELSE ROUND(1 - (mn.[Qty] / p.[Qty]), 2) * 100     END AS LostPerc
INTO #LIST
FROM 
(
	SELECT FORMGUID , SUM(QTY) QTY 
	FROM [PSI000] 
	WHERE [StartDate] >= @FromDate
	  AND [EndDate]   <= @ToDate
	GROUP BY [FormGuid]
)p 
INNER JOIN 
(
	SELECT ISNULL(FORMGUID,0x0) as FormGuid , co.Guid CostGuid , SUM(QTY) QTY 
	FROM [MN000] MN
	INNER JOIN fnGetCostsList(@CostGuid) co ON co.[Guid] = mn.[OutCostGUID]
	WHERE  [OutDate] >= @FromDate
	   AND [OutDate] <= @ToDate
	GROUP BY [FormGuid] ,co.Guid
) mn ON   mn.FormGuid = p.FormGuid
INNER JOIN co000 co ON co.[GUID] = mn.[CostGuid]

IF(@FormGuid <> 0x0)
	DELETE FROM #LIST WHERE FormGuid <> @FormGuid

INSERT INTO #LIST
SELECT DISTINCT
	   co.Guid CostGuid ,
	   CAST(co.[Number] as NVARCHAR(10)) + '            ' + co.Name CostName ,
	   0x0  ParentGuid  ,
	   0x0  FormGuid    ,
	   (SELECT SUM(PlanQty) FROM #LIST WHERE ParentGuid = Guid )  as PlanQty          ,
	   (SELECT SUM(ManQty)  FROM #LIST WHERE ParentGuid = Guid )  as ManQty           ,
	   (SELECT SUM(ManQty) - SUM(PlanQty) FROM #List WHERE ParentGuid = Guid ) as def,
	   0 UsePerc,
	   0 LostPerc
FROM #LIST lst
INNER JOIN co000 co ON co.Guid = lst.ParentGuid


UPDATE #LIST SET 
	UsePerc  =  (CASE PlanQty WHEN 0 THEN 0 ELSE ROUND((ManQty     / PlanQty), 2) * 100	END), 
	LostPerc =  (CASE PlanQty WHEN 0 THEN 0 ELSE ROUND(1 - (ManQty / PlanQty), 2) * 100 END)
FROM #LIST
WHERE PARENTGUID = 0x0


INSERT INTO #RESULT
SELECT  DISTINCT
		res.CostGuid As CostGuid,--ISNULL(CAST((SELECT Number FROM co000 WHERE GUID = co.[ParentGUID]) as NVARCHAR(10)),'') + '-' +  ISNULL(CAST(co.[Number] as NVARCHAR(10)),'')+ '            ' + co.Name        CostName	   ,
		CAST (res.AccountName as NVARCHAR(100)) as AccountName,
		'«‰Õ—«›' AS [TYPE],	
		SUM(res.VALUE) AS VALUE
FROM #RESULT res
GROUP BY res.CostGuid , res.AccountName

SELECT 
		lst.CostName CostName,
		res.AccountName AS AccountName,
		'«‰Õ—«›' AS [TYPE],		
		res.value AS Value
FROM #LIST lst 
INNER JOIN #Result res ON lst.CostGuid = res.CostGuid 
WHERE res.Type = '«‰Õ—«›'
UNION
SELECT lst.CostName CostName,
		res.AccountName AS AccountName,
	   '‰”»… «·Âœ—' AS Type,
	   LostPerc AS Value
FROM #LIST lst
INNER JOIN #Result res ON lst.CostGuid = res.CostGuid 
WHERE res.Type = '«‰Õ—«›'
UNION
SELECT lst.CostName CostName,
		res.AccountName AS AccountName,
	   '«‰Õ—«› »”»» ÷⁄› «·«‰ «Ã' AS Type,
	   (LostPerc / 100) * res.Value AS Value
FROM #LIST lst 
INNER JOIN #Result res ON lst.CostGuid = res.CostGuid 
WHERE res.Type = '«‰Õ—«›'
UNION
SELECT lst.CostName CostName,
		res.AccountName AS AccountName,
	   '«‰Õ—«› ⁄‰ «·„Ê«“‰…' AS Type,
	   ((100 - LostPerc) / 100) * res.Value AS Value
FROM #LIST lst 
INNER JOIN #Result res ON lst.CostGuid = res.CostGuid 
WHERE res.Type = '«‰Õ—«›'
################################################################################
CREATE PROC RepGetManMatChildTree
(
     @MATGUID    [UNIQUEIDENTIFIER], 
     @PARENTPATH [NVARCHAR](max) = ''
)
AS 
      DECLARE @MANFORM  [UNIQUEIDENTIFIER]
      DECLARE @SELECTED UNIQUEIDENTIFIER
      DECLARE @MAT UNIQUEIDENTIFIER
      DECLARE @CNT INT
      DECLARE @PPATH [NVARCHAR](1000)
      
      SELECT TOP 1 @MANFORM = [PARENTGUID] 
      FROM MI000 MI
      INNER JOIN MN000 MN ON MN.GUID = MI.PARENTGUID
      INNER JOIN FM000 FM ON FM.GUID = MN.FORMGUID
      WHERE   MN.TYPE = 0 AND MI.TYPE = 0 AND MATGUID = @MATGUID
      PRINT @MANFORM
               
      IF (@PARENTPATH = '')
      BEGIN
				  IF NOT EXISTS ( SELECT * FROM tempdb..sysobjects WHERE name = '##TREEBUFFER')
                  CREATE TABLE ##TREEBUFFER
                  (
                        [GUID]               [UNIQUEIDENTIFIER],
                        [PARENTGUID]         [UNIQUEIDENTIFIER],
                        [MATGUID]            [UNIQUEIDENTIFIER],
                        [ISHALFREADYMAT]     [BIT]                  ,
                        [PATH]               [NVARCHAR](1000)  ,
                        [QTY]                [FLOAT]                ,
						[Unit]				 [INT],	
                        [TYPE]               [INT]                ,
                        [IsSemiReadyMat]     [INT]                  
                  )
                  SET @PARENTPATH = '0'
      END
      
			INSERT INTO ##TREEBUFFER
            SELECT  MI.[GUID] , MI.PARENTGUID , MI.MATGUID , DBO.ISHALFREADYMAT(MI.MATGUID) , @PARENTPATH + '.' + CAST(MI.NUMBER AS NVARCHAR(100)) , MI.QTY , MI.Unity, MI.[TYPE] , 0
            FROM   MI000 MI
			INNER JOIN MN000 MN ON MN.GUID = MI.PARENTGUID
			INNER JOIN FM000 FM ON FM.GUID = MN.FORMGUID
            WHERE   MN.Type = 0 AND MI.TYPE = 1 AND PARENTGUID = @MANFORM 

      SELECT TOP 1
            @SELECTED = [GUID],
            @MAT = [MATGUID],
            @PPATH     = [PATH]
      FROM ##TREEBUFFER
      WHERE ISHALFREADYMAT = 1
      ORDER BY [PATH]          
      IF(@SELECTED <> 0X0)
      BEGIN
            UPDATE ##TREEBUFFER SET [ISHALFREADYMAT] = 0 , [IsSemiReadyMat] = 1 WHERE GUID = @SELECTED
            EXEC [DBO].[REPGETMANMATCHILDTREE]  @MAT, @PPATH
      END
      IF(@PARENTPATH = '0')
      BEGIN
            SET @CNT = (SELECT COUNT(*) FROM ##TREEBUFFER WHERE ISHALFREADYMAT = 1)
            IF(@CNT = 0)
            BEGIN
                  SELECT [TREE].[GUID] ,[TREE].[PARENTGUID] ,[FM].[Name] AS FORMNAME,[MATGUID] , [MT].[NAME] AS MATNAME,[TREE].[QTY],[TREE].[PATH], [TREE].[Unit], [TREE].[IsSemiReadyMat]
                  FROM ##TREEBUFFER TREE
                  LEFT JOIN MN000 MN ON [MN].[GUID] = [TREE].[PARENTGUID]                 
                  LEFT JOIN FM000 FM ON [FM].[GUID] = [MN].[FORMGUID]
                  LEFT JOIN MT000 MT ON [MT].[GUID] = [TREE].[MATGUID]
                  ORDER BY [TREE].[PATH]               
	          DROP TABLE ##TREEBUFFER
            END
      END
################################################################################
#END