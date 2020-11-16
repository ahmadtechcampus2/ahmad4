################################################################################
CREATE PROCEDURE prcNSCheckChecksNotificationConditions(
	@notificationGuid UNIQUEIDENTIFIER,
	@objectGuid UNIQUEIDENTIFIER)
AS
BEGIN

	DECLARE @CostGuid UNIQUEIDENTIFIER
	DECLARE @BranchGuid UNIQUEIDENTIFIER 
	DECLARE @accountCustomers UNIQUEIDENTIFIER
	DECLARE @CondGuid UNIQUEIDENTIFIER
	DECLARE @CustomerGroupGuid UNIQUEIDENTIFIER

	SELECT @CostGuid = CC.CostCenterGuid , @BranchGuid = CC.BranchGuid 
	FROM NSChecksCondition000 CC
    WHERE CC.NotificationGuid = @notificationGuid
	
	DECLARE @BranchSysEnable int = (SELECT value from op000 where name  = 'EnableBranches')
	DECLARE @Branch_Tbl TABLE( [GUID] [UNIQUEIDENTIFIER]) 
	IF @BranchSysEnable = 1
	Begin
		INSERT INTO @Branch_Tbl  SELECT [GUID] FROM [dbo].[fnGetBranchesList]( @BranchGuid)  
		IF ISNULL( @BranchGuid, 0x0) = 0x0   
			INSERT INTO @Branch_Tbl VALUES(0x0)
	END
	ELSE
	Begin
		INSERT INTO @Branch_Tbl VALUES((SELECT BranchGUID FROM ch000 ch  WHERE ch.[GUID] = @objectGuid))
	END

	DECLARE @Cost_Tbl TABLE( [GUID] [UNIQUEIDENTIFIER]) 
	INSERT INTO @Cost_Tbl  SELECT [GUID] FROM [dbo].[fnGetCostsList]( @CostGuid)  
	IF ISNULL( @CostGuid, 0x0) = 0x0   
		INSERT INTO @Cost_Tbl VALUES(0x0)

	SELECT @CustomerGroupGuid = CG.[Guid], @accountCustomers = CG.AccountCustomers, @CondGuid = CG.ConditionsGuid 
	FROM NSCustomerGroup000 CG INNER JOIN NSChecksCondition000 CC ON CG.[Guid] = CC.[CustomerGroupGuid] AND CC.NotificationGuid = @notificationGuid

	DECLARE @customer TABLE([Guid] UNIQUEIDENTIFIER, Security INT)
	INSERT INTO @customer EXEC prcGetCustsList 0x0, @accountCustomers, @CondGuid

	DELETE @customer WHERE [GUID] IN (SELECT G.CustomerGuid FROM NSCustomerGroupCustomer000 G WHERE G.CustomerGroupGuid = @CustomerGroupGuid)

	IF NOT EXISTS 
	( 
		SELECT * FROM ch000 ch 
		INNER JOIN NSChecksSrcType000 st ON ch.TypeGUID =st.TypeGuid AND ch.GUID = @objectGuid
		INNER JOIN NSChecksCondition000 c ON c.Guid = st.ChecksConditionGuid AND c.NotificationGuid = @notificationGuid
		INNER JOIN cu000 CU ON CU.AccountGUID=ch.AccountGUID
		INNER JOIN @customer CG ON CU.[GUID] = CG.[Guid]
		INNER JOIN  @Cost_Tbl fn ON ch.Cost1GUID = fn.[GUID]
		INNER JOIN  @Branch_Tbl fnBr ON ch.BranchGUID = fnBr.[GUID]
	)
	BEGIN
		RETURN 0
	END
	RETURN 1
END  
####################################################################################
CREATE PROCEDURE NSPrcGetChecksTypes
	@SrcGuids     AS  NVARCHAR(MAX)
As
	SET NOCOUNT ON

	CREATE TABLE #ChecksTypes
	(
		pay	      INT,
		[receive] INT
	)
	DECLARE @SrcGuid AS VARCHAR(37)

	WHILE LEN(@SrcGuids) > 0
		BEGIN
			SET @SrcGuid=(SELECT SUBSTRING(@SrcGuids,1,36))

			INSERT INTO #ChecksTypes(pay, [receive])
			SELECT bPayable,bReceivable
			FROM nt000 
			WHERE [GUID]= (SELECT CONVERT(UNIQUEIDENTIFIER, @SrcGuid))

			SET @SrcGuids=(SELECT REPLACE(@SrcGuids,@SrcGuid,''))
		END

SELECT * FROM #ChecksTypes
####################################################################################
CREATE FUNCTION fnNSCheckChecksManualNotificationConditions(
	@notificationGuid UNIQUEIDENTIFIER,
	@objectGuid UNIQUEIDENTIFIER)
RETURNS BIT AS
BEGIN
	RETURN 1
END 
####################################################################################
CREATE PROCEDURE prcNSCheckChecksManualEventCondtions
@eventConditonGuid UNIQUEIDENTIFIER
AS
BEGIN
	INSERT INTO #object SELECT CheckGuid FROM NSChecksManualCondition000
	WHERE EventConditionGuid = @eventConditonGuid
END
################################################################################
CREATE FUNCTION fnNSCheckChecksScheduleEventCondtions(
	@eventConditonGuid UNIQUEIDENTIFIER,
	@fromDate DATETIME)
RETURNS @object TABLE 
(
	[GUID]	UNIQUEIDENTIFIER
)
AS 
BEGIN
	DECLARE @beforeDays INT
	SELECT @beforeDays =  DC.BeforeDays from NSScheduleEventCondition000 DC where DC.EventConditionGuid = @eventConditonGuid
	
	insert into @object SELECT ch.[GUID] FROM ch000 ch 
	WHERE DATEDIFF(day, ch.DueDate, @fromDate) = -1 * @beforeDays
	RETURN
END
####################################################################################
#END

		