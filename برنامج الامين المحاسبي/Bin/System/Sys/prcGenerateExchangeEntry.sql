##########################################################
CREATE  PROC prcGenExchangeEntryAvg
	@exchangGuid UNIQUEIDENTIFIER,
	/*
		1 Add new Exchange
		2 Update old Exchange
		3 Maintain Exchange 
	*/
	@OperationType INT = 1,
	@CalcCostMethod INT = 0,
	/*
		-1  By System Option
		0 without calc profit
		1 Cash Val
		2 AVG
	*/
	@UserGuid UNIQUEIDENTIFIER = 0x0
AS
	SET NOCOUNT ON

	DECLARE @BranchGuid UNIQUEIDENTIFIER ,
		@entryNum INT ,
		@defaultCur UNIQUEIDENTIFIER ,
		@OldEntryGuid UNIQUEIDENTIFIER,
		@OldCostGuid		UNIQUEIDENTIFIER,
		@payCurrency UNIQUEIDENTIFIER,
		@Date	DateTime,
		@defCurr  UNIQUEIDENTIFIER,
		@CreateDate DateTime,
		@CreateUserGuid UNIQUEIDENTIFIER
	
	SELECT @OldEntryGuid = EntryGuid, @BranchGuid = BranchGuid, 
		@payCurrency = payCurrency, @date = [date]
	FROM trnExchange000 
	WHERE GUID = @exchangGuid
	
	IF (IsNull(@OldEntryGuid, 0x0) = 0x0)
		SET @entryNum = [dbo].[fnEntry_getNewNum](@BranchGUID)		
	else
	begin
		SELECT top 1
			@entryNum = ce.number,
			@CreateDate=CE.CreateDate, 
			@CreateUserGuid=CE.CreateUserGUID,
			@OldcostGuid = en.costGuid
		FROM 
			ce000 ce
			INNER JOIN en000 en on en.ParentGUID = ce.GUID
		where 
			ce.guid = @OldEntryGuid
			AND en.CostGuid <> 0x0
		--update ce000 set isPosted = 0  where guid = @OldEntryGuid
		Exec prcDisableTriggers 'ce000'
		Exec prcDisableTriggers 'en000'
			delete from er000 where entryguid =  @OldEntryGuid
			delete from ce000 where guid =  @OldEntryGuid
			delete from en000 where parentguid =  @OldEntryGuid
		Exec prcEnableTriggers 'ce000'
		Exec prcEnableTriggers 'en000'

	end
	
	SET @entryNum = ISNULL(@entryNum, 0)

	IF (@entryNum = 0 OR EXISTS (SELECT * FROM CE000 WHERE NUMBER = @entryNum AND Branch = @BranchGUID))
		SET @entryNum = [dbo].[fnEntry_getNewNum](@BranchGUID)		

	SELECT @defCurr = guid FROM my000 WHERE currencyval = 1
	IF (@payCurrency = @defCurr)
		EXEC prcGenExchangeEntry1 @exchangGuid, @entryNum, @UserGuid, @OldCostGuid
	ELSE
	BEGIN
		-- option
		IF (@CalcCostMethod = -1)
		BEGIN
			SELECT @CalcCostMethod = dbo.FnTrnGetCostValCalcMethodOption()
		END
		IF (@CalcCostMethod = 0)
			EXEC prcGenExchangeEntry1 @exchangGuid, @entryNum, @UserGuid, @OldCostGuid
		ELSE
		BEGIN 
			DECLARE @CalcAvgMethod INT
			-- ≈÷«›…
			IF (@OperationType = 1) 
				SELECT  @CalcAvgMethod = 1
			ELSE
			--  ⁄œÌ·
			IF (@OperationType = 2) 
				SELECT  @CalcAvgMethod = 2
			ELSE
			-- ’Ì«‰…
			IF (@OperationType = 3)
				SELECT  @CalcAvgMethod = 1
				
			DECLARE @IsAvgMethd			BIT,
					@CurrencyCostVal	FLOAT,
					@CurBalance			FLOAT,
					@LastDate			DATETIME
			SELECT
					@IsAvgMethd = ISAvgMethod,
					@CurrencyCostVal = CurrencyCostVal,
					@CurBalance = CurBalance,
					@LastDate = Date
			FROM FnTrnGetCurrencyCost(@payCurrency, @DATE, @CalcCostMethod, @CalcAvgMethod)						
			
			IF (ISNULL(@CurrencyCostVal, 0) = 0)
			BEGIN
				EXEC prcGenExchangeEntry1 @exchangGuid, @entryNum, @UserGuid, @OldCostGuid
			END	
			ELSE
			BEGIN
				
				EXEC prcGenExchangeEntry2 @exchangGuid, @entryNum, @CurrencyCostVal, @UserGuid, @OldcostGuid
				IF (@IsAvgMethd = 1)
					EXEC prcTrnInsertTrnCurrencyBalance @payCurrency, @CurBalance, @CurrencyCostVal, @LastDate
			END	
		END
	END
	DECLARE @entryGuid UNIQUEIDENTIFIER

	SELECT @entryGuid=ce.GUID FROM ce000 ce 
		inner join trnExchange000 te on ce.GUID=te.EntryGuid
	WHERE te.Guid = @exchangGuid

	UPDATE [ce000] SET 
	CreateDate =
		CASE WHEN @OperationType = 2 THEN  @CreateDate ELSE GETDATE() END,
	CreateUserGUID =
		CASE WHEN @OperationType = 2 THEN  @CreateUserGuid ELSE [dbo].[fnGetCurrentUserGUID]() END,
	LastUpdateDate = 
		CASE WHEN @OperationType = 2 THEN  GETDATE() ELSE LastUpdateDate END,
	LastUpdateUserGUID =
		CASE WHEN @OperationType = 2 THEN  [dbo].[fnGetCurrentUserGUID]() ELSE LastUpdateUserGUID END
	WHERE Guid = @entryGUID  
