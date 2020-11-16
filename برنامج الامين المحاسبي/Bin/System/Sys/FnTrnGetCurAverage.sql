#####################################################
CREATE FUNCTION fnTrnExAccSellOrRateOption()
RETURNS BIT
AS
BEGIN
	DECLARE @value BIT
	SELECT @value = CAST( Value AS BIT) FROM op000 WHERE [Name]= 'TrnCfg_ExAccounts_SellsOrRateDifference'
	RETURN (ISNULL(@value, 0))
END
#####################################################
CREATE FUNCTION FnTrnGetExchangeAccount
		(
			@TypeGuid UNIQUEIDENTIFIER = 0X0,
			@CurrencyGuid UNIQUEIDENTIFIER = 0X0
		)
	RETURNS @Result TABLE (TypeGuid UNIQUEIDENTIFIER, CurrencyGuid UNIQUEIDENTIFIER,
	 AccountGuid UNIQUEIDENTIFIER)
AS 
BEGIN
	INSERT INTO @Result
	SELECT 
		Type.Guid,
		Acc.CurrencyGuid,
		Acc.AccountGuid
	FROM 
		TrnExchangeTypes000 AS Type
		INNER JOIN TrnGroupCurrencyAccount000 AS GroupAcc 
			ON GroupAcc.GUID = Type.GroupCurrencyAccGUID
		INNER JOIN TrnCurrencyAccount000 AS Acc ON Acc.ParentGuid = GroupAcc.Guid 
	WHERE 
		(@TypeGuid = 0X0 OR  Type.Guid = @TypeGuid)
		AND
		(@CurrencyGuid = 0X0 OR Acc.CurrencyGuid = @CurrencyGuid)
	
	RETURN
END	
#####################################################
CREATE FUNCTION fnTrnGetLastExchangeEvalRecord
			(
				@CurrencyGUID UNIQUEIDENTIFIER,
				@ToDate       DATETIME 
			)
RETURNS @Result TABLE (EvaluatedVal FLOAT, EqEvlBalance FLOAT, [DATE] DATETIME)

AS
BEGIN

DECLARE @Date DATETIME,
	@EvGuid  UNIQUEIDENTIFIER


DECLARE @EvDetailGuidTable TABLE (GUID UNIQUEIDENTIFIER, DETGUID UNIQUEIDENTIFIER)

INSERT INTO @EvDetailGuidTable
SELECT 	TOP 1
	Ev.GUID,
	EvDet.GUID
FROM TrnAccountsEvl000 AS Ev
	INNER JOIN TrnAccountsEvlDetail000 AS EvDet ON Ev.GUID = EvDet.ParentGUID
	INNER JOIN FnTrnGetExchangeAccount(0x0, @CurrencyGUID) AS Accounts 
		ON Accounts.AccountGuid = EvDet.AccountGuid
WHERE 	
	Ev.[Date] <= @ToDate
	AND EvDet.CurrencyGUID = @CurrencyGUID
ORDER BY Ev.[Date] DESC 

INSERT INTO @Result
SELECT 
	EvDet.EvaluatedVal,
	EvDet.EqEvlBalance,
	Ev.[Date]
FROM @EvDetailGuidTable AS record
INNER JOIN TrnAccountsEvl000 AS Ev ON Ev.GUID = record.GUID 
INNER JOIN TrnAccountsEvlDetail000 AS EvDet 
	ON EvDet.ParentGUID = Ev.Guid AND EvDet.GUID = record.DETGUID


RETURN
END
#####################################################
CREATE FUNCTION FnTrnGetCurAverage
		(
			@Currency UNIQUEIDENTIFIER,
			@ToDate DATETIME = GetDate
		) 
	RETURNS @Result TABLE (CurAvg FLOAT, CurBalance FLOAT, [DATE] DATETIME) 
