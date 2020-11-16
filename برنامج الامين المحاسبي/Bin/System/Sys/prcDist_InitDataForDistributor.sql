####################################################
CREATE PROC prcDistInitTripOfDistributor
	@DistGuid	UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	DECLARE @VanGuid	UNIQUEIDENTIFIER,
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

	DELETE DistDeviceTr000 WHERE DistributorGuid = @DistGUID
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

	INSERT INTO DistTr000 
	(
		Number, 
		GUID,
		DistributorGuid,
		Date,
		VanGuid,
		VisitReq,
		State
	)
	SELECT 
		Number, 
		GUID,
		DistributorGuid,
		Date,
		VanGuid,
		VisitReq,
		State
	FROM 
		DistDeviceTr000
	WHERE 
		DistributorGuid = @DistGUID
		
####################################################
CREATE PROC prcDist_InitDataForDistributor
		@DistributorGUID uniqueidentifier,
		@UserName	nvarchar(200)
AS
	SET NOCOUNT ON
	
	IF EXISTS (SELECT LoginName From us000 WHERE LoginName = @UserName)
		EXEC prcConnections_Add2 @UserName
	ELSE
	BEGIN
		SELECT TOP 1 @UserName = LoginName From us000 Where bAdmin = 1 
		EXEC prcConnections_Add2 @UserName
	END
	
	EXEC prcDistInitTripOfDistributor				@DistributorGUID 
	EXEC prcDistInitTemplateOfDistributor 			@DistributorGUID
	EXEC prcDistInitCustOfDistributor 				@DistributorGUID
	EXEC prcDistInitCustomerAddresses				@DistributorGUID
	EXEC prcDistInitMatOfDistributor 				@DistributorGUID
	EXEC prcDistInitMatSnOfDistributor 				@DistributorGUID
	EXEC prcDistInitDiscDetailOfDistributor			@DistributorGUID
	EXEC prcDistInitProOfDistributor				@DistributorGUID
	EXEC prcDistInitOffersCondOfDistributor			@DistributorGUID 
	EXEC prcDistInitCustStockOfDistributor			@DistributorGUID
	EXEC prcDistInitCustStatementOfDistributor		@DistributorGUID
	EXEC prcDistInitOrderOfDistributor				@DistributorGUID
	EXEC prcDistInitLastPriceOfDistributor			@DistributorGUID
	EXEC prcDistInitCF_ValueOfDistributor			@DistributorGUID
	EXEC prcDistInitOrdersStatementOfDistributor	@DistributorGUID
####################################################
#END