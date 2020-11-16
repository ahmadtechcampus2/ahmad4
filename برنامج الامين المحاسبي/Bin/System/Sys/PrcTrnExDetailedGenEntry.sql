###############################################
CREATE PROCEDURE PrcTrnExDetailedGenEntry
	@ExchangeGuid UNIQUEIDENTIFIER,
	/*
		1 Add new Exchange
		2 Update old Exchange
		3 Maintain Exchange 
	*/
	@OperationType INT = 1,
	@CalcCostMethod INT = -1
		/*
		-1  By System Option
		0 without calc profit
		1 Cash Val
		2 AVG
	*/
        
AS  
	SET NOCOUNT ON  

	DECLARE @CostGuid			UNIQUEIDENTIFIER,
			@CashAcc			UNIQUEIDENTIFIER,
			@PayAcc				UNIQUEIDENTIFIER,
			@RoundAcc			UNIQUEIDENTIFIER,
			@defcurrency		UNIQUEIDENTIFIER,
			@OldEntryGUID		UNIQUEIDENTIFIER,
			@entryGuid			UNIQUEIDENTIFIER,
			@RoundCurrency		UNIQUEIDENTIFIER,
			@branchguid			UNIQUEIDENTIFIER,
			@TypeGuid			UNIQUEIDENTIFIER,
			@Date  				DATETIME,
			@PayCurrencyVal		FLOAT, 
			@CashCurrencyVal	FLOAT, 
			@RoundValue			FLOAT,
			@RoundCurrencyVal	FLOAT,
			@Amount				FLOAT, 
			@IsDebitRound		BIT,
			@entryNum			INT,
			@exchaneNum			INT,
			@maxnumber			INT,
			@IsRateDiffrenceAccOption	BIT

	SET @IsRateDiffrenceAccOption = dbo.fnTrnExAccSellOrRateOption()
	IF (ISNULL(@OldEntryGuid, 0x0) = 0x0)
		SET @entryNum = [dbo].[fnEntry_getNewNum](@BranchGUID)		
	ELSE
	BEGIN
		SELECT @entryNum = number FROM ce000 WHERE guid = @OldEntryGuid
		--update ce000 set isPosted = 0  where guid = @OldEntryGuid
		DELETE FROM er000 WHERE entryguid =  @OldEntryGuid
		DELETE FROM ce000 WHERE guid =  @OldEntryGuid
		DELETE FROM en000 WHERE parentguid =  @OldEntryGuid
	END

	SELECT	
			@PayCurrencyVal = PayCurrencyVal, 
			@CashCurrencyVal = CashCurrencyVal, 
			@CostGuid = CostGuid,
			@CashAcc = CashAcc,
			@PayAcc = PayAcc, 
			@RoundAcc = RoundAccGuid,
			@RoundValue = RoundValue,
			@Date = ex.[Date], 
			@RoundCurrency = ex.RoundCurrency,
			@RoundCurrencyVal = ex.RoundCurrencyVal,
			@BranchGuid = ex.branchGuid,
			@TypeGuid = t.guid,
			@exchaneNum = ex.number,
			@OldEntryGUID = ex.EntryGuid
	FROM TrnExchangeTypes000 AS t  
		INNER JOIN trnExchange000 AS ex ON t.guid = ex.typeguid 
	WHERE ex.guid = @ExchangeGuid  
	SELECT	@Amount = SUM(amount) FROM TrnExchangeDetail000 WHERE type = 1 
	SET @entryNum = ISNULL(@entryNum, 0)	
	IF (@entryNum = 0 OR EXISTS (SELECT * FROM CE000 WHERE NUMBER = @entryNum AND Branch = @BranchGUID))
		SET @EntryNum = [dbo].[fnEntry_getNewNum](@BranchGuid)
	
	IF (@entryNum IS NULL)
		SET @entryNum = 1	 
	SET @entryGuid = NEWID()  

	SELECT @defcurrency = GUID FROM my000 WHERE Number = 1  
	
	SELECT *
	INTO #rec FROM trnExchange000 WHERE guid = @ExchangeGuid
	
	EXEC  prcDisableTriggers 'ce000' 
	EXEC  prcDisableTriggers 'en000' 
	 
	INSERT INTO ce000(Type, Number, Date, PostDate, Debit, Credit, Branch,
			  Notes, CurrencyVal, IsPosted, Security,  GUID, CurrencyGUID)      
		SELECT 1, @entryNum, @Date, @Date, @amount, @amount, @branchguid,
			note, 1, 0, Security, @entryguid, @defcurrency
		FROM #rec	
		
	INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes, 
		   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID, 
		   CostGUID, ContraAccGUID)  
	  SELECT 
		d.number,
		@Date,
		Amount,
		0,
		'',
		CurrencyVal,
		@entryGUID,
		AccGuid,
		CurrencyGuid,
		@CostGuid,
		@PayAcc
	   FROM TrnExchangeDetail000 AS d 
 	   WHERE ExchangeGUID = @ExchangeGuid and Type = 0 

	SELECT @maxnumber = @@ROWCOUNT
	-- MAX(Number) + 1 
	--FROM En000
	--WHERE ParentGUID = 
	

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
			
	IF (@CalcCostMethod = -1)
	BEGIN
		SELECT @CalcCostMethod = dbo.FnTrnGetCostValCalcMethodOption()
	END
	

	CREATE TABLE #acc(CurrencyGuid UNIQUEIDENTIFIER, SellsOrProfit_Acc UNIQUEIDENTIFIER, SellsCostOrLose_Acc UNIQUEIDENTIFIER) 

	INSERT INTO #acc
	SELECT 
		D.CurrencyGuid,
		ac.SellsAccGUID,
		ac.SellSCostAccGUID
	FROM TrnExchangeDetail000 AS d
 	INNER JOIN TrnCurrencySellsAcc000 AS ac on ac.CurrencyGuid = d.CurrencyGuid 
	WHERE d.exchangeguid = @ExchangeGuid and d.type = 1 
	
	
	DECLARE @CurrencyGuid			UNIQUEIDENTIFIER,
			@PayAccGuid				UNIQUEIDENTIFIER,
			@SellsOrProfit_Acc		UNIQUEIDENTIFIER,
			@SellsCostOrLose_Acc	UNIQUEIDENTIFIER,
			@CurrencyVal			FLOAT,
			@PayAmount				FLOAT,
			@number					INT
 
	DECLARE SellCur Cursor	 FORWARD_ONLY FOR  
	SELECT 
		det.CurrencyGuid,
		det.AccGuid,
		ac.SellsAccGUID,
		ac.SellSCostAccGUID,
		det.CurrencyVal,		
		det.Amount,
		det.number
	FROM TrnExchangeDetail000 AS det
	INNER JOIN TrnCurrencySellsAcc000 AS ac on ac.CurrencyGuid = det.CurrencyGuid 
	
	WHERE ExchangeGUID = @ExchangeGuid and Type = 1
	ORDER BY Number
	
	open SellCur
	FETCH NEXT FROM SellCur INTO 
			@CurrencyGuid,
			@PayAccGuid, 
			@SellsOrProfit_Acc,
			@SellsCostOrLose_Acc,
			@CurrencyVal,
			@PayAmount,
			@number
		-- „⁄ «·—»Õ
        IF (@CalcCostMethod <> 0)
        BEGIN
			WHILE @@FETCH_STATUS = 0 
			BEGIN
				DECLARE @CostPayAmount		FLOAT,
						@IsAvgMethod		BIT,
						@CurrencyCostVal	FLOAT,
						@CurBalance			FLOAT,
						@LastDate			DATETIME
				SELECT
						@IsAvgMethod = ISAvgMethod,
						@CurrencyCostVal = CurrencyCostVal,
						@CurBalance = CurBalance,
						@LastDate = Date
				FROM FnTrnGetCurrencyCost(@CurrencyGuid, @DATE, @CalcCostMethod, @CalcAvgMethod)		
				
				SET @maxnumber = @maxnumber + 1
				IF (IsNull(@CurrencyCostVal, 0) = 0 OR @CurrencyGuid = @defcurrency)
				BEGIN
					INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
						   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
						   CostGUID, ContraAccGUID) 
					VALUES(	 @maxnumber, @Date, 0,
						  @PayAmount,
						  '',
						  @CurrencyVal, 
						  @entryGUID,
						  @PayAccGuid,
						  @CurrencyGuid,--PayCurrency,
						  @CostGuid,
						  0x0)
				END
				ELSE
				BEGIN
		
					SELECT @CostPayAmount = @CurrencyCostVal * (@PayAmount / @CurrencyVal)
		
					IF (@IsAvgMethod = 1)
						EXEC prcTrnInsertTrnCurrencyBalance @CurrencyGuid, @CurBalance, @CurrencyCostVal, @LastDate

					IF (@IsRateDiffrenceAccOption = 1 OR @SellsOrProfit_Acc = @SellsCostOrLose_Acc)
					BEGIN
							DECLARE @Profit		FLOAT,
									@Lose		FLOAT,
									@Account 	UNIQUEIDENTIFIER
						
						SELECT @Profit = 0, @Lose = 0
						IF (@PayAmount > @CostPayAmount)
						BEGIN
							SET @Profit = @PayAmount - @CostPayAmount
							SET @Account = @SellsOrProfit_Acc
						END	
						ELSE
						BEGIN	
							SET @Lose = @CostPayAmount - @PayAmount
							SET @Account = @SellsCostOrLose_Acc
						END	
						
						INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
							   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
							   CostGUID, ContraAccGUID) 
						VALUES(	 
							  @maxnumber, 
							  @Date, 
							  @Lose,
							  @Profit,
							  '',
							  1, 
							  @entryGUID,
							  @Account,
							  @defcurrency,
							  @CostGuid,
							  0x0
							  )
						
						SET @maxnumber = @maxnumber + 1
					END
					ELSE
					BEGIN
						INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
							   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
							   CostGUID, ContraAccGUID) 
						VALUES(
								@maxnumber,
								@Date, 0,
								@PayAmount,	'',	1, @entryGUID,
								@SellsOrProfit_Acc,	@defcurrency,
								@CostGuid,0x0
							)
			
						SET @maxnumber = @maxnumber + 1
						INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
							   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
							   CostGUID, ContraAccGUID) 
			 			VALUES(
			 					@maxnumber, @Date, 
			 					@CostPayAmount, 0, '', 1, 
			 					@entryGUID, 
			 					@SellsCostOrLose_Acc, 
			 					@defcurrency,
								@CostGuid, 0x0
							)
					END
					
					SET @maxnumber = @maxnumber + 1
					INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
						   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
						   CostGUID, ContraAccGUID) 
					VALUES(
							@maxnumber, @Date,
							0, @CostPayAmount, '',
							@CurrencyCostVal, 
							@entryGUID, 
							@PayAccGuid,
							@CurrencyGuid, 
							@CostGuid, 0x0
						)
				END-- else
		
				FETCH NEXT FROM SellCur INTO 
						@CurrencyGuid,
						@PayAccGuid, 
						@SellsOrProfit_Acc,
						@SellsCostOrLose_Acc,
						@CurrencyVal,
						@PayAmount,
						@number
			END--End WHILE
			
		END-- END IF(@ValType = 1)
        -- »œÊ‰ «·—»Õ
        ELSE --  @ValType = 2
        BEGIN
                WHILE @@FETCH_STATUS = 0
                BEGIN
        	        INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
					            CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
					             CostGUID, ContraAccGUID) 
				    VALUES(@maxnumber, @Date,0, @PayAmount, '',
							@CurrencyVal, @entryGUID, @PayAccGuid,
							@CurrencyGuid, @CostGuid, @cashacc)

                FETCH NEXT FROM SellCur INTO 
					@CurrencyGuid,
					@PayAccGuid, 
					@SellsOrProfit_Acc,
					@SellsCostOrLose_Acc,
					@CurrencyVal,
					@PayAmount,
					@number
                END--END WHILE  
        END-- END  @ValType = 2
	
	CLOSE SellCur 
	DEALLOCATE SellCur

	DECLARE @EntryBalance   FLOAT,
		@SumDebit  FLOAT,
		@SumCredit FLOAT
	
	SELECT 
		@EntryBalance = SUM(Debit) - SUM(Credit)
	FROM 
		EN000 
	WHERE ParentGUID = @entryGUID

	
	SELECT @maxnumber = @maxnumber + 1
	--IF @RoundValue != 0	 
	IF (@EntryBalance != 0)
	BEGIN 
		DECLARE @Debit FLOAT 
		DECLARE @credit FLOAT 
	 	
		IF (@EntryBalance > 0)
		BEGIN
			SET @Debit = 0
			SET @credit = @EntryBalance
		END
		ELSE
		BEGIN
			SET @Debit = -1 * @EntryBalance
			SET @credit = 0	
		END	
		INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes, 
			   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID, 
			   CostGUID, ContraAccGUID) 
		SELECT 	  @maxnumber , @Date, 
			@Debit, 
			@Credit,
			Note, 
			RoundCurrencyVal,
			@entryGUID, 
			@RoundAcc, 
			RoundCurrency,
			@CostGuid,	 
			CASE @isDebitRound WHEN 1 THEN @PayAcc ELSE @CashAcc END
		   FROM trnExchange000   
	 	   WHERE GUID = @ExchangeGuid		    
	 END 
	
	INSERT INTO er000 (EntryGUID, ParentGUID, ParentType, ParentNumber) 
	VALUES(@entryGUID, @ExchangeGuid , 507 , @exchaneNum )  

	UPDATE TrnExchange000  
	SET EntryGuid = @entryGUID 
	WHERE guid = @ExchangeGuid 
	 
	update ce000 SET isposted = 1 
	WHERE guid = @entryguid 

	EXEC prcEnableTriggers 'ce000' 
	EXEC prcEnableTriggers 'en000' 

	SELECT @entryGUID AS EntryGuid , @entryNum  AS EntryNumber 
###################################
#END

