###############################################################
CREATE TRIGGER trgBeforeInsertOMT ON  TrnTransferCompanyCard000
INSTEAD  OF INSERT
NOT FOR REPLICATION
AS 
SET NOCOUNT ON
	INSERT Into TrnTransferCompanyCard000(
		[Number]
        ,[Guid]
        ,[Security]
        ,[IsOut]
        ,[BranchID]
        ,[Date]
        ,[Time]
        ,[InternalNumber]
        ,[Note]
        ,[TrnNumber]
        ,[Source]
        ,[CountryCode]
        ,[ReciveDate]
        ,[FirstPersonName]
        ,[FirstPersonFather]
        ,[FirstPersonLastName]
        ,[InCardCurrencyID]
        ,[ValueInCardCurrency]
        ,[CardCurrencyValue]
        ,[Wags]
        ,[ValueInDefaultCurrency]
        ,[ActualCurrencyValue]
        ,[DocumentTypeId]
        ,[Address]
        ,[SecondPersonName]
        ,[SecondPersonFather]
        ,[SecondPersonLastName]
        ,[TrnCause]
        ,[DocumentNumber]
        ,[UserId]
        ,[UserCenterGuid],
		[ExecutorGuid])
	SELECT 
	ISNULL((CASE
		 WHEN IsOut=0 THEN 
			(SELECT MAX(NUMBER) FROM TrnTransferCompanyCard000 where IsOut=0) 
		ELSE (SELECT MAX(NUMBER) FROM TrnTransferCompanyCard000 where IsOut=1)
	 END),0)+ ROW_NUMBER() OVER (PARTITION BY IsOut ORDER BY (SELECT 1)) 
	  ,[Guid]
      ,[Security]
      ,[IsOut]
      ,[BranchID]
      ,[Date]
      ,[Time]
      ,[InternalNumber]
      ,[Note]
      ,[TrnNumber]
      ,[Source]
      ,[CountryCode]
      ,[ReciveDate]
      ,[FirstPersonName]
      ,[FirstPersonFather]
      ,[FirstPersonLastName]
      ,[InCardCurrencyID]
      ,[ValueInCardCurrency]
      ,[CardCurrencyValue]
      ,[Wags]
      ,[ValueInDefaultCurrency]
      ,[ActualCurrencyValue]
      ,[DocumentTypeId]
      ,[Address]
      ,[SecondPersonName]
      ,[SecondPersonFather]
      ,[SecondPersonLastName]
      ,[TrnCause]
      ,[DocumentNumber]
      ,[UserId]
      ,[UserCenterGuid]
	  ,[ExecutorGuid]
	FROM inserted i
###############################################################
CREATE TRIGGER trgAfterInsertOMT ON  TrnTransferCompanyCard000
AFTER INSERT
NOT FOR REPLICATION
AS  
	SET NOCOUNT ON;
	DECLARE @tranGuid UNIQUEIDENTIFIER
	SELECT @tranGuid=guid FROM INSERTED
	
	EXEC prcTranCompanyCardGenEntry @tranGuid,0
#######################################################
CREATE TRIGGER trgAfterUpdateOMT ON  TrnTransferCompanyCard000
AFTER UPDATE
NOT FOR REPLICATION
AS  
	SET NOCOUNT ON;
	DECLARE @tranGuid UNIQUEIDENTIFIER,@UserGuid UNIQUEIDENTIFIER
	SELECT @tranGuid=guid FROM INSERTED
	SELECT @UserGuid=UserId FROM deleted
	
	EXEC prcTranCompanyCardGenEntry @tranGuid,1,@UserGuid
############################################################
CREATE TRIGGER trgAfterDeleteOMT ON  TrnTransferCompanyCard000
AFTER DELETE
NOT FOR REPLICATION
AS 
	SET NOCOUNT ON; 
	DECLARE @tranGuid UNIQUEIDENTIFIER
	SELECT @tranGuid=guid FROM deleted

	UPDATE CE000
	SET IsPosted=0
	WHERE guid IN (SELECT entryguid FROM er000 WHERE ParentGUID=@tranGuid)

	DELETE FROM ce000 
	WHERE guid IN (SELECT entryguid FROM er000 WHERE ParentGUID=@tranGuid)

	DELETE FROM er000
	WHERE ParentGUID=@tranGuid
###############################################################
CREATE PROCEDURE prcTranCompanyCardGenEntry
@TranId UNIQUEIDENTIFIER,
	@modify int,
	@UserGuid UNIQUEIDENTIFIER=0x
