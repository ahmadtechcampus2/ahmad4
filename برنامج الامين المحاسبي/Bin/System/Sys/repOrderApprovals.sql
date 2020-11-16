#############################################################################
CREATE PROCEDURE repOrderApprovals 
	@TypeGuid UNIQUEIDENTIFIER,
	@OrderGuid UNIQUEIDENTIFIER = 0X0
AS 
	SET NOCOUNT ON   
		
	DECLARE @IsOutput BIT 
	DECLARE @CurrentDate DATE = GETDATE();
	
	SELECT 
		@IsOutput = bIsOutput
	FROM 
		bt000
	WHERE 
		[GUID] = @TypeGuid

	DECLARE @Result TABLE (
		OrderApprovalGuid UNIQUEIDENTIFIER,
		[UserGuid] UNIQUEIDENTIFIER,
		[AlternativeUserCardGuid] UNIQUEIDENTIFIER,
		[IsApproved] BIT, 
		[ApprovalDate] DATETIME, 
		[ComputerName] NVARCHAR(255),
		[IsAdmin] BIT,
		[Number] INT)
	 
	IF ISNULL(@TypeGUID, 0x0) = 0x0
		RETURN 

	DECLARE @Manager UNIQUEIDENTIFIER = 0x00 
	IF @isOutput = 0  
		SET @manager =(SELECT CONVERT(UNIQUEIDENTIFIER, Value) FROM op000 WHERE Name = 'PurchaseManager') 
	ELSE  
		SET @Manager = (SELECT CONVERT(UNIQUEIDENTIFIER, Value) FROM op000 WHERE Name = 'SalesManager')

	IF (
		(@Manager <> 0x00) 
		AND 
		(
			((ISNULL(@OrderGuid, 0x0) <> 0x0) AND EXISTS(SELECT * FROM OrderApprovals000 WHERE OrderGuid = @OrderGuid))
			OR 
			((ISNULL(@OrderGuid, 0x0) = 0x0) AND EXISTS(SELECT * FROM UsrApp000 WHERE ParentGuid = @TypeGuid))
		)
	)
	BEGIN 
		INSERT INTO @Result 
		SELECT 0x0, @Manager, 0x0, 0, @CurrentDate, HOST_NAME(), 1, 0
		
		DECLARE @ApprovalDate DATETIME 
		IF EXISTS (SELECT @ApprovalDate FROM MgrApp000 mng CROSS APPLY dbo.fnGetLastApprovalState(mng.GUID) AS oaps WHERE mng.OrderGUID = @OrderGuid) 
		BEGIN 
			UPDATE @Result
			SET 
				UserGUID = 
					CASE ISNULL(oaps.IsApproved, 0) WHEN 0 THEN @Manager ELSE 
						CASE ISNULL(oaps.AlternativeUserGUID, 0x0) WHEN 0x0 THEN @Manager ELSE oaps.UserGUID END 
					END,
				IsApproved = ISNULL(oaps.IsApproved, 0), 
				ApprovalDate = ISNULL(oaps.OperationTime, @CurrentDate),
				ComputerName = ISNULL(oaps.ComputerName, HOST_NAME()),
				AlternativeUserCardGUID = ISNULL(oaps.AlternativeUserGUID, 0x0)
			FROM 
				MgrApp000 mng 
				OUTER APPLY dbo.fnGetLastApprovalState(mng.GUID) AS oaps 
			WHERE 
				mng.OrderGUID = @OrderGuid
		END  
	END 
		
	IF ISNULL(@OrderGuid, 0x0) <> 0x0
	BEGIN 
		IF EXISTS(SELECT * FROM OrderApprovals000 WHERE OrderGuid = @OrderGuid)
		BEGIN
			INSERT INTO @Result
			SELECT 
				app.Guid,
				CASE ISNULL(appState.IsApproved, 0) WHEN 0 THEN app.UserGUID ELSE 
					appState.UserGUID
				END,
				CASE ISNULL(appState.IsApproved, 0) WHEN 0 THEN 0x0 ELSE 
					ISNULL(appState.AlternativeUserGUID, 0x0)
				END,
				ISNULL(appState.IsApproved, 0),
				ISNULL(appState.OperationTime, CONVERT(DateTime,0)),
				ISNULL(appState.ComputerName, ''),
				0,
				app.Number
			FROM 
				OrderApprovals000 app
				OUTER APPLY dbo.fnGetLastApprovalState(app.GUID) AS appState 
			WHERE 
				app.OrderGuid = @OrderGuid
		END

		DECLARE @UserGuid UNIQUEIDENTIFIER
		SET @UserGuid = dbo.fnGetCurrentUserGUID()
		IF EXISTS (
			SELECT 
				* 
			FROM 
				@Result res 
				INNER JOIN [OrderAlternativeUsers000] oau ON res.UserGUID = oau.UserGUID 
				LEFT JOIN OrderAlternativeUserTypes000 oaut ON oau.GUID = oaut.ParentGUID 
			WHERE 
				((oau.IsActive = 1) OR (oau.IsLimitedActive = 1 AND @CurrentDate BETWEEN oau.StartDate AND oau.ExpireDate))
				AND 
				((oau.IsAllAvailableTypes = 1) OR (oaut.OrderTypeGUID = @TypeGuid))
				AND 
				oau.AlternativeUserGUID = @UserGuid)
		BEGIN 
			UPDATE @Result
			SET 
				UserGuid = @UserGuid,
				AlternativeUserCardGUID = oau.GUID 
			FROM 
				@Result res 
				INNER JOIN [OrderAlternativeUsers000] oau ON res.UserGUID = oau.UserGUID 
				LEFT JOIN OrderAlternativeUserTypes000 oaut ON oau.GUID = oaut.ParentGUID 
			WHERE 
				((oau.IsActive = 1) OR (oau.IsLimitedActive = 1 AND @CurrentDate BETWEEN oau.StartDate AND oau.ExpireDate))
				AND 
				((oau.IsAllAvailableTypes = 1) OR (oaut.OrderTypeGUID = @TypeGuid))
				AND 
				oau.AlternativeUserGUID = @UserGuid			
				AND 
				(
					((oau.[Type] = 0) AND (res.IsAdmin = 0)) 
					OR 
					((@IsOutput = 1) AND (oau.[Type] = 1) AND (res.IsAdmin = 1)) 
					OR 
					((@IsOutput = 0) AND (oau.[Type] = 2) AND (res.IsAdmin = 1)) 
				)
				AND 
				((IsApproved = 0))

		END
	END ELSE BEGIN 
		INSERT INTO @Result
		SELECT 
			GUID,
			UserGUID,
			-- userTbl.LoginName,
			0x0,
			0,
			@CurrentDate,
			HOST_NAME(),
			0,
			[Order]
		FROM 
			UsrApp000
			-- INNER JOIN us000 userTbl ON userTbl.GUID = userApproval.UserGUID 
		WHERE 
			ParentGuid = @TypeGUID  
		ORDER BY 
			[Order] 
	END 
	
	SELECT 
		res.*,
		us.LoginName AS UserName 
	FROM 
		@Result res 
		INNER JOIN us000 us ON us.GUID = res.UserGUID
	ORDER BY [IsApproved] DESC, CASE [IsApproved] WHEN 1 then [ApprovalDate] else [res].[Number] END

#############################################################################
CREATE PROCEDURE prcInsertOrderApprovalState @ParentGuid UNIQUEIDENTIFIER
	, @UserGuid UNIQUEIDENTIFIER
	, @AlternativeUserGUID UNIQUEIDENTIFIER
	, @IsApproved BIT
AS
SET NOCOUNT ON

DECLARE @CurrentDate DATETIME = GETDATE();
DECLARE @UserApprovalDate DATETIME
DECLARE @PreventCancelApproval INT = 0

-----------------------------------------------------
--get PreventCanceApproval from order options
SELECT @PreventCancelApproval = ISNULL(value, 0)
FROM [op000]
WHERE [name] like 'AmnOrders_PreventCancelApproval'
-----------------------------------------------------
--get Current order Guid
DECLARE @CurrentOrderGuid UNIQUEIDENTIFIER;

SELECT @CurrentOrderGuid = OrderGuid
FROM OrderApprovals000
WHERE GUID = @ParentGuid
-----------------------------------------------------
--get Last approval state  Date of current user on current order.
SELECT @UserApprovalDate = MAX(OperationTime)
FROM OrderApprovalStates000 appState
WHERE appState.ParentGuid = @ParentGuid
-----------------------------------------------------
-- cancel all approvals whose date comes  after  last  current  user approval on current order 
-- when he cancel his approval on order 
-- depend on check PreventCancelApproval
IF (@IsApproved = 0) AND (@PreventCancelApproval = 0)
	INSERT INTO OrderApprovalStates000 (
		[GUID]
		, [Number]
		, ParentGuid
		, UserGuid
		, AlternativeUserGUID
		, IsApproved
		, OperationTime
		, ComputerName
		)
	SELECT NEWID()
		, oas.Number + 1
		, oa.GUID
		, @UserGUID
		, 0x0
		, 0
		, @CurrentDate
		, HOST_NAME()
	FROM OrderApprovals000 oa
	CROSS APPLY dbo.fnGetLastApprovalState(oa.GUID) oas
	WHERE oas.OperationTime > @UserApprovalDate
		AND oa.OrderGuid = @CurrentOrderGuid
		AND oas.IsApproved = 1
-----------------------------------------------------
--finally add new approval state of current user on current order 
--increment last number of approval state
DECLARE @Number INT

SELECT @Number = ISNULL(MAX(Number) + 1, 1)
FROM OrderApprovalStates000
WHERE ParentGuid = @ParentGuid
-----------------------------------------------------
--add new approval state of current user on current order
INSERT INTO OrderApprovalStates000 (
	Guid
	, Number
	, ParentGuid
	, UserGuid
	, AlternativeUserGUID
	, IsApproved
	, OperationTime
	, ComputerName
	)
VALUES (
	NEWID()
	, @Number
	, @ParentGuid
	, @UserGuid
	, @AlternativeUserGUID
	, @IsApproved
	, @CurrentDate
	, HOST_NAME()
	)
#############################################################################
#END
