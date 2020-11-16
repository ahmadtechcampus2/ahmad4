####################################################################
CREATE FUNCTION fnGetAccountTopCustomer
(@AccountGuid UNIQUEIDENTIFIER )
RETURNS UNIQUEIDENTIFIER
AS BEGIN
DECLARE		
		@CustomerAcc	[UNIQUEIDENTIFIER]
		SELECT TOP 1 @CustomerAcc = GUID FROM cu000 WHERE [AccountGUID] = @AccountGuid	

	RETURN ISNULL(@CustomerAcc, 0x0)
END
####################################################################
CREATE PROC TrnGenCloseCashierEntry_Debit
	@CloseGuid UNIQUEIDENTIFIER, 
	@entryNum INT,
	/*
		1 Add new Exchange
		2 Update old Exchange
		3 Maintain Exchange 
	*/
	@OperationType INT = 1,
	@EnNotePrefix	NVARCHAR(50) = ''
AS  
	SET NOCOUNT ON 
	DECLARE  
		@costguid uniqueidentifier, 
		@ExchangeAcc uniqueidentifier,
		@AccGUID UNIQUEIDENTIFIER,
		@defaultCur UNIQUEIDENTIFIER, 
		@DATE	DATETIME, 
		@enNumber  INT, 
		@entryGuid UNIQUEIDENTIFIER,
		@GroupCurrencyAccount UNIQUEIDENTIFIER,--»ÿ«ﬁ… ’‰«œÌﬁ «·⁄„·«  «·„Õœœ… ›Ì ‰„ÿ «·’—«›…
		@BasicGroupCurrencyAccount UNIQUEIDENTIFIER,--»ÿ«ﬁ… ’‰«œÌﬁ «·⁄„·«  «·—∆Ì”Ì… «·„Õœœ… ›Ì ‰„ÿ «·’—«›…
		@Notes NVARCHAR(250)
		
	SELECT
		@costguid = t.CostGuid,
		@AccGUID = c.AccountGuid,
		@ExchangeAcc = t.ExchangeAcc,
		@DATE = c.[DATE],
		@GroupCurrencyAccount = t.GroupCurrencyAccGUID,
		@BasicGroupCurrencyAccount = t.MngerGroupCurrencyAccGUID,
		@Notes = C.Notes
	FROM TrnCloseCashier000 AS c
	INNER JOIN TrnExchangeTypes000 AS t ON t.Guid = c.ExchangeTypeGuid
	WHERE c.guid = @CloseGuid
	
	Declare @isGenEntriesAccordingToUserAccounts BIT
	SELECT @isGenEntriesAccordingToUserAccounts = CAST(value AS BIT) FROM op000 WHERE name = 'TrnCfg_Exchange_GenEntriesAccordingToUserAccounts'
	IF (ISNULL(@isGenEntriesAccordingToUserAccounts, 0) <> 0)
	BEGIN
		SELECT
			@costguid = t.CostGuid,
			@GroupCurrencyAccount = t.GroupCurrencyAccGUID,
			@BasicGroupCurrencyAccount = center.CurrencyAccountGuidCenter,
			@Notes = C.Notes,
			@Date = c.[DATE]
		FROM 
			TrnCloseCashier000 AS c
			INNER JOIN TrnUserConfig000 AS t ON t.UserGuid = c.UserGuid
			INNER JOIN TrnCenter000 as center On Center.GUID=t.CenterGuid
		WHERE 
			c.guid = @CloseGuid
	END

	IF (ISNULL(@BasicGroupCurrencyAccount,0x0) = 0x0)
		SELECT @BasicGroupCurrencyAccount = CAST(VALUE AS [UNIQUEIDENTIFIER])
	    FROM OP000 WHERE NAME  = 'TrnCfg_CurrencyAccount'

	SET @entryGuid = NEWID()  
	SELECT @defaultCur = guid FROM my000 WHERE CurrencyVal = 1
	
	INSERT INTO ce000(Number, DATE, PostDate, Debit, Credit, 
			  Notes, CurrencyVal, IsPosted, Security, Branch, GUID, CurrencyGUID)      
	SELECT 	 @entryNum , [DATE], GETDATE(), Amount, Amount, @Notes, 1, 0, security, branchGuid, 
		@entryGuid, @defaultCur 
	FROM TrnCloseCashier000 AS c	
	WHERE c.GUID = @CloseGuid  
	------------------------------------------------------
	
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
		

		
	------------------------------------------------------
	DECLARE @Cur CURSOR ,
			@Number 	INT,
			@CurrencyGUID 	UNIQUEIDENTIFIER,
			@Amount 	FLOAT,
			@BasicAccGUID  	UNIQUEIDENTIFIER,
			@ExTypeAccGUID  UNIQUEIDENTIFIER,
			@CustomerGUID  UNIQUEIDENTIFIER,
			@BasicCustomerGUID  UNIQUEIDENTIFIER

	SET @Cur = CURSOR  FAST_FORWARD FOR
		SELECT 
			detail.Number * 2,
			detail.CurrencyGUID,
			detail.Amount,
			BasicAc.AccountGUID,
			CloseAc.AccountGUID,
			dbo.fnGetAccountTopCustomer(CloseAc.AccountGUID) CustomerGuid,
			dbo.fnGetAccountTopCustomer(BasicAc.AccountGUID) BasicCustomerGuid
		FROM 
			TrnCloseCashier000 AS c	
			INNER JOIN TrnCloseCashierDetail000 AS detail ON detail.ParentGuid = c.GUID
			INNER JOIN TrnCurrencyAccount000 AS CloseAc ON CloseAc.CurrencyGUID = detail.CurrencyGUID AND CloseAc.ParentGUID = @GroupCurrencyAccount
			--INNER JOIN fnTrnBasicCurrencyAccount() AS BasicAc ON BasicAc.CurrencyGUID = detail.CurrencyGUID
			INNER JOIN TrnCurrencyAccount000 AS BasicAc ON BasicAc.CurrencyGUID = detail.CurrencyGUID AND BasicAc.ParentGUID = @BasicGroupCurrencyAccount
		WHERE c.GUID = @CloseGuid 
			AND detail.Amount <> 0
	ORDER BY detail.Number
	
	OPEN @Cur 
	
	FETCH FROM @Cur INTO 
		@Number, @CurrencyGUID, @Amount, @BasicAccGUID, @ExTypeAccGUID, @CustomerGUID, @BasicCustomerGUID
	
	WHILE @@FETCH_STATUS = 0 
	BEGIN

		DECLARE @IsAvgMethd			BIT,
				@CurrencyCostVal	FLOAT,
				@CurBalance			FLOAT,
				@LastDate			DATETIME
		SELECT
				@IsAvgMethd = ISAvgMethod,
				@CurrencyCostVal = CurrencyCostVal,
				@CurBalance = CurBalance,
				@LastDate = Date
		FROM FnTrnGetCurrencyCost(@CurrencyGUID, @DATE, -1, @CalcAvgMethod)		
		
		IF (ISNULL(@CurrencyCostVal, 0) = 0)
			SELECT @CurrencyCostVal = InVal FROM fnTrnGetCurrencyInOutVal(@CurrencyGUID, @DATE)
		ELSE	
		BEGIN
			IF (@IsAvgMethd = 1)
				EXEC prcTrnInsertTrnCurrencyBalance @CurrencyGUID, @CurBalance, @CurrencyCostVal, @LastDate
		END

		INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,
			   CurrencyGUID, CurrencyVal, ParentGUID, accountGUID,
			   CostGUID, ContraAccGUID,CustomerGUID)
		VALUES( 
			@Number,
			@DATE,
			@Amount * @CurrencyCostVal,
			0,	
			@EnNotePrefix + ' ' + @Notes,
			@CurrencyGUID,
			@CurrencyCostVal,
			@entryGuid,
			@BasicAccGUID,
			0x0,
			@ExTypeAccGUID,
			@BasicCustomerGUID)
		

		INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,
			   CurrencyGUID, CurrencyVal, ParentGUID, accountGUID,
			   CostGUID, ContraAccGUID,CustomerGUID)
		VALUES( 
			@Number + 1,
			@DATE,
			0,
			@Amount * @CurrencyCostVal,
			@EnNotePrefix + ' ' + @Notes,
			@CurrencyGUID,
			@CurrencyCostVal,
			@entryGuid,
			@ExTypeAccGUID,
			@costguid,
			@BasicAccGUID,
			@CustomerGUID)
		FETCH FROM @Cur INTO 
			@Number, @CurrencyGUID, @Amount, @BasicAccGUID, @ExTypeAccGUID, @CustomerGUID, @BasicCustomerGUID
	END
