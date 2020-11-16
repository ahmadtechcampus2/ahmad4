#########################################################
CREATE PROCEDURE prcGetPostMove
	@OrderGuid UNIQUEIDENTIFIER = 0x00
 AS 
 	SET NOCOUNT ON 

	DECLARE @Language BIT = dbo.fnConnections_GetLanguage();

	SELECT
		[o].[oriPOGUID] AS OrderGuid,
		[bu].[buNumber] AS OrderNumber,
		[bu].[buType] AS OrderTypeGuid,
		[o].[oriPostNumber] AS PostNumber,
		[o].[oriPostGuid] AS PostGuid,
		[o].[oriDate] AS PostDate,
		[o].[oriTypeGuid] AS ToStateGuid,
		CASE @Language
				WHEN 0 THEN oit1.NAME
				ELSE CASE ISNULL(oit1.LatinName, '')
						WHEN '' THEN oit1.NAME
						ELSE oit1.LatinName
					END
		END AS [ToStateName],
		[oit1].[operation] AS ToStateOperation,
		[previousState].[TypeGuid] AS [FromStateGuid],
		CASE @Language
				WHEN 0 THEN oit2.NAME
				ELSE CASE ISNULL(oit2.LatinName, '')
						WHEN '' THEN oit2.NAME
						ELSE oit2.LatinName
					END
		END AS [FromStateName],
		CASE WHEN [oit1].[operation] <> 3 THEN [o].[oriBuGUID] ELSE 0x0 END AS BillGuid,
	    [bill].[buType] AS BillTypeGuid,
		CASE WHEN [oit1].[operation] <> 3 THEN
	         CASE WHEN  [oit1].[operation] = 2 THEN CASE WHEN [o].[oribIsRecycled] = 0 THEN SUBSTRING ([o].[oriNotes],4,LEN([o].[oriNotes])) ELSE [o].[oriNotes] END
			 ELSE [o].[oriNotes] END
	    ELSE '' END AS BillName,
		[o].[oribIsRecycled] AS IsRecycled,
		bill.buLCGUID,
		TransInfo.LcGuid,
		lc.LatinName,
		lc.Name,
		TransInfo.LcLatinName,
		TransInfo.LcName,
		lc.State,
		TransInfo.LcState,
		(CASE bIsRecycled
			WHEN 0 THEN bill.buLCGUID ELSE TransInfo.LcGuid
		END) AS buLCGUID,
		(CASE bIsRecycled
			WHEN 0 THEN 
			(CASE 
				WHEN @Language <> 0 AND lc.LatinName <> '' THEN lc.LatinName  ELSE lc.Name
			 END) + '-' + Convert(nvarchar(255), lc.Number)
			Else
			(CASE
				WHEN @Language <> 0 AND TransInfo.LcLatinName <> '' THEN TransInfo.LcLatinName  ELSE TransInfo.LcName
			 END) + '-' + Convert(nvarchar(255), TransInfo.LcNumber)
		 END) AS LcName,
		 CASE bIsRecycled WHEN 0 THEN lc.State ELSE TransInfo.LcState END AS State
	FROM 
		[vwORI] [o]
		INNER JOIN vwBu bu ON bu.buGUID = o.oriPOGUID
		LEFT JOIN ori000 previousState ON previousState.POIGUID = [o].oriPOIGuid AND previousState.Number = [o].oriNumber - 1
		LEFT JOIN oit000 oit1 ON oit1.[GUID] = o.oriTypeGuid
		LEFT JOIN oit000 oit2 ON oit2.[GUID] = previousState.TypeGuid
		LEFT JOIN vwBu bill ON bill.buGUID = [o].[oriBuGUID]
		LEFT JOIN LC000 lc ON bill.buLCGUID = lc.GUID
		LEFT JOIN TransferedOrderBillsInfo000 TransInfo ON ISNULL(TransInfo.TransferOriBuGuid, TransInfo.OriBuGuid) = [o].oriBuGUID
	WHERE 
		(oriQty > 0 OR oriBonusPostedQty > 0) AND [o].[oriPostNumber] <> 0 AND [o].[oriPOGUID] = @OrderGuid 
		AND [o].[oriTypeGuid] <> [previousState].[TypeGuid]
	GROUP BY	
		[o].[oriPOGUID],
		[bu].[buNumber],
		[bu].[buType],
		[o].[oriPostNumber],
		[o].[oriPostGuid],
		[o].[oriTypeGuid],
		CASE @Language
				WHEN 0 THEN oit1.NAME
				ELSE CASE ISNULL(oit1.LatinName, '')
						WHEN '' THEN oit1.NAME
						ELSE oit1.LatinName
					END
		END,
		[oit1].[operation] ,
		[o].[oriDate],
		[previousState].[TypeGuid],
		CASE @Language
				WHEN 0 THEN oit2.NAME
				ELSE CASE ISNULL(oit2.LatinName, '')
						WHEN '' THEN oit2.NAME
						ELSE oit2.LatinName
					END
		END,
		CASE WHEN [oit1].[operation] <> 3 THEN [o].[oriBuGUID] ELSE 0x0 END ,
		[bill].[buType],
		CASE WHEN [oit1].[operation] <> 3 THEN
	         CASE WHEN  [oit1].[operation] = 2 THEN CASE WHEN [o].[oribIsRecycled] = 0 THEN SUBSTRING ([o].[oriNotes],4,LEN([o].[oriNotes])) ELSE [o].[oriNotes] END
			 ELSE [o].[oriNotes] END
	    ELSE '' END,
		[o].[oribIsRecycled],
		bill.buLCGUID,
		bIsRecycled,
		lc.LatinName,
		lc.Name,
		lc.Number,
		lc.State,
		TransInfo.LcGuid,
		TransInfo.LcLatinName,
		TransInfo.LcName,
		TransInfo.LcState,
		TransInfo.LcNumber
		
	ORDER BY 
		[o].[oriPostNumber], [o].[oriDate] 
