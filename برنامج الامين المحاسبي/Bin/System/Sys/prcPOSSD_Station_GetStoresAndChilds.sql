################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetStoresAndChilds
-- Params -------------------------------   
	@StationGuid		UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------

	DECLARE @NULLABLEGUID UNIQUEIDENTIFIER
	SET @NULLABLEGUID = 0x0

	SELECT
		SS.Number					AS Number,
		SS.StoreGUID				AS StoreGUID,
		ST.Code						AS Code,
		ST.Name						AS StoreName,
		St.LatinName				AS StoreLatinName,
		@NULLABLEGUID			    AS MainStoreGUID

	INTO #POSSMainStores
	FROM 
		POSSDStationStores000 SS
		INNER JOIN st000 ST ON ST.GUID = SS.StoreGUID
	WHERE
		SS.StationGUID = @StationGuid
	
	
	SELECT 
		 ST.Number, 
		 ST.GUID AS StoreGUID, 
		 ST.Code, 
		 ST.Name AS StoreName,
		 ST.LatinName AS StoreLatinName, 
		 POSSST.StoreGUID AS MainStoreGUID
	INTO #POSSSubStores
	FROM 
		POSSDStationStores000 POSSST 
		CROSS APPLY [dbo].[fnGetStoresList](POSSST.StoreGUID) fnGS 
		INNER JOIN st000 ST ON st.GUID = fnGS.GUID
	WHERE  
		POSSST.StoreGUID <> st.GUID AND POSSST.StationGUID = @StationGuid
	GROUP BY 
		ST.GUID, ST.Number, ST.Code,  ST.Name, ST.LatinName, POSSST.StationGUID, POSSST.StoreGUID


	CREATE TABLE #RESULT
	(
		Number			 INT,
		StoreGUID		 UNIQUEIDENTIFIER, 
		Code			 NVARCHAR(250),
		StoreName		 NVARCHAR(250),
		StoreLatinName   NVARCHAR(250),
		MainStoreGUID    UNIQUEIDENTIFIER,
		InPOSSInvStores	 Bit
	)

	INSERT INTO #RESULT 
	SELECT *, 1 FROM #POSSMainStores

	UPDATE
		res
	SET
		res.MainStoreGUID   = SS.MainStoreGUID
	FROM
		#RESULT AS res
		INNER JOIN #POSSSubStores AS SS ON res.StoreGUID = SS.StoreGUID
	WHERE
		res.InPOSSInvStores = 1
	
	INSERT INTO #RESULT
	SELECT 
		SS.Number, SS.StoreGUID, SS.Code, SS.StoreName, SS.StoreLatinName, SS.MainStoreGUID, 0
	FROM 
		#POSSSubStores SS
		LEFT JOIN #RESULT res on res.StoreGUID = SS.StoreGUID
	WHERE res.StoreGUID IS NULL

	SELECT * FROM #RESULT ORDER BY Number
#################################################################
#END
