################################################################################
CREATE PROCEDURE prcNSCheckAccountNotificationConditions(
	@notificationGuid UNIQUEIDENTIFIER,
	@objectGuid UNIQUEIDENTIFIER)
AS
BEGIN
	
	DECLARE @BranchSysEnable INT
	DECLARE @AccountGUID	 UNIQUEIDENTIFIER
	DECLARE @CostCenterGUID  UNIQUEIDENTIFIER
	DECLARE @BranchGUID		 UNIQUEIDENTIFIER
	DECLARE @Branch_Tbl		TABLE([GUID] UNIQUEIDENTIFIER) 
	DECLARE @CostCenter_Tbl TABLE([GUID] UNIQUEIDENTIFIER)
	DECLARE @Account_Tbl	TABLE([GUID] UNIQUEIDENTIFIER) 

	SELECT 
		@AccountGUID	= AccountGuid, 
		@CostCenterGUID = CostCenterGuid, 
		@BranchGUID		= BranchGuid 
	FROM 
		NSAccountCondition000
	WHERE 
		NotificationGuid = @notificationGuid


	---------- Cost Center ----------	
	INSERT INTO @CostCenter_Tbl  
	SELECT [GUID] 
	FROM [dbo].[fnGetCostsList]( @CostCenterGUID)  

	IF ISNULL( @CostCenterGUID, 0x0) = 0x0   
		INSERT INTO @CostCenter_Tbl VALUES(0x0)


	---------- Branch ----------
	SET @BranchSysEnable = (SELECT value FROM op000 WHERE name = 'EnableBranches')
	
	IF @BranchSysEnable = 1
	BEGIN
		INSERT INTO @Branch_Tbl  
		SELECT [GUID] 
		FROM [dbo].[fnGetBranchesList](@BranchGUID)

		IF ISNULL( @BranchGUID, 0x0) = 0x0   
			INSERT INTO @Branch_Tbl VALUES(0x0)
	END
	ELSE
	BEGIN
		INSERT INTO @Branch_Tbl VALUES(( SELECT 
											Branch 
									     FROM 
											ce000 CE 
											INNER JOIN en000 EN ON CE.[GUID] =  En.ParentGUID 
										 WHERE 
											EN.[GUID] = @objectGuid ))
	END
	
	---------- Account ----------
	INSERT INTO @Account_Tbl SELECT 
								[GUID] 
							 FROM 
								dbo.fnGetAccountsList(@AccountGUID, 0)

	-- RESULT
	IF NOT EXISTS( SELECT * 
				   FROM
					ce000 CE 
					INNER JOIN en000 EN ON EN.[GUID] = @objectGuid AND CE.[GUID] =  EN.ParentGUID
					INNER JOIN @Branch_Tbl BR ON CE.Branch = BR.[GUID]
					INNER JOIN @CostCenter_Tbl CO ON EN.CostGUID = CO.[GUID]
					INNER JOIN @Account_Tbl AC ON EN.AccountGUID = AC.[GUID] )
	BEGIN
		RETURN 0
	END
	RETURN 1

END
################################################################################
CREATE FUNCTION fnNSCheckAccountEventCondtions(
	@eventConditonGuid UNIQUEIDENTIFIER,
	@objectGuid UNIQUEIDENTIFIER)
RETURNS BIT AS
BEGIN 
	
	DECLARE @IsDebit  BIT 
	DECLARE @IsCredit BIT


	SELECT @IsDebit  = IsDebit, 
		   @IsCredit = IsCredit 
	FROM 
		NSAccountEventCondition000 
	WHERE 
		EventConditionGuid = @eventConditonGuid

 IF EXISTS(	SELECT * FROM en000 
			WHERE 
				[GUID] = @objectGuid
				AND ((@IsDebit  = 1 AND Debit  <> 0) 
				OR   (@IsCredit = 1 AND Credit <> 0) ))
	BEGIN
		RETURN 1
	END 

	RETURN 0

END 
################################################################################
#END