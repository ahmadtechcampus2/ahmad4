################################################################################
CREATE PROCEDURE prcPOSSD_GetTicketSupervisorApprovals
	@TicketGUID UNIQUEIDENTIFIER,
	@IsOrder BIT
AS
SET NOCOUNT ON

	CREATE TABLE #SuperVisorsApprovals ( [TicketGUID]			UNIQUEIDENTIFIER,
										 [SupervisorName]		NVARCHAR(250),
										 [SupervisorLatinName]	NVARCHAR(250),
										 [PermissionName]		NVARCHAR(250),
										 [CreatedOnDateTime]	DATETIME,
										 [MatName]				NVARCHAR(1000),
										 [MatLatinName]			NVARCHAR(1000),
										 [Percentage]			FLOAT,
										 [Value]				FLOAT,
										 [Price]				FLOAT,
										 [Unit]					NVARCHAR(100) )

	
	DECLARE @OrderGUID UNIQUEIDENTIFIER = 0x0
	IF(@IsOrder = 1)
	BEGIN
		SET @OrderGUID = (SELECT [GUID] FROM POSSDTicketOrderInfo000 WHERE TicketGUID = @TicketGUID)
	END

	SELECT
		DiscAndAdd.TicketGuid, 
		SUM(DiscAndAdd.ItemShareOfTotalDiscount) AS IDiscVal,
		SUM(DiscAndAdd.ItemShareOfTotalAddition) AS IExtrVal,
		SUM(DiscAndAdd.ValueToDiscount) AS TotalDiscount,
		SUM(DiscAndAdd.ValueToAdd) AS TotalAddition,
		SUM(TI.Value) AS TotalValue
	INTO 
		#TicketDiscountAddition
	FROM 
		fnPOSSD_Ticket_GetDiscountAndAddition (@TicketGUID) DiscAndAdd
		INNER JOIN POSSDTicketItem000 TI ON DiscAndAdd.[Guid] = TI.[GUID]
	GROUP BY 
		DiscAndAdd.TicketGuid

	--=============================== Ticket
	INSERT INTO #SuperVisorsApprovals
	SELECT 
		op.[RecordGUID] AS [TicketGUID],
		e .[Name] AS [SupervisorName],
		e .[LatinName] AS [SupervisorLatinName],
		op.[PermissionName],
		op.[CreatedOnDateTime],
		'' AS [MatName],
		'' AS [MatLatinName],

		CASE WHEN op.[PermissionName] = 'ChangeTicketDiscount' THEN (DISCADD.IDiscVal / (DISCADD.TotalValue - DISCADD.TotalDiscount) * 100)
			 WHEN op.[PermissionName] = 'ChangeTicketAddition' THEN (DISCADD.IExtrVal / (DISCADD.TotalValue + DISCADD.TotalAddition) * 100)
		END AS [Percentage],

		CASE WHEN op.[PermissionName] = 'ChangeTicketDiscount' THEN DISCADD.IDiscVal
			 WHEN op.[PermissionName] = 'ChangeTicketAddition' THEN DISCADD.IExtrVal
			 ELSE 0
		END AS [Value],

		0 AS [Price],
		'' AS [Unit]

	  FROM 
		[dbo].[POSSDOperationPermission000] op
		INNER JOIN [dbo].[POSSDTicket000] t ON t.[GUID] = op.[RecordGUID]
		INNER JOIN [dbo].[POSSDEmployee000] e ON e.[GUID] = op.[SupervisorGUID]
		LEFT JOIN #TicketDiscountAddition DISCADD ON op.[RecordGUID] = DISCADD.TicketGuid
	  WHERE 
		T.[GUID] = @TicketGUID
		AND((op.[PermissionName] != 'ChangeTicketDiscount')
		   OR(op.[PermissionName] = 'ChangeTicketDiscount' AND DISCADD.TotalDiscount !=0))

	--=============================== Ticket Item
	INSERT INTO #SuperVisorsApprovals
	SELECT 
		ti.TicketGUID AS [TicketGUID],
		e.[Name] AS [SupervisorName],
		e.[LatinName] AS [SupervisorLatinName],
		op.[PermissionName],
		op.[CreatedOnDateTime],
		ti.[MatName],
		ti.[MatLatinName],

		CASE WHEN op.[PermissionName] = 'ChangeTicketItemDiscount' THEN (ti.[ItemDiscountValue] / ti.[Value]) * 100 
			 WHEN op.[PermissionName] = 'ChangeTicketItemAddition' THEN (ti.[ItemAdditionValue] / ti.[Value]) * 100
			 ELSE 0
		END AS [Percentage],

		CASE WHEN op.[PermissionName] = 'ChangeTicketItemDiscount' THEN ti.[ItemDiscountValue]
			 WHEN op.[PermissionName] = 'ChangeTicketItemAddition' THEN ti.[ItemAdditionValue]
			 ELSE 0
		END AS [Value],

		CASE WHEN op.[PermissionName] IN ('ChangeWholePrice', 
										  'ChangeHalfPrice', 
										  'ChangeVendorPrice', 
										  'ChangeExportPrice', 
										  'ChangeRetailPrice', 
										  'ChangeEndUserPrice', 
										  'ChangeManualPrice') THEN ti.[Price] ELSE 0 END,
		CASE op.[PermissionName] WHEN 'ChagneUnit' THEN ti.[UnitName] ELSE '' END AS [Unit]	

	  FROM 
		[dbo].[POSSDOperationPermission000] op
		INNER JOIN [dbo].[vwPOSSDTicketItems] ti ON ti.[ItemGuid] = op.[RecordGUID]
		INNER JOIN [dbo].[POSSDEmployee000] e ON e.[GUID] = op.[SupervisorGUID]
	  WHERE 
		ti.TicketGUID = @TicketGUID
		AND((op.[PermissionName] != 'ChangeTicketItemDiscount')
		   OR(op.[PermissionName] = 'ChangeTicketItemDiscount' AND ti.[ItemDiscountValue] !=0))

	--=============================== Order
	INSERT INTO #SuperVisorsApprovals
	SELECT 
		OP.[RecordGUID]										AS [TicketGUID],
		E .[Name]											AS [SupervisorName],
		E .[LatinName]										AS [SupervisorLatinName],
		OP.[PermissionName]									AS [PermissionName],
		OP.[CreatedOnDateTime]								AS [CreatedOnDateTime],
		''													AS [MatName],
		''													AS [MatLatinName],

		CASE WHEN op.[PermissionName] = 'ChangeTicketDiscount' THEN (DISCADD.IDiscVal / (DISCADD.TotalValue - DISCADD.TotalDiscount) * 100)
			 WHEN op.[PermissionName] = 'ChangeTicketAddition' THEN (DISCADD.IExtrVal / (DISCADD.TotalValue + DISCADD.TotalAddition) * 100)
		END AS [Percentage],

		CASE WHEN op.[PermissionName] = 'ChangeTicketDiscount' THEN DISCADD.IDiscVal
			 WHEN op.[PermissionName] = 'ChangeTicketAddition' THEN DISCADD.IExtrVal
			 WHEN op.[PermissionName] = 'AddDeliveryValue'     THEN OI.DeliveryFee 
			 ELSE 0
		END AS [Value],

		0												    AS [Price],
		''												    AS [Unit]
	  FROM 
		[dbo].[POSSDOperationPermission000] OP
		INNER JOIN POSSDTicketOrderInfo000 OI	   ON OI.[GUID] = OP.RecordGUID
		INNER JOIN POSSDEmployee000 E			   ON E.[GUID] = OP.[SupervisorGUID]
		LEFT  JOIN #TicketDiscountAddition DISCADD ON OI.TicketGUID = DISCADD.TicketGuid
	  WHERE 
		OI.[GUID] = @OrderGUID
		AND @IsOrder = 1


	  --=============================== RESULT
	  SELECT 
		[SupervisorName],
		[SupervisorLatinName],
		[PermissionName],
		[CreatedOnDateTime],
		[MatName],
		[MatLatinName],
		[Percentage],
		[Value],
		[Price],
		[Unit]
	 FROM 
		#SuperVisorsApprovals
	 ORDER BY 
		[CreatedOnDateTime]
#################################################################
#END