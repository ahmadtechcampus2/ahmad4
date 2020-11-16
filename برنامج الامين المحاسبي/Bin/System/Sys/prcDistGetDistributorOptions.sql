####################################################
CREATE PROCEDURE prcDistGetDistributorOptions
	@PalmUserName NVARCHAR(250)
AS
	SET NOCOUNT ON
	DECLARE @lstPrices INT
	SELECT @lstPrices = ObjectNumber 
	FROM DistDD000 AS dd
		INNER JOIN Distributor000 AS d On d.Guid = dd.DistributorGuid
	WHERE	dd.ObjectType = 5 -- Prices
			AND [d].[PalmUserName] = @PalmUserName
	DECLARE @Price1Name NVARCHAR(100),
			@Price2Name NVARCHAR(100),
			@Price3Name NVARCHAR(100),
			@Price4Name NVARCHAR(100),
			@Price5Name NVARCHAR(100),
			@Price6Name NVARCHAR(100)
	SELECT @Price1Name = ISNULL(Asc1, '') FROM mc000 WHERE Type = 8 AND Number = 1095	-- Whole
	SELECT @Price2Name = ISNULL(Asc1, '') FROM mc000 WHERE Type = 8 AND Number = 1096	-- Half
	SELECT @Price3Name = ISNULL(Asc1, '') FROM mc000 WHERE Type = 8 AND Number = 1098   -- Vendor
	SELECT @Price4Name = ISNULL(Asc1, '') FROM mc000 WHERE Type = 8 AND Number = 1099   -- Export
	SELECT @Price5Name = ISNULL(Asc1, '') FROM mc000 WHERE Type = 8 AND Number = 1097   -- Retail
	SELECT @Price6Name = ISNULL(Asc1, '') FROM mc000 WHERE Type = 8 AND Number = 1100   -- EndUser
	SELECT TOP 1
		[d].[Number],
		[d].[Guid],
		[d].[Code],
		[d].[Name],
		ISNULL([d].[LatinName], '')	AS LatinName,
		[d].[DistributorPassword], 
		[d].[SupervisorPassword], 
		[d].[License],
		[d].[StoreGUID], 
		[d].[OrderStoreGuid], 
		[d].[MatSortFld], 
		[d].[CustSortFld], 
		[d].[DefaultPayType], 
		[d].[CanChangePrice], 
		[d].[VisitPerDay],
		[d].[ItemDiscType], 
		[d].[AccessByBarcode], 
		[d].[UseStockOfCust], 
		[d].[UseShelfShare], 
		[d].[UseActivity], 
		[d].[UseCustTarget], 
		[d].[ShowCustInfo], 
		[d].[ShowQuestionnaire],
		[d].[ShowBills],		
		[d].[ShowEntries],
		-- [d].[ShowNoSalesReasons],
		[d].[ShowRequiredMaterials],
		[d].[SpecifyOrder],
		[d].[NoOverTakeMaxDebit],
		[d].[OutNegative], 
		[d].[ShowTodayRoute], 
		[d].[UseCustLastPrice], 
		[d].[CustBarcodeHasValidate], 
		[d].[CanChangeCustBarcode], 
		[d].[ExportSerialNumFlag], 
		[d].[PrintPrice],
		[d].[CheckBillOffers], 
		[d].[CanAddBonus], 
		[d].[AddMatByBarcode], 
		[d].[CanUpdateOffer],
		[d].[CanAddCustomer]				AS CanAddNewCust,
		[d].[ChangeCustCard]				AS CanUpdateCust,
		[d].[AccessByRFID]					AS AccessByRFID,
		[d].[IgnoreNoDetailsVisits]			AS IgnoreEmptyVisit,
		[d].[OutRouteVisitsNumber]			AS VisitsOutOfRoute,
		[d].[CanUpdateBill],
		[d].[CanDeleteBill],
		[d].[ExportDetailedCustAcc],
		[d].[EndVisitByBarcode],
		CASE [d].[ResetDaily] WHEN 1 THEN 0 ELSE [d].[LastBuNumber] END AS LastBuNumber,
		CASE [d].[ResetDaily] WHEN 1 THEN 0 ELSE [d].[LastEnNumber] END AS LastEnNumber,
		[d].[UploadPassword],
		[d].[ResetDaily],
		ISNULL([o].BillTypeGuid, 0x0)		AS OrderBtGuid,
		ISNULL([o].TransferTypeGuid, 0x0)	AS OrderTsGuid,
		ISNULL([o].MaxStoreBalance, 0)		AS OrderMaxBalance,
		CASE ISNULL([o].PriceType, 0)	WHEN 4		THEN 1		-- Whole Price		«·Ã„·… 
										WHEN 8		THEN 2		-- Half Price		‰’› «·Ã„·… 
										WHEN 16		THEN 3		-- Export Price		«· ’œÌ— 
										WHEN 32		THEN 4		-- Vendor Price		«·„Ê“⁄ 
										WHEN 64		THEN 5		-- Retail Price		«·„›—ﬁ 
										WHEN 128	THEN 6		-- EndUser Price	«·„” Â·ﬂ 
										ELSE 1
		END AS OrderPriceType,
		ISNULL([o].AutoGenOrder, 0)			AS OrderAutoGen,
		ISNULL([o].CanUpdateOrder, 0)		AS OrderCanUpdate,
		ISNULL(@Price1Name, '')				AS Price1Name,
		ISNULL(@Price2Name, '')				AS Price2Name,
		ISNULL(@Price3Name, '')				AS Price3Name,
		ISNULL(@Price4Name, '')				AS Price4Name,
		ISNULL(@Price5Name, '')				AS Price5Name,
		ISNULL(@Price6Name, '')				AS Price6Name,
		ISNULL(@lstPrices, 1)				AS lstPrices,
		GetDate()							AS SyncDate,
        dbo.fnDistGetRouteNumOfDate(GetDate()) AS SyncNumOfDate,
        dbo.fnOption_GetInt('DistCfg_Coverage_RouteCount', '7') AS CoverageRouteCount,
		[d].UseCustomerPrice,
		[d].HideEmptyMatInEntryBills,
		[d].CanUseGPRS,
		[d].VerificationStore,
		[d].GPRSTransferType,
		[d].AverageVisitPeriod,
		[d].ShowNearbyCustomersOnly,
		[d].NewCustomerDefaultPrice,
		[d].UserGuid,
		[d].LastSalesNumber,
		[d].LastReturnNumber,
		[d].AutoNewCustToRoute,
		[d].ExportOrdersReportFlag AS  ExportOrdersStatementFlag
	FROM  
		[Distributor000] AS d
		LEFT JOIN DistOrders000 AS o ON o.DistGuid = d.Guid
	WHERE 
		[d].[PalmUserName] = @PalmUserName
-----------------------------------------------------------------------------------------------------------------------------------------------

/*
EXEC prcDistGetDistributorOptions 'Tarek' 
Select * From Distributor000
*/
####################################################
#END