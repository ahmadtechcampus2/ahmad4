################################################################################
CREATE FUNCTION fnNSGetCustBalWithCostAndBranch(@customerGuid UNIQUEIDENTIFIER,@costGuid UNIQUEIDENTIFIER,@branchGuid UNIQUEIDENTIFIER,@readUnPosted BIT = 0)
RETURNS @CustBalances TABLE 
(
	CustBalancesValue FLOAT,
	CustBalancesWithCurrCode NVARCHAR(max)
)
AS 
BEGIN

	DECLARE @ACCGUID	UNIQUEIDENTIFIER
	SET @ACCGUID = (SELECT cu.[AccountGUID] 
				FROM cu000 cu  
				WHERE cu.[GUID] = @customerGuid)
				
	INSERT INTO @CustBalances
	SELECT * FROM fnNSGetAccBalWithCostAndBranch(@ACCGUID,@costGuid,@branchGuid,@readUnPosted)
	RETURN
END
################################################################################
CREATE FUNCTION fnNSGetAccBalWithCostAndBranch(@AccGuid UNIQUEIDENTIFIER, @costGuid UNIQUEIDENTIFIER, @branchGuid UNIQUEIDENTIFIER, @readUnPosted BIT = 0)
RETURNS @CustBalances TABLE 
(
	AccBalancesValue FLOAT,
	AccBalancesWithCurrCode NVARCHAR(MAX)
)
AS 
BEGIN
	DECLARE @BalncesValue FLOAT = 0
	DECLARE @CurrCode     NVARCHAR(50) 		
	DECLARE @Cost_Tbl     TABLE([GUID] UNIQUEIDENTIFIER) 
	DECLARE @Branch_Tbl   TABLE([GUID] UNIQUEIDENTIFIER)


	INSERT INTO @Cost_Tbl  
	SELECT [GUID] 
	FROM [dbo].[fnGetCostsList](@costGuid)  
	IF ISNULL( @costGuid, 0x0) = 0x0   
		INSERT INTO @Cost_Tbl VALUES(0x0)

	
	INSERT INTO @Branch_Tbl  
	SELECT [GUID] 
	FROM [dbo].[fnGetBranchesList](@branchGuid)  
	IF ISNULL( @branchGuid, 0x0) = 0x0   
		INSERT INTO @Branch_Tbl VALUES(0x0)
	

	SELECT 
		@CurrCode = (SELECT my.Code 
				     FROM ac000 ac 
					 INNER JOIN  my000 my  ON my.[GUID] = ac.CurrencyGUID 
					 WHERE ac.[GUID] = @AccGuid)

	SELECT 
		@BalncesValue = (SELECT SUM([dbo].[fnCurrency_fix]([en].[debit], [en].[currencyGuid], [en].[currencyVal], ac.CurrencyGUID, [en].[date]))
							  - SUM([dbo].[fnCurrency_fix]([en].[credit], [en].[currencyGuid], [en].[currencyVal], ac.CurrencyGUID, [en].[date])))
	FROM 
		en000 en
		INNER JOIN @Cost_Tbl fn ON en.CostGUID = fn.[GUID]
		INNER JOIN ac000 ac ON ac.[GUID] = en.AccountGUID 
		INNER JOIN ce000 ce ON en.parentGuid = ce.[Guid]
		INNER JOIN @Branch_Tbl fnBr ON ce.Branch = fnBr.[GUID]
	WHERE 
		en.AccountGUID = @AccGuid 
		AND ce.IsPosted = CASE @readUnPosted WHEN 0 THEN 1 ELSE ce.IsPosted END
	GROUP BY 
		en.AccountGUID
	

	INSERT INTO 
		@CustBalances
	SELECT 
		ISNULL(@BalncesValue, 0),
		[dbo].fnNSFormatMoneyAsNVARCHAR(ABS(ISNULL(@BalncesValue, 0)), @CurrCode)

	RETURN
END
################################################################################
#END
