################################################################################
CREATE PROC prcNSCheckMatMonitoringNotificationConditions
	@notificationGuid UNIQUEIDENTIFIER,
	@objectGuid UNIQUEIDENTIFIER
AS
BEGIN 

		DECLARE @MatGroup	 UNIQUEIDENTIFIER
		DECLARE @MatGuid	 UNIQUEIDENTIFIER


		DECLARE @MatCondition UNIQUEIDENTIFIER
		SELECT 	@MatGroup = MaterialGroupGuid,@MatGuid = MaterialGuid, @MatCondition = MaterialConditionGuid 
								 FROM NSMatMonitoringCondition000
								 WHERE NotificationGuid = @notificationGuid
	    

		DECLARE @Table TABLE (MatGuid UNIQUEIDENTIFIER, [Security] INT)
		INSERT INTO @Table EXEC [prcGetMatsList]  NULL, @MatGroup,-1,@MatCondition  

		IF EXISTS(SELECT *
		FROM mt000 mt INNER JOIN @Table M ON M.MatGuid = mt.[GUID]
		AND M.MatGuid = CASE @MatGuid WHEN 0x0 THEN M.MatGuid ELSE @MatGuid END
		AND mt.[GUID] = @objectGuid)
			BEGIN
				RETURN 1
			END
		ELSE
			BEGIN
				RETURN 0
			END
END
################################################################################
CREATE FUNCTION fnNSCheckMatMonitoringEventCondtions(
	@eventConditonGuid UNIQUEIDENTIFIER,
	@objectGuid UNIQUEIDENTIFIER)
RETURNS BIT AS
BEGIN 
	DECLARE @QtyType		INT
	DECLARE @LimitType		INT
	DECLARE @SpecificQty	FLOAT
	DECLARE @MatQty			FLOAT
	DECLARE @PreviousQty	FLOAT
	DECLARE @MaxQty			FLOAT
	DECLARE @MinQty			FLOAT
	DECLARE @ReorderPoint	FLOAT

	SELECT @PreviousQty = PrevQty, @MatQty = Qty, @MaxQty = High, @MinQty = Low, @ReorderPoint = OrderLimit
	FROM mt000 mt 
	WHERE [GUID] = @objectGuid

	SET @PreviousQty = @PreviousQty - (	SELECT TOP 1 SUM(bi.Qty) 
										FROM bi000 AS bi
											INNER JOIN bu000 AS bu ON bi.ParentGUID = bu.[GUID]
										WHERE MatGUID = @objectGuid AND bu.IsPosted = 1
										GROUP BY bi.ParentGUID
										ORDER BY max(bu.Date) DESC)


	SELECT @QtyType = QtyType, @SpecificQty = SpecificQuantity, @LimitType = LimitType
	FROM NSMatMonitoringEventCondition000
	WHERE EventConditionGuid = @eventConditonGuid

	----------------------------1-«·Õœ «·√⁄·Ï
	IF(@QtyType & 1 = 1)
	BEGIN
		IF(@MaxQty = 0)
		BEGIN
			RETURN 0
		END
		IF(@MatQty > @MaxQty AND @PreviousQty <= @MaxQty)
		BEGIN
			RETURN 1
		END
	END
	----------------------------2-«·Õœ «·√œ‰Ï
	IF(@QtyType & 2 = 2)
	BEGIN
		IF(@MinQty = 0)
		BEGIN
			RETURN 0
		END
		IF(@MatQty < @MinQty AND @PreviousQty >= @MinQty)
		BEGIN
			RETURN 1
		END
	END
	----------------------------4-‰ﬁÿ… ≈⁄«œ… «·ÿ·»
	IF(@QtyType & 4 = 4)
	BEGIN
		IF(@ReorderPoint = 0)
		BEGIN
			RETURN 0
		END
		IF(@MatQty < @ReorderPoint AND @PreviousQty >= @ReorderPoint)
		BEGIN
			RETURN 1
		END
	END
	----------------------------8-ﬂ„Ì… „⁄Ì‰…
	IF(@QtyType & 8 = 8)
	BEGIN

		IF((@LimitType = 0) AND (@MatQty < @SpecificQty) AND (@PreviousQty >= @SpecificQty))
		BEGIN
			RETURN 1
		END

		IF((@LimitType = 1) AND (@MatQty > @SpecificQty) AND (@PreviousQty <= @SpecificQty))
		BEGIN
			RETURN 1
		END

	END
	RETURN 0
END
################################################################################
#END
		