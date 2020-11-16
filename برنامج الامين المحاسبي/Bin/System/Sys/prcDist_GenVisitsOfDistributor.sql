#################################################################
CREATE PROC prcDist_GenVisitsOFDistributor
	@DistGuid	UNIQUEIDENTIFIER
AS 
SET NOCOUNT ON 
	 
	DECLARE @MaxViNum INT 
	SELECT @MaxViNum = Max(Number) FROM DistVi000 
	SET @MaxViNum = ISNULL(@MaxViNum, 0)  + 1 
----------------- Visits 
	INSERT INTO DistVi000 
		(	 
			Number,  
			Guid,  
			TripGuid,  
			CustomerGuid,  
			StartTime,  
			FinishTime,  
			State,  
			EntryStockOfCust,  
			EntryVisibility, 
			UseCustBarcode,
			UseCustGPS
		) 
	SELECT 
			Vi.Number + @MaxViNum,  
			Vi.Guid,  
			Vi.TripGuid,  
			Vi.CustomerGuid,  
			Vi.StartTime,  
			Vi.FinishTime,  
			Vi.State,  
			Vi.EntryStockOfCust,  
			Vi.EntryVisibility, 
			ISNULL(UseCustBarcode, 0),
			ISNULL(UseCustGPS, 0)  
	FROM  
		DistDeviceVi000	AS Vi 
	WHERE  
		DistributorGuid = @DistGuid 
----------------- BillVisits 
	INSERT INTO DistVd000   
		(  
			Guid,   
			VistGuid,   
			Type,   
			ObjectGuid,   
			Flag  
		)  
	SELECT   
			newID(),   
			bu.VisitGuid,   
			3,   
			bu.Guid,   
			1  
	FROM   
		DistDeviceBu000 AS bu 
		LEFT JOIN DistVd000 AS vd ON vd.ObjectGuid = bu.Guid 
	WHERE   
		DistributorGuid = @DistGuid	  
		AND vd.Guid IS NULL 
----------------- Payments 
	INSERT INTO DistVd000   
		(  
			Guid,   
			VistGuid,   
			Type,   
			ObjectGuid,   
			Flag  
		)  
	SELECT   
			newID(),   
			en.VisitGuid,   
			2,   
			en.Guid,   
			1  
	FROM   
		DistDeviceEn000 AS en 
		LEFT JOIN DistVd000 AS vd ON vd.ObjectGuid = en.Guid 
	WHERE   
		DistributorGuid = @DistGuid	  
		AND vd.Guid IS NULL 
-----------------  
	DELETE DistDeviceVi000 WHERE DistributorGuid = @DistGuid 
	-- DELETE DistDeviceUnSales000 WHERE DistributorGuid = @DistGuid 
#################################################################
CREATE PROC prcDist_GenAll
AS       
	SET NOCOUNT ON  
	
	DECLARE @DistGuid	UNIQUEIDENTIFIER,
			@C			CURSOR

	SET @C = CURSOR FAST_FORWARD FOR  SELECT Guid FROM Distributor000 WHERE IsSync = 0
	OPEN @C FETCH NEXT FROM @C INTO @DistGuid
	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC prcDist_GenVisitsOFDistributor		@DistGuid
		EXEC prcDist_UpdateCustsOFDistributor	@DistGuid
		EXEC prcDistPostCustomerAddresses		@DistGuid
		EXEC prcDist_GenBillOFDestributor		@DistGuid
		EXEC prcDist_GenPaymentOFDestributor	@DistGuid
		FETCH NEXT FROM @C INTO @DistGuid
	END
	CLOSE @C DEALLOCATE @C
#################################################################
#END