CLOSE @Cur
DEALLOCATE @Cur  

----------------------------------------------------
	SELECT @entryGuid AS EntryGuid 
####################################################################
CREATE PROC TrnGenCloseCashierEntry_Credit
	@CloseGuid UNIQUEIDENTIFIER, 
	@entryNum INT,
	@OperationType INT,
	@EnNotePrefix	NVARCHAR(50) = ''
AS  
	SET NOCOUNT ON 
	DECLARE  
		@costguid uniqueidentifier, 
		@ExchangeAcc uniqueidentifier,
		@AccGUID UNIQUEIDENTIFIER,
		@defaultCur UNIQUEIDENTIFIER, 
		@DATE	DATETIME, 
		@enNumber  INT, 
		@entryGuid UNIQUEIDENTIFIER,
		@GroupCurrencyAccount UNIQUEIDENTIFIER,--»ÿ«ﬁ… ’‰«œÌﬁ «·⁄„·«  «·„Õœœ… ›Ì ‰„ÿ «·’—«›…
		@BasicGroupCurrencyAccount UNIQUEIDENTIFIER,--»ÿ«ﬁ… ’‰«œÌﬁ «·⁄„·«  «·—∆Ì”Ì… «·„Õœœ… ›Ì ‰„ÿ «·’—«›…
		@Notes NVARCHAR(250)
	SELECT
		@costguid = t.CostGuid,
		@AccGUID = c.AccountGuid,
		@ExchangeAcc = t.ExchangeAcc,
		@DATE = c.[DATE],
		@GroupCurrencyAccount = t.GroupCurrencyAccGUID,
		@BasicGroupCurrencyAccount = t.MngerGroupCurrencyAccGUID,
		@Notes = C.Notes
	FROM TrnCloseCashier000 AS c
	INNER JOIN TrnExchangeTypes000 AS t ON t.Guid = c.ExchangeTypeGuid
	WHERE c.guid = @CloseGuid

	Declare @isGenEntriesAccordingToUserAccounts BIT
	SELECT @isGenEntriesAccordingToUserAccounts = CAST(value AS BIT) FROM op000 WHERE name = 'TrnCfg_Exchange_GenEntriesAccordingToUserAccounts'
	IF (ISNULL(@isGenEntriesAccordingToUserAccounts, 0) <> 0)
	BEGIN
		SELECT
			@costguid = t.CostGuid,
			@GroupCurrencyAccount = t.GroupCurrencyAccGUID,
			@BasicGroupCurrencyAccount = center.CurrencyAccountGuidCenter,
			@Notes = C.Notes,
			@Date = c.[DATE]
		FROM 
			TrnCloseCashier000 AS c
			INNER JOIN TrnUserConfig000 AS t ON t.UserGuid = c.UserGuid
			INNER JOIN TrnCenter000 as center On Center.GUID=t.CenterGuid
		WHERE 
			c.guid = @CloseGuid
	END
		
	IF (ISNULL(@BasicGroupCurrencyAccount,0x0) = 0x0)
		SELECT @BasicGroupCurrencyAccount = CAST(VALUE AS [UNIQUEIDENTIFIER])
	    FROM OP000 WHERE NAME  = 'TrnCfg_CurrencyAccount'

	SET @entryGuid = NEWID()  
	SELECT @defaultCur = guid FROM my000 WHERE CurrencyVal = 1
	
	INSERT INTO ce000(Number, DATE, PostDate, Debit, Credit, 
			  Notes, CurrencyVal, IsPosted, Security, Branch, GUID, CurrencyGUID)      
	SELECT 	 @entryNum , [DATE], GETDATE(), Amount, Amount, @Notes, 1, 0, security, branchGuid, 
		@entryGuid, @defaultCur 
	FROM TrnCloseCashier000 AS c	
	WHERE c.GUID = @CloseGuid  
	------------------------------------------------------
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
	------------------------------------------------------
	
	DECLARE @Cur CURSOR ,
			@Number 	INT,
			@CurrencyGUID 	UNIQUEIDENTIFIER,
			@Amount 	FLOAT,
			@BasicAccGUID  	UNIQUEIDENTIFIER,
			@ExTypeAccGUID  UNIQUEIDENTIFIER,
			@CustomerGUID  UNIQUEIDENTIFIER,
			@BasicCustomerGUID  UNIQUEIDENTIFIER

	SET @Cur = CURSOR  FAST_FORWARD FOR
		SELECT 
			detail.Number * 2,
			detail.CurrencyGUID,
			detail.Amount,
			BasicAc.AccountGUID,
			CloseAc.AccountGUID,
			dbo.fnGetAccountTopCustomer(CloseAc.AccountGUID) CustomerGuid,
			dbo.fnGetAccountTopCustomer(BasicAc.AccountGUID) BasicCustomerGuid
		FROM 
			TrnCloseCashier000 AS c	
			INNER JOIN TrnCloseCashierDetail000 AS detail ON detail.ParentGuid = c.GUID
			INNER JOIN TrnCurrencyAccount000 AS CloseAc ON CloseAc.CurrencyGUID = detail.CurrencyGUID AND CloseAc.ParentGUID = @GroupCurrencyAccount
			INNER JOIN TrnCurrencyAccount000 AS BasicAc ON BasicAc.CurrencyGUID = detail.CurrencyGUID AND BasicAc.ParentGUID = @BasicGroupCurrencyAccount
		WHERE c.GUID = @CloseGuid 
			AND detail.Amount <> 0
	ORDER BY detail.Number
	
	OPEN @Cur 
	
	FETCH FROM @Cur INTO 
		@Number, @CurrencyGUID, @Amount, @BasicAccGUID, @ExTypeAccGUID, @CustomerGUID, @BasicCustomerGUID
	
	WHILE @@FETCH_STATUS = 0 
	BEGIN
	
		DECLARE	@IsAvgMethd			BIT,
				@CurrencyCostVal	FLOAT,
				@CurBalance			FLOAT,
				@LastDate			DATETIME
		SELECT
				@IsAvgMethd = ISAvgMethod,
				@CurrencyCostVal = CurrencyCostVal,
				@CurBalance = CurBalance,
				@LastDate = Date
		FROM FnTrnGetCurrencyCost(@CurrencyGUID, @DATE, -1, @CalcAvgMethod)		
		
		IF (ISNULL(@CurrencyCostVal, 0) = 0)
			SELECT @CurrencyCostVal = InVal FROM fnTrnGetCurrencyInOutVal(@CurrencyGUID, @DATE)
		ELSE	
		BEGIN
			IF (@IsAvgMethd = 1)
				EXEC prcTrnInsertTrnCurrencyBalance @CurrencyGUID, @CurBalance, @CurrencyCostVal, @LastDate
		END
		
		INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,
			   CurrencyGUID, CurrencyVal, ParentGUID, accountGUID,
			   CostGUID, ContraAccGUID, CustomerGUID)
		VALUES( 
			@Number + 1,
			@DATE,
			0,
			@Amount * @CurrencyCostVal,
			@EnNotePrefix + ' ' + @Notes,
			@CurrencyGUID,
			@CurrencyCostVal,
			@entryGuid,
			@BasicAccGUID,
			0x0,
			@ExTypeAccGUID,
			@BasicCustomerGUID)

		INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,
			   CurrencyGUID, CurrencyVal, ParentGUID, accountGUID,
			   CostGUID, ContraAccGUID, CustomerGUID)
		VALUES( 
			@Number,
			@DATE,
			@Amount * @CurrencyCostVal,
			0,	
			@EnNotePrefix + ' ' + @Notes,
			@CurrencyGUID,
			@CurrencyCostVal,
			@entryGuid,
			@ExTypeAccGUID,
			@costguid,
			@BasicAccGUID,
			@CustomerGUID)

		FETCH FROM @Cur INTO 
			@Number, @CurrencyGUID, @Amount, @BasicAccGUID, @ExTypeAccGUID, @CustomerGUID, @BasicCustomerGUID

	END
CLOSE @Cur
DEALLOCATE @Cur  

----------------------------------------------------
SELECT @entryGuid AS EntryGuid
####################################################################
CREATE  PROC TrnGenCloseCashierEntry_Close
	@CloseGuid UNIQUEIDENTIFIER, 
	@entryNum INT,
	@OperationType INT,
	@EnNotePrefix	NVARCHAR(50) = ''
