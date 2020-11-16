##########################################################################
CREATE PROCEDURE prcDistInitOrdersStatementOfDistributor
		@DistributorGUID uniqueidentifier 
AS      
	SET NOCOUNT ON      
	DECLARE @SalesManGUID			uniqueidentifier, 
			@CostGUID 				uniqueidentifier, 
			@StartDate 				DateTime,  
			@ExportFlag			BIT
			
	SELECT 
			@SalesManGUID 		= [PrimSalesManGUID], 
			@StartDate			= GETDATE() - [ExportOrdersReportDays],
			@ExportFlag			= [ExportOrdersReportFlag]
	FROM 
		[Distributor000] 
	WHERE 
		[GUID] = @DistributorGUID
		
	SELECT @CostGUID = [CostGUID] FROM [vwDistSalesMan] WHERE [GUID] = @SalesManGUID 
	

	DELETE FROM DistDeviceOrderStatement000 WHERE DistributorGuid = @DistributorGuid
	
	IF @ExportFlag = 0
		RETURN

	INSERT INTO DistDeviceOrderStatement000 (GUID, DistributorGUID, OrderGUID, CustGUID, TypeAbbrev, TypeLatinAbbrev, OrderNumber, Date, OrderState, NetTotalPrice, RequiredQty, AchievedQty, RemainingQty, RequiredBonusQty, AchievedBonusQty)
	SELECT
		NEWID(),
		@DistributorGUID,
		OrderGuid,
		OrderCustGuid,
		BtAbbrev,
		BtLatinAbbrev,
		OrderNumber,
		OrderDate,
		( CASE 
			WHEN ( orderInfo.Finished = 1 ) THEN 1 -- FINISHED 
			ELSE ( CASE
						WHEN orderInfo.Add1 = 1 THEN 2 -- CANCELLED 
						ELSE 0 -- ACTIVE 
					END )
			END ),
		SUM(NetItemTotalPrice),
		SUM(Required),
		SUM(Achieved),
		SUM(Required) - SUM(Achieved),
		SUM(RequiredBonus),
		SUM(AchievedBonus)
	FROM 
		fnGetOrderPostDetails(DEFAULT) orderPostDetails
		INNER JOIN ORADDINFO000 orderInfo ON orderInfo.ParentGuid = orderPostDetails.OrderGuid
		INNER JOIN DistDeviceCu000 AS [ddCu] ON [ddCu].[cuGUID] = orderPostDetails.OrderCustGuid AND [ddCu].DistributorGuid = @DistributorGUID 
	WHERE 
		OrderCostGuid = @CostGUID
		AND BtType = 5 -- Order sell 
		AND OrderDate > @StartDate
	GROUP BY 
		OrderGuid,
		OrderDate,
		BtAbbrev,
		BtLatinAbbrev,
		OrderNumber,
		OrderCustGuid,
		Finished,
		Add1
	ORDER BY
		OrderNumber DESC
##########################################################################
##END