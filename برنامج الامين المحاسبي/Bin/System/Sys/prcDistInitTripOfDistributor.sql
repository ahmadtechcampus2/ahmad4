####################################################
######## prcDistInitTripOfDistributor
CREATE PROC prcDistInitTripOfDistributor
	@DistGuid	UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	DECLARE @VanGuid		UNIQUEIDENTIFIER,
			@VisitReq   	INT,
			@MaxTrNumber	INT

	SELECT 
		@VanGuid = ISNULL(VanGuid, 0x00), 
		@VisitReq = ISNULL(VisitPerDay, 0) 
	FROM 
		vwDistributor
	WHERE 
		Guid = @DistGuid 
	
	SELECT @MaxTrNumber = MAX(Number) FROM DistTr000
	SET @MaxTrNumber = ISNULL(@MaxTrNumber, 0) + 1 

	INSERT INTO DistDeviceTr000
	(
		Number, 
		GUID,
		DistributorGuid,
		Date,
		VanGuid,
		VisitReq,
		State
	)
	VALUES
	(
		@MaxTrNumber,
		newID(),
		@DistGuid,
		GetDate(),
		@VanGuid,
		@VisitReq,
		0
	)


	INSERT INTO DistTr000 SELECT * FROM DistDeviceTr000

####################################################
#END
