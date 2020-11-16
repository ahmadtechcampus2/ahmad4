######################################################
CREATE PROC  prcTransfer_genEntry
	@TransferGUID 			UNIQUEIDENTIFIER, -- �������  
	@CashAccGUID			UNIQUEIDENTIFIER,-- ����� ��������   
	-- 500 ����� ��� ����� ������  
	-- 501 ����� ��� �����  
	-- 502 ����� ��� �������  
	-- 503 ����� ��� ���  
	-- 504 ����� ��� �������
	-- 506 ����� ��� 
	-- 520 ����� �������
	@TrEntryType 		INT, 
	@CostGuid				UNIQUEIDENTIFIER,-- ���� ������ 
	@CurrentBranch		UNIQUEIDENTIFIER = 0x0 
AS    
	SET NOCOUNT ON   
	BEGIN TRAN   
	DECLARE   
        @SourceType 		int, 
		@DestType		int, 
		@RatioType 		UNIQUEIDENTIFIER, -- ��� ����� �����   
		@wageType 		UNIQUEIDENTIFIER, -- ���  �����   
		@entryGUID 		UNIQUEIDENTIFIER, -- ����� ���� ��� ����   
		@entryNum 		INT , -- ��� ����� ������   
		@branchGUID 	UNIQUEIDENTIFIER, -- ����� ������  
		@DifferentAccGUID	UNIQUEIDENTIFIER,  
		@SourceWagesAccGUID	UNIQUEIDENTIFIER, --���� ���� ����� ������ 	-- debit   
		@DestWagesAccGUID	UNIQUEIDENTIFIER, --���� ���� ����� ������ ���� 	-- credit   
		@DestAccGUID		UNIQUEIDENTIFIER, --���� ����� ������ ����	-- credit   
		@SourceAccGuid 		UNIQUEIDENTIFIER, -- ���� ����� ������   
		@CompanyAcc			UNIQUEIDENTIFIER, --���� ���� ������ ������	-- credit   
		  
		@SourceWages	FLOAT, -- ����� �� ����� ��� �������� ���� ����� ������   
		@DestWages		FLOAT,-- ����� �� ����� ��� �������� ���� ����� ������ ����   
		@CompanyWages	FLOAT, -- ����� �� ����� ��� �������� ���� ������ ������   
		@DiscAcc		UNIQUEIDENTIFIER,---���� ������� ����� �� ��� ��������   
		@ExtraAcc		UNIQUEIDENTIFIER, -- ���� ������ ����� �� ��� ��������   
		@DiscVal		FLOAT,			--���� �����   
		@ExtraVal		FLOAT,			-- ���� ��������   
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
	SET @NewState = 0 -- ���� ������� �������  
	SET @ProcType = 0 -- ��� ���������   

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
		WHEN @TrEntryType = 500/*���*/ THEN @AmnBranchSource 
		WHEN @TrEntryType = 501/*���*/ THEN @AmnBranchDest 
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

	SET @Note = ' ����� '
			 
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
		SET @Note ='��� *' + @Note   
	ELSE IF	@TrEntryType = 501  
		SET @Note ='��� *' + @Note   
	 
	
	--  ������ �������� ��������� ����� ������   
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

	-- ����� ��� ����� ������� ��� ������ � �������� � ������ �������  
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
				WHEN @TrEntryType = 500/*���*/ THEN MustCashedAmount   
				WHEN @TrEntryType = 501/*���*/ THEN MustPaidAmount   
				ELSE MustPaidAmount	END,   
			CASE    
				WHEN @TrEntryType = 500/*���*/ THEN MustCashedAmount    
				WHEN @TrEntryType = 501/*���*/ THEN MustPaidAmount    
				ELSE MustPaidAmount	END,   
			@Note,   
			CASE   
				WHEN @TrEntryType = 500/*���*/ THEN @BaseCurrencyVal  
				WHEN @TrEntryType = 501/*���*/ THEN @BaseCurrencyVal  
				ELSE CurrencyVal	END,   
			0,   
			Security, 
			@branchGUID,  
			@entryGUID,   
 			CASE   
				WHEN @TRENTRYTYPE = 500/*���*/ THEN @BASECURRENCY  
 				WHEN @TRENTRYTYPE = 501/*���*/ THEN @BASECURRENCY  
 				ELSE CURRENCYGUID	END			  
		FROM trnTransferVoucher000   
		WHERE GUID = @TransferGUID   
	DECLARE @enNumber Int   
	SELECT @enNumber = 0   
	----------------------------------------------------------------------------  
	IF @TrEntryType = 500 -- ����� ��� �����   
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
	  			   @tmpAccGuid , -- ���� ������ ������   
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

		SET @NewState = 2 -- ������ �� ������   
		SET @ProcType = 4 -- ���   
		-- ����� �������� � �������� ��� ����� ������  
		SET @enNumber = @enNumber + 4   
		Update trntransfervoucher000   
		SET Cashed = 1   
		WHERE Guid = @TransferGUID  
	  
	--��� ��� ���� �� ������� ���� ��� ����� ���� ����� ����� ���� ���   
		UPDATE TrnTransferVoucher000   
		SET CashAccGuid = @CashAccGUID   
		WHERE Guid = @TransferGUID   
	  
	END -- ����� ����� ��� �����   
	----------------------------------------------------------------------------  
	ELSE IF @TrEntryType = 501 -- ����� ��� �����  
	BEGIN  
	IF @SourceType = 2 -- ����� ��� �����  
	BEGIN  
		INSERT INTO en000 ([Number], [Date], [Debit], [Credit], Notes,  
				   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,  
	 			   CostGUID, ContraAccGUID)   
   
		--�� ���� ������ ������ ����� �������   
		-- ��� ���� ������� ����� �������   
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
		SET @NewState = 8 -- ������ �������   
		SET @ProcType = 8 -- ���  		  

		UPDATE trntransfervoucher000  
		SET paid = 1   
		WHERE Guid = @TransferGUID  
		  
	END  
	ELSE IF  @TrEntryType = 504 -- ����� ��� ����� 	
	BEGIN
		
	INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,  
				   CurrencyVal, ParentGUID, accountGUID, CurrencyGUID,  
	 			   CostGUID, ContraAccGUID)   
   
		--�� ���� ������ ������ ����� �������   
		-- ��� ���� ������� ����� �������   
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
	
		SET @NewState = 9 -- ����� �� ��� ������   
		SET @ProcType = 9 -- ������� �����

		UPDATE trntransfervoucher000  
		SET Closed = 1   
		WHERE Guid = @TransferGUID  
		
	END
	
	--ELSE IF @TrEntryType = 502 -- ����� ��� ����� 
	--BEGIN 
		---- �� ���� ������ ������ ����� �������  
		---- ��� ���� ����� ������  ������ + ����� ����� �������  
		 
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
				   --@SourceAccGuid , -- ���� ����� ������  
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
				   --@CashAccGUID , -- ���� ������� 
				   --CurrencyGUID, 
				   --0x00, 
				   --0x00  
			   --FROM trnTransferVoucher000  
		 	   --WHERE GUID = @TransferGUID 
		--END 
		--*/ 
		--SET @NewState = 7 -- �� �������  
		--SET @ProcType = 7 -- �����   
		--Update trntransfervoucher000  
		--SET IsReturned = 1  
		--WHERE Guid = @TransferGUID 
	 
	--END 
	----------------------------------------------------------------------------  
	IF @TrEntryType = 503 -- ����� ��� ����� �����   
	BEGIN  

		SET @NewState = 2 -- ������ �� ������   
		SET @ProcType = 4 -- ���   
		-- ����� �������� � �������� ��� ����� ������  
		SET @enNumber = @enNumber + 3   
		Update trntransfervoucher000   
		SET Cashed = 1   
		WHERE Guid = @TransferGUID  
	  
	--��� ��� ���� �� ������� ���� ��� ����� ���� ����� ����� ���� ���   
		UPDATE TrnTransferVoucher000   
		SET CashAccGuid = @CashAccGUID   
		WHERE Guid = @TransferGUID   
	  
	END -- ����� ����� ��� �����   
	ELSE IF @TrEntryType = 506 -- ����� ��� ������� �����   
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
			SET @NewState = 2 -- ������ �� ������   
			SET @ProcType = 4 -- ���   
			-- ����� �������� � �������� ��� ����� ������  
			SET @enNumber = @enNumber + 3   
			Update trntransfervoucher000   
			SET Cashed = 1   
			WHERE Guid = @TransferGUID  
		  
		--��� ��� ���� �� ������� ���� ��� ����� ���� ����� ����� ���� ���   
			UPDATE TrnTransferVoucher000   
			SET CashAccGuid = @CashAccGUID   
			WHERE Guid = @TransferGUID   
  
		SET @NewState = 4 -- ������ ����   
		SET @ProcType = 5 -- ����� ���   
		Update trntransfervoucher000 SET IsReturned = 2 WHERE Guid = @TransferGUID  
	END  
	ELSE IF @TrEntryType = 520 -- ����� ��� ��������
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
	  			   @tmpAccGuid , -- ���� ������ ������   
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
			SET @NewState = 2 -- ������ �� ������   
			SET @ProcType = 4 -- ���   
			-- ����� �������� � �������� ��� ����� ������  
			SET @enNumber = @enNumber + 3   
			
			--Update trntransfervoucher000   
			--SET Cashed = 1   
			--WHERE Guid = @TransferGUID  
		  
		----��� ��� ���� �� ������� ���� ��� ����� ���� ����� ����� ���� ���   
			--UPDATE TrnTransferVoucher000   
			--SET CashAccGuid = @CashAccGUID   
			--WHERE Guid = @TransferGUID   
  
		--SET @NewState = 4 -- ������ ����   
		--SET @ProcType = 5 -- ����� ���   
		--Update trntransfervoucher000 SET IsReturned = 2 WHERE Guid = @TransferGUID  
	END  

	IF @wageType != 0x00   
	IF @TrEntryType = 500 OR @TrEntryType = 503 OR @TrEntryType = 506  
	BEGIN   
		  
		IF @DiscVal != 0   
		BEGIN   
			-- ��� ���� �������� �� ����� ������  
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
			-- ��� ���� �������� �� ����� ������  
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
	-- ����� ���� ������ ��� �������� ������� �� ��� ��� ������ ������   
	WHILE EXISTS(SELECT * FROM en000 e INNER JOIN ac000 a ON e.accountGuid = a.guid WHERE e.parentGuid = @entryGUID AND a.type = 8)   
	BEGIN   
		-- ����� ������ �������� ������� ������� ���� �����   
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
		   
		-- ��� ������ ������� ���� �� ������ ����� ��� �������� �������   
		DELETE en000 WHERE parentGuid = @entryGuid AND number < 0   
		-- continue looping untill no distributive accounts are found   
		-- in the currently generated entry @entryGuid  
	END   
	-- ����� �����   
	UPDATE ce000 SET IsPosted = 1 WHERE GUID = @entryGUID    
	-- ��� ����� �� ����  
	DECLARE @trnNumber Int   
	SELECT @trnNumber = number FROM trntransfervoucher000 WHERE guid = @TransferGUID  
	INSERT INTO er000 (EntryGUID, ParentGUID, ParentType, ParentNumber)   
	VALUES(@entryGUID, @TransferGUID, @TrEntryType, @trnNumber)    
      
	-- return data about generated entry    
	SELECT @entryGUID as EntryGuid , @entryNum  as EntryNumber  
	-- ���� ���� �������   
	EXEC prcTrnSetVoucherState @TransferGUID, @NewState , @ProcType , @entryGUID , 1/*Entry , 2 voucher*/  
	COMMIT TRAN   

#############################################
#END
