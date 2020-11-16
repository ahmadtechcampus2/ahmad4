#########################################################################
CREATE FUNCTION fnManagerIsApproved(@OrderGuid UNIQUEIDENTIFIER)
	RETURNS BIT 
AS BEGIN 
	DECLARE @IsApproved BIT 
	SELECT
		TOP 1 @IsApproved = oas.IsApproved 
	FROM 
		OrderApprovalStates000 oas 
		INNER JOIN MgrApp000 mgr ON mgr.GUID = oas.ParentGUID
	WHERE 
		mgr.OrderGuid = @OrderGuid
	ORDER BY 
		oas.OperationTime DESC

	RETURN ISNULL(@IsApproved, 0)
END 
#########################################################################
CREATE FUNCTION fnOrderUserIsApproved(@OrderApprovalGuid UNIQUEIDENTIFIER)
	RETURNS BIT 
AS BEGIN 
	DECLARE @IsApproved BIT 
	SELECT TOP 1 @IsApproved = IsApproved FROM OrderApprovalStates000 WHERE ParentGuid = @OrderApprovalGuid ORDER BY OperationTime DESC

	RETURN ISNULL(@IsApproved, 0)
END 
#########################################################################
CREATE FUNCTION fnGetLastApprovalState(@OrderApprovalGuid UNIQUEIDENTIFIER)
	RETURNS TABLE
AS RETURN 
	SELECT TOP 1 * FROM OrderApprovalStates000 WHERE ParentGuid = @OrderApprovalGuid ORDER BY OperationTime DESC
#########################################################################
CREATE VIEW vwOrderApprovals
AS 
	SELECT 
		*,
		dbo.fnOrderUserIsApproved(Guid) AS IsApproved
	FROM 
		OrderApprovals000 
#########################################################################
CREATE FUNCTION fnOrderApprovalState (@OrderGuid AS UNIQUEIDENTIFIER)
	RETURNS INT /*0 not approved, 1 partially approved, 2 fully approved, 3 No Approval Needed*/
AS 
BEGIN 
	-- Declare the return variable here 
	DECLARE  
			@OrderApprovalState INT = 0, 
			@UsersCount INT = 0, 
			@ApprovalsSum INT = 0, 
			@NotApproved INT = 0, 
			@PartialApproved INT = 1, 
			@FullyApproved INT = 2,  
			@NoApprovalNeeded INT = 3,  
		    @isOutput BIT = 0,  
	        @Manager UNIQUEIDENTIFIER = 0x00
	         
	SELECT @isOutput = btIsOutput FROM vwbu WHERE buGUID = @OrderGuid 
	IF @isOutput = 0  
		SET @manager = (SELECT CONVERT(UNIQUEIDENTIFIER, Value) FROM op000 WHERE Name = 'PurchaseManager') 
	ELSE  
		SET @Manager = (SELECT CONVERT(UNIQUEIDENTIFIER, Value) FROM op000 WHERE Name = 'SalesManager') 
	
	IF EXISTS (SELECT * FROM MgrApp000 WHERE (OrderGUID = @OrderGuid) AND (dbo.fnOrderUserIsApproved(Guid) = 1)) AND @Manager <> 0x00 -- „’«œﬁ«  „œ—«¡ «·„»Ì⁄«  «Ê «·„‘ —Ì«   
	  	RETURN @FullyApproved 
	
	IF NOT EXISTS (SELECT GUID FROM OrderApprovals000 WHERE OrderGuid = @OrderGuid)
		RETURN  @NoApprovalNeeded  
	ELSE BEGIN  
		-- Get  accounts that assigned to  approve for this order - Sum of Approvals of the same count 
		SELECT @UsersCount = COUNT(UserGuid), @ApprovalsSum = SUM(CASE ISNULL(IsApproved, 0) WHEN 0 THEN 0 ELSE 1 END) FROM vwOrderApprovals WHERE OrderGuid = @OrderGuid GROUP BY OrderGuid
	 
		IF (@UsersCount <> 0) 
		BEGIN 
			IF @UsersCount = @ApprovalsSum  
				SET @OrderApprovalState = @FullyApproved 
			IF @UsersCount > @ApprovalsSum 
				SET @OrderApprovalState = @PartialApproved
			IF @ApprovalsSum = 0 
				SET @OrderApprovalState = @NotApproved
		END ELSE
			SET @OrderApprovalState = @FullyApproved
	END 

	RETURN @OrderApprovalState 
END 
#########################################################################
CREATE VIEW vwExtendedOrders
AS 
	SELECT
		bu.GUID AS OrderGuid,
		bu.Date AS OrderDate,
		bu.TypeGuid AS OrderTypeGuid,
		oai.Finished AS IsFinished,
		oai.Add1 AS IsCanceled,
		dbo.fnOrderApprovalState(bu.GUID) AS OrderApprovalState,
		dbo.fnOrderAreApprovalsAsType(bu.GUID) AS AreApprovalsAsType
	FROM 	
		bu000 bu 
		INNER JOIN OrAddInfo000 oai ON oai.ParentGuid = bu.Guid 
#########################################################################
CREATE FUNCTION fnPreviousUsersApproved(@OrAppGuid UNIQUEIDENTIFIER, @OrderGuid UNIQUEIDENTIFIER)
	RETURNS BIT 
AS BEGIN 
	DECLARE 
		@Order INT,
		@Count INT
	
	SELECT 
		TOP 1 @Order = Number
	FROM 
		OrderApprovals000
	WHERE 
		OrderGuid = @OrderGuid AND [Guid] = @OrAppGuid

	IF EXISTS(
		SELECT 
			*
		FROM 
			vwOrderApprovals
		WHERE 
			OrderGuid = @OrderGuid 
			AND 
			Number < ISNULL(@Order, 0)
			AND 
			IsApproved = 0)
			RETURN 0
	
	RETURN 1
END 
#########################################################################
CREATE FUNCTION fnNextUserApproved(@UserGuid UNIQUEIDENTIFIER, @OrderGuid UNIQUEIDENTIFIER)
	RETURNS BIT 
AS BEGIN 
	DECLARE 
		@Order INT,
		@IsApproved BIT 
	
	SELECT 
		TOP 1 @Order = Number
	FROM 
		OrderApprovals000
	WHERE 
		OrderGuid = @OrderGuid AND UserGuid = @UserGuid

	SELECT 
		@IsApproved = ISNULL(IsApproved, 0)
	FROM 
		vwOrderApprovals
	WHERE 
		OrderGuid = @OrderGuid 
		AND 
		UserGuid = @UserGuid 
		AND 
		Number = ISNULL(@Order, 0)
	
	RETURN @IsApproved
END 
#########################################################################
CREATE FUNCTION fnIsLastApprovalState(@UserGuid UNIQUEIDENTIFIER, @OrderGuid UNIQUEIDENTIFIER)
	RETURNS BIT 
AS BEGIN 
	DECLARE 
		@lastDate DATETIME,
		@currentUserDate DATETIME
	
	 SELECT  @lastDate = MAX(OperationTime) 
	 FROM
		OrderApprovals000 app
		OUTER APPLY dbo.fnGetLastApprovalState(app.GUID) AS appState
	WHERE 
		app.OrderGuid = @OrderGuid AND appState.IsApproved = 1

	SELECT @currentUserDate = OperationTime 
	FROM
		OrderApprovals000 app
		OUTER APPLY dbo.fnGetLastApprovalState(app.GUID) AS appState
	WHERE 
		app.OrderGuid = @OrderGuid AND app.UserGuid = @UserGuid
								
	IF(@currentUserDate < @lastDate)
		RETURN 0
	ELSE
		RETURN 1
	
	RETURN 0
END 
#########################################################################
#END
