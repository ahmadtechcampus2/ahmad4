##################################################################################
CREATE PROCEDURE prc_InventoryNetAfterReservationRep 
	@MatGuid UNIQUEIDENTIFIER,
	@GroupGuid UNIQUEIDENTIFIER,
	@StoreGuid UNIQUEIDENTIFIER,
	@SelectedUnit INT,
    @EndDate DATETIME,
	@ReservdQtyDetailed BIT,
	@StoreDetailed		BIT,
	@ShowReservedMaterialsOnly BIT
AS
	BEGIN
		SET NOCOUNT ON
		
		DECLARE @language [INT]		
	    SET @language = [dbo].[fnConnections_getLanguage]() 
	 
		CREATE TABLE [#MatTbl]
		 (
		    [mtNumber]   [UNIQUEIDENTIFIER],
		    [mtSecurity] [INT]
		 )
	    INSERT INTO [#MatTbl]
        EXEC [prcGetMatsList] @MatGuid, @GroupGuid
	  CREATE TABLE #StoreTbl
         (
            [Guid] [UNIQUEIDENTIFIER],
			[Security] [INT]
         )
        INSERT INTO #StoreTbl exec [prcGetStoresList] @StoreGuid
		CREATE TABLE #ReservedQTYS
		(
			[reservedQty] [FLOAT],
			[mtGuid]    [UNIQUEIDENTIFIER],
			[storeGuid]   [UNIQUEIDENTIFIER]
		)
	
		INSERT INTO #ReservedQTYS
		SELECT 
				(CASE @SelectedUnit
					  WHEN 1 THEN (ISNULL(SUM(fn.ReservedQty), 0))
					  WHEN 2 THEN (ISNULL(SUM(fn.ReservedQty/ (CASE [mt].[mtUnit2Fact] WHEN 0 THEN [mt].[mtDefUnitFact] ELSE [mt].[mtUnit2Fact] END)), 0))
					  WHEN 3 THEN (ISNULL(SUM(fn.ReservedQty / (CASE [mt].[mtUnit3Fact] WHEN 0 THEN [mt].[mtDefUnitFact] ELSE [mt].[mtUnit3Fact] END)), 0))
					  ELSE (ISNULL(SUM(fn.ReservedQty / [mt].[mtDefUnitFact]), 0))
				 END
				) AS reservedQty,
				mt.mtGUID,
				(CASE @StoreDetailed 
					when 1 THEN fn.StoreGUID
					ELSE 0X0
				END
				) AS storeGuid
		FROM
			fnGetReservedQtyDetails(0x0,0x0,0x0) fn
			INNER JOIN vwMt mt ON fn.MatGuid = mt.mtGUID
			INNER JOIN #StoreTbl st ON st.GUID = fn.StoreGUID
		WHERE
			fn.[buDate] <= @EndDate
		GROUP BY mt.mtGUID,
				CASE @StoreDetailed 
					 WHEN 1 THEN fn.StoreGUID
					 ELSE 0x0
				END
		
		DECLARE @isCalcPurchaseOrderRemindedQty BIT
		SELECT @isCalcPurchaseOrderRemindedQty = dbo.fnOption_GetInt('AmnCfg_CalcPurchaseOrderRemindedQty', '0')
						
		CREATE TABLE #PurchaseOrderRemainingQTYS
		(
			[remainingQty] [FLOAT],
			[mtGuid]    [UNIQUEIDENTIFIER],
			[storeGuid]   [UNIQUEIDENTIFIER]
		)
	
		INSERT INTO #PurchaseOrderRemainingQTYS
		SELECT 
				(CASE @SelectedUnit
					  WHEN 1 THEN (ISNULL(SUM(fn.RemainingQty), 0))
					  WHEN 2 THEN (ISNULL(SUM(fn.RemainingQty/ (CASE [mt].[mtUnit2Fact] WHEN 0 THEN [mt].[mtDefUnitFact] ELSE [mt].[mtUnit2Fact] END)), 0))
					  WHEN 3 THEN (ISNULL(SUM(fn.RemainingQty / (CASE [mt].[mtUnit3Fact] WHEN 0 THEN [mt].[mtDefUnitFact] ELSE [mt].[mtUnit3Fact] END)), 0))
					  ELSE (ISNULL(SUM(fn.RemainingQty / [mt].[mtDefUnitFact]), 0))
				 END
				) AS reservedQty,
				mt.mtGUID,
				(CASE @StoreDetailed 
					when 1 THEN fn.biStorePtr
					ELSE 0X0
				END
				) AS storeGuid
		FROM
			vwmt mt
			INNER JOIN #MatTbl mat ON mat.mtNumber = mt.mtGUID			
			CROSS APPLY fnGetPurchaseOrderRemainingQtyDetails(mat.mtNumber, 0x0, 0x0) fn
			INNER JOIN #StoreTbl st ON st.GUID = fn.biStorePtr
		WHERE
			fn.[buDate] <= @EndDate
		GROUP BY mt.mtGUID,
				 CASE @StoreDetailed 
				 	  WHEN 1 THEN fn.biStorePtr
				 	  ELSE 0x0
				 END

		CREATE TABLE #MaterialMasterResult
		(
			unit NVARCHAR(100),
			mtQty FLOAT,
			reservedQty FLOAT,
			availableQty FLOAT,
			remainingQty FLOAT,
			netQty	FLOAT,
			storeName NVARCHAR(250),
			storeGuid UNIQUEIDENTIFIER,
			storeNumber INT,
			materialGuid UNIQUEIDENTIFIER,
			materialNumber INT,
			materialStoreGuid UNIQUEIDENTIFIER
		)

		IF(@isCalcPurchaseOrderRemindedQty = 0)
			BEGIN
				INSERT INTO #MaterialMasterResult
				SELECT DISTINCT 
								(CASE @SelectedUnit
							  		  WHEN 1 THEN [MT].[mtUnity]
							  		  WHEN 2 THEN (CASE [MT].[MtUnit2] WHEN '' THEN [MT].[mtDefUnitName] ELSE [MT].[MtUnit2] END)
							  		  WHEN 3 THEN (CASE [MT].[MtUnit3] WHEN '' THEN [MT].[mtDefUnitName] ELSE [MT].[MtUnit3] END)
							  		  ELSE [MT].[mtDefUnitName]
							      END
							    ) AS unit,
							    ISNULL((CASE @SelectedUnit
							  			   WHEN 1 THEN SUM([bu].[biQty]* [bu].[buDirection])
							  			   WHEN 2 THEN SUM([bu].[biQty]* [bu].[buDirection] / (CASE [bu].[mtUnit2Fact] WHEN 0 THEN [bu].[mtDefUnitFact] ELSE [bu].[mtUnit2Fact] END))
							  			   WHEN 3 THEN SUM([bu].[biQty]* [bu].[buDirection] / (CASE [bu].[mtUnit3Fact] WHEN 0 THEN [bu].[mtDefUnitFact] ELSE [bu].[mtUnit3Fact] END))
							  			   ELSE SUM([bu].[biQty]* [bu].[buDirection] / [bu].[mtDefUnitFact])
										END
							           ) ,0) AS mtQty ,
							    ISNULL(R.reservedQty, 0) AS reservedQty,
							   (ISNULL((CASE @SelectedUnit
							  			     WHEN 1 THEN SUM([bu].[biQty]* [bu].[buDirection])
							  			     WHEN 2 THEN SUM([bu].[biQty]* [bu].[buDirection] / (CASE [bu].[mtUnit2Fact] WHEN 0 THEN [bu].[mtDefUnitFact] ELSE [bu].[mtUnit2Fact] END))
							  			     WHEN 3 THEN SUM([bu].[biQty]* [bu].[buDirection] / (CASE [bu].[mtUnit3Fact] WHEN 0 THEN [bu].[mtDefUnitFact] ELSE [bu].[mtUnit3Fact] END))
							  			     ELSE SUM([bu].[biQty]* [bu].[buDirection] / [bu].[mtDefUnitFact])
										END
							           ) ,0)
							   ) AS availableQty,
							   0 AS remainingQty,
							   ISNULL(((CASE @SelectedUnit
							  				WHEN 1 THEN SUM([bu].[biQty]* [bu].[buDirection])
							  				WHEN 2 THEN SUM([bu].[biQty]* [bu].[buDirection] / (CASE [bu].[mtUnit2Fact] WHEN 0 THEN [bu].[mtDefUnitFact] ELSE [bu].[mtUnit2Fact] END))
							  				WHEN 3 THEN SUM([bu].[biQty]* [bu].[buDirection] / (CASE [bu].[mtUnit3Fact] WHEN 0 THEN [bu].[mtDefUnitFact] ELSE [bu].[mtUnit3Fact] END))
							  				ELSE SUM([bu].[biQty]* [bu].[buDirection] / [bu].[mtDefUnitFact])
										END
							           
							          ))
									    - 
									   ISNULL([R].[reservedQty], 0), 0) AS netQty,
							   (CASE @StoreDetailed
									WHEN 1 THEN [st].[Name] 
									ELSE ''
							   END
							   ) AS storeName,
							   (CASE @StoreDetailed
									WHEN 1 THEN [st].[GUID] 
									ELSE 0X0
							   END
							   ) AS storeGuid,
							   (CASE @StoreDetailed
									 WHEN 1 THEN [st].[Number]
									 ELSE 0
						        END
							   ) AS storeNumber,
							   [bu].[biMatPtr] AS materialGuid,
							   [MT].[mtNumber] AS materialNumber,
							   NEWID() as materialStoreGuid				
				FROM 
					vwMt mt 
					INNER JOIN #MatTbl [mat] ON [mat].[mtNumber] = [mt].[mtGUID]
					INNER JOIN vwExtended_bi [bu] ON [bu].[biMatPtr] = [mat].[mtnumber] 
					LEFT JOIN #ReservedQTYS [R] ON [R].[mtGuid] = [mat].[mtNumber] AND (R.storeGuid = (CASE WHEN @StoreDetailed = 1 THEN BU.biStorePtr ELSE 0x0 END))			
					INNER JOIN #StoreTbl [storeTbl] ON [storeTbl].[Guid] = [bu].[buStorePtr]
					LEFT JOIN vwORI [ori] ON [ori].[oriPOGUID] = [bu].[buGUID]
					LEFT JOIN st000 [st] ON [st].[GUID] = [bu].[buStorePtr]
				WHERE
					 ([bu].[buIsPosted] <> 0
					  OR
					 ([bu].[buIsPosted] = 0 AND ([BU].[btType] = 5)))
					  AND
					 [bu].[buDate] <= @EndDate		
				GROUP BY
						CASE @SelectedUnit
							 WHEN 1 THEN [MT].[mtUnity]
							 WHEN 2 THEN (CASE [MT].[MtUnit2] WHEN '' THEN [MT].[mtDefUnitName] ELSE [MT].[MtUnit2] END)
							 WHEN 3 THEN (CASE [MT].[MtUnit3] WHEN '' THEN [MT].[mtDefUnitName] ELSE [MT].[MtUnit3] END)
							 ELSE [MT].[mtDefUnitName]
						END,
						CASE @StoreDetailed
						 	 WHEN 1 THEN [st].[Name]
						 	 ELSE ''
						END,
						[bu].[biMatPtr],
						[MT].[mtNumber],
						CASE @StoreDetailed
							 WHEN 1 THEN [st].[GUID]
							 ELSE 0x0
						END,
						CASE @StoreDetailed
							 WHEN 1 THEN [st].[Number]
							 ELSE 0
						END,
						[R].[reservedQty]
				ORDER BY 
						[MT].[mtNumber]
			END
		ELSE
			BEGIN
				INSERT INTO #MaterialMasterResult
				SELECT DISTINCT 
							(CASE @SelectedUnit
						  		  WHEN 1 THEN [MT].[mtUnity]
						  		  WHEN 2 THEN (CASE [MT].[MtUnit2] WHEN '' THEN [MT].[mtDefUnitName] ELSE [MT].[MtUnit2] END)
						  		  WHEN 3 THEN (CASE [MT].[MtUnit3] WHEN '' THEN [MT].[mtDefUnitName] ELSE [MT].[MtUnit3] END)
						  		  ELSE [MT].[mtDefUnitName]
						      END
						    ) AS unit,
						    ISNULL((CASE @SelectedUnit
						  			   WHEN 1 THEN SUM([bu].[biQty]* [bu].[buDirection])
						  			   WHEN 2 THEN SUM([bu].[biQty]* [bu].[buDirection] / (CASE [bu].[mtUnit2Fact] WHEN 0 THEN [bu].[mtDefUnitFact] ELSE [bu].[mtUnit2Fact] END))
						  			   WHEN 3 THEN SUM([bu].[biQty]* [bu].[buDirection] / (CASE [bu].[mtUnit3Fact] WHEN 0 THEN [bu].[mtDefUnitFact] ELSE [bu].[mtUnit3Fact] END))
						  			   ELSE SUM([bu].[biQty]* [bu].[buDirection] / [bu].[mtDefUnitFact])
									END
						           ) ,0) AS mtQty ,
						    ISNULL(R.reservedQty, 0) AS reservedQty,
						   (ISNULL((CASE @SelectedUnit
						  			     WHEN 1 THEN SUM([bu].[biQty]* [bu].[buDirection])
						  			     WHEN 2 THEN SUM([bu].[biQty]* [bu].[buDirection] / (CASE [bu].[mtUnit2Fact] WHEN 0 THEN [bu].[mtDefUnitFact] ELSE [bu].[mtUnit2Fact] END))
						  			     WHEN 3 THEN SUM([bu].[biQty]* [bu].[buDirection] / (CASE [bu].[mtUnit3Fact] WHEN 0 THEN [bu].[mtDefUnitFact] ELSE [bu].[mtUnit3Fact] END))
						  			     ELSE SUM([bu].[biQty]* [bu].[buDirection] / [bu].[mtDefUnitFact])
									END
						           ) ,0)
								    + ISNULL(MAX(RemainingQTYS.remainingQty), 0)
						   ) AS availableQty,
						   ISNULL(MAX(RemainingQTYS.remainingQty), 0) AS remainingQty,
						   ISNULL(((CASE @SelectedUnit
						  				WHEN 1 THEN SUM([bu].[biQty]* [bu].[buDirection])
						  				WHEN 2 THEN SUM([bu].[biQty]* [bu].[buDirection] / (CASE [bu].[mtUnit2Fact] WHEN 0 THEN [bu].[mtDefUnitFact] ELSE [bu].[mtUnit2Fact] END))
						  				WHEN 3 THEN SUM([bu].[biQty]* [bu].[buDirection] / (CASE [bu].[mtUnit3Fact] WHEN 0 THEN [bu].[mtDefUnitFact] ELSE [bu].[mtUnit3Fact] END))
						  				ELSE SUM([bu].[biQty]* [bu].[buDirection] / [bu].[mtDefUnitFact])
									END
						           
						          )
								    + 							  
								   ISNULL(MAX(RemainingQTYS.remainingQty), 0))
								    - 
								   ISNULL([R].[reservedQty], 0), 0) AS netQty,
						   (CASE @StoreDetailed
								WHEN 1 THEN [st].[Name] 
								ELSE ''
						   END
						   ) AS storeName,
						   (CASE @StoreDetailed
								WHEN 1 THEN [st].[GUID] 
								ELSE 0X0
						   END
						   ) AS storeGuid,
						   (CASE @StoreDetailed
								 WHEN 1 THEN [st].[Number]
								 ELSE 0
					        END
						   ) AS storeNumber,
						   [bu].[biMatPtr] AS materialGuid,
						   [MT].[mtNumber] AS materialNumber,
						   NEWID() as materialStoreGuid
				FROM 
					vwMt mt 
					INNER JOIN #MatTbl [mat] ON [mat].[mtNumber] = [mt].[mtGUID]
					INNER JOIN vwExtended_bi [bu] ON [bu].[biMatPtr] = [mat].[mtnumber] 
					LEFT JOIN #ReservedQTYS [R] ON [R].[mtGuid] = [mat].[mtNumber] AND (R.storeGuid = (CASE WHEN @StoreDetailed = 1 THEN BU.biStorePtr ELSE 0x0 END))
					LEFT JOIN #PurchaseOrderRemainingQTYS [RemainingQTYS] ON [RemainingQTYS].[mtGuid] = [mat].[mtNumber] AND (RemainingQTYS.storeGuid = (CASE WHEN @StoreDetailed = 1 THEN BU.biStorePtr ELSE 0x0 END))			
					INNER JOIN #StoreTbl [storeTbl] ON [storeTbl].[Guid] = [bu].[buStorePtr]
					LEFT JOIN vwORI [ori] ON [ori].[oriPOGUID] = [bu].[buGUID]
					LEFT JOIN st000 [st] ON [st].[GUID] = [bu].[buStorePtr]
				WHERE
					 ([bu].[buIsPosted] <> 0
					  OR
					 ([bu].[buIsPosted] = 0 AND ([BU].[btType] = 5 OR [BU].[btType] = 6)))
					  AND
					 [bu].[buDate] <= @EndDate		
				GROUP BY
						CASE @SelectedUnit
							 WHEN 1 THEN [MT].[mtUnity]
							 WHEN 2 THEN (CASE [MT].[MtUnit2] WHEN '' THEN [MT].[mtDefUnitName] ELSE [MT].[MtUnit2] END)
							 WHEN 3 THEN (CASE [MT].[MtUnit3] WHEN '' THEN [MT].[mtDefUnitName] ELSE [MT].[MtUnit3] END)
							 ELSE [MT].[mtDefUnitName]
						END,
						CASE @StoreDetailed
						 	 WHEN 1 THEN [st].[Name]
						 	 ELSE ''
						END,
						[bu].[biMatPtr],
						[MT].[mtNumber],
						CASE @StoreDetailed
							 WHEN 1 THEN [st].[GUID]
							 ELSE 0x0
						END,
						CASE @StoreDetailed
							 WHEN 1 THEN [st].[Number]
							 ELSE 0
						END,
						[R].[reservedQty]
				ORDER BY 
						[MT].[mtNumber]	
			END


		IF @ShowReservedMaterialsOnly != 0
			BEGIN
				SELECT * FROM #MaterialMasterResult
				WHERE reservedQty <> 0
				ORDER BY 
						materialNumber,
						storeNumber
			END		
        ELSE
			BEGIN
				SELECT * FROM #MaterialMasterResult
				ORDER BY 
						materialNumber,
						storeNumber
			END
			IF @ReservdQtyDetailed != 0
			BEGIN
				SELECT DISTINCT
								bu.buDate AS orderDate,
								(CASE 
									  WHEN @language <> 0 AND bu.btLatinName <> '' THEN bu.btLatinName  
									  ELSE bu.btName 
								 END) + ': ' + CAST(bu.buNumber AS NVARCHAR) AS orderName,
								(CASE 
									  WHEN @language <> 0 AND cu.cuLatinName <> '' THEN cu.cuLatinName  
									  ELSE cu.cuCustomerName 
								 END) AS customerName,
								 ISNULL((CASE @SelectedUnit
											  WHEN 1 THEN (SUM(ori.oriQty))
											  WHEN 2 THEN (SUM(ori.oriQty / (CASE [bu].[mtUnit2Fact] WHEN 0 THEN [bu].[mtDefUnitFact] ELSE [bu].[mtUnit2Fact] END)))
											  WHEN 3 THEN (SUM(ori.oriQty / (CASE [bu].[mtUnit3Fact] WHEN 0 THEN [bu].[mtDefUnitFact] ELSE [bu].[mtUnit3Fact] END)))
											  ELSE (SUM(ori.oriQty / [bu].[mtDefUnitFact]))
										  END
										 ), 0) AS reservedQtyDetailed,
								ori.oriPOIGuid AS oriPOIGuid, 
								ori.oriPOGuid AS orderGuid,
								bu.biMatPtr AS orderMaterialPtr,
								masterResult.materialStoreGuid AS orderMaterialStoreGuid
				FROM 
					 vwORI ori 
					 INNER JOIN vwExtended_bi bu ON ori.oriPOIGuid = bu.bIGUID
					 INNER JOIN #MatTbl mat ON mat.mtNumber = bu.biMatPtr
					 INNER JOIN #StoreTbl st ON st.Guid = bu.biStorePtr
					 INNER JOIN oit000 OIT ON ori.oriTypeGuid = OIT.[Guid]
					 INNER JOIN fnGetReservedQtyDetails(0x0,0x0,0x0) fn ON fn.BiGuid = ori.oriPOIGuid AND fn.TypeGUID = ori.oriTypeGUID
					 LEFT JOIN vwCu cu ON cu.cuGUID = bu.buCustPtr
					 LEFT JOIN #MaterialMasterResult masterResult ON masterResult.storeGUID = bu.biStorePtr AND masterResult.materialGuid = bu.biMatPtr
				WHERE 
					[bu].[buDate] <= @EndDate
					 AND
					bu.btType = 5
					 AND 
					IsQtyReserved = 1
				GROUP BY
					bu.buDate,
					CASE 
						  WHEN @language <> 0 AND bu.btLatinName <> '' THEN bu.btLatinName  
						  ELSE bu.btName 
					END,
					bu.buNumber,
					ori.oriPOGuid,
					ori.oriPOIGuid,
					bu.biMatPtr,
					CASE 
						  WHEN @language <> 0 AND cu.cuLatinName <> '' THEN cu.cuLatinName  
						  ELSE cu.cuCustomerName 
					END,
					masterResult.materialStoreGuid
			END
	END
##################################################################################
#END
