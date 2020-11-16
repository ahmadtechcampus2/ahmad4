##################################################################################
## Added by Huzifa 15-5-2007
CREATE PROCEDURE prcExGenProfitEntry
@EntryGuid UNIQUEIDENTIFIER,
@CurGuid UNIQUEIDENTIFIER,
@ProfitAccount  UNIQUEIDENTIFIER,
@Average  FLOAT(53),
@Profit FLOAT(53) 
AS

SET NOCOUNT ON 

DECLARE	@EntryItemGuid UNIQUEIDENTIFIER,
	@ExchangeGuid UNIQUEIDENTIFIER,
	@CurrencyVal FLOAT(53),
	@NUMBER FLOAT(53),
	@AutoPost Bit,
	@CostGuid UNIQUEIDENTIFIER,
	@CashAcc UNIQUEIDENTIFIER,
	@PayAcc UNIQUEIDENTIFIER,
	@CurrentDate DateTime
	select @CurrentDate = dbo.GetJustDate(GetDate())
SELECT @ExchangeGuid = Guid 
FROM TrnExchange000
WHERE EntryGuid = @EntryGuid

SELECT @AutoPost = bAutoPostEntry , @CostGuid= CostGuid , @ProfitAccount = CASE @ProfitAccount WHEN 0x00 THEN ProfitAccGuid ELSE @ProfitAccount END,
@CurrencyVal = PayCurrencyVal ,@CashAcc = CashAcc , @PayAcc = PayAcc
FROM trnExchangeTypes000 AS ExType  INNER JOIN TrnExchange000 AS Ex ON ExType.guid = ex.typeguid
WHERE EX.Guid = @ExchangeGuid

SELECT @CurGuid = Guid
FROM my000
WHERE CurrencyVal = 1

CREATE TABLE #ExTblEntry(EntryGuid UNIQUEIDENTIFIER,EntryNumber FLOAT(53))

INSERT INTO #ExTblEntry
Exec prcGenExchangeEntry @ExchangeGuid

SELECT TOP 1 @EntryGuid = EntryGuid 
FROM #ExTblEntry

SELECT @NUMBER = ISNULL(MAX(Number),0)+1 
FROM en000 
WHERE parentguid = @EntryGuid

Exec prcDisableTriggers 'ce000'
Exec prcDisableTriggers 'en000'

IF @Profit >  0 
BEGIN 

	SELECT @EntryItemGuid = Guid 
	FROM en000 
	WHERE parentguid = @EntryGuid AND Debit = 0 
	
	UPDATE en000 
	SET Credit = Credit - @Profit , CurrencyVal = @Average
	WHERE Guid = @EntryItemGuid

	INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
			   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
			   CostGUID, ContraAccGUID) 
	VALUES ( 
		@NUMBER, 
		@CurrentDate,
		0,
		@Profit,
		'',
		1,
		@EntryGuid ,
		@ProfitAccount ,
		@CurGuid,
		0x00,
		0x00
		)
	
END
ELSE IF @Profit <  0 
BEGIN	
	SELECT @EntryItemGuid = Guid 
	FROM en000 
	WHERE parentguid = @EntryGuid AND Debit = 0 
	
	UPDATE en000 
	SET Credit = Credit - @Profit , CurrencyVal = @Average
	WHERE Guid = @EntryItemGuid

	INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
			   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
			   CostGUID, ContraAccGUID) 
	VALUES ( 
		@NUMBER, 
		@CurrentDate,
		ABS(@Profit),
		0,
		'',
		1,
		@EntryGuid ,
		@ProfitAccount ,
		@CurGuid,
		0x00,
		0x00
		)
	
END

Exec prcEnableTriggers 'ce000'
Exec prcEnableTriggers 'en000'
################################################################################
#END