##############################################################
CREATE  PROC prcGenExchangeEntryFifo
	@exchangGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	DECLARE		@CeDate DateTime,
			@PayCurrency UNIQUEIDENTIFIER,
			@CashCurrency UNIQUEIDENTIFIER,
			@PayCurrencyVal FLOAT,
			@CashCurrencyVal FLOAT,
			@bAutoContraAcc BIT,
			@AutoPostEntry BIT , 
			@CostGuid UNIQUEIDENTIFIER ,
			@CashAcc UNIQUEIDENTIFIER,
			@PayAcc UNIQUEIDENTIFIER,
			@RoundAcc UNIQUEIDENTIFIER,
			@RoundValue FLOAT ,
			@IsDebitRound BIT,
			@SellsAcc UNIQUEIDENTIFIER,
			@SellsCostAcc UNIQUEIDENTIFIER,
			@BranchGuid UNIQUEIDENTIFIER
			
	SELECT @PayCurrencyVal = ex.PayCurrencyVal, @CashCurrencyVal = ex.CashCurrencyVal,
		@CashCurrency = cashCurrency, @payCurrency = payCurrency,	
		@bAutoContraAcc = bAutoContraAcc ,   @AutoPostEntry = bAutoPostEntry ,
		@CostGuid = CostGuid , @CashAcc = CashAcc , @PayAcc = PayAcc ,
		@RoundAcc = RoundAccGuid , @RoundValue = RoundValue , @IsDebitRound = RoundDir,
		@SellsAcc = SellsAcc, @SellsCostAcc = SellsCostAcc,
		@CeDate = dbo.GetJustDate(ex.Date), @BranchGuid = branchguid 
		
	FROM TrnExchangeTypes000 AS t 
	INNER JOIN trnExchange000 AS ex ON t.guid = ex.typeguid
	INNER JOIN trnCurrencyAcc000 as curAcc	ON CurAcc.TypeGuid = t.Guid 
		AND ex.payCurrency = CurAcc.CurrencyGuid
	WHERE ex.guid = @exchangGuid ;		

	EXEC  prcDisableTriggers 'ce000'
	EXEC  prcDisableTriggers 'en000'

	DECLARE @entryNum INT ,
		@entryGuid UNIQUEIDENTIFIER ,
		@defCurrency UNIQUEIDENTIFIER ,
		@OldEntryGuid UNIQUEIDENTIFIER
		
	create table #curfifo(CurrAmount float, val float, sequenc int)
	set @EntryNum = [dbo].[fnEntry_getNewNum](@BranchGuid)
	
	SET @entryGuid = newid() 
	SELECT @defCurrency = guid 
	FROM my000 WHERE CurrencyVal = 1 

	select *
	into #rec
	From trnExchange000 where Guid = @exchangGuid

	if (@cashcurrency <> @defCurrency)
	BEGIN
		insert into TrnCurrencyFifo000 
		select newid(), cashCurrency, cashCurrencyval, cashamount / cashCurrencyval, [date]
		from #rec
	END	

	-- insert entry header 
	INSERT INTO ce000(Type, Number, Date, Debit, Credit,
			  Notes, CurrencyVal, IsPosted, Security, Branch, GUID, CurrencyGUID)     
	SELECT 	1,@entryNum, @CeDate,
		CashAmount,CashAmount,Note,1,@AutoPostEntry,security,branchGuid,@entryGuid,@defCurrency
	FROM #rec 
	

	INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
		   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
		   CostGUID, ContraAccGUID) 
	  SELECT   0 , @CeDate,
		   CASE @isDebitRound WHEN 1 THEN CashAmount ELSE CashAmount + (@RoundValue*CashCurrencyVal) END ,
		   0,
		   Note,
		   CashCurrencyVal, 
		   @entryGUID ,
		   @CashAcc,
		   CashCurrency, 
		   @CostGuid,
		   CASE @bAutoContraAcc WHEN 0 THEN 0x00 ELSE @PayAcc END 
	   FROM #rec 
	
	if (@paycurrency <> @defCurrency)
	BEGIN
	declare @curamount float
	select @curamount = (payamount / PayCurrencyVal) from #rec	
	insert into  #curfifo
	exec trnGetCurrencyFifio @paycurrency, @curamount, @PayCurrencyVal

	INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
		   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
		   CostGUID, ContraAccGUID) 
	  SELECT   
		   sequenc, 
		   @CeDate,
		   0,
		   f.CurrAmount * f.Val,
		   ' ',
		   f.val,
		   @entryGUID ,
		   @PayAcc,
		   @Paycurrency, 
		   @CostGuid,
		   CASE @bAutoContraAcc WHEN 0 THEN 0x00 ELSE @CashAcc END 
	   FROM #curfifo as f
	

	declare @lstSeq int, @SumCredit Float 
	select @lstSeq = max(sequenc) + 1 from #curfifo
	select @SumCredit = sum(CurrAmount * val) from #curfifo

	INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
		   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
		   CostGUID, ContraAccGUID) 
 	SELECT 	 
		  @lstSeq,
		  @CeDate,	
		  0, 
		  cashAmount, -- or  
		  Note,
		  cashCurrencyval, -- or 1
		  @entryGUID,
		  @SellsAcc,
		  CashCurrency,
		  @CostGuid,
		  CASE @bAutoContraAcc WHEN 0 THEN 0x00 ELSE @SellsCostAcc END 

	   FROM #rec


	INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
		   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
		   CostGUID, ContraAccGUID) 
 	SELECT 	 
		  @lstSeq + 1,
		  @CeDate,	
		  @SumCredit, 
		  0, -- or  
		  Note,
		  cashCurrencyval, -- or 1
		  @entryGUID,
		  @SellsCostAcc,
		  CashCurrency,
		  @CostGuid,
		  CASE @bAutoContraAcc WHEN 0 THEN 0x00 ELSE @SellsAcc END 
	   FROM #rec
	end
	else
	INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
		   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
		   CostGUID, ContraAccGUID) 
		SELECT 	  1 , @CeDate,  0,
		  CASE @isDebitRound WHEN 1 THEN PayAmount + (@RoundValue*PayCurrencyVal) ELSE PayAmount END,
		  Note,
		  PayCurrencyVal, 
		  @entryGUID ,
		  @PayAcc,
		  PayCurrency, 
		  @CostGuid,
		  CASE @bAutoContraAcc WHEN 0 THEN 0x00 ELSE @CashAcc END  
	FROM #rec	

	IF @RoundValue != 0	
	BEGIN

	DECLARE @Debit float
	DECLARE @credit float
	
	IF (@isDebitRound = 1)
	begin
		if (@RoundValue > 0)
		begin
			SET @Debit = @RoundValue * @PayCurrencyVal
			SET @Credit = 0
		end
		else
		begin
			SET @Debit = 0
			SET @Credit = @RoundValue * -1 * @PayCurrencyVal
		end
	end
	else
	begin
		if (@RoundValue > 0)
		begin
			SET @Debit = 0
			SET @Credit = @RoundValue * @CashCurrencyVal
		end
		else
		begin
			SET @Debit = @RoundValue * -1 * @CashCurrencyVal
			SET @Credit = 0
		end
	end

	INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
		   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
		   CostGUID, ContraAccGUID)
	SELECT 	  4 ,
		  @CeDate,
		@Debit,	--CASE @isDebitRound WHEN 1 THEN @RoundValue * PayCurrencyVal ELSE 0 END,
		@Credit,	--CASE @isDebitRound WHEN 0 THEN @RoundValue * PayCurrencyVal ELSE 0 END,
		Note,
		CASE @isDebitRound when 1 THEN PayCurrencyVal ELSE CashCurrencyVal End, 
		@entryGUID,
		@RoundAcc,
		CASE @isDebitRound when 1 THEN PayCurrency ELSE CashCurrency END,
		@CostGuid,	
		CASE @bAutoContraAcc WHEN 0 THEN 0x00 ELSE CASE @isDebitRound WHEN 1 THEN @PayAcc ELSE @CashAcc END END   
	   FROM #rec--trnExchange000  
 	   --WHERE GUID = @exchangGuid		   
	 END
	
	DECLARE @exchaneNum INT 
	SELECT @exchaneNum = Number FROM trnExchange000 WHERE guid = @exchangGuid 
	INSERT INTO er000 (EntryGUID, ParentGUID, ParentType, ParentNumber) 
	VALUES(@entryGUID, @exchangGuid , 507 , @exchaneNum )  
    
	UPDATE TrnExchange000 
	SET EntryGuid = @entryGUID
	WHERE guid = @exchangGuid
	
	EXEC prcEnableTriggers 'ce000'
	EXEC prcEnableTriggers 'en000'

	SELECT @entryGUID AS EntryGuid , @entryNum  AS EntryNumber
