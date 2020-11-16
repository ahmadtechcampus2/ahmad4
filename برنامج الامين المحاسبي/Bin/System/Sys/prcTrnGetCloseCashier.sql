######################################################################################
CREATE  PROCEDURE trnGetCloseCashier
	@ExchangeType	[UNIQUEIDENTIFIER],
	@CurrencyGuid  	[UNIQUEIDENTIFIER] = 0x0
AS    
	SET NOCOUNT ON     
	DECLARE			@acc_cur	CURSOR,   
				@curr_cur	CURSOR,   
				@class_cur	CURSOR,   
				@AccGuid 	[UNIQUEIDENTIFIER],   
				@CurGuid 	[UNIQUEIDENTIFIER],
				@CostGuid 	[UNIQUEIDENTIFIER],
				@LastDate   	DATETIME
			   
	CREATE TABLE [#Result](     
				[Account] [UNIQUEIDENTIFIER],     
				[AccName] [NVARCHAR]( 255) COLLATE ARABIC_CI_AI,    
				[Currency] [UNIQUEIDENTIFIER],     
				[CurName] [NVARCHAR]( 255) COLLATE ARABIC_CI_AI,    
				[CurNumber] [BIGINT],    
				[CurrencyVal] [FLOAT],    
				[Balance] [FLOAT])  

	SET @acc_cur = CURSOR FAST_FORWARD FOR     
				SELECT     
					[AccountGUID], [CurrencyGUID], t.[CostGuid]    
				FROM    
					[TrnCurrencyAcc000]as ac 
					inner join TrnExchangeTypes000 as t on t.guid = ac.typeguid
				WHERE     
					[TypeGUID] = @ExchangeType  
					AND
					(@CurrencyGuid = 0x0 OR @CurrencyGuid = [CurrencyGUID])
       
	OPEN @acc_cur FETCH FROM @acc_cur INTO  @AccGuid, @CurGuid, @CostGuid     
	WHILE @@FETCH_STATUS = 0     
	BEGIN    
		IF(@AccGuid <> 0x0) AND (@CurGuid <> 0x0)   
		BEGIN    

		Declare @PayAmount Float, @CashAmount Float, @Balance Float			
		
		select
			@PayAmount = Sum(Credit),
			@CashAmount = Sum(Debit) 
		From TrnFnGetCurrencyEntries(@CurGuid, @AccGuid, @CostGuid,'','2100')   			
	
		SELECT @Balance = @CashAmount - @payAmount 

		insert into #Result
		SELECT 
				@AccGuid, ac.[name],my.guid, my.[name], my.number,
				my.Currencyval,@Balance	
		FROM 
			my000 as my
			inner join  ac000 as ac on ac.guid = @AccGuid
		where my.guid = @CurGuid

		END    
		FETCH FROM @acc_cur INTO  @AccGuid, @CurGuid, @CostGuid
	END    
	CLOSE @acc_cur	DEALLOCATE @acc_cur
	
	SELECT * FROM [#Result]
	order by CurNumber
#########################################################################
#END