################################################################################
CREATE PROCEDURE prcNSCheckEntryNotificationConditions(
	@notificationGuid UNIQUEIDENTIFIER,
	@objectGuid UNIQUEIDENTIFIER)
AS
BEGIN

	DECLARE @CostAll UNIQUEIDENTIFIER 
	DECLARE @CashAccount UNIQUEIDENTIFIER
	DECLARE @BranchGuid UNIQUEIDENTIFIER
	DECLARE @accountCustomers UNIQUEIDENTIFIER
	DECLARE @CondGuid UNIQUEIDENTIFIER
	DECLARE @CustomerGroupGuid UNIQUEIDENTIFIER
	
	SELECT @BranchGuid = BC.BranchGuid ,@CostAll = BC.CostCenterGuid, @CashAccount = BC.CashAccount from NSEntryCondition000 BC WHERE BC.NotificationGuid = @notificationGuid
	
	DECLARE @Cost_Tbl TABLE( [GUID] [UNIQUEIDENTIFIER]) 
	INSERT INTO @Cost_Tbl  SELECT [GUID] FROM [dbo].[fnGetCostsList]( @CostAll)  
	IF ISNULL( @CostAll, 0x0) = 0x0   
		INSERT INTO @Cost_Tbl VALUES(0x0)

	DECLARE @BranchSysEnable int = (SELECT value from op000 where name  = 'EnableBranches')
	DECLARE @Branch_Tbl TABLE( [GUID] [UNIQUEIDENTIFIER]) 
	IF @BranchSysEnable = 1
	BEGIN
		INSERT INTO @Branch_Tbl  SELECT [GUID] FROM [dbo].[fnGetBranchesList]( @BranchGuid)  
		IF ISNULL( @BranchGuid, 0x0) = 0x0   
			INSERT INTO @Branch_Tbl VALUES(0x0)
	END
	ELSE
	Begin
		INSERT INTO @Branch_Tbl VALUES((SELECT Branch FROM ce000 CE INNER JOIN en000 EN ON CE.[GUID] =  En.ParentGUID WHERE EN.[GUID] = @objectGuid))
	END
	
	DECLARE @CashAccountTbl TABLE( [GUID] [UNIQUEIDENTIFIER]) 
	INSERT INTO @CashAccountTbl  SELECT [GUID] FROM dbo.fnGetAccountsList(@CashAccount, 0)

	SELECT @CustomerGroupGuid = CG.[Guid], @accountCustomers = CG.AccountCustomers, @CondGuid = CG.ConditionsGuid 
	FROM NSCustomerGroup000 CG INNER JOIN NSEntryCondition000 EC ON CG.[Guid] = EC.[CustomerGroupGuid] AND EC.NotificationGuid = @notificationGuid

	DECLARE @customer TABLE([Guid] UNIQUEIDENTIFIER, Security INT)
	INSERT INTO @customer EXEC prcGetCustsList 0x0, @accountCustomers, @CondGuid

	DELETE @customer WHERE [GUID] IN (SELECT G.CustomerGuid FROM NSCustomerGroupCustomer000 G WHERE G.CustomerGroupGuid = @CustomerGroupGuid)
	
	IF NOT EXISTS (SELECT * FROM et000 ET 
		right JOIN NSEntrySrcType000 SRC on ET.[GUID] = SRC.TypeGuid 
		right JOIN ce000 CE on CE.TypeGUID =SRC.TypeGuid
		INNER JOIN  @Branch_Tbl fnBr ON CE.Branch = fnBr.[GUID]
		INNER JOIN en000 EN on EN.[GUID] = @objectGuid AND CE.[GUID] =  En.ParentGUID
		INNER JOIN NSEntryCondition000 EC ON EC.[GUID] = SRC.EntryConditionGuid AND EC.NotificationGuid = @notificationGuid
		INNER JOIN cu000 CU on CU.AccountGUID = En.AccountGUID
		INNER JOIN @customer CG ON CU.[GUID] = CG.[Guid] 
		INNER JOIN  @Cost_Tbl fn ON EN.CostGUID = fn.[GUID]
		INNER JOIN @CashAccountTbl CA ON EN.ContraAccGUID = CA.[GUID])
	BEGIN
		RETURN 0
	END
	RETURN 1 
END 
################################################################################
CREATE FUNCTION fnNSCheckEntryEventCondtions(
	@eventConditonGuid UNIQUEIDENTIFIER,
	@objectGuid UNIQUEIDENTIFIER)
RETURNS BIT AS
BEGIN 

	DECLARE @CustomerAccountBalanceType INT
	DECLARE @customerAccountBalance FLOAT
	DECLARE @CashAccountEntryBalance FLOAT
	DECLARE @CustomerAccount UNIQUEIDENTIFIER
	DECLARE @BranchGuid UNIQUEIDENTIFIER
	DECLARE @eventConditionReadUnPosted Bit
	DECLARE @objectIsPosted Bit

	SELECT @eventConditionReadUnPosted = ReadUnPosted, @CustomerAccountBalanceType = CustomerAccountBalanceType FROM NSEntryEventCondition000 EC WHERE ec.EventConditionGuid = @eventConditonGuid
	SELECT @BranchGuid = vw.ceBranch,@objectIsPosted = vw.ceIsPosted, @CustomerAccount = vw.enAccount, @CashAccountEntryBalance = vw.enCredit - vw.enDebit from vwCeEn vw where [enGUID] = @objectGuid

	IF(@eventConditionReadUnPosted = 0 and @objectIsPosted = 0)
	BEGIN
		return 0
	END

	IF(@CustomerAccountBalanceType & 1 = 1 and @CashAccountEntryBalance < 0) -- œ›⁄ œ›⁄… ·„Ê—œ --
	BEGIN
		return 1
	END

	ELSE IF(@CustomerAccountBalanceType & 2 = 2 and @CashAccountEntryBalance > 0) --  «” ·«„ œﬁ⁄… „‰ «·“»Ê‰
	BEGIN
		return 1
	END

	DECLARE @BranchSysEnable int = (SELECT value from op000 where name  = 'EnableBranches')
	IF @BranchSysEnable <> 1
	BEGIN
		SET @BranchGuid = 0x0
	END
	
	SELECT @customerAccountBalance = AccBalancesValue from fnNSGetAccBalWithCostAndBranch(@CustomerAccount, 0x0, @BranchGuid , @eventConditionReadUnPosted)

	IF(@customerAccountBalance <> 0) --  ’›Ì— «·Õ”«»
	BEGIN
		RETURN 0
	END

	IF(@CustomerAccountBalanceType & 4 = 4 and @CashAccountEntryBalance < 0) -- œ›⁄ œ›⁄… ·„Ê—œ --
	BEGIN
		return 1
	END

	ELSE IF(@CustomerAccountBalanceType & 8 = 8 and @CashAccountEntryBalance > 0) --  «” ·«„ œﬁ⁄… „‰ «·“»Ê‰
	BEGIN
		return 1
	END

	RETURN 0
END 
################################################################################
#END