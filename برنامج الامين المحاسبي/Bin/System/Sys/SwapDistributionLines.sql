######################################################
CREATE PROCEDURE SwapDistributionLines
	@Dist1 UNIQUEIDENTIFIER,
	@Dist2 UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	DECLARE 
		@Dist1CustomersAccGuid UNIQUEIDENTIFIER,
		@Dist2CustomersAccGuid UNIQUEIDENTIFIER
	SELECT @Dist1CustomersAccGuid = CustomersAccGuid from Distributor000 where Guid = @Dist1
	SELECT @Dist2CustomersAccGuid = CustomersAccGuid from Distributor000 where Guid = @Dist2
	-- SWAP DISTRIBUTION LINES
	SELECT [GUID] INTO #Temp FROM DistDistributionLines000 WHERE DistGuid = @Dist2
	
	UPDATE DistDistributionLines000
	SET		DistGuid = @Dist2
	WHERE	DistGuid = @Dist1
	
	UPDATE DistDistributionLines000
	SET		DistGuid = @Dist1
	WHERE	GUID IN(SELECT GUID FROM #temp)
	
	-- SWAP COMPOSIT ACCOUNTS
	DELETE #Temp
	
	INSERT INTO #Temp SELECT SonGuid From ci000
	WHERE ParentGuid = @Dist2CustomersAccGuid

	UPDATE ci000
	SET		parentGuid = @Dist2CustomersAccGuid
	WHERE	ParentGuid = @Dist1CustomersAccGuid
	
	UPDATE ci000
	SET		parentGuid = @Dist1CustomersAccGuid
	WHERE	SonGUID IN (SELECT GUID FROM #Temp)
######################################################
#END