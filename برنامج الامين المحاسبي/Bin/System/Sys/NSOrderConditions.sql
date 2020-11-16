################################################################################
CREATE PROCEDURE prcNSCheckOrderNotificationConditions(
	@notificationGuid UNIQUEIDENTIFIER,
	@objectGuid UNIQUEIDENTIFIER)
AS
BEGIN 

	DECLARE @CostAll UNIQUEIDENTIFIER
	DECLARE @BranchAll UNIQUEIDENTIFIER
	DECLARE @StoreGuid UNIQUEIDENTIFIER  
	DECLARE @accountCustomers UNIQUEIDENTIFIER
	DECLARE @CondGuid UNIQUEIDENTIFIER
	DECLARE @CustomerGroupGuid UNIQUEIDENTIFIER

	SELECT @StoreGuid = BC.storeGuid,@BranchAll = BC.BranchGuid ,@CostAll = BC.CostCenterGuid from NSOrderCondition000 BC
                WHERE BC.NotificationGuid = @notificationGuid

	DECLARE @Cost_Tbl TABLE( [GUID] [UNIQUEIDENTIFIER]) 
	INSERT INTO @Cost_Tbl  SELECT [GUID] FROM [dbo].[fnGetCostsList](@CostAll)  
	IF ISNULL( @CostAll, 0x0) = 0x0   
		INSERT INTO @Cost_Tbl VALUES(0x0)

	DECLARE @Store_Tbl TABLE( [GUID] [UNIQUEIDENTIFIER]) 
	INSERT INTO @Store_Tbl  SELECT [GUID] FROM [dbo].[fnGetStoresList](@StoreGuid)  
	IF ISNULL( @StoreGuid, 0x0) = 0x0   
		INSERT INTO @Store_Tbl VALUES(0x0)
	
	DECLARE @BranchSysEnable int = (SELECT value from op000 where name  = 'EnableBranches')
	DECLARE @Branch_Tbl TABLE( [GUID] [UNIQUEIDENTIFIER]) 
	IF @BranchSysEnable = 1
	Begin
		INSERT INTO @Branch_Tbl  SELECT [GUID] FROM [dbo].[fnGetBranchesList]( @BranchAll)  
		IF ISNULL( @BranchAll, 0x0) = 0x0   
			INSERT INTO @Branch_Tbl VALUES(0x0)
	END
	ELSE
	Begin
		INSERT INTO @Branch_Tbl VALUES((SELECT Branch FROM bu000 BU WHERE BU.[GUID] = @objectGuid))
	END

	SELECT @CustomerGroupGuid = CG.[Guid], @accountCustomers = CG.AccountCustomers, @CondGuid = CG.ConditionsGuid 
	FROM NSCustomerGroup000 CG INNER JOIN NSOrderCondition000 OC ON CG.[Guid] = OC.[CustomerGroupGuid] AND OC.NotificationGuid = @notificationGuid

	DECLARE @customer TABLE([Guid] UNIQUEIDENTIFIER, Security INT)
	INSERT INTO @customer EXEC prcGetCustsList 0x0, @accountCustomers, @CondGuid

	DELETE @customer WHERE [GUID] IN (SELECT G.CustomerGuid FROM NSCustomerGroupCustomer000 G WHERE G.CustomerGroupGuid = @CustomerGroupGuid)

	IF NOT EXISTS ( 
	SELECT * FROM bu000 BU INNER JOIN NSOrderSrcType000 SRC on BU.TypeGUID = SRC.TypeGuid AND BU.[GUID] = @objectGuid 
			INNER JOIN NSOrderCondition000 BC ON BC.[GUID] = SRC.OrderConditionGuid AND BC.NotificationGuid = @notificationGuid
			INNER JOIN @customer CU ON BU.CustGUID = CU.[Guid]
			INNER JOIN @Cost_Tbl fn ON BU.CostGUID = fn.[GUID]
			INNER JOIN @Store_Tbl fnSt ON BU.StoreGUID = fnSt.[GUID]
			INNER JOIN @Branch_Tbl fnBr ON BU.Branch = fnBr.[GUID]
			)
	BEGIN
		RETURN 0
	END
	RETURN 1 
END
################################################################################
CREATE FUNCTION fnNSCheckOrderScheduleEventCondtions(
	@eventConditonGuid UNIQUEIDENTIFIER,
	@fromDate DATETIME)
RETURNS @object TABLE 
(
	[GUID]	UNIQUEIDENTIFIER
)
BEGIN 
	DECLARE @beforeDays INT
	SELECT @beforeDays =  DC.BeforeDays from NSScheduleEventCondition000 DC where DC.EventConditionGuid = @eventConditonGuid
	
	insert into @object select BU.GUID from bu000 BU 
	INNER JOIN fnGetOrdersDueDates() fn ON BU.GUID = fn.ParentGuid
	AND DATEDIFF(day, fn.DueDate, @fromDate) = -1 * @beforeDays
	return
END 
################################################################################
#END