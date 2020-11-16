##########################################################
CREATE   proc prcTrnStoreCurBalanceAvg
	@ExchangeGuid uniqueidentifier 
AS 
	DECLARE @PayCuravg float, @PayCurBalance float, 
		@CashCuravg float, @CashCurBalance float 
	SELECT 
		@PayCuravg = curavg, 
		@PayCurBalance = CurBalance 
	From FnTrnGetpayCurAvgFromLast(@ExchangeGuid) 
	 
	if (IsNull(@PayCuravg, 0) = 0) 
		select @PayCuravg = 1, @PayCurBalance = 0 
	SELECT 
		@CashCuravg = curavg, 
		@CashCurBalance = CurBalance 
	From FnTrnGetCashCurAvgFromLast(@ExchangeGuid)
	
	if (IsNull(@CashCuravg, 0) = 0) 
		select @CashCuravg = CashCurrencyVal, @CashCurBalance = CASHRoundAmount 
		From TrnExchange000 
		Where Guid = @ExchangeGuid	 
	
	update TrnExchange000 
	set CashCurBalance = @CashCurBalance, CashAvgVal = @CashCuravg, 
		PayAvgVal = @PayCuravg, PayCurBalance = @PayCurBalance 
	Where Guid = @ExchangeGuid
########################################################
CREATE   proc prcTrnStoreAllCurBalanceAvg 
AS 
	declare @GUID  uniqueidentifier 
	DECLARE AvgCursor CURSOR FORWARD_ONLY FOR   
	select  
		Guid 
	From TrnExchange000 
	order by date 
	OPEN AvgCursor  
	FETCH NEXT FROM AvgCursor INTO  
			@Guid 
	WHILE @@FETCH_STATUS = 0  
	BEGIN   
		exec prcTrnStoreCurBalanceAvg @Guid	 
		FETCH NEXT FROM AvgCursor INTO  
			@Guid 
	END   
	CLOSE AvgCursor  
	DEALLOCATE AvgCursor
######################################################
#END