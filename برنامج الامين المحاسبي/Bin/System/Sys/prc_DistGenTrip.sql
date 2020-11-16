########################################
## prc_DistGenTrip
CREATE PROC prc_DistGenTrip
	@GUID				uniqueidentifier, 
	@DistributorGUID	uniqueidentifier,
	@NewOrRefresh		int
AS 
	SET NOCOUNT ON 
	DECLARE @Date datetime 
	SET @Date = GetDate() 
	DECLARE @VanGUID uniqueidentifier 
	SELECT @VanGUID = VanGUID FROM Distributor000 WHERE GUID = @DistributorGUID 
	DECLARE @RouteNum int  
	IF EXISTS( SELECT Value FROM op000 WHERE Name = 'DistCfg_Coverage_RouteNum')  
		SELECT @RouteNum = Value FROM op000 WHERE Name = 'DistCfg_Coverage_RouteNum'  
	ELSE  
		SET @RouteNum = 1  
	-- CREATE TABLE #CustomerRouteTbl(GUID uniqueidentifier)
	-- INSERT INTO #CustomerRouteTbl EXEC prcDistGetRouteOfDistributor @DistributorGUID, @RouteNum  
	 
	DECLARE @VisitReq int 
	-- SELECT @VisitReq = Count(*) FROM #CustomerRouteTbl 
	SELECT @VisitReq = VisitPerDay FROM Distributor000 WHERE GUID = @DistributorGUID
	DECLARE @VisitNum int 
	SELECT @VisitNum = ISNULL(Max(Number), 0) + 1 FROM DistTr000 
	if (@NewOrRefresh = 0)
	begin
		INSERT INTO DistTr000 
		SELECT @VisitNum, @GUID, @DistributorGUID, @Date, @VanGUID, @VisitReq, 0 -- 0: Export only
	end
	else
	begin
		UPDATE DistTr000 
			SET [Date] = @Date, VanGUID = @VanGUID, VisitReq = @VisitReq
		WHERE
			GUID = @GUID
	end
#############################
CREATE PROC prc_DistGetCreatedTrip
	@DistGUID uniqueidentifier
AS
	DECLARE @TripGUID uniqueidentifier
	SELECT @TripGUID = GUID FROM DistTr000 WHERE DistributorGUID = @DistGUID AND State = 0
	SET @TripGUID = ISNULL(@TripGUID, 0x0)
	SELECT @TripGUID AS GUID
#############################
CREATE PROC prc_SetTripImported
	@TripGUID uniqueidentifier
AS
	UPDATE DistTr000 SET State = 1 WHERE GUID = @TripGUID AND State = 0
#############################
#END
