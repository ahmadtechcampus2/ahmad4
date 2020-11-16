#########################################################################
CREATE PROCEDURE CalculateOrdersDelays
	@UserGUID UNIQUEIDENTIFIER
	,@DateToCalculateAt DATETIME
	,@PartiallyPosted BIT = 0
	,@NeverPostedFrom BIT = 0
AS
BEGIN
	
	EXECUTE prcNotSupportedInAzureYet
	/*
	SET NOCOUNT ON;

	DECLARE @FromDate AS DATE = '2014-01-01' -- بداية المدة
	SELECT @FromDate = Value FROM op000 WHERE Name = 'AmnCfg_FPDate'
	DECLARE @ODPCCount AS INT
	DECLARE @PartiallyPostedValue AS BIT
	DECLARE @NeverPostedFromValue AS BIT
	DECLARE @IsAdmin AS BIT
	SELECT 
		@ODPCCount = Count([GUID])
	FROM 
		OrdersDelaysPanelCustomization000 
	WHERE 
		UserGUID = @UserGUID
	
	IF (@ODPCCount <> 0) AND (@PartiallyPosted = 0) AND (@NeverPostedFrom = 0)
	BEGIN
		--GET SETTING
		SELECT 
			@PartiallyPostedValue = PartiallyPosted 
			,@NeverPostedFromValue = NeverPostedFrom
		FROM 
			OrdersDelaysPanelCustomization000 
		WHERE 
			UserGUID = @UserGUID
	END
	ELSE
	BEGIN
		-- USE DEFAULT SETTINGS
		SELECT 
			@PartiallyPostedValue = @PartiallyPosted
			,@NeverPostedFromValue = @NeverPostedFrom
	END

	SET @IsAdmin = dbo.fnIsAdmin(@UserGuid)

	SELECT
		xyz.OrderGUID
		,xyz.StateGUID
		,xyz.MaterialGUID
		, xyz.btName + ' - ' + CONVERT(NVARCHAR(250),vBu.buNumber) AS OrderName
		,Max(DaysDelayed) As DelayDays
		--, xyz.QtyOfOrderItem --Debug purpose
		--, xyz.QtyPostedFromState --Debug purpose
		--, xyz.QtyPostedToState --Debug purpose
		--TODO: يوجد حالة خاصة قد تكون لم تعالج بعد وهي عند تساوي المرحل من الحالة مع المرحل إليها بقيمة أكبر من صفر
		,(CASE WHEN (xyz.QtyPostedFromState > 0) AND (xyz.QtyPostedToState > 0)
				THEN xyz.QtyPostedToState - xyz.QtyPostedFromState 
				ELSE 
					(
						CASE WHEN (xyz.QtyPostedFromState = 0) AND (xyz.QtyPostedToState = 0)
						THEN xyz.QtyOfOrderItem
						ELSE
							(CASE WHEN xyz.QtyPostedFromState > 0
							THEN 
								xyz.QtyOfOrderItem - xyz.QtyPostedFromState
							ELSE
								xyz.QtyPostedToState
							END)
						END
					)
				END) AS LateQty
		, (CASE WHEN xyz.QtyPostedFromState > 0 THEN 1 ELSE 0 END) AS ParitallyPosted
		, (CASE WHEN (xyz.QtyPostedFromState = 0) THEN 1 ELSE 0 END) AS NeverPostedFrom 
	INTO 
		#Delays
	FROM
	(	
		SELECT 
			oit.[Guid] StateGUID,
			oit.Name,
			ots.OrderGUID,
			vbi.biMatPtr AS MaterialGUID,
			vBt.btName,
			dlst.[Date],
			(CASE WHEN (dlst.[Date] > OTSI.EndDate) THEN ABS(DATEDIFF(d, dlst.[Date], otsi.EndDate)) ELSE 0 END) DaysDelayed,
			ISNULL((SELECT SUM(ABS(qty)) FROM ori000 ori where ori.number = 0 and ori.POGUID = ots.OrderGUID AND ori.POIGUID = ori1.POIGUID ), 0) As QtyOfOrderItem
			,ISNULL((SELECT SUM(ABS(qty)) FROM ori000 ori where ori.qty < 0 and ori.number <> 0 and ori.POGUID = ots.OrderGUID and ori.POIGuid = ori1.POIGUID and ori.TypeGuid = otsi.StateGUID and ori.[Date] <= @DateToCalculateAt), 0) As QtyPostedFromState
			,ISNULL((SELECT SUM(ABS(qty)) FROM ori000 ori where ori.qty > 0 and ori.number <> 0 and ori.POGUID = ots.OrderGUID and ori.POIGuid = ori1.POIGUID and ori.TypeGuid = otsi.StateGUID and ori.[Date] <= @DateToCalculateAt), 0) As QtyPostedToState
			-- ,(select Permission from ui000 where UserGUID = @UserGUID and SubId = vBt.btGUID and PermType = 1) AS Permission -- Debug purpose
		FROM
			oit000 oit
			INNER JOIN OrderTimeScheduleItems000 otsi ON oit.[GUID] = otsi.StateGUID
			INNER JOIN OrderTimeSchedule000 ots ON ots.[GUID] = otsi.OTSParent
			INNER JOIN ORI000 ori1 ON ori1.[POGUID] = ots.OrderGUID
			INNER JOIN vwExtended_bi vbi ON (vbi.buGuid = ots.OrderGUID) AND (vbi.biGUID = ori1.POIGuid)
			INNER JOIN vwBt vBt ON vBt.btGUID = ots.OrderTypeGUID
			INNER JOIN 
			(
				SELECT DATEADD(d, number, @fromDate) AS [date]
				FROM master..spt_values WHERE [type] = 'P' AND DATEADD(d, number, @fromDate) <= @DateToCalculateAt
			) dlst ON dlst.[Date] <= @DateToCalculateAt 
		WHERE 
			(CASE WHEN (dlst.[Date] > OTSI.EndDate) THEN ABS(DateDiff(d, dlst.[Date], otsi.EndDate)) ELSE 0 END) > 0
			AND
			((@IsAdmin = 0) AND (vbi.buSecurity <= (select Permission from ui000 where UserGUID = @UserGUID and SubId = vBt.btGUID and PermType = 1))
			OR
			@IsAdmin = 1
			)
			
	) xyz 
		INNER JOIN vwBu vBu ON vBu.buGuid = xyz.OrderGUID
	GROUP BY
		xyz.OrderGUID
		,xyz.StateGUID
		,xyz.MaterialGUID
		,xyz.btName + ' - ' + CONVERT(NVARCHAR(250),vBu.buNumber)
		--,xyz.QtyOfOrderItem --Debug purpose
		--, xyz.QtyPostedFromState --Debug purpose
		--, xyz.QtyPostedToState --Debug purpose
		,(CASE WHEN (xyz.QtyPostedFromState > 0) AND (xyz.QtyPostedToState > 0)
				THEN xyz.QtyPostedToState - xyz.QtyPostedFromState 
				ELSE 
					(
						CASE WHEN (xyz.QtyPostedFromState = 0) AND (xyz.QtyPostedToState = 0)
						THEN xyz.QtyOfOrderItem
						ELSE
							(CASE WHEN xyz.QtyPostedFromState > 0
							THEN 
								xyz.QtyOfOrderItem - xyz.QtyPostedFromState
							ELSE
								xyz.QtyPostedToState
							END)
						END
					)
				END)
		, (CASE WHEN xyz.QtyPostedFromState > 0 THEN 1 ELSE 0 END) 
		, (CASE WHEN (xyz.QtyPostedFromState = 0) THEN 1 ELSE 0 END)
	HAVING
		(((CASE WHEN xyz.QtyPostedFromState > 0 THEN 1 ELSE 0 END) =  @PartiallyPostedValue) AND (@PartiallyPostedValue = 1))
		OR
		(((CASE WHEN (xyz.QtyPostedFromState = 0) THEN 1 ELSE 0 END) = @NeverPostedFromValue) AND (@NeverPostedFromValue = 1))

	SELECT 
		* 
	INTO
		#PREVIOUSDELAYS
	FROM 
		OrdersStatesDelays000
	WHERE 
		UserGUID = @UserGUID
		AND
		PartiallyPosted = @PartiallyPostedValue
		AND
		NeverPostedFrom = @NeverPostedFromValue

	DELETE 
	FROM 
		OrdersStatesDelays000 
	WHERE 
		UserGUID = @UserGUID 
	
	INSERT INTO
		OrdersStatesDelays000
	SELECT 
		NEWID() AS [GUID],
		d.OrderGUID AS OrderGUID,
		@UserGUID AS UserGUID,
		d.StateGUID,
		d.DelayDays,
		d.MaterialGUID,
		d.LateQty AS DelayQuantity,
		GETDATE() AS DateCreated,
		ISNULL(CASE WHEN (d.OrderGUID = ps.OrderGUID) AND (d.MaterialGUID = ps.MaterialGUID) AND (d.StateGUID = ps.StateGUID) THEN 1 ELSE 0 END, 0) AS IsUpdated,
		d.ParitallyPosted,
		d.NeverPostedFrom
	FROM
		#Delays d
		LEFT JOIN #PREVIOUSDELAYS ps ON (d.OrderGUID = ps.OrderGUID) AND (d.MaterialGUID = ps.MaterialGUID) AND (d.StateGUID = ps.StateGUID) AND (ps.UserGUID = @UserGUID)
	WHERE
		d.LateQty > 0

	-- إجراء الاحتساب لمعرفة الطلبيات التي تأخرت عن تاريخ التسليم المتفق عليه بحيث لا تكون ملغية أو منتهية
	SELECT 
		POGUID AS OrderGUID
		, SUM(QTY) AS DelayQuantity
	INTO
		#UnpostedTotally
	FROM 
		ORI000
	WHERE 
		BuGuid = 0x00
	GROUP BY
		POGUID
	HAVING 
		SUM(QTY) > 0

	SELECT 
		vbu.buGUID AS OrderGUID
		,DateDiff(d, oinfo.ADDate, @DateToCalculateAt) AS DelayDays
		,ut.DelayQuantity
	INTO 
		#ORDERSDELAYS
	FROM
		vwBu vbu
		INNER JOIN ORADDINFO000 oinfo ON oinfo.ParentGUID = vbu.buGUID
		RIGHT JOIN #UnpostedTotally ut ON ut.OrderGUID = vbu.buGUID
	WHERE
		(oinfo.Add1 <> 1)
		AND 
		(oinfo.Finished <> 1)
		AND
		DateDiff(d, oinfo.ADDate, @DateToCalculateAt) > 0
		
	INSERT INTO 
		OrdersStatesDelays000 
	SELECT  
		NEWID() AS [GUID], 
		od.OrderGUID AS OrderGUID, 
		@UserGUID AS UserGUID, 
		CAST(0x00 AS UNIQUEIDENTIFIER) AS StateGUID, 
		od.DelayDays AS DelayDays, 
		CAST(0x00 AS UNIQUEIDENTIFIER) AS MaterialGUID, 
		od.DelayQuantity AS DelayQuantity, 
		GETDATE() AS DateCreated,
		ISNULL(CASE WHEN (od.OrderGUID = ps.OrderGUID) THEN 1 ELSE 0 END, 0) AS IsUpdated, 
		0 AS ParitallyPosted, 
		0 AS NeverPostedFrom 
	 FROM 
		#ORDERSDELAYS od
		LEFT JOIN #PREVIOUSDELAYS ps ON (od.OrderGUID = ps.OrderGUID)
*/
END

#########################################################################
#END