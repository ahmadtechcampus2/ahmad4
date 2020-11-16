################################################################################
CREATE FUNCTION NSFnGeneralCustomerBalance(@customerGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @customerInfoBalance TABLE 
(
		Balance			NVARCHAR(100)
)
AS 
BEGIN
	INSERT INTO 
		@customerInfoBalance
	SELECT 
		CuBalance
	FROM 
		[dbo].NSFnCustInfoBalance(@customerGuid) 
	RETURN
END
################################################################################
CREATE FUNCTION NSFnGeneralCustomerInfo(@customerGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @customerInfoBalance TABLE 
(
		MaxBalance			NVARCHAR(100),
		DiscRatio			NVARCHAR(100)

)
AS 
BEGIN
	INSERT INTO 
		@customerInfoBalance
	SELECT 
		[dbo].fnNSFormatMoneyAsNVARCHAR(CU.acMaxDebit / CU.acCurrencyVal, MY.Code),
		CAST(cuDiscRatio AS NVARCHAR(100)) + ' %'
	FROM 
		vwCuAc CU INNER JOIN my000 MY ON CU.acCurrencyPtr = MY.[GUID] AND CU.cuGUID = @customerGuid
	RETURN
END
################################################################################
CREATE FUNCTION NSFnGeneralCustomerLastPayInfo(@customerGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @payInfo TABLE 
(
		PayValue			NVARCHAR(100),
		PayDate			DATE
)
AS 
BEGIN
	INSERT INTO 
		@payInfo
	SELECT	
		[dbo].fnNSFormatMoneyAsNVARCHAR(Credit / CurrencyVal, Code),
		[Date]
	FROM
		(SELECT TOP 1 
			ENCE.enAccount,
			ENCE.ceDate [Date],
			ENCE.ceNumber,
			ENCE.enCurrencyVal CurrencyVal,
			MY.Code Code,
			SUM(ENCE.enCredit / ENCE.enCurrencyVal) Credit
		FROM 
		vwCeEn AS  ENCE INNER JOIN [Er000] AS [er] ON ENCE.[ceGuid] = [er].[EntryGuid] 
		INNER JOIN [vwPy] AS [py] ON [er].[ParentGuid] = [py].[pyGuid] 
		INNER JOIN cu000 CU ON CU.AccountGUID = ENCE.enAccount
		INNER JOIN my000 my ON my.[GUID] = ENCE.enCurrencyPtr
		WHERE CU.[GUID] = @customerGuid AND enCredit > 0 
		GROUP BY ENCE.enAccount, ENCE.ceDate, ENCE.ceNumber, ENCE.enCurrencyVal, my.Code
		ORDER BY ENCE.ceDate DESC, ENCE.ceNumber DESC) T
	RETURN
END
################################################################################
CREATE FUNCTION NSFnGeneralCustomerLastDebitInfo(@customerGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @payInfo TABLE 
(
		DebitValue			NVARCHAR(100),
		DebitDate			DATE
)
AS 
BEGIN
	INSERT INTO 
		@payInfo
	SELECT	
		[dbo].fnNSFormatMoneyAsNVARCHAR(Debit / CurrencyVal, Code),
		[Date]
	FROM
		(SELECT TOP 1 
			ENCE.enAccount,
			ENCE.ceDate [Date],
			ENCE.ceNumber,
			ENCE.enCurrencyVal CurrencyVal,
			MY.Code Code,
			SUM(ENCE.enDebit / ENCE.enCurrencyVal) Debit
		FROM 
		vwCeEn AS  ENCE 
		INNER JOIN cu000 CU ON CU.AccountGUID = ENCE.enAccount
		INNER JOIN my000 my ON my.[GUID] = ENCE.enCurrencyPtr
		WHERE CU.[GUID] = @customerGuid AND enDebit > 0 
		GROUP BY ENCE.enAccount, ENCE.ceDate, ENCE.ceNumber, ENCE.enCurrencyVal, my.Code
		ORDER BY ENCE.ceDate DESC, ENCE.ceNumber DESC) T
	RETURN
END
################################################################################
CREATE FUNCTION NSFnGeneralCustomerLastCreditInfo(@customerGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @payInfo TABLE 
(
		CreditValue			NVARCHAR(100),
		CreditDate			DATE
)
AS 
BEGIN
	INSERT INTO 
		@payInfo
	SELECT	
		[dbo].fnNSFormatMoneyAsNVARCHAR(Credit / CurrencyVal, Code),
		[Date]
	FROM
		(SELECT TOP 1 
			ENCE.enAccount,
			ENCE.ceDate [Date],
			ENCE.ceNumber,
			ENCE.enCurrencyVal CurrencyVal,
			MY.Code Code,
			SUM(ENCE.enCredit / ENCE.enCurrencyVal) Credit
		FROM 
		vwCeEn AS  ENCE 
		INNER JOIN cu000 CU ON CU.AccountGUID = ENCE.enAccount
		INNER JOIN my000 my ON my.[GUID] = ENCE.enCurrencyPtr
		WHERE CU.[GUID] = @customerGuid AND enCredit > 0 
		GROUP BY ENCE.enAccount, ENCE.ceDate, ENCE.ceNumber, ENCE.enCurrencyVal, my.Code
		ORDER BY ENCE.ceDate DESC, ENCE.ceNumber DESC) T
	RETURN
END
################################################################################
#END