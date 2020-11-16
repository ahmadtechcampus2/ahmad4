####################################################
CREATE PROCEDURE repOrderPaymentMove
@CustGuid		[uniqueidentifier],
@AccountGuid	[uniqueidentifier],
@CostGuid		[uniqueidentifier],
@StoreGuid		[uniqueidentifier],
@CurrencyGuid	[uniqueidentifier],
@StartDate			[Date],
@EndDate			[Date],
@OrderTypesSrc	[UNIQUEIDENTIFIER],
@OrderCond      [UNIQUEIDENTIFIER] = 0x0, 
@IsPaid				[INT],
@IsPartialPaid		[INT],
@IsUnPaid			[INT],
@IsRecieved			[INT],
@IsPartialRecieved	[INT],
@IsNotRecieved		[INT],
@GroupByCustomer	[INT]
AS
SET NOCOUNT ON
DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
CREATE TABLE #BillsTypesTbl (  
              TypeGuid    UNIQUEIDENTIFIER,  
              Sec         INT,                
              ReadPrice   INT,                
              UnPostedSec INT)                
       INSERT INTO #BillsTypesTbl EXEC prcGetBillsTypesList2 @OrderTypesSrc 
       CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])
	  
	------------------------------------------------------------------- 
	-------------------------   #OrdersTbl   -------------------------- 
	CREATE TABLE #OrdersTbl ( 
		OrderGuid UNIQUEIDENTIFIER, 
		[Security]  INT) 
	INSERT INTO #OrdersTbl (OrderGuid, Security) EXEC prcGetOrdersList @OrderCond 
	------------------------------------------------------------------- 
	DECLARE @StoreTbl TABLE(StoreGuid UNIQUEIDENTIFIER) 
	INSERT INTO @StoreTbl SELECT Guid FROM fnGetStoresList(@StoreGuid) 
	------------------------------------------------------------------- 
	------------------------------------------------------------------- 
	DECLARE @CostTbl TABLE (CostGuid UNIQUEIDENTIFIER) 
	INSERT INTO @CostTbl SELECT Guid FROM fnGetCostsList(@CostGuid) 
	IF ISNULL(@CostGuid, 0x0) = 0x0 
		INSERT INTO @CostTbl VALUES(0x0) 
	------------------------------------------------------------------------- 
	--------------------------#CustTbl---------------------------------
	CREATE TABLE [#CustTbl]( [CustGUID] [UNIQUEIDENTIFIER], [Security] [INT] , [CustName] NVARCHAR(1000) COLLATE Arabic_CI_AI)
	INSERT INTO [#CustTbl] ([CustGUID], [Security])		EXEC [prcGetCustsList] 		@CustGUID, @AccountGUID ,0x00
	IF (@CustGUID = 0X00) AND (@AccountGUID = 0X00)
		INSERT INTO [#CustTbl] VALUES(0X00,0,NULL)
	
	UPDATE c
	SET [CustName] = (SELECT CustomerName FROM cu000 WHERE [Guid] = c.CustGuid )
	From  [#CustTbl] c

	IF @Lang <> 0
	BEGIN
		UPDATE C
		SET C.CustName = (CASE cu.LatinName WHEN N'' THEN C.CustName ELSE cu.LatinName END)
		FROM 
			#CustTbl AS C
			INNER JOIN cu000 AS CU ON C.CustGUID = CU.GUID
	END
	------------------------------------------------------------------------------
CREATE TABLE [#Result]
( 
[buGUID]			[UNIQUEIDENTIFIER] DEFAULT 0x0,
[typeGUID]			[UNIQUEIDENTIFIER] DEFAULT 0x0,
[Security]			[INT],
[UserSecurity]		[INT],
[Name]				NVARCHAR(1000) COLLATE Arabic_CI_AI,
[CustomerName]		NVARCHAR(1000) COLLATE Arabic_CI_AI,
[CustomerGuid]		[UNIQUEIDENTIFIER],
[CustomerBalance]	[FLOAT],
[FinishedState]		[INT],
[PaymentState]		[INT],
[Date]				[DATETIME],
[PaidValue]			[FLOAT],  --ãÓÏÏ
[TotalValue]		[FLOAT], --ÐãÉ
[RemainingValue]	[INT],	--ÈÇÞí
[BillValue]			[FLOAT], -- ÞíãÉ ÇáÝæÇÊíÑ
[UnPaidBillValue]	[FLOAT], -- ÞíãÉ ÇáÝæÇÊíÑ ÛíÑ ÇáãÓÏÏÉ
[CurrencyVal]		[FLOAT],
[IsOrder]			[BIT] ,
[RefOrderGuid]		[UNIQUEIDENTIFIER] DEFAULT 0x0,
[BillDate]			[DATETIME] ,
[ceGUID]			[UNIQUEIDENTIFIER],
[BillTotalValue]	[FLOAT]
)
INSERT INTO #Result
(
		[buGUID] ,
		[RefOrderGuid],
		[typeGUID],
		[Security],
		[UserSecurity],
		[Name],
		[CustomerGuid],
		[CustomerName],
		[FinishedState], -- 2 finished , 1  partialfinished , 0 notfinished
		[PaymentState],	--2 paid , 1 partialpaid, 0 unpaid
		[Date],
		[CurrencyVal],
		[IsOrder],
		[BillDate],
		[ceGUID],
		[BillTotalValue]
)
SELECT
		bu.[buGuid],
		bu.[buGuid],
		bt.TypeGuid,
		ISNULL(bu.buSecurity, 0),
		CASE bu.buIsPosted WHEN 1 THEN bt.Sec ELSE bt.UnPostedSec END,
		(CASE @Lang WHEN 0 THEN bu.btName ELSE (CASE bu.btLatinName WHEN N'' THEN bu.btName ELSE bu.btLatinName END) END ) + ' - ' + CONVERT(NVARCHAR(11), bu.buNumber),
		cu.CustGUID,
		cu.CustName,
		dbo.fnGetFinishedState(bu.[buGuid]),
		dbo.fnGetPaymentState(bu.[buGuid]),
		bu.[buDate],
		bu.buCurrencyVal,
		1,
		bu.[buDate]
		,0x0,
		0
FROM
		vwbu bu
		INNER JOIN [ORADDINFO000] OInfo ON bu.buGuid = OInfo.ParentGuid
		INNER JOIN [#BillsTypesTbl] bt on bt.TypeGuid = bu.[buType]
		INNER JOIN [#OrdersTbl] otbl ON bu.[buGuid] = otbl.[OrderGuid]
		INNER JOIN @StoreTbl store ON store.StoreGuid = bu.buStorePtr
		INNER JOIN @CostTbl cost ON cost.CostGuid = bu.buCostPtr
		INNER JOIN [#CustTbl] AS [cu] ON [cu].[CustGUID] = bu.buCustPtr
WHERE
		(bu.buPayType = 1 )--Deferred
		 AND  bu.[buDate] BETWEEN @StartDate AND @EndDate
		 AND (bu.[buCurrencyPtr] = @CurrencyGuid OR  @CurrencyGuid = 0x00)
		 AND [OInfo].[Add1] = 0   --not canceled orders
	EXEC [prcCheckSecurity]
		IF(@IsPaid = 0)
		DELETE FROM #Result WHERE [PaymentState] = 2
		IF(@IsPartialPaid = 0)
		DELETE FROM #Result WHERE [PaymentState] = 1
		IF(@IsUnPaid = 0)
		DELETE FROM #Result WHERE [PaymentState] = 0
		IF(@IsRecieved = 0)
		DELETE FROM #Result WHERE [FinishedState] = 2
		IF(@IsPartialRecieved = 0)
		DELETE FROM #Result WHERE [FinishedState] = 1
		IF(@IsNotRecieved = 0)
		DELETE FROM #Result WHERE [FinishedState] = 0
--ÍÓÇÈ ÇáãÓÏÏ æ ÇáÈÇÞí æ ÇáÐãÉ	
--ãÓÏÏ	
UPDATE  R
SET
		[PaidValue] =	Res.[PaidValue]  
FROM
	(
	SELECT 
			SUM(ISNULL(bp.Val, 0))  PaidValue,
			CASE @GroupByCustomer WHEN 1 THEN CustomerGuid ELSE bu.buGUID END AS ResGuid
	FROM
	     bp000  bp
		 INNER JOIN vworderpayments  PAY ON PAY.PaymentGuid = bp.DebtGUID 
		 INNER JOIN vwBu  BU ON BU.buGUID = PAY.BillGuid
		 INNER JOIN #Result R ON R.BuGuid = PAY.BillGuid
	GROUP BY
		CASE @GroupByCustomer WHEN 1 THEN CustomerGuid ELSE bu.buGUID END
		) Res
	INNER JOIN #Result R ON (R.CustomerGuid = Res.ResGuid AND @GroupByCustomer = 1) OR (R.buGuid = Res.ResGuid)	
	UPDATE #Result
	SET [PaidValue] = 0 
	WHERE [PaidValue] IS NULL
--  ÐãÉ 
UPDATE  R
SET
		[TotalValue]	= Res.[TotalValue] 	 
FROM
	(
	SELECT 
			ISNULL(SUM(Pay.[UpdatedValueWithCurrency]),0)  TotalValue,
			CASE @GroupByCustomer WHEN 1 THEN CustomerGuid ELSE bu.buGUID END  AS  [ResGuid]
	FROM
		 vworderpayments  PAY
		 INNER JOIN vwBu  BU ON BU.buGUID = PAY.BillGuid
		 INNER JOIN #Result R ON R.BuGuid = PAY.BillGuid
	GROUP BY
		CASE @GroupByCustomer WHEN 1 THEN CustomerGuid ELSE bu.buGUID END
		) Res
	INNER JOIN #Result R ON (R.CustomerGuid = Res.ResGuid AND @GroupByCustomer = 1) OR (R.buGuid = Res.ResGuid)
	
--ÈÇÞí
UPDATE #Result
SET [RemainingValue] = [TotalValue] - [PaidValue]
			
--ÍÓÇÈ ÞíãÉ ÝæÇÊíÑ ÇáØáÈ
	
	UPDATE  R
	SET 
			BillValue = ISNULL(Res.BillTotal,0)
	FROM 
		(SELECT
		
					 R.oriPOGUID  AS  [ResGuid],
					SUM(R.biQty *(R.biUnitPrice + R.biUnitExtra - R.biUnitDiscount) + R.biVAT) AS BillTotal
		FROM (
				SELECT 
						DISTINCT 
								bi.*,
								ori.oriPOGUID  [oriPOGUID],
								ori.oriPOGUID   [ResGuid]
				FROM	vwORI ori 
						INNER JOIN vwExtended_bi bi ON bi.buGUID = ori.oriBuGUID
						LEFT JOIN oit000 oit ON ori.oriTypeGuid = oit.[Guid]
						LEFT JOIN #Result R1 ON bi.buGuid = R1.BuGuid
				WHERE
						oit.QtyStageCompleted = 1 AND ori.oriQty > 0 AND ori.oriType = 0
				)R
		
		GROUP BY
					 R.oriPOGUID
					
		)Res
		INNER JOIN #Result R ON Res.ResGuid = R.BuGuid
		
UPDATE #Result
SET BillValue = 0 
WHERE BillValue IS NULL 
---------------------------------------------------------------
 --ÞíãÉ ÇáÝæÇÊíÑ ÛíÑ ÇáãÓÏÏÉ
	Update  #Result 
	SET 
			UnPaidBillValue =  (BillValue - PaidValue )
	WHERE 
			BillValue > PaidValue 
---------------------------------------------------------------
--ÅÙåÇÑ ÑÕíÏ ÇáÒÈæä
	Update R
	SET
			[CustomerBalance] = Res.Balance
	FROM
		(
		SELECT 
				cu.CustomerName  CustomerName,
				ac.debit - ac.credit  Balance
		FROM 
				cu000 cu
				INNER JOIN ac000 ac ON cu.accountguid = ac.[guid]
		)Res
		INNER JOIN #Result R ON R.CustomerName = Res.CustomerName 
---------------------------------------------------------------

IF (@GroupByCustomer  = 0)
BEGIN 
	INSERT INTO #Result 
	(
	[RefOrderGuid],
	[PaidValue],
	[CurrencyVal],
	[Name],
	[Date],
	[IsOrder],
	[BillDate],
	[ceGUID]
	)
	SELECT
		DISTINCT
		bi.buGuid, -- ParentGuid,
		bp.Val,
		bi.buCurrencyval,
		ISNULL(((CASE @Lang WHEN 0 THEN et.Abbrev ELSE (CASE et.LatinAbbrev WHEN N'' THEN et.Abbrev ELSE et.LatinAbbrev END) END )+ ': ' + CAST(py.Number AS NVARCHAR)),
		bi.btAbbrev+ ': ' + CAST(bi.buNumber AS NVARCHAR)),
		ISNULL(en.[Date], bi.buDate),
		0,
		bi.buDate,
		ce.[GUID]
	FROM 
		bp000 bp
		INNER JOIN  vwOrderPayments OrderPayments ON (bp.DebtGUID = OrderPayments.PaymentGuid)
		INNER JOIN #result r on r.buguid = OrderPayments.BillGuid
		INNER JOIN en000 en ON bp.PayGUID = en.[Guid]
		INNER JOIN ce000 ce ON en.ParentGUID = ce.[GUID]
		INNER JOIN er000 er ON er.EntryGUID = ce.[GUID]
		INNER JOIN py000 py ON py.[GUID] = er.ParentGUID
		INNER JOIN et000 et ON et.[Guid] = ce.TypeGUID
		INNER JOIN vwExtended_bi bi ON bi.buGuid = OrderPayments.BillGuid
END 

IF(@GroupByCustomer = 1)
BEGIN 
	UPDATE 
		R 
	SET
		[buGUID]=0x0,
		[typeGUID]=0x0,
		[Name]	=NULL,
		[RefOrderGuid] = 0x0,
		[Security]	= 0,
		[UserSecurity]=0,
		[FinishedState]	=0,
		[PaymentState]=0,
		[Date]	=NULL,
		[CurrencyVal]=1,
		[IsOrder]=0 ,
		[BillDate] =NULL,
		[UnPaidBillValue] =R1.TotalUnPaidVal,
		[BillValue] = R1.TotalBillVal
		FROM
		(SELECT SUM(BillValue) AS TotalBillVal, SUM(UnPaidBillValue) AS TotalUnPaidVal, [CustomerGuid] FROM #Result GROUP BY [CustomerGuid])R1
		INNER JOIN  #Result R on R.[CustomerGuid] = r1.[CustomerGuid]
	
END

--******************************************************************** 
UPDATE 
Res
SET [BillTotalValue] = buTotal
FROM [#Result] AS Res
INNER JOIN
(
	SELECT
	orderGuid,
	Sum(( bi.BiQty * ( bi.BiPrice + BiExtra - BiDiscount ) ) + ( BiVat ) - ( biBonusDisc )) AS buTotal
	FROM   (
				SELECT 
				ori.oriPOGUID             AS orderGuid,
				bi.biQty                  AS BiQty,
				ISNULL(bi.biUnitPrice, 0) AS BiPrice,
				ISNULL(bi.biUnitExtra, 0) AS BiExtra,
				ISNULL(biUnitDiscount, 0) AS BiDiscount,
				ISNULL(bi.biBonusDisc, 0) AS biBonusDisc,
				ISNULL(bi.biVAT, 0)       AS BiVat
			FROM   vwExtended_bi bi
					INNER JOIN vwORI ori ON bi.biGUID = ori.oriBiGUID
					INNER JOIN oit000 oit ON ori.oriTypeGuid = oit.[Guid]
			WHERE  oit.QtyStageCompleted = 1
					AND ori.oriQty > 0
					AND ori.oriType = 0
			) bi
	GROUP  BY bi.orderGuid
) AS TotalRes ON TotalRes.orderGuid = Res.buGUID

--********************************************************************

--Sort Options
DECLARE @SelectStr AS NVARCHAR(MAX)

SET @SelectStr = 'SELECT DISTINCT *, ISNULL(BillTotalValue, 0) AS BillTotalVal, ISNULL(BillTotalValue, 0) - ISNULL(PaidValue, 0) AS UnPaidBill
				  FROM #Result R '
			   +' ORDER BY   Date , Name Asc'

IF(@GroupByCustomer  = 0)
	SET @selectStr = 'SELECT *, ISNULL(BillTotalValue, 0) AS BillTotalVal, ISNULL(BillTotalValue, 0) - ISNULL(PaidValue, 0) AS UnPaidBill
					  FROM #Result 
					  WHERE IsOrder = 1 
					  ORDER BY BillDate, RefOrderGuid '
EXEC (@SelectStr)


SELECT [Date], [Name], [PaidValue] , [RefOrderGuid], ceGUID
FROM #Result 
WHERE IsOrder = 0 
ORDER BY BillDate, RefOrderGuid
####################################################
#END