##############################################################
CREATE  proc trnGetCurrencyFifio 
		 @Currency uniqueidentifier,
		 @AllAmount Float,
		 @payCurrencyVal float
AS
	DECLARE @val 	float,
		@Number int,
		@Amount Float,
		@SubAmount Float,   
		@tempAmount float,
		@Guid UNIQUEIDENTIFIER
	create table #res (Amount Float, val Float, sequenc INT IDENTITY(1,1))
	set @TempAmount = @AllAmount

	declare fifoCursor cursor for 
	SELECT 
		CurrencyVal,
		Amount,
		Guid
	from
		TrnCurrencyFifo000
	where CurrencyGuid = @Currency
	Order By [Date]
	
	Open	fifoCursor
	fetch next from fifoCursor
	into 	
		@Val,
		@Amount,
		@Guid
		WHILE (@@FETCH_STATUS = 0 AND @AllAmount > 0 )
		BEGIN
			if (@AllAmount	> @Amount)
			BEGIN
				set @AllAmount	= @AllAmount - @Amount

				insert into #res(Amount, Val)	
				Values(@Amount, @val)

				Delete from TrnCurrencyFifo000 Where Guid = @Guid 				
			END
			ELSE
			BEGIN
				update  TrnCurrencyFifo000 
				set Amount = @Amount - @AllAmount 
				Where Guid = @Guid 	
							
				insert into #res(Amount, Val)	
				Values(@AllAmount, @val)
				
				set @AllAmount	= 0
			END					
			fetch next from fifoCursor
			into 
			@Val,
			@Amount,
			@Guid			
		End
	CLOSE fifoCursor
	DEALLOCATE fifoCursor 


	if (@AllAmount > 0)
	BEGIN 
		insert into #res(Amount, Val)	
		Values(@AllAmount, @payCurrencyVal)
	END		
	select Amount, val, sequenc from #res order by sequenc
