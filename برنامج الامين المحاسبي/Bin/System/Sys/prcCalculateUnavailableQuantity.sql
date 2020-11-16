##################################################################################
CREATE PROCEDURE prcCalculateUnavailableQuantity 
 	@OrderGuid UNIQUEIDENTIFIER = 0x00,
 	@PPOGuid UNIQUEIDENTIFIER = 0x00,
 	@MaterialGUID UNIQUEIDENTIFIER = 0x00,
 	@CalcNotAvailableQuantityPerStore BIT = 0
 AS 
 	SET NOCOUNT ON
	
	DECLARE @debugMode BIT = 0
	--SET @debugMode = 1 -- uncomment for Debug purpose
 	---------------------    #PreparationSourcesTbl   ------------------------     
   	SELECT [VALUE] AS [Guid] INTO #PreparationSourcesTbl FROM op000 AS o WHERE o.Name LIKE 'AmnOrders_PreparationSources%'
	----------------------------
	IF @debugMode = 1
		SELECT '#PreparationSourcesTbl', * FROM #PreparationSourcesTbl 
	----------------------------
	-----------------------  #PreparedMats  ---------------------------     
	SELECT 
		bi.biMatPtr AS MatGuid,
		CASE WHEN bi.biStorePtr <> 0x0 THEN bi.biStorePtr ELSE bi.buStorePtr END AS StoreGuid
	INTO #PreparedMats 
	FROM ppi000 AS ppi
		INNER JOIN vwExtended_bi AS bi ON ppi.SOIGuid = bi.biGUID 
	WHERE
		ppi.PPOGuid = @PPOGuid
		AND ppi.SOGuid = @OrderGuid
		AND ppi.IsQuantityNotCalculated = 1 -- ·· „ÌÌ“ »Ì‰  «· Õ÷Ì—«  «·ﬁœÌ„… Ê«·Õ«·Ì… ·„Ê«œ «·ÿ·»   	
		AND ((@MaterialGUID = 0x00) OR ((bi.biMatPtr = @MaterialGUID) AND (@MaterialGUID <> 0x00)))
	----------------------------
	IF @debugMode = 1
		SELECT '#PreparedMats', * FROM #PreparedMats 
	--------------------------------------------------------------------
	-----------------------  »«ﬁÏ ÿ·»«  «·»Ì⁄  ---------------------------
	SELECT  
 		ExBi.biMatPtr AS MatGuid,
 		CASE WHEN ExBi.biStorePtr <> 0x00 THEN ExBi.biStorePtr ELSE ExBi.buStorePtr END AS StoreGuid,
 		ExBi.biQty AS OrderedQty,
 		ISNULL ((SELECT SUM(ISNULL(ORI.Qty, 0))
		 FROM ori000 ORI    
		 WHERE
			 ORI.POIGUID = ExBi.biGUID AND ExBi.btType = 5 
			 AND ORI.TypeGuid = (SELECT TOP 1 OIT.Guid FROM oit000 OIT INNER JOIN oitvs000 OITVS ON OIT.Guid = OITVS.ParentGuid WHERE OITVS.OtGuid = ExBi.buType AND OITVS.Selected = 1 ORDER BY OIT.PostQty Desc)  
		), 0)AS AcheivedQty 	
 	INTO #SellMats
 	FROM
 		#PreparedMats MatTbl
 		INNER JOIN vwExtended_bi AS ExBi ON ExBi.biMatPtr = MatTbl.MatGuid    
 		INNER JOIN OrAddInfo000 AS Info ON Info.ParentGuid = ExBi.buGUID
 		INNER JOIN bt000 AS bt ON bt.GUID = ExBi.buType
 	WHERE     
 		(Info.Finished = 0)     
 		AND (Info.Add1 = '0') 		
 		AND ExBi.buGUID <> @OrderGuid 
		AND bt.bNoPrepareCmd = 0
		AND bt.[Type] = 5 
		AND ((@CalcNotAvailableQuantityPerStore = 0) OR ((CASE WHEN ExBi.biStorePtr <> 0x00 THEN ExBi.biStorePtr ELSE ExBi.buStorePtr END) IN (SELECT DISTINCT StoreGuid FROM #PreparedMats) AND (@CalcNotAvailableQuantityPerStore = 1)))
	----------------------------
	IF @debugMode = 1
		SELECT '#SellMats', * FROM #SellMats
	----------------------------
	------------------------------------	
	SELECT 
		SellTbl.MatGuid,
		--SellTbl.StoreGuid,
		SUM(ISNULL(SellTbl.OrderedQty, 0) - ISNULL(SellTbl.AcheivedQty, 0)) AS RemainedQty
	INTO #SellRemained
	FROM  
		#SellMats SellTbl
		INNER JOIN #PreparedMats  MatTbl ON MatTbl.MatGuid = SellTbl.MatGuid 
				AND MatTbl.StoreGuid = (CASE WHEN @CalcNotAvailableQuantityPerStore = 1 THEN SellTbl.StoreGuid ELSE MatTbl.StoreGuid END)
	GROUP BY 
		SellTbl.MatGuid   
	---------------------------------
	IF @debugMode = 1
		SELECT '#SellRemained', * FROM #SellRemained
	---------------------------------
	-----------------------  »«ﬁÏ ÿ·»«  «·‘—«¡  ---------------------------
	SELECT  
		ExBi.biMatPtr AS MatGuid,
		CASE WHEN ExBi.biStorePtr <> 0x00 THEN ExBi.biStorePtr ELSE ExBi.buStorePtr END AS StoreGuid,
		ExBi.biQty AS OrderedQty,
		ISNULL((SELECT SUM(ISNULL(ORI.Qty, 0))
		 FROM ori000 ORI    
		 WHERE
			 ORI.POIGUID = ExBi.biGUID AND ExBi.btType = 6 
			 AND ORI.TypeGuid = (SELECT TOP 1 OIT.Guid FROM oit000 OIT INNER JOIN oitvs000 OITVS ON OIT.Guid = OITVS.ParentGuid WHERE OITVS.OtGuid = ExBi.buType AND OITVS.Selected = 1 ORDER BY OIT.PostQty Desc)  
		), 0) AS AcheivedQty 
 	INTO #PurchaseMats
 	FROM
 		#PreparedMats MatTbl
 		INNER JOIN vwExtended_bi AS ExBi ON ExBi.biMatPtr = MatTbl.MatGuid    
 		INNER JOIN OrAddInfo000 AS Info ON Info.ParentGuid = ExBi.buGUID
 		INNER JOIN #PreparationSourcesTbl PrepSrc ON PrepSrc.[Guid] = ExBi.buType
 	WHERE     
 		(Info.Finished = 0)     
 		AND (Info.Add1 = '0') 		
 		AND ExBi.buGUID <> @OrderGuid  
		AND ((@CalcNotAvailableQuantityPerStore = 0) OR ((CASE WHEN ExBi.biStorePtr <> 0x00 THEN ExBi.biStorePtr ELSE ExBi.buStorePtr END) IN (SELECT DISTINCT StoreGuid FROM #PreparedMats) AND (@CalcNotAvailableQuantityPerStore = 1)))
		AND ((@MaterialGUID = 0x00) OR ((ExBi.biMatPtr = @MaterialGUID) AND (@MaterialGUID <> 0x00)))
 	---------------------------------
	IF @debugMode = 1
		SELECT '#PurchaseMats', * FROM #PurchaseMats
	--------------------------------
	SELECT 
		PurchaseTbl.MatGuid,
		ISNULL(SUM(PurchaseTbl.OrderedQty - PurchaseTbl.AcheivedQty), 0) AS RemainedQty
	INTO #PurchaseRemained
	FROM  
		#PurchaseMats PurchaseTbl
		INNER JOIN #PreparedMats  MatTbl ON MatTbl.MatGuid = PurchaseTbl.MatGuid 
				AND MatTbl.StoreGuid = CASE WHEN @CalcNotAvailableQuantityPerStore = 1 THEN PurchaseTbl.StoreGuid ELSE MatTbl.StoreGuid END 
	GROUP BY 
			PurchaseTbl.MatGuid 	
	------------------------------------------------------------------
	IF @debugMode = 1
		SELECT '#PurchaseRemained', * FROM #PurchaseRemained
	/*===============================================================*     
	 *                       Prepared Quantities                     *     
	 *===============================================================*/
 	SELECT 
		ppi.MatGuid,
 		SUM(ISNULL(ppi.Quantity, 0)) AS Quantity 
 	INTO #Prepared
	FROM	   
		ppi000 ppi 
		INNER JOIN ppo000 AS ppo ON ppo.GUID    = ppi.PPOGuid
		INNER JOIN #PreparedMats  MatTbl ON MatTbl.MatGuid = ppi.MatGuid
		INNER JOIN vwExtended_bi AS ExBi ON ExBi.biGUID = ppi.SOIGuid
	WHERE	 
		ppo.POGuid = 0x00 
		AND 
		ppo.TypeGUID <> 0x00 
		AND 
		ppi.SOGuid <> @OrderGuid
		AND
		((@CalcNotAvailableQuantityPerStore = 0) OR ((CASE WHEN ExBi.biStorePtr <> 0x00 THEN ExBi.biStorePtr ELSE ExBi.buStorePtr END) IN (SELECT DISTINCT StoreGuid FROM #PreparedMats) AND (@CalcNotAvailableQuantityPerStore = 1)))
	GROUP BY 
		ppi.MatGuid	
	------------------------------
	IF @debugMode = 1
		SELECT '#Prepared', * FROM #Prepared	
	/*===============================================================*     
	 *							Result				                 *     
	 *===============================================================*/
	SELECT 
		bi.biMatPtr AS MatGuid,
	    --Total.StoreGuid,
	   ISNULL((ISNULL(bi.biQty, 0) 
			+ ISNULL(STotal.RemainedQty, 0) 
			- ISNULL(PTotal.RemainedQty, 0)
			- ISNULL(prep.Quantity, 0) 
			- ISNULL((SELECT sum(ms.Qty)
				FROM ms000  ms 
				WHERE ms.MatGUID = bi.biMatPtr AND ms.StoreGUID = 
						CASE WHEN @CalcNotAvailableQuantityPerStore = 1 
						THEN (CASE WHEN bi.biStorePtr <> 0x00 THEN bi.biStorePtr ELSE bi.buStorePtr END)
						ELSE ms.StoreGUID
						END 
				GROUP BY ms.MatGUID ), 0)),0) AS LackQty  
	INTO 
		#final
	FROM   
		vwExtended_bi AS bi
		LEFT JOIN #SellRemained AS STotal ON bi.biMatPtr = STotal.MatGuid 
		LEFT JOIN #PurchaseRemained PTotal ON  bi.biMatPtr = PTotal.MatGuid
	    LEFT JOIN #Prepared  AS prep ON prep.MatGuid = bi.biMatPtr
	WHERE 
		bi.buGUID = @OrderGuid 
		AND ((@MaterialGUID = 0x00) OR ((bi.biMatPtr = @MaterialGUID) AND (@MaterialGUID <> 0x00)))		
	----------------------------------------------------------------------- 
	IF @debugMode = 1
		SELECT '#final', * FROM #final 	
	-----------------------------------------------------------------------		
	/*===============================================================*     
	 *                       Update Data                            *     
	 *===============================================================*/
	UPDATE PPI
	SET 
		PPI.Quantity = (CASE WHEN (F.LackQty < 0 OR F.LackQty = 0) 
						THEN 0
						ELSE
							CASE WHEN (F.LackQty < bi.biQty) THEN F.LackQty ELSE bi.biQty END
						END)
		,PPI.IsQuantityNotCalculated = 0 --·«‰Â«¡  ÃÂÌ“ «·„«œ… ·· Õ÷Ì—  
	FROM 
		ppi000 PPI
		LEFT JOIN #final AS F  ON F.MatGuid = PPI.MatGuid
		INNER JOIN vwExtended_bi AS bi ON PPI.SOIGuid = bi.biGUID
	WHERE 
		PPI.SOGuid = @OrderGuid AND PPI.PPOGuid = @PPOGuid		
	AND PPI.MatGuid = @MaterialGUID

	SELECT * FROM #final WHERE LackQty > 0
##################################################################################
#END