#########################################################
CREATE PROCEDURE prcGetPostMaterials
	@OrderGuid UNIQUEIDENTIFIER = 0x00,
	@PostGuid UNIQUEIDENTIFIER = 0x00
 AS 
 	SET NOCOUNT ON 
	
	DECLARE @IsRecycled  BIT = 0
	DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
	SELECT TOP 1 @IsRecycled = bIsRecycled FROM ori000 WHERE PostGuid = @PostGuid AND POGUID = @OrderGuid
	CREATE TABLE #OrderBills(
		buGUID UNIQUEIDENTIFIER,
		buType UNIQUEIDENTIFIER,
		btAbbrev NVARCHAR(250),
		buNumber FLOAT,
		buCostPtr UNIQUEIDENTIFIER,
		buDate DATETIME,
		buStorePtr UNIQUEIDENTIFIER,
		buTotal FLOAT,
		buTotalExtra FLOAT,
		buTotalDisc FLOAT,
		buBonusDisc FLOAT,
		biGUID UNIQUEIDENTIFIER,
		biStorePtr UNIQUEIDENTIFIER,
		biCostPtr UNIQUEIDENTIFIER,
		biUnity FLOAT,
		biMatPtr UNIQUEIDENTIFIER,
		biQty FLOAT,
		biPrice FLOAT,
		biUnitPrice FLOAT,
		biClassPtr NVARCHAR(250),
		biDiscount FLOAT,
		biExtra FLOAT,
		biBonusDisc FLOAT,
		biVAT FLOAT,
		biCurrencyVal FLOAT,
		biExpireDate DATETIME)
	--------‰”Œ «·›Ê« Ì— «·„œÊ—… «·Œ«’… »«·ÿ·»Ì… „‰ «·ÃœÊ· «·–Ì ÌÕÊÌ ›Ê« Ì— «·ÿ·»Ì«  «·„œÊ—… ------  
	IF (@IsRecycled = 1)
	BEGIN
		DECLARE @X xml 
		SELECT @X = BillXmlData from TrnOrdBu000 Where OrderGuid = @OrderGuid
		INSERT INTO #OrderBills
		SELECT  x.r.value('(buGUID)[1]', 'uniqueidentifier') as [buGuid],
		  x.r.value('(buType)[1]', 'uniqueidentifier') as [buType],
		  x.r.value('(btAbbrev)[1]', 'NVARCHAR(250)') as [btAbbrev],
		  x.r.value('(buNumber)[1]', 'FLOAT') as [buNumber],
		  x.r.value('(buCostPtr)[1]', 'uniqueidentifier') as [buCostPtr],
		  x.r.value('(buDate)[1]', 'DATETIME') as [buDate],
		  x.r.value('(buStorePtr)[1]', 'uniqueidentifier') as [buStorePtr],
		  x.r.value('(buTotal)[1]', 'FLOAT') as [buTotal],
		  x.r.value('(buTotalExtra)[1]', 'FLOAT') as [buTotalExtra],
		  x.r.value('(buTotalDisc)[1]', 'FLOAT') as [buTotalDisc],
		  x.r.value('(buBonusDisc)[1]', 'FLOAT') as [buBonusDisc],
		  x.r.value('(biGUID)[1]', 'uniqueidentifier') as [biGuid],
		  x.r.value('(biStorePtr)[1]', 'uniqueidentifier') as [biStorePtr],
		  x.r.value('(biCostPtr)[1]', 'uniqueidentifier') as [biCostPtr],
		  x.r.value('(biUnity)[1]', 'FLOAT') as [biUnity],
		  x.r.value('(biMatPtr)[1]', 'uniqueidentifier') as [biMatPtr],
		  x.r.value('(biQty)[1]', 'FLOAT') as [biQty],
		  x.r.value('(biPrice)[1]', 'FLOAT') as [biPrice],
		  x.r.value('(biUnitPrice)[1]', 'FLOAT') as [biUnitPrice],
		  x.r.value('(biClassPtr)[1]', 'NVARCHAR(250)') as [biClassPtr],
		  x.r.value('(biDiscount)[1]', 'FLOAT') as [biDiscount],
		  x.r.value('(biExtra)[1]', 'FLOAT') as [biExtra],
		  x.r.value('(biBonusDisc)[1]', 'FLOAT') as [biBonusDisc],
		  x.r.value('(biVAT)[1]', 'FLOAT') as [biVat],
		  x.r.value('(biCurrencyVal)[1]', 'FLOAT') as [biCurrencyVal],
		  x.r.value('(biExpireDate)[1]', 'DATETIME') as [biExpireDate]
	FROM   
		  @X.nodes('/OrderBills') as x(r)
		  
	END
	
	--------‰”Œ «·›Ê« Ì— «·Œ«’… »«·ÿ·»Ì«  «·€Ì— „œÊ—… ------
	ELSE
	BEGIN
		INSERT INTO #OrderBills
			SELECT  
				buGUID ,
				buType,
				btAbbrev,
				buNumber,
				buCostPtr,
				buDate,
				buStorePtr,
				buTotal,
				buTotalExtra,
				buTotalDisc,
				buBonusDisc,
				biGUID,
				biStorePtr,
				biCostPtr,
				biUnity,
				biMatPtr,
				biQty,
				biPrice,
				biUnitPrice,
				biClassPtr,
				biUnitDiscount,
				biUnitExtra,
				biBonusDisc,
				biVAT,
				biCurrencyVal,
				biExpireDate
			FROM 
				vwExtended_bi bi
			WHERE 
				bi.buGUID IN (SELECT BuGuid FROM ori000 ori where ori.POGUID = @OrderGuid)
	END

	SELECT
			[o].[oriPOIGUID] AS POIGuid,
			[o].[oriPOGUID] AS OrderGuid,
			[o].[oriPostNumber] AS PostNumber,
			[o].[oriPostGuid] AS PostGuid,
			[mt].[mtGUID] AS MatGuid,
			[mt].[mtCode] + '-' + (CASE @Lang WHEN 0 THEN mt.[mtName] ELSE (CASE mt.mtLatinName WHEN N'' THEN mt.mtName ELSE Mt.mtLatinName END) END ) AS MatName,
			[mt].mtCompositionName COLLATE ARABIC_CI_AI AS mtCompositionName,
			[mt].mtCompositionLatinName AS mtCompositionLatinName,
			[bi1].[biNumber]  AS biNumber,
			[bi2].[biCostPtr] AS CostGuid,
			[co].[Code] + '-' + [co].[Name] COLLATE ARABIC_CI_AI AS CostName,
			[bi2].[biStorePtr] AS StoreGuid,
			[st].[Code] + '-' + [st].[Name] COLLATE ARABIC_CI_AI AS StoreName,
			[o].[oriQty] / (CASE [bi1].[biUnity] 
								WHEN 2 THEN mt.mtUnit2Fact
								WHEN 3 THEN mt.mtUnit3Fact 
								ELSE 1 END)AS Qty,
			[bi1].[biBillQty] AS OrderQty,
			[o].[oriBonusPostedQty] AS BonusQty,
			[bi2].[biClassPtr] AS Class,
			[bi2].[biExpireDate] AS ExpirationDate,
			[bi1].[biUnity] AS Unity,
			CASE [bi1].[biUnity] WHEN 1 THEN mt.mtUnity
								WHEN 2 THEN mt.mtUnit2
								WHEN 3 THEN mt.mtUnit3 END AS UnityName,
			CASE [bi1].[biUnity]  WHEN 2 THEN mt.mtUnit2Fact
								  WHEN 3 THEN mt.mtUnit3Fact 
								  ELSE 1 END AS UnitFact,
			[o].[oriNumber] AS Number,
			[o].[oriType] AS oriType,
			[o].[oriNotes] AS Note,
			[o].[oriBuGUID] AS buGuid,
			[o].[oriBiGUID] AS biGuid,
			[mt].[mtExpireFlag] AS ExpireFlag,
			CASE [bi1].[biCurrencyVal] WHEN 0 THEN [bi1].[biExtra] ELSE [bi1].[biExtra] / [bi1].[biCurrencyVal] END AS ExtraRatio,
			CASE [bi1].[biCurrencyVal] WHEN 0 THEN [bi1].[biDiscount] ElSE [bi1].[biDiscount] / [bi1].[biCurrencyVal] END As DiscRatio,
			CASE [bi1].[btVATSystem]  
				WHEN 2 THEN ((bi1.biUnitPrice * mtUnitFact * (1 + biVATr/100))) / CASE bi1.biCurrencyVal WHEN 0 THEN 1 ELSE bi1.biCurrencyVal END 
				ELSE (bi1.biUnitPrice * mtUnitFact) / CASE bi1.biCurrencyVal WHEN 0 THEN 1 ELSE bi1.biCurrencyVal END 
			END AS Price 
		FROM 
			[vwORI] [o]
			INNER JOIN [vwExtended_bi] [bi1] ON [bi1].[biGUID] = [o].[oriPOIGUID]
			LEFT JOIN [#OrderBills] [bi2] ON [bi2].[buGuid] = [o].[oriBuGuid] AND [bi2].[biGUID] = [o].[oriBiGUID]
			INNER JOIN [vwMt] AS [mt] ON [bi1].[biMatPtr] = [mt].[mtGuid]
			LEFT JOIN [co000] AS [co] ON [co].[GUID] = [bi2].[biCostPtr]
			LEFT JOIN [st000] AS [st] ON [st].[GUID] = [bi2].[biStorePtr]
		WHERE 
			([o].[oriQty] > 0 OR [o].[oriBonusPostedQty] > 0)
			AND [o].[oriPOGUID] = @OrderGuid
			AND [o].[oriPostGuid] = @PostGuid
		GROUP BY	
			[o].[oriPOIGUID],
			[o].[oriPOGUID],
			[o].[oriPostNumber],
			[o].[oriPostGuid],
			[mt].[mtGUID],
			[mt].[mtCode] + '-' + (CASE @Lang WHEN 0 THEN mt.[mtName] ELSE (CASE mt.mtLatinName WHEN N'' THEN mt.mtName ELSE Mt.mtLatinName END) END ),
			[mt].mtCompositionName COLLATE ARABIC_CI_AI,
			[mt].mtCompositionLatinName,
			[bi1].[biNumber],
			[bi2].[biCostPtr],
			[co].[Code] + '-' + [co].[Name] COLLATE ARABIC_CI_AI,
			[bi2].[biStorePtr],
			[st].[Code] + '-' + [st].[Name] COLLATE ARABIC_CI_AI,
			[o].[oriQty] / (CASE [bi1].[biUnity] 
								WHEN 2 THEN mt.mtUnit2Fact
								WHEN 3 THEN mt.mtUnit3Fact 
								ELSE 1 END),
			[bi1].[biBillQty], 
			[o].[oriBonusPostedQty],
			[bi2].[biClassPtr],
			[bi2].[biExpireDate],
			[bi1].[biUnity],
			CASE [bi1].[biUnity] WHEN 1 THEN mt.mtUnity
								WHEN 2 THEN mt.mtUnit2
								WHEN 3 THEN mt.mtUnit3 END,
			CASE [bi1].[biUnity]  WHEN 2 THEN mt.mtUnit2Fact
								  WHEN 3 THEN mt.mtUnit3Fact 
								  ELSE 1 END,
			[o].[oriNumber],
			[o].[oriType],
			[o].[oriNotes],
			[o].[oriBuGUID],
			[o].[oriBiGUID],
			[mt].[mtExpireFlag],
			CASE [bi1].[biCurrencyVal] WHEN 0 THEN [bi1].[biExtra] ELSE [bi1].[biExtra] / [bi1].[biCurrencyVal] END ,
			CASE [bi1].[biCurrencyVal] WHEN 0 THEN [bi1].[biDiscount] ElSE [bi1].[biDiscount] / [bi1].[biCurrencyVal] END,
			CASE [bi1].[btVATSystem]  
				WHEN 2 THEN ((bi1.biUnitPrice * mtUnitFact * (1 + biVATr/100))) / CASE bi1.biCurrencyVal WHEN 0 THEN 1 ELSE bi1.biCurrencyVal END 
				ELSE (bi1.biUnitPrice * mtUnitFact) / CASE bi1.biCurrencyVal WHEN 0 THEN 1 ELSE bi1.biCurrencyVal END 
			END
		ORDER BY 
			[bi1].[biNumber]
#########################################################
CREATE PROCEDURE prcUpdateOrdersPayments @BillGuid UNIQUEIDENTIFIER
AS
    SET NOCOUNT ON

    CREATE TABLE #OrdersTbl
      (
         OrderGuid UNIQUEIDENTIFIER
      )

    ------------ ⁄œÌ· ﬁÌ„… «·–„… ··ÿ·»Ì«  «·„— »ÿ… »«·›« Ê—… «·„⁄œ·…----------
    INSERT INTO #OrdersTbl
    SELECT DISTINCT POGUID
    FROM   ori000
    WHERE  BuGuid = @BillGuid

    DECLARE @OrdGuid UNIQUEIDENTIFIER = 0x0;
    DECLARE ord_Cursor CURSOR FOR
      SELECT OrderGuid
      FROM   #OrdersTbl

    OPEN ord_Cursor

    FETCH NEXT FROM ord_Cursor INTO @OrdGuid

    WHILE @@FETCH_STATUS = 0
      BEGIN
          EXEC prcUpdateOrderPayments
            @OrdGuid,
            0

          FETCH NEXT FROM ord_Cursor INTO @OrdGuid
      END

    CLOSE ord_Cursor

    DEALLOCATE ord_Cursor 
#########################################################
CREATE PROCEDURE prcGetPostMatDetails @OrderGuid UNIQUEIDENTIFIER = 0x00,
                                     @MatGuid   UNIQUEIDENTIFIER = 0x00
AS
    SET NOCOUNT ON

    SELECT bi.biGUID                                                AS POIGUID,
		   bi.biNumber												AS biNumber,
           [mt].[mtCode] + '-' + [mt].[mtName] COLLATE ARABIC_CI_AI AS MatName,
		   [bi].[biBillQty]											AS OrderQty,
		   [bi].[biUnity]											AS Unity,
           CASE [bi].[biUnity]
             WHEN 1 THEN mt.mtUnity
             WHEN 2 THEN mt.mtUnit2
             WHEN 3 THEN mt.mtUnit3
           END                                                      AS UnityName,
           CASE [bi].[biUnity]
             WHEN 2 THEN mt.mtUnit2Fact
             WHEN 3 THEN mt.mtUnit3Fact
             ELSE 1
           END                                                      AS UnitFact,
           [mt].[mtExpireFlag]                                      AS ExpireFlag,
           CASE [bi].[biCurrencyVal]
             WHEN 0 THEN [bi].[biDiscount]
             ELSE [bi].[biDiscount] / [bi].[biCurrencyVal]
           END                                                      AS DiscRatio,
           CASE [bi].[biCurrencyVal]
             WHEN 0 THEN [bi].[biExtra]
             ELSE [bi].[biExtra] / [bi].[biCurrencyVal]
           END                                                      AS ExtraRatio,
		   CASE [bi].[btVATSystem]  
				WHEN 2 THEN ((bi.biUnitPrice * mtUnitFact * (1 + biVATr/100))) / CASE bi.biCurrencyVal WHEN 0 THEN 1 ELSE bi.biCurrencyVal END 
				ELSE (bi.biUnitPrice * mtUnitFact) / CASE bi.biCurrencyVal WHEN 0 THEN 1 ELSE bi.biCurrencyVal END 
			END AS Price 
    FROM   [vwExtended_bi] [bi]
           INNER JOIN [vwMt] AS [mt]
                   ON [mt].[mtGuid] = [bi].[biMatPtr]
    WHERE  bi.buGUID = @OrderGuid
           AND biMatPtr = @MatGuid 
#########################################################
CREATE PROCEDURE prcModifyPostToBill
    @OrderGuid UNIQUEIDENTIFIER = 0x00,
	@PostGuid UNIQUEIDENTIFIER = 0x00
 AS 
 	SET NOCOUNT ON 

	DECLARE @BillGuid UNIQUEIDENTIFIER = 0x00,
			@OrderCount INT;

	SELECT @BillGuid = BuGuid FROM ori000 WHERE POGUID =  @OrderGuid AND PostGuid = @PostGuid
	----------ÃœÊ· «·√ﬁ·«„ «·„ÊÃÊœ… ›Ì «·›« Ê—… ÊÃœÊ· «· —ÕÌ· „⁄«
	SELECT 
        ori.Guid AS oriGuid,
		ori.biGuid AS biGuid
	INTO 
		#BillQty
	FROM 
		ori000 ori
	WHERE
		 ori.PostGuid = @PostGuid
	----------ÃœÊ· «·√ﬁ·«„ «·„ÊÃÊœ… ›Ì «·›« Ê—… Ê€Ì— „ÊÃÊœ… ›Ì ÃœÊ· «· —ÕÌ·
	SELECT 
	    biGuid AS biGuid,
		biMatPtr AS MatGuid,  
	    biQty AS biQty,
		biBonusQnt AS bonusQty
	INTO
		#NewItem
	FROM
		vwExtended_bi
	WHERE
		buGUID = @BillGuid AND biGuid NOT IN (SELECT biGuid FROM ori000 WHERE buGUID = @BillGuid)
	-----------≈÷«›… «·„Ê«œ «·ÃœÌœ… ›Ì «·›« Ê—… ≈·Ï ÃœÊ· «· —ÕÌ·
	DECLARE  @BiGuid UNIQUEIDENTIFIER = 0x0,
			 @MatGuid UNIQUEIDENTIFIER = 0x0,
			 @PoiGuid UNIQUEIDENTIFIER = 0x0,
			 @Number INT,
			 @Qty FLOAT = 0,
			 @BonusQty FLOAT = 0;

	DECLARE i CURSOR FOR SELECT BiGUid, MatGuid, biQty, bonusQty FROM #NewItem   
			OPEN i  
				FETCH NEXT FROM i INTO  @BiGuid,@MatGuid, @Qty, @BonusQty
				WHILE @@FETCH_STATUS = 0  
				BEGIN 
					SELECT @Number = MAX(Number) FROM ori000 WHERE POGUID = @OrderGuid
					SELECT @PoiGuid = biGUID FROM vwBi WHERE biParent = @OrderGuid AND biMatPtr = @MatGuid
					------------------------insert Negative Qty------------
					INSERT INTO ori000 (Number, GUID, POIGUID, Qty, Type, Date, Notes, POGUID, BuGuid, TypeGuid, BonusPostedQty, bIsRecycled, PostGuid, PostNumber, BiGuid )
					SELECT TOP 1 @Number, NEWID(), @PoiGuid, - @Qty, Type, Date, Notes, POGUID, BuGuid, TypeGuid, - @BonusQty, bIsRecycled, PostGuid, PostNumber, @BiGuid
						FROM 
						ori000 ori
						WHERE 
						ori.POGUID = @OrderGuid AND ori.PostGuid = @PostGuid AND (ori.Qty < 0 OR ori.BonusPostedQty < 0)
					ORDER BY Number DESC
					------------------------insert positive Qty-------------
					INSERT INTO ori000 (Number, GUID, POIGUID, Qty, Type, Date, Notes, POGUID, BuGuid, TypeGuid, BonusPostedQty, bIsRecycled, PostGuid, PostNumber, BiGuid)
					SELECT TOP 1 @Number , NEWID(), @PoiGuid, @Qty, Type, Date, Notes, POGUID, BuGuid, TypeGuid, @BonusQty, bIsRecycled, PostGuid, PostNumber, @BiGuid
						FROM 
						ori000 ori
						WHERE 
						ori.POGUID = @OrderGuid AND ori.PostGuid = @PostGuid AND (ori.Qty > 0 OR ori.BonusPostedQty > 0)
					ORDER BY Number DESC
				FETCH NEXT FROM i INTO  @BiGuid, @MatGuid, @Qty, @BonusQty
				END  
			CLOSE i  
			DEALLOCATE i
	----------- ÕœÌÀ «·ﬂ„Ì«  «·„—Õ·… ›Ì ÃœÊ· «· —ÕÌ·
	UPDATE
		 ori000 SET Qty = CASE WHEN Qty > 0 THEN bi2.biQty ELSE -bi2.biQty END,
		 BonusPostedQty = CASE WHEN BonusPostedQty > 0 THEN bi2.biBillBonusQnt ELSE 0 END,
		 Date = bi2.buDate ,
		 POIGUID = CASE WHEN bi1.biMatPtr = bi2.biMatPtr THEN POIGUID ELSE (SELECT biGUID FROM vwExtended_bi WHERE 
		 biMatPtr = bi2.biMatPtr AND buGuid = @OrderGuid) END
	FROM
		 #BillQty bi 
		 INNER JOIN ori000 ori ON bi.oriGuid = ori.GUID
		 INNER JOIN vwExtended_bi bi1 ON bi1.biGuid = ori.POIGUID  ---- √ﬁ·«„ «·ÿ·»Ì… 
		 LEFT JOIN vwExtended_bi bi2 ON bi2.biGUID = bi.biGuid  -- √ﬁ·«„ «·›« Ê—… «·„ Ê·œ… ⁄‰ «·ÿ·»Ì…
   -----------Õ–› «·√ﬁ·«„ «· Ì  „ Õ–›Â« „‰ «·›« Ê—… „‰ ÃœÊ· «· —ÕÌ·--------------
	DELETE FROM ori000 WHERE PostGuid = @PostGuid  AND ((POIGUID IS NULL) OR ori000.biGuid NOT IN (SELECT biGuid FROM vwExtended_bi WHERE buGUID = @BillGuid))

	EXEC prcUpdateOrdersPayments @BillGuid
#########################################################
CREATE PROCEDURE prcGetBillItems
	@PostGuid UNIQUEIDENTIFIER = 0x00,
    @OrderGuid UNIQUEIDENTIFIER = 0x00
 AS 
 	SET NOCOUNT ON 

	SELECT BiGuid AS Guid FROM ori000 WHERE PostGuid = @PostGuid AND POGUID = @OrderGuid
#########################################################
CREATE PROCEDURE prcDeletePostToTrans
	@PostGuid UNIQUEIDENTIFIER = 0x00,
    @OrderGuid UNIQUEIDENTIFIER = 0x00,
	@OutBillGuid UNIQUEIDENTIFIER = 0x00,
	@InBillGuid UNIQUEIDENTIFIER = 0x00
 AS 
 	SET NOCOUNT ON 

	DECLARE @InBillIsPosted BIT,
			@OutBillIsPosted BIT;
	
	SELECT @InBillIsPosted = buIsPosted FROM vwBu WHERE buGUID = @InBillGuid
	SELECT @OutBillIsPosted = buIsPosted FROM vwBu WHERE buGUID = @OutBillGuid
	
	IF(@InBillIsPosted = 1)
		EXECUTE [prcBill_Post1] @InBillGuid, 0
	IF(@OutBillIsPosted = 1)
		EXECUTE [prcBill_Post1] @OutBillGuid, 0

	-----Õ–› √ﬁ·«„ ›Ê« Ì— «·≈Œ—«Ã-------
	DELETE [SNT000]
    FROM 
		   [SNT000] 
	WHERE 
		 biGuid IN (SELECT biGuid FROM ori000 WHERE PostGuid = @PostGuid AND POGUID = @OrderGuid)
	DELETE FROM
		 bi000
	WHERE 
		 Guid IN (SELECT biGuid FROM ori000 WHERE PostGuid = @PostGuid AND POGUID = @OrderGuid)
	-----Õ–› √ﬁ·«„ ›Ê« Ì— «·≈œŒ«·-------
	DELETE [SNT000]
    FROM 
		   [SNT000] 
	WHERE 
		 biGuid IN (SELECT inBi.biGuid 
		          FROM 
					  vwBi outBi 
					  INNER JOIN ori000 ori ON ori.biGuid = outBi.biGuid
					  INNER JOIN vwBi inBi ON inBi.biNumber = outBi.biNumber
				  WHERE 
					  ori.PostGuid = @PostGuid AND ori.POGUID = @OrderGuid AND inBi.biParent = @InBillGuid)
	DELETE FROM
		 bi000
	WHERE 
		 Guid IN (SELECT inBi.biGuid 
		          FROM 
					  vwBi outBi 
					  INNER JOIN ori000 ori ON ori.biGuid = outBi.biGuid
					  INNER JOIN vwBi inBi ON inBi.biNumber = outBi.biNumber
				  WHERE 
					  ori.PostGuid = @PostGuid AND ori.POGUID = @OrderGuid AND inBi.biParent = @InBillGuid)

	 ---------------  ⁄œÌ· ﬁÌ„… ≈Ã„«·Ì ›« Ê—… «·≈Œ—«Ã --------------
	UPDATE 
		bu000 SET Total = bu.buTotal
	FROM
		(SELECT 
			bu.buGuid AS buGuid,
			SUM(bi.BiQty * (bi.biUnitPrice + bi.biUnitExtra - bi.biUnitDiscount) + bi.biVat) AS buTotal
		FROM
			vwBu bu
			INNER JOIN vwExtended_bi bi ON bi.buGUID = bu.buGuid 
		WHERE
			bu.buGuid = @OutBillGuid
	    GROUP BY
			bu.buGuid) bu
		WHERE
			Guid = bu.buGuid
 --------------- ⁄œÌ· ﬁÌ„… ≈Ã„«·Ì ›« Ê—… «·≈œŒ«·-------------
	UPDATE 
		bu000 SET Total = bu.buTotal
	FROM
		(SELECT 
			bu.buGuid AS buGuid,
			SUM(bi.BiQty * (bi.biUnitPrice + bi.biUnitExtra - bi.biUnitDiscount) + bi.biVat) AS buTotal
		FROM
			vwBu bu
			INNER JOIN vwExtended_bi bi ON bi.buGUID = bu.buGuid 
		WHERE
			bu.buGuid = @InBillGuid
	    GROUP BY
			bu.buGuid) bu
		WHERE
			Guid = bu.buGuid

	IF(@InBillIsPosted = 1)
		EXECUTE [prcBill_Post1] @InBillGuid, 1
	IF(@OutBillIsPosted = 1)
		EXECUTE [prcBill_Post1] @OutBillGuid, 1
#########################################################
#END