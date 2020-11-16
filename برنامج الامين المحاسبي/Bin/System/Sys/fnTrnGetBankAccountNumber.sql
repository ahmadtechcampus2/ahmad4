###########################################################################
CREATE FUNCTION fnTrnGetBankAccountNumber
	(
	
		@NumberGuid	UNIQUEIDENTIFIER = 0x0
		,@BankGuid	UNIQUEIDENTIFIER = 0x0
		,@AccountGuid	UNIQUEIDENTIFIER = 0x0
		,@CurrencyGuid	UNIQUEIDENTIFIER = 0x0
	)
RETURNS TABLE	
AS	
RETURN
(
	SELECT 
		an.[Guid] AS Guid
		,an.AccountNumber
		,an.BankGuid
		,bank.Name AS BankName
		,an.CurrencyGuid
		,my.[Name] AS CurrencyName
		,an.AccountGuid
		,ac.Code + '-' + ac.Name AS AccountName 
	FROM 
		TrnBankAccountNumber000 AS an	
		INNER JOIN TrnBank000 AS bank ON bank.[Guid] = an.BankGuid
		INNER JOIN my000 AS my ON my.[Guid] = an.CurrencyGuid
		INNER JOIN Ac000 AS ac ON ac.[Guid] = an.AccountGuid			
	WHERE 		
		(@NumberGuid = 0x0 OR an.[Guid] = @NumberGuid)
		AND
		(@BankGuid = 0x0 OR bank.[Guid] = @BankGuid)
		AND
		(@AccountGuid = 0x0 OR ac.[Guid] = @AccountGuid)
		AND		
		(@CurrencyGuid = 0x0 OR my.[Guid] = @CurrencyGuid)
)
###########################################################################
#END