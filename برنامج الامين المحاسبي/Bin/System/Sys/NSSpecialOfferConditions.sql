################################################################################
CREATE FUNCTION fnNSSpecialOfferNotificationConditions(
	@notificationGuid UNIQUEIDENTIFIER,
	@objectGuid UNIQUEIDENTIFIER)
RETURNS BIT AS
BEGIN 
	RETURN 1
END
################################################################################
CREATE FUNCTION fnNSSpecialOfferEventCondtions
(@eventConditonGuid UNIQUEIDENTIFIER)
RETURNS @object TABLE 
(
	[GUID]	UNIQUEIDENTIFIER
)
AS 
BEGIN

	INSERT INTO @object SELECT CG.CustomerGuid FROM NSCustomerGroupCustomer000 CG
	INNER JOIN NSSpecialOfferEventCondition000 EC ON EC.CustomersGroupGuid = CG.CustomerGroupGuid
	AND EC.EventConditionGuid = @eventConditonGuid
	RETURN
END
################################################################################
CREATE PROCEDURE prcNSSpecialOfferEventCondtions
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
#END