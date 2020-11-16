##################################################################################
CREATE PROCEDURE prcOrders_CheckApprovals 
	@StartDate DATETIME,
	@EndDate DATETIME, 
	@SourcesGUID UNIQUEIDENTIFIER,		-- The selected order sources guid  
	@IncludeMissedApprovals BIT = 1,    -- 1: include the missed approvals, 0: don’t include them. 
	@IncludeNotApproved BIT = 1,        -- 1: include the not approved orders, 0: don’t include them. 
	@IncludePartiallyApproved BIT = 0,	-- 1: include the partially approved orders, 0: don’t include them. 
	@IsPreserveApprovals BIT = 0        -- 1: preserve the found approvals if found (related to the IncludePartiallyApproved argument).
AS
	SET NOCOUNT ON 
	---------------------    #OrderTypesTbl   ------------------------       
	CREATE TABLE #OrderTypesTbl (
		[TYPE] UNIQUEIDENTIFIER,
		Sec INT,
		ReadPrice INT,
		UnPostedSec INT)   

	INSERT INTO #OrderTypesTbl
	EXEC prcGetBillsTypesList2 @SourcesGUID 

	DECLARE @Orders TABLE(OrderGuid UNIQUEIDENTIFIER, OrderTypeGuid UNIQUEIDENTIFIER, OrderApprovalState INT)
	INSERT INTO @Orders
	SELECT
		ord.OrderGuid,
		ord.OrderTypeGuid,
		ord.OrderApprovalState
	FROM 
		vwExtendedOrders ord
		INNER JOIN #OrderTypesTbl OrderTypes ON ord.[OrderTypeGuid] = OrderTypes.[TYPE]
	WHERE 
		(
			(ord.OrderApprovalState = 0 AND @IncludeNotApproved = 1)
			OR 
			(ord.OrderApprovalState = 1 AND @IncludePartiallyApproved = 1)
			OR 
			(ord.OrderApprovalState = 3 AND @IncludeMissedApprovals = 1)
			/*2: Fully Approved, not included.*/
		)
		AND ord.[OrderDate] BETWEEN @StartDate AND @EndDate	
		AND ord.IsFinished = 0 
		AND ord.IsCanceled = 0
		AND AreApprovalsAsType = 0 

	IF @IncludeNotApproved = 1 
	BEGIN
		DELETE [OrderApprovals000]
		FROM 
			[OrderApprovals000] oa 
			INNER JOIN @Orders ord ON ord.OrderGuid = oa.OrderGuid 
		WHERE 
			ord.OrderApprovalState = 0 

		INSERT INTO OrderApprovals000 ([GUID], [Number], [OrderGuid], [UserGuid])
		SELECT NEWID(), app.[Order], ord.[OrderGuid], app.[UserGuid]			
		FROM 
			UsrApp000 app 
			INNER JOIN @Orders ord ON ord.[OrderTypeGuid] = app.[ParentGuid]
		WHERE 
			ord.OrderApprovalState = 0 
	END 

	IF @IncludePartiallyApproved = 1
	BEGIN 
		IF @IsPreserveApprovals = 0
		BEGIN 
			DELETE [OrderApprovals000]
			FROM 
				[OrderApprovals000] oa 
				INNER JOIN @Orders ord ON ord.OrderGuid = oa.OrderGuid 
			WHERE 
				ord.OrderApprovalState = 1 

			INSERT INTO OrderApprovals000 ([GUID], [Number], [OrderGuid], [UserGuid])
			SELECT NEWID(), app.[Order], ord.[OrderGuid], app.[UserGuid]			
			FROM 
				UsrApp000 app 
				INNER JOIN @Orders ord ON ord.[OrderTypeGuid] = app.[ParentGuid]
			WHERE 
				ord.OrderApprovalState = 1 
		END ELSE BEGIN 
			DELETE [OrderApprovals000]
			FROM 
				[OrderApprovals000] oa 
				INNER JOIN @Orders ord ON ord.OrderGuid = oa.OrderGuid 
				LEFT JOIN UsrApp000 us ON us.UserGuid = oa.UserGuid AND us.[ParentGuid] = ord.[OrderTypeGuid] 
			WHERE 
				us.Guid IS NULL 
				AND 
				ord.OrderApprovalState = 1

			UPDATE [OrderApprovals000]
			SET 
				Number = us.[Order]
			FROM 
				UsrApp000 us
				INNER JOIN @Orders ord ON us.[ParentGuid] = ord.[OrderTypeGuid] 
				INNER JOIN [OrderApprovals000] oa ON us.UserGuid = oa.UserGuid AND oa.OrderGuid = ord.OrderGuid
			WHERE 
				oa.Number != us.[Order]
				AND 
				ord.OrderApprovalState = 1
			
			INSERT INTO OrderApprovals000 ([GUID], [Number], [OrderGuid], [UserGuid])
			SELECT NEWID(), us.[Order], ord.[OrderGuid], us.[UserGuid]			
			FROM 
				UsrApp000 us
				INNER JOIN @Orders ord ON us.[ParentGuid] = ord.[OrderTypeGuid] 
				LEFT JOIN [OrderApprovals000] oa ON us.UserGuid = oa.UserGuid AND oa.OrderGuid = ord.OrderGuid
			WHERE 
				oa.Guid IS NULL 
				AND 
				ord.OrderApprovalState = 1
		END 			
	END 

	IF @IncludeMissedApprovals = 1
	BEGIN 
		INSERT INTO OrderApprovals000 ([GUID], [Number], [OrderGuid], [UserGuid])
		SELECT NEWID(), app.[Order], ord.[OrderGuid], app.[UserGuid]			
		FROM 
			UsrApp000 app 
			INNER JOIN @Orders ord ON ord.[OrderTypeGuid] = app.[ParentGuid]
		WHERE 
			ord.OrderApprovalState = 3 
	END 
##################################################################################
CREATE PROCEDURE prcOrder_SaveApprovals
	@OrderGuid UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 

	DECLARE @TypeGuid UNIQUEIDENTIFIER 
	SET @TypeGuid = (SELECT TypeGuid FROM bu000 WHERE guid = @OrderGuid)
	IF ISNULL(@TypeGuid, 0x0) = 0x0
		RETURN 

	DELETE OrderApprovals000 WHERE orderGuid = @OrderGuid

	INSERT INTO OrderApprovals000
	SELECT 
		NewId(), 
		[Order], 
		@OrderGuid, 
		[UserGuid]
	FROM 
		UsrApp000 
	WHERE 
		ParentGUID = @TypeGuid
##################################################################################
#END
