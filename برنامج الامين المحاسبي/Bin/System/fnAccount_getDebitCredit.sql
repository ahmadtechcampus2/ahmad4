#########################################################
CREATE FUNCTION fnAccount_Customer_getDebitCredit(
		@accGuid [uniqueidentifier],
		@curGuid [uniqueidentifier] = 0x0,
		@CustGUID[uniqueidentifier] = 0x0)
	RETURNS TABLE
AS 
	RETURN (		
		SELECT 
			ISNULL(	CASE ISNULL(@curGuid, 0x0) 
						WHEN  0x0 THEN SUM([enDebit])
						ELSE SUM([dbo].[fnCurrency_fix]([enDebit], [enCurrencyPtr], [enCurrencyVal], @curGUID, [enDate]))	
					END
			, 0.0 ) AS [Debit],

			ISNULL(	CASE ISNULL(@curGuid, 0x0) 
						WHEN  0x0 THEN SUM([enCredit])
						ELSE SUM([dbo].[fnCurrency_fix]([enCredit], [enCurrencyPtr], [enCurrencyVal], @curGUID, [enDate]))	
					END
			, 0.0 ) AS [Credit] 
		FROM vwCeEn e
		INNER JOIN [fnGetAccountsList](@accGuid, 0) [f] ON [enAccount] = [f].[guid] 
		WHERE 
			[ceisPosted] <> 0 
			AND 
			(ISNULL(@CustGUID, 0x0) = 0x0 OR [enCustomerGUID] = @CustGUID)
	)
#########################################################
CREATE FUNCTION fnAccount_getDebitCredit(
			@accGuid [uniqueidentifier],
			@curGuid [uniqueidentifier] = 0x0)
	RETURNS TABLE
AS 
	RETURN ( 
		SELECT 
			[Debit], [Credit] 
		FROM
			[dbo].fnAccount_Customer_getDebitCredit(
				@accGuid ,
				@curGuid ,
				default
			)
	)
#########################################################
#END 