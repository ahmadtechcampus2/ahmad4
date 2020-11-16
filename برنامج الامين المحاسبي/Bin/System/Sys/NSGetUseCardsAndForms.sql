################################################################################
CREATE FUNCTION NSGetStoreUse()
RETURNS @Store TABLE 
(
		[GUID]	UNIQUEIDENTIFIER
)
AS 
BEGIN
	INSERT INTO @Store SELECT DISTINCT StoreGuid FROM NSBillCondition000 
	INSERT INTO @Store SELECT DISTINCT StoreGuid FROM NSOrderCondition000 EXCEPT SELECT GUID FROM @Store
	
	RETURN
END 
################################################################################
CREATE FUNCTION NSGetCostCenterUse()
RETURNS @Cost TABLE 
(
		[GUID]	UNIQUEIDENTIFIER
)
AS 
BEGIN
	INSERT INTO @Cost SELECT DISTINCT CostCenterGuid FROM NSBillCondition000 
	INSERT INTO @Cost SELECT DISTINCT CostCenterGuid FROM NSOrderCondition000 EXCEPT SELECT GUID FROM @Cost
	INSERT INTO @Cost SELECT DISTINCT CostCenterGuid FROM NSChecksCondition000 EXCEPT SELECT GUID FROM @Cost
	INSERT INTO @Cost SELECT DISTINCT CostCenterGuid FROM NSEntryCondition000 EXCEPT SELECT GUID FROM @Cost
	INSERT INTO @Cost SELECT DISTINCT CostGuid FROM NSAccountBalancesSchedulingGrid000 EXCEPT SELECT GUID FROM @Cost
	RETURN
END
################################################################################
CREATE FUNCTION NSGetBranchUse()
RETURNS @Branch TABLE 
(
		[GUID]	UNIQUEIDENTIFIER
)
AS 
BEGIN
	INSERT INTO @Branch SELECT DISTINCT BranchGuid FROM NSBillCondition000 
	INSERT INTO @Branch SELECT DISTINCT BranchGuid FROM NSOrderCondition000 EXCEPT SELECT GUID FROM @Branch
	INSERT INTO @Branch SELECT DISTINCT BranchGuid FROM NSChecksCondition000 EXCEPT SELECT GUID FROM @Branch
	INSERT INTO @Branch SELECT DISTINCT BranchGuid FROM NSEntryCondition000 EXCEPT SELECT GUID FROM @Branch
	INSERT INTO @Branch SELECT DISTINCT BranchGuid FROM NSAccountBalancesSchedulingGrid000 EXCEPT SELECT GUID FROM @Branch
	RETURN
END
################################################################################
CREATE FUNCTION NSGetAccountUse()
RETURNS @Account TABLE 
(
		[GUID]	UNIQUEIDENTIFIER
)
AS 
BEGIN
	INSERT INTO @Account SELECT DISTINCT AccountGuid FROM NSAccountBalancesSchedulingGrid000 
	INSERT INTO @Account SELECT DISTINCT CashAccount FROM NSEntryCondition000 EXCEPT SELECT GUID FROM @Account
	INSERT INTO @Account SELECT DISTINCT AccountCustomers FROM NSCustomerGroup000 EXCEPT SELECT GUID FROM @Account
	RETURN
END
################################################################################
#END
