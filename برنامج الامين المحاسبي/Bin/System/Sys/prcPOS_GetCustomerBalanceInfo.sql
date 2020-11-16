################################################################################
CREATE FUNCTION fnPOS_GetCustomerDeferredAmount (@CustomerGUID UNIQUEIDENTIFIER, @IsToday BIT = 0)
	RETURNS FLOAT 
AS BEGIN 

	RETURN (
		ISNULL((SELECT 
			SUM(ISNULL(pak.DeferredAmount, 0))
		FROM 
			POSOrder000 o 
			INNER JOIN POSPaymentsPackage000 pak	ON pak.GUID	= o.PaymentsPackageID	
			INNER JOIN cu000 cu						ON cu.GUID	= pak.DeferredAccount
			LEFT JOIN BillRel000 br					ON o.GUID	= br.ParentGUID
		WHERE 
			cu.GUID = @CustomerGUID
			AND 
			pak.DeferredAmount > 0
			AND 
			br.GUID IS NULL
			AND 
			((@IsToday = 0) OR ((@IsToday = 1) AND (CONVERT(DATE, o.[Date]) = CONVERT(DATE, GETDATE()))))
			), 0)
	
		)
END
################################################################################
CREATE PROC prcPOS_GetCustomerBalance
	@CustomerGUID UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 

	DECLARE @customer_bal FLOAT

	SELECT 
		@customer_bal = SUM([en].[Credit] - [en].[Debit])
	FROM 
		[ac000] [ac]
		INNER JOIN [cu000] [cu]			ON [ac].[GUID] = [cu].[AccountGUID]
		INNER JOIN [en000] [en]			ON [ac].[GUID] = [en].[AccountGUID]
		INNER JOIN [ce000] [ce]			ON [ce].[GUID] = [en].[ParentGUID]
		INNER JOIN DiscountCard000 [d]	ON [cu].[GUID] = [d].[CustomerGUID]
	WHERE 
		([ce].[IsPosted] = 1) 
		AND 
		[cu].[GUID] = @CustomerGUID

	SELECT ISNULL(@customer_bal, 0) + dbo.fnPOS_GetCustomerDeferredAmount(@CustomerGUID, DEFAULT) AS Balance
################################################################################
CREATE PROC prcPOS_GetCustomerBalanceInfo
	@CustomerGUID UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	IF ISNULL(@CustomerGUID, 0x0) = 0x0 
		RETURN 
	
	DECLARE 
		@bal			FLOAT = 0,
		@max			FLOAT = 0,
		@hasBadject		BIT	= 0	
	
	IF EXISTS (SELECT * FROM cu000 WHERE GUID = @CustomerGUID AND Warn > 0)
	BEGIN 
		SELECT TOP 1
			@bal = CASE cu.[Warn] WHEN 1 THEN ISNULL((cu.[Debit] - cu.[Credit]) + ISNULL(ch.Value, 0), 0) ELSE (ISNULL((cu.[Credit] - cu.[Debit]), 0) - ISNULL(ch.Value, 0)) END,
			@max = cu.[MaxDebit]
		FROM 
			cu000 cu
			OUTER APPLY dbo.fnCheque_AccCust_GetBudgetValue(cu.AccountGUID, cu.GUID, cu.ConsiderChecksInBudget) ch
		WHERE 
			cu.GUID = @CustomerGUID
			AND 
			cu.Warn > 0

		SET @hasBadject = 1
	END 
		
	IF (@hasBadject = 0) AND EXISTS (SELECT * FROM cu000 cu INNER JOIN ac000 ac ON ac.GUID = cu.AccountGUID WHERE cu.GUID = @CustomerGUID AND ac.Warn > 0)
	BEGIN 
		SELECT TOP 1
			@bal = CASE ac.[Warn] WHEN 1 THEN ISNULL((ac.[Debit] - ac.[Credit]) + ISNULL(ch.Value, 0), 0) ELSE (ISNULL((ac.[Credit] - ac.[Debit]), 0) - ISNULL(ch.Value, 0)) END,
			@max = ac.[MaxDebit]
		FROM 
			cu000 cu
			INNER JOIN ac000 ac ON ac.GUID = cu.AccountGUID 
			OUTER APPLY dbo.fnCheque_GetBudgetValue(ac.GUID, ac.ConsiderChecksInBudget) ch
		WHERE 
			cu.GUID = @CustomerGUID
			AND 
			ac.Warn > 0
		
		SET @hasBadject = 1
	END

	IF ((@hasBadject = 0) OR (ISNULL(@max, 0) = 0))
		RETURN 

	SET @bal = @bal + dbo.fnPOS_GetCustomerDeferredAmount(@CustomerGUID, DEFAULT)

	DECLARE @lang INT 
	SET @lang = [dbo].[fnConnections_GetLanguage]()

	SELECT 
		ISNULL(@bal, 0)	AS Balance,
		ISNULL(@max, 0)	AS MaxBalance,
		CASE @lang WHEN 0 THEN CustomerName ELSE CASE LatinName WHEN '' THEN CustomerName ELSE LatinName END END AS CustomerName
	FROM 
		cu000 
	WHERE 
		GUID = @CustomerGUID
################################################################################
#END
