########################################################
CREATE PROCEDURE prcAccount_getBalance
	@accGuid [UNIQUEIDENTIFIER],
	@curGuid [UNIQUEIDENTIFIER] = NULL
AS
/*
this procedure:
	- returns the fixed balance of @accGuid
	- when @curGuid is null or 0x0, the currency is taken from account.currencyGuid	
*/

	SET NOCOUNT ON
	IF ISNULL(@curGuid, 0x0) = 0x0
		SET @curGuid = (SELECT [CurrencyGuid] FROM [ac000] WHERE [guid] = @accGuid)

	SELECT 
		SUM( ISNULL( [en].[fixedEnDebit], 0) - ISNULL( [en].[fixedEnCredit], 0) ) AS [Balance], 
		SUM( ISNULL( [en].[fixedEnDebit], 0)) AS [Debit],
		SUM( ISNULL( [en].[fixedEnCredit], 0)) AS [Credit],
		[dbo].[fnGetCurVal] (@curGuid, getdate()) AS [CurrencyVal]
	FROM 
		[dbo].[fnCeEn_Fixed](@curGUID) [en] INNER JOIN [dbo].[fnGetAccountsList](@accGuid, DEFAULT) [ac] ON [en].[enAccount] = [ac].[GUID]
	WHERE 
		[en].[ceIsPosted] = 1 
########################################################
CREATE PROCEDURE prcCustomer_getBalance
	@CustomerGuid [UNIQUEIDENTIFIER],
	@CurrencyGuid [UNIQUEIDENTIFIER] = NULL
AS
/*
this procedure:
	- returns the fixed balance of @CustomerGuid
	- when @CurrencyGuid is null or 0x0, the currency is taken from account.currencyGuid	
*/
	SET NOCOUNT ON

	DECLARE @AccountGUID [UNIQUEIDENTIFIER]

	SELECT TOP 1 
		@AccountGUID = ac.GUID 
	FROM 
		ac000 ac 
		INNER JOIN cu000 cu ON cu.AccountGUID = ac.GUID 
	WHERE cu.GUID = @CustomerGUID

	IF @AccountGUID IS NULL 
		RETURN

	IF ISNULL(@CurrencyGuid, 0x0) = 0x0
		SET @CurrencyGuid = (SELECT [CurrencyGuid] FROM [ac000] WHERE [guid] = @AccountGUID)
	
	SELECT 
		SUM( ISNULL( [en].[fixedEnDebit], 0) - ISNULL( [en].[fixedEnCredit], 0) ) AS [Balance], 
		SUM( ISNULL( [en].[fixedEnDebit], 0)) AS [Debit],
		SUM( ISNULL( [en].[fixedEnCredit], 0)) AS [Credit],
		[dbo].[fnGetCurVal] (@CurrencyGuid, getdate()) AS [CurrencyVal]
	FROM 
		[dbo].[fnCeEn_Fixed](@CurrencyGuid) [en]
	WHERE 
		[en].[enAccount] = @AccountGUID
		AND
		en.enCustomerGUID = @CustomerGUID
		AND
		[en].[ceIsPosted] = 1 
########################################################
CREATE PROCEDURE prcAccount_getBalance_Uncommited
	@accGuid [UNIQUEIDENTIFIER],
	@curGuid [UNIQUEIDENTIFIER] = NULL
AS
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	SET NOCOUNT ON
	
	EXEC prcAccount_getBalance @accGuid, @curGuid
########################################################
#END