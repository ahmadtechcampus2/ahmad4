#######################################
CREATE PROC prcTrnStoreCurrClassDefault
	@ExchangeGuid UNIQUEIDENTIFIER
AS
	DECLARE @PayCur UNIQUEIDENTIFIER, 
		@CashCur UNIQUEIDENTIFIER,
		@payONEclass UNIQUEIDENTIFIER,
		@cashONEclass UNIQUEIDENTIFIER,
		@payVal FLOAT,
		@Cashval FLOAT,
		@Date DATETIME

	SELECT 
		@PayCur = PayCurrency,
		@CashCur = CashCurrency,
		@payVal = PayRoundAmount,
		@Cashval = CashRoundAmount,
		@Date = [Date]

	FROM	TrnExchange000
	WHERE	GUID = @ExchangeGuid 		

	SELECT
		@payONEclass = GUID
	FROM TrnCurrencyClass000 AS c
	WHERE CurrencyGuid = @PayCur AND classVal = 1

	SELECT
		@cashONEclass = GUID
	FROM TrnCurrencyClass000 AS c
	WHERE CurrencyGuid = @CashCur AND classVal = 1	

	IF (not EXists (SELECT guid FROM TrnExchangeCurrClass000 
		WHERE parentGuid = @ExchangeGuid AND TYPE = 0))
	BEGIN
		INSERT INTO TrnExchangeCurrClass000(ParentGuid, ClassGuid,Type, Value, CurGuid, PayValue, Date)
		VALUES(@ExchangeGuid, @payONEclass, 0, @payVal, @PayCur, 0, @Date)

	END	

	IF (not EXists (SELECT guid FROM TrnExchangeCurrClass000 
		WHERE parentGuid = @ExchangeGuid AND TYPE = 1))
	BEGIN
		INSERT INTO TrnExchangeCurrClass000(ParentGuid, ClassGuid,Type, Value, CurGuid, PayValue, Date)
		VALUES(@ExchangeGuid, @CashONEclass, 0, @CashVal, @CashCur, 0, @Date)
	END	
#######################################
#END