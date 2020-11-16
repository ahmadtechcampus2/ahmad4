################################################################################
CREATE PROCEDURE prcNSCheckBillNotificationConditions(
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

	SELECT @StoreGuid = BC.storeGuid,@CostAll = BC.CostCenterGuid,@BranchAll = BC.BranchGuid  from NSBillCondition000 BC
                WHERE BC.NotificationGuid = @notificationGuid

	DECLARE @Cost_Tbl TABLE( [GUID] [UNIQUEIDENTIFIER]) 
	INSERT INTO @Cost_Tbl  SELECT [GUID] FROM [dbo].[fnGetCostsList]( @CostAll)  
	IF ISNULL( @CostAll, 0x0) = 0x0   
		INSERT INTO @Cost_Tbl VALUES(0x0)

	DECLARE @Store_Tbl TABLE( [GUID] [UNIQUEIDENTIFIER]) 
	INSERT INTO @Store_Tbl  SELECT [GUID] FROM [dbo].[fnGetStoresList]( @StoreGuid)  
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
	BEGIN
		INSERT INTO @Branch_Tbl VALUES((SELECT Branch FROM bu000 BU WHERE BU.[GUID] = @objectGuid))
	END

	SELECT @CustomerGroupGuid = CG.[Guid], @accountCustomers = CG.AccountCustomers, @CondGuid = CG.ConditionsGuid 
	FROM NSCustomerGroup000 CG INNER JOIN NSBillCondition000 BC ON CG.[Guid] = BC.[CustomerGroupGuid] AND BC.NotificationGuid = @notificationGuid

	DECLARE @customer TABLE([Guid] UNIQUEIDENTIFIER, Security INT)
	INSERT INTO @customer EXEC prcGetCustsList 0x0, @accountCustomers, @CondGuid

	DELETE @customer WHERE [GUID] IN (SELECT G.CustomerGuid FROM NSCustomerGroupCustomer000 G WHERE G.CustomerGroupGuid = @CustomerGroupGuid)

	IF NOT EXISTS ( 
			SELECT * FROM bu000 BU INNER JOIN NSBillSrcType000 SRC on BU.TypeGUID = SRC.TypeGuid AND BU.[GUID] = @objectGuid 
			INNER JOIN NSBillCondition000 BC ON BC.[GUID] = SRC.BillConditionGuid AND BC.NotificationGuid = @notificationGuid
			INNER JOIN @customer CU ON BU.CustGUID = CU.[Guid]
		    INNER JOIN @Cost_Tbl fn ON BU.CostGUID = fn.[GUID]
			INNER JOIN @Branch_Tbl fnBr ON BU.Branch = fnBr.[GUID]
			INNER JOIN @Store_Tbl fnSt ON BU.StoreGUID = fnSt.[GUID]
			INNER JOIN cu000 C on C.[GUID] = bu.CustGUID
		)
	BEGIN
		RETURN 0
	END
	RETURN 1 
END
################################################################################
CREATE FUNCTION fnNSCheckBillEventCondtions(
	@eventConditonGuid UNIQUEIDENTIFIER,
	@objectGuid UNIQUEIDENTIFIER)
RETURNS BIT AS
BEGIN 
	DECLARE @balanceType INT
	DECLARE @SpecificBalance FLOAT
	DECLARE @maxBalance FLOAT
	DECLARE @beforeBalance FLOAT
	DECLARE @maxBalanceType INT
	DECLARE @accountCurrValue INT 
	
	SELECT @balanceType = ec.BalanceType, @SpecificBalance = EC.SpecificBalance, @beforeBalance = ec.BeforeBalance from NSBillEventCondition000 EC where ec.EventConditionGuid = @eventConditonGuid
	IF @balanceType = 0 -- without balance conditions
	BEGIN
		RETURN 1
	END
	SELECT @accountCurrValue = ac.CurrencyVal,@maxBalance = MaxDebit / ac.CurrencyVal, @maxBalanceType = Warn FROM bu000 bu INNER JOIN ac000 ac ON bu.CustAccGUID = ac.[GUID] AND bu.[GUID] = @objectGuid
		-------------------------------------------------
	DECLARE @custGuid UNIQUEIDENTIFIER = (SELECT bu.CustGUID FROM bu000 bu WHERE bu.GUID = @objectGuid)
	DECLARE @costGuid UNIQUEIDENTIFIER 
	DECLARE @branchGuid UNIQUEIDENTIFIER
	SELECT @costGuid = bc.CostCenterGuid ,@branchGuid = bc.BranchGuid FROM NSBillCondition000 bc WHERE bc.NotificationGuid = (SELECT ec.NotificationGuid FROM NSEventCondition000 ec WHERE ec.Guid = @eventConditonGuid)
	
	DECLARE @billBalance FLOAT = (SELECT SUM((en.Debit - en.Credit)/@accountCurrValue) FROM en000 en INNER JOIN vwBuCe buce ON en.AccountGUID = buce.buCustAcc AND en.ParentGUID = buce.ceGUID AND buce.buGUID = @objectGuid)
	DECLARE @currentBalance FLOAT
	------------------------------------------------------	
	IF @balanceType = -1 -- Check specific balance debit
	BEGIN
		SET @currentBalance = (SELECT CustBalancesValue FROM dbo.fnNSGetCustBalWithCostAndBranch(@CustGuid,@costGuid,@branchGuid,DEFAULT))
		IF(@currentBalance >= @SpecificBalance AND (@currentBalance - @billBalance <  @SpecificBalance))
		BEGIN
			RETURN 1
		END
	END
	-------------------------------------------------
	IF @balanceType = -2 -- Check specific balance credit
	BEGIN
		SET @currentBalance = (SELECT CustBalancesValue FROM dbo.fnNSGetCustBalWithCostAndBranch(@CustGuid,@costGuid,@branchGuid,DEFAULT))
		SET @currentBalance = @currentBalance * -1
		SET @billBalance = @billBalance * -1
	
		IF( @currentBalance >= @SpecificBalance AND ( @currentBalance - @billBalance < @SpecificBalance ) )
		BEGIN
			RETURN 1
		END
	END
	-------------------------------------------------
	ELSE IF ISNULL(@maxBalanceType, 0) <> 0 -- Check before max balance not none
	BEGIN
		SET @currentBalance = (SELECT CustBalancesValue FROM dbo.fnNSGetCustBalWithCostAndBranch(@CustGuid,0x0,0x0,DEFAULT))	
		IF @balanceType = 5		-- ‰”»… „⁄Ì‰…
			SET @SpecificBalance = @maxBalance - (@beforeBalance * @maxBalance / 100 )
		ELSE					-- ﬁÌ„… „⁄Ì‰…	
			SET @SpecificBalance = @maxBalance - @beforeBalance
		IF @maxBalanceType <> 1 
		BEGIN
			SET @currentBalance = @currentBalance * -1 
			SET @billBalance = @billBalance * -1
		END   
		IF @currentBalance >= @SpecificBalance AND (@currentBalance - @billBalance < @SpecificBalance)
		BEGIN
			RETURN 1
		END
	END
	RETURN 0
END 
################################################################################
CREATE FUNCTION fnNSCheckBillWelcomeEventCondtions(
	@eventConditonGuid UNIQUEIDENTIFIER,
	@objectGuid UNIQUEIDENTIFIER)
RETURNS BIT AS
BEGIN 
DECLARE @byCostCenter	 BIT
DECLARE @byBranch		 BIT
DECLARE @COUNT			 INT
DECLARE @CustomerGUID	 UNIQUEIDENTIFIER
DECLARE @CostGUID		 UNIQUEIDENTIFIER
DECLARE @buCostGUID		 UNIQUEIDENTIFIER
DECLARE @BranchGUID		 UNIQUEIDENTIFIER
DECLARE @buBranchGUID	 UNIQUEIDENTIFIER
DECLARE @StoreGUID		 UNIQUEIDENTIFIER


SELECT @CostGUID = bc.CostCenterGuid, @BranchGUID = bc.BranchGuid, @byCostCenter = bw.ByCostCenter,
	   @byBranch = bw.ByBranch, @StoreGUID = bc.StoreGuid
FROM NSEventCondition000 ev 
INNER JOIN NSBillCondition000 bc ON ev.NotificationGuid = bc.NotificationGuid 
INNER JOIN NSBillWelcomeEventCondition000 bw ON ev.[Guid] = bw.EventConditionGuid
WHERE ev.[Guid] = @eventConditonGuid

DECLARE @billType UNIQUEIDENTIFIER
				 SELECT @billType = TypeGUID 
				 FROM bu000 
				 WHERE [GUID] = @objectGuid

DECLARE @Type INT
SET		@Type = (SELECT bt.[Type] 
				 FROM bu000 bu 
				 INNER JOIN bt000 bt ON bt.[GUID] = bu.TypeGUID
				 AND bu.[GUID] = @objectGuid )

SELECT @CustomerGUID = buCustPtr,  @buCostGUID = buCostPtr, @buBranchGUID = buBranch
FROM vwbu 
WHERE buGUID = @objectGuid
-----------------------------------------------------------------------------------------
IF(@CostGUID = 0x0 AND @BranchGUID = 0x0)
	BEGIN
		IF(@byCostCenter = 0 AND @byBranch = 0)
		BEGIN
			SET @COUNT = (SELECT COUNT(*) 
						  FROM vwbu bu INNER JOIN fnGetStoresList(@StoreGUID) sl
						  ON bu.buStorePtr = sl.[GUID]
						  WHERE bu.buCustPtr = @CustomerGUID
						  AND @Type NOT IN (5, 6)
						  and bu.buType = @billType)
		END
		IF(@byCostCenter = 1 AND @byBranch = 0)
		BEGIN
			SET @COUNT = (SELECT COUNT(*) 
						  FROM vwbu bu INNER JOIN fnGetStoresList(@StoreGUID) sl
						  ON bu.buStorePtr = sl.[GUID]
						  WHERE bu.buCustPtr = @CustomerGUID
						  AND bu.buCostPtr   = @buCostGUID
						  AND @Type NOT IN (5, 6)
						  and bu.buType = @billType)
		END
		IF(@byCostCenter = 0 AND @byBranch = 1)
		BEGIN
			SET @COUNT = (SELECT COUNT(*) 
						  FROM vwbu bu INNER JOIN fnGetStoresList(@StoreGUID) sl
						  ON bu.buStorePtr = sl.[GUID]
						  WHERE bu.buCustPtr = @CustomerGUID
						  AND bu.buBranch	 = @buBranchGUID
						  AND @Type NOT IN (5, 6)
						  and bu.buType = @billType)
		END
		IF(@byCostCenter = 1 AND @byBranch = 1)
		BEGIN
			SET @COUNT = (SELECT COUNT(*) 
						  FROM vwbu bu INNER JOIN fnGetStoresList(@StoreGUID) sl
						  ON bu.buStorePtr = sl.[GUID]
						  WHERE bu.buCustPtr = @CustomerGUID
						  AND bu.buCostPtr   = @buCostGUID
						  AND bu.buBranch	 = @buBranchGUID
						  AND @Type NOT IN (5, 6)
						  and bu.buType = @billType)
		END
	END
-----------------------------------------------------------------------------------------
IF(@CostGUID != 0x0 AND @BranchGUID = 0x0)
	BEGIN
		IF(@byCostCenter = 0)
		BEGIN
			SET @COUNT = (SELECT COUNT(*) 
						  FROM vwbu bu INNER JOIN fnGetCostsList(@CostGUID) cl
						  ON bu.buCostPtr = cl.[GUID] INNER JOIN fnGetStoresList(@StoreGUID) sl
						  ON bu.buStorePtr = sl.[GUID]
						  WHERE bu.buCustPtr = @CustomerGUID
						  AND @Type NOT IN (5, 6)
						  and bu.buType = @billType)
		END
		IF(@byCostCenter = 1)
		BEGIN
			SET @COUNT = (SELECT COUNT(*) 
						  FROM vwbu bu INNER JOIN fnGetCostsList(@CostGUID) cl
						  ON bu.buCostPtr = cl.[GUID] INNER JOIN fnGetStoresList(@StoreGUID) sl
						  ON bu.buStorePtr = sl.[GUID]
						  WHERE bu.buCustPtr = @CustomerGUID
						  AND bu.buCostPtr = @buCostGUID
						  AND @Type NOT IN (5, 6)
						  and bu.buType = @billType)
		END
	END
-----------------------------------------------------------------------------------------
IF(@CostGUID = 0x0 AND @BranchGUID != 0x0)
	BEGIN
		IF(@byBranch = 0)
		BEGIN
			SET @COUNT = (SELECT COUNT(*) 
						  FROM vwbu bu INNER JOIN fnGetBranchesList(@BranchGUID) Bl
						  ON bu.buBranch = Bl.[GUID] INNER JOIN fnGetStoresList(@StoreGUID) sl
						  ON bu.buStorePtr = sl.[GUID]
						  WHERE bu.buCustPtr = @CustomerGUID
						  AND @Type NOT IN (5, 6)
						  and bu.buType = @billType)
		END
		IF(@byBranch = 1)
		BEGIN
			SET @COUNT = (SELECT COUNT(*) 
						  FROM vwbu bu INNER JOIN fnGetBranchesList(@BranchGUID) Bl
						  ON bu.buBranch = Bl.[GUID] INNER JOIN fnGetStoresList(@StoreGUID) sl
						  ON bu.buStorePtr = sl.[GUID]
						  WHERE bu.buCustPtr = @CustomerGUID
						  AND bu.buBranch	 = @buBranchGUID
						  AND @Type NOT IN (5, 6)
						  and bu.buType = @billType)
		END
	END
-----------------------------------------------------------------------------------------
IF(@CostGUID != 0x0 AND @BranchGUID != 0x0)
	BEGIN
		IF(@byCostCenter = 0 AND @byBranch = 0)
		BEGIN
			SET @COUNT = (SELECT COUNT(*) 
						  FROM vwbu bu INNER JOIN fnGetCostsList(@CostGUID) cl
						  ON bu.buCostPtr = cl.[GUID] INNER JOIN fnGetBranchesList(@BranchGUID) Bl
						  ON bu.buBranch = Bl.[GUID] INNER JOIN fnGetStoresList(@StoreGUID) sl
						  ON bu.buStorePtr = sl.[GUID]
						  WHERE bu.buCustPtr = @CustomerGUID
						  AND @Type NOT IN (5, 6)
						  and bu.buType = @billType)
		END
		IF(@byCostCenter = 1 AND @byBranch = 0)
		BEGIN
			SET @COUNT = (SELECT COUNT(*) 
						  FROM vwbu bu INNER JOIN fnGetCostsList(@CostGUID) cl
						  ON bu.buCostPtr = cl.[GUID] INNER JOIN fnGetBranchesList(@BranchGUID) Bl
						  ON bu.buBranch = Bl.[GUID] INNER JOIN fnGetStoresList(@StoreGUID) sl
						  ON bu.buStorePtr = sl.[GUID]
						  WHERE bu.buCustPtr = @CustomerGUID
						  AND bu.buCostPtr = @buCostGUID
						  AND @Type NOT IN (5, 6)
						  and bu.buType = @billType)
		END
		IF(@byCostCenter = 0 AND @byBranch = 1)
		BEGIN
			SET @COUNT = (SELECT COUNT(*) 
						  FROM vwbu bu INNER JOIN fnGetBranchesList(@BranchGUID) Bl
						  ON bu.buBranch = Bl.[GUID] INNER JOIN fnGetCostsList(@CostGUID) cl
						  ON bu.buCostPtr = cl.[GUID] INNER JOIN fnGetStoresList(@StoreGUID) sl
						  ON bu.buStorePtr = sl.[GUID]
						  WHERE bu.buCustPtr = @CustomerGUID
						  AND bu.buBranch	 = @buBranchGUID
						  AND @Type NOT IN (5, 6)
						  and bu.buType = @billType)
		END
		IF(@byCostCenter = 1 AND @byBranch = 1)
		BEGIN
			SET @COUNT = (SELECT COUNT(*) 
						  FROM vwbu bu INNER JOIN fnGetCostsList(@CostGUID) cl
						  ON bu.buCostPtr = cl.[GUID] INNER JOIN fnGetBranchesList(@BranchGUID) Bl
						  ON bu.buBranch = Bl.[GUID] INNER JOIN fnGetStoresList(@StoreGUID) sl
						  ON bu.buStorePtr = sl.[GUID]
						  WHERE bu.buCustPtr = @CustomerGUID
						  AND bu.buCostPtr = @buCostGUID
						  AND bu.buBranch	 = @buBranchGUID
						  AND @Type NOT IN (5, 6)
						  and bu.buType = @billType)
		END
	END
-----------------------------------------------------------------------------------------
		IF(@COUNT = 1)
		  BEGIN
		   RETURN 1
		  END
	RETURN 0
END

################################################################################
CREATE FUNCTION fnNSCheckBillScheduleEventCondtions(
	@eventConditonGuid UNIQUEIDENTIFIER,
	@fromDate DATETIME)
RETURNS @object TABLE 
(
	[GUID]	UNIQUEIDENTIFIER
)
BEGIN 
	DECLARE @beforeDays INT
	SELECT @beforeDays =  DC.BeforeDays from NSScheduleEventCondition000 DC where DC.EventConditionGuid = @eventConditonGuid

	insert into @object select BU.GUID from bu000 BU INNER JOIN pt000 PT ON BU.GUID = PT.RefGUID
	WHERE PT.Type = 3 AND DATEDIFF(day, PT.DueDate, @fromDate) = -1 * @beforeDays
	return
END 
################################################################################
#END

		