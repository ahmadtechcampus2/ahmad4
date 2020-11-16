####################################################################
CREATE PROCEDURE prcMatMoveSeveralYears
-- Params ---------------------------   
	@Material			UNIQUEIDENTIFIER,
	@StoreGUID			UNIQUEIDENTIFIER,
	@CustomerGUID		UNIQUEIDENTIFIER,
	@CostGUID			UNIQUEIDENTIFIER,
	@CurrencyGUID		UNIQUEIDENTIFIER,
	@StartDate			DATETIME,
	@EndDate			DATETIME,
	@Class				NVARCHAR(250),
	@Contain			NVARCHAR(200),    
    @NotContain			NVARCHAR(200),
	@ShowPosted			BIT,
	@ShowUnPosted		BIT,
	@ReportSourceFlag	INT,
	@UseUnit			INT,
	@MatNameToSearch	NVARCHAR(250),
	@MatCodeToSearch	NVARCHAR(250),
	@SearchBy			INT			  -- 1 : ByGuid | 2 : ByName | 3 : ByCode

-------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------
CREATE TABLE #AvgPrevBalance
(
	AvgPrevPrice	    FLOAT
)

CREATE TABLE #MasterResult
(
	Number			    INT IDENTITY(1,1),
	FirstPeriodDate		DATETIME,
	EndPeriodDate		DATETIME,
	PreviousBalance		FLOAT,
	InQty				FLOAT,
	OutQty				FLOAT,
	MoveBalance			FLOAT,
	Balance				FLOAT,
	MaxPurchase			FLOAT,
	MinPurchase			FLOAT,
	AvgPurchase			FLOAT,
	AvgSell				FLOAT,
	AvgPreviousBalance  FLOAT,
	Unit				NVARCHAR(200),
	DataBaseName		NVARCHAR(256),
	MatGuid				UNIQUEIDENTIFIER
)


CREATE TABLE #DetailsResult
(
	MatGUID			  UNIQUEIDENTIFIER,
	BiGUID			  UNIQUEIDENTIFIER,
	BUGUID			  UNIQUEIDENTIFIER,
	[Date]			  DATETIME,
	FormatedNum		  NVARCHAR(250),
	BillType		  INT,
	AffectCostPrice   BIT,
	UnitFact		  INT,
	Unit			  NVARCHAR(250),
	detailsInQty	  FLOAT,
	detailsOutQty	  FLOAT,
	detailsBalanceQty FLOAT,

	InBonus			  FLOAT,
	OutBonus		  FLOAT,
					  
	InValue			  FLOAT,
	OutValue		  FLOAT,
	InPrice			  FLOAT,
	OutPrice		  FLOAT,
					  
	IsInput			  INT,
	BuNote			  NVARCHAR(1000),
	BiNote			  NVARCHAR(1000),
	BiStore			  NVARCHAR(250),
	SaleMan			  FLOAT,
	Vendor			  FLOAT,
	CustomerName	  NVARCHAR(250),
	BiCostCenter	  NVARCHAR(250),
	BiLength		  FLOAT,
	BiWidth			  FLOAT,
	BiHeight		  FLOAT,
	BiCount			  FLOAT,
	[ExpireDate]	  DATETIME,
	ProductionDate	  DATETIME,
	BiClass			  NVARCHAR(250),
	BranchName		  NVARCHAR(250),
	DatabaseName	  NVARCHAR(256),

	UserSecurity			INT,
	Security				INT
)

 CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT]) 

 DECLARE @DataBaseName		 NVARCHAR(128)
 DECLARE @FirstPeriodDate	 DATETIME
 DECLARE @EndPeriodDate		 DATETIME
 DECLARE @Query				 NVARCHAR(300)
 DECLARE @MaterialGUID		 UNIQUEIDENTIFIER
 DECLARE @GetBill			 NVARCHAR(MAX)
 DECLARE @GetPreviousBalance NVARCHAR(MAX)
 DECLARE @UserId			 UNIQUEIDENTIFIER
 DECLARE @PrevBalance		 FLOAT
 DECLARE @firstLoop			 BIT
 DECLARE @Lang				 INT