AS  
	SET NOCOUNT ON 
	DECLARE  
		@costguid uniqueidentifier, 
		@ExchangeAcc uniqueidentifier,
		@AccGUID UNIQUEIDENTIFIER,
		@defaultCur UNIQUEIDENTIFIER, 
		@DATE	DATETIME, 
		@enNumber  INT, 
		@entryGuid UNIQUEIDENTIFIER,
		@GroupCurrencyAccount UNIQUEIDENTIFIER,--»ÿ«ﬁ… ’‰«œÌﬁ «·⁄„·«  «·„Õœœ… ›Ì ‰„ÿ «·’—«›…
		@BasicGroupCurrencyAccount UNIQUEIDENTIFIER,--»ÿ«ﬁ… ’‰«œÌﬁ «·⁄„·«  «·—∆Ì”Ì… «·„Õœœ… ›Ì ‰„ÿ «·’—«›…
		@Notes NVARCHAR(250)
	SELECT
		@costguid = t.CostGuid,
		@AccGUID = c.AccountGuid,
		@ExchangeAcc = t.ExchangeAcc,
		@DATE = c.[DATE],
		@GroupCurrencyAccount = t.GroupCurrencyAccGUID,
		@BasicGroupCurrencyAccount = t.MngerGroupCurrencyAccGUID,
		@Notes = C.Notes
	FROM TrnCloseCashier000 AS c
	INNER JOIN TrnExchangeTypes000 AS t ON t.Guid = c.ExchangeTypeGuid
	WHERE c.guid = @CloseGuid
	
	Declare @isGenEntriesAccordingToUserAccounts BIT
	SELECT @isGenEntriesAccordingToUserAccounts = CAST(value AS BIT) FROM op000 WHERE name = 'TrnCfg_Exchange_GenEntriesAccordingToUserAccounts'
	IF (ISNULL(@isGenEntriesAccordingToUserAccounts, 0) <> 0)
	BEGIN
		SELECT
			@costguid = t.CostGuid,
			@GroupCurrencyAccount = t.GroupCurrencyAccGUID,
			@BasicGroupCurrencyAccount = center.CurrencyAccountGuidCenter,
			@ExchangeAcc	= t.CurrentAccountGuid,
			@DATE= c.Date,
			@Notes=c.Notes
		FROM 
			TrnCloseCashier000 AS c
			INNER JOIN TrnUserConfig000 AS t ON t.UserGuid = c.UserGuid
			INNER JOIN TrnCenter000 as center On Center.GUID=t.CenterGuid
		WHERE 
			c.guid = @CloseGuid
	END

	IF (ISNULL(@BasicGroupCurrencyAccount,0x0) = 0x0)
		SELECT @BasicGroupCurrencyAccount = CAST(VALUE AS [UNIQUEIDENTIFIER])
	    FROM OP000 WHERE NAME  = 'TrnCfg_CurrencyAccount'

	SET @entryGuid = NEWID()  
	SELECT @defaultCur = guid FROM my000 WHERE CurrencyVal = 1
	
	INSERT INTO ce000(Number, DATE, PostDate, Debit, Credit, 
			  Notes, CurrencyVal, IsPosted, Security, Branch, GUID, CurrencyGUID)      
	SELECT 	 @entryNum , [DATE], GETDATE(), Amount, Amount, @Notes, 1, 0, security, branchGuid, 
		@entryGuid, @defaultCur 
	FROM TrnCloseCashier000 AS c	
	WHERE c.GUID = @CloseGuid  
	------------------------------------------------------
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
	------------------------------------------------------
	
	DECLARE @Cur CURSOR ,
			@Number 	INT,
			@CurrencyGUID 	UNIQUEIDENTIFIER,
			@Amount 	FLOAT,
			@BasicAccGUID  	UNIQUEIDENTIFIER,
			@ExTypeAccGUID  UNIQUEIDENTIFIER,
			@balance	FLOAT,
			@CustomerGUID  UNIQUEIDENTIFIER,
			@BasicCustomerGUID  UNIQUEIDENTIFIER

	SET @Cur = CURSOR  FAST_FORWARD FOR
		SELECT 
			detail.Number * 4,
			detail.CurrencyGUID,
			detail.Amount,
			BasicAc.AccountGUID,
			CloseAc.AccountGUID,
			detail.Balance, 
			dbo.fnGetAccountTopCustomer(CloseAc.AccountGUID) CustomerGuid,
			dbo.fnGetAccountTopCustomer(BasicAc.AccountGUID) BasicCustomerGuid
		FROM 
			TrnCloseCashier000 AS c	
			INNER JOIN TrnCloseCashierDetail000 AS detail ON detail.ParentGuid = c.GUID
			INNER JOIN TrnCurrencyAccount000 AS CloseAc ON CloseAc.CurrencyGUID = detail.CurrencyGUID AND CloseAc.ParentGUID = @GroupCurrencyAccount
			--INNER JOIN fnTrnBasicCurrencyAccount() AS BasicAc ON BasicAc.CurrencyGUID = detail.CurrencyGUID
			INNER JOIN TrnCurrencyAccount000 AS BasicAc ON BasicAc.CurrencyGUID = detail.CurrencyGUID AND BasicAc.ParentGUID = @BasicGroupCurrencyAccount
		WHERE c.GUID = @CloseGuid 
			AND (detail.Amount <> 0 OR (detail.Balance - detail.Amount) <> 0)
	ORDER BY detail.Number
	
	OPEN @Cur 
	
	FETCH FROM @Cur INTO 
		@Number, @CurrencyGUID, @Amount, @BasicAccGUID, @ExTypeAccGUID, @balance, @CustomerGUID,  @BasicCustomerGUID 
	
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		
		DECLARE	@IsAvgMethd			BIT,
				@CurrencyCostVal	FLOAT,
				@LastBalance		FLOAT,
				@LastDate			DATETIME
		SELECT
				@IsAvgMethd = ISAvgMethod,
				@CurrencyCostVal = CurrencyCostVal,
				@LastBalance = CurBalance,
				@LastDate = Date
		FROM FnTrnGetCurrencyCost(@CurrencyGUID, @DATE, -1, @CalcAvgMethod)		
		
		IF (ISNULL(@CurrencyCostVal, 0) = 0)
			SELECT @CurrencyCostVal = InVal FROM fnTrnGetCurrencyInOutVal(@CurrencyGUID, @DATE)
		ELSE	
		BEGIN
			IF (@IsAvgMethd = 1)
				EXEC prcTrnInsertTrnCurrencyBalance @CurrencyGUID, @LastBalance, @CurrencyCostVal, @LastDate
		END
		
		IF (@Amount <> 0)
		BEGIN
			INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,
				   CurrencyGUID, CurrencyVal, ParentGUID, accountGUID,
				   CostGUID, ContraAccGUID,CustomerGUID)
			VALUES( 
				@Number,
				@DATE,
				@Amount * @CurrencyCostVal,
				0,	
				@EnNotePrefix + ' ' + @Notes,
				@CurrencyGUID,
				@CurrencyCostVal,
				@entryGuid,
				@BasicAccGUID,
				0x0,
				@ExTypeAccGUID,
				@BasicCustomerGUID )
			

			INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,
				   CurrencyGUID, CurrencyVal, ParentGUID, accountGUID,
				   CostGUID, ContraAccGUID,CustomerGUID)
			VALUES( 
				@Number + 1,
				@DATE,
				0,
				@Amount * @CurrencyCostVal,
				@EnNotePrefix + ' ' + @Notes,
				@CurrencyGUID,
				@CurrencyCostVal,
				@entryGuid,
				@ExTypeAccGUID,
				@costguid,
				@BasicAccGUID,
				@CustomerGUID)
	END
	IF (@balance - @Amount <> 0)
	BEGIN
		---  Õ„Ì· ⁄·Ï –„… «·’—«›	
		INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,
				   CurrencyGUID, CurrencyVal, ParentGUID, accountGUID,
				   CostGUID, ContraAccGUID)
			VALUES( 
				@Number + 2,
				@DATE,
				(@balance - @Amount) * @CurrencyCostVal,
				0,	
				@EnNotePrefix + ' ' + @Notes,
				@CurrencyGUID,
				@CurrencyCostVal,
				@entryGuid,
				@ExchangeAcc,
				0x0,
				@ExTypeAccGUID)

			INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,
				   CurrencyGUID, CurrencyVal, ParentGUID, accountGUID,
				   CostGUID, ContraAccGUID)
			VALUES( 
				@Number + 3,
				@DATE,
				0,
				(@balance - @Amount) * @CurrencyCostVal,
				@EnNotePrefix + ' ' + @Notes,
				@CurrencyGUID,
				@CurrencyCostVal,
				@entryGuid,
				@ExTypeAccGUID,
				@costguid,
				@ExchangeAcc)

		END
		FETCH FROM @Cur INTO 
			@Number, @CurrencyGUID, @Amount, @BasicAccGUID, @ExTypeAccGUID, @balance, @CustomerGUID,  @BasicCustomerGUID 
	END
