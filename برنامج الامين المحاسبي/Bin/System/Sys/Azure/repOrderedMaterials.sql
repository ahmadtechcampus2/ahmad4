###############################################################################
CREATE PROCEDURE repOrderedMaterials
	@OrderGuid		[UNIQUEIDENTIFIER] = 0x0, 
	@MatGuid		[UNIQUEIDENTIFIER] = 0x0, 
	@GroupGuid		[UNIQUEIDENTIFIER] = 0x0, 
	@StoreGuid		[UNIQUEIDENTIFIER] = 0x0, 
	@SrcTypesguid   [UNIQUEIDENTIFIER] = 0x0, 
	@FromDate   	[DATETIME] = '2009-1-1',  
	@ToDate     	[DATETIME] = '2010-10-31' 
AS 
	SET NOCOUNT ON  
	--------------------------------------------------------------  
/*  
ÊÍÏíÏ ãÌãæÚÇÊ ÇáãæÇÏ ÇáÊí ÊÊã ÇáÝáÊÑÉ ÚáíåÇ
*/  

	SELECT * 
	INTO #Groups 
	FROM fnGetGroupsList(@GroupGuid)
	--------------------------------------------------------------  
/*  
ÊÍÏíÏ ÇÓã ÇáÝÆÉ 
*/  
	DECLARE @ClassName NVARCHAR (255)   
	SET @ClassName = (select notes from bu000 where guid = @OrderGuid)   
	--------------------------------------------------------------  
/*  
ÇáÍÕæá Úáì ÌÏæá Ýíå ÇáãæÇÏ ÇáãØáæÈÉ + ãÚáæãÇÊ Úä ÇáØáÈíÉ ãËá ÇáßãíÉ ÇáãØáæÈÉ  
æ åÐÇ ÇáÌÏæá åæ ÇáÌÏæá ÇáÃÓÇÓí ÇáÐí ÓíÊæáÏ ãäå ÌÏæá Çá  
TMP  
æ ÈÇáÊÇáí ÈÇÞí ÇáÌÏÇæá  
*/  
	SELECT BI.MatGuid,BI.ClassPtr, SUM(BI.Qty) AS QTY   
		INTO #OrderedMats 		   
			FROM BI000 BI  
		    INNER JOIN BU000 BU ON BU.GUID = BI.PARENTGUID  
		    INNER JOIN BT000 BT ON BT.GUID = BU.TYPEGUID  
		WHERE ( @OrderGuid = 0x0 OR BU.GUID = @OrderGuid )  
			  AND BT.TYPE IN (5, 6)  
			  AND BU.DATE >= @FromDate  
			  AND BU.DATE <= @ToDate  
		GROUP BY BI.MatGuid,BI.ClassPtr  
	--------------------------------------------------------------  
/*  
ÅäÔÇÁ ÌÏæá  
TMP  
ÇáÐí åæ ÊÝßíß ááãæÇÏ ÇáãæÌæÏÉ Ýí ÇáÌÏæá ÇáÓÇÈÞ  
æ ÇáÊÝßíß åäÇ íÔãá ÇáãæÇÏ ÇáÃæáíÉ æ äÕÝ ÇáãÕäÚÉ ÈÔßá ÔÌÑí   
+   
ÇáßãíÉ ÇáãØáæÈÉ ãä ßá ãä åÐå ÇáãæÇÏ áÊÛØíÉ ÇáßãíÉ ÇáãØáæÈÉ Ýí ÇáØáÈíÉ  
*/  
	--IF EXISTS ( SELECT * FROM tempdb..sysobjects WHERE name = '#TMP')   
	--	DROP TABLE #TMP  
	CREATE TABLE #TMP  
                  (   
						[selectedGUID]                     [UNIQUEIDENTIFIER],   
                        [GUID]                     [UNIQUEIDENTIFIER],   
                        [PARENTGUID]         [UNIQUEIDENTIFIER],  
						[ClassPtr]           NVARCHAR (255) COLLATE ARABIC_CI_AI,  
						[FORMNAME]           NVARCHAR (255) COLLATE ARABIC_CI_AI,  
                        [MATGUID]            [UNIQUEIDENTIFIER],   
						[MATNAME]           NVARCHAR (255) COLLATE ARABIC_CI_AI,   
                        [QTY]                [FLOAT]                ,   
                        [QtyInForm]                [FLOAT]                ,   
                        [PATH]                   [NVARCHAR](1000)  ,   
						[Unit]			[INT],	   
                        [IsSemiReadyMat]   [INT],  
                  )   
	Declare @OrderedMatGuid UNIQUEIDENTIFIER   
	Declare @OrderedMatQty INT    
	Declare @OrderedClassPtr NVARCHAR (255) 
	Declare SellCur Cursor   FORWARD_ONLY FOR    
    Select   
    	MatGuid 
		,Qty  
		,ClassPtr 
	FROM #OrderedMats  
	OPEN SellCur  
		FETCH NEXT FROM SellCur INTO   
			@OrderedMatGuid 
			,@OrderedMatQty  
			,@OrderedClassPtr 
		WHILE @@FETCH_STATUS = 0  
    		BEGIN  
				INSERT INTO #TMP   
					EXEC prcGetManufacMaterialTree @OrderedMatGuid, @OrderedClassPtr, '' 
				UPDATE #TMP SET Qty = Qty * @OrderedMatQty 
				FETCH NEXT FROM SellCur INTO   
					@OrderedMatGuid 
					,@OrderedMatQty  
					,@OrderedClassPtr 
			END  
	CLOSE SellCur   
	DEALLOCATE SellCur  
	--------------------------------------------------------------   
	SELECT *  
	INTO #TMP2  
	FROM #TMP 
	DELETE FROM #TMP 
	INSERT INTO #TMP 
	SELECT NULL, NULL, NULL, '', '', MatGuid, MatName, SUM(Qty) Qty, 0, '', 0, 0 
	FROM #TMP2 
	GROUP BY MatGuid, MatName 
	--------------------------------------------------------------  
