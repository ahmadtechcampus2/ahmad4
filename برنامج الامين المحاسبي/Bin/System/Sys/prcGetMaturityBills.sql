###########################################################################
CREATE PROCEDURE prcGetMaturityBills
AS
BEGIN
	SET NOCOUNT ON
	CREATE TABLE #BillsTypesTbl (  
		TypeGuid        UNIQUEIDENTIFIER,  
		Sec         INT,                
		ReadPrice   INT,                
		UnPostedSec INT)                
	INSERT INTO #BillsTypesTbl EXEC prcGetBillsTypesList2 0x0 
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])
	
	CREATE TABLE [#Result]( 
		[buGUID] UNIQUEIDENTIFIER,
		[typeGUID] UNIQUEIDENTIFIER,
		[Security] INT,
		[UserSecurity] INT,
		[buName] NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[CustomerName] NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[DueDate] DATETIME,
		[PaidValue] FLOAT,
		[TotalValue] FLOAT,
		[DaysDif] INT,
		[IsTransfered] BIT
	)
	DECLARE @CurrentDate DATETIME = GETDATE();
	
	INSERT INTO #Result
	SELECT
		bu.buGUID,
		bt.TypeGuid,
		ISNULL(bu.buSecurity, 0),
		CASE bu.buIsPosted WHEN 1 THEN bt.Sec ELSE bt.UnPostedSec END,
		bu.btName + ' - ' + CONVERT(NVARCHAR(11), bu.buNumber),
		cu.CustomerName,
		ISNULL(pt.DueDate, @CurrentDate),
		ISNULL(bp.SumBbVal,0) ,
		buTotal + buVat - buTotalDisc + buTotalExtra, 
		DATEDIFF ( day , @CurrentDate, ISNULL(pt.DueDate, @CurrentDate)),
		0
	FROM
	    vwbu bu 
		OUTER APPLY (SELECT SUM(Val) AS SumBbVal FROM bp000 bp WHERE DebtGUID = bu.buGUID OR PayGUID = bu.buGUID) bp
		LEFT JOIN cu000 cu on cu.GUID = bu.buCustPtr
		INNER JOIN MaturityBills000 mb on mb.BillTypeGuid = bu.buType
		INNER JOIN #BillsTypesTbl bt on bt.TypeGuid = bu.buType
		LEFT JOIN pt000 pt on pt.RefGUID = bu.buGUID
	WHERE 
	    DATEDIFF ( day , @CurrentDate, ISNULL(pt.DueDate, @CurrentDate)) <= mb.DaysCount 
		AND bu.buPayType = 1 AND mb.Type IN (1,2,3,4) AND mb.IsChecked = 1 
		AND ISNULL(bp.SumBbVal,0) < (buTotal + buVat - buTotalDisc + buTotalExtra)
	UNION ALL 
	SELECT
		0x0,
		bt.TypeGuid,
		ISNULL(ce.ceSecurity, 0),
		CASE ce.ceIsPosted WHEN 1 THEN bt.Sec ELSE bt.UnPostedSec END,
		btt.Name + ' - ' + CONVERT(NVARCHAR(11), CAST(TransferedInfo AS XML).value('/Number[1]','INT')),
		cu.CustomerName,
		ISNULL(pt.DueDate, @CurrentDate),
		CAST(TransferedInfo AS XML).value('/Total[1]','FLOAT') - 
				( CASE pt.[Debit] WHEN 0 THEN pt.[Credit] ELSE pt.[Debit] END ) + ISNULL(bp.Val,0),
		CAST(TransferedInfo AS XML).value('/Total[1]','FLOAT'), 
		DATEDIFF ( day , @CurrentDate, ISNULL(pt.DueDate, @CurrentDate)),
		1
	FROM
	    pt000 pt 
		INNER JOIN vwCeEN ce ON ce.ceGUID = pt.refGUID AND ce.enAccount = CustAcc
		LEFT JOIN cu000 cu on cu.GUID = ce.enCustomerGUID
		INNER JOIN MaturityBills000 mb on mb.BillTypeGuid = pt.TypeGuid
		INNER JOIN #BillsTypesTbl bt on bt.TypeGuid = pt.TypeGuid
		INNER JOIN bt000 btt ON btt.GUID =  pt.TypeGuid
		LEFT JOIN (
				SELECT  DebtGUID ,  SUM(Val) AS Val FROM 
					(
						SELECT DebtGUID , Val FROM bp000 bp 
						UNION ALL 
						SELECT PayGUID , Val  FROM bp000 bp 
					) t
					GROUP BY DebtGUID
				) bp ON bp.DebtGUID = enGUID
	WHERE 
	    DATEDIFF ( day , @CurrentDate, ISNULL(pt.DueDate, @CurrentDate)) <= mb.DaysCount 
		 AND mb.Type IN (1,2,3,4) AND mb.IsChecked = 1 AND IsTransfered = 1 
		AND ISNULL(bp.Val,0) < CAST(TransferedInfo AS XML).value('/Total[1]','FLOAT')

		EXEC [prcCheckSecurity] 
		SELECT * FROM #Result ORDER BY DueDate ASC