CLOSE @Cur
DEALLOCATE @Cur

----------------------------------------------------
	SELECT @entryGuid AS EntryGuid
########################################################################
CREATE PROC TrnDeleteCloseCashierEntry
	@CloseGuid UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON
	
	DECLARE @guid uniqueidentifier 

	SELECT @guid = EntryGuid 
	FROM TrnCloseCashier000
	WHERE  guid = @CloseGuid

	update ce SET isposted = 0 
	FROM ce000 AS ce 
	WHERE guid = @guid

	delete ce000 WHERE guid = @guid
	
	UPDATE TrnCloseCashier000 
	SET EntryGuid = 0x00
	WHERE guid = @CloseGuid
########################################################################
CREATE  PROC TrnGenCloseCashierGenEntry
	@CloseGuid UNIQUEIDENTIFIER,
	@OperationType INT = 1,
	@EnNotePrefix	NVARCHAR(50) = ''

AS
	SET NOCOUNT ON 

	IF @OperationType = 3 and @EnNotePrefix = '' 
	BEGIN
		SELECT TOP 1 @EnNotePrefix = REPLACE(en.Notes,ce.Notes,'') 
		FROM
			TrnCloseCashier000 CC
			INNER JOIN ce000 ce ON ce.GUID = CC.EntryGuid
			INNER JOIN en000 en ON en.ParentGUID = ce.GUID
		WHERE 
			CC.guid = @CloseGuid
	
		SET @EnNotePrefix = ISNULL(@EnNotePrefix, '')
	END

	DECLARE	@Type INT ,
		@entryNum INT, 
		@BranchGuid  UNIQUEIDENTIFIER,
		@OldEntryGuid UNIQUEIDENTIFIER,
		@EntryGuid UNIQUEIDENTIFIER,
		@closeNum INT,
		@CreateDate Datetime,
		@CreateUserGuid UNIQUEIDENTIFIER
		
	SELECT	@Type = type, @OldEntryGuid = EntryGuid, 
		@BranchGuid = BranchGuid,@closeNum = c.number
	FROM TrnCloseCashier000 AS c
 	WHERE c.guid = @CloseGuid
	EXEC  prcDisableTriggers 'ce000' 
	EXEC  prcDisableTriggers 'en000' 

	IF (IsNull(@OldEntryGuid, 0x0) = 0x00) 
		SET @entryNum = [dbo].[fnEntry_getNewNum](@BranchGUID)		
	ELSE 
	BEGIN	
		SELECT @entryNum = NUMBER, @CreateDate = CreateDate, @CreateUserGuid = CreateUserGUID
		FROM ce000  WHERE GUID =  @OldEntryGuid

		DELETE FROM ce000 WHERE Guid = @OldEntryGuid
		DELETE FROM en000 WHERE ParentGuid = @OldEntryGuid
		DELETE FROM er000 WHERE EntryGuid = @OldEntryGuid
	END

	SET @entryNum = ISNULL(@entryNum, 0)

	IF (@entryNum = 0 OR EXISTS (SELECT * FROM CE000 WHERE NUMBER = @entryNum AND Branch = @BranchGUID))
		SET @entryNum = [dbo].[fnEntry_getNewNum](@BranchGUID)	
		
			
	CREATE Table #res(EntryGuid UNIQUEIDENTIFIER)
	IF (@type = 0) --  ”·Ì„ ≈·Ï «·’—«›
	BEGIN
		INSERT INTO #res
		EXEC	TrnGenCloseCashierEntry_Credit	
			@CloseGuid,
			@entryNum,
			@OperationType,
			@EnNotePrefix
	END		
	ELSE
	IF (@type = 1)
	BEGIN
		INSERT INTO #res
		EXEC	TrnGenCloseCashierEntry_Debit
			@CloseGuid,
	 		@entryNum,
	 		@OperationType,
			@EnNotePrefix
	END
	ELSE		
		INSERT INTO #res
		EXEC	TrnGenCloseCashierEntry_Close
			@CloseGuid,
	 		@entryNum,
	 		@OperationType,
			@EnNotePrefix

	SELECT @entryGUID = EntryGuid FROM #res
	UPDATE TrnCloseCashier000    
	SET EntryGuid = @entryGUID   
	WHERE guid = @CloseGuid   
	   
   	INSERT INTO er000 (EntryGUID, ParentGUID, ParentType, ParentNumber)  
	VALUES(@entryGUID, @CloseGuid , 517 , @closeNum )   

	EXEC prcEnableTriggers 'ce000'   
	EXEC prcEnableTriggers 'en000'   
	   
	UPDATE [ce000] SET [IsPosted] = 1,
	CreateDate =
		CASE WHEN @OperationType = 2 THEN  @CreateDate ELSE GETDATE() END,
	CreateUserGUID =
		CASE WHEN @OperationType = 2 THEN  @CreateUserGuid ELSE [dbo].[fnGetCurrentUserGUID]() END,
	LastUpdateDate = 
		CASE WHEN @OperationType = 2 THEN  GETDATE() ELSE LastUpdateDate END,
	LastUpdateUserGUID =
		CASE WHEN @OperationType = 2 THEN  [dbo].[fnGetCurrentUserGUID]() ELSE LastUpdateUserGUID END
	WHERE Guid = @entryGUID  

	-- return data about generated entry     
	SELECT @entryGUID AS EntryGuid , @entryNum  AS EntryNumber
####################################################################
CREATE PROCEDURE prcTrnGenDepositEntry_Debit
	@DepositGuid UNIQUEIDENTIFIER, 
	@entryNum INT,
    @ValType  INT,
	@OldCostGuid UNIQUEIDENTIFIER = 0x0
    /*
        @ValType = 1       «· ⁄«œ· «·Ê”ÿÌ
        @ValType = 2        ⁄«œ· «·‘—«¡
    */
AS  
	SET NOCOUNT ON 
	DECLARE  
		@Costguid	UNIQUEIDENTIFIER, 
		@CurGuid	UNIQUEIDENTIFIER, 
		@DATE		DATETIME, 
		@enNumber	INT, 
		@entryGuid	UNIQUEIDENTIFIER,
		@Notes		NVARCHAR(250),
		@RecCurAcc  UNIQUEIDENTIFIER,
		@DepositType INT,
		@AccoutnGUID UNIQUEIDENTIFIER = 0x0,
		@CustomerGUID UNIQUEIDENTIFIER = 0x0,
		@RecCustomerGUID UNIQUEIDENTIFIER = 0x0;
	SELECT
		@Costguid = t.CostGuid,
		@RecCurAcc = dep.CurrencyAccGuid,
		@DATE = dep.[DATE],
		@Notes = dep.Notes, 
		@CurGuid = dep.CurrencyGUID,
		@DepositType = dep.type
	FROM 
		TrnDeposit000 AS dep
		INNER JOIN TrnExchangeTypes000 AS t ON t.Guid = dep.TypeGuid
		LEFT JOIN TrnGroupCurrencyAccount000 as gc ON gc.GUID = t.GroupCurrencyAccGUID
		LEFT JOIN TrnCurrencyAccount000 ca ON ca.ParentGUID = gc.GUID AND ca.AccountGUID = dep.CurrencyAccGUID
	WHERE 
		dep.guid = @DepositGuid

	DECLARE @IsGenEntriesAccordingToUserAccounts BIT
	SELECT @IsGenEntriesAccordingToUserAccounts = value FROM op000 WHERE Name = 'TrnCfg_Exchange_GenEntriesAccordingToUserAccounts'
	IF @IsGenEntriesAccordingToUserAccounts = 1
	BEGIN
		IF @OldCostGuid = 0x0
			SELECT 
				@costguid = CostGuid
			FROM
				TrnUserConfig000 
			WHERE 
				UserGuid = dbo.fnGetCurrentUserGUID()
		ELSE
			SET @costguid = @OldCostGuid
	END
	IF ISNULL(@RecCurAcc, 0x0) = 0x0 
	BEGIN
		RAISERROR('AmnE0195: Exchange Deposit Account  was not found ...', 16, 1)
		RETURN
	END

	SET @entryGuid = NEWID()  
	DECLARE @CurrencyVal FLOAT
	exec prcTrnGetCurrAvg @CurGuid, @DATE, @CurrencyVal out
	
	INSERT INTO ce000(Number, DATE,	 PostDate, Notes, CurrencyVal, IsPosted, Security, Branch, GUID, CurrencyGUID)      
	SELECT @entryNum, [DATE],GETDATE(),   @Notes, @CurrencyVal, 0,		security, branchGuid, @entryGuid, @CurGuid
	FROM 
		TrnDeposit000 AS c	
	WHERE 
		c.GUID = @DepositGuid  
	------------------------------------------------------	
	DECLARE @Cur CURSOR,
			@Number			INT,
			@AccGuid		UNIQUEIDENTIFIER,
			@Amount			FLOAT,
			@DetailNotes	NVARCHAR(50)
	SET @Cur = CURSOR  FAST_FORWARD FOR
		SELECT 
			detail.Number * 2,
			detail.AccGuid,
			detail.Amount,
			detail.Notes
		FROM 
			TrnDeposit000 AS dep	
			INNER JOIN TrnDepositDetail000 AS detail ON detail.ParentGuid = dep.GUID
		WHERE 
			dep.GUID = @DepositGuid 
			AND ISNULL(detail.AccGuid, 0x0) <> 0x0
			AND detail.Amount <> 0
		ORDER BY detail.Number
	OPEN @Cur
	FETCH FROM @Cur INTO @Number, @AccGuid, @Amount, @DetailNotes

	WHILE @@FETCH_STATUS = 0 
	BEGIN
		IF EXISTS (SELECT GUID FROM vwAcCu WHERE (GUID = @RecCurAcc  AND CustomersCount > 1))
		BEGIN
			SELECT @AccoutnGUID = GUID FROM vwAcCu WHERE (GUID = @RecCurAcc  AND CustomersCount > 1);
			INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
			SELECT 1, 0, 'AmnE0052: [' + CAST(@AccoutnGUID AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
			RETURN 
		END 
		ELSE IF EXISTS (SELECT GUID FROM vwAcCu WHERE (GUID = @AccGuid  AND CustomersCount > 1))
		BEGIN 
			SELECT @AccoutnGUID = GUID FROM vwAcCu WHERE (GUID = @AccGuid  AND CustomersCount > 1);
			INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
			SELECT 1, 0, 'AmnE0052: [' + CAST(@AccoutnGUID AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
			RETURN
		END

		IF EXISTS (SELECT GUID FROM vwAcCu WHERE (GUID = @RecCurAcc  AND CustomersCount = 1))
		BEGIN
			SELECT @RecCustomerGUID = cuGUID FROM vwCu WHERE cuAccount = @RecCurAcc
		END 

		IF EXISTS (SELECT GUID FROM vwAcCu WHERE (GUID = @AccGuid  AND CustomersCount = 1))
		BEGIN
			SELECT @CustomerGUID = cuGUID FROM vwCu WHERE cuAccount = @AccGuid 
		END 

		INSERT INTO en000 ( [Number], [DATE], [Debit], [Credit], Notes, CurrencyGUID, CurrencyVal, 
							ParentGUID, accountGUID, CostGUID, ContraAccGUID, CustomerGUID)
		VALUES( 
			@Number,
			@DATE,
			@Amount * @CurrencyVal,
			0,	
			@DetailNotes,
			@CurGUID,
			@CurrencyVal,
			@entryGuid,
			CASE @DepositType WHEN 1 THEN @RecCurAcc ELSE @AccGuid END,
			CASE @DepositType WHEN 1 THEN @costguid ELSE 0x0 END,
			CASE @DepositType WHEN 1 THEN @AccGuid ELSE @RecCurAcc END,
			CASE @DepositType WHEN 1 THEN @RecCustomerGUID ELSE @CustomerGUID END)
		
		INSERT INTO en000 ( [Number], [DATE], [Debit], [Credit], Notes, CurrencyGUID, CurrencyVal, 
							ParentGUID, accountGUID, CostGUID, ContraAccGUID, CustomerGUID)
		VALUES( 
			@Number + 1,
			@DATE,
			0,
			@Amount * @CurrencyVal,
			@DetailNotes,
			@CurGUID,
			@CurrencyVal,
			@entryGuid,
			CASE @DepositType WHEN 1 THEN @AccGuid ELSE @RecCurAcc END,
			CASE @DepositType WHEN 1 THEN 0x0 ELSE @Costguid END,
			CASE @DepositType WHEN 1 THEN @RecCurAcc ELSE @AccGuid END,
			CASE @DepositType WHEN 1 THEN @CustomerGUID ELSE @RecCustomerGUID END)

		FETCH FROM @Cur INTO @Number, @AccGuid, @Amount, @DetailNotes
	END
CLOSE @Cur
DEALLOCATE @Cur  
----------------------------------------------------
	SELECT @entryGuid AS EntryGuid
####################################################################
CREATE PROC prcTrnGenDepositEntry_Credit
	@DepositGuid UNIQUEIDENTIFIER, 
	@entryNum INT,
    @ValType  INT
    /*
        @ValType = 1       «· ⁄«œ· «·Ê”ÿÌ
        @ValType = 2        ⁄«œ· «·»Ì⁄
    */
AS  
	SET NOCOUNT ON 
	DECLARE  
		@costguid uniqueidentifier, 
		@defaultCur UNIQUEIDENTIFIER, 
		@DATE	DATETIME, 
		@enNumber  INT, 
		@entryGuid UNIQUEIDENTIFIER,
		@Notes NVARCHAR(250),
		@RecGroupCurAcc  UNIQUEIDENTIFIER,
		@TypeGroupCurAcc  UNIQUEIDENTIFIER
	SELECT
		@costguid = t.CostGuid,
		@RecGroupCurAcc = dep.CurrencyAccGuid,
		@TypeGroupCurAcc =  t.GroupCurrencyAccGUID,
		@DATE = dep.[DATE],
		@Notes = dep.Notes
--select * from TrnDeposit000	
	FROM TrnDeposit000 AS dep
	INNER JOIN TrnExchangeTypes000 AS t ON t.Guid = dep.TypeGuid
	WHERE dep.guid = @DepositGuid
	IF EXISTS (
		SELECT RecCurAcc.AccountGUID,TypeCurAcc.AccountGUID
		FROM 
			TrnDeposit000 AS dep	
--select * from TrnDepositDetail000
			INNER JOIN TrnDepositDetail000 AS detail ON detail.ParentGuid = dep.GUID
			LEFT JOIN TrnCurrencyAccount000 AS RecCurAcc 
				ON RecCurAcc.ParentGUID = @RecGroupCurAcc 
				--AND RecCurAcc.CurrencyGUID = detail.CurrencyGUID 
			LEFT JOIN TrnCurrencyAccount000 AS TypeCurAcc 
				ON TypeCurAcc.ParentGUID = @TypeGroupCurAcc --AND TypeCurAcc.CurrencyGUID = detail.CurrencyGUID 
			WHERE dep.GUID = @DepositGuid AND detail.Amount <> 0
				AND 
				(
					ISNULL(RecCurAcc.AccountGUID, 0X0) = 0X0 
					OR 
					ISNULL(TypeCurAcc.AccountGUID , 0X0) = 0X0
				)
		)
	BEGIN
		RAISERROR('AmnE0195: Exchange Deposit Account  was not found ...', 16, 1)
		RETURN
	END
	SET @entryGuid = NEWID()  
	SELECT @defaultCur = guid FROM my000 WHERE CurrencyVal = 1
	
	
	INSERT INTO ce000(Number, DATE, PostDate, Notes, CurrencyVal, IsPosted, Security, Branch, GUID, CurrencyGUID)      
	SELECT 	 @entryNum , [DATE] , GETDATE(),@Notes, 1, 0, security, branchGuid, 
		@entryGuid, @defaultCur 
	FROM TrnDeposit000 AS c	
	WHERE c.GUID = @DepositGuid  
	------------------------------------------------------
	
	DECLARE @Cur CURSOR ,
			@Number INT,
			@CurrencyGUID UNIQUEIDENTIFIER,
			@Amount FLOAT,
			@RecCurAccGUID UNIQUEIDENTIFIER,
			@TypeCurAccGUID UNIQUEIDENTIFIER
	SET @Cur = CURSOR  FAST_FORWARD FOR
		SELECT 
			detail.Number * 2,
			--detail.CurrencyGUID,
			detail.Amount,
			RecCurAcc.AccountGUID,
			TypeCurAcc.AccountGUID
		FROM 
			TrnDeposit000 AS dep	
			INNER JOIN TrnDepositDetail000 AS detail ON detail.ParentGuid = dep.GUID
			INNER JOIN TrnCurrencyAccount000 AS RecCurAcc 
				ON RecCurAcc.ParentGUID = @RecGroupCurAcc --AND RecCurAcc.CurrencyGUID = detail.CurrencyGUID 
			INNER JOIN TrnCurrencyAccount000 AS TypeCurAcc 
				ON TypeCurAcc.ParentGUID = @TypeGroupCurAcc --AND TypeCurAcc.CurrencyGUID = detail.CurrencyGUID 
			WHERE dep.GUID = @DepositGuid AND detail.Amount <> 0
	ORDER BY detail.Number
	
	OPEN @Cur 
	FETCH FROM @Cur INTO 
		@Number, @CurrencyGUID, @Amount, @RecCurAccGUID, @TypeCurAccGUID
	
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		DECLARE @CurrencyVal FLOAT
		--IF (@ValType = 1)
		--	SELECT @CurrencyVal = CurAvg FROM FnTrnGetCurAverage2(@CurrencyGUID, @DATE)
		--IF (@ValType = 2 OR ISNULL(@CurrencyVal, 0) = 0)
		SELECT @CurrencyVal = OutVal FROM fnTrnGetCurrencyInOutVal(@CurrencyGUID, @DATE)
		INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,
			   CurrencyGUID, CurrencyVal, ParentGUID, accountGUID,
			   CostGUID, ContraAccGUID)
		VALUES( 
			@Number,
			@DATE,
			@Amount * @CurrencyVal,
			0,
			N' ”·Ì„ ÊœÌ⁄… ' + @Notes,
			@CurrencyGUID,
			@CurrencyVal,
			@entryGuid,
			@RecCurAccGUID,
			@costguid,
			@TypeCurAccGUID)
		INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,
			   CurrencyGUID, CurrencyVal, ParentGUID, accountGUID,
			   CostGUID, ContraAccGUID)
		VALUES( 
			@Number + 1,
			@DATE,
			0,			
			@Amount * @CurrencyVal,
			N' ”·Ì„ ÊœÌ⁄… ' + @Notes,
			@CurrencyGUID,
			@CurrencyVal,
			@entryGuid,
			@TypeCurAccGUID,			
			@costguid,
			@RecCurAccGUID)
		
		FETCH FROM @Cur INTO 
			@Number, @CurrencyGUID, @Amount, @RecCurAccGUID, @TypeCurAccGUID
	END
CLOSE @Cur
DEALLOCATE @Cur  
----------------------------------------------------
	SELECT @entryGuid AS EntryGuid 
######################################################
CREATE PROCEDURE prcTrnDepositGenEntry
	@DepositGuid UNIQUEIDENTIFIER,
	@IsModify           BIT = 0,
    @DepositValType     INT = 1,--        ”‰œ «··≈Ìœ«⁄
    @WithdrawValType    INT = 1--         ”‰œ «· ”·Ì„   
        /*
        @DepsitValType = 1       «· ⁄«œ· «·Ê”ÿÌ
        @DepsitValType = 2        ⁄«œ· «·‘—«¡
        
        @WithdrawValType = 1       «· ⁄«œ· «·Ê”ÿÌ
        @WithdrawValType = 2        ⁄«œ· «·»Ì⁄
        */
AS
	SET NOCOUNT ON 
	
	DECLARE	@Type	INT,
		@entryNum	INT, 
		@BranchGuid  UNIQUEIDENTIFIER,
		@OldEntryGuid UNIQUEIDENTIFIER,
		@EntryGuid	UNIQUEIDENTIFIER,
		@DepositNum	INT,
		@Er_Number	INT,	
		@OldCostGuid UNIQUEIDENTIFIER,
		@CreateDate DateTime,
	    @CreateUserGuid UNIQUEIDENTIFIER

	SELECT	@Type = type, @OldEntryGuid = EntryGuid, 
		@BranchGuid = BranchGuid, @DepositNum = c.number
	FROM TrnDeposit000 AS c
 	WHERE c.guid = @DepositGuid
	EXEC  prcDisableTriggers 'ce000' 
	EXEC  prcDisableTriggers 'en000' 
	IF (IsNull(@OldEntryGuid, 0x0) = 0x00) 
		SET @entryNum = [dbo].[fnEntry_getNewNum](@BranchGUID)		
	ELSE 
	BEGIN	
		SELECT @entryNum = NUMBER, @CreateDate = CreateDate, @CreateUserGuid = CreateUserGUID 
		FROM ce000 WHERE GUID =  @OldEntryGuid
		SELECT TOP 1 @OldCostGuid = CostGUID FROM en000 WHERE ParentGuid = @OldEntryGuid AND CostGUID <> 0x0
		DELETE FROM ce000 WHERE Guid = @OldEntryGuid
		DELETE FROM en000 WHERE ParentGuid = @OldEntryGuid
		DELETE FROM er000 WHERE EntryGuid = @OldEntryGuid
	END
		
	CREATE Table #res(EntryGuid UNIQUEIDENTIFIER)
	SET @Er_Number = CASE @type WHEN 1 THEN 520 ELSE 521 END
	SET @OldCostGuid = ISNULL(@OldCostGuid, 0x0)
	INSERT INTO #res
	EXEC prcTrnGenDepositEntry_Debit  @DepositGuid, @entryNum, @DepositValType, @OldCostGuid
	SELECT @entryGUID = EntryGuid FROM #res
	UPDATE TrnDeposit000    
	SET EntryGuid = @entryGUID   
	WHERE guid = @DepositGuid   
   
   	INSERT INTO er000 (EntryGUID, ParentGUID, ParentType, ParentNumber)  
	VALUES(@entryGUID, @DepositGuid , @Er_Number , @DepositNum )
	
	EXEC prcEnableTriggers 'ce000'   
	EXEC prcEnableTriggers 'en000'  
	
	UPDATE [ce000] SET [IsPosted] = 1,
	CreateDate =
		CASE WHEN @IsModify = 1 THEN  @CreateDate ELSE GETDATE() END,
	CreateUserGUID =
		CASE WHEN @IsModify = 1 THEN  @CreateUserGuid ELSE [dbo].[fnGetCurrentUserGUID]() END,
	LastUpdateDate = 
		CASE WHEN @IsModify = 1 THEN  GETDATE() ELSE LastUpdateDate END,
	LastUpdateUserGUID =
		CASE WHEN @IsModify = 1 THEN  [dbo].[fnGetCurrentUserGUID]() ELSE LastUpdateUserGUID END
	WHERE Guid = @entryGUID  

	SELECT @entryGUID AS EntryGuid , @entryNum  AS EntryNumber
####################################################################
CREATE  PROC TrnGenCloseCashierCenterGenEntry
	@CloseGuid UNIQUEIDENTIFIER,
	@OperationType INT = 1,
	@CloseTypeString Nvarchar(250)
AS
	SET NOCOUNT ON 
	DECLARE	@Type INT ,
		@entryNum INT, 
		@BranchGuid  UNIQUEIDENTIFIER,
		@OldEntryGuid UNIQUEIDENTIFIER,
		@EntryGuid UNIQUEIDENTIFIER,
		@closeNum INT,
		@CreateDate DateTime,
		@CreateUserGuid UNIQUEIDENTIFIER

	SELECT	@Type = type, @OldEntryGuid = EntryGuid, 
		@BranchGuid = BranchGuid,@closeNum = c.number
	FROM TrnCloseCashier000 AS c
 	WHERE c.guid = @CloseGuid
	EXEC  prcDisableTriggers 'ce000' 
	EXEC  prcDisableTriggers 'en000' 

	IF (IsNull(@OldEntryGuid, 0x0) = 0x00) 
		SET @entryNum = [dbo].[fnEntry_getNewNum](@BranchGUID)		
	ELSE 
	BEGIN	
		SELECT @entryNum = NUMBER, @CreateDate = CreateDate, @CreateUserGuid = CreateUserGUID
		FROM ce000  WHERE GUID =  @OldEntryGuid

		DELETE FROM ce000 WHERE Guid = @OldEntryGuid
		DELETE FROM en000 WHERE ParentGuid = @OldEntryGuid
		DELETE FROM er000 WHERE EntryGuid = @OldEntryGuid
	END

	SET @entryNum = ISNULL(@entryNum, 0)

	IF (@entryNum = 0 OR EXISTS (SELECT * FROM CE000 WHERE NUMBER = @entryNum AND Branch = @BranchGUID))
		SET @entryNum = [dbo].[fnEntry_getNewNum](@BranchGUID)	
		
			
	CREATE Table #res(EntryGuid UNIQUEIDENTIFIER)
	IF (@type = 0) --  ”·Ì„ ≈·Ï «·„—«ﬂ“
	BEGIN
		INSERT INTO #res
		EXEC	TrnGenCloseCashierCenterEntry_Credit	
			@CloseGuid,
			@entryNum,
			@OperationType,
			@CloseTypeString
	END		
	ELSE
	IF (@type = 1)
	BEGIN
		INSERT INTO #res
		EXEC	TrnGenCloseCashierCenterEntry_Debit
			@CloseGuid,
	 		@entryNum,
	 		@OperationType,
			@CloseTypeString
	END
	
	SELECT @entryGUID = EntryGuid FROM #res
	UPDATE TrnCloseCashier000    
	SET EntryGuid = @entryGUID   
	WHERE guid = @CloseGuid   
	   
   	INSERT INTO er000 (EntryGUID, ParentGUID, ParentType, ParentNumber)  
	VALUES(@entryGUID, @CloseGuid , 527 , @closeNum )   
	EXEC prcEnableTriggers 'ce000'   
	EXEC prcEnableTriggers 'en000'   
	   
	UPDATE [ce000] SET [IsPosted] = 1,
	CreateDate =
		CASE WHEN @OperationType = 2 THEN  @CreateDate ELSE GETDATE() END,
	CreateUserGUID =
		CASE WHEN @OperationType = 2 THEN  @CreateUserGuid ELSE [dbo].[fnGetCurrentUserGUID]() END,
	LastUpdateDate = 
		CASE WHEN @OperationType = 2 THEN  GETDATE() ELSE LastUpdateDate END,
	LastUpdateUserGUID =
		CASE WHEN @OperationType = 2 THEN  [dbo].[fnGetCurrentUserGUID]() ELSE LastUpdateUserGUID END
	WHERE Guid = @entryGUID  
	-- return data about generated entry     
	SELECT @entryGUID AS EntryGuid , @entryNum  AS EntryNumber
####################################################################
CREATE PROC TrnGenCloseCashierCenterEntry_Debit
	@CloseGuid UNIQUEIDENTIFIER, 
	@entryNum INT,
	/*
		1 Add new Exchange
		2 Update old Exchange
		3 Maintain Exchange 
	*/
	@OperationType INT = 1,
	@CloseTypeString Nvarchar(250)
AS  
	SET NOCOUNT ON 
	DECLARE  
		@costguid uniqueidentifier, 
		@ExchangeAcc uniqueidentifier,
		@AccGUID UNIQUEIDENTIFIER,
		@defaultCur UNIQUEIDENTIFIER, 
		@DATE	DATETIME, 
		@enNumber  INT, 
		@entryGuid UNIQUEIDENTIFIER,
		@GroupCurrencyAccount UNIQUEIDENTIFIER,--»ÿ«ﬁ… ’‰«œÌﬁ «·⁄„·«  «·„Õœœ… ›Ì ‰„ÿ «·’—«›…
		@BasicGroupCurrencyAccount UNIQUEIDENTIFIER,--»ÿ«ﬁ… ’‰«œÌﬁ «·⁄„·«  «·—∆Ì”Ì… «·„Õœœ… ›Ì ‰„ÿ «·’—«›…
		@Notes NVARCHAR(250)
		
	SELECT
		@costguid = 0x0,
		@GroupCurrencyAccount = center.CurrencyAccountGuidCenter,
		@BasicGroupCurrencyAccount = center.ManagementCurrencyAccountGuid,
		@Notes = C.Notes,
		@AccGUID = c.AccountGuid,
		@DATE = c.[DATE]
	FROM 
		TrnCloseCashier000 AS c
		INNER JOIN TrnCenter000 as center On Center.GUID=c.UserGuid
	WHERE 
		c.guid = @CloseGuid

	IF (ISNULL(@BasicGroupCurrencyAccount,0x0) = 0x0)
		SELECT @BasicGroupCurrencyAccount = CAST(VALUE AS [UNIQUEIDENTIFIER])
	    FROM OP000 WHERE NAME  = 'TrnCfg_CurrencyAccount'

	SET @entryGuid = NEWID()  
	SELECT @defaultCur = guid FROM my000 WHERE CurrencyVal = 1
	
	INSERT INTO ce000(Number, DATE, PostDate, Debit, Credit, 
			  Notes, CurrencyVal, IsPosted, Security, Branch, GUID, CurrencyGUID)      
	SELECT 	 @entryNum , [DATE], GETDATE(), Amount, Amount, @Notes, 1, 0, security, branchGuid, 
		@entryGuid, @defaultCur 
	FROM TrnCloseCashier000 AS c	
	WHERE c.GUID = @CloseGuid  
	------------------------------------------------------
	
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
		

		
	------------------------------------------------------
	DECLARE @Cur CURSOR ,
			@Number 	INT,
			@CurrencyGUID 	UNIQUEIDENTIFIER,
			@Amount 	FLOAT,
			@BasicAccGUID  	UNIQUEIDENTIFIER,
			@ExTypeAccGUID  UNIQUEIDENTIFIER,
			@CustomerGUID  UNIQUEIDENTIFIER,
			@BasicCustomerGUID UNIQUEIDENTIFIER

	SET @Cur = CURSOR  FAST_FORWARD FOR
		SELECT 
			detail.Number * 2,
			detail.CurrencyGUID,
			detail.Amount,
			BasicAc.AccountGUID,
			CloseAc.AccountGUID,
			dbo.fnGetAccountTopCustomer(CloseAc.AccountGUID) CustomerGuid,
			dbo.fnGetAccountTopCustomer(BasicAc.AccountGUID) BasicCustomerGuid
		FROM 
			TrnCloseCashier000 AS c	
			INNER JOIN TrnCloseCashierDetail000 AS detail ON detail.ParentGuid = c.GUID
			INNER JOIN TrnCurrencyAccount000 AS CloseAc ON CloseAc.CurrencyGUID = detail.CurrencyGUID AND CloseAc.ParentGUID = @GroupCurrencyAccount
			--INNER JOIN fnTrnBasicCurrencyAccount() AS BasicAc ON BasicAc.CurrencyGUID = detail.CurrencyGUID
			INNER JOIN TrnCurrencyAccount000 AS BasicAc ON BasicAc.CurrencyGUID = detail.CurrencyGUID AND BasicAc.ParentGUID = @BasicGroupCurrencyAccount
		WHERE c.GUID = @CloseGuid 
			AND detail.Amount <> 0
	ORDER BY detail.Number
	
	OPEN @Cur 
	
	FETCH FROM @Cur INTO 
		@Number, @CurrencyGUID, @Amount, @BasicAccGUID, @ExTypeAccGUID, @CustomerGUID, @BasicCustomerGUID
	
	WHILE @@FETCH_STATUS = 0 
	BEGIN

		DECLARE @IsAvgMethd			BIT,
				@CurrencyCostVal	FLOAT,
				@CurBalance			FLOAT,
				@LastDate			DATETIME
		SELECT
				@IsAvgMethd = ISAvgMethod,
				@CurrencyCostVal = CurrencyCostVal,
				@CurBalance = CurBalance,
				@LastDate = Date
		FROM FnTrnGetCurrencyCost(@CurrencyGUID, @DATE, -1, @CalcAvgMethod)		
		
		IF (ISNULL(@CurrencyCostVal, 0) = 0)
			SELECT @CurrencyCostVal = InVal FROM fnTrnGetCurrencyInOutVal(@CurrencyGUID, @DATE)
		ELSE	
		BEGIN
			IF (@IsAvgMethd = 1)
				EXEC prcTrnInsertTrnCurrencyBalance @CurrencyGUID, @CurBalance, @CurrencyCostVal, @LastDate
		END

		INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,
			   CurrencyGUID, CurrencyVal, ParentGUID, accountGUID,
			   CostGUID, ContraAccGUID, CustomerGUID)
		VALUES( 
			@Number,
			@DATE,
			@Amount * @CurrencyCostVal,
			0,	
			@CloseTypeString + @Notes,
			@CurrencyGUID,
			@CurrencyCostVal,
			@entryGuid,
			@BasicAccGUID,
			0x0,
			@ExTypeAccGUID,
			@BasicCustomerGUID)
		

		INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,
			   CurrencyGUID, CurrencyVal, ParentGUID, accountGUID,
			   CostGUID, ContraAccGUID, CustomerGUID)
		VALUES( 
			@Number + 1,
			@DATE,
			0,
			@Amount * @CurrencyCostVal,
			@CloseTypeString + @Notes,
			@CurrencyGUID,
			@CurrencyCostVal,
			@entryGuid,
			@ExTypeAccGUID,
			@costguid,
			@BasicAccGUID,
			@CustomerGUID)
		FETCH FROM @Cur INTO 
			@Number, @CurrencyGUID, @Amount, @BasicAccGUID, @ExTypeAccGUID, @CustomerGUID, @BasicCustomerGUID
	END
CLOSE @Cur
DEALLOCATE @Cur  

----------------------------------------------------
	SELECT @entryGuid AS EntryGuid  
####################################################################################
CREATE  PROC TrnGenCloseCashierCenterEntry_Credit
	@CloseGuid UNIQUEIDENTIFIER, 
	@entryNum INT,
	@OperationType INT,
	@CloseTypeString Nvarchar(250)
AS  
	SET NOCOUNT ON 
	DECLARE  
		@costguid uniqueidentifier, 
		@ExchangeAcc uniqueidentifier,
		@AccGUID UNIQUEIDENTIFIER,
		@defaultCur UNIQUEIDENTIFIER, 
		@DATE	DATETIME, 
		@enNumber  INT, 
		@entryGuid UNIQUEIDENTIFIER,
		@GroupCurrencyAccount UNIQUEIDENTIFIER,--»ÿ«ﬁ… ’‰«œÌﬁ «·⁄„·«  «·„Õœœ… ›Ì ‰„ÿ «·’—«›…
		@BasicGroupCurrencyAccount UNIQUEIDENTIFIER,--»ÿ«ﬁ… ’‰«œÌﬁ «·⁄„·«  «·—∆Ì”Ì… «·„Õœœ… ›Ì ‰„ÿ «·’—«›…
		@Notes NVARCHAR(500)

	
	SELECT
		@costguid = 0x0,
		@GroupCurrencyAccount = center.CurrencyAccountGuidCenter,
		@BasicGroupCurrencyAccount = center.ManagementCurrencyAccountGuid,
		@Notes = C.Notes,
		@AccGUID = c.AccountGuid,
		@DATE = c.[DATE]
	FROM 
		TrnCloseCashier000 AS c
		INNER JOIN TrnCenter000 as center On Center.GUID=c.UserGuid
	WHERE 
		c.guid = @CloseGuid
	
		
	IF (ISNULL(@BasicGroupCurrencyAccount,0x0) = 0x0)
		SELECT @BasicGroupCurrencyAccount = CAST(VALUE AS [UNIQUEIDENTIFIER])
	    FROM OP000 WHERE NAME  = 'TrnCfg_CurrencyAccount'

	SET @entryGuid = NEWID()  
	SELECT @defaultCur = guid FROM my000 WHERE CurrencyVal = 1
	
	INSERT INTO ce000(Number, DATE, PostDate, Debit, Credit, 
			  Notes, CurrencyVal, IsPosted, Security, Branch, GUID, CurrencyGUID)      
	SELECT 	 @entryNum , [DATE], GETDATE(), Amount, Amount, @Notes, 1, 0, security, branchGuid, 
		@entryGuid, @defaultCur 
	FROM TrnCloseCashier000 AS c	
	WHERE c.GUID = @CloseGuid  
	------------------------------------------------------
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
	------------------------------------------------------
	
	DECLARE @Cur CURSOR ,
			@Number 	INT,
			@CurrencyGUID 	UNIQUEIDENTIFIER,
			@Amount 	FLOAT,
			@BasicAccGUID  	UNIQUEIDENTIFIER,
			@ExTypeAccGUID  UNIQUEIDENTIFIER,
			@CustomerGUID  UNIQUEIDENTIFIER,
			@BasicCustomerGUID UNIQUEIDENTIFIER
			

	SET @Cur = CURSOR  FAST_FORWARD FOR
		SELECT 
			detail.Number * 2,
			detail.CurrencyGUID,
			detail.Amount,
			BasicAc.AccountGUID,
			CloseAc.AccountGUID,
			dbo.fnGetAccountTopCustomer(CloseAc.AccountGUID) CustomerGuid,
			dbo.fnGetAccountTopCustomer(BasicAc.AccountGUID) BasicCustomerGuid
		FROM 
			TrnCloseCashier000 AS c	
			INNER JOIN TrnCloseCashierDetail000 AS detail ON detail.ParentGuid = c.GUID
			INNER JOIN TrnCurrencyAccount000 AS CloseAc ON CloseAc.CurrencyGUID = detail.CurrencyGUID AND CloseAc.ParentGUID = @GroupCurrencyAccount
			INNER JOIN TrnCurrencyAccount000 AS BasicAc ON BasicAc.CurrencyGUID = detail.CurrencyGUID AND BasicAc.ParentGUID = @BasicGroupCurrencyAccount
		WHERE c.GUID = @CloseGuid 
			AND detail.Amount <> 0
	ORDER BY detail.Number
	
	OPEN @Cur 
	
	FETCH FROM @Cur INTO 
		@Number, @CurrencyGUID, @Amount, @BasicAccGUID, @ExTypeAccGUID, @CustomerGUID, @BasicCustomerGUID
	
	WHILE @@FETCH_STATUS = 0 
	BEGIN
	
		DECLARE	@IsAvgMethd			BIT,
				@CurrencyCostVal	FLOAT,
				@CurBalance			FLOAT,
				@LastDate			DATETIME
		SELECT
				@IsAvgMethd = ISAvgMethod,
				@CurrencyCostVal = CurrencyCostVal,
				@CurBalance = CurBalance,
				@LastDate = Date
		FROM FnTrnGetCurrencyCost(@CurrencyGUID, @DATE, -1, @CalcAvgMethod)		
		
		IF (ISNULL(@CurrencyCostVal, 0) = 0)
			SELECT @CurrencyCostVal = InVal FROM fnTrnGetCurrencyInOutVal(@CurrencyGUID, @DATE)
		ELSE	
		BEGIN
			IF (@IsAvgMethd = 1)
				EXEC prcTrnInsertTrnCurrencyBalance @CurrencyGUID, @CurBalance, @CurrencyCostVal, @LastDate
		END
		
		INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,
			   CurrencyGUID, CurrencyVal, ParentGUID, accountGUID,
			   CostGUID, ContraAccGUID, CustomerGUID)
		VALUES( 
			@Number + 1,
			@DATE,
			0,
			@Amount * @CurrencyCostVal,
			@CloseTypeString  + @Notes,
			@CurrencyGUID,
			@CurrencyCostVal,
			@entryGuid,
			@BasicAccGUID,
			0x0,
			@ExTypeAccGUID,
			@BasicCustomerGUID)

		INSERT INTO en000 ([Number], [DATE], [Debit], [Credit], Notes,
			   CurrencyGUID, CurrencyVal, ParentGUID, accountGUID,
			   CostGUID, ContraAccGUID, CustomerGUID)
		VALUES( 
			@Number,
			@DATE,
			@Amount * @CurrencyCostVal,
			0,	
			@CloseTypeString + @Notes,
			@CurrencyGUID,
			@CurrencyCostVal,
			@entryGuid,
			@ExTypeAccGUID,
			@costguid,
			@BasicAccGUID,
			@CustomerGUID)

		FETCH FROM @Cur INTO 
			@Number, @CurrencyGUID, @Amount, @BasicAccGUID, @ExTypeAccGUID, @CustomerGUID, @BasicCustomerGUID

	END
CLOSE @Cur
DEALLOCATE @Cur  

----------------------------------------------------
SELECT @entryGuid AS EntryGuid 
#####################################################################################
#END 