################################################################################
CREATE PROCEDURE prcNSCheckCustBirthDayNotificationConditions(
	@notificationGuid UNIQUEIDENTIFIER,
	@objectGuid UNIQUEIDENTIFIER)
AS
BEGIN 

	DECLARE @accountCustomers UNIQUEIDENTIFIER
	DECLARE @CondGuid UNIQUEIDENTIFIER
	DECLARE @CustomerGroupGuid UNIQUEIDENTIFIER

	SELECT @CustomerGroupGuid = CG.[Guid], @accountCustomers = CG.AccountCustomers, @CondGuid = CG.ConditionsGuid 
	FROM NSCustomerGroup000 CG INNER JOIN NSCustBirthDayCondition000 BC ON CG.[Guid] = BC.[CustomerGroupGuid] AND BC.NotificationGuid = @notificationGuid

	DECLARE @customer TABLE([Guid] UNIQUEIDENTIFIER, Security INT)
	INSERT INTO @customer EXEC prcGetCustsList 0x0, @accountCustomers, @CondGuid

	DELETE @customer WHERE [GUID] IN (SELECT G.CustomerGuid FROM NSCustomerGroupCustomer000 G WHERE G.CustomerGroupGuid = @CustomerGroupGuid)

	IF NOT EXISTS ( 
			SELECT * FROM @customer cu 
			WHERE cu.[GUID] = @objectGuid 
		)
	BEGIN
		RETURN 0
	END
	RETURN 1 
END
################################################################################
CREATE FUNCTION fnNSCheckCustBirthDayEventCondtions(
	@eventConditonGuid UNIQUEIDENTIFIER,
	@fromDate DATE)
RETURNS @object TABLE 
(
	[GUID]	UNIQUEIDENTIFIER
)
BEGIN 
	INSERT INTO @object SELECT cu.[GUID] FROM cu000 cu 
	WHERE Month(cu.DateOfBirth) = Month(@fromDate)
	AND DAY(cu.DateOfBirth) = DAY(@fromDate)
	RETURN
END 
################################################################################
#END