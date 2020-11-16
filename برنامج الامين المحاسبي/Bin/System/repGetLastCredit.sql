#########################################################
## Ì⁄Ìœ ¬Œ— ﬁÌ„… œ«∆‰… »Ì‰  «—ÌŒÌ‰ ·Õ”«» „Õœœ
CREATE PROCEDURE repGetLastCredit
	@StartDate [DATETIME],
	@EndDate [DATETIME],
	@AccPtr [UNIQUEIDENTIFIER],
	@CurrencyGuid [UNIQUEIDENTIFIER],
	@CostPtr [UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON 

	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result]( [LastPay] [FLOAT], [Date] [DATETIME], [ceSecurity] [INT])

	DECLARE @Cost_Tbl TABLE( [GUID] [UNIQUEIDENTIFIER]) 
	INSERT INTO @Cost_Tbl  SELECT [GUID] FROM [dbo].[fnGetCostsList]( @CostPtr)  
	IF ISNULL( @CostPtr, 0x0) = 0x0   
		INSERT INTO @Cost_Tbl VALUES(0x0)

	INSERT INTO [#Result]
	SELECT TOP 1
		[dbo].[fnCurrency_fix]( [enCredit], [enCurrencyPtr], [enCurrencyVal], @CurrencyGuid , @EndDate) AS [LastPay],
		[enDate] AS [Date],
		[ceSecurity]
	FROM
		[vwExtended_en] [en]
		INNER JOIN @Cost_Tbl [co] ON [en].[enCostPoint] = [co].[Guid]
	WHERE
		([enDate] BETWEEN @StartDate AND @EndDate)
		AND( [enDebit] = 0)
		AND( [enAccount] = @AccPtr)
	ORDER BY [enDate] DESC
	
	exec [prcCheckSecurity]

	select * from [#Result]
#########################################################
#END
