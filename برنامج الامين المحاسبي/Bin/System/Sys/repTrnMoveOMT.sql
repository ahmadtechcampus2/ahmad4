############################################################## 
CREATE PROC repTrnMoveOMT
	@StartDate			DATE,
	@EndDate			DATE,
	@ShowInTransfer		BIT,
	@ShowOutTransfer	BIT,
	@ShowRepDetails		BIT,
	@SourceSender		UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	IF @ShowRepDetails <> 1
	BEGIN
			SELECT 
				tt.Guid,
				tt.TrnNumber,
				tt.Date,
				us.LoginName AS AmnUserName,
				ex.Name AS ExecutorName,
				tb.Name,
				tt.IsOut,
				(tt.ValueInCardCurrency * tt.IsOut) AS ValueInCardCurrencyOUT,
				(CASE tt.IsOut WHEN 0 THEN tt.ValueInCardCurrency else 0 END) AS ValueInCardCurrencyIN,
				(CASE tt.IsOut WHEN 0 THEN tt.ValueInCardCurrency else 0 END) * CardCurrencyValue AS CalcValueInDefaultCurrency,
				tt.ValueInDefaultCurrency,
				tc.Name As trnCenter
			FROM 
				TrnTransferCompanyCard000 AS tt
				INNER JOIN TrnBranch000 AS tb ON tb.GUID = tt.BranchID 
				INNER JOIN TrnCenter000 As tc ON tt.UserCenterGuid = tc.GUID
				INNER JOIN RepSrcs AS rs ON tt.BranchID = rs.IdType
				LEFT JOIN TrnExecutors000 ex on ex.Guid = tt.ExecutorGuid
				LEFT JOIN us000 us on us.GUID = tt.UserId
			WHERE 
				(@ShowInTransfer = 1 OR IsOut != 0)
				AND (@ShowOutTransfer = 1 OR IsOut != 1)
				AND (tt.Date between @StartDate AND @EndDate)
				AND rs.IdTbl = @SourceSender
			ORDER BY tt.Date,tt.TrnNumber
	END
	ELSE
	BEGIN
		SELECT 
			tb.Name,
			SUM(tt.ValueInCardCurrency * tt.IsOut) AS ValueInCardCurrencyOUT,
			SUM(CASE tt.IsOut WHEN 1 THEN 1 ELSE 0 END) AS OutCount,
			SUM(CASE tt.IsOut WHEN 1 THEN 0 ELSE 1 END) AS INCount,
			SUM(CASE tt.IsOut WHEN 0 THEN tt.ValueInCardCurrency else 0 END) AS ValueInCardCurrencyIN,
			SUM((CASE tt.IsOut WHEN 0 THEN tt.ValueInCardCurrency else 0 END) * CardCurrencyValue) AS CalcValueInDefaultCurrency,
			SUM(tt.ValueInDefaultCurrency) AS ValueInDefaultCurrency
		FROM 
			TrnTransferCompanyCard000 AS tt
			INNER JOIN TrnBranch000 AS tb ON tb.GUID = tt.BranchID 
			INNER JOIN RepSrcs AS rs ON tt.BranchID = rs.IdType
		WHERE 
			(@ShowInTransfer = 1 OR IsOut != 0)
			AND (@ShowOutTransfer = 1 OR IsOut != 1)
			AND (tt.Date between @StartDate AND @EndDate)
			AND rs.IdTbl = @SourceSender
		GROUP BY tb.Name
	END
#################################################################
CREATE PROC prcValidateOMTTransferConditions
	@TrnGuid		UNIQUEIDENTIFIER,
	@DocumentNumber	VARCHAR(50),
	@Amount			FLOAT,
	@IsOut			BIT, 
	@Date			DATETIME,
	@Time			DATETIME = ''
AS
	SET NOCOUNT ON

	SELECT @Date = CAST(CAST(@Date AS DATE) AS VARCHAR(10)) + ' ' + CAST(CAST(@Time AS TIME) AS VARCHAR(12))
	DECLARE 
		@ConditionsPeriod	INT,
		@ConditionAmount	FLOAT
	
	SELECT  @ConditionsPeriod = CAST (value AS INT) FROM op000 WHERE name = CASE @IsOut WHEN 0 THEN 'TrnCfg_OMT_OutTransferPeriod' ELSE 'TrnCfg_OMT_InTransferPeriod' END
	SELECT  @ConditionAmount = CAST(REPLACE(value, ',', '') AS FLOAT) FROM op000 WHERE name = CASE @IsOut WHEN 0 THEN 'TrnCfg_OMT_OutTransferAmount' ELSE 'TrnCfg_OMT_InTransferAmount' END
	
	SET  @ConditionsPeriod = ISNULL(@ConditionsPeriod, 0)
	SET  @ConditionAmount = ISNULL(@ConditionAmount, 0)
	
	IF @IsOut = 0
	BEGIN
		DECLARE 
			@CurrGuid	UNIQUEIDENTIFIER,
			@Temp		FLOAT = @Amount

		SELECT @CurrGuid = CAST(value AS UNIQUEIDENTIFIER) FROM op000 WHERE Name = 'TrnCfg_OMT_CurrencyGuid'
		SELECT @Amount = @Amount / NULLIF(BuyTranfer, 0) from fnTrnGetCurrencyInOutVal(@CurrGuid, @Date)

		IF ISNULL(@Amount, 0) = 0
		BEGIN
			SET @Amount = @Temp
			SELECT @Amount /= ISNULL(dbo.fnGetCurVal(@CurrGuid, @Date), 1)
		END
	END

	IF @Amount > @ConditionAmount AND @ConditionAmount > 0
	BEGIN
		SELECT 1 AS result, CAST(@ConditionAmount AS varchar) AS Msg -- the ammount is greater than the allowed limit
		RETURN
	END

	DECLARE @Period INT
	SELECT 
		@Period = DATEDIFF(DAY, Max(Date), @Date)
	FROM 
		TrnTransferCompanyCard000 
	WHERE 
		DocumentNumber = @DocumentNumber
		And IsOut = @IsOut
		And Date <= @Date
		And Guid <> @TrnGuid

	IF @Period < @ConditionsPeriod and @ConditionsPeriod > 0
	BEGIN
		SELECT 2  AS result, CAST(@ConditionsPeriod - @Period AS varchar) Msg -- you can't recieve this transfer before @Msg day
		RETURN
	END

	SELECT 0 AS result, '' as Msg
#################################################################
#END     
