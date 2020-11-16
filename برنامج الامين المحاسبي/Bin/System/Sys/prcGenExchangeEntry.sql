############################################################
CREATE PROC prcGenExchangeEntry1 
	@exchangGuid UNIQUEIDENTIFIER, 
	@EntryNum int,
	@UserGuid UNIQUEIDENTIFIER = 0x0,
	@OldCostGuid UNIQUEIDENTIFIER = 0x0
AS 
	DECLARE	@CostGuid		UNIQUEIDENTIFIER,
		@CashAcc			UNIQUEIDENTIFIER,
		@PayAcc				UNIQUEIDENTIFIER,
		@RoundAcc			UNIQUEIDENTIFIER,
		@entryGuid			UNIQUEIDENTIFIER,
		@defaultCur			UNIQUEIDENTIFIER,
		@CeDate  			DATETIME,
		@RoundValue			FLOAT,
		@PayCurrencyVal		FLOAT,
		@CashCurrencyVal	FLOAT,
		@CashCurrency		UNIQUEIDENTIFIER,
		@IsDebitRound		BIT,
		@exchaneNum			INT,
		@CommissionAmount	FLOAT,
		@CommissionNet		FLOAT,
		@CommissionCurrencyVal FLOAT,
		@CommissionCurrency	UNIQUEIDENTIFIER,
		@TypeGuid			UNIQUEIDENTIFIER,
		@CustomerGUID       UNIQUEIDENTIFIER,
		@ContraCustomerGUID UNIQUEIDENTIFIER
		
	SELECT *
	INTO #ExchangeRec
	FROM trnExchange000 WHERE Guid = @exchangGuid

	SELECT	
			@TypeGuid = t.[Guid],
			@PayCurrencyVal = PayCurrencyVal, 
			@CashCurrencyVal = CashCurrencyVal,
			@CashCurrency = CashCurrency,
			@CostGuid = CostGuid,
			@CashAcc = CashAcc,
			@PayAcc = PayAcc ,
			@RoundAcc = RoundAccGuid,
			@RoundValue = RoundValue,
			@IsDebitRound = RoundDir,
			@CeDate = ex.Date,
			@exchaneNum = ex.Number,
			@CommissionAmount = ex.CommissionAmount,
			@CommissionNet = ex.CommissionNet,
			@CommissionCurrency = ex.CommissionCurrency,
			@CommissionCurrencyVal = CASE WHEN CommissionCurrency = CashCurrency AND CashCurrencyVal <> 0 
										THEN CashCurrencyVal 
										ELSE 1 
									END 
	FROM TrnExchangeTypes000 AS t 
	INNER JOIN #ExchangeRec AS ex ON ex.TypeGuid = t.[Guid]
	
		Declare @isGenEntriesAccordingToUserAccounts BIT 
	SELECT @isGenEntriesAccordingToUserAccounts = value from op000 where Name = 'TrnCfg_Exchange_GenEntriesAccordingToUserAccounts'
	IF (@isGenEntriesAccordingToUserAccounts = 1)
	BEGIN
		SELECT  
			@CostGuid = CASE WHEN ISNULL(@OldCostGuid, 0x0) = 0x0 THEN CostGuid ELSE @OldCostGuid END,
			@RoundAcc = RoundAccountGuid
		FROM 
			TrnUserConfig000 AS uc
		WHERE uc.UserGuid = @UserGuid

		IF (ISNULL(@CostGuid, 0x0) = 0x0 OR ISNULL(@RoundAcc, 0x0) = 0x0)
			RETURN
	END

	-- get new entry number and guid 
	SET @entryGuid = NEWID() 
	-- get the defualt currency 
	SELECT @defaultCur = guid FROM my000 WHERE number = 1 

	EXEC  prcDisableTriggers 'ce000'
	EXEC  prcDisableTriggers 'en000'
	
	-- insert entry header 
	INSERT INTO ce000(Type, Number, Date, PostDate, Debit, Credit,
			  Notes, CurrencyVal, IsPosted, Security, Branch, GUID, CurrencyGUID)     
	SELECT 	1, @entryNum, @CeDate, @CeDate,
		CashAmount,CashAmount, Note ,
		1, 1,security,branchGuid,@entryGuid,@defaultCur
	FROM #ExchangeRec

	SET @CustomerGUID = dbo.fnGetAccountTopCustomer(@CashAcc)
	SET @ContraCustomerGUID = dbo.fnGetAccountTopCustomer(@PayAcc) 

	INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
		   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
		   CostGUID, ContraAccGUID, CustomerGUID) 
	  SELECT   0 , @CeDate,
		   CASE @isDebitRound WHEN 1 THEN CashAmount ELSE CashAmount + (@RoundValue*CashCurrencyVal) END ,
		   0,
		   CashNote,
		   CashCurrencyVal, 
		   @entryGUID ,
		   @CashAcc,
		   CashCurrency, 
		   @CostGuid,
		   @PayAcc,
		   @CustomerGUID
	   FROM #ExchangeRec
	UNION 
 	SELECT 	  1 , @CeDate,
		  0,
		  CASE @isDebitRound WHEN 1 THEN PayAmount + (@RoundValue*PayCurrencyVal) ELSE PayAmount END,
		   PayNote,
		  PayCurrencyVal, 
		  @entryGUID ,
		  @PayAcc,
		  PayCurrency, 
		  @CostGuid,
		  @CashAcc,
		  @ContraCustomerGUID
	   FROM #ExchangeRec

	DECLARE @EntryBalance FLOAT
	SELECT @EntryBalance = SUM(Debit) - SUM(Credit)
	FROM EN000 
	WHERE ParentGUID = @entryGUID

	DECLARE @EnNumber INT
	SET @EnNumber = 2	
	
	IF (@CommissionAmount > 0)
	BEGIN
		DECLARE	@CommissionAccount			UNIQUEIDENTIFIER
				,@commission_Cash_Account	UNIQUEIDENTIFIER
		
		SELECT 
			@CommissionAccount = CAST(VALUE AS [UNIQUEIDENTIFIER])
		FROM OP000 
		WHERE NAME  = 'TrnCfg_Exchange_AccountCommission'

		IF (@CommissionCurrency <> @CashCurrency)
		BEGIN
			IF (@isGenEntriesAccordingToUserAccounts = 1)
			BEGIN
				SELECT 
					@commission_Cash_Account = ca.AccountGUID 
				FROM 
					#ExchangeRec ex
					INNER JOIN TrnUserConfig000 uc ON uc.UserGuid = ex.UserGuid
					INNER JOIN TrnGroupCurrencyAccount000 gca ON gca.GUID = uc.GroupCurrencyAccGUID
					INNER JOIN TrnCurrencyAccount000 ca ON ca.ParentGUID = gca.GUID
				WHERE
					ca.CurrencyGUID = @CommissionCurrency
			END
			ELSE
			BEGIN
				SELECT 
					@commission_Cash_Account = c_acc.AccountGuid
			
				FROM TrnExchangeTypes000 AS ty
				INNER JOIN  TrnCurrencyAccount000 AS c_acc ON c_acc.ParentGuid = ty.GroupCurrencyAccGuid
				WHERE ty.[Guid] = @TypeGuid AND c_acc.CurrencyGuid = @CommissionCurrency
			END
		END
		ELSE
		BEGIN
			SET @commission_Cash_Account = @CashAcc
		END
		
		INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
		   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
		   CostGUID, ContraAccGUID) 
	  SELECT   
		   @EnNumber, 
		   @CeDate,
		   @CommissionNet,
		   0,
		   Note + N' قبض العمولة',
		   @CommissionCurrencyVal,
		   @entryGUID ,
		   @commission_Cash_Account,
		   @CommissionCurrency, 
		   @CostGuid,
		   @CommissionAccount
	   FROM #ExchangeRec

	   SET @EnNumber = @EnNumber + 1

		INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
		   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
		   CostGUID, ContraAccGUID) 
	  SELECT   
		   @EnNumber, 
		   @CeDate,
		   0,
		   @CommissionAmount,
		   Note + N' العمولة',
		   1,
		   @entryGUID ,
		   @CommissionAccount,
		   @defaultCur, 
		   @CostGuid,
		   @commission_Cash_Account
	   FROM #ExchangeRec

	   SET @EnNumber = @EnNumber + 1

	   IF (@CommissionAmount <> @CommissionNet)
		BEGIN
	   		INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
			   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
			   CostGUID, ContraAccGUID) 
		  SELECT   
			   @EnNumber, 
			   @CeDate,
			   CASE WHEN @CommissionAmount > @CommissionNet THEN @CommissionAmount - @CommissionNet ELSE 0 END,
			   CASE WHEN @CommissionAmount < @CommissionNet THEN @CommissionNet - @CommissionAmount ELSE 0 END,
			   Note + N' تقريب العمولة',
			   @CommissionCurrencyVal,
			   @entryGUID ,
			   @RoundAcc,
			   @CommissionCurrency, 
			   @CostGuid,
			   CASE WHEN @CommissionAmount < @CommissionNet THEN @commission_Cash_Account ELSE @CommissionAccount END
		   FROM #ExchangeRec
		   
	   	   SET @EnNumber = @EnNumber + 1
		END
	END 

	IF @EntryBalance != 0 
	BEGIN
		DECLARE @Debit float
		DECLARE @credit float
		
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
		SELECT 	  
			@EnNumber , @CeDate,
			@Debit,
			@Credit,
			Note + ' ' + CashNote + ' ' + PayNote,
			CASE @isDebitRound when 1 THEN PayCurrencyVal ELSE CashCurrencyVal End, 
			@entryGUID,
			@RoundAcc,
			CASE @isDebitRound when 1 THEN PayCurrency ELSE CashCurrency END,
			@CostGuid,	
			CASE @isDebitRound WHEN 1 THEN @PayAcc ELSE @CashAcc END  
		   FROM #ExchangeRec
	 END
	
	INSERT INTO er000 (EntryGUID, ParentGUID, ParentType, ParentNumber) 
	VALUES(@entryGUID, @exchangGuid , 507 , @exchaneNum )  
    
	UPDATE TrnExchange000 
	SET EntryGuid = @entryGUID
	WHERE guid = @exchangGuid
	
	EXEC prcEnableTriggers 'ce000'
	EXEC prcEnableTriggers 'en000'

	-- return data about generated entry  
	SELECT @entryGUID AS EntryGuid , @entryNum  AS EntryNumber