################################################################
CREATE PROCEDURE prcTrnCancelExchange
	@ExchangeGuid	UNIQUEIDENTIFIER,
	@Note			NVARCHAR(50) = ''
AS
/*
Result:
	0- no entry generated for the exchange statement to cancel it
	1- there is already a cancellation entry related to the exchange statement
	2- entry generated successfully!
*/
	SET NOCOUNT ON
	
	DECLARE @CeGuid		UNIQUEIDENTIFIER,
			@NewCeGuid	UNIQUEIDENTIFIER,
			@NewCeNum	INT

	SELECT	@CeGuid		= EntryGuid FROM TrnExchange000 WHERE Guid = @ExchangeGuid

	IF EXISTS (SELECT ac.GUID FROM vwAcCu ac INNER JOIN en000 en ON en.AccountGUID = ac.GUID WHERE en.ParentGUID = @CeGuid AND  CustomersCount > 1)
	BEGIN 
		DECLARE @AccountGUID UNIQUEIDENTIFIER;
		SELECT TOP 1 @AccountGUID = ac.GUID FROM vwAcCu ac INNER JOIN en000 en ON en.AccountGUID = ac.GUID WHERE en.ParentGUID = @CeGuid AND CustomersCount > 1

		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT 1, 0, 'AmnE0052: [' + CAST(@AccountGUID AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
		RETURN
	END 
	SELECT	@NewCeNum	= MAX(Number) + 1 from ce000
	SET		@NewCeGuid	= NEWID()
	IF @Note = ''
		SET @Note = '≈·€«¡ ⁄„·Ì… '

	IF ISNULL(@CeGuid, 0x0) = 0x0
	BEGIN
		SELECT 0x0 AS CancelEntryGuid, 0 AS Result
		RETURN
	END

	IF EXISTS(SELECT * FROM TrnExchange000 WHERE Guid = @ExchangeGuid AND CancelEntryGuid <> 0x0)
	BEGIN
		SELECT CancelEntryGuid, 1 AS Result
		FROM 
			TrnExchange000 AS ex
			INNER JOIN ce000 AS ce ON ce.Guid = ex.CancelEntryGuid
		WHERE ex.Guid = @ExchangeGuid
		RETURN
	END

	-- Generate exchange cancel entry
	BEGIN TRANSACTION ['Generate_cancel_entry']
		INSERT INTO ce000
			(Type, Number,	Date, Debit, Credit, Notes, CurrencyVal, IsPosted, State, Security, Num1, Num2, Branch, GUID, CurrencyGUID, TypeGUID, IsPrinted, PostDate)
		SELECT 
			Type, @NewCeNum, GETDATE(), Debit, Credit, @Note + Notes, CurrencyVal, 0, State, Security, Num1, Num2, Branch, @NewCeGuid, CurrencyGUID, TypeGUID, 0, GETDATE()
		FROM 
			ce000 
		WHERE Guid = @CeGuid
		------------------------
		INSERT INTO en000
			(Number, Date, Debit, Credit, Notes, CurrencyVal, Class, Num1, Num2, Vendor, SalesMan, GUID, ParentGUID, AccountGUID, CurrencyGUID, CostGUID, ContraAccGUID, AddedValue, ParentVATGuid, BiGUID, CustomerGUID)
		select 
			Number, GETDATE(), Credit, Debit, @Note + Notes, CurrencyVal, Class, Num1, Num2, Vendor, SalesMan, NEWID(), @NewCeGuid, AccountGUID, CurrencyGUID, CostGUID, ContraAccGUID, AddedValue, ParentVATGuid, BiGUID, CustomerGUID
		From 
			en000 
		where parentGuid = @CeGuid
		-------------------------
		UPDATE ce000 SET IsPosted = (SELECT Isposted FROM ce000 WHERE guid = @CeGuid)
		WHERE Guid = @NewCeGuid
		--------------------------
		INSERT INTO er000 
			(GUID, EntryGUID, ParentGUID, ParentType, ParentNumber)
		SELECT
			NEWID(), @NewCeGuid, @ExchangeGuid, ParentType, ParentNumber
		FROM er000 
		WHERE entryGuid = @CeGuid
		--***********************************
		Update TrnExchange000 
		SET CancelEntryGuid = @NewCeGuid
		WHERE Guid = @ExchangeGuid
	COMMIT TRANSACTION ['Generate_cancel_entry']

	SELECT @NewCeGuid AS CancelEntryGuid, 2 AS Result
################################################################
CREATE PROC prcCheckExchangeConditions
	@ExchangeGuid	UNIQUEIDENTIFIER,
	@IsModify		bit = 0
AS
	SET NOCOUNT ON

	Declare
		@CustomerGuid	UNIQUEIDENTIFIER,
		@Date			Date,
		@ExchangeValue	float,
		@FromDate	DATE,
		@ToDate		DATE,
		@ProcessCnt	INT,
		@LinkOption	INT,
		@TotalAllowedAmounts FLOAT,
		@Result		INT = 0,
		@Count		INT,
		@PayCurrency	UNIQUEIDENTIFIER
	SELECT 
		@CustomerGuid = CustomerGuid,
		@Date			= Date,
		@ExchangeValue	=  (PayAmount/ PayCurrencyVal),
		@PayCurrency	= PayCurrency
	FROM 
		TrnExchange000
	WHERE 
		Guid = @ExchangeGuid
	
	SELECT 
		@FromDate	= FromDate,
		@ToDate		= ToDate,
		@ProcessCnt	= ProcessCnt,
		@LinkOption	= LinkOption,
		@TotalAllowedAmounts = TotalAllowedAmounts
	FROM 
		ExchangeProcessConditions000 
	Where 
		@Date BETWEEN FromDate AND ToDate
		AND MyGuid = @PayCurrency
	ORDER BY 
		Number
	IF ISNULL(@CustomerGuid, 0x0) = 0x0
		OR NOT Exists(select * FROM ExchangeProcessConditions000 Where @Date BETWEEN FromDate AND ToDate)
	BEGIN
		SELECT 0 AS Result
		RETURN
	END
	SELECT 
		@Count = COUNT(*)
	FROM 
		TrnExchange000
	WHERE
		CustomerGuid = @CustomerGuid
		AND Date between @FromDate AND DATEADD(day,1,@ToDate)
		AND (Guid <> @ExchangeGuid OR @IsModify = 0)
		AND PayCurrency = @PayCurrency
		AND CancelEntryGuid = 0x0
	SET @Count = ISNULL(@Count, 0)
	
	
	IF @LinkOption = 1 AND (@Count > @ProcessCnt) OR @ExchangeValue > @TotalAllowedAmounts
	BEGIN
		if (@Count > @ProcessCnt AND @ProcessCnt <> 0)
			SET @Result += 1
		if @ExchangeValue > @TotalAllowedAmounts
			SET @Result += 2
	END

	ELSE IF (@LinkOption = 2 AND (@Count > @ProcessCnt OR ((SELECT SUM(PayAmount/ PayCurrencyVal) FROM TrnExchange000
		WHERE CancelEntryGuid = 0x0 AND CustomerGuid = @CustomerGuid AND PayCurrency = @PayCurrency
		AND (Date between @FromDate AND DATEADD(day,1,@ToDate))) > @TotalAllowedAmounts)))
	BEGIN
		IF @Count > @ProcessCnt AND @ProcessCnt <> 0
			SET @Result += 1
		if ((SELECT SUM(PayAmount/ PayCurrencyVal) FROM TrnExchange000
		WHERE CancelEntryGuid = 0x0 AND CustomerGuid = @CustomerGuid AND PayCurrency = @PayCurrency
		AND (Date between @FromDate AND DATEADD(day,1,@ToDate))) > @TotalAllowedAmounts)
		
			SET @Result += 2
	END
	SELECT @Result Result
################################################################
#END