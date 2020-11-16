###############################################################################
CREATE PROC prcCheque_ReadEntries
	@ChequeGUID UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 

	SELECT 
		ce.GUID AS EntryGUID,
		er.ParentType AS EntryRelatedType,
		ce.Number AS EntryNumber,
		ce.Date AS EntryDate,
		ISNULL([ColCh].[Number], 0) AS [ColPartNumber]
	FROM 
		ch000 ch 
		INNER JOIN er000 er ON er.ParentGUID = ch.GUID 
		INNER JOIN ce000 ce ON er.EntryGUID = ce.GUID 
		LEFT JOIN [ColCh000] [ColCh] ON [ce].[GUID] = [ColCh].[EntryGUID]
	WHERE 
		ch.GUID = @ChequeGUID
	ORDER BY 
		ISNULL([ColCh].[Number], 0),
		ce.Number
###############################################################################
CREATE PROCEDURE prcCheque_History_Add
	@ChGUID UNIQUEIDENTIFIER,
	@Date DATETIME,
	@State INT,
	@EventType INT,
	@EntryGuid UNIQUEIDENTIFIER,
	@DebitGuid UNIQUEIDENTIFIER,
	@CreditGuid UNIQUEIDENTIFIER,
	@EventVal FLOAT,
	@EntryRelType INT, 
	@CurrencyGUID UNIQUEIDENTIFIER,
	@CurrencyVal FLOAT,
	@ColChGUID UNIQUEIDENTIFIER,
	@ExchangeRatesValue FLOAT,
	@CostDebit UNIQUEIDENTIFIER,
	@CostCredit UNIQUEIDENTIFIER,
	@DebitCustomer UNIQUEIDENTIFIER,
	@CreditCustomer UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	DECLARE @Num INT
	SET @Num = (SELECT Number FROM ce000 WHERE [GUID] = @EntryGuid)
	INSERT INTO [ChequeHistory000](
		[Number],
		[GUID],
		[ChequeGUID],
		[Date],
		[State],
		[EventNumber],
		[EntryNumber],
		[DebitAccount],
		[CreditAccount],
		[EventVal],
		[EntryRelType], 
		[EntryGUID], 
		[CurrencyGUID],
		[CurrencyVal],
		[ColChGuid], 
		[ExchangeRatesValue],
		[CostDebit],
		[CostCredit],
		[DebitCustomer],
		[CreditCustomer])
	VALUES(
		(SELECT ISNULL(MAX(Number), 0) FROM [ChequeHistory000] WHERE ChequeGUID = @ChGUID) + 1,
		NEWID(),
		@ChGUID,
		@Date,
		@State,
		@EventType,
		ISNULL(@Num, 0),
		@DebitGuid,
		@CreditGuid,
		@EventVal,
		@EntryRelType, 
		@EntryGuid, 	
		@CurrencyGUID,	
		@CurrencyVal,
		@ColChGUID,
		@ExchangeRatesValue,
		@CostDebit,
		@CostCredit,
		@DebitCustomer,
		@CreditCustomer)
###############################################################################
CREATE PROCEDURE prcCheque_History_Delete
	@ChGUID UNIQUEIDENTIFIER,
	@EventType INT
AS
	SET NOCOUNT ON
	DECLARE @ChequeHistoryGUID UNIQUEIDENTIFIER
	SELECT TOP 1 
		@ChequeHistoryGUID = [GUID]
	FROM 
		[ChequeHistory000] 
	WHERE 
		ChequeGUID = @ChGUID
		AND 
		[EventNumber] = @EventType
	ORDER BY 
		[Number] DESC 

	IF ISNULL(@ChequeHistoryGUID, 0x0) != 0x0
	BEGIN 
		DELETE [ChequeHistory000] WHERE [GUID] = @ChequeHistoryGUID
	END 
###############################################################################
CREATE PROCEDURE prcCheque_History_Delete_Col
	@ChGUID UNIQUEIDENTIFIER,
	@EventType INT,
	@ColchGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	DECLARE @ChequeHistoryGUID UNIQUEIDENTIFIER
	SELECT TOP 1 
		@ChequeHistoryGUID = [GUID]
	FROM 
		[ChequeHistory000] 
	WHERE 
		ChequeGUID = @ChGUID
		AND 
		[EventNumber] = @EventType
		AND
		 [ColChGuid] = @ColchGuid
	ORDER BY 
		[Number] DESC 

	IF ISNULL(@ChequeHistoryGUID, 0x0) != 0x0
	BEGIN 
		DELETE [ChequeHistory000] WHERE [GUID] = @ChequeHistoryGUID
	END 
###############################################################################
CREATE  PROCEDURE prcCheque_ReadEntryAccounts
	@ChequeGUID UNIQUEIDENTIFIER,
	@ParentType INT
AS
	SET NOCOUNT ON

	SELECT TOP 1
		DebitAccount,
		CreditAccount,
		CostDebit,
		CostCredit,
		DebitCustomer, 
		CreditCustomer
	FROM 
		ChequeHistory000 ch
	WHERE 
		ch.ChequeGUID = @ChequeGUID
		AND  
		ch.EntryRelType = @ParentType 
	ORDER BY 
		Number desc
###############################################################################
CREATE PROCEDURE prcCheque_GetEntryGUID
	@ChequeGUID UNIQUEIDENTIFIER,
	@ParentType INT
AS
	SET NOCOUNT ON

	SELECT TOP 1 ce.[GUID] AS EntryGUID
	FROM
		ch000 ch 
		INNER JOIN er000 er ON ch.GUID = er.ParentGUID 
		INNER JOIN ce000 ce ON er.EntryGUID = ce.GUID
	WHERE 
		ch.GUID = @ChequeGuid
		AND 
		er.ParentType = @ParentType
	ORDER BY 
		ce.Number DESC
###############################################################################
CREATE PROCEDURE RepChequeHistory
	@ChGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	SELECT 
		ch.Guid as Guid,
		ch.Date as Date,
		ch.State as State,
		EventNumber,
		ch.State as State1,
		EventNumber as EventNumber1,
		CASE WHEN ISNULL((CASE 
					WHEN ((ch.state = 0) AND (ch.EventNumber = 33) AND CAST(ISNULL(EntryNumber,0) AS NVARCHAR(MAX))=  '0' ) THEN 
					(SELECT number FROM ce000 ce inner join er000 er on er.entryguid= ce.guid WHERE er.parentguid=@ChGUID AND  er.parenttype = 5 )	 
					ELSE CAST(EntryNumber AS NVARCHAR(MAX)) END ) ,'0') = '0' then '' 

				ELSE CAST(EntryNumber AS NVARCHAR(MAX))  
		END
		AS EntryNumber,
		AD.Code AS DebitAccCode,
		AD.Name AS DebitAccName,
		AD.LatinName AS DebitAccLatinName, 
		AC.Code AS CreditAccCode,
		AC.Name AS CreditAccName,
		AC.LatinName AS CreditAccLatinName,
		ch.EventVal AS EventVal,
		ch.ExchangeRatesValue AS ExchangeRatesValue,
		cuD.CustomerName AS DebitCustName,
		cuD.LatinName AS DebitCustLatinName,
		cuC.CustomerName AS CreditCustName,
		cuC.LatinName AS CreditCustLatinName
	FROM 
		ChequeHistory000 ch
		LEFT JOIN vdAc AD ON AD.GUID = DebitAccount
		LEFT JOIN vdAc AC ON AC.GUID = CreditAccount
		LEFT JOIN vdCu cuD ON cuD.[GUID] = DebitCustomer AND cuD.[AccountGUID] = AD.GUID
		LEFT JOIN vdCu cuC ON cuC.[GUID] = CreditCustomer AND cuC.[AccountGUID] = AC.GUID
	WHERE 
		ChequeGUID = @ChGUID
	ORDER BY 
		ch.Number
###############################################################################
CREATE PROCEDURE prcDeleteChequehistory
	@ChequeGuid UNIQUEIDENTIFIER
AS
	DELETE FROM ChequeHistory000
	WHERE ChequeGUID=@ChequeGuid
#####################################################################################
CREATE FUNCTION fnIsAccountFoundInPortfolio(@Guid UNIQUEIDENTIFIER, @Type INT)
RETURNS INT
BEGIN
	
	IF( @type = 1) 
	BEGIN
		IF EXISTS  (SELECT * FROM vReceiveAcc 
						WHERE Guid = @Guid )
		RETURN 1; 
	END
	ELSE IF (@type = 2 )
	BEGIN
		IF EXISTS  (SELECT * FROM  vPayAcc  
						WHERE Guid = @Guid )
		RETURN 1; 	
	END
	ELSE IF (@type = 3)
	BEGIN
		 IF EXISTS  (SELECT * FROM  vUnderDiscountingAcc  
							WHERE Guid = @Guid )
		 RETURN 1; 
	END
	ELSE IF(@type = 4)
	BEGIN
		 IF EXISTS  (SELECT * FROM vDiscountingAcc
							WHERE Guid = @Guid )
		 RETURN 1; 
	END
	ELSE IF(@type = 5)
	BEGIN
		IF EXISTS  (SELECT * FROM vCollectiONAcc 
							WHERE Guid = @Guid )
		RETURN 1; 
	END
	ELSE IF(@type = 6)
	BEGIN
		IF EXISTS  (SELECT * FROM  vEndorsementAcc 
							WHERE Guid = @Guid )
		RETURN 1; 
	END
	ELSE IF (@type = 7)
	BEGIN
			IF EXISTS  (SELECT * FROM  vReceivePayAcc 
							WHERE Guid = @Guid )
		RETURN 1; 
	END
	RETURN 0;
END
###################################################################################
CREATE PROC prcCheque_GetEventCurrencyInfo
	@ChequeGUID UNIQUEIDENTIFIER,
	@ParentNumber INT 
AS 
	SET NOCOUNT ON 
	SELECT TOP 1 
		CurrencyGUID, 
		CurrencyVal, 
		EventVal
	FROM 
		ChequeHistory000
	WHERE 
		ChequeGUID = @ChequeGUID
		AND 
		EntryRelType = @ParentNumber
	ORDER BY 
		Number DESC
##################################################################################
CREATE PROCEDURE prcDeleteEventAccCostRatio
	@ChequeGUID UNIQUEIDENTIFIER,
	@ParentType INT
AS
 
	DELETE FROM AccCostnewRatio000
	WHERE ParentGuid =@ChequeGUID AND Entry_Rel=@ParentType
###################################################################################
CREATE PROC prcBill_RelatedCheques
	@BillGUID UNIQUEIDENTIFIER
AS 
	DECLARE @canDelete BIT 
	SET @canDelete = 1
	IF EXISTS (
		SELECT * FROM 
			bu000 bu 
			INNER JOIN ch000 ch ON ch.ParentGUID = bu.GUID 
			INNER JOIN nt000 nt ON ch.TypeGUID = nt.GUID 
		WHERE bu.GUID = @BillGUID AND ((ch.state != 0) AND (ch.state != 14) AND (nt.bCanFinishing = 0))) 
			SET @canDelete = 0

	SELECT 
		(SELECT COUNT(*) FROM ch000 WHERE ParentGUID = @BillGUID) AS ChequesCount,
		@canDelete AS CanDelete
###################################################################################
CREATE FUNCTION fnCheque_HasEvents(@ChequeGUID UNIQUEIDENTIFIER)
	RETURNS BIT 
AS 
BEGIN 
	DECLARE @State INT 
	SELECT @State = [State] FROM ch000 WHERE [GUID] = @ChequeGUID

	IF @State != 0
		RETURN 1

	IF EXISTS(SELECT * FROM ChequeHistory000 WHERE ChequeGUID = @ChequeGUID AND EventNumber != 33 AND EventNumber != 34)
		RETURN 1
	
	RETURN 0
END 	
###################################################################################
CREATE function fnIsGenByPOSPayRecEntry(@checkGuid UNIQUEIDENTIFIER)
RETURNS int 
AS 
BEGIN
    IF (@checkGuid in (SELECT guid FROM POSPayRecieveTable000))
	BEGIN
	    RETURN 1 
	END
	RETURN 0
END		
###################################################################################
CREATE FUNCTION fnGetLastChequeHistory(@ChequeId UNIQUEIDENTIFIER)
RETURNS TABLE
AS
	RETURN (SELECT TOP 1 * FROM ChequeHistory000 WHERE ChequeGUID = @ChequeId ORDER BY Number Desc)
###################################################################################
CREATE FUNCTION fnGetLastChequeHistoryDate(@ChequeId UNIQUEIDENTIFIER)
RETURNS DATETIME
AS
BEGIN
	DECLARE @chDate DATETIME
    SET @chDate = (SELECT TOP (1) Date FROM ChequeHistory000 WHERE ChequeGUID = @ChequeId ORDER BY Number DESC)
	RETURN @chDate
END
###################################################################################
#END