/*  
åäÇ äÍÓÈ ÇáßãíÉ ÇáãÕÑæÝÉ ááãæÇÏ  
*/  
	SELECT BI.MatGuid, SUM( CASE BT.BILLTYPE WHEN 0 THEN -BI.QTY WHEN 3 THEN -BI.QTY WHEN 4 THEN -BI.QTY WHEN 1 THEN BI.QTY WHEN 2 THEN BI.QTY WHEN 5 THEN BI.QTY END) AS QtyHasBeenGiven  
	INTO #QtyHasBeenGiven  
		FROM  BI000 BI  
		INNER JOIN BU000 BU ON BI.ParentGuid = BU.GUID  
		INNER JOIN BT000 BT ON BU.TypeGUID = BT.GUID  
        INNER JOIN [RepSrcs] RS ON RS.[IDTYPE] = BU.[TYPEGUID]      
		INNER JOIN #TMP TMP ON TMP.MatGuid = BI.MatGuid  
		WHERE	Bu.Date >= @FromDate   
				AND BU.Date <= @ToDate  
				AND [rs].IdTbl = @SrcTypesguid  
				AND BU.isposted = 1 -- ÍÕÑÇ ÇáÝæÇÊíÑ ÇáãÑÍáÉ  
				AND (@OrderGuid = 0x0 OR BI.ClassPtr = @ClassName) -- ÝÞØ Þáã ÇáÝÇÊæÑÉ ááÝÆÉ ÇáãÍÏÏÉ  
		GROUP BY BI.MatGuid  
	--------------------------------------------------------------  
/*  
åäÇ äÍÓÈ ÇáãÎÒæä  
*/  
	SELECT BI.MatGuid, SUM( CASE BT.BILLTYPE WHEN 0 THEN BI.QTY WHEN 3 THEN BI.QTY WHEN 4 THEN BI.QTY WHEN 1 THEN -BI.QTY WHEN 2 THEN -BI.QTY WHEN 5 THEN -BI.QTY END) AS QtyInStore  
	INTO #QtyInStore  
		FROM  BI000 BI  
		INNER JOIN BU000 BU ON BI.ParentGuid = BU.GUID  
		INNER JOIN BT000 BT ON BU.TypeGUID = BT.GUID  
		INNER JOIN #TMP TMP ON TMP.MatGuid = BI.MatGuid  
		WHERE BU.isposted = 1 -- ÍÕÑÇ ÇáÝæÇÊíÑ ÇáãÑÍáÉ  
			  AND ( @StoreGuid = 0x0 OR  BI.StoreGUID = @StoreGuid OR ( BU.StoreGUID = 0x0 AND BU.StoreGUID = @StoreGuid ) )   
			  AND BU.Date <= @ToDate  
			  AND (@OrderGuid = 0x0 OR BI.ClassPtr = @ClassName) -- ÝÞØ Þáã ÇáÝÇÊæÑÉ ááÝÆÉ ÇáãÍÏÏÉ  
		GROUP BY BI.MatGuid  

SELECT TMP.MatName, TMP.ClassPtr, TMP.Qty Qty, ISNULL( QtyHasBeenGiven.QtyHasBeenGiven, 0) + ISNULL( QtyInStore.QtyInStore , 0) TotalOrdered , QtyHasBeenGiven.QtyHasBeenGiven QtyHasBeenGiven, QtyInStore.QtyInStore  QtyInStore, TMP.Qty  - ( ISNULL( QtyHasBeenGiven.QtyHasBeenGiven , 0) + ISNULL( QtyInStore.QtyInStore , 0) ) NotOrderedQty   
FROM #TMP TMP 
	INNER JOIN MT000 MT ON MT.Guid = TMP.MatGuid 
	LEFT JOIN #QtyHasBeenGiven QtyHasBeenGiven ON QtyHasBeenGiven.MatGuid = TMP.MatGUID   
	LEFT JOIN #QtyInStore QtyInStore ON QtyInStore.MatGUID = TMP.MatGUID 
WHERE (TMP.MatGuid = @MatGuid OR @MatGuid = '00000000-0000-0000-0000-000000000000')
	  AND (MT.GroupGuid IN ( SELECT * FROM #Groups ) OR @GroupGuid = '00000000-0000-0000-0000-000000000000')
	
################################################################################
#END