#####################################################################
CREATE PROC prcGenExchangeEntry2 
	@exchangGuid		UNIQUEIDENTIFIER,
	@EntryNum			INT,
	@AvgPayCurrencyVal	FLOAT = 0,
	@UserGuid			UNIQUEIDENTIFIER = 0x0,
	@OldCostGuid		uniqueidentifier = 0x0
AS

	DECLARE @CostGuid		UNIQUEIDENTIFIER,
			@CashAcc		UNIQUEIDENTIFIER,
			@PayAcc			UNIQUEIDENTIFIER,
			@RoundAcc		UNIQUEIDENTIFIER,
			@entryGuid		UNIQUEIDENTIFIER,
			@defaultCur		UNIQUEIDENTIFIER,
			@PayCurrency	UNIQUEIDENTIFIER,
			@CeDate			DATETIME,
			@PayCurrencyVal	FLOAT,
			@PayRoundAmount	FLOAT,
			@PayAmount		FLOAT,
			@RoundValue		FLOAT,
			@SellAmount		FLOAT,
			@AvgPayAmount	FLOAT,
			@EnNumber		INT,
			@IsDebitRound	BIT,
			@IsRateDiffrenceAccOption	BIT,
			@SellsOrProfit_Acc			UNIQUEIDENTIFIER,
			@SellsCostOrLose_Acc		UNIQUEIDENTIFIER,
			@CashCurrency				UNIQUEIDENTIFIER,
			@CommissionAmount			FLOAT,
			@CommissionNet				FLOAT,
			@CommissionCurrencyVal		FLOAT,
			@CommissionCurrency			UNIQUEIDENTIFIER,
			@TypeGuid					UNIQUEIDENTIFIER,
			@CustomerGUID				UNIQUEIDENTIFIER,
			@ContraCustomerGUID			UNIQUEIDENTIFIER
	
	SELECT *
	INTO #ExchangeRec
	FROM trnExchange000 WHERE Guid = @exchangGuid
	
	SELECT 
		@TypeGuid = t.[Guid], 
		@PayCurrencyVal = ex.PayCurrencyVal, 
		@CostGuid = CostGuid, 
		@CashAcc = CashAcc,
		@CashCurrency = CashCurrency,
		@PayAcc = PayAcc ,
		@RoundAcc = RoundAccGuid,
		@RoundValue = RoundValue,
		@IsDebitRound = RoundDir,
		@SellsOrProfit_Acc = SellsAcc.SellsAccGUID,
		@SellsCostOrLose_Acc = SellsAcc.SellsCostAccGUID,
		@CeDate = ex.date,
		@PayAmount = ex.[PayAmount],
		@PayCurrency = ex.PayCurrency,
		@CommissionAmount = ex.CommissionAmount,
		@CommissionNet = ex.CommissionNet,
		@CommissionCurrency = ex.CommissionCurrency,
		@CommissionCurrencyVal = CASE WHEN CommissionCurrency = CashCurrency AND CashCurrencyVal <> 0 
									THEN CashCurrencyVal 
									ELSE 1 
								END 
	FROM TrnExchangeTypes000 AS t 
	INNER JOIN #ExchangeRec AS ex ON t.guid = ex.typeguid
	INNER JOIN TrnCurrencySellsAcc000 as SellsAcc ON ex.payCurrency = SellsAcc.CurrencyGuid
	
	Declare @isGenEntriesAccordingToUserAccounts BIT 
	SELECT @isGenEntriesAccordingToUserAccounts = value from op000 where Name = 'TrnCfg_Exchange_GenEntriesAccordingToUserAccounts'
	IF (@isGenEntriesAccordingToUserAccounts = 1)
	BEGIN
		SELECT  
			@CostGuid = CASE WHEN isnull(@OldCostGuid, 0x0) = 0x0 THEN CostGuid ELSE @OldCostGuid END,
			@RoundAcc = RoundAccountGuid
		FROM 
			TrnUserConfig000 AS uc
		WHERE uc.UserGuid = @UserGuid

		IF (ISNULL(@CostGuid, 0x0) = 0x0 OR ISNULL(@RoundAcc, 0x0) = 0x0)
			RETURN
	END

	SET @IsRateDiffrenceAccOption = dbo.fnTrnExAccSellOrRateOption()
	IF (@AvgPayCurrencyVal = 0)
		SELECT @AvgPayCurrencyVal = CurAvg 
		FROM FnTrnGetCurAverage2(@PayCurrency, @CeDate)
	
	IF (@IsDebitRound = 0)
	BEGIN
		SET @PayRoundAmount = @PayAmount / @PayCurrencyVal
	END
	ELSE
	BEGIN
		SET @PayRoundAmount = (@PayAmount + (@RoundValue*@PayCurrencyVal)) / @PayCurrencyVal
	END

	-- get new entry number and guid 
	SET @entryGuid = NEWID() 
	-- get the defualt currency 
	SELECT @defaultCur = guid FROM my000 WHERE Number = 1 

	EXEC  prcDisableTriggers 'ce000'
	EXEC  prcDisableTriggers 'en000'
	
	SET @CustomerGUID = dbo.fnGetAccountTopCustomer(@CashAcc)
	SET @ContraCustomerGUID = dbo.fnGetAccountTopCustomer(@PayAcc) 

	-- insert entry header 
	INSERT INTO ce000(Type, Number, Date, PostDate, Debit, Credit,
			  Notes, CurrencyVal, IsPosted, Security, Branch, GUID, CurrencyGUID)     
	SELECT 	1,@entryNum, @CeDate, @CeDate,
		CashAmount,CashAmount, Note,
		1, 1/*@AutoPostEntry*/,security,branchGuid,@entryGuid,@defaultCur
	FROM #ExchangeRec 
	
	SELECT @AvgPayAmount = (@PayRoundAmount * @AvgPayCurrencyVal) 
	
	SET @EnNumber = 0
	INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
		   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
		   CostGUID, ContraAccGUID, CustomerGUID) 
	  SELECT   @EnNumber, @CeDate,
		   CASE @isDebitRound WHEN 1 THEN CashAmount ELSE CashAmount + (@RoundValue*CashCurrencyVal) END ,
		   --CashRoundAmount, -- هنا محسوبة بالسوري	
		   0,--credit
		   CashNote,
		   CashCurrencyVal,
		   @entryGUID ,
		   @CashAcc,
		   CashCurrency, 
		   @CostGuid,
		   CASE @IsRateDiffrenceAccOption WHEN 0 THEN @SellsOrProfit_Acc ELSE 0X0 END,
		   @CustomerGUID
	   FROM #ExchangeRec
	
	SET @SellAmount =  CASE @isDebitRound WHEN 1 THEN @PayAmount + (@RoundValue * @PayCurrencyVal) ELSE @PayAmount END

	IF(@SellAmount <> @AvgPayAmount)
	BEGIN
		
		IF (@IsRateDiffrenceAccOption = 1 OR @SellsOrProfit_Acc = @SellsCostOrLose_Acc)
		BEGIN
			
			DECLARE @Profit		FLOAT,
					@Lose		FLOAT,
					@Account 	UNIQUEIDENTIFIER
					
			
			SELECT @Profit = 0, @Lose = 0
			IF (@SellAmount > @AvgPayAmount)
			BEGIN
				SET @Profit = @SellAmount - @AvgPayAmount
				SET @Account = @SellsOrProfit_Acc
			END	
			ELSE
			BEGIN	
				SET @Lose = @AvgPayAmount - @SellAmount
				SET @Account = @SellsCostOrLose_Acc
			END	

			SET @CustomerGUID = dbo.fnGetAccountTopCustomer(@Account)
			SET @EnNumber = @EnNumber + 1
			INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
			   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
			   CostGUID, ContraAccGUID, CustomerGUID) 
			  SELECT   1, @CeDate,
				   @Lose,
				   @Profit,
				   Note + ' ' + CashNote + ' ' + PayNote ,
				   1,
				   @entryGUID ,
				   @Account,
				   @defaultCur, 
				   @CostGuid,
				   0X0,
				   @CustomerGUID
			FROM #ExchangeRec
		END
		ELSE
		BEGIN
			SET @CustomerGUID = dbo.fnGetAccountTopCustomer(@SellsOrProfit_Acc)
			SET @EnNumber = @EnNumber + 1
			INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
				   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
				   CostGUID, ContraAccGUID, CustomerGUID) 
			SELECT   @EnNumber, @CeDate,
				   0,--@AvgPayAmount,
				   CASE @isDebitRound WHEN 1 THEN PayAmount + (@RoundValue*PayCurrencyVal) ELSE PayAmount END,
				     PayNote ,
				   1,
				   @entryGUID ,
				   @SellsOrProfit_Acc,
				   @defaultCur, 
				   @CostGuid,
				   @CashAcc,
				   @CustomerGUID
			FROM #ExchangeRec
			
			SET @EnNumber = @EnNumber + 1
			SET @CustomerGUID = dbo.fnGetAccountTopCustomer(@SellsCostOrLose_Acc)
			INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
				   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
				   CostGUID, ContraAccGUID, CustomerGUID) 
			  SELECT   @EnNumber, @CeDate,
				   @AvgPayAmount,	
				   0,
				   Note + ' ' + CashNote + ' ' + PayNote ,
				   1,
				   @entryGUID ,
				   @SellsCostOrLose_Acc,
				   @defaultCur, 
				   @CostGuid,
				   @PayAcc,
				   @CustomerGUID
			   FROM #ExchangeRec 
			SET @EnNumber = 3
		END
	END
	SET @EnNumber = @EnNumber + 1
	
	INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
		   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
		   CostGUID, ContraAccGUID, CustomerGUID) 
 	SELECT 	  @EnNumber,
		  @CeDate,	
		  0, -- Debit
		  @AvgPayAmount, 
		   PayNote,
		  @AvgPayCurrencyVal,
		  @entryGUID,
		  @PayAcc,
		  PayCurrency,
		  @CostGuid,
		  CASE @IsRateDiffrenceAccOption WHEN 0 THEN @SellsCostOrLose_Acc ELSE 0X0 END,
		  @ContraCustomerGUID
	FROM #ExchangeRec

	SET @EnNumber =  @EnNumber + 1	
	
	IF (@CommissionAmount > 0)
	BEGIN
		DECLARE	@CommissionAccount			UNIQUEIDENTIFIER
				,@commission_Cash_Account	UNIQUEIDENTIFIER
		
		SELECT 
			@CommissionAccount = CAST(VALUE AS [UNIQUEIDENTIFIER])
		FROM OP000 
		WHERE NAME  = 'TrnCfg_Exchange_AccountCommission'

		IF (@CommissionCurrency <> @CashCurrency)
		BEGIN
			IF (@isGenEntriesAccordingToUserAccounts = 1)
			BEGIN
				SELECT 
					@commission_Cash_Account = ca.AccountGUID 
				FROM 
					#ExchangeRec ex
					INNER JOIN TrnUserConfig000 uc ON uc.UserGuid = ex.UserGuid
					INNER JOIN TrnGroupCurrencyAccount000 gca ON gca.GUID = uc.GroupCurrencyAccGUID
					INNER JOIN TrnCurrencyAccount000 ca ON ca.ParentGUID = gca.GUID
				WHERE
					ca.CurrencyGUID = @CommissionCurrency
			END
			ELSE
			BEGIN
				SELECT 
					@commission_Cash_Account = c_acc.AccountGuid
			
				FROM TrnExchangeTypes000 AS ty
				INNER JOIN  TrnCurrencyAccount000 AS c_acc ON c_acc.ParentGuid = ty.GroupCurrencyAccGuid
				WHERE ty.[Guid] = @TypeGuid AND c_acc.CurrencyGuid = @CommissionCurrency
			END
		END
		ELSE
		BEGIN
			SET @commission_Cash_Account = @CashAcc
		END
		
		SET @CustomerGUID = dbo.fnGetAccountTopCustomer(@commission_Cash_Account)
		INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
		   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
		   CostGUID, ContraAccGUID, CustomerGUID) 
	  SELECT   
		   @EnNumber, 
		   @CeDate,
		   @CommissionNet,
		   0,
		   Note + N' قبض العمولة',
		   @CommissionCurrencyVal,
		   @entryGUID ,
		   @commission_Cash_Account,
		   @CommissionCurrency, 
		   @CostGuid,
		   @CommissionAccount,
		   @CustomerGUID
	   FROM #ExchangeRec
 
	   SET @EnNumber = @EnNumber + 1

		SET @CustomerGUID = dbo.fnGetAccountTopCustomer(@CommissionAccount)
		INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
		   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
		   CostGUID, ContraAccGUID, CustomerGUID) 
	  SELECT   
		   @EnNumber, 
		   @CeDate,
		   0,
		   @CommissionAmount,
		   Note + N' العمولة',
		   1,
		   @entryGUID ,
		   @CommissionAccount,
		   @defaultCur, 
		   @CostGuid,
		   @commission_Cash_Account,
		   @CustomerGUID
	   FROM #ExchangeRec

	   SET @EnNumber = @EnNumber + 1

	   IF (@CommissionAmount <> @CommissionNet)
		BEGIN
			SET @CustomerGUID = dbo.fnGetAccountTopCustomer(@RoundAcc)
	   		INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
			   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
			   CostGUID, ContraAccGUID, CustomerGUID) 
		  SELECT   
			   @EnNumber, 
			   @CeDate,
			   CASE WHEN @CommissionAmount > @CommissionNet THEN @CommissionAmount - @CommissionNet ELSE 0 END,
			   CASE WHEN @CommissionAmount < @CommissionNet THEN @CommissionNet - @CommissionAmount ELSE 0 END,
			   Note + N' تقريب العمولة',
			   @CommissionCurrencyVal,
			   @entryGUID ,
			   @RoundAcc,
			   @CommissionCurrency, 
			   @CostGuid,
			   CASE WHEN @CommissionAmount < @CommissionNet THEN @commission_Cash_Account ELSE @CommissionAccount END,
			   @CustomerGUID
		   FROM #ExchangeRec
		   
	   	   SET @EnNumber = @EnNumber + 1
		END
	END 

	DECLARE @EntryBalance FLOAT
	SELECT @EntryBalance = SUM(Debit) - SUM(Credit)
	FROM EN000 
	WHERE ParentGUID = @entryGUID
	IF @EntryBalance != 0 --@RoundValue != 0 
	BEGIN
		DECLARE @Debit float
		DECLARE @credit float
		
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

		SET @CustomerGUID = dbo.fnGetAccountTopCustomer(@RoundAcc)
		SET @EnNumber = @EnNumber + 1
		INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,
			   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,
			   CostGUID, ContraAccGUID, CustomerGUID)
		SELECT 	
			  @EnNumber,
			  @CeDate,
			@Debit,--CASE @isDebitRound WHEN 1 THEN @RoundValue * PayCurrencyVal ELSE 0 END,
			@Credit,--CASE @isDebitRound WHEN 0 THEN @RoundValue * PayCurrencyVal ELSE 0 END,
			Note + ' ' + CashNote + ' ' + PayNote,
			CASE @isDebitRound when 1 THEN PayCurrencyVal ELSE CashCurrencyVal End, 
			@entryGUID,
			@RoundAcc,
			CASE @isDebitRound when 1 THEN PayCurrency ELSE CashCurrency END,
			@CostGuid,	
			CASE @isDebitRound WHEN 1 THEN @PayAcc ELSE @CashAcc END,
			@CustomerGUID
		   FROM #ExchangeRec
	 END
	
	DECLARE @exchaneNum INT 
	SELECT @exchaneNum = Number FROM trnExchange000 WHERE guid = @exchangGuid 
	INSERT INTO er000 (EntryGUID, ParentGUID, ParentType, ParentNumber) 
	VALUES(@entryGUID, @exchangGuid , 507 , @exchaneNum )  
    
	UPDATE TrnExchange000
	SET PayAvgval = @AvgPayCurrencyVal
	WHERE guid = @exchangGuid

	UPDATE TrnExchange000 
	SET EntryGuid = @entryGUID
	WHERE guid = @exchangGuid
	
	EXEC prcEnableTriggers 'ce000'
	EXEC prcEnableTriggers 'en000'

	SELECT @entryGUID AS EntryGuid , @entryNum  AS EntryNumber
