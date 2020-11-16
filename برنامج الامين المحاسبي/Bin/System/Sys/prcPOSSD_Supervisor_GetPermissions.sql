################################################################################
CREATE PROCEDURE prcPOSSD_Supervisor_GetPermissions
-- Params -----------------------------------
	@SupervisorGuid			UNIQUEIDENTIFIER,
	@EmployeeGuid			UNIQUEIDENTIFIER,
	@StationGuid            UNIQUEIDENTIFIER,
	@ShiftGuid				UNIQUEIDENTIFIER,
	@MaterialGuid			UNIQUEIDENTIFIER,
	@GroupGuid				UNIQUEIDENTIFIER,
	@OperationType			INT,
	@PermissionType			INT,
	@StartDate				DATETIME,
	@EndDate				DATETIME
---------------------------------------------
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	
	DECLARE @language INT = [dbo].[fnConnections_getLanguage]()

	CREATE TABLE #Result ( SupervisorGuid	UNIQUEIDENTIFIER,
						   EmployeeGuid		UNIQUEIDENTIFIER,
						   TicketGuid		UNIQUEIDENTIFIER,
						   OrderGuid		UNIQUEIDENTIFIER,
						   MaterialGuid		UNIQUEIDENTIFIER,
						   CustomerGuid		UNIQUEIDENTIFIER,
						   StationGuid		UNIQUEIDENTIFIER,
						   Operation		INT,
						   [Type]			INT,
						   PermissionStr	NVARCHAR(50),
						   OperationType	INT,
						   OperationNumber	INT,
						   ShfitCode		NVARCHAR(50),
						   StationName		NVARCHAR(250),
						   EmployeeName		NVARCHAR(250),
						   SupervisorName	NVARCHAR(250),
						   PermissionName	NVARCHAR(50),
						   CustomerName		NVARCHAR(250),
						   [Date]			NVARCHAR(50),
						   [Time]			NVARCHAR(50),
						   [Percentage]		FLOAT,
						   [Value]			FLOAT,
						   Price			FLOAT,
						   Unit				NVARCHAR(50),
						   PriceName		NVARCHAR(50),
						   [Group]			NVARCHAR(250),
						   Material			NVARCHAR(250))

	CREATE TABLE #TicketDiscountAddition (TicketGuid	UNIQUEIDENTIFIER,
										  IDiscVal		FLOAT,
										  IExtrVal 		FLOAT,
										  TotalDiscount	FLOAT,
										  TotalAddition	FLOAT,
										  TotalValue	FLOAT)

	DECLARE @ChangeTicketDiscountFilter          INT = 2
	DECLARE @ChangeTicketAdditionFilter          INT = 4
	DECLARE @ChangeItemDiscountFilter            INT = 8
	DECLARE @ChangeItemAdditionFilter            INT = 16
	DECLARE @ChangeItemPriceFilter               INT = 32
	DECLARE @ChangeItemUnitFilter                INT = 64
	DECLARE @AddDeliveryValueFilter              INT = 128
	DECLARE @CancelDeliveryOrderFilter           INT = 256
	DECLARE @CancelOrderFromOrderTabFilter       INT = 512
	DECLARE @CancelOrderFromSearchCustPageFilter INT = 1024

	DECLARE @SalesOperationFilter     INT = 2
	DECLARE @ReSalesOperationFilter   INT = 4
	DECLARE @DeliveryOperationFilter  INT = 8
	DECLARE @PickupOperationFilter    INT = 16

--============================ PERMISSIONS
	SELECT *
	INTO #OperationPermissionResult
	FROM POSSDOperationPermission000 
	WHERE ( SupervisorGUID = @SupervisorGuid OR @SupervisorGuid = 0x0 )
	  AND ( EmployeeGUID = @EmployeeGuid OR @EmployeeGuid = 0x0 )
	  AND ( CreatedOnDateTime BETWEEN @StartDate AND @EndDate )
	  AND (( @GroupGuid <> 0x0 and OperationType  = 1) OR (@GroupGuid = 0x0))
	  AND (( @MaterialGuid <> 0x0 and OperationType  = 1) OR (@MaterialGuid = 0x0))
	  AND ( (PermissionName = 'ChangeTicketDiscount'		  AND @PermissionType & @ChangeTicketDiscountFilter          = @ChangeTicketDiscountFilter)
	     OR (PermissionName = 'ChangeTicketAddition'		  AND @PermissionType & @ChangeTicketAdditionFilter          = @ChangeTicketAdditionFilter)
	     OR (PermissionName = 'ChangeTicketItemDiscount'	  AND @PermissionType & @ChangeItemDiscountFilter            = @ChangeItemDiscountFilter)
	     OR (PermissionName = 'ChangeTicketItemAddition'      AND @PermissionType & @ChangeItemAdditionFilter            = @ChangeItemAdditionFilter)
	     OR (PermissionName = 'ChagneUnit'				      AND @PermissionType & @ChangeItemUnitFilter                = @ChangeItemUnitFilter)
		 OR (PermissionName = 'ChangeWholePrice'			  AND @PermissionType & @ChangeItemPriceFilter               = @ChangeItemPriceFilter)
		 OR (PermissionName = 'ChangeHalfPrice'				  AND @PermissionType & @ChangeItemPriceFilter               = @ChangeItemPriceFilter)
		 OR (PermissionName = 'ChangeVendorPrice'			  AND @PermissionType & @ChangeItemPriceFilter               = @ChangeItemPriceFilter)
		 OR (PermissionName = 'ChangeExportPrice'			  AND @PermissionType & @ChangeItemPriceFilter               = @ChangeItemPriceFilter)
		 OR (PermissionName = 'ChangeRetailPrice'			  AND @PermissionType & @ChangeItemPriceFilter               = @ChangeItemPriceFilter)
		 OR (PermissionName = 'ChangeEndUserPrice'			  AND @PermissionType & @ChangeItemPriceFilter               = @ChangeItemPriceFilter)
		 OR (PermissionName = 'ChangeManualPrice'			  AND @PermissionType & @ChangeItemPriceFilter               = @ChangeItemPriceFilter)
	     OR (PermissionName = 'AddDeliveryValue'			  AND @PermissionType & @AddDeliveryValueFilter              = @AddDeliveryValueFilter)
		 OR (PermissionName = 'CancelDeliveryOrder'           AND @PermissionType & @CancelDeliveryOrderFilter           = @CancelDeliveryOrderFilter)
	     OR (PermissionName = 'CancelOrderFromOrderTab'       AND @PermissionType & @CancelOrderFromOrderTabFilter       = @CancelOrderFromOrderTabFilter)
	     OR (PermissionName = 'CancelOrderFromSearchCustPage' AND @PermissionType & @CancelOrderFromSearchCustPageFilter = @CancelOrderFromSearchCustPageFilter) )
	  

--============================ STATIONS
	SELECT * 
	INTO #StationResult
	FROM POSSDStation000 
	WHERE [GUID] = @StationGuid OR @StationGuid = 0x0

--============================ SHIFTS
	SELECT * 
	INTO #ShiftResult
	FROM POSSDShift000
	WHERE [GUID] = @ShiftGuid OR @ShiftGuid = 0x0 

--============================ GROUPS
	SELECT GR.*
	INTO #GroupResult
	FROM gr000 GR 
	INNER JOIN [dbo].[fnGetGroupsListByLevel](@GroupGuid, 0) GRFn ON GR.[GUID] = GRFn.[GUID]


--=========================================== TICKET PERMISSIONS
	INSERT INTO #TicketDiscountAddition
	SELECT
		DiscAndAdd.TicketGuid, 
		SUM(DiscAndAdd.ItemShareOfTotalDiscount) AS IDiscVal,
		SUM(DiscAndAdd.ItemShareOfTotalAddition) AS IExtrVal,
		SUM(DiscAndAdd.ValueToDiscount) AS TotalDiscount,
		SUM(DiscAndAdd.ValueToAdd) AS TotalAddition,
		SUM(TI.Value) AS TotalValue
	FROM 
		POSSDTicketItem000 TI 
		CROSS APPLY fnPOSSD_Ticket_GetDiscountAndAddition (TI.TicketGUID) DiscAndAdd
	GROUP BY 
		DiscAndAdd.TicketGuid

	INSERT INTO #Result
	SELECT 
		OP.SupervisorGUID						AS SupervisorGuid,
		OP.EmployeeGUID							AS EmployeeGuid,
		T.[GUID]								AS TicketGuid,
		0x0										AS OrderGuid,
		0x0										AS MaterialGuid,
		ISNULL(CU.[GUID], 0x0)					AS CustomerGuid,
		S.[GUID]								AS StationGuid,
		T.[Type]								AS Operation,
		CASE T.OrderType WHEN 0 THEN (CASE T.[Type] WHEN 2 THEN 2 ELSE 1 END) 
						 ELSE 3 END AS [Type],
		''										AS PermissionStr,
		T.OrderType								AS OperationType,
		T.Number								AS OperationNumber,
		SH.Code									AS ShfitCode,
		S.Name									AS StationName,
		Employee.Name							AS EmployeeName,
		Supervisor.Name							AS SupervisorName,
		OP.PermissionName						AS PermissionName,
		CU.CustomerName							AS CustomerName,
		CAST(OP.CreatedOnDateTime AS DATE)		AS [Date],
		CAST(OP.CreatedOnDateTime AS TIME(0))	AS [Time],
		CASE WHEN op.[PermissionName] = 'ChangeTicketDiscount' THEN (DISCADD.IDiscVal / (DISCADD.TotalValue - DISCADD.TotalDiscount) * 100)
			 WHEN op.[PermissionName] = 'ChangeTicketAddition' THEN (DISCADD.IExtrVal / (DISCADD.TotalValue + DISCADD.TotalAddition) * 100)
			 ELSE 0
		END AS [Percentage],

		CASE WHEN op.[PermissionName] = 'ChangeTicketDiscount' THEN DISCADD.IDiscVal
			 WHEN op.[PermissionName] = 'ChangeTicketAddition' THEN DISCADD.IExtrVal
			 ELSE 0
		END AS [Value],
		0  AS price,
		'' AS Unit,
		'' AS PriceName,
		'' AS [Group],
		'' AS Material
	FROM 
		#OperationPermissionResult OP
		INNER JOIN POSSDTicket000 T					ON OP.RecordGUID	  = T.[GUID]
		INNER JOIN #TicketDiscountAddition DISCADD	ON DISCADD.TicketGuid = T.[GUID]
		INNER JOIN #ShiftResult SH					ON T.ShiftGUID		  = SH.[GUID]
		INNER JOIN #StationResult S					ON SH.StationGUID	  = S.[GUID]
		INNER JOIN POSSDEmployee000 Employee		ON OP.EmployeeGUID	  = Employee.[GUID]
		INNER JOIN POSSDEmployee000 Supervisor		ON OP.SupervisorGUID  = Supervisor.[GUID]
		LEFT  JOIN cu000 CU							ON T.CustomerGUID	  = CU.[GUID]
	WHERE
	   (((T.[Type] = 0 AND T.OrderType = 0) AND @OperationType & @SalesOperationFilter    = @SalesOperationFilter)
	 OR ((T.[Type] = 2 AND T.OrderType = 0) AND @OperationType & @ReSalesOperationFilter  = @ReSalesOperationFilter)
	 OR	( T.OrderType = 2 AND @OperationType & @DeliveryOperationFilter = @DeliveryOperationFilter)
	 OR ( T.OrderType = 1 AND @OperationType & @PickupOperationFilter   = @PickupOperationFilter))

	AND((op.[PermissionName] != 'ChangeTicketDiscount')
	    OR(op.[PermissionName] = 'ChangeTicketDiscount' AND DISCADD.IDiscVal !=0))

--=========================================== TICKET ITEM PERMISSIONS
	INSERT INTO #Result
	SELECT
	OP.SupervisorGUID							AS SupervisorGuid,
		OP.EmployeeGUID							AS EmployeeGuid,
		T.[GUID]								AS TicketGuid,
		0x0										AS OrderGuid,
		TI.MatGUID								AS MaterialGuid,
		ISNULL(CU.[GUID], 0x0)					AS CustomerGuid,
		S.[GUID]								AS StationGuid,
		T.[Type]								AS Operation,
		CASE T.OrderType WHEN 0 THEN (CASE T.[Type] WHEN 2 THEN 2 ELSE 1 END) 
						 ELSE 3 END AS [Type],
		''										AS PermissionStr,
		T.OrderType							    AS OperationType,
		T.Number							    AS OperationNumber,
		SH.Code								    AS ShfitCode,
		S.Name                                  AS StationName,
		Employee.Name						    AS EmployeeName,
		Supervisor.Name					        AS SupervisorName,
		OP.PermissionName					    AS PermissionName,
		CU.CustomerName						    AS CustomerName,
		CAST(OP.CreatedOnDateTime AS DATE)      AS [Date],
		CAST(OP.CreatedOnDateTime AS TIME(0))   AS [Time],
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
										  'ChangeManualPrice') THEN TI.[Price] ELSE 0 END  AS Price,
		CASE op.[PermissionName] WHEN 'ChagneUnit' THEN TI.[UnitName] ELSE '' END          AS Unit	,
		''		AS PriceName,
		GR.Name AS [Group],
		MT.Name AS Material
	FROM 
		#OperationPermissionResult OP
		INNER JOIN vwPOSSDTicketItems TI		ON OP.RecordGUID     = TI.ItemGuid
		INNER JOIN POSSDTicket000 T				ON TI.TicketGUID     = T.[GUID]
		INNER JOIN #ShiftResult SH				ON T.ShiftGUID		 = SH.[GUID]
		INNER JOIN #StationResult S				ON SH.StationGUID	 = S.[GUID]
		INNER JOIN POSSDEmployee000 Employee	ON OP.EmployeeGUID	 = Employee.[GUID]
		INNER JOIN POSSDEmployee000 Supervisor	ON OP.SupervisorGUID = Supervisor.[GUID]
		INNER JOIN mt000 MT						ON TI.MatGUID		 = MT.[GUID]
		INNER JOIN #GroupResult GR				ON MT.GroupGUID		 = GR.[GUID]
		LEFT  JOIN cu000 CU						ON T.CustomerGUID	 = CU.[GUID]
	WHERE
		(TI.MatGUID = @MaterialGuid OR @MaterialGuid = 0x0)
	AND(((T.[Type] = 0 AND T.OrderType = 0) AND @OperationType & @SalesOperationFilter   = @SalesOperationFilter)
	  OR((T.[Type] = 2 AND T.OrderType = 0) AND @OperationType & @ReSalesOperationFilter = @ReSalesOperationFilter)
	  OR( T.OrderType = 2 AND @OperationType & @DeliveryOperationFilter = @DeliveryOperationFilter)
	  OR( T.OrderType = 1 AND @OperationType & @PickupOperationFilter   = @PickupOperationFilter))

	  AND((op.[PermissionName] != 'ChangeTicketItemDiscount')
	     OR(op.[PermissionName] = 'ChangeTicketItemDiscount' AND ti.[ItemDiscountValue] !=0))

--=========================================== ORDERS
	INSERT INTO #Result
	SELECT 
		OP.SupervisorGUID						AS SupervisorGuid,
		OP.EmployeeGUID							AS EmployeeGuid,
		T.[GUID]								AS TicketGuid,
		OI.[GUID]								AS OrderGuid,
		0x0										AS MaterialGuid,
		ISNULL(CU.[GUID], 0x0)					AS CustomerGuid,
		S.[GUID]								AS StationGuid,
		T.[Type]							    AS Operation,
		3									    AS [Type],
		''										AS PermissionStr,
		T.OrderType								AS OperationType,
		T.Number								AS OperationNumber,
		SH.Code									AS ShfitCode,
		S.Name									AS StationName,
		Employee.Name							AS EmployeeName,
		Supervisor.Name							AS SupervisorName,
		OP.PermissionName						AS PermissionName,
		CU.CustomerName							AS CustomerName,
		CAST(OP.CreatedOnDateTime AS DATE)		AS [Date],
		CAST(OP.CreatedOnDateTime AS TIME(0))	AS [Time],
		0										AS [Percentage],
		CASE WHEN op.[PermissionName] = 'AddDeliveryValue' THEN OI.DeliveryFee 
			 ELSE 0 
			 END AS [Value],
		0  AS price,
		'' AS Unit,
		'' AS PriceName,
		'' AS [Group],
		'' AS Material
	FROM 
		#OperationPermissionResult OP
		INNER JOIN POSSDTicketOrderInfo000 OI	ON OP.RecordGUID     = OI.[GUID]
		INNER JOIN POSSDTicket000 T				ON OI.TicketGUID     = T.[GUID]
		INNER JOIN #ShiftResult SH				ON T.ShiftGUID		 = SH.[GUID]
		INNER JOIN #StationResult S				ON SH.StationGUID    = S.[GUID]
		INNER JOIN POSSDEmployee000 Employee	ON OP.EmployeeGUID	 = Employee.[GUID]
		INNER JOIN POSSDEmployee000 Supervisor	ON OP.SupervisorGUID = Supervisor.[GUID]
		LEFT  JOIN cu000 CU						ON T.CustomerGUID	 = CU.[GUID]
	WHERE
		( T.OrderType = 2 AND @OperationType & @DeliveryOperationFilter = @DeliveryOperationFilter)
	 OR ( T.OrderType = 1 AND @OperationType & @PickupOperationFilter   = @PickupOperationFilter)

--================== R E S U L T ==================
	SELECT * FROM #Result ORDER BY OperationNumber
#################################################################
#END
