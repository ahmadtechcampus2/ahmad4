##################################################################################
CREATE VIEW vwPPOrderBiItems
AS 
SELECT 
	[PPOI].*,
	[BiMt].*,
		CASE [BiMt].[biUnity] 
			WHEN 2 THEN [BiMt].[mtUnit2Fact]
			WHEN 3 THEN [BiMt].[mtUnit3Fact]  
			ELSE [BiMt].[mtUnitFact] 
		END AS [biUnitFact], 
		CASE [PPOI].ppoIsNotAvailableQuantity 
			WHEN 1 THEN [PPOI].[ppiQuantity] 
			ELSE [bimt].[biQty] 
		END AS [Quantity]
FROM 
	[vwPPOrderItems] AS [PPOI] 
	INNER JOIN [vwExtended_bi] AS [BiMt] ON [BiMt].[biGuid] = [PPOI].[ppiSOIGUID]
##################################################################################
CREATE VIEW vwOrders 
AS
	SELECT 
		buType   	AS BtGuid,
		buGuid   	AS Guid,
		--buType   	AS BtGuid,
		CAST(buNumber AS NVARCHAR(255))	AS BuNumber,
		buNotes  	AS BuNotes,
		btName   	AS BtName,
		btLatinName AS BtLatinName,
		btType		AS BtType,
		buSecurity  AS Security,
		buCust_Name AS CustomerName
	FROM
		vwBu
	WHERE 
		btType IN (5, 6)
##################################################################################
CREATE VIEW vwSalesOrders
AS 
 SELECT  SalesOrders.Guid, 
	     SalesOrders.BtGuid, 
	     SalesOrders.BuNumber,
	     SalesOrders.BuNotes,
		 SalesOrders.BtName, 
		 SalesOrders.BtType,
		 SalesOrders.Security,
		 SalesOrders.CustomerName 
 FROM  vwOrders SalesOrders 
			INNER JOIN orAddInfo000 OrderInfo ON OrderInfo.ParentGuid = SalesOrders.Guid 
     WHERE SalesOrders.BtType = 5 
	     AND	
			 OrderInfo.Finished = 0 
	    AND 
			OrderInfo.Add1 = 0
##################################################################################
CREATE VIEW vwOrderBuBiPosted
AS	
	SELECT DISTINCT [ori].POGUID AS orderGuid,
					[order].btName AS orderName,
					[order].btLatinName AS orderLatinName,
					[ori].buGUID AS orderPostedBillGuid,
					[order].buNumber AS orderNumber,
					[order].btType AS orderType,
					[ori].BiGuid AS orderPostedBiGuid
    FROM ori000 [ori] 
    INNER JOIN vwExtended_bi [billPosted] ON [billPosted].buGUID =  [ori].buGUID
    LEFT JOIN vwExtended_bi [order] ON [order].buGUID = [ori].POGUID
##################################################################################
CREATE VIEW vwOrderBuPosted
AS	
	SELECT DISTINCT [ori].POGUID AS orderGuid,
					[order].btName AS orderName,
					[order].btLatinName AS orderLatinName,
					[ori].buGUID AS orderPostedBillGuid,
					[order].buNumber AS orderNumber,
					[order].btType AS orderType
    FROM ori000 [ori] 
    INNER JOIN vwExtended_bi [billPosted] ON [billPosted].buGUID =  [ori].buGUID
    LEFT JOIN vwExtended_bi [order] ON [order].buGUID = [ori].POGUID
##################################################################################
#END
