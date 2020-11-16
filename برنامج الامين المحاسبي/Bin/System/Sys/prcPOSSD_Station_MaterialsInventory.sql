################################################################################
CREATE PROCEDURE prcPOSSD_Station_MaterialsInventory
		@StationGUID UNIQUEIDENTIFIER
AS
BEGIN
	
	CREATE TABLE #MaterialInventory ( MaterialGuid UNIQUEIDENTIFIER,
									  StoreGuid	   UNIQUEIDENTIFIER,
									  Qty		   FLOAT )


	CREATE TABLE #InventoryResult ( MaterialGuid  UNIQUEIDENTIFIER,
									StoreGuid	  UNIQUEIDENTIFIER,
									Qty			  FLOAT )

--================================= INVENTORY GROUP
    SELECT
		 fn.[GUID]
	INTO #Group
    FROM 
		POSSDStationGroup000 SG
        CROSS APPLY [dbo].[fnGetGroupsOfGroup](SG.GroupGUID) fn
    WHERE
        SG.StationGUID = @StationGUID
	GROUP BY
		fn.[GUID]

--================================= MATERIALS FROM COLLECTIVE GROUPS
    SELECT
		 fn.mtGUID AS MaterialGUID,
		 G.[GUID] AS CollectiveGroupGIUD,
		 mt.GroupGUID as GroupGUID
	INTO #CollectiveGroupsMaterials
    FROM 
		#Group G
        CROSS APPLY [dbo].[fnGetMatsOfCollectiveGrps](G.[GUID]) fn
		INNER JOIN gr000 GR ON G.[GUID] = GR.[GUID] AND GR.Kind = 1
		INNER JOIN mt000 mt on MT.GUID = fn.mtGUID 
		WHERE MT.GroupGUID NOT IN (SELECT [GUID] FROM #Group)


--================================= INVENTORY STORE
    SELECT
		 fnGS.[GUID]
	INTO #Store
    FROM 
		POSSDStationStores000 SS
        CROSS APPLY [dbo].[fnGetStoresList](SS.StoreGUID) fnGS
    WHERE
        SS.StationGUID = @StationGUID
	GROUP BY
		fnGS.[GUID]

--================================= STATIONS STORE
----------- STATIONS SALE BILL TYPE STORE
	SELECT 
		S.[GUID] AS StationGuid, 
		BT.DefStoreGUID AS [GUID]
	INTO #StationSaleBillTypeStore
	FROM 
		POSSDStation000 S 
		INNER JOIN POSSDShift000 SH ON SH.StationGUID = S.[GUID] AND SH.CloseDate IS NULL
		INNER JOIN bt000 BT ON  S.SaleBillTypeGUID =  BT.[GUID]


	SELECT 
		SaleStore.stationGuid
	INTO #SaleStation
	FROM 
		#Store S 
		LEFT JOIN #StationSaleBillTypeStore SaleStore ON S.[GUID] = SaleStore.[GUID]
	WHERE 
		SaleStore.stationGuid  IS NOT NULL
	GROUP BY 
		SaleStore.stationGuid


	INSERT INTO #MaterialInventory
	SELECT 
		MT.[GUID] AS MaterialGuid,
		fnGS.StoreGuid AS StoreGuid,
		-SUM(CASE TI.UnitType + 1 WHEN 2 THEN TI.Qty * MT.Unit2Fact 
                                  WHEN 3 THEN TI.Qty * MT.Unit3Fact
                                  ELSE TI.Qty END) AS Qty
		
	FROM 
		#SaleStation S
		CROSS APPLY [dbo].[fnPOSSD_Station_GetStore](S.StationGuid, 0) fnGS
		INNER JOIN POSSDShift000 SH ON S.stationGuid = SH.StationGUID AND SH.CloseDate IS NULL
		INNER JOIN POSSDTicket000 T ON T.ShiftGUID = SH.[GUID] AND T.[Type] = 0 AND T.[State] = 0
		INNER JOIN POSSDTicketItem000 TI ON TI.TicketGUID = T.[GUID] 
		INNER JOIN mt000 MT ON TI.MatGUID = MT.[GUID]
		INNER JOIN #Group G ON MT.GroupGUID = G.[GUID] 
	GROUP BY
		MT.[GUID],
		fnGS.StoreGuid

	-------- materials from collective groups
	INSERT INTO #MaterialInventory
	SELECT 
		MT.[GUID] AS MaterialGuid,
		fnGS.StoreGuid AS StoreGuid,
		-SUM(CASE TI.UnitType + 1 WHEN 2 THEN TI.Qty * MT.Unit2Fact 
                                  WHEN 3 THEN TI.Qty * MT.Unit3Fact
                                  ELSE TI.Qty END) AS Qty
		
	FROM 
		#SaleStation S
		CROSS APPLY [dbo].[fnPOSSD_Station_GetStore](S.StationGuid, 0) fnGS
		INNER JOIN POSSDShift000 SH ON S.stationGuid = SH.StationGUID AND SH.CloseDate IS NULL
		INNER JOIN POSSDTicket000 T ON T.ShiftGUID = SH.[GUID] AND T.[Type] = 0 AND T.[State] = 0
		INNER JOIN POSSDTicketItem000 TI ON TI.TicketGUID = T.[GUID] 
		inner join #CollectiveGroupsMaterials CGM on CGM.MaterialGUID = TI.MatGUID
		INNER JOIN mt000 MT ON CGM.MaterialGUID = MT.[GUID]
		INNER JOIN #Group G ON CGM.CollectiveGroupGIUD = G.[GUID] 
	GROUP BY
		MT.[GUID],
		fnGS.StoreGuid
		

----------- STATIONS RETURN SALE BILL TYPE STORE
	SELECT 
		S.[GUID] AS StationGuid, 
		BT.DefStoreGUID AS [GUID]
	INTO #StationReSaleBillTypeStore
	FROM 
		POSSDStation000 S 
		INNER JOIN POSSDShift000 SH ON SH.StationGUID = S.[GUID] AND SH.CloseDate IS NULL
		INNER JOIN bt000 BT ON  S.SaleReturnBillTypeGUID =  BT.[GUID]
		
	SELECT 
		ReSaleStore.StationGuid 
	INTO #ReSaleStation
	FROM 
		#Store s 
		LEFT JOIN #StationReSaleBillTypeStore ReSaleStore ON S.[GUID] = ReSaleStore.[GUID]
	WHERE 
		ReSaleStore .stationGuid  IS NOT NULL
	GROUP BY 
		ReSaleStore .stationGuid 

	INSERT INTO #MaterialInventory
	SELECT 
		MT.[GUID] AS MaterialGuid,
		fnGS.StoreGuid AS StoreGuid,
		SUM(CASE TI.UnitType + 1 WHEN 2 THEN TI.Qty * MT.Unit2Fact 
                                 WHEN 3 THEN TI.Qty * MT.Unit3Fact
                                 ELSE TI.Qty END) AS Qty
	FROM 
		#ReSaleStation S 
		CROSS APPLY [dbo].[fnPOSSD_Station_GetStore](S.StationGuid, 2) fnGS
		INNER JOIN POSSDShift000 SH ON S.stationGuid = sh.StationGUID AND SH.CloseDate IS NULL
		INNER JOIN POSSDTicket000 T ON T.ShiftGUID = SH.[GUID] AND T.[Type] = 2 AND T.[State] = 0
		INNER JOIN POSSDTicketItem000 TI ON TI.TicketGUID = T.[GUID]
		INNER JOIN mt000 MT ON TI.MatGUID = MT.[GUID]
		INNER JOIN #Group G ON MT.GroupGUID = G.[GUID]
	GROUP BY
		MT.[GUID],
		fnGS.StoreGuid

	-------- materials from collective groups
	INSERT INTO #MaterialInventory
	SELECT 
		MT.[GUID] AS MaterialGuid,
		fnGS.StoreGuid AS StoreGuid,
		SUM(CASE TI.UnitType + 1 WHEN 2 THEN TI.Qty * MT.Unit2Fact 
                                 WHEN 3 THEN TI.Qty * MT.Unit3Fact
                                 ELSE TI.Qty END) AS Qty
	FROM 
		#ReSaleStation S 
		CROSS APPLY [dbo].[fnPOSSD_Station_GetStore](S.StationGuid, 2) fnGS
		INNER JOIN POSSDShift000 SH ON S.stationGuid = sh.StationGUID AND SH.CloseDate IS NULL
		INNER JOIN POSSDTicket000 T ON T.ShiftGUID = SH.[GUID] AND T.[Type] = 2 AND T.[State] = 0
		INNER JOIN POSSDTicketItem000 TI ON TI.TicketGUID = T.[GUID]
		INNER JOIN #CollectiveGroupsMaterials CGM ON CGM.MaterialGUID = TI.MatGUID
		INNER JOIN mt000 MT ON CGM.MaterialGUID = MT.[GUID]
		INNER JOIN #Group G ON CGM.CollectiveGroupGIUD = G.[GUID]
	GROUP BY
		MT.[GUID],
		fnGS.StoreGuid

----------- ALAMEEN QTY
	INSERT INTO #MaterialInventory
	SELECT 
		MS.MatGUID,
		MS.StoreGUID,
		MS.Qty
	FROM 
		ms000 MS
		INNER JOIN mt000 MT ON MS.MatGUID   = MT.[GUID]
		INNER JOIN #Store S ON MS.StoreGUID =  S.[GUID]
		INNER JOIN #Group G ON MT.GroupGUID =  G.[GUID] 
	WHERE
		MS.Qty <> 0

	-------- materials from collective groups
	INSERT INTO #MaterialInventory
	SELECT 
		MS.MatGUID,
		MS.StoreGUID,
		MS.Qty
	FROM 
		ms000 MS
		INNER JOIN #CollectiveGroupsMaterials MAT ON MS.MatGUID   = MAT.MaterialGUID
		INNER JOIN #Store S ON MS.StoreGUID =  S.[GUID]
		INNER JOIN #Group G ON MAT.CollectiveGroupGIUD =  G.[GUID] 
	WHERE
		MS.Qty <> 0

--============================= RESULT

	INSERT INTO #InventoryResult
	SELECT 
		MaterialGuid, 
		StoreGuid, 
		SUM(Qty) AS Qty
	FROM 
		#MaterialInventory 
	GROUP BY 
		MaterialGuid, 
		StoreGuid


	SELECT
		NEWID() AS [Guid],
		IR.MaterialGuid AS MatGUID,
		MT.Parent AS MatParent,
		IR.StoreGuid AS StoreGUID,
		MT.Name AS MatName,
		MT.LatinName AS MatLatinName,
		CASE mt.DefUnit WHEN 1 THEN mt.Unity
						WHEN 2 THEN mt.Unit2
						WHEN 3 THEN mt.Unit3
						ELSE mt.Unity END AS DefUnit,
		CASE MT.DefUnit
            WHEN 1 THEN IR.Qty
            WHEN 2 THEN IR.Qty / (CASE MT.Unit2Fact WHEN 0 THEN 1 ELSE MT.Unit2Fact END)
            WHEN 3 THEN IR.Qty / (CASE MT.Unit3Fact WHEN 0 THEN 1 ELSE MT.Unit3Fact END)
            END  AS DefQty,       
        MT.Unity AS Unit1, 
		IR.Qty                  AS QtyUnit1,
        MT.Unit2 AS Unit2, 
		IR.Qty / (CASE MT.Unit2Fact WHEN 0 THEN 1 ELSE MT.Unit2Fact END) AS QtyUnit2,
        MT.Unit3 AS Unit3, 
		IR.Qty / (CASE MT.Unit3Fact WHEN 0 THEN 1 ELSE MT.Unit3Fact END) AS QtyUnit3,
		GR.[GUID] AS GroupGUID, 
		GR.Name AS GroupName, 
		GR.LatinName AS GroupLatinName,
		ST.Name AS StoreName,
		ST.LatinName AS StoreLatinName

	FROM 
		#InventoryResult IR
		INNER JOIN mt000 MT ON IR.MaterialGuid = MT.[GUID]
		INNER JOIN gr000 GR ON MT.GroupGUID = GR.[GUID]
		INNER JOIN st000 ST ON IR.StoreGuid = ST.[GUID]
		ORDER BY ST.Code, IR.Qty DESC 
END
#################################################################
CREATE FUNCTION fnPOSSD_Station_GetStore
-- Param ------------------------------------------------
		( @StationGuid		UNIQUEIDENTIFIER,			
		  @BillType		INT )-- 0:Sale - 2:ReturnSale 
-- Return -----------------------------------------------
RETURNS TABLE
---------------------------------------------------------
AS

	RETURN
	SELECT 
		BT.DefStoreGUID AS StoreGuid
	FROM 
		POSSDStation000 S 
		INNER JOIN bt000 BT ON (CASE @BillType WHEN 0 THEN S.SaleBillTypeGUID ELSE S.SaleReturnBillTypeGUID END) = BT.[GUID]
	WHERE
		S.GUID = @StationGuid
#################################################################
#END