AS	 
BEGIN  
	DECLARE --@initBalance FLOAT, 
		@initCurBalance FLOAT,
		@CurrencyBalance FLOAT,
		@initDate DATETIME, 
		@DATE DATETIME 
	DECLARE @Debit FLOAT, @Credit FLOAT, 
		@Avg FLOAT, 
		@EnParentGuid UNIQUEIDENTIFIER,
		@NewAvg FLOAT, @CurrencyVal FLOAT, 
		@AvgEffect INT 
		 
 	SELECT 	--@initBalance = Balance,
		@initCurBalance = CurBalance, 
		@initDate = [DATE], 
		@Avg = CurrencyVal 
	FROM TrnCurrencyBalance000 
	WHERE Currency =  @Currency 
	--AND [DATE] < @ToDate 
	AND [DATE] = (SELECT MAX([DATE])  
			FROM TrnCurrencyBalance000  
			WHERE Currency = @Currency 
			AND [DATE] < @ToDate) 
	SET @initDate = ISNULL(@initDate, '1980') 
	--SET @initBalance = ISNULL(@initBalance, 0) 
	SET @Avg = ISNULL(@Avg, 0) 
	DECLARE @EvaluatedVal FLOAT, 
		@LastEvDate DATETIME, 
		@FromDate DATETIME 
	SET @FromDate = '' 
			 
	SELECT  
		@EvaluatedVal = EvaluatedVal, 
		@LastEvDate = [DATE] 
	FROM	fnTrnGetLastExchangeEvalRecord(@Currency, @ToDate) 
	SET @EvaluatedVal = ISNULL(@EvaluatedVal, 0) 
	IF (@EvaluatedVal <> 0 AND @LastEvDate > @initDate) 
	BEGIN 
		SET @Avg = @EvaluatedVal 
		SET @FROMDATE = DATEADD(ss, 1, @LastEvDate) 
		
		-- Õ”«» «·—’Ìœ «·’ÕÌÕ
		SELECT
			@initCurBalance = (sumdebit - sumcredit) 
		FROM FnTrnGetExchangeCurrencyBalance(@Currency, '', @LastEvDate)--@ToDate) 
	END 
	ELSE 
	BEGIN 
		SET @FROMDATE = DATEADD(ss, 1, @initDate) 
	END 
	SET @CurrencyBalance = ISNULL(@initCurBalance, 0)
	SET @Date = @FROMDATE 
	DECLARE AvgCursor CURSOR FORWARD_ONLY FOR   
	SELECT  
		CurrencyVal,		 
		Debit / CurrencyVal, 
 		Credit / CurrencyVal, 
		[DATE],
		AvgEffect ,
		ParentGuid
	FROM FnTrnExCurrEntries(0x0, @Currency, @FROMDATE, @ToDate, 0, 0x0) 
 	ORDER BY [DATE], CeNumber, EnNumber  
	OPEN AvgCursor  
	FETCH NEXT FROM AvgCursor INTO  
			@CurrencyVal,  
			@Debit, 
			@credit, 
			@DATE, 
			@AvgEffect,
			@EnParentGuid
	WHILE @@FETCH_STATUS = 0  
	BEGIN   
		IF ((@Debit <> 0) AND (@EnParentGUID NOT IN (SELECT EntryGuid FROM TrnCloseCashier000))) -- ‘—«¡
		BEGIN 
			IF (@AvgEffect = 1) 
			BEGIN 
				IF (@Avg = 0)
					SET @Avg = @CurrencyVal
					
				IF (@CurrencyBalance > 0)
				BEGIN
					SET @NewAvg = (@CurrencyBalance * @Avg + @Debit * @CurrencyVal) / (@CurrencyBalance + @Debit) 
					SET @Avg = @NewAvg 
				END	
				ELSE
					SET @Avg = @CurrencyVal
					
				SET @CurrencyBalance = @CurrencyBalance + @Debit
			END	 
		END		 
		ELSE IF ((@Debit = 0) AND (@EnParentGUID NOT IN (SELECT EntryGuid FROM TrnCloseCashier000))) -- „»Ì⁄
		BEGIN 
			SET @CurrencyBalance = @CurrencyBalance - @Credit 
		END 
	 
		FETCH NEXT FROM AvgCursor INTO  
			@CurrencyVal,  
			@Debit, 
			@credit, 
			@DATE, 
			@AvgEffect ,
			@EnParentGuid

	END   
	CLOSE AvgCursor  
	DEALLOCATE AvgCursor 
	 
	DECLARE @CurrentCurrencyVal FLOAT, 
		@Ebslon FLOAT 
	SELECT @CurrentCurrencyVal = InVal FROM fnTrnGetCurrencyInOutVal(@Currency ,@ToDate) 
	SELECT @Ebslon = 0.2
	SELECT @CurrencyBalance = ISNULL(@CurrencyBalance, 0)
  
	IF (@Avg > @CurrentCurrencyVal * (1 + @Ebslon) OR @Avg < @CurrentCurrencyVal * (1 - @Ebslon)) 
	BEGIN 
		INSERT INTO @Result  
		VALUES	(@CurrentCurrencyVal, @CurrencyBalance, @DATE) 
	END 
	ELSE 
	BEGIN 
		INSERT INTO @Result  
		VALUES	(@Avg,	@CurrencyBalance, @DATE) 
	END	 