DECLARE @GetAvgPrevBalance  NVARCHAR(MAX)
DECLARE @AvgPrevPrice FLOAT = 0

	EXEC @Lang = [dbo].fnConnections_GetLanguage;

	DECLARE AllDatabases CURSOR FOR				 
	SELECT [DatabaseName], [FirstPeriod], [EndPeriod] FROM FnGetReportDataSources(@StartDate, @EndDate) ORDER BY [FirstPeriod]
	OPEN AllDatabases;	 

	SET @MaterialGUID = @Material;
	SET @firstLoop   = 1;
	FETCH NEXT FROM AllDatabases INTO @DataBaseName, @FirstPeriodDate, @EndPeriodDate;
	WHILE (@@FETCH_STATUS = 0)
	BEGIN 
	----------Set User Admin
		IF(@DataBaseName <> DB_NAME())
		BEGIN
		 DECLARE @SetUserAdmin  NVARCHAR(MAX) ='EXEC [' + @DataBaseName + '].[dbo].[NSPrcConnectionsAddAdmin]'
		 EXEC sp_executesql @SetUserAdmin
		 END
	   ---------------- Search By Name
	   IF @SearchBy = 2
	   BEGIN
		   SET @MaterialGUID = 0x0
		   SET @Query = 'SELECT @GuidOut = GUID FROM  [' + @DataBaseName + '].[dbo].[mt000] WHERE Name = ''' + @MatNameToSearch + ''''
		   EXEC sp_executesql @Query, N' @GuidOut UNIQUEIDENTIFIER OUTPUT', @GuidOut = @MaterialGUID OUTPUT;
	   END

	   ---------------- Search By Code
	   IF @SearchBy = 3
	   BEGIN
	       SET @MaterialGUID = 0x0
		   SET @Query = 'SELECT @GuidOut = GUID FROM  [' + @DataBaseName + '].[dbo].[mt000] WHERE Code = ''' + @MatCodeToSearch + '''';
		   EXEC sp_executesql @Query, N' @GuidOut UNIQUEIDENTIFIER OUTPUT', @GuidOut = @MaterialGUID OUTPUT;
	   END

	   ---------------- Previous Balance For First Data
		IF((@firstLoop = 1) AND (@StartDate > @FirstPeriodDate))
	   BEGIN
		   SET @GetPreviousBalance = 
		   'SELECT @PrevBal = SUM((biQty* (CASE btIsInput WHEN 0 THEN -1 ELSE 1 END))/(( CASE '+CONVERT(NVARCHAR(10), @UseUnit) +
		   '	WHEN 0 THEN 1   
				WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END  
				WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END  
				WHEN 3 THEN  
					CASE[mtDefUnit]   
						WHEN 1 THEN 1   
						WHEN 2 THEN CASE [mtUnit2Fact]  WHEN 0 THEN 1 ELSE [mtUnit2Fact]  END  
						WHEN 3 THEN CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE[mtUnit3Fact] END  
					END  
			END)))' +
			'FROM  [' + @DataBaseName + '].[dbo].[vwExtended_bi] 
			WHERE ( biMatPtr = ''' + CONVERT(NVARCHAR(38),@MaterialGUID) + '''
			OR mtParent = ''' + CONVERT(NVARCHAR(38),@MaterialGUID) + ''' )
			AND buDate BETWEEN ''' + CONVERT(NVARCHAR(38),@FirstPeriodDate) + ''' AND ''' + CONVERT(NVARCHAR(38),DATEADD(DAY, -1, @StartDate) ) + '''';
		   EXEC sp_executesql @GetPreviousBalance, N' @PrevBal FLOAT OUTPUT', @PrevBal = @PrevBalance OUTPUT;
	   END

	   ---------------- Get user id for security
	   IF @DataBaseName = DB_NAME()
	   BEGIN
			SELECT @UserId = [dbo].[fnGetCurrentUserGUID]()
	   END
	   ELSE
	   BEGIN 
		   SET @Query = 'SELECT TOP 1 @UserIdOut=GUID  FROM [' + @DataBaseName + N'].[dbo].us000 WHERE bAdmin = 1'
		   EXEC sp_executesql @Query, N' @UserIdOut UNIQUEIDENTIFIER OUTPUT', @UserIdOut = @UserId OUTPUT;   
	   END

	   ---------------- Get Bill
	   SET @GetBill =  N'INSERT INTO #DetailsResult EXEC [' + @DataBaseName + '].[dbo].[prcMatMovePerYear] ' +
			'''' + CONVERT(NVARCHAR(38), @MaterialGUID) + ''','  +
			'''' + CONVERT(NVARCHAR(38), @StoreGUID) + ''','  +
			'''' + CONVERT(NVARCHAR(38), @CustomerGUID) + ''','  +
			'''' + CONVERT(NVARCHAR(38), @CostGUID) + ''','  +
			'''' + CONVERT(NVARCHAR(38), @CurrencyGUID) + ''','  +
			'''' + CONVERT(NVARCHAR(38), @UserId)   + ''',' +
			'''' + CONVERT(NVARCHAR(50), @StartDate) + ''','  +
			'''' + CONVERT(NVARCHAR(50), @EndDate) + ''','  +
			'''' + @Class + ''','  +
			'''' + @Contain + ''','  +
			'''' + @NotContain + ''','  +
			CONVERT(NVARCHAR(10), @UseUnit) + ',' +
			CONVERT(NVARCHAR(10), @ShowPosted) + ',' +
			CONVERT(NVARCHAR(10), @ShowUnPosted) + ',' +
			CONVERT(NVARCHAR(10), @ReportSourceFlag) + ',' +
			CONVERT(NVARCHAR(10), @firstLoop) + ',' +
			CONVERT(NVARCHAR(10), @Lang);


	EXEC sp_executesql @GetBill;

	----------------------------------- Get Avrerge Previous Price
	IF(@firstLoop = 1)
	BEGIN
			CREATE TABLE [#t_Prices] ([mtNumber] [UNIQUEIDENTIFIER],[APrice] [FLOAT])
			CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], [UnPostedSecurity] [INTEGER])
			DECLARE @GetBillsTypesTbl  NVARCHAR(MAX)
			DECLARE @Guid UNIQUEIDENTIFIER = 0x0;
			SET @GetBillsTypesTbl  =  N' USE '+ @DataBaseName + '; 
			INSERT INTO [#BillsTypesTbl]EXEC [' + @DataBaseName +'].[dbo].[prcGetBillsTypesList2] '+
			'''' + CONVERT(NVARCHAR(38), @Guid) + '''' 
			EXEC sp_executesql @GetBillsTypesTbl;
		
		   SET @GetAvgPrevBalance =  N'EXEC [' + @DataBaseName + '].[dbo].[prcGetAvgPrevPriceOneMaterial] ' +
				'''' + CONVERT(NVARCHAR(38), @MaterialGUID) + ''',' +
				'''' + CONVERT(NVARCHAR(38), @CurrencyGUID) + ''',' +
				'''' + CONVERT(VARCHAR(50), @StartDate, 21) + '''' 

		EXEC sp_executesql @GetAvgPrevBalance;
		INSERT INTO #AvgPrevBalance SELECT APrice FROM #t_Prices
		DROP TABLE [#BillsTypesTbl]
		DROP TABLE [#t_Prices]
	END
	----------------------------------- MASTER RESULT
	SELECT ISNULL(SUM(detailsInQty  + CASE detailsInQty  WHEN 0 THEN 0 ELSE InBonus END), 0) AS SumInQty, 
		   ISNULL(SUM(detailsOutQty + CASE detailsOutQty WHEN 0 THEN 0 ELSE OutBonus END), 0) AS SumOutQty
	INTO #CalcQty 
	FROM #DetailsResult 
	WHERE DatabaseName = @DataBaseName

	INSERT INTO #MasterResult (DataBaseName, FirstPeriodDate, EndPeriodDate, PreviousBalance, InQty, OutQty, MoveBalance, Balance,
							   MaxPurchase, MinPurchase, AvgPurchase, AvgSell, AvgPreviousBalance, Unit, MatGuid)
	VALUES(
	@DataBaseName, 
	CASE @firstLoop WHEN 1 THEN @StartDate ELSE @FirstPeriodDate END ,
	@EndPeriodDate,
	CASE @firstLoop WHEN 1 THEN ISNULL(@PrevBalance, 0) ELSE 0 END,
	(SELECT SumInQty  FROM #CalcQty),
	(SELECT SumOutQty FROM #CalcQty),
	(SELECT SumInQty  FROM #CalcQty)  - (SELECT SumOutQty FROM #CalcQty),
	CASE @firstLoop WHEN 1 THEN ((SELECT SumInQty FROM #CalcQty) - (SELECT SumOutQty FROM #CalcQty)) + (ISNULL(@PrevBalance, 0)) ELSE 0 END,
	(SELECT ISNULL(MAX(InPrice), 0) FROM #DetailsResult WHERE DatabaseName = @DataBaseName AND IsInput = 1),
	(SELECT ISNULL(MIN(InPrice), 0) FROM #DetailsResult WHERE DatabaseName = @DataBaseName AND IsInput = 1),
	(SELECT CASE SUM(detailsInQty+InBonus) WHEN 0 THEN 0 ELSE ISNULL(SUM(detailsInQty*InPrice) / SUM(detailsInQty+InBonus), 0) END  FROM #DetailsResult WHERE DatabaseName = @DataBaseName AND BillType IN(0,4) ),
	(SELECT CASE SUM(detailsOutQty+OutBonus) WHEN 0 THEN 0 ELSE ISNULL(SUM(detailsOutQty*OutPrice) / SUM(detailsOutQty+OutBonus), 0) END FROM #DetailsResult WHERE DatabaseName = @DataBaseName AND BillType = 1),
	ISNULL((CASE @firstLoop WHEN 1 THEN (SELECT ISNULL(AvgPrevPrice, 0) FROM #AvgPrevBalance) ELSE 0 END), 0),
	ISNULL((SELECT Top 1 Unit FROM #DetailsResult WHERE DatabaseName = @DataBaseName ), ''),
	@Material
	)

	DROP TABLE #CalcQty
	------------------------------------------------

	FETCH NEXT FROM AllDatabases INTO  @DataBaseName, @FirstPeriodDate, @EndPeriodDate;
	SET @firstLoop   = 0
	END

	CLOSE      AllDatabases;
	DEALLOCATE AllDatabases;

	EXEC prcCheckSecurity @result  = '#DetailsResult'

--set the end period date of the last database to be the EndDate from report parameters
	UPDATE #MasterResult
	SET EndPeriodDate = @EndDate
	WHERE DatabaseName = @DataBaseName

--------Prossicing the balance and previous balance in Master Result--------
	DECLARE @RowNumber INT = 1
	WHILE (SELECT COUNT(*) FROM #MasterResult) > @RowNumber
	BEGIN
		UPDATE #MasterResult SET PreviousBalance = (SELECT Balance FROM #MasterResult WHERE Number = @RowNumber)
		WHERE Number = @RowNumber + 1

		UPDATE #MasterResult SET Balance = (SELECT MoveBalance + PreviousBalance FROM #MasterResult WHERE Number = @RowNumber + 1)
		WHERE Number = @RowNumber + 1

		SET @RowNumber = @RowNumber + 1
	END

	--IF (@BalanceZeroOnFirstPeriod = 1)
	--BEGIN
	--	UPDATE #MasterResult SET PreviousBalance = 0
	--	WHERE Number = 1
	--END
----------------------------------------------------------------------------

 SELECT * FROM #MasterResult

 SELECT *, detailsOutQty*OutPrice AS OutVal, detailsInQty*InPrice AS InVal 
 FROM #DetailsResult
 ORDER BY [Date], [BillType]

 SELECT * FROM #SecViol
####################################################################
CREATE PROCEDURE prcMatMovePerYear
-- Params -------------------------------   
	@MaterialGUID		UNIQUEIDENTIFIER,
	@StoreGUID			UNIQUEIDENTIFIER,
	@CustomerGUID		UNIQUEIDENTIFIER,
	@CostGUID			UNIQUEIDENTIFIER,
	@CurrencyGUID		UNIQUEIDENTIFIER,
	@UserID				UNIQUEIDENTIFIER = 0x0,
	@StartDate			DATETIME,
	@EndDate			DATETIME,
	@Class				NVARCHAR(250),
	@Contain			NVARCHAR(200),    
    @NotContain			NVARCHAR(200),
	@UseUnit			INT,
	@ShowPosted			BIT,
	@ShowUnPosted		BIT,
	@ReportSourceFlag	INT,
	@IsFirstData		INT,
	@Lang				INT
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------

DECLARE @BillPurchase		INT = 2
DECLARE @BillSell			INT = 4
DECLARE @BillReturnPurchase INT = 8
DECLARE @BillReturnSell		INT = 16
DECLARE @BillInput			INT = 32
DECLARE @BillOutput			INT = 64
DECLARE @OrderSell			INT = 128
DECLARE @OrderBuy			INT = 256
DECLARE @Transfer			INT = 512


IF(@IsFirstData = 1)
BEGIN
	DECLARE @FirstPeriodDateOfFirstData DATETIME = (SELECT CAST(value AS DATETIME) FROM op000 WHERE Name = 'AmnCfg_FPDate')
	IF(@StartDate < @FirstPeriodDateOfFirstData)
	BEGIN
		SET @StartDate = @FirstPeriodDateOfFirstData
	END
END



SELECT 
	 BI.biMatPtr,
	 BI.biGUID,
	 BI.buGUID,
	 BI.buDate,
	 BI.buNumber,
	 BI.buFormatedNumber,
	 BI.btBillType,
	 BI.btAffectCostPrice,
	CASE @UseUnit   
				WHEN 0 THEN 1   
				WHEN 1 THEN CASE BI.[mtUnit2Fact] WHEN 0 THEN 1 ELSE BI.[mtUnit2Fact] END  
				WHEN 2 THEN CASE BI.[mtUnit3Fact] WHEN 0 THEN 1 ELSE BI.[mtUnit3Fact] END  
				WHEN 3 THEN  
					CASE BI.[mtDefUnit]   
						WHEN 1 THEN 1   
						WHEN 2 THEN CASE BI.[mtUnit2Fact]  WHEN 0 THEN 1 ELSE BI.[mtUnit2Fact]  END  
						WHEN 3 THEN CASE BI.[mtUnit3Fact] WHEN 0 THEN 1 ELSE BI.[mtUnit3Fact] END  
					END  
			END UnitFact,
		 CASE @UseUnit   
				WHEN 0 THEN BI.[MtUnity]    
				WHEN 1 THEN CASE BI.[MtUnit2] WHEN '' THEN  BI.[MtUnity] ELSE BI.[MtUnit2] END  
				WHEN 2 THEN CASE BI.[MtUnit3] WHEN '' THEN  BI.[MtUnity] ELSE BI.[MtUnit3] END  
				WHEN 3 THEN  
					CASE BI.[mtDefUnit]  
						WHEN 1 THEN BI.[MtUnity]    
						WHEN 2 THEN CASE BI.[MtUnit2]  WHEN '' THEN BI.[MtUnity]  ELSE BI.[MtUnit2]  END  
						WHEN 3 THEN CASE BI.[MtUnit3] WHEN '' THEN BI.[MtUnity]  ELSE BI.[MtUnit3] END  
					END  
			END  UnitName,

	 CASE BI.btIsInput WHEN 1 THEN BI.biQty/( CASE @UseUnit   
				WHEN 0 THEN 1   
				WHEN 1 THEN CASE BI.[mtUnit2Fact] WHEN 0 THEN 1 ELSE BI.[mtUnit2Fact] END  
				WHEN 2 THEN CASE BI.[mtUnit3Fact] WHEN 0 THEN 1 ELSE BI.[mtUnit3Fact] END  
				WHEN 3 THEN  
					CASE BI.[mtDefUnit]   
						WHEN 1 THEN 1   
						WHEN 2 THEN CASE BI.[mtUnit2Fact]  WHEN 0 THEN 1 ELSE BI.[mtUnit2Fact]  END  
						WHEN 3 THEN CASE BI.[mtUnit3Fact] WHEN 0 THEN 1 ELSE BI.[mtUnit3Fact] END  
					END  
			END) ELSE 0 END AS InQty,




	 CASE BI.btIsInput WHEN 0 THEN BI.biQty/( CASE @UseUnit   
				WHEN 0 THEN 1   
				WHEN 1 THEN CASE BI.[mtUnit2Fact] WHEN 0 THEN 1 ELSE BI.[mtUnit2Fact] END  
				WHEN 2 THEN CASE BI.[mtUnit3Fact] WHEN 0 THEN 1 ELSE BI.[mtUnit3Fact] END  
				WHEN 3 THEN  
					CASE BI.[mtDefUnit]   
						WHEN 1 THEN 1   
						WHEN 2 THEN CASE BI.[mtUnit2Fact]  WHEN 0 THEN 1 ELSE BI.[mtUnit2Fact]  END  
						WHEN 3 THEN CASE BI.[mtUnit3Fact] WHEN 0 THEN 1 ELSE BI.[mtUnit3Fact] END  
					END  
			END) ELSE 0 END AS OutQty,

	 CASE BI.btIsInput WHEN 1 THEN BI.biBonusQnt
					          ELSE 0 END AS InBonus,

	 CASE BI.btIsInput WHEN 0 THEN BI.biBonusQnt
					          ELSE 0 END AS OutBonus,

	 CASE BI.btIsInput WHEN 1 THEN [dbo].[fnCurrency_fix](BI.biPrice, BI.biCurrencyPtr, BI.biCurrencyVal, @CurrencyGUID, BI.buDate) * BI.biBillQty 
					          ELSE 0 END AS InValue,

	 CASE BI.btIsInput WHEN 0 THEN [dbo].[fnCurrency_fix](BI.biPrice, BI.biCurrencyPtr, BI.biCurrencyVal, @CurrencyGUID, BI.buDate) * BI.biBillQty 
					          ELSE 0 END AS OutValue,

	 BI.btDiscAffectCost,
	 BI.btExtraAffectCost,
	 BI.btDiscAffectProfit,
	 BI.btExtraAffectProfit,

	 [dbo].[fnCurrency_fix](BI.biDiscount, BI.biCurrencyPtr, BI.biCurrencyVal, @CurrencyGUID, BI.buDate) biDiscount,
	 [dbo].[fnCurrency_fix](BI.biTotalDiscountPercent, BI.biCurrencyPtr, BI.biCurrencyVal, @CurrencyGUID, BI.buDate) biTotalDiscountPercent,
	 [dbo].[fnCurrency_fix](BI.biExtra, BI.biCurrencyPtr, BI.biCurrencyVal, @CurrencyGUID, BI.buDate) biExtra,
	 [dbo].[fnCurrency_fix](BI.biTotalExtraPercent, BI.biCurrencyPtr, BI.biCurrencyVal, @CurrencyGUID, BI.buDate) biTotalExtraPercent,

	 BI.btIsInput,
	 BI.BuNotes,
	 BI.BiNotes,
	 	 	CASE @Lang WHEN 0 THEN ST.Name 
					   ELSE CASE ST.LatinName WHEN '' THEN ST.Name
											  ELSE CU.LatinName END END		  AS  StoreName,
	 BI.buSalesmanPtr,
	 BI.buVendor,
	 ISNULL(CASE @Lang WHEN 0 THEN CU.CustomerName 
					   ELSE CASE CU.LatinName WHEN '' THEN CU.CustomerName 
											  ELSE CU.LatinName END END , '') AS  CustomerName,
	 ISNULL(CASE @Lang WHEN 0 THEN CO.Name 
					   ELSE CASE CO.LatinName WHEN '' THEN CO.Name 
											  ELSE CO.LatinName END END , '') AS  CostName,
	 BI.biLength,
	 BI.biWidth,
	 BI.biHeight,
	 BI.biCount,
	 BI.biExpireDate,
	 BI.biProductionDate,
	 BI.BiClassptr,
	 ISNULL(BR.Name , '')AS BranchName,
	 DB_NAME() AS DataBaseName,
	 BuTbl.Security				AS UserSecurity,
	 BI.buSecurity				AS Security
		
INTO #FirstResult
FROM vwExtended_bi BI
LEFT JOIN bt000 BT ON BI.buType		= BT.[GUID]
LEFT JOIN st000 ST ON BI.BiStorePtr = ST.[GUID]
LEFT JOIN co000 CO ON BI.biCostPtr  = CO.[GUID]
LEFT JOIN cu000 CU ON BI.buCustPtr  = CU.[GUID]
LEFT JOIN br000 BR ON BI.buBranch   = BR.[GUID] 
LEFT JOIN [dbo].[fnGetBillsTypesList](null, @UserID)  BuTbl ON BuTbl.[Guid] = BI.buType

WHERE  (BI.biMatPtr = @MaterialGUID OR BI.mtParent = @MaterialGUID)
AND	   BI.buDate BETWEEN @StartDate AND @EndDate
AND	   (@StoreGUID	  = 0x0 OR @StoreGUID    = BI.BiStorePtr)
AND	   (@CustomerGUID = 0x0 OR @CustomerGUID = BI.buCustPtr)
AND    (@CostGUID	  = 0x0 OR @CostGUID	 = BI.biCostPtr)
AND   ((@ShowPosted   = 0  AND BI.buIsPosted = 0) OR @ShowPosted   = 1)
AND   ((@ShowUnPosted = 0  AND BI.buIsPosted = 1) OR @ShowUnPosted = 1)
AND	   (@Class		  = ''	OR @Class		 = [biClassPtr])
AND    (@Contain	  = ''  OR BI.buNotes LIKE	   '%'+ @Contain	+ '%')
AND    (@NotContain	  = ''  OR BI.buNotes NOT LIKE '%'+ @NotContain + '%')
AND   (NOT(BT.[Type] = 2 AND BT.SortNum = 1) OR ((BT.[Type] = 2 AND BT.SortNum = 1) AND BI.buDate >= @StartDate))

AND	   (
			(BI.btBillType = 0 AND @ReportSourceFlag & @BillPurchase	   = @BillPurchase AND (BI.btType <> 3 AND BI.btType <> 4))		 ------ ‘—«¡
		 OR (BI.btBillType = 1 AND @ReportSourceFlag & @BillSell		   = @BillSell)							------ „»Ì⁄
		 OR (BI.btBillType = 2 AND @ReportSourceFlag & @BillReturnPurchase = @BillReturnPurchase)				------ „— Ã⁄ ‘—«¡
		 OR (BI.btBillType = 3 AND @ReportSourceFlag & @BillReturnSell	   = @BillReturnSell)					------ „— Ã⁄ „»Ì⁄
		 OR (BI.btBillType = 4 AND @ReportSourceFlag & @BillInput		   = @BillInput  AND BI.btType != 6)	------ ≈œŒ«·
		 OR (BI.btBillType = 5 AND @ReportSourceFlag & @BillOutput		   = @BillOutput AND BI.btType != 5)	------ ≈Œ—«Ã
		 OR (BI.btType	   = 5 AND @ReportSourceFlag & @OrderSell		   = @OrderSell)						------ ÿ·»«  „»Ì⁄
		 OR (BI.btType	   = 6 AND @ReportSourceFlag & @OrderBuy		   = @OrderBuy)							------ ÿ·»«  ‘—«¡
		 OR ((BI.btType	= 3 OR BI.btType = 4) AND @ReportSourceFlag & @Transfer = @Transfer))					------ „‰«ﬁ·«  

SELECT 
	 biMatPtr,
	 biGUID,
	 buGUID,
	 buDate,
	 buFormatedNumber,
	 btBillType,
	 btAffectCostPrice,
	 UnitFact, 
	 UnitName,
	 InQty,
	 OutQty,
	 InQty - OutQty AS BalanceQty,
	 InBonus,
	 OutBonus,
	 InValue,
	 OutValue,
----------------------------------------- InPrice
	 CASE WHEN btIsInput = 1 AND InQty <> 0 THEN 

		CASE ((btDiscAffectCost | btDiscAffectProfit) & (~btExtraAffectCost & ~btExtraAffectProfit) ) 
			 WHEN 1 THEN ((InValue - biDiscount - biTotalDiscountPercent) / InQty) 
		ELSE 
			CASE  ((~btDiscAffectCost & ~btDiscAffectProfit) & (btExtraAffectCost | btExtraAffectProfit)) 
				  WHEN 1 THEN ((InValue + biExtra + biTotalExtraPercent) / InQty)  
			ELSE 
				CASE (~btDiscAffectCost & ~btExtraAffectCost & ~btDiscAffectProfit & ~btExtraAffectProfit)  
					 WHEN 1 THEN (InValue / InQty)
				ELSE 
					CASE ((btDiscAffectCost | btDiscAffectProfit) & (btExtraAffectCost | btExtraAffectProfit)) 
						 WHEN 1 THEN ((InValue + biExtra - biDiscount + biTotalExtraPercent - biTotalDiscountPercent) / InQty)
					END
				END
			END
		END

	ELSE 0 END AS InPrice,

----------------------------------------- OutPrice
	CASE WHEN btIsInput = 0 AND OutQty <> 0 THEN

		CASE ((btDiscAffectCost | btDiscAffectProfit) & (~btExtraAffectCost & ~btExtraAffectProfit) ) 
			 WHEN 1 THEN ((OutValue - biDiscount - biTotalDiscountPercent) / OutQty) 
		ELSE 
			CASE  ((~btDiscAffectCost & ~btDiscAffectProfit) & (btExtraAffectCost | btExtraAffectProfit)) 
				  WHEN 1 THEN ((OutValue + biExtra + biTotalExtraPercent) / OutQty)  
			ELSE 
				CASE (~btDiscAffectCost & ~btExtraAffectCost & ~btDiscAffectProfit & ~btExtraAffectProfit)  
					 WHEN 1 THEN (OutValue / OutQty)
				ELSE 
					CASE ((btDiscAffectCost | btDiscAffectProfit) & (btExtraAffectCost | btExtraAffectProfit)) 
						 WHEN 1 THEN ((OutValue + biExtra - biDiscount + biTotalExtraPercent - biTotalDiscountPercent) / OutQty)
					END
				END
			END
		END

	ELSE 0 END AS OutPrice,

	 ------------------------------------------------------------------------------
	 btIsInput,
	 BuNotes,
	 BiNotes,
	 StoreName,
	 buSalesmanPtr,
	 buVendor,
	 CustomerName,
	 CostName,
	 biLength,
	 biWidth,
	 biHeight,
	 biCount,
	 biExpireDate,
	 biProductionDate,
	 BiClassptr,
	 BranchName,
	 DataBaseName,
	 UserSecurity,
	 Security
INTO #FinalResult
FROM #FirstResult
ORDER BY
		[buDate]  ASC,
		[buNumber]  ASC,
		[btIsInput]  DESC
		

SELECT * FROM #FinalResult
ORDER BY
	[buDate]  ASC,
	[btIsInput]  DESC,
	[buFormatedNumber]  ASC
####################################################################
CREATE PROCEDURE prcGetAvgPrevPriceOneMaterial
-- Params -------------------------------   
	@MaterialGUID		UNIQUEIDENTIFIER,
	@CurrencyGUID		UNIQUEIDENTIFIER,
	@StartDate			DATETIME
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
CREATE TABLE [#MatTbl](MatGUID UNIQUEIDENTIFIER, mtSecurity INT)
CREATE TABLE [#StoreTbl]([StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT])

DECLARE @CurrencyVal  FLOAT = 0
DECLARE @AvgPrevPrice FLOAT = 0
DECLARE @D DATETIME = @StartDate - 1
	INSERT INTO [#StoreTbl]	SELECT [Guid] , [Security] FROM st000
	INSERT INTO [#MatTbl]  SELECT [GUID], [Security] FROM mt000 WHERE ([GUID] = @MaterialGUID OR [Parent] = @MaterialGUID)
	SELECT @CurrencyVal = CurrencyVal FROM my000 WHERE [GUID] = @CurrencyGUID
	EXEC [prcGetAvgPrice] '1/1/1980', @D, @MaterialGUID, 0X00, 0X00, 0X00, -1, @CurrencyGUID, @CurrencyVal, 0x0, 0, 0
DROP TABLE [#MatTbl]
DROP TABLE [#StoreTbl]
####################################################################
CREATE PROCEDURE prcCheckMaterialHasDifferencesNames
	@Material	 UNIQUEIDENTIFIER,
	@StartDate	 DATETIME,
	@EndDate	 DATETIME 
AS 
BEGIN
	SET NOCOUNT ON;
-------------------------------------------------------------
	CREATE TABLE #Result
	(
		DatabaseName	NVARCHAR(256) COLLATE ARABIC_CI_AI,
		FirstPeriodDate DATE,
		EndPeriodDate	DATE,
		MaterialName	NVARCHAR(256) COLLATE ARABIC_CI_AI,
		MaterialCode	NVARCHAR(256) COLLATE ARABIC_CI_AI
	)

	DECLARE @currentDbName			NVARCHAR(128)
	DECLARE @currentFirstPeriodDate DATE
	DECLARE @currentEndPeriodDate	DATE

	DECLARE @MatName				NVARCHAR(256)
	DECLARE @MatCode				NVARCHAR(256)

	DECLARE @Query					NVARCHAR(300)
	DECLARE @ParmDefinition			NVARCHAR(300)

	DECLARE  @HasDifferentName		INT
	DECLARE  @HasDifferentCode		INT
	DECLARE  @ISDataBaseNotExist	INT
	
	DECLARE @NotExistDataBaseName		NVARCHAR(300)

	SET @ParmDefinition = N'@NameOut NVARCHAR(256) OUTPUT, @CodeOut NVARCHAR(256) OUTPUT'

	DECLARE AllDatabases			CURSOR FOR		 
	SELECT [DatabaseName], [FirstPeriod], [EndPeriod] FROM FnGetReportDataSources(@StartDate, @EndDate)
	OPEN AllDatabases;	    
	
	FETCH NEXT FROM AllDatabases INTO @currentDbName, @currentFirstPeriodDate, @currentEndPeriodDate;
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		
	   SET @MatName = ''; SET @MatCode = '';
	   SET @Query = 'SELECT @NameOut = Name, @CodeOut = Code FROM ['+ @currentDbName +'].[dbo].[mt000] WHERE GUID = '''+ CONVERT(NVARCHAR(38), @Material) +'''';
	   EXEC sp_executesql @Query, @ParmDefinition, @NameOut = @MatName OUTPUT, @CodeOut = @MatCode OUTPUT;
	   INSERT INTO #Result
	   VALUES(@currentDbName, @currentFirstPeriodDate, @currentEndPeriodDate, @MatName, @MatCode)
	   
	   
	   FETCH NEXT FROM AllDatabases INTO @currentDbName, @currentFirstPeriodDate, @currentEndPeriodDate;
	END;

	CLOSE AllDatabases;
	DEALLOCATE AllDatabases;

	DELETE #Result WHERE MaterialName = ''

	SELECT DISTINCT MaterialName 
	INTO #NameCount
	FROM #Result

	SELECT DISTINCT MaterialCode
	INTO #CodeCount
	FROM #Result

	IF(SELECT COUNT(MaterialName) FROM #NameCount) > 1
	BEGIN
		SET @HasDifferentName = 1
	END
	ELSE
	BEGIN
		SET @HasDifferentName = 0
	END

	IF(SELECT COUNT(MaterialCode) FROM #CodeCount) > 1
	BEGIN
		SET @HasDifferentCode = 1
	END
	ELSE
	BEGIN
		SET @HasDifferentCode = 0
	END


	DECLARE @MatNameInCurrentYear NVARCHAR(128) = (SELECT name FROM mt000 WHERE [GUID] = @Material)
	DECLARE @MatCodeInCurrentYear NVARCHAR(128) = (SELECT code FROM mt000 WHERE [GUID] = @Material)

	IF(SELECT COUNT(*) FROM #NameCount) = 1
	BEGIN
		IF(@MatNameInCurrentYear != (SELECT MaterialName FROM #NameCount))
		BEGIN
			SET @HasDifferentName = 1
		END
	END

	IF(SELECT COUNT(*) FROM #CodeCount) = 1
	BEGIN
		IF(@MatCodeInCurrentYear != (SELECT MaterialCode FROM #CodeCount))
		BEGIN
			SET @HasDifferentCode = 1
		END
	END
	/*
	IF(SELECT COUNT(*) FROM ReportDataSources000 RDS WHERE RDS.DatabaseName NOT IN( select DatabaseName from #Result)) =1
	BEGIN
		set @ISDataBaseNotExist = 1
	END
	ELSE
	BEGIN
		set @ISDataBaseNotExist = 0
	END

	SELECT top(1) @NotExistDataBaseName = RDS.DatabaseName FROM ReportDataSources000 RDS WHERE RDS.DatabaseName NOT IN( SELECT DatabaseName FROM #Result)
	DELETE RDS FROM ReportDataSources000 RDS WHERE RDS.DatabaseName NOT IN( SELECT DatabaseName FROM #Result)
	*/
	SELECT @HasDifferentName AS HasDifferentName, @HasDifferentCode AS HasDifferentCode  , @ISDataBaseNotExist AS IsDataBaseNotExist, @NotExistDataBaseName AS NotExistDataBaseName 
END
####################################################################
CREATE PROCEDURE prcCalcAvgPrevBalanceWithCurrency
-- Params -------------------------------   
	@DataBaseName		 NVARCHAR(128),
	@AvgPrevBalance		 FLOAT,
	@OldCurrencyGuid	 UNIQUEIDENTIFIER,
	@StartDate			 DATETIME,
	@EndDate			 DATETIME
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------

 DECLARE @GetDefaultCurrency				 NVARCHAR(MAX)
 DECLARE @GetOldCurrencyVal					 NVARCHAR(MAX)
 DECLARE @GetAvgPrevBalanceWithCurr			 NVARCHAR(MAX)
 DECLARE @DefaultCurrencyGuid				 UNIQUEIDENTIFIER				
 DECLARE @OldCurrencyVal					 FLOAT
 DECLARE @FirstDataBaseName					 NVARCHAR(128)
 DECLARE @AvgPrevBalanceWithoutCurr			 FLOAT


  ------------- Get default currency guid in current database
 	 SET @GetDefaultCurrency = ' SELECT @CurrOut = value FROM  [' + @DataBaseName + '].[dbo].[op000] WHERE Name = ''AmnCfg_DefaultCurrency'' '
	 EXEC sp_executesql @GetDefaultCurrency, N' @CurrOut UNIQUEIDENTIFIER OUTPUT', @CurrOut = @DefaultCurrencyGuid OUTPUT;

 IF(@DefaultCurrencyGuid != @OldCurrencyGuid)
 BEGIN

	 ------------- Get first database name 
		 SET @FirstDataBaseName	= (SELECT TOP 1 [DatabaseName] FROM FnGetReportDataSources(@StartDate, @EndDate) ORDER BY [FirstPeriod])


	 ------------- Get currency Value from first database
  		 SET @GetOldCurrencyVal = 'SELECT TOP 1 @CurrVal = [CurrencyVal] FROM  [' + @FirstDataBaseName + '].[dbo].[mh000] WHERE [CurrencyGUID] = ''' + CONVERT(NVARCHAR(38),@OldCurrencyGuid) + '''  ORDER BY [Date] DESC'
		 EXEC sp_executesql @GetOldCurrencyVal, N' @CurrVal FLOAT OUTPUT', @CurrVal = @OldCurrencyVal OUTPUT;


	 ------------- Return AvgPrevBalance to default currency
		 SET @AvgPrevBalanceWithoutCurr = @AvgPrevBalance * @OldCurrencyVal


	 ------------- Calculate AvgPrevBalance with required currency
		 DECLARE @AvgPrevBalanceWithCurr FLOAT
		 DECLARE @GetCurrentDataFirstPeriodDate NVARCHAR(300)
		 DECLARE @CurrentDataFirstPeriodDate DATETIME

 		 SET @GetCurrentDataFirstPeriodDate = ' SELECT @DateOut = CAST(value AS DATETIME) FROM  [' + @DataBaseName + '].[dbo].[op000] WHERE Name = ''AmnCfg_FPDate'' '
		 EXEC sp_executesql @GetCurrentDataFirstPeriodDate, N' @DateOut DATETIME OUTPUT', @DateOut = @CurrentDataFirstPeriodDate OUTPUT;

		 SET @GetAvgPrevBalanceWithCurr = 'SELECT @FLOATOut = ([' + @DataBaseName + '].[dbo].[fnCurrency_fix]('+CONVERT(NVARCHAR(250), @AvgPrevBalanceWithoutCurr)+', ''' + CONVERT(NVARCHAR(38),@DefaultCurrencyGuid) + ''', 1, ''' + CONVERT(NVARCHAR(38),@OldCurrencyGuid) + ''', ''' + CONVERT(NVARCHAR(38),@CurrentDataFirstPeriodDate) + '''))'
		 EXEC sp_executesql @GetAvgPrevBalanceWithCurr, N' @FLOATOut FLOAT OUTPUT', @FLOATOut = @AvgPrevBalanceWithCurr OUTPUT;


		 SELECT @AvgPrevBalanceWithCurr AS AvgPrevBalance

 END

 ELSE BEGIN
	SELECT @AvgPrevBalance AS AvgPrevBalance
 END
####################################################################
#END