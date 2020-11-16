##############################################
CREATE   Function FnTrnGetCashCurAvgFromLast
		( 
			@Guid  uniqueidentifier 
		) 
	RETURNS @Result Table (CurAvg Float, CurBalance Float) 
AS 
Begin 
	Declare @Date DateTime, 
		@CashCurrency  uniqueidentifier, 
		@CashRoundAmount Float, 
		@CashCurrencyVal Float 
	 
	SELECT  
		@Date = Date, 
		@CashCurrency = CashCurrency, 
		@CashRoundAmount = CashRoundAmount, 
		@CashCurrencyVal = CashCurrencyVal  
	FROM TrnExchange000 
	Where Guid = @Guid  
	declare @prev_Guid uniqueidentifier 
	select  
		@prev_Guid = Guid 
	FROM TrnExchange000		 
	WHERE 	 
		(@CashCurrency = CashCurrency OR  @CashCurrency = PayCurrency) 
		AND Date =  
		(select Max(date) from trnexchange000  
			WHERE [Date] < @Date 
		) 
	Declare 
		@prev_Balance FLOAT,  
		@prev_AvgVal FLOAT, 
		@CurBalance FLOAT, 
		@NewAvg FLOAT 
	SELECT  
		@prev_AvgVal =  
		case @CASHCurrency 
			WHEN PayCurrency THEN 
				PayAvgVal 
			ELSE  CashAvgVal 
		end, 
		@prev_Balance =  
		case @CASHCurrency 
			WHEN PayCurrency THEN 
				PayCurBalance 
			ELSE  CashCurBalance 
		end 
	From TrnExchange000 
	Where  
		Guid = @prev_Guid 
	set @prev_Balance = isNull(@prev_Balance , 0) 
	set @prev_AvgVal = isNull(@prev_AvgVal , 0) 
	Set @NewAvg = (@prev_Balance * @prev_AvgVal + @CashRoundAmount * @CashCurrencyVal) 
	Set @NewAvg = @NewAvg / (@prev_Balance + @CashRoundAmount) 
	set @CurBalance =  @prev_Balance + @CashRoundAmount 
	insert into @Result 
	VALUES(@NewAvg, @CurBalance) 
	 
return 
END 
#############################################################
CREATE   Function FnTrnGetPayCurAvgFromLast 
		( 
			@Guid  uniqueidentifier 
		) 
	RETURNS @Result Table (CurAvg Float, CurBalance Float) 
AS 
Begin 
	Declare @Date DateTime, 
		@PayCurrency  uniqueidentifier, 
		@PayRoundAmount Float, 
		@PayCurrencyVal Float 
	 
	SELECT  
		@Date = Date, 
		@PayCurrency = PayCurrency, 
		@PayRoundAmount = PayRoundAmount, 
		@PayCurrencyVal = payCurrencyVal  
	FROM TrnExchange000 
	Where Guid = @Guid  
	declare @prev_Guid uniqueidentifier 
	select  
		@prev_Guid = Guid 
	FROM TrnExchange000		 
	WHERE 	 
		(@PayCurrency = CashCurrency OR  @PayCurrency = PayCurrency) 
		AND Date =  
		(select Max(date) from trnexchange000  
			WHERE [Date] < @Date 
		) 
	Declare 
		@prev_Balance FLOAT,  
		@prev_AvgVal FLOAT, 
		@CurBalance FLOAT, 
		@NewAvg FLOAT 
	SELECT  
		@prev_AvgVal =  
		case @PayCurrency 
			WHEN PayCurrency THEN 
				PayAvgVal 
			ELSE  CashAvgVal 
		end, 
		@prev_Balance =  
		case @PayCurrency 
			WHEN PayCurrency THEN 
				PayCurBalance 
			ELSE  CashCurBalance 
		end 
	From TrnExchange000 
	Where  
		Guid = @prev_Guid 
	set @prev_Balance = isNull(@prev_Balance , 0) 
	set @prev_AvgVal = isNull(@prev_AvgVal , 0) 
	 
	Set @NewAvg = @prev_AvgVal 
	set @CurBalance =  @prev_Balance - @PayRoundAmount 
	if (@CurBalance < 0) 
		set @CurBalance = 0 
	insert into @Result 
	VALUES(@NewAvg, @CurBalance) 
	 
return 
END 
###################################
#END