RETURN 
END 
##############################################
CREATE FUNCTION FnTrnGetCurAverage2
		(
			@Currency UNIQUEIDENTIFIER,
			@ToDate DATETIME = GetDate
		)
	RETURNS @Result TABLE (CurAvg FLOAT, CurBalance FLOAT,[DATE] DATETIME)
AS	
BEGIN 	
	DECLARE @Debit FLOAT, @Credit FLOAT,
		@Avg FLOAT,
		@NewAvg FLOAT, @CurrencyVal FLOAT,
		@EnParentGuid UNIQUEIDENTIFIER,
		@DATE DATETIME, @AvgEffect INT,
		@initCurBalance FLOAT,
		@CurrencyBalance FLOAT
	SELECT @initCurBalance = 0, @Avg = 0
	
	DECLARE @EvaluatedVal FLOAT,
		@LastEvDate DATETIME,
		@FROMDATE DATETIME
	SET @FROMDATE = ''
			
	SELECT 
		@EvaluatedVal = EvaluatedVal,
		@LastEvDate = [DATE]
	FROM	fnTrnGetLastExchangeEvalRecord(@Currency, @ToDate)
	SET @EvaluatedVal = ISNULL(@EvaluatedVal, 0)
	IF (@EvaluatedVal <> 0 )
	BEGIN
		SET @Avg = @EvaluatedVal
		SET @FROMDATE = DATEADD(ss, 1, @LastEvDate)
				-- Õ”«» «·—’Ìœ «·’ÕÌÕ
		SELECT
			@initCurBalance = (sumdebit - sumcredit) 
		FROM FnTrnGetExchangeCurrencyBalance(@Currency, '', @LastEvDate)--@ToDate) 
	END
	SET @CurrencyBalance = ISNULL(@initCurBalance, 0)
	SET @Date = @FROMDATE 
	
	DECLARE AvgCursor CURSOR FORWARD_ONLY FOR  
	SELECT 
		CurrencyVal,		
		Debit / CurrencyVal,
 		Credit / CurrencyVal,
		[DATE],
		AvgEffect,
		ParentGuid
 	FROM FnTrnExCurrEntries(0x0, @Currency, @FROMDATE, @ToDate, 0, 0x0)
	ORDER BY [DATE], [CeNumber], [EnNumber]
	
	OPEN AvgCursor 
	FETCH NEXT FROM AvgCursor INTO 
			@CurrencyVal, 
			@Debit,
			@credit,
			@DATE,
			@AvgEffect,
			@EnParentGuid
	
	WHILE @@FETCH_STATUS = 0 
	BEGIN  
			
		IF ((@Debit <> 0) AND (@EnParentGUID NOT IN (SELECT EntryGuid FROM TrnCloseCashier000))) -- ‘—«¡
		BEGIN 
			IF (@AvgEffect = 1)
			BEGIN	
				IF (@Avg = 0)
					SET @Avg = @CurrencyVal
				
				IF (@CurrencyBalance > 0)
				BEGIN
					SET @NewAvg = (@CurrencyBalance * @Avg + @Debit * @CurrencyVal) / (@CurrencyBalance + @Debit)
					SET @Avg = @NewAvg
				END	
				ELSE
					SET @Avg = @CurrencyVal
					
				SET @CurrencyBalance = @CurrencyBalance + @Debit					
			END
		END		
		ELSE IF ((@Debit = 0) AND (@EnParentGUID NOT IN (SELECT EntryGuid FROM TrnCloseCashier000))) -- „»Ì⁄
		BEGIN
			SET @CurrencyBalance = @CurrencyBalance - @Credit 
		END
	
		FETCH NEXT FROM AvgCursor INTO 
			@CurrencyVal, 
			@Debit,
			@credit,
			@DATE,
			@AvgEffect,
			@EnParentGuid
	END  
	CLOSE AvgCursor 
	DEALLOCATE AvgCursor
	DECLARE @CurrentCurrencyVal FLOAT,
			@Ebslon FLOAT
	SELECT @CurrentCurrencyVal = InVal FROM fnTrnGetCurrencyInOutVal(@Currency ,@ToDate)
	SELECT @Ebslon = 0.2
	SELECT @CurrencyBalance = ISNULL(@CurrencyBalance, 0)
	IF (@Avg > @CurrentCurrencyVal * (1 + @Ebslon) OR @Avg < @CurrentCurrencyVal * (1 - @Ebslon))
	BEGIN
		INSERT INTO @Result 
		VALUES	(@CurrentCurrencyVal, @CurrencyBalance, @DATE)
	END
	ELSE
	BEGIN
		INSERT INTO @Result 
		VALUES	(@Avg,	@CurrencyBalance, @DATE)
	END	
