################################################################################
CREATE FUNCTION fnNSGetAccDiffFromMaxBalanceInfo(@AccountGuid UNIQUEIDENTIFIER , @readUnPosted BIT = 0)
RETURNS @maxDebitInfo TABLE 
(
	DiffFromMaxDebitValue	FLOAT,
	DiffFromMaxDebitWithCurrCode	NVARCHAR(100)
)
AS 
BEGIN
	DECLARE @MaxDebit FLOAT
	
	DECLARE @language [INT]	= (SELECT [dbo].[fnConnections_getLanguage]() )
	DECLARE @balancesExceededString [NVARCHAR](50) = (SELECT [dbo].[fnStrings_get]('NS\MAXBALANCES', @language) )

	DECLARE @AccWarn int 
	DECLARE @AccCurrancyCode NVARCHAR (50)
	DECLARE @AccMaxDebit FLOAT

	SELECT @AccWarn = ac.Warn, @AccCurrancyCode= my.code , @AccMaxDebit = ac.MaxDebit / ac.CurrencyVal
	FROM ac000 ac 
	INNER JOIN my000 my on ac.CurrencyGUID = my.GUID 
	WHERE ac.GUID = @accountGuid

	DECLARE @accBalances FLOAT  
	
	SELECT @accBalances = AccBalancesValue FROM fnNSGetAccBalWithCostAndBranch(@accountGuid,0x0,0x0,@readUnPosted)

	SET @MaxDebit = (CASE @AccWarn
	WHEN 1 THEN  (@AccMaxDebit - (@accBalances))
	WHEN 2 THEN  (-@AccMaxDebit - (@accBalances))
	ELSE 0 END)

	INSERT INTO @maxDebitInfo 
	SELECT 
	@MaxDebit,
	(CASE WHEN @MaxDebit > 0 THEN (CASE WHEN @AccWarn = 1 THEN ([dbo].fnNSFormatMoneyAsNVARCHAR(ABS(@MaxDebit),@AccCurrancyCode))
	                                             WHEN @AccWarn = 2 THEN @balancesExceededString + ([dbo].fnNSFormatMoneyAsNVARCHAR(ABS(@MaxDebit),@AccCurrancyCode)) END) 
	     WHEN @MaxDebit < 0 THEN (CASE WHEN @AccWarn = 1 THEN @balancesExceededString +([dbo].fnNSFormatMoneyAsNVARCHAR(ABS(@MaxDebit),@AccCurrancyCode)) 
	                                             WHEN @AccWarn = 2 THEN ([dbo].fnNSFormatMoneyAsNVARCHAR(ABS(@MaxDebit),@AccCurrancyCode))  END)  
		  WHEN @MaxDebit = 0 THEN ([dbo].fnNSFormatMoneyAsNVARCHAR(ABS(@MaxDebit),@AccCurrancyCode))
		  END
		  )
	RETURN
end
################################################################################
#END