AS
	SET NOCOUNT ON;
	DECLARE 
		@CurrencyId UNIQUEIDENTIFIER,
		@CurrencyValue FLOAT,
		@Value FLOAT,
		@Notes VARCHAR(MAX),
		@VoucherId UNIQUEIDENTIFIER = NEWID(),
		@vocherNumber INT,
		@ceNumber INT=dbo.fnEntry_getNewNum(NULL),
		@IsOut BIT,
		@DefaultCurrencyID UNIQUEIDENTIFIER,
		@DateOMt  DateTime,
		@AccountOptionName NVARCHAR(250),
		@CreateDate DateTime,
		@CreateUserGuid UNIQUEIDENTIFIER

	SELECT
		@vocherNumber=Number,
		@CurrencyId = InCardCurrencyID,
		@CurrencyValue = CardCurrencyValue,
		@Value = CASE IsOut WHEN 1 THEN (ValueInCardCurrency + Wags) * CardCurrencyValue ELSE ValueInDefaultCurrency END,
		@Notes = Note+' Cash* '+TrnNumber+' '+dbo.fnOption_Get('TrnCfg_OMT_CompanyName','8000'),
		@IsOut = IsOut,
		@DefaultCurrencyID = (SELECT TOP 1 Guid FROM my000 WHERE CurrencyVal = 1),
		@DateOMt =Date,
		@AccountOptionName = CASE IsOut WHEN 1 THEN 'TrnCfg_OMT_OutTranAccGuid' ELSE 'TrnCfg_OMT_InTranAccGuid' END
	FROM
		TrnTransferCompanyCard000
	WHERE Guid = @TranId;
	IF(@modify = 1)
	BEGIN
		DECLARE @g UNIQUEIDENTIFIER=(SELECT EntryGUID FROM er000 WHERE ParentGUID=@TranId)
		SELECT 
			@ceNumber = Number, 
			@CreateDate = CreateDate, 
			@CreateUserGuid = CreateUserGUID 
		FROM ce000 WHERE guid=@g
		DELETE FROM er000 WHERE EntryGUID=@g
		UPDATE CE000
			SET IsPosted=0
		WHERE guid=@g
		DELETE FROM ce000 WHERE guid=@g
	END
	INSERT INTO ce000(GUID, Type, Number, Security, Date, Debit, Credit, TypeGUID, IsPosted, PostDate, CurrencyGUID, CurrencyVal, Notes)
	
	VALUES(@VoucherId, 1,@ceNumber , 1, @DateOMt, @Value, @Value, 0x, 0, GETDATE(), @CurrencyId, @CurrencyValue, @Notes)

	;WITH UserAcc AS
	(
		SELECT 
			CASE @IsOut WHEN 1 THEN CU.AccountGUID ELSE dbo.fnOption_GetGUID(@AccountOptionName) END AS FirstAccount, 
			CASE @IsOut WHEN 0 THEN CU.AccountGUID ELSE dbo.fnOption_GetGUID(@AccountOptionName) END AS SecondAccount, 
			CU.CurrencyGUID, 
			c.CostGuid
		FROM 
			TrnCurrencyAccount000 AS CU 
			JOIN TrnUserConfig000 AS C ON C.GroupCurrencyAccGUID = CU.ParentGUID
		WHERE 
			UserGuid = CASE WHEN @modify = 1 THEN @UserGuid ELSE dbo.fnGetCurrentUserGUID() END
			AND ((CurrencyGUID = @CurrencyId AND @IsOut = 1) OR (@IsOut = 0 AND CurrencyGUID = @DefaultCurrencyID))
	)
	INSERT INTO en000(GUID, Number, Date, AccountGUID, CostGUID, Debit, Credit, CurrencyGUID, CurrencyVal, ParentGUID, ContraAccGUID, CustomerGUID) 
	SELECT
		NEWID(),
		0,
		@DateOMt,
		FirstAccount,
		CASE @IsOut WHEN 1 THEN U.CostGuid ELSE 0x END,
		@Value,
		0,
		@CurrencyId,
		@CurrencyValue,
		@VoucherId,
		SecondAccount,
		dbo.fnGetAccountTopCustomer(FirstAccount)
	FROM UserAcc U 
	UNION ALL
	SELECT
		NEWID(),
		1,
		@DateOMt,
		SecondAccount,
		CASE @IsOut WHEN 0 THEN U.CostGuid ELSE 0x END,
		0,
		@Value,
		CASE @IsOut WHEN 1 THEN @CurrencyId ELSE @DefaultCurrencyID END,
		CASE @IsOut WHEN 1 THEN @CurrencyValue ELSE 1 END,
		@VoucherId,
		FirstAccount,
		dbo.fnGetAccountTopCustomer(SecondAccount) 
	FROM UserAcc U
	
	INSERT INTO [er000] ([EntryGUID],[ParentGUID],[ParentType],[ParentNumber])  
	VALUES(@VoucherId, @TranId, 524, @vocherNumber)  

	UPDATE [ce000] SET [IsPosted] = 1,
	CreateDate =
		CASE WHEN @modify = 1 THEN  @CreateDate ELSE GETDATE() END,
	CreateUserGUID =
		CASE WHEN @modify = 1 THEN  @CreateUserGuid ELSE [dbo].[fnGetCurrentUserGUID]() END,
	LastUpdateDate = 
		CASE WHEN @modify = 1 THEN  GETDATE() ELSE LastUpdateDate END,
	LastUpdateUserGUID =
		CASE WHEN @modify = 1 THEN  [dbo].[fnGetCurrentUserGUID]() ELSE LastUpdateUserGUID END
	WHERE Guid = @VoucherId  