RETURN
END
################################################################
CREATE  function FnExchangeGetRegenReocrds
			(
				@DATE DATETIME,
				@CashCurrency	  UNIQUEIDENTIFIER,
				@PayCurrency	  UNIQUEIDENTIFIER 	
			)
returns @result TABLE(Guid UNIQUEIDENTIFIER, DATE DATETIME, CashCurrency NVARCHAR(100), 
			 payCurrency NVARCHAR(100), exType NVARCHAR(255), number INT)		

AS
BEGIN 
INSERT INTO @Result 
SELECT ex.Guid, DATE, CashCurrency, payCurrency, type.[name]  AS TypeName, ex.number
	FROM TrnExchange000 AS ex
	INNER JOIN trneXchangetypes000 AS type ON type.guid = ex.typeguid	
	WHERE 	([DATE] > @DATE )
			AND 
			(CashCurrency = @CashCurrency OR CashCurrency = @PayCurrency OR 
			PayCurrency = @PayCurrency OR	PayCurrency = @PayCurrency)
	ORDER BY DATE
RETURN 
END
##############################################
CREATE FUNCTION FnTrnGetCurrencyCost
		( 
			@Currency UNIQUEIDENTIFIER, 
			@ToDate DATETIME = GetDate, 
			@CostCalcMethod INT = 1, 
			-- -1 BY SytemOption 
			-- 1 CashVal 
			-- 2 AVG 
			@AvgCalcMethod INT = 1 
			-- 1 Avg By TrnCurrencyBalance (For insert) 
			-- 2 Avg Without TrnCurrencyBalance (For update)	 
		) 
	RETURNS @Result TABLE(ISAvgMethod BIT, CurrencyCostVal FLOAT, CurBalance FLOAT, Date DATETIME) 
