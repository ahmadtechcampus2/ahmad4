###################################################
CREATE  proc prcTrnStore_CashBalance
		@Currency uniqueidentifier,
		@Amount Float, 
		@CurrencyVal Float				
AS

	--IF NOT EXISTS (SELECT * FROM TrnCurrencyBalance000 where Currency = @Currency)
		--insert into TrnCurrencyBalance000 (Currency, Balance, CurrencyVal, Date)
		--values(@Currency, @Amount, @CurrencyVal, GetDate()) 

--else	
--BEGIN
	--DECLARE @Balance float,
		--@avg float	

	--select 
		--@Balance = balance,
		--@avg = CurrencyVal
	--from TrnCurrencyBalance000
	--where Currency = @Currency

	--if (@Balance = 0 or @avg = 0)
		--UPDATE TrnCurrencyBalance000
		--set 
			--balance = @Amount,
			--CurrencyVal = @CurrencyVal
		--where Currency = @Currency
	--else	
	--BEGIN	

		--declare @newAvg float,
			--@newBalance float

		--select @newBalance = @Balance + @Amount
		--select @newAvg = @newBalance / ((@Balance / @avg) + (@Amount / @CurrencyVal))
		
		--UPDATE TrnCurrencyBalance000
		--set 
			--balance = @newBalance,
			--CurrencyVal = @newAvg
		--where Currency = @Currency
	--end
--END
##########################################
CREATE  proc prcTrnStore_PayBalance
		@Currency uniqueidentifier,
		@Amount Float, 
		@CurrencyVal Float				
AS
--SET NOCOUNT ON		
	--IF NOT EXISTS (SELECT * FROM TrnCurrencyBalance000 where Currency = @Currency)
		--insert into TrnCurrencyBalance000 (Currency, Balance, CurrencyVal, Date)
		--values(@Currency, 0, @CurrencyVal, GetDate()) 
--else
--BEGIN
	--Declare @Balance float,
		--@avg float,
		--@NewBalance Float

	--select @Balance = Balance, @Avg =  CurrencyVal
	--From TrnCurrencyBalance000 where Currency = @Currency

	--select @NewBalance = (@Balance / @Avg) - (@Amount / @CurrencyVal)
	--select @NewBalance = @NewBalance * @avg
	--if (@NewBalance < 0) 
	--set @NewBalance = 0
	--update TrnCurrencyBalance000
	--set Balance = @NewBalance
	--where Currency = @Currency
--END


#######################################
CREATE   proc prcTrnStore_CurrencyBlanace
	@ExchangeGuid uniqueidentifier
as
SET NOCOUNT ON
--Declare @CashCurrency uniqueidentifier,
	--@CashAmount Float,
	--@CashCurrencyVal float,		

	--@payCurrency uniqueidentifier,
	--@payAmount float,
	--@PayCurrencyVal	float			

--select 
	--@CashCurrency = CashCurrency,
	--@CashAmount = CashAmount,
	--@CashCurrencyVal = CashCurrencyVal,
	--@payCurrency = PayCurrency,
	--@payAmount = payAmount,
	--@PayCurrencyVal = PayCurrencyVal
--From TrnExchange000 where Guid = @ExchangeGuid

	--exec prcTrnStore_CashBalance @CashCurrency, @CashAmount, @CashCurrencyVal
	--exec prcTrnStore_PayBalance @payCurrency, @payAmount, @PayCurrencyVal
#######################################
CREATE  PROC prcTrnStore_CurrencyBlanaceDetail
	@ExchangeGuid uniqueidentifier
as
	Declare @Currency uniqueidentifier,
		@CurrencyVal float,
		@Amount float,
		@Type int

	DECLARE cur CURSOR FORWARD_ONLY FOR  
	select 
		CurrencyGuid,
		CurrencyVal,
		Amount, 
		Type
	From TrnExchangeDetail000 
	where ExchangeGuid = @ExchangeGuid
	Order by type	

	OPEN cur
	FETCH NEXT FROM cur INTO 
		@Currency,
		@CurrencyVal,
		@Amount,
		@Type
	WHILE @@FETCH_STATUS = 0 
	BEGIN  
		if (@type = 0)
			exec prcTrnStore_CashBalance @Currency, @Amount, @CurrencyVal
		else
			exec prcTrnStore_PayBalance @Currency, @Amount, @CurrencyVal

		FETCH NEXT FROM cur INTO 
			@Currency,
			@CurrencyVal,
			@Amount,
			@Type

	END  
	CLOSE cur 
	DEALLOCATE cur
#######################################
#END