################################################################################
CREATE FUNCTION NSEntryGetCustomerInfo(@ObjectGuid UNIQUEIDENTIFIER)
RETURNS @receiver TABLE 
(
		[GUID]			UNIQUEIDENTIFIER,
		receiverName	CHAR(15),
		mailAddress1	NVARCHAR(100),
		smsAddress1		VARCHAR(20),
		mailAddress2	NVARCHAR(100),
		smsAddress2		VARCHAR(20),
		NSNotSendSMS			BIT,
		NSNotSendEmail			BIT
)
AS 
BEGIN
	INSERT INTO @receiver select 0x0, 'Entry customer', cu.nsemail1, cu.nsmobile1, cu.nsemail2, cu.nsmobile2 , cu.NSNotSendSMS, cu.NSNotSendEmail FROM vwCu CU 
	INNER JOIN ac000 AC on AC.[GUID] = CU.cuAccount
	INNER JOIN vwEn EN ON En.enGUID = @objectGuid and  EN.enAccount = AC.[GUID]
	RETURN
END
################################################################################
CREATE FUNCTION NSFnEntryInfo(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
returns @EntryInfo table 
(
		cuCustomerName		NVARCHAR(255),
		cuCustomerPrefix	NVARCHAR(255),
		cuCustomerSuffix	NVARCHAR(255),
		cuCustomerLName		NVARCHAR(255),
		EntryNumber			INT,
		EntryDate			DATE,
		EntryValue			NVARCHAR(255),
		CostName			NVARCHAR(255),
		BranchName			NVARCHAR(255),
		TypeName			NVARCHAR(255)
)
AS 
BEGIN
	INSERT INTO @EntryInfo
    SELECT CU.cuCustomerName,
	CU.cuPrefix ,
	CU.cuSuffix ,
	CU.cuLatinName,
	CASE WHEN ISNULL(ER.ParentNumber, 0) = 0 THEN ENCE.ceNumber ELSE ER.ParentNumber END,
	ENCE.ceDate,
	[dbo].fnNSFormatMoneyAsNVARCHAR(ABS((ENCE.enDebit - ENCE.enCredit) / ENCE.enCurrencyVal), MY.Code),
	CO.Name,
	br.brName,
	et.Name
	FROM vwCu CU
    INNER JOIN ac000 AC on AC.[GUID] = CU.cuAccount
    INNER JOIN vwCeEn ENCE ON ENCE.enAccount = AC.[GUID] AND ENCE.enGUID = @ObjectGuid
	LEFT JOIN et000 et ON ENCE.ceTypeGUID = et.GUID
	INNER JOIN my000 MY ON ENCE.enCurrencyPtr = MY.[GUID]
	LEFT JOIN er000 ER ON ER.EntryGUID = ENCE.ceGUID
	LEFT JOIN co000 CO on CO.GUID = ENCE.enCostPoint
	LEFT JOIN vwbr br ON br.brGUID = ENCE.ceBranch 
	RETURN
END
################################################################################
CREATE FUNCTION NSEntryCustBal(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @EntryCustInfo TABLE 
(
		EntryCustBal NVARCHAR(255)
)
AS 
BEGIN
	DECLARE @eventConditonGuid UNIQUEIDENTIFIER = (SELECT EventConditionGuid FROM NSMessage000 WHERE Guid = @messageGuid)
	DECLARE @readUnPosted Bit =  (SELECT DC.ReadUnPosted from NSEntryEventCondition000 DC where DC.EventConditionGuid = @eventConditonGuid)
	
	DECLARE @ACCGUID   UNIQUEIDENTIFIER

	SELECT @ACCGUID = ENCE.enAccount  FROM vwCeEn ENCE
                WHERE ENCE.[enGUID] = @objectGuid

	INSERT INTO @EntryCustInfo
    SELECT  AccBalancesWithCurrCode FROM fnNSGetAccBalWithCostAndBranch(@ACCGUID,0x0,0x0,@readUnPosted)
	RETURN
end
################################################################################
CREATE FUNCTION NSEntryCustBalWithCost(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @EntryCustInfo TABLE 
(
		EntryCustBalCost NVARCHAR(255)
)
AS 
BEGIN
	DECLARE @eventConditonGuid UNIQUEIDENTIFIER = (SELECT EventConditionGuid FROM NSMessage000 WHERE Guid = @messageGuid)
	DECLARE @readUnPosted Bit =  (SELECT DC.ReadUnPosted from NSEntryEventCondition000 DC where DC.EventConditionGuid = @eventConditonGuid)

	DECLARE @ACCGUID   UNIQUEIDENTIFIER
	DECLARE @COSTGUID  UNIQUEIDENTIFIER 

	SELECT @COSTGUID = ENCE.enCostPoint ,@ACCGUID = ENCE.enAccount  FROM vwCeEn ENCE
                WHERE ENCE.[enGUID] = @objectGuid

	INSERT INTO @EntryCustInfo
    SELECT  AccBalancesWithCurrCode FROM fnNSGetAccBalWithCostAndBranch(@ACCGUID,@COSTGUID,0x0,@readUnPosted)
	RETURN
end
################################################################################
CREATE FUNCTION NSEntryCustBalWithBranch(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @EntryCustInfo TABLE 
(
		EntryCustBalBranch NVARCHAR(255)
)
AS 
BEGIN
	DECLARE @eventConditonGuid UNIQUEIDENTIFIER = (SELECT EventConditionGuid FROM NSMessage000 WHERE Guid = @messageGuid)
	DECLARE @readUnPosted Bit =  (SELECT DC.ReadUnPosted from NSEntryEventCondition000 DC where DC.EventConditionGuid = @eventConditonGuid)
	DECLARE @ACCGUID   UNIQUEIDENTIFIER
	DECLARE @BRANCHGUID  UNIQUEIDENTIFIER 

	SELECT @BRANCHGUID = ENCE.ceBranch ,@ACCGUID = ENCE.enAccount  FROM vwCeEn ENCE
                WHERE ENCE.[enGUID] = @objectGuid

	INSERT INTO @EntryCustInfo
    SELECT  AccBalancesWithCurrCode FROM fnNSGetAccBalWithCostAndBranch(@ACCGUID,0x0,@BRANCHGUID,@readUnPosted)
	RETURN
end
################################################################################
CREATE FUNCTION NSEntryCustBalWithCostAndBr(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @EntryCustInfo TABLE 
(
		EntryCustBalCostBR NVARCHAR(255)
)
AS 
BEGIN
	DECLARE @eventConditonGuid UNIQUEIDENTIFIER = (SELECT EventConditionGuid FROM NSMessage000 WHERE Guid = @messageGuid)
	DECLARE @readUnPosted Bit =  (SELECT DC.ReadUnPosted from NSEntryEventCondition000 DC where DC.EventConditionGuid = @eventConditonGuid)
	
	DECLARE @ACCGUID   UNIQUEIDENTIFIER
	DECLARE @COSTGUID  UNIQUEIDENTIFIER 
	DECLARE @BRANCHGUID  UNIQUEIDENTIFIER 

	SELECT @BRANCHGUID = ENCE.ceBranch ,@COSTGUID = ENCE.enCostPoint ,@ACCGUID = ENCE.enAccount  FROM vwCeEn ENCE
                WHERE ENCE.[enGUID] = @objectGuid

	INSERT INTO @EntryCustInfo
    SELECT  AccBalancesWithCurrCode FROM fnNSGetAccBalWithCostAndBranch(@ACCGUID,@COSTGUID,@BRANCHGUID,@readUnPosted)
	RETURN
end
################################################################################
CREATE FUNCTION NSEntryCustDiffFromMaxBalance(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @EntryInfo TABLE 
(
		EntryCustDiffFromMaxBalance NVARCHAR(255)
)
AS 
BEGIN
	DECLARE @eventConditonGuid UNIQUEIDENTIFIER = (SELECT EventConditionGuid FROM NSMessage000 WHERE Guid = @messageGuid)
	DECLARE @readUnPosted Bit =  (SELECT DC.ReadUnPosted from NSEntryEventCondition000 DC where DC.EventConditionGuid = @eventConditonGuid)

	DECLARE @ACCGUID   UNIQUEIDENTIFIER

	SELECT @ACCGUID = ENCE.enAccount  FROM vwCeEn ENCE
                WHERE ENCE.[enGUID] = @objectGuid

	INSERT INTO @EntryInfo
    SELECT  DiffFromMaxDebitWithCurrCode FROM fnNSGetAccDiffFromMaxBalanceInfo(@ACCGUID , @readUnPosted)
	RETURN
end
################################################################################
#END