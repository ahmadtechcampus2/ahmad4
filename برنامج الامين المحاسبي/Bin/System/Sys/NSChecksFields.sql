################################################################################
CREATE FUNCTION NSChecksGetCustomerInfo(@ObjectGuid UNIQUEIDENTIFIER)
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
	INSERT INTO @receiver select 0x0, 'Checks customer', cu.nsemail1, cu.nsmobile1, cu.nsemail2, cu.nsmobile2 , cu.NSNotSendSMS, cu.NSNotSendEmail FROM vwCu CU 
	INNER JOIN ac000 AC ON AC.[GUID] = CU.cuAccount
	INNER JOIN vwCh CH ON CH.CHGUID = @objectGuid and  CH.chAccount = AC.[GUID]
	RETURN
END
####################################################################################
CREATE FUNCTION NSFnChecksInfo(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @ChecksInfo TABLE 
(
		CustName			NVARCHAR(255),
		CustSuffix			NVARCHAR(255),
		CustPrefix			NVARCHAR(255),
		CustLName           NVARCHAR(255),
		ChecksNum			NVARCHAR(255),
		ChecksDate			DATE,
		ChecksDueDate		DATE,
		ChecksVal			NVARCHAR(50),
		CostName			NVARCHAR(255),
		BranchName			NVARCHAR(50),
		CheckTypeName		NVARCHAR(50)
)
AS 
	BEGIN
		DECLARE @CustomerGuid  UNIQUEIDENTIFIER
		SET     @CustomerGuid = (SELECT CU.[GUID]
								 FROM cu000 CU  
								 INNER JOIN ch000 CH ON CU.AccountGUID = CH.AccountGUID 
								 INNER JOIN ac000 AC ON CU.AccountGUID = AC.[GUID]
								 AND CH.[GUID] = @ObjectGuid )

		DECLARE @CurrCodeCh  AS NVARCHAR(50)
		SET		@CurrCodeCh = (SELECT MY.Code
							   FROM ch000 CH INNER JOIN my000 MY
							   ON CH.CurrencyGUID = MY.[GUID]
							   AND CH.[GUID] = @ObjectGuid) 

		DECLARE @CurrCodeAc  AS NVARCHAR(50)
		SET		@CurrCodeAc = (SELECT MY.Code
						       FROM cu000 CU  
						       INNER JOIN ch000 CH ON CU.AccountGUID = CH.AccountGUID 
						       INNER JOIN ac000 AC ON CU.AccountGUID = AC.[GUID] AND CH.[GUID] = @ObjectGuid
						       INNER JOIN my000 MY ON AC.CurrencyGUID = MY.[GUID])

		-------------------------------------------------------------------------------------------------------
		INSERT INTO @ChecksInfo
		SELECT CU.CustomerName, CU.Suffix, CU.Prefix, CU.LatinName,
			   CH.Num, CH.[Date], CH.DueDate,  [dbo].fnNSFormatMoneyAsNVARCHAR((ROUND(CH.Val / CH.CurrencyVal, 2)),@CurrCodeCh),
			   CO.Name,
				br.brName, nt.Name
		FROM cu000 CU  
		INNER JOIN ch000 CH ON CU.AccountGUID = CH.AccountGUID 
		INNER JOIN ac000 AC ON CU.AccountGUID = AC.[GUID] AND CH.[GUID] = @ObjectGuid
		LEFT JOIN  co000 CO ON CO.[GUID] = CH.Cost1GUID
		LEFT JOIN  vwbr br	ON br.brGUID = CH.BranchGUID
		LEFT JOIN  nt000 nt	ON nt.[GUID] = CH.TypeGUID
	RETURN
END
################################################################################
CREATE FUNCTION NSCheckCustBal(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @CheckAccBal TABLE 
(
		CheckCustBal NVARCHAR(255)
)
AS 
BEGIN
	DECLARE @ACCGUID   UNIQUEIDENTIFIER = (SELECT ch.chAccount  FROM vwch ch 
                WHERE ch.[chGUID] = @objectGuid)

	INSERT INTO @CheckAccBal
    SELECT  AccBalancesWithCurrCode FROM fnNSGetAccBalWithCostAndBranch(@ACCGUID,0x0,0x0,DEFAULT)

	RETURN
END
####################################################################################
CREATE FUNCTION NSCheckBalWithCostCenter(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @CheckAccBal TABLE 
(
		CheckCustBalCost NVARCHAR(255)
)
AS 
BEGIN
	DECLARE @COSTGUID  UNIQUEIDENTIFIER 
	DECLARE @ACCGUID   UNIQUEIDENTIFIER

	SELECT @COSTGUID = ch.chCost1GUID, @ACCGUID = ch.chAccount  FROM vwch ch 
                WHERE ch.[chGUID] = @objectGuid

	INSERT INTO @CheckAccBal
    SELECT  AccBalancesWithCurrCode FROM fnNSGetAccBalWithCostAndBranch(@ACCGUID,@COSTGUID,0x0,DEFAULT)

	RETURN
END
####################################################################################
CREATE FUNCTION NSCheckBalWithBranch(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @CheckAccBal TABLE 
(
		CheckCustBalBranch NVARCHAR(255)
)
AS 
BEGIN
	DECLARE @BranchGUID  UNIQUEIDENTIFIER 
	DECLARE @ACCGUID   UNIQUEIDENTIFIER

	SELECT @BranchGUID = ch.chBranchGUID, @ACCGUID = ch.chAccount  FROM vwch ch 
                WHERE ch.[chGUID] = @objectGuid

	INSERT INTO @CheckAccBal
    SELECT  AccBalancesWithCurrCode FROM fnNSGetAccBalWithCostAndBranch(@ACCGUID,0x0,@BranchGUID,DEFAULT)

	RETURN
END
####################################################################################
CREATE FUNCTION NSCheckBalWithCostAndBr(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @CheckAccBal TABLE 
(
		CheckCustBalCostBranch NVARCHAR(255)
)
AS 
BEGIN
	DECLARE @BranchGUID  UNIQUEIDENTIFIER 
	DECLARE @COSTGUID   UNIQUEIDENTIFIER
	DECLARE @ACCGUID   UNIQUEIDENTIFIER

	SELECT @COSTGUID = ch.chCost1GUID, @BranchGUID = ch.chBranchGUID, @ACCGUID = ch.chAccount  FROM vwch ch 
                WHERE ch.[chGUID] = @objectGuid

	INSERT INTO @CheckAccBal
    SELECT  AccBalancesWithCurrCode FROM fnNSGetAccBalWithCostAndBranch(@ACCGUID,@COSTGUID,@BranchGUID,DEFAULT)

	RETURN
END
####################################################################################
#END