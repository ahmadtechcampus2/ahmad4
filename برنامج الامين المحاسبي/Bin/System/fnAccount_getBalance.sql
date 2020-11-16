#########################################################
CREATE function fnAccCust_getBalance(
		@accGuid [uniqueidentifier],
		@curGuid [uniqueidentifier] = 0x0,
		@StartDate [DATETIME] = '1/1/1980',
		@EndDate [DATETIME] = NULL,
		@CostGuid [UNIQUEIDENTIFIER] =0x00,
		@CustGuid [uniqueidentifier] =0x00)
	returns [float]
AS BEGIN
/*
this function:
	- returns the balance of a given @accGuid in the given @curGuid by accumulating posted entries
	- ignores @curGuid when 0x0.
	- deals with core tables directly, ignoring branches and itemSecurity features.
*/

	declare @result [float]

	DECLARE @CostTbl TABLE ([Cost] UNIQUEIDENTIFIER)
	INSERT INTO @CostTbl SELECT Guid from dbo.fnGetCostsList(@CostGuid)
	IF @CostGuid = 0X00
		INSERT INTO @CostTbl VALUES(0X00)
	if isnull(@curGuid, 0x0) = 0x0
	BEGIN
		IF @EndDate IS NULL
			SET @result = (
					SELECT 
						sum([e].[debit]) 
							- sum([e].[credit]) 
					FROM [en000] [e] inner join [ce000] [c] ON [e].[parentGuid] = [c].[guid] inner join [fnGetAccountsList](@accGuid, 0) [f] ON [e].[accountGuid] = [f].[guid]
					INNER JOIN @CostTbl J ON J.Cost = e.CostGuid
					WHERE [c].[isPosted] <> 0 AND CAST ([e].[Date] AS DATE) >= @StartDate )
		ELSE
				SET @result = (
					SELECT 
						sum([e].[debit]) 
							- sum([e].[credit]) 
					FROM [en000] [e] inner join [ce000] [c] ON [e].[parentGuid] = [c].[guid] inner join [fnGetAccountsList](@accGuid, 0) [f] ON [e].[accountGuid] = [f].[guid]
					INNER JOIN @CostTbl J ON J.Cost = e.CostGuid
					WHERE [c].[isPosted] <> 0 AND CAST ([e].[Date] AS DATE) BETWEEN @StartDate AND @EndDate AND [e].CustomerGUID = CASE WHEN ISNULL(@CustGuid, 0x0) <> 0x0 THEN  @CustGuid ELSE [e].CustomerGUID END )

	END
	else
	BEGIN
		IF @EndDate IS NULL
			set @result = (
					select
						sum([dbo].[fnCurrency_fix]([e].[debit], [e].[currencyGuid], [e].[currencyVal], @curGUID, [e].[date]))
							- sum([dbo].[fnCurrency_fix]([e].[credit], [e].[currencyGuid], [e].[currencyVal], @curGUID, [e].[date]))
					from [en000] [e] inner join [ce000] [c] on [e].[parentGuid] = [c].[guid] inner join [fnGetAccountsList](@accGuid, 0) [f] on [e].[accountGuid] = [f].[guid]
					INNER JOIN @CostTbl J ON J.Cost = e.CostGuid
					where [c].[isPosted] <> 0  AND CAST ([e].[Date] AS DATE) >= @StartDate  AND [e].CustomerGUID = CASE WHEN ISNULL(@CustGuid, 0x0) <> 0x0 THEN  @CustGuid ELSE [e].CustomerGUID END)
		ELSE
			set @result = (
					SELECT
						SUM([dbo].[fnCurrency_fix]([e].[debit], [e].[currencyGuid], [e].[currencyVal], @curGUID, [e].[date]))
							- SUM([dbo].[fnCurrency_fix]([e].[credit], [e].[currencyGuid], [e].[currencyVal], @curGUID, [e].[date]))
					FROM [en000] [e] inner join [ce000] [c] on [e].[parentGuid] = [c].[guid] inner join [fnGetAccountsList](@accGuid, 0) [f] on [e].[accountGuid] = [f].[guid]
					INNER JOIN @CostTbl J ON J.Cost = e.CostGuid
					WHERE [c].[isPosted] <> 0   AND CAST ([e].[Date] AS DATE) BETWEEN @StartDate AND @EndDate  AND [e].CustomerGUID = CASE WHEN ISNULL(@CustGuid, 0x0) <> 0x0 THEN  @CustGuid ELSE [e].CustomerGUID END)
	END

	RETURN isnull(@result, 0.0)
END

#########################################################
CREATE function fnAccount_getBalance(
		@accGuid [uniqueidentifier],
		@curGuid [uniqueidentifier] = 0x0,
		@StartDate [DATETIME] = '1/1/1980',
		@EndDate [DATETIME] = NULL,
		@CostGuid [UNIQUEIDENTIFIER] =0x00)
	RETURNS [float]
AS BEGIN 
RETURN dbo.fnAccCust_getBalance(
		@accGuid ,
		@curGuid ,
		@StartDate,
		@EndDate ,
		@CostGuid ,
		0x00 )
END
#########################################################
#end