#####################################################################
create PROC prcGenExchangeEntry
	@exchangGuid UNIQUEIDENTIFIER,
	@AvgPayCurrencyVal float = 0
AS
	SET NOCOUNT ON
	DECLARE @PayCurrency uniqueidentifier,
		@CashCurrency uniqueidentifier,
		@DefaultCurrency uniqueidentifier,
		@BranchGuid uniqueidentifier
		
	CREATE  Table #result(EntryGuid uniqueidentifier, EntryNum int)
	SELECT 
		@PayCurrency = PayCurrency,
		@CashCurrency = CashCurrency
		
 	FROM trnExchange000  s
	WHERE guid = @exchangGuid 		
	
	declare @EntryNum int
	set @EntryNum = [dbo].[fnEntry_getNewNum](@branchguid)
	
	SELECT @DefaultCurrency = guid 
	From my000 where CurrencyVal = 1 
	--and number = (select min(number) From my000 where currencyval = 1)  

	-- عند بيع سوري، أي عند شراء عملة غير محلية بالسوري 
	IF (@DefaultCurrency = @PayCurrency) 
	BEGIN
	
	insert into #result
		exec prcGenExchangeEntry1 @exchangGuid, @EntryNum
	END
	ELSE
	BEGIN	
		--Declare @Date DateTime, @PayCurr uniqueidentifier
		--select @Date = [date], @PayCurr = PayCurrency
		--From 
		--	trnExchange000 where guid = @exchangGuid
		
		--if (@AvgPayCurrencyVal = 0)
		--	SELECT @AvgPayCurrencyVal = CurAvg 
		--	From FnTrnGetCurAverage2(@PayCurr, @Date)
		
		if 	(IsNull(@AvgPayCurrencyVal, 0) = 0)
				insert into #result
				exec prcGenExchangeEntry1 @exchangGuid, @EntryNum
		ELSE
			---عند بيع عملة غير محلية 
			insert into #result
			exec prcGenExchangeEntry2 @exchangGuid, @EntryNum, @AvgPayCurrencyVal
	END	

	EXEC prcEnableTriggers 'ce000'
	EXEC prcEnableTriggers 'en000'

	select EntryGuid, EntryNum from #result
###################################
#END

