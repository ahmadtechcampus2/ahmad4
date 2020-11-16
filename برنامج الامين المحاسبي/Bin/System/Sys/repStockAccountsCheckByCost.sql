#################################################################
CREATE PROC repStockAccountsCheckByCost
	@EndDate		DATE,
	@IgnoredVarianceValue FLOAT,
	@FromDate	DATE = NULL
AS
	SET NOCOUNT ON;
	DECLARE @FPDate DATE = (SELECT dbo.fnDate_Amn2Sql(Value) FROM op000 WHERE Name = N'AmnCfg_FPDate');
	--------------------------------------------------------------
	CREATE TABLE [#t_Prices]  
	(  
		[mtNumber] 	[UNIQUEIDENTIFIER],  
		[APrice] 	[FLOAT]  
	)

	DECLARE @SDate Date = ISNULL(@FromDate,@FPDate)
	DECLARE @DefCur  UNIQUEIDENTIFIER = ( SELECT [dbo].fnGetDefaultCurr())
	WHILE @SDate <= @EndDate
	BEGIN
		EXEC prcGetAvgPrice @FPDate , @SDate , @CurrencyGuid = @DefCur , @CalcTotalPrice = 1
		DECLARE @Invent FLOAT = (SELECT SUM(APrice) FROM #t_Prices)
		DECLARE @AccBalance FLOAT = (SELECT  ISNULL( SUM(Debit - Credit)  , 0)
		FROM en000  en
		INNER JOIN #Accounts A 
		ON en.AccountGUID = A.acGUID AND en.Date <= @SDate)

		INSERT INTO  #EndResult VALUES   (@SDate , @Invent , @AccBalance , ABS(@Invent - @AccBalance))
		IF ( ABS(@Invent - @AccBalance)  > ABS(@IgnoredVarianceValue) )
			BREAK;
		SET @SDate = DATEADD(day,1,@SDate)

		TRUNCATE TABLE #t_Prices
	END

#################################################################
#END