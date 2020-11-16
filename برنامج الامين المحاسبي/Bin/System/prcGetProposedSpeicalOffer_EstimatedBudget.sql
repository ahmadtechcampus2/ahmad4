###############################################################################
CREATE PROCEDURE prcGetProposedSpeicalOffer_EstimatedBudget(
	@DATE DATETIME, -- Bill date 
	@BillTypeGuid UNIQUEIDENTIFIER, -- Bill type guid 
	@AccountGuid UNIQUEIDENTIFIER = 0x0, -- Bill account guid
	@CostGuid UNIQUEIDENTIFIER = 0x0, -- Bill Cost guid
	@CustomerGuid UNIQUEIDENTIFIER)
AS 
	SET NOCOUNT ON
	
	CREATE TABLE #Result(
		SpecialOfferGuid UNIQUEIDENTIFIER,
		SpecialOfferName NVARCHAR(255) COLLATE ARABIC_CI_AI,
		SpeicalOfferCode NVARCHAR(255) COLLATE ARABIC_CI_AI,
		ItemGuid UNIQUEIDENTIFIER,
		PeriodGuid UNIQUEIDENTIFIER,
		Budget FLOAT,
		Applied FLOAT,
		SpeicalOfferCustCondGuid UNIQUEIDENTIFIER)	
		
	INSERT INTO #Result	
	SELECT
		so.GUID,
		so.Name,
		so.Code,
		sop.GUID,
		sop.PeriodGuid,
		sop.Budget,
		ISNULL((SELECT SUM(discount) FROM bi000 WHERE SOGuid = sop.[GUID]), 0),
		so.CustCondGUID
	FROM
		SpecialOffers000 so
		INNER JOIN SOPeriodBudgetItem000 sop ON sop.SpecialOfferGUID = so.GUID
		INNER JOIN bdp000 pr ON pr.[GUID] = sop.PeriodGuid
	WHERE
		so.[Type] = 4 -- SO_ESTIMATED_BUDGET
		AND
		(so.IsAllBillTypes = 1 OR EXISTS(SELECT * FROM SOBillTypes000 WHERE @BillTypeGuid = BillTypeGuid AND SpecialOfferGUID = so.[GUID]))
		AND
		so.IsActive = 1
		AND
		@DATE BETWEEN pr.StartDate AND pr.EndDate
		AND
		(@AccountGuid = 0x0 OR (@AccountGuid = so.AccountGUID OR EXISTS(SELECT * FROM [dbo].[fnGetAccountParents](@AccountGuid) WHERE [GUID] = so.AccountGUID)))
		AND
		(@CostGuid = 0x0  OR (@CostGuid = so.CostGUID OR EXISTS(SELECT * FROM [dbo].[fnGetCostParents](@CostGuid) WHERE [GUID] = so.CostGUID)))
	ORDER BY
		so.Number,
		sop.Number
		
	DECLARE 
		@soCursor CURSOR,
		@soGUID UNIQUEIDENTIFIER,
		@soCustCondGuid UNIQUEIDENTIFIER,
		@verfied BIT,
		@soFoundGuid UNIQUEIDENTIFIER
	
	SET @soFoundGuid = 0x0
	SET @soCursor = CURSOR FAST_FORWARD FOR 
					SELECT 
						SpecialOfferGuid, 
						SpeicalOfferCustCondGuid 
					FROM 
						#Result
					WHERE 
						SpeicalOfferCustCondGuid <> 0x0


	IF EXISTS(SELECT * FROM #Result WHERE SpeicalOfferCustCondGuid <> 0x0)	
	BEGIN
		OPEN @soCursor
		FETCH NEXT FROM @soCursor INTO @soGUID, @soCustCondGuid

		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @verfied = 1
			
			EXEC @verfied = prcIsCustCondVerified @soCustCondGuid, @CustomerGuid

			IF @verfied = 0
			BEGIN
				DELETE FROM #Result WHERE SpecialOfferGuid = @soGUID
			END
			FETCH NEXT FROM @soCursor INTO @soGUID, @soCustCondGuid
		END
		CLOSE @soCursor
		DEALLOCATE @soCursor
	END

	SELECT * FROM #Result
################################################################################
#END