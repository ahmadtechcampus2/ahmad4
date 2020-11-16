#################################################################
CREATE PROC prcPDABilling_GenVisits
	@PDAGuid	UNIQUEIDENTIFIER 
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
			EntryVisibility 
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
			Vi.EntryVisibility 
	FROM  
		DistDeviceVi000	AS Vi 
	WHERE  
		DistributorGuid = @PDAGuid 
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
			VisitGuid,  
			3,  
			Guid,  
			1 
	FROM  
		DistDeviceBu000 
	WHERE  
		DistributorGuid = @PDAGuid	 
----------------- PaymentsVisits 
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
			VisitGuid,  
			2,  
			Guid,  
			1 
	FROM  
		DistDeviceEn000


	DELETE DistDeviceVi000 WHERE DistributorGuid = @PDAGuid 

#################################################################
#END