END
###########################################################################
CREATE PROCEDURE prcGetMaturityOrders
AS
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #OrderTypesTbl (  
		TypeGuid        UNIQUEIDENTIFIER,  
		Sec         INT,                
		ReadPrice   INT,                
		UnPostedSec INT)                
	INSERT INTO #OrderTypesTbl EXEC prcGetBillsTypesList2 0x0 

	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])
	
	CREATE TABLE [#Result]( 
	    [TypeGUID] UNIQUEIDENTIFIER,
		[buGUID] UNIQUEIDENTIFIER,
		[Security] INT,
		[UserSecurity] INT,
		[buName] NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[CustomerName] NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[DueDate] DATETIME,
		[PaidValue] FLOAT,
		[TotalValue] FLOAT,
		[DaysDif] INT,
		[PaymentNumber] INT,
		[PaymentCount] INT
	)

	CREATE TABLE [#Payments](
	   [PayGUID] UNIQUEIDENTIFIER,
	   [PaidValue] FLOAT
	   )

	DECLARE @CurrentDate DATETIME = GETDATE();

	INSERT INTO
		#Payments
	SELECT 
		bp.DebtGUID AS PayGUID,
		SUM(bp.Val) AS PaidValue
	FROM
		 bp000 AS bp
	GROUP BY
		 bp.DebtGUID

	INSERT INTO 
		#Result
	SELECT 
	    bt.TypeGuid,
		PAY.[BillGuid] AS [buGUID],
		ISNULL(bu.buSecurity, 0),
		bt.UnPostedSec,
		bu.[btName] + ' - ' + CAST(bu.buNumber AS NVARCHAR(36)) AS [buName],
		cu.CustomerName AS CustomerName, 
		PAY.[PaymentDate] AS [DueDate],
		ISNULL(P.PaidValue, 0) AS [PaidValue],
		Pay.[UpdatedValueWithCurrency]  AS [TotalValue], 
		DATEDIFF ( day , @CurrentDate, ISNULL(PAY.[PaymentDate], @CurrentDate)) AS [DaysDif],
		PAY.PaymentNumber AS PaymentNumber,
		(select COUNT(*) from vworderpayments where BillGuid = PAY.[BillGuid]) AS [PaymentCount] 
	FROM 
		vworderpayments AS PAY
		LEFT JOIN vwBu AS BU ON BU.buGUID = PAY.BillGuid
		LEFT JOIN cu000 cu on cu.GUID = BU.buCustPtr
		LEFT JOIN #Payments P ON P.PayGUID = PAY.PaymentGuid
		INNER JOIN MaturityBills000 AS MB ON MB.BillTypeGuid = BU.buType
		INNER JOIN #OrderTypesTbl bt on bt.TypeGuid = BU.buType
		INNER JOIN ORADDINFO000 OInfo ON BU.buGUID = OInfo.ParentGuid	
	WHERE
	   MB.IsChecked = 1 AND DATEDIFF (day ,@CurrentDate, ISNULL(PAY.[PaymentDate], @CurrentDate)) <= MB.DaysCount
	   AND MB.Type IN (5, 6) AND (Pay.[UpdatedValueWithCurrency] - ISNULL(P.PaidValue, 0)) > 0
	   AND OInfo.Add1 ='0' AND OInfo.Add2 <> '2'

	   EXEC [prcCheckSecurity] 
	   SELECT * FROM #Result ORDER BY DueDate ASC
END
###########################################################################
#END