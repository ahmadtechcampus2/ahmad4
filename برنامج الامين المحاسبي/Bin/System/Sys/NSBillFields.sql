################################################################################
CREATE FUNCTION NSGetCustomerInfo(@ObjectGuid UNIQUEIDENTIFIER)
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
	INSERT INTO @receiver select 0x0, 'bill customer', cu.nsemail1, cu.nsmobile1, cu.nsemail2, cu.nsmobile2, cu.NSNotSendSMS, cu.NSNotSendEmail FROM vwCu CU inner join vwBu bu ON bu.buGUID = @objectGuid and cu.cuGUID = bu.buCustPtr
	RETURN
END
################################################################################
CREATE FUNCTION NSFnBillInfo(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @billInfo TABLE 
(
		CustName			NVARCHAR(255),
		CustLName           NVARCHAR(255),
		BillNumber			NVARCHAR(50),
		total				NVARCHAR(50),
		BuDate				DATE,
		BuType				NVARCHAR(250),
		CuSuffix			NVARCHAR(25),
		CuPrefix			NVARCHAR(25),
		Currency			NVARCHAR(50),
		Branch				NVARCHAR(50),
		CostCenter			NVARCHAR(50),
		DueDate             DATE
)
AS 
BEGIN

 DECLARE @CustomerGuid  UNIQUEIDENTIFIER
 Set @CustomerGuid = (SELECT cu.[GUID] from cu000 cu
                      INNER JOIN bu000 bu on bu.CustGUID = cu.GUID
					  where  bu.[GUID]=  @ObjectGuid )
   DECLARE @CurrName VARCHAR(20)
   set @CurrName = (select my.Code from bu000 bu
                     INNER JOIN my000 my on my.[GUID] = bu.CurrencyGUID    
					 where bu.[GUID] = @ObjectGuid)

	INSERT INTO @billInfo
	SELECT cu.cuCustomerName,cu.cuLatinName, '(' + CAST(bu.buNumber AS NVARCHAR(50)) + ')', [dbo].fnNSFormatMoneyAsNVARCHAR  ( Round(((bu.buTotal-bu.buTotalDisc+bu.buTotalExtra+bu.buVAT)  / bu.buCurrencyVal),2) , @CurrName ) AS TotalBal ,bu.BuDate,bu.btName,cu.cuSuffix,cu.cuPrefix,my.myName ,br.brName,co.coName,
	pt.ptDueDate
 
	FROM vwBu bu
	left JOIN vwbr br ON br.brGUID = bu.buBranch
	left JOIN vwco co ON co.coGUID = bu.buCostPtr
	left JOIN vwcu cu ON cu.cuGUID = bu.buCustPtr
	left JOIN vwExtended_AC ac ON ac.[GUID] = cu.cuAccount
	left JOIN vwmy my ON my.myGUID = ac.CurrencyGUID
	left JOIN vwPt pt ON pt.ptCustAcc = ac.[GUID]  
	WHERE buGUID = @ObjectGuid
	RETURN
end
####################################################################################
CREATE FUNCTION NSFnCustInfoBalance(@CustGuid UNIQUEIDENTIFIER)
RETURNS @billInfoBalance TABLE 
(
		CuBalance			NVARCHAR(50),
		MaxDebit            FLOAT
)
AS 
BEGIN
	DECLARE @BalancesValue float
	DECLARE @BalancesWithCode VARCHAR(255)
	SELECT @BalancesValue = CustBalancesValue,@BalancesWithCode = CustBalancesWithCurrCode  FROM fnNSGetCustBalWithCostAndBranch(@CustGuid,0x0,0x0,DEFAULT)
	INSERT INTO @billInfoBalance
	
	SELECT @BalancesWithCode ,
	(case ac.Warn 
	when 1 then  (ac.MaxDebit - (@BalancesValue))
	when 2 then  (-ac.MaxDebit - (@BalancesValue))
	else 0 END)
	FROM vwcu cu
	INNER JOIN vwExtended_AC ac ON ac.[GUID] = cu.cuAccount 
	LEFT JOIN my000 my ON my.[GUID] =  ac.CurrencyGUID
	WHERE cu.cuGUID = @custguid
	RETURN
end
################################################################################
CREATE FUNCTION NSFnBillCustInfoBalance(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @billInfoBalance TABLE 
(
		CuBalance			NVARCHAR(50),
		MaxDebit            NVARCHAR(100)
)
AS 
BEGIN
	DECLARE @CustMaxDebit float
	DECLARE @BalancesWithCode VARCHAR(255)
	DECLARE @CustomerGuid UNIQUEIDENTIFIER= (SELECT cu.[GUID] from cu000 cu
                      INNER JOIN bu000 bu on bu.CustGUID = cu.GUID
					  where  bu.[GUID]=  @ObjectGuid )
	SELECT @CustMaxDebit = MaxDebit,@BalancesWithCode = CuBalance  FROM  [dbo].NSFnCustInfoBalance( @CustomerGuid)  
	
	DECLARE @accGuid UNIQUEIDENTIFIER = (SELECT CuAc.acGUID From vwCuAc CuAc WHERE CuAc.[cuGUID] = @CustomerGuid)
	
	
	INSERT INTO @billInfoBalance
	SELECT 
	@BalancesWithCode,
	
	DiffFromMaxDebitWithCurrCode FROM [dbo].fnNSGetAccDiffFromMaxBalanceInfo(@accGuid, DEFAULT)

	RETURN
end
################################################################################
CREATE FUNCTION NSBillBalWithCostCenter(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @BillCostInfo TABLE 
(
		BillCustBalWithCost NVARCHAR(255)
)
AS 
BEGIN
	DECLARE @COSTGUID  UNIQUEIDENTIFIER 
	DECLARE @CustGUID UNIQUEIDENTIFIER

	SELECT @COSTGUID = bu.CostGUID, @CustGUID = bu.[CustGUID]  FROM bu000 bu 
                WHERE bu.[GUID] = @objectGuid

	INSERT INTO @BillCostInfo
    SELECT  CustBalancesWithCurrCode FROM fnNSGetCustBalWithCostAndBranch(@CustGUID,@COSTGUID,0x0,DEFAULT)

	RETURN
end
################################################################################
CREATE FUNCTION NSBillBalWithCostAndBranch(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @BillCustBalances TABLE 
(
		BillCustBalWithCostAndBr NVARCHAR(255)
)
AS 
BEGIN

	DECLARE @COSTGUID  UNIQUEIDENTIFIER 
	DECLARE @CustGUID UNIQUEIDENTIFIER
	DECLARE @BranchGUID  UNIQUEIDENTIFIER

	SELECT @COSTGUID = bu.CostGUID, @CustGUID = bu.[CustGUID] ,@BranchGUID = bu.[Branch] FROM bu000 bu 
                WHERE bu.[GUID] = @objectGuid

	INSERT INTO @BillCustBalances
    SELECT  CustBalancesWithCurrCode FROM fnNSGetCustBalWithCostAndBranch(@CustGUID,@COSTGUID,@BranchGUID,DEFAULT)

	RETURN
end
################################################################################
CREATE FUNCTION NSBillBalWithBranch(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @BillCustBalances TABLE 
(
		BillCustBalBranch NVARCHAR(255)
)
AS 
BEGIN
	DECLARE @CustGUID  UNIQUEIDENTIFIER 
	DECLARE @BranchGUID  UNIQUEIDENTIFIER

	SELECT  @CustGUID = bu.[CustGUID] ,@BranchGUID = bu.[Branch] FROM bu000 bu 
                WHERE bu.[GUID] = @objectGuid

	INSERT INTO @BillCustBalances
    SELECT  CustBalancesWithCurrCode FROM fnNSGetCustBalWithCostAndBranch(@CustGUID,0x0,@BranchGUID,DEFAULT)

	RETURN
end
################################################################################
CREATE FUNCTION fnNSAccountBalance
(
	@accountGuid UNIQUEIDENTIFIER
)
RETURNS FLOAT
AS
BEGIN
	DECLARE @balance FLOAT

	SELECT @balance = SUM(en.Debit - en.Credit)
	FROM en000 EN 
	INNER JOIN ce000 CE on en.ParentGUID = ce.[GUID]
	WHERE ce.IsPosted <> 0 and en.AccountGUID =  @accountGuid
	GROUP BY en.AccountGUID

	RETURN ISNULL(@balance, 0)
END
################################################################################
#END