AS	 
BEGIN  
	IF (@CostCalcMethod = -1) 
	BEGIN 
		-- 2 Ê”ÿÌ, By Avg currency value
		-- 1 ”⁄— ‘—«¡, By cash currency value
		SELECT  
			@CostCalcMethod = CAST(VALUE AS INT) 
		FROM OP000 
		WHERE [NAME] = 'TrnCfg_CostValCalcWay' 
		SELECT @CostCalcMethod = ISNULL(@CostCalcMethod, 1) 
	END 
	IF @CostCalcMethod = 1 
	BEGIN 
		INSERT INTO @Result 
		SELECT  
			0, 
			InVal, 
			0, 
			'1900' 
		FROM fnTrnGetCurrencyInOutVal(@Currency, @ToDate) 
		RETURN  
	END 
	 
	IF (@AvgCalcMethod = 1) 
	BEGIN 
	 
		INSERT INTO @Result 
		SELECT  
			1, 
			CurAvg, 
			CurBalance, 
			Date 
		FROM FnTrnGetCurAverage(@Currency, @ToDate) 
		 
		RETURN  
	END 
	
		INSERT INTO @Result 
		SELECT  
			1, 
			CurAvg, 
			CurBalance, 
			Date 
		FROM FnTrnGetCurAverage2(@Currency, @ToDate) 
		RETURN 
END		 
##############################################
CREATE FUNCTION FnTrnGetSystemCurCostVal
		(
			@Currency UNIQUEIDENTIFIER,
			@ToDate DATETIME = GetDate
		)
	RETURNS FLOAT
AS	
BEGIN 
	
	DECLARE @CostCalcWay INT
	SELECT 
		@CostCalcWay = CAST(VALUE AS INT)
	FROM OP000
	WHERE [NAME] = 'TrnCfg_CostValCalcWay'
	SELECT @CostCalcWay = ISNULL(@CostCalcWay, 1)


	RETURN (SELECT CurrencyCostVal FROM dbo.FnTrnGetCurrencyCost(@Currency, @ToDate, @CostCalcWay, 1))
END
##############################################
CREATE FUNCTION FnTrnGetCostValCalcMethodOption()
	RETURNS INT 
	-- 0 Without profit, 1 Cash, 2 Avg 
AS	 
BEGIN  
	DECLARE @PayCurrencyValMethod INT 

	--  ⁄«œ· ”⁄— «·»Ì⁄
	-- 2 ”⁄— «·„»Ì⁄
	-- 1  ⁄«œ· ”⁄— «·ﬂ·›…
	SELECT  
		@PayCurrencyValMethod = CAST(VALUE AS INT) 
	FROM OP000 
	WHERE [NAME] = 'TrnCfg_PayCurrencyEntryVal' 
	SELECT @PayCurrencyValMethod = ISNULL(@PayCurrencyValMethod, 1) 
		
	IF (@PayCurrencyValMethod = 2)  
	BEGIN
		RETURN 0 -- Without profit
	END

	DECLARE @ResultCalcCostMethod INT		
	-- IF By Cost value
	-- 2 Ê”ÿÌ, By Avg currency value
	-- 1 ”⁄— ‘—«¡, By cash currency value
	SELECT  
		@ResultCalcCostMethod = CAST(VALUE AS INT) 
	FROM OP000 
	WHERE [NAME] = 'TrnCfg_CostValCalcWay' 
	SELECT @ResultCalcCostMethod = ISNULL(@ResultCalcCostMethod, 2) 

	RETURN @ResultCalcCostMethod 
END 
##############################################
CREATE PROC prcTrnInsertTrnCurrencyBalance
	@CurrencyGuid	UNIQUEIDENTIFIER,
	@CurBalance		FLOAT,
	@CurrencyAvg	FLOAT,
	@Date			DATETIME
AS
	DELETE FROM TrnCurrencyBalance000 WHERE Currency = @CurrencyGUID
	INSERT INTO TrnCurrencyBalance000(Currency, CurBalance, CurrencyVal, [Date])
	VALUES(@CurrencyGuid, @CurBalance, @CurrencyAvg, @Date) 			
##############################################
#END