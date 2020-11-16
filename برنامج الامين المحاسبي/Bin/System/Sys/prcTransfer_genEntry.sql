######################################################
CREATE PROC  prcTransfer_genEntry
	@TransferGUID 			UNIQUEIDENTIFIER, -- «·ÕÊ«·…  
	@CashAccGUID			UNIQUEIDENTIFIER,-- ’‰œÊﬁ «·„” Œœ„   
	-- 500  Ê·Ìœ ﬁÌœ «·ﬁ»÷ «·‰ﬁœÌ  
	-- 501  Ê·Ìœ ﬁÌœ «·œ›⁄  
	-- 502  Ê·Ìœ ﬁÌœ «·≈—Ã«⁄  
	-- 503  Ê·Ìœ ﬁÌœ ¬Ã·  
	-- 504  Ê·Ìœ ﬁÌœ «·≈ﬁ›«·
	-- 506 ≈—Ã«⁄ ¬‰Ì 
	-- 520 ≈·€«¡ «·ÕÊ«·…
	@TrEntryType 		INT, 
	@CostGuid				UNIQUEIDENTIFIER,-- „—ﬂ“ «·ﬂ·›… 
	@CurrentBranch		UNIQUEIDENTIFIER = 0x0 
AS    
	SET NOCOUNT ON   
	BEGIN TRAN   
	DECLARE   
        @SourceType 		int, 
		@DestType		int, 
		@RatioType 		UNIQUEIDENTIFIER, -- ‰„ÿ  Ê“Ì⁄ «·√Ã—   
		@wageType 		UNIQUEIDENTIFIER, -- ‰„ÿ  «·√Ã—   
		@entryGUID 		UNIQUEIDENTIFIER, -- «·ﬁÌœ «·–Ì ”Ê› ÌÊ·œ   
		@entryNum 		INT , -- —ﬁ„ «·ﬁÌœ «·„Ê·œ   
		@branchGUID 	UNIQUEIDENTIFIER, -- «·›—⁄ «·„—”·  
		@DifferentAccGUID	UNIQUEIDENTIFIER,  
		@SourceWagesAccGUID	UNIQUEIDENTIFIER, --Õ”«» √ÃÊ— «·›—⁄ «·„—”· 	-- debit   
		@DestWagesAccGUID	UNIQUEIDENTIFIER, --Õ”«» √ÃÊ— «·›—⁄ «·„—”· ≈·ÌÂ 	-- credit   
		@DestAccGUID		UNIQUEIDENTIFIER, --Õ”«» «·›—⁄ «·„—”· ≈·ÌÂ	-- credit   
		@SourceAccGuid 		UNIQUEIDENTIFIER, -- Õ”«» «·›—⁄ «·„—”·   
		@CompanyAcc			UNIQUEIDENTIFIER, --Õ”«» √ÃÊ— «·‘—ﬂ… «·⁄«„…	-- credit   
		  
		@SourceWages	FLOAT, -- ﬁ—«¡… „‰  Ê“Ì⁄ ‰”» «·ÕÊ«·«  ‰”»… «·›—⁄ «·„—”·   
		@DestWages		FLOAT,-- ﬁ—«¡… „‰  Ê“Ì⁄ ‰”» «·ÕÊ«·«  ‰”»… «·›—⁄ «·„—”· ≈·ÌÂ   
		@CompanyWages	FLOAT, -- ﬁ—«¡… „‰  Ê“Ì⁄ ‰”» «·ÕÊ«·«  ‰”»… «·‘—ﬂ… «·⁄«„…   
		@DiscAcc		UNIQUEIDENTIFIER,---Õ”«» Õ”„Ì«   «·›—⁄ „‰ √Ã· «·Õ”„Ì«    
		@ExtraAcc		UNIQUEIDENTIFIER, -- Õ”«» ≈÷«›«  «·›—⁄ „‰ √Ã· «·≈÷«›«    
		@DiscVal		FLOAT,			--ﬁÌ„… «·Õ”„   
		@ExtraVal		FLOAT,			-- ﬁÌ„… «·≈÷«›«    
		@Note			NVARCHAR(256) ,  
		   
		@returnWagesFlag	Bit,  
		@returnWages		FLOAT,  
		@payCurrency UNIQUEIDENTIFIER,  
		@exchangeCurrency UNIQUEIDENTIFIER,  
		@payCurrencyVal FLOAT(53),  
		@exchangeCurrencyVal FLOAT(53),  
		@DestBranchWages FLOAT(53),  
		@DestRecordedAmount  FLOAT(53) , 
		@AgentGuid	UNIQUEIDENTIFIER, 
		@AgentWagesAcc  UNIQUEIDENTIFIER, 
		@DATE				DATETIME 

	
		 
	SELECT 	@DATE = GETDATE() 
	DECLARE @NewState INT , @ProcType INT   
	SET @NewState = 0 -- Õ«·… «·ÕÊ«·… «·ÃœÌœ…  
	SET @ProcType = 0 -- ‰Ê⁄ «·≈Ã—«∆Ì…   

	DECLARE 
		@SourceGUID  	UNIQUEIDENTIFIER,  
		@DestGUID  	UNIQUEIDENTIFIER 	 
	 
	SELECT	  
		@SourceType = SourceType, 
		@DestType = DestinationType,    
		@SourceGUID = SourceBranch,  
		@DestGUID = DestinationBranch,  
		@AgentGuid = AgentBranch, 
		@payCurrency = payCurrency,  
		@exchangeCurrency = exchangeCurrency ,  
		@payCurrencyVal = payCurrencyVal ,  
		@exchangeCurrencyVal =  exchangeCurrencyVal,  
		@DestBranchWages = DestBranchWages,  
		@DestRecordedAmount  = DestRecordedAmount  
	FROM   trnTransferVoucher000 
	WHERE GUID = @TransferGUID  
	 
	
	DECLARE @AmnBranchSource UNIQUEIDENTIFIER, 
			@AmnBranchDest UNIQUEIDENTIFIER 
	
	IF (@SourceType = 1) 
		SELECT @AmnBranchSource = AmnBranchGuid
		FROM TrnBranch000  
		WHERE Guid = @SourceGUID 
		
	IF (@DestType = 1) 
		SELECT @AmnBranchDest = AmnBranchGuid 
		FROM TrnBranch000  
		WHERE Guid = @DestGUID 

	IF (@SourceType = 1  AND @DestType = 1) 
	BEGIN 
	SELECT @branchGUID =  
	CASE  
		WHEN @TrEntryType = 500/*ﬁ»÷*/ THEN @AmnBranchSource 
		WHEN @TrEntryType = 501/*œ›⁄*/ THEN @AmnBranchDest 
		ELSE @CurrentBranch END 
	END 
	ELSE 
	IF (@SourceType = 1 AND @DestType = 2) 
		SELECT @branchGUID = @AmnBranchSource 
	ELSE 
	IF (@SourceType = 2 AND @DestType = 1) 
		SELECT @branchGUID = @AmnBranchDest 
	ELSE 
	IF (@SourceType = 2 AND @DestType = 2) 
	BEGIN 
		--SELECT @branchGUID = @AgentBranch 
		SELECT @branchGUID = @CurrentBranch 
		SELECT @AgentWagesAcc = WagesAccGuid 
		FROM trnBranch000   
		WHERE AmnBranchGuid = @AgentGUID  
	END 

	SET @Note = ' ÕÊ«·… '
			 
	IF(@SourceType = 1) 
	BEGIN 
		SELECT 
			@SourceWagesAccGUID = WagesAccGuid, 
			@SourceAccGuid = BranchAccGuid ,
			@Note = @Note + [Name] + ' '  
		FROM trnBranch000   
		WHERE Guid = @SourceGUID  
		--WHERE AmnBranchGuid = @SourceGUID  
		--SET @SourceGUID = @SourceBranch 
	END 
	ELSE 
	BEGIN 
		SELECT  
			@SourceWagesAccGUID = WagesAccGuid,  
			@SourceAccGuid = AccGUID,
			@Note = @Note + [Name] + ' '  
		FROM trnOffice000   
		WHERE GUID = @SourceGUID 
		--SET @SourceGUID = @SourceOffice 
	END 
	IF(@DestType = 1) 
	BEGIN 
		SELECT  
			@DestWagesAccGUID = WagesAccGuid, 
			@DestAccGUID = BranchAccGuid,
			@Note = @Note + [Name] + ' '  
		FROM trnBranch000   
		WHERE Guid = @DestGUID   
		--WHERE AmnBranchGuid = @DestGUID 
	END 
	ELSE 
	BEGIN 
		SELECT 
			@DestWagesAccGUID = WagesAccGuid, 
			@DestAccGUID = AccGUID  ,
			@Note = @Note + [Name] + ' '  
		FROM trnOffice000   
		WHERE GUID = @DestGUID 
	END 

	DECLARE	@tmpAccGuid	 UNIQUEIDENTIFIER,
		@tmpWagesAccGuid UNIQUEIDENTIFIER

	SELECT 	@tmpAccGuid = CAST(VALUE AS [UNIQUEIDENTIFIER])
	FROM op000 WHERE NAME = 'TrnCfg_TransferAccount'
	
	SELECT 	@tmpWagesAccGuid = CAST(VALUE AS [UNIQUEIDENTIFIER])
	FROM op000 WHERE NAME = 'TrnCfg_TransferWagesAccount'
		

	SELECT @CompanyAcc = Value   
	FROM op000   
	WHERE NAME = 'TrnCfg_GeneralAcc' 

	SET @Note = @Note +  ':' + (SELECT CAST([InternalNum] AS NVARCHAR (10))  
				   FROM [trnTransferVoucher000] AS [t]   
				   WHERE [t].[Guid] = @TransferGUID)   
	IF @TrEntryType = 500   
		SET @Note ='ﬁ»÷ *' + @Note   
	ELSE IF	@TrEntryType = 501  
		SET @Note ='œ›⁄ *' + @Note   
	 
	
	--  Õ”«»«  «·Õ”„Ì«  Ê«·≈÷«›«  ··›—⁄ «·„—”·   
	SELECT 	@DiscAcc = DiscountAcc, @ExtraAcc = ExtraAcc   
	FROM trnBranch000   
	WHERE GUID = @SourceGUID 

	SELECT 	
		@DiscVal = WagesDisc ,  
		@ExtraVal= WagesExtra   
	FROM trnTransferVoucher000   
	WHERE GUID = @TransferGUID   
	-- is Empty result SET FROM previous SELECT , raise error AND return  
	IF @@ROWCOUNT = 0   
	BEGIN   
		RAISERROR('AmnE0193: Transfer specified was not found ...', 16, 1)   
		ROLLBACK TRAN   
		RETURN   
	END   

	SELECT 	@wageType = ISNULL(WagesTypeGuid ,0x0) , @ratioType = ISNULL(RatioTypeGuid, 0x0)
	FROM TrnBranchsConfig000
	WHERE SourceGUID = @SourceGUID AND DestinationGUID = @DestGUID

	-- ﬁ—«¡… ‰”»  Ê“Ì⁄ «·√—»«Õ »Ì‰ «·„—”· Ê «·„” ﬁ»· Ê «·‘—ﬂ… «·⁄«„·…  
	IF @wagetype = 0x00  
	begin   
		SET @DiscVal = 0   
		SET @ExtraVal =  0   
		SET @SourceWages  = 0   
		SET @DestWages = 0   
		SET @CompanyWages = 0  
	END   
	ELSE IF @ratioType != 0x00   
		SELECT @SourceWages = SourceAccRatio ,  
		       @DestWages = @DestBranchWages ,   
		       @CompanyWages = GeneralAccRatio  
		FROM trnRatio000   
		WHERE Guid = @RatioType  
	ELSE   
		SET @SourceWages = 100  
		  
	SET @DestWages = @DestBranchWages  
		  
   
	-- DELETE old entry relation er000  
	EXEC prcER_delete @TransferGUID, @TrEntryType   
	  
	-- prepare new entry guid AND number:     
	SET @entryGUID = NEWID()     
	SET @entryNum = dbo.fnEntry_getNewNum( @CurrentBranch)  
	IF ( exists (SELECT *FROM ce000 WHERE number = @entryNum)) 
		SELECT @entryNum = max(number) + 1 FROM ce000 
----------------------------------------------------------------------  
----------------------------------------------------------------------  
		DECLARE @MustCashedAmount as float(53)  
		DECLARE @MustPaidAmount as float(53)  
		DECLARE @NetWages as float(53)  
		DECLARE @CurrencyGUID as uniqueidentifier  
		DECLARE @CurrencyVal as float(53)  
		DECLARE @BaseCurrencyVal as float(53)  
		DECLARE @BaseCurrency as uniqueidentifier  
		SELECT Top 1 @BaseCurrencyVal = CurrencyVal, @BaseCurrency = GUID FROM my000 WHERE CurrencyVal = 1 ORDER BY NUmber  
		SELECT   
			@DestRecordedAmount = DestRecordedAmount,  
			@MustCashedAmount = MustCashedAmount,  
			@MustPaidAmount = MustPaidAmount,  
			@NetWages = NetWages,  
			@CurrencyGUID = CurrencyGUID,  
			@CurrencyVal = CurrencyVal  
		FROM  
			trnTransferVoucher000   
		WHERE GUID = @TransferGUID  
			  
		DECLARE @def as float(53)  
----------------------------------------------------------------------  
----------------------------------------------------------------------  
-- INSERT Entry Header goes here  
	INSERT INTO ce000(Type, Number, DATE, Debit, Credit,  
			  Notes, CurrencyVal, IsPosted, Security, Branch, GUID, CurrencyGUID)       
		SELECT   
				1, @entryNum, @DATE,    
			CASE   
				WHEN @TrEntryType = 500/*ﬁ»÷*/ THEN MustCashedAmount   
				WHEN @TrEntryType = 501/*œ›⁄*/ THEN MustPaidAmount   
				ELSE MustPaidAmount	END,   
			CASE    
				WHEN @TrEntryType = 500/*ﬁ»÷*/ THEN MustCashedAmount    
				WHEN @TrEntryType = 501/*œ›⁄*/ THEN MustPaidAmount    
				ELSE MustPaidAmount	END,   
			@Note,   
			CASE   
				WHEN @TrEntryType = 500/*ﬁ»÷*/ THEN @BaseCurrencyVal  
				WHEN @TrEntryType = 501/*œ›⁄*/ THEN @BaseCurrencyVal  
				ELSE CurrencyVal	END,   
			0,   
			Security, 
			@branchGUID,  
			@entryGUID,   
 			CASE   
				WHEN @TRENTRYTYPE = 500/*ﬁ»÷*/ THEN @BASECURRENCY  
 				WHEN @TRENTRYTYPE = 501/*œ›⁄*/ THEN @BASECURRENCY  
 				ELSE CURRENCYGUID	END			  
		FROM trnTransferVoucher000   
		WHERE GUID = @TransferGUID   
	DECLARE @enNumber Int   
	SELECT @enNumber = 0   
	----------------------------------------------------------------------------  
	IF @TrEntryType = 500 --  Ê·Ìœ ”‰œ «·ﬁ»÷   
	BEGIN  
		
		INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,  
				   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,  
				   CostGUID, ContraAccGUID)   
			   SELECT  @enNumber ,  
				   @DATE,  
				   MustCashedAmount,  
				   0,  
				   @Note,  
				   CurrencyVal,   
				   @entryGUID ,  
				   @CashAccGUID,  
				   CurrencyGUID,   
				   @CostGuid,  
				   0x00   
			   FROM trnTransferVoucher000   
		 	   WHERE GUID = @TransferGUID  
		UNION  
			  SELECT   @enNumber + 1,  
				   @DATE,  
				   0 ,  
				   MustCashedAmount - NetWages,  
				   @Note,  
 				   CurrencyVal,   
				   @entryGUID ,  
	  			   @tmpAccGuid , -- Õ”«» ÕÊ«·«  „ﬁ»Ê÷…   
				   CurrencyGUID,   
				   @CostGuid,  
				   0x00   
			   FROM trnTransferVoucher000   
		 	   WHERE GUID = @TransferGUID  
 

			INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,  
				   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,  
				   CostGUID, ContraAccGUID)   
			SELECT     @enNumber + 2,  
				   @DATE,  
				   0 ,  
				   Wages - DestBranchWages, 
				   @Note,  
 				   CurrencyVal,   
				   @entryGUID ,  
	  			   @SourceWagesAccGUID,  
				   CurrencyGUID,   
				   @CostGuid,  
				   0x00   
			   FROM trnTransferVoucher000   
		 	   WHERE GUID = @TransferGUID	
			
			IF (@DestBranchWages > 0)
			BEGIN
				INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,  
					   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,  
					   CostGUID, ContraAccGUID)   
				SELECT     @enNumber + 3,  
					   @DATE,  
					   0,  
					   DestBranchWages, 
					   @Note,  
		 			   ExchangeCurrencyVal,   
					   @entryGUID ,  
	  				   @TmpWagesAccGuid,  
					   ExchangeCurrency,   
					   @CostGuid,  
					   0x00   
				   FROM trnTransferVoucher000   
		 		   WHERE GUID = @TransferGUID			
			END

		SET @NewState = 2 -- „ﬁ»Ê÷… „‰ «·„—”·   
		SET @ProcType = 4 -- ﬁ»÷   
		-- ≈÷«›… «·Õ”„Ì«  Ê «·≈÷«›«  ≈·Ï «·ﬁÌœ «·„Ê·œ  
		SET @enNumber = @enNumber + 4   
		Update trntransfervoucher000   
		SET Cashed = 1   
		WHERE Guid = @TransferGUID  
	  
	--≈–« ﬁ»÷ ‰⁄œ· ›Ì «·≈Ì’«· »ÕÌÀ Ì „  Œ“Ì‰ Õ”«» ’‰œÊﬁ «·›—⁄ «·–Ì ﬁ»÷   
		UPDATE TrnTransferVoucher000   
		SET CashAccGuid = @CashAccGUID   
		WHERE Guid = @TransferGUID   
	  
	END -- ‰Â«Ì…  Ê·Ìœ ”‰œ «·ﬁ»÷   
	----------------------------------------------------------------------------  
	ELSE IF @TrEntryType = 501 --  Ê·Ìœ ”‰œ «·œ›⁄  
	BEGIN  
	IF @SourceType = 2 --  Ê·Ìœ ”‰œ «·œ›⁄  
	BEGIN  
		INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,  
				   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,  
	 			   CostGUID, ContraAccGUID)   
   
		--„‰ Õ”«» ÕÊ«·«  „” ·„… »⁄„·… «· ”·Ì„   
		-- ≈·Ï Õ”«» «·’‰œÊﬁ »⁄„·… «· ”·Ì„   
		Select  @enNumber ,  
			   @Date,  
			   MustPaidAmount,  
			   0,  
			   @Note,  
			   @PayCurrencyVal,  
			   @entryGUID ,  
			   @tmpAccGuid ,
			   @PayCurrency,  
			   @CostGuid,  
			   0x00   
		FROM trnTransferVoucher000   
	 	WHERE GUID = @TransferGUID		  
	
		UNION
			Select   @enNumber + 1  ,  
			   @Date,  
			   0,  
			   MustPaidAmount,  
			   @Note,  
			   @PayCurrencyVal ,  
			   @entryGUID ,  
			   @CashAccGUID,  
			   @PayCurrency,  
			   @CostGuid,  
			   0x00   
		FROM trnTransferVoucher000   
		WHERE GUID = @TransferGUID  

		IF (@DestBranchWages > 0)
		BEGIN
			INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,  
				   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,  
				   CostGUID, ContraAccGUID)   
			SELECT     @enNumber + 2,  
				   @Date,  
				   DestBranchWages, 
				   0,	
				   @Note,  
		 		   ExchangeCurrencyVal,   
				   @entryGUID ,  
	  			   @TmpWagesAccGuid,  
				   ExchangeCurrency,   
				   @CostGuid,  
				   0x00   
			FROM trnTransferVoucher000   
		 	WHERE GUID = @TransferGUID			

			UNION
			SELECT     @enNumber + 3,  
				   @Date,  
				   0,  
				   DestBranchWages, 
				   @Note,  
		 		   CurrencyVal,   
				   @entryGUID ,  
	  			   @DestWagesAccGUID,  
				   CurrencyGUID,   
				   @CostGuid,  
				   0x00   
			FROM trnTransferVoucher000   
		 	WHERE GUID = @TransferGUID			
		END
	END
	ELSE 
	IF @SourceType = 1
	BEGIN	
		INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,  
				   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,  
	 			   CostGUID, ContraAccGUID)   
   
   		SELECT  @enNumber ,  
			   @DATE,  
			   MustPaidAmount + DestBranchWages,  
			   0,  
			   @Note,  
			   @PayCurrencyVal,  
			   @entryGUID ,  
			   @SourceAccGuid,
			   @PayCurrency,  
			   @CostGuid,  
			   0x00   
		FROM trnTransferVoucher000   
	 	WHERE GUID = @TransferGUID		  
	
		UNION
			SELECT   @enNumber + 1  ,  
			   @DATE,  
			   0,  
			   MustPaidAmount,  
			   @Note,  
			   @PayCurrencyVal ,  
			   @entryGUID ,  
			   @CashAccGUID,  
			   @PayCurrency,  
			   @CostGuid,  
			   @SourceAccGuid   
		FROM trnTransferVoucher000   
		WHERE GUID = @TransferGUID  
		IF (@DestBranchWages > 0)
		BEGIN
			INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,  
				   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,  
				   CostGUID, ContraAccGUID)   
			SELECT     @enNumber + 2,  
				   @DATE,  
				   0,  
				   DestBranchWages, 
				   @Note,  
		 		   CurrencyVal,   
				   @entryGUID ,  
	  			   @DestWagesAccGUID,  
				   CurrencyGUID,   
				   @CostGuid,  
				   @SourceAccGuid   
			FROM trnTransferVoucher000   
		 	WHERE GUID = @TransferGUID			
		END
	END
		SET @NewState = 8 -- „œ›Ê⁄… ··„” ·„   
		SET @ProcType = 8 -- œ›⁄  		  

		UPDATE trntransfervoucher000  
		SET paid = 1   
		WHERE Guid = @TransferGUID  
		  
	END  
	ELSE IF  @TrEntryType = 504 --  Ê·Ìœ ﬁÌœ ≈ﬁ›«· 	
	BEGIN
		
	INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,  
				   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,  
	 			   CostGUID, ContraAccGUID)   
   
		--„‰ Õ”«» ÕÊ«·«  „” ·„… »⁄„·… «· ”·Ì„   
		-- ≈·Ï Õ”«» «·’‰œÊﬁ »⁄„·… «· ”·Ì„   
		SELECT  @enNumber ,  
			   @DATE,  
			   MustPaidAmount,  
			   0,  
			   @Note,  
			   @PayCurrencyVal,  
			   @entryGUID ,  
			   @tmpAccGuid ,
			   @PayCurrency,  
			   @CostGuid,  
			   0x00   
		FROM trnTransferVoucher000   
	 	WHERE GUID = @TransferGUID		  
	
		UNION
			SELECT   @enNumber + 1,  
			   @DATE,  
			   0,  
			   MustPaidAmount,  
			   @Note,  
			   @PayCurrencyVal ,  
			   @entryGUID ,  
			   @DestAccGUID,  
			   @PayCurrency,  
			   @CostGuid,  
			   @tmpAccGuid   
		FROM trnTransferVoucher000   
		WHERE GUID = @TransferGUID  
			
		IF (@DestBranchWages > 0)
		BEGIN
			INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,  
				   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,  
				   CostGUID, ContraAccGUID)   
			SELECT     @enNumber + 2,  
				   @DATE,  
				   DestBranchWages, 
				   0,	
				   @Note,  
		 		   ExchangeCurrencyVal,   
				   @entryGUID ,  
	  			   @TmpWagesAccGuid,  
				   ExchangeCurrency,   
				   @CostGuid,  
				   @DestWagesAccGUID   
			FROM trnTransferVoucher000   
		 	WHERE GUID = @TransferGUID			

			UNION
			SELECT     @enNumber + 3,  
				   @DATE,  
				   0,  
				   DestBranchWages, 
				   @Note,  
		 		   CurrencyVal,   
				   @entryGUID ,  
	  			   @DestWagesAccGUID,  
				   CurrencyGUID,   
				   @CostGuid,  
				   @TmpWagesAccGuid   
			FROM trnTransferVoucher000   
		 	WHERE GUID = @TransferGUID			
		END
	
		SET @NewState = 9 -- „ﬁ›·… „‰ ﬁ»· «·„—”·   
		SET @ProcType = 9 -- «·ÕÊ«·… „ﬁ›·…

		UPDATE trntransfervoucher000  
		SET Closed = 1   
		WHERE Guid = @TransferGUID  
		
	END
	
	--ELSE IF @TrEntryType = 502 --  Ê·Ìœ ”‰œ ≈—Ã«⁄ 
	--BEGIN 
		---- „‰ Õ”«» ÕÊ«·«  „” ·„… »⁄„·… «· ”·Ì„  
		---- ≈·Ï Õ”«» «·›—⁄ «·„—”·  «·„»·€ + «·√Ã— »⁄„·… «· Õ—Ìﬂ  
		 
		--SELECT @returnWagesFlag = Cast(value as bit) 
		--FROM op000  
		--WHERE NAME = 'TrnCfg_ReturnWages_t' 
		--SET @returnWages = ISNULL(@returnWages,0) 
		 
		--INSERT INTO en000 (Number, DATE, Debit, Credit, Notes, 
				   --CurrencyVal, ParentGUID, accountGUID, CurrencyGUID, 
				   --CostGUID, ContraAccGUID)  
		 
				   --SELECT  @enNumber , 
				   --@DATE, 
				   --MustPaidAmount  , 
				   --0 , 
				   --@Note, 
				   --@PayCurrencyVal, 
				   --@entryGUID ,  
				   --@tmpPaidAccGuid,	
				   --@PayCurrency, 
				   --0x00, 
				   --0x00  
			   --FROM trnTransferVoucher000  
		 	   --WHERE GUID = @TransferGUID 
		--Union 
			   	   --SELECT  @enNumber + 1 , 
				   --@DATE, 
				   --0, 
				  --MustPaidAmount,	---(MustPaidAmount + (NetWages * @SourceWages / 100)) , 
				   --@Note, 
				   --@ExchangeCurrencyVal, 
				   --@entryGUID , 
				   --@SourceAccGuid , -- Õ”«» «·›—⁄ «·„—”·  
				   --@ExchangeCurrency, 
				   --0x00, 
				   --0x00  
			   --FROM trnTransferVoucher000  
		 	   --WHERE GUID = @TransferGUID 
		 	    
				 
		--/** NOTE TO MODIFY *****************************************************************/				 
	 	---- calculate return wages FROM returnTypeGuid  
	 	---- AND THEN apply it in  following query 
		--/* 
		--DECLARE @ReturnTrType uniqueidentifier  
		 
		--SELECT @ReturnTrType = ReturnTrType  
		--FROM trnTransferTypes000  
		--WHERE guid = @TransferType 
		 
		 
		--IF @returnWagesFlag = 1  
		--BEGIN  
			--INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes, 
				   --CurrencyVal, ParentGUID, accountGUID, CurrencyGUID, 
				   --CostGUID, ContraAccGUID)  
			--SELECT     @enNumber + 2 , 
				   --@DATE, 
				   --@returnWages, 
				   --0, 
				   --@Note, 
				   --CurrencyVal, 
				   --@entryGUID , 
				   --@CashAccGUID , -- Õ”«» «·’‰œÊﬁ 
				   --CurrencyGUID, 
				   --0x00, 
				   --0x00  
			   --FROM trnTransferVoucher000  
		 	   --WHERE GUID = @TransferGUID 
		--END 
		--*/ 
		--SET @NewState = 7 --  „ ≈—Ã«⁄Â«  
		--SET @ProcType = 7 -- ≈—Ã«⁄   
		--Update trntransfervoucher000  
		--SET IsReturned = 1  
		--WHERE Guid = @TransferGUID 
	 
	--END 
	----------------------------------------------------------------------------  
	IF @TrEntryType = 503 --  Ê·Ìœ ”‰œ «·ﬁ»÷ «·¬Ã·   
	BEGIN  

		SET @NewState = 2 -- „ﬁ»Ê÷… „‰ «·„—”·   
		SET @ProcType = 4 -- ﬁ»÷   
		-- ≈÷«›… «·Õ”„Ì«  Ê «·≈÷«›«  ≈·Ï «·ﬁÌœ «·„Ê·œ  
		SET @enNumber = @enNumber + 3   
		Update trntransfervoucher000   
		SET Cashed = 1   
		WHERE Guid = @TransferGUID  
	  
	--≈–« ﬁ»÷ ‰⁄œ· ›Ì «·≈Ì’«· »ÕÌÀ Ì „  Œ“Ì‰ Õ”«» ’‰œÊﬁ «·›—⁄ «·–Ì ﬁ»÷   
		UPDATE TrnTransferVoucher000   
		SET CashAccGuid = @CashAccGUID   
		WHERE Guid = @TransferGUID   
	  
	END -- ‰Â«Ì…  Ê·Ìœ ”‰œ «·ﬁ»÷   
	ELSE IF @TrEntryType = 506 --  Ê·Ìœ ”‰œ «·≈—Ã«⁄ «·¬‰Ì   
	BEGIN   
			INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,  
				   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,  
				   CostGUID, ContraAccGUID)   

			   SELECT  @enNumber + 1,  
				   @DATE,  
				   0,
				   MustCashedAmount,  
				   @Note,  
				   CurrencyVal,   
				   @entryGUID ,  
				   @CashAccGUID,  
				   CurrencyGUID,   
				   @CostGuid,  
				   0x00   
			   FROM trnTransferVoucher000   
		 	   WHERE GUID = @TransferGUID  
		UNION  
			  SELECT   @enNumber,  
				   @DATE,  
				   MustCashedAmount - NetWages,
				   0,  
				   @Note,  
 				   CurrencyVal,   
				   @entryGUID ,  
	  			   @tmpAccGuid , 
				   CurrencyGUID,   
				   @CostGuid,  
				   0x00   
			   FROM trnTransferVoucher000   
		 	   WHERE GUID = @TransferGUID  


			INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,  
				   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,  
				   CostGUID, ContraAccGUID)   
			SELECT     @enNumber + 2,  
				   @DATE,  
				   Wages - DestBranchWages, 
				   0 ,  
				   @Note,  
 				   CurrencyVal,   
				   @entryGUID ,  
	  			   @SourceWagesAccGUID,  
				   CurrencyGUID,   
				   @CostGuid,  
				   0x00   
			   FROM trnTransferVoucher000   
		 	   WHERE GUID = @TransferGUID	
			
			IF (@DestBranchWages > 0)
			BEGIN
				INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,  
					   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,  
					   CostGUID, ContraAccGUID)   
				SELECT     @enNumber + 3,  
					   @DATE,  
					   DestBranchWages, 
					   0,
					   @Note,  
		 			   ExchangeCurrencyVal,   
					   @entryGUID ,  
	  				   @TmpWagesAccGuid,  
					   ExchangeCurrency,   
					   @CostGuid,  
					   0x00   
				   FROM trnTransferVoucher000   
		 		   WHERE GUID = @TransferGUID			
			END
			SET @NewState = 2 -- „ﬁ»Ê÷… „‰ «·„—”·   
			SET @ProcType = 4 -- ﬁ»÷   
			-- ≈÷«›… «·Õ”„Ì«  Ê «·≈÷«›«  ≈·Ï «·ﬁÌœ «·„Ê·œ  
			SET @enNumber = @enNumber + 3   
			Update trntransfervoucher000   
			SET Cashed = 1   
			WHERE Guid = @TransferGUID  
		  
		--≈–« ﬁ»÷ ‰⁄œ· ›Ì «·≈Ì’«· »ÕÌÀ Ì „  Œ“Ì‰ Õ”«» ’‰œÊﬁ «·›—⁄ «·–Ì ﬁ»÷   
			UPDATE TrnTransferVoucher000   
			SET CashAccGuid = @CashAccGUID   
			WHERE Guid = @TransferGUID   
  
		SET @NewState = 4 -- „— Ã⁄… ¬‰Ì«   
		SET @ProcType = 5 -- ≈—Ã«⁄ ¬‰Ì   
		Update trntransfervoucher000 SET IsReturned = 2 WHERE Guid = @TransferGUID  
	END  
	ELSE IF @TrEntryType = 520 --  Ê·Ìœ ﬁÌœ «··≈·€«¡
	BEGIN   
	
		INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,  
				   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,  
				   CostGUID, ContraAccGUID)   
			   SELECT  @enNumber ,  
				   @DATE,  
				   0,
				   MustCashedAmount,  
				   @Note,  
				   CurrencyVal,   
				   @entryGUID ,  
				   @CashAccGUID,  
				   CurrencyGUID,   
				   @CostGuid,  
				   0x00   
			   FROM trnTransferVoucher000   
		 	   WHERE GUID = @TransferGUID  
		UNION  
			  SELECT   @enNumber + 1,  
				   @DATE,  
				   MustCashedAmount - NetWages,  
				   0,
				   @Note,  
 				   CurrencyVal,   
				   @entryGUID ,  
	  			   @tmpAccGuid , -- Õ”«» ÕÊ«·«  „ﬁ»Ê÷…   
				   CurrencyGUID,   
				   @CostGuid,  
				   0x00   
			   FROM trnTransferVoucher000   
		 	   WHERE GUID = @TransferGUID  
 

			INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,  
				   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,  
				   CostGUID, ContraAccGUID)   
			SELECT     @enNumber + 2,  
				   @DATE,  
				   Wages - DestBranchWages, 
				   0,
				   @Note,  
 				   CurrencyVal,   
				   @entryGUID ,  
	  			   @SourceWagesAccGUID,  
				   CurrencyGUID,   
				   @CostGuid,  
				   0x00   
			   FROM trnTransferVoucher000   
		 	   WHERE GUID = @TransferGUID	
			
			IF (@DestBranchWages > 0)
			BEGIN
				INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,  
					   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,  
					   CostGUID, ContraAccGUID)   
				SELECT     @enNumber + 3,  
					   @DATE,  
					   DestBranchWages, 
					   0,	
					   @Note,  
		 			   ExchangeCurrencyVal,   
					   @entryGUID ,  
	  				   @TmpWagesAccGuid,  
					   ExchangeCurrency,   
					   @CostGuid,  
					   0x00   
				   FROM trnTransferVoucher000   
		 		   WHERE GUID = @TransferGUID			
			END
			SET @NewState = 2 -- „ﬁ»Ê÷… „‰ «·„—”·   
			SET @ProcType = 4 -- ﬁ»÷   
			-- ≈÷«›… «·Õ”„Ì«  Ê «·≈÷«›«  ≈·Ï «·ﬁÌœ «·„Ê·œ  
			SET @enNumber = @enNumber + 3   
			
			--Update trntransfervoucher000   
			--SET Cashed = 1   
			--WHERE Guid = @TransferGUID  
		  
		----≈–« ﬁ»÷ ‰⁄œ· ›Ì «·≈Ì’«· »ÕÌÀ Ì „  Œ“Ì‰ Õ”«» ’‰œÊﬁ «·›—⁄ «·–Ì ﬁ»÷   
			--UPDATE TrnTransferVoucher000   
			--SET CashAccGuid = @CashAccGUID   
			--WHERE Guid = @TransferGUID   
  
		--SET @NewState = 4 -- „— Ã⁄… ¬‰Ì«   
		--SET @ProcType = 5 -- ≈—Ã«⁄ ¬‰Ì   
		--Update trntransfervoucher000 SET IsReturned = 2 WHERE Guid = @TransferGUID  
	END  

	IF @wageType != 0x00   
	IF @TrEntryType = 500 OR @TrEntryType = 503 OR @TrEntryType = 506  
	BEGIN   
		  
		IF @DiscVal != 0   
		BEGIN   
			-- ﬁ·„ Õ”«» «·Õ”„Ì«  ›Ì «·›—⁄ «·„—”·  
			INSERT INTO en000 (Number, DATE, Debit, Credit, Notes,   
					   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,  
					   CostGUID, ContraAccGUID)   
				SELECT   
					@enNumber,   
					@DATE,   
					CASE @TrEntryType WHEN 506 THEN 0 ELSE @DiscVal END,  
					CASE @TrEntryType WHEN 506 THEN @DiscVal ELSE 0 END,  
					Code,   
					CurrencyVal,   
					@entryGUID,   
					@DiscAcc,   
					CurrencyGUID,   
					@CostGuid,  
					0x0   
				FROM trnTransferVoucher000   
				WHERE GUID = @TransferGUID   
			SET @enNumber = @enNumber + 1   
		END   
		  
		IF @ExtraVal != 0   
		BEGIN   
			-- ﬁ·„ Õ”«» «·≈÷«›«  ›Ì «·›—⁄ «·„—”·  
			INSERT INTO en000 (Number, DATE, Debit, Credit, Notes,  
					   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,  
					   CostGUID, ContraAccGUID)   
				SELECT   
					@enNumber,   
					@DATE,   
					CASE @TrEntryType WHEN 506 THEN @ExtraVal ELSE 0 END,  
					CASE @TrEntryType WHEN 506 THEN 0 ELSE @ExtraVal END,  
					Code,   
					CurrencyVal,   
					@entryGUID,   
					@ExtraAcc,   
					CurrencyGUID,   
					@CostGuid,   
					0x0   
				FROM trnTransferVoucher000   
				WHERE GUID = @TransferGUID   
			SET @enNumber = @enNumber + 1  
		END 		  
	END  
	--  Ê“Ì⁄ ﬁÌ„… «·Õ”«» ⁄·Ï «·Õ”«»«  «·√»‰«¡ ›Ì Õ«· ﬂ«‰ «·Õ”«»  Ê“Ì⁄Ì   
	WHILE EXISTS(SELECT * FROM en000 e INNER JOIN ac000 a ON e.accountGuid = a.guid WHERE e.parentGuid = @entryGUID AND a.type = 8)   
	BEGIN   
		--  ⁄·Ì„ «·ﬁÌÊœ «·„— »ÿ… »Õ”«»«   Ê“Ì⁄Ì… »ﬁÌ„ ”«·»…   
		UPDATE en000 SET number = - e.number   
		FROM en000 e INNER JOIN ac000 a ON e.accountGuid = a.guid   
		WHERE e.parentGuid = @entryGuid AND a.type = 8   
		   
		-- INSERT distributives detailes:   
		INSERT INTO en000 (Number, DATE, Debit, Credit, Notes, CurrencyVal, ParentGUID, accountGUID, CurrencyGUID, CostGUID, ContraAccGUID)   
			SELECT 	- e.number, -- this is called unmarking.   
				e.DATE,   
				e.debit * c.num2 / 100,   
				e.credit * c.num2 / 100,   
				e.notes,   
				e.currencyVal,   
				e.parentGUID,   
				c.sonGuid,--e.accountGUID,   
				e.currencyGUID,   
				e.costGUID,   
				e.contraAccGUID   
			FROM en000 e INNER JOIN ac000 a ON e.accountGuid = a.guid  
				 INNER JOIN ci000 c ON a.guid = c.parentGuid   
			WHERE e.parentGuid = @entryGuid AND a.type = 8   
		   
		-- Õ–› «·ﬁÌÊœ «·√’·Ì… »Õﬂ„ √‰ «·ﬁÌÊœ  Ê“⁄  ⁄·Ï «·Õ”«»«  «·√»‰«¡   
		DELETE en000 WHERE parentGuid = @entryGuid AND number < 0   
		-- continue looping untill no distributive accounts are found   
		-- in the currently generated entry @entryGuid  
	END   
	--  —ÕÌ· «·ﬁÌœ   
	UPDATE ce000 SET IsPosted = 1 WHERE GUID = @entryGUID    
	-- —Ìÿ «·ﬁÌœ „⁄ √’·Â  
	DECLARE @trnNumber Int   
	SELECT @trnNumber = number FROM trntransfervoucher000 WHERE guid = @TransferGUID  
	INSERT INTO er000 (EntryGUID, ParentGUID, ParentType, ParentNumber)   
	VALUES(@entryGUID, @TransferGUID, @TrEntryType, @trnNumber)    
      
	-- return data about generated entry    
	SELECT @entryGUID as EntryGuid , @entryNum  as EntryNumber  
	--  €Ì— Õ«·… «·ÕÊ«·…   
	EXEC prcTrnSetVoucherState @TransferGUID, @NewState , @ProcType , @entryGUID , 1/*Entry , 2 voucher*/  
	COMMIT TRAN   

#############################################
#END
