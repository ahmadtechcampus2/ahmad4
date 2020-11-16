#########################################################
CREATE PROCEDURE prcCustomer_GetWindowInfo
	@CustomerGUID			[UNIQUEIDENTIFIER]
AS 
SET NOCOUNT ON
DECLARE
	@lastDebit			[FLOAT],    
	@lastCredit			[FLOAT],
	@lastDebitDate		[DATETIME],    
	@lastCreditDate		[DATETIME],
	@CurrencyGUID		[UNIQUEIDENTIFIER],
	@SumUnPayedBills	[FLOAT],
	@CurrencyVal		[FLOAT]
	

	SELECT TOP 1 
		@lastCredit = ISNULL(en.[Credit], 0),
		@lastCreditDate = ISNULL(en.Date, '1/1/1980')
	FROM 
		en000 en 
		inner join cu000 cu on en.CustomerGUID = cu.GUID 
		inner join ac000 ac on cu.AccountGUID = ac.GUID AND en.AccountGUID = ac.GUID
		inner join ce000 ce on en.ParentGUID = ce .GUID
	WHERE  customerguid = @CustomerGUID AND en.[Credit] > 0 
	ORDER BY en.[Date] DESC , ce.Number DESC

	SELECT TOP 1 
		@lastDebit = ISNULL(en.[Debit], 0),
		@lastDebitDate = ISNULL(en.Date, '1/1/1980')
	FROM 
		en000 en 
		inner join cu000 cu on en.CustomerGUID = cu.GUID 
		inner join ac000 ac on cu.AccountGUID = ac.GUID  AND en.AccountGUID = ac.GUID
		inner join ce000 ce on en.ParentGUID = ce .GUID
	WHERE  customerguid = @CustomerGUID AND en.[Debit] > 0 
	ORDER BY en.[Date] DESC, ce.Number DESC

	SET @CurrencyGUID = ISNULL((SELECT CurrencyGUID
									FROM ac000 ac
									INNER JOIN cu000 cu on cu.AccountGUID = ac.GUID
									WHERE  cu.GUID = @CustomerGUID),0x0)
	
	SET  @CurrencyVal = ISNULL((SELECT TOP 1 CurrencyVal FROM mh000 WHERE CurrencyGUID = @CurrencyGUID ORDER BY [Date] DESC) ,0 )	

	IF @CurrencyVal = 0
		SET @CurrencyVal = ISNULL((SELECT TOP 1 CurrencyVal FROM my000 WHERE GUID = @CurrencyGUID), 1);

	SET @lastCredit = @lastCredit/@CurrencyVal
	SET @lastDebit = @lastDebit/@CurrencyVal

	SET @SumUnPayedBills = 0 

	IF EXISTS (SELECT [Value] FROM op000 WHERE [Name] = 'AmncfStopCustomer' AND Value = '1')
	BEGIN
			;WITH TOTAL AS 
			( 
					SELECT 
						(bu.Total + bu.TotalExtra - bu.TotalDisc  + (CASE bt.VatSystem WHEN 2 THEN 0 ELSE bu.Vat END) - ISNULL(bp.Val,0) - ISNULL(pp.Val,0)) AS amount
					FROM
						bu000 bu
						INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
						INNER JOIN pt000 pt ON pt.RefGUID = bu.[Guid]
						LEFT JOIN er000 er ON er.ParentGUID = bu.[GUID]
						INNER JOIN ce000 ce ON ce.[Guid] = entryGuid
						INNER JOIN en000 en ON en.parentguid = ce.GUID
						LEFT JOIN (SELECT SUM(Val) AS Val, DebtGUID FROM bp000 GROUP BY DebtGUID) bp ON bp.DebtGUID = bu.GUID
						LEFT JOIN (SELECT SUM(Val) AS Val, PayGUID FROM bp000 GROUP BY payGUID) pp ON pp.PayGUID = bu.GUID
						INNER JOIN cu000 cu ON cu.GUID = en.CustomerGUID
						INNER JOIN ac000 ac ON ac.GUID = cu.AccountGUID
					WHERE 
						bt.bIsOutput > 0 
						AND bu.PayType = 1 
						AND bu.IsPosted > 0
						AND bu.Total + bu.TotalExtra - bu.TotalDisc  + (CASE bt.VatSystem WHEN 2 THEN 0 ELSE bu.Vat END) - ISNULL(bp.Val,0)- ISNULL(pp.Val,0) > 0.9
						AND dbo.fnGetDateFromTime(pt.DueDate) < dbo.fnGetDateFromTime(GETDATE())
						AND cu.GUID = @CustomerGUID
						AND bt.bPayTerms = 1
				UNION ALL 
					SELECT 
						(ISNULL (en.Debit, 0) - ISNULL(bp.Val,0) - ISNULL(pp.Val,0)) AS amount 
					FROM 
						ce000 AS ce
						INNER JOIN pt000 pt ON pt.RefGUID = ce.[Guid]
						LEFT JOIN er000 er ON er.ParentGUID = ce.[Guid]
						INNER JOIN ce000 ce1 ON ce1.[Guid] = entryGuid
						INNER JOIN en000 en ON en.parentguid = ce1.GUID
						LEFT JOIN (SELECT SUM(Val) AS Val, DebtGUID FROM bp000 GROUP BY DebtGUID) bp ON bp.DebtGUID = en.GUID
						LEFT JOIN (SELECT SUM(Val) AS Val, PayGUID FROM bp000 GROUP BY payGUID) pp ON pp.PayGUID = en.GUID
						INNER JOIN cu000 cu ON cu.GUID = en.CustomerGUID
						INNER JOIN ac000 ac ON ac.GUID = cu.AccountGUID
					WHERE
						en.Debit - ISNULL(bp.Val,0)- ISNULL(pp.Val,0) > 0.9
						AND dbo.fnGetDateFromTime(pt.DueDate) < dbo.fnGetDateFromTime(GETDATE())
						AND cu.GUID = @CustomerGUID
			)
			SELECT  @SumUnPayedBills = SUM(amount)
			from TOTAL
		END

		SET @SumUnPayedBills = @SumUnPayedBills/@CurrencyVal

	Select @lastDebit AS lastDebit, @lastCredit AS lastCredit, @lastDebitDate AS lastDebitDate, @lastCreditDate	As 	lastCreditDate, @CurrencyGUID  AS CurrencyGUID ,@SumUnPayedBills AS SumUnPayedBills
#########################################################
CREATE FUNCTION fnAccount_GetCustomers (@AccountGUID UNIQUEIDENTIFIER)
	RETURNS TABLE
AS
	RETURN(
		SELECT
			*
		FROM
			[vdCu2]
		WHERE AccountGuid = @AccountGUID
		) 
 
#########################################################
CREATE FUNCTION fnAccount_GetEnCustomer (@AccGuid uniqueidentifier)
	RETURNS TABLE
 AS
 RETURN
	(SELECT
	   cu.cuGUID Guid,
	   cu.cuCustomerName Name,
	   SUM(en.Debit) Debit,
	   SUM(en.Credit) Credit
	FROM 
		en000 en
	LEFT JOIN  vwCu cu on en.CustomerGUID = cu.cuGUID
	INNER JOIN ce000 ce on ce.GUID = en.ParentGUID
	WHERE 
		cuAccount = @AccGuid and ce.IsPosted = 1
	GROUP BY 
		cuCustomerName, cu.cuGUID )
#########################################################
#end