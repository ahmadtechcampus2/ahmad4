################################################################################
CREATE FUNCTION fnEmptyNotificationConditions(
	@notificationGuid UNIQUEIDENTIFIER,
	@objectGuid UNIQUEIDENTIFIER)
RETURNS BIT AS
BEGIN 
	RETURN 1
END
################################################################################
CREATE PROCEDURE prcNSManualEventCondtions
(@eventConditonGuid UNIQUEIDENTIFIER)
AS 
BEGIN
	DECLARE @accountCustomers UNIQUEIDENTIFIER
	DECLARE @CondGuid UNIQUEIDENTIFIER
	DECLARE @CustomerGroupGuid UNIQUEIDENTIFIER

	SELECT @CustomerGroupGuid = CG.[Guid], @accountCustomers = CG.AccountCustomers, @CondGuid = CG.ConditionsGuid 
	FROM NSCustomerGroup000 CG INNER JOIN NSSpecialOfferEventCondition000 EC ON CG.[Guid] = EC.CustomersGroupGuid AND EC.EventConditionGuid = @eventConditonGuid

	DECLARE @customer TABLE([Guid] UNIQUEIDENTIFIER, Security INT)
	INSERT INTO @customer EXEC prcGetCustsList 0x0, @accountCustomers, @CondGuid

	DELETE @customer WHERE [GUID] IN (SELECT G.CustomerGuid FROM NSCustomerGroupCustomer000 G WHERE G.CustomerGroupGuid = @CustomerGroupGuid)

	INSERT INTO #object SELECT [Guid] FROM @customer
END
################################################################################
CREATE PROCEDURE prcNSManualGetIncludedCustomers
( 
	@accountCustomers UNIQUEIDENTIFIER,
	@CondGuid UNIQUEIDENTIFIER,
	@BranchGuid UNIQUEIDENTIFIER,
	@checkBalance INT,
	@balance FLOAT)
AS 
BEGIN
	SET NOCOUNT ON

	DECLARE @BranchSysEnable INT = (SELECT value from op000 where name  = 'EnableBranches')
	DECLARE @branchNumber INT = ISNULL((SELECT Number from br000 where [Guid] = @BranchGuid), 0)

	DECLARE @customer TABLE([Guid] UNIQUEIDENTIFIER, Security INT)
	INSERT INTO @customer EXEC prcGetCustsList 0x0, @accountCustomers, @CondGuid

	SELECT CU.CUGUID, CU.cuCustomerName, CU.cuLatinName, CU.NSEmail1, CU.NSEmail2, CU.NSMobile1, NSMobile2,CU.NSNotSendSMS ,CU.NSNotSendEMAIL , CU.cuAccount As acGuid 
	from vwCu CU 
	INNER JOIN @customer FCU on FCU.GUID = CU.cuGUID
	INNER JOIN ac000 AC on ac.GUID = cu.cuAccount
	CROSS APPLY dbo.fnNSGetCustBalWithCostAndBranch(CU.cuGUID, 0x0, @BranchGuid, 0) branchbal
	CROSS APPLY dbo.fnNSGetCustBalWithCostAndBranch(CU.cuGUID, 0x0, 0x0, 0) bal
	WHERE  (ISNull(@BranchGuid, 0x0) = 0x0 OR @BranchSysEnable = 0 OR ([dbo].[fnGetBranchMask](@branchNumber) & [AC].[BranchMask]) > 0) 
			AND 
			(@checkBalance = 0
			OR (@checkBalance = 1 AND ABS(ISNULL(branchbal.CustBalancesValue, 0)) > ABS(@balance))
			OR (@checkBalance = 2 AND AC.Warn = 1 AND (ISNULL(bal.CustBalancesValue, 0)) >= (ac.MaxDebit / (Case WHEN ac.CurrencyVal = 0 THEN 1 ELSE ac.CurrencyVal END )))
			OR (@checkBalance = 2 AND AC.Warn = 2 AND (-1 * ISNULL(bal.CustBalancesValue, 0)) >= ac.MaxDebit /(Case WHEN ac.CurrencyVal = 0 THEN 1 ELSE ac.CurrencyVal END )))
END
################################################################################
#END