##########################################################
CREATE PROCEDURE prcTranCompanyCardGenEntryCancelWithoutWags
	@TranId UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON;

	DECLARE 
		@CurrencyId UNIQUEIDENTIFIER,
		@CurrencyValue FLOAT,
		@Value FLOAT,
		@Notes VARCHAR(MAX),
		@VoucherId UNIQUEIDENTIFIER = NEWID(),
		@vocherNumber INT,
		@ceNumber INT=dbo.fnEntry_getNewNum(NULL),
		@AccCustomerGUID UNIQUEIDENTIFIER,
		@OutTranCustomerGUID  UNIQUEIDENTIFIER,
		@CustomerGUID UNIQUEIDENTIFIER

	SELECT
		@vocherNumber=Number,
		@CurrencyId = InCardCurrencyID,
		@CurrencyValue = CardCurrencyValue,
		@Value = ValueInCardCurrency,
		@Notes = Note +' Cancel* '+TrnNumber+' '+dbo.fnOption_Get('TrnCfg_OMT_CompanyName','8000')
	FROM
		TrnTransferCompanyCard000
	WHERE Guid = @TranId;

	INSERT INTO ce000(GUID, Type, Number, Security, Date, Debit, Credit, TypeGUID, IsPosted, PostDate, CurrencyGUID, CurrencyVal, Notes)
	
	VALUES(@VoucherId, 1,@ceNumber , 1, GETDATE(), 0, 0, 0x, 0, GETDATE(), @CurrencyId, @CurrencyValue, @Notes)

	SELECT CU.* ,c.CostGuid
	INTO #TMP
	FROM 
		TrnCurrencyAccount000 AS CU 
		JOIN TrnUserConfig000 AS C ON C.GroupCurrencyAccGUID = CU.ParentGUID
	WHERE 
		UserGuid = dbo.fnGetCurrentUserGUID()

		SELECT @AccCustomerGUID = dbo.fnOption_GetGUID('TrnCfg_OMT_OutTranAccGuid');
		IF EXISTS (SELECT * FROM vwaccu WHERE GUID = @AccCustomerGUID AND CustomersCount = 1)
		BEGIN
			SELECT  @OutTranCustomerGUID = cuGuid FROM vwCu cu WHERE cuAccount = @AccCustomerGUID
		END


		SELECT @AccCustomerGUID = AccountGUID FROM #TMP WHERE CurrencyGUID = @CurrencyId
		IF EXISTS (SELECT * FROM vwaccu WHERE GUID = @AccCustomerGUID AND CustomersCount = 1)
		BEGIN
			SELECT  @CustomerGUID = cuGuid FROM vwCu cu WHERE cuAccount = @AccCustomerGUID
		END


	INSERT INTO en000(GUID, Number, Date, AccountGUID, CostGUID, Debit, Credit, CurrencyGUID, CurrencyVal, ParentGUID, ContraAccGUID, CustomerGUID) 
	SELECT
		NEWID(),
		0,
		GETDATE(),
		dbo.fnOption_GetGUID('TrnCfg_OMT_OutTranAccGuid'),
		0x,
		@Value * @CurrencyValue,
		0,
		@CurrencyId,
		@CurrencyValue,
		@VoucherId,
		t.AccountGUID,
		ISNULL(@OutTranCustomerGUID, 0x0)
	FROM #TMP t WHERE CurrencyGUID = @CurrencyId
	UNION ALL
	SELECT
		NEWID(),
		1,
		GETDATE(),
		t.AccountGUID,
		t.CostGuid,
		0,
		@Value * @CurrencyValue,
		@CurrencyId,
		@CurrencyValue,
		@VoucherId,
		dbo.fnOption_GetGUID('TrnCfg_OMT_OutTranAccGuid'),
		ISNULL(@CustomerGUID, 0x0)
	FROM #TMP t WHERE CurrencyGUID = @CurrencyId
	
	
	INSERT INTO [er000] ([EntryGUID],[ParentGUID],[ParentType],[ParentNumber])  
	VALUES(@VoucherId, @TranId, 526, @vocherNumber) 

	UPDATE ce000
	SET IsPosted=1
	WHERE guid=@VoucherId
###################################################################
CREATE PROCEDURE prcTranCompanyCardGenEntryCancel
	@TranId UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON;
	
	DECLARE 
		@CurrencyId UNIQUEIDENTIFIER,
		@CurrencyValue FLOAT,
		@Value FLOAT,
		@Notes VARCHAR(MAX),
		@VoucherId UNIQUEIDENTIFIER = NEWID(),
		@vocherNumber INT,
		@ceNumber INT=dbo.fnEntry_getNewNum(NULL),
		@IsOut BIT,
		@DefaultCurrencyID UNIQUEIDENTIFIER,
		@AccountOptionName NVARCHAR(250),
		@Ceguid UNIQUEIDENTIFIER	
	SELECT
		@vocherNumber=Number,
		@CurrencyId = InCardCurrencyID,
		@CurrencyValue = CardCurrencyValue,
		@Value = CASE IsOut WHEN 1 THEN (ValueInCardCurrency + Wags) * CardCurrencyValue ELSE ValueInDefaultCurrency END,
		@Notes = Note +' Cancel* '+TrnNumber+' '+dbo.fnOption_Get('TrnCfg_OMT_CompanyName','8000'),
		@IsOut = IsOut,
		@DefaultCurrencyID = (SELECT TOP 1 Guid FROM my000 WHERE CurrencyVal = 1),
		@AccountOptionName = CASE IsOut WHEN 1 THEN 'TrnCfg_OMT_OutTranAccGuid' ELSE 'TrnCfg_OMT_InTranAccGuid' END
	FROM
		TrnTransferCompanyCard000
	WHERE Guid = @TranId;

	SELECT 
		@Ceguid=EntryGUID
	FROM 
		Er000
	WHERE ParentGUID=@TranId

	INSERT INTO ce000(GUID, Type, Number, Security, Date, Debit, Credit, TypeGUID, IsPosted, PostDate, CurrencyGUID, CurrencyVal, Notes)
	VALUES(@VoucherId, 1,@ceNumber , 1, GETDATE(), @Value, @Value, 0x, 0, GETDATE(), @CurrencyId, @CurrencyValue, @Notes)

	INSERT INTO en000(GUID, Number, Date, AccountGUID, CostGUID, Debit, Credit, CurrencyGUID, CurrencyVal, ParentGUID, ContraAccGUID, CustomerGuid) 
	SELECT 
		NEWID(),
		number,
		GetDate(),
		AccountGUID ,
		CostGUID,
		CASE WHEN Debit > 0 THEN 0 ELSE credit END ,
		CASE WHEN credit > 0 THEN 0 ELSE Debit END ,
		CurrencyGUID,
		CurrencyVal,
		@VoucherId,
		ContraAccGUID ,
		dbo.fnGetAccountTopCustomer(AccountGUID) 
	FROM en000
	WHERE ParentGUID=@Ceguid 
	

	INSERT INTO [er000] ([EntryGUID],[ParentGUID],[ParentType],[ParentNumber])  
	VALUES(@VoucherId, @TranId, 525, @vocherNumber)  

	UPDATE ce000
	SET IsPosted=1
	WHERE guid=@VoucherId
######################################################################
CREATE VIEW InCardCompany AS
SELECT tc.* FROM TrnTransferCompanyCard000 AS tc
INNER JOIN [TrnBranch000] AS [tbr] ON [tc].[BranchID] = [tbr].[GUID]
INNER JOIN [vwBr] AS [br] ON [br].[brGUID] = [tbr].[AmnBranchGUID]
WHERE tc.IsOut = 0 AND 
(
(SELECT TOP 1 bAdmin FROM us000
WHERE GUID  = (SELECT dbo.fnGetCurrentUserGUID())) = 1
OR
ISNULL((SELECT TOP 1 Permission FROM [dbo].[ui000] AS ui WHERE ui.ReportId = 536932690 AND ui.UserGUID = (SELECT dbo.fnGetCurrentUserGUID())),0) = 1
OR tc.UserCenterGuid = (SELECT TOP 1 CenterGuid FROM TrnUserConfig000 WHERE UserGuid = (SELECT dbo.fnGetCurrentUserGUID()))
)
##################################################
CREATE VIEW OutCardCompany AS
SELECT tc.* FROM TrnTransferCompanyCard000 AS tc
INNER JOIN [TrnBranch000] AS [tbr] ON [tc].[BranchID] = [tbr].[GUID]
INNER JOIN [vwBr] AS [br] ON [br].[brGUID] = [tbr].[AmnBranchGUID]
WHERE tc.IsOut = 1 AND 
(
(SELECT TOP 1 bAdmin FROM us000
WHERE GUID  = (SELECT dbo.fnGetCurrentUserGUID())) = 1
OR
ISNULL((SELECT TOP 1 Permission FROM [dbo].[ui000] AS ui WHERE ui.ReportId = 536932689 AND ui.UserGUID = (SELECT dbo.fnGetCurrentUserGUID())),0) = 1
OR tc.UserCenterGuid = (SELECT TOP 1 CenterGuid FROM TrnUserConfig000 WHERE UserGuid = (SELECT dbo.fnGetCurrentUserGUID()))
)
#########################################
CREATE PROCEDURE prcTranCompanyCardGenEntryMain
@fromDate DATETIME='1-1-2016',
@EndDate DATETIME='1-12-2016'
AS
	SET NOCOUNT ON;

	SELECT 	* 
	 INTO #temp
	FROM 
		TrnTransferCompanyCard000
	WHERE	
		IsOut=0 
		AND Guid NOT IN (SELECT ParentGUID FROM ER000 where ParentType =525) 
		AND ValueInCardCurrency > 0 AND (Date BETWEEN @fromDate AND @EndDate)

	SELECT * 
	INTO #temp2 
	FROM
		 ER000
	WHERE 
		ParentGUID IN (SELECT guid FROM #temp)

	DECLARE @curGuid UNIQUEIDENTIFIER=(SELECT GUID FROM my000 where CurrencyVal=1)
	
	EXEC [prcDisableTriggers] 'ce000', 0
	EXEC [prcDisableTriggers] 'en000', 0

	INSERT INTO en000(GUID, Number, AccountGUID, CostGUID, Debit, Credit, CurrencyGUID, CurrencyVal, ParentGUID, ContraAccGUID,Notes) 
	SELECT 
		NEWID(),
		2,
		CASE WHEN e.Debit - (t2.ValueInCardCurrency* E.CurrencyVal) > 0 THEN dbo.fnOption_GetGUID('TrnCfg_OMT_NegativeExchangeDiffAccGuid') ELSE dbo.fnOption_GetGUID('TrnCfg_OMT_PositiveExchangeDiffAccGuid')END,
		0x0,
		CASE WHEN e.Debit - (t2.ValueInCardCurrency* E.CurrencyVal) > 0 THEN abs(e.Debit - (t2.ValueInCardCurrency* E.CurrencyVal)) ELSE 0 END,
		CASE WHEN e.Debit - (t2.ValueInCardCurrency* E.CurrencyVal) < 0 THEN abs(e.Debit - (t2.ValueInCardCurrency* E.CurrencyVal)) ELSE 0 END,
		@curGuid,
		1,
		e.ParentGUID,
		0x0,
		e.Notes
	FROM 
		en000 e INNER JOIN #temp2 t ON  EntryGUID=e.ParentGUID
		INNER JOIN #temp t2 ON t.ParentGUID=t2.Guid
		WHERE abs(e.Debit - (t2.ValueInCardCurrency* E.CurrencyVal) )>  0  AND e.Number=0 AND e.CurrencyVal =t2.CardCurrencyValue AND e.CurrencyGUID=t2.InCardCurrencyID;

	UPDATE e
		SET Debit = t2.ValueInCardCurrency*e.CurrencyVal
	FROM 
		en000 e INNER JOIN #temp2 t ON  EntryGUID=e.ParentGUID
		INNER JOIN #temp t2 ON t.ParentGUID=t2.Guid AND e.Number=0 AND e.CurrencyGUID=t2.InCardCurrencyID;
	
	EXEC [prcEnableTriggers] 'ce000'
	EXEC [prcEnableTriggers] 'en000'

	SELECT 
		* 
	FROM 
		TrnTransferCompanyCard000
	WHERE	
		IsOut=0 AND (Date BETWEEN @fromDate AND @EndDate)
		AND (Guid  IN (SELECT ParentGUID FROM ER000 where ParentType =525) OR  ValueInCardCurrency <= 0) AND (Date BETWEEN @fromDate AND @EndDate)
		ORDER BY Number
####################################################################
#END