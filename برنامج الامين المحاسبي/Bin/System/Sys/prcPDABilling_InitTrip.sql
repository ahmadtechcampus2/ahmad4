#################################################################
CREATE PROCEDURE prcPDABilling_InitTrip
	@PDAGUID UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 

	DECLARE @MaxTrNumber	INT 
	SELECT @MaxTrNumber = MAX(Number) FROM DistTr000 
	SET @MaxTrNumber = ISNULL(@MaxTrNumber, 0) + 1  

	DELETE DistDeviceTr000 WHERE DistributorGuid = @PDAGUID 

	INSERT INTO DistDeviceTr000 
	( 
		Number,  
		[GUID], 
		DistributorGuid, 
		Date, 
		VanGuid, 
		VisitReq, 
		[State] 
	) 
	VALUES 
	( 
		@MaxTrNumber, 
		newID(), 
		@PDAGUID, 
		GetDate(), 
		0x00, 
		0, 
		0 
	) 
 
	INSERT INTO DistTr000  
	( 
		Number,  
		[GUID], 
		DistributorGuid, 
		Date, 
		VanGuid, 
		VisitReq, 
		[State] 
	) 
	SELECT  
		Number,  
		[GUID], 
		DistributorGuid, 
		Date, 
		VanGuid, 
		VisitReq, 
		[State] 
	FROM  
		DistDeviceTr000 
	WHERE  
		DistributorGuid = @PDAGUID 


/*
EXEC prcPDABilling_InitTrip '2C8484AA-EF78-4629-92BF-44731488B3BD'
SELECT * FROM DistTr000 Where DistributorGuid = '2C8484AA-EF78-4629-92BF-44731488B3BD'
*/
#################################################################
#END