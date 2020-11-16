#########################################################################
CREATE PROCEDURE prcNeededMatsRep
-- PARAMETERS   
  @Mat            UNIQUEIDENTIFIER = 0x00,
  @Grp            UNIQUEIDENTIFIER = 0x00,
  @Cost           UNIQUEIDENTIFIER = 0x00,
  @Store          UNIQUEIDENTIFIER = 0x00,
  @StartDate      DATETIME = '01/01/1980',
  @EndDate        DATETIME = '12/30/2011',
  @UseUnit        INT = 1,
  @Option         INT = 1,
  @ShowAllReqMats BIT = 1,
  @OrderTypesSrc  UNIQUEIDENTIFIER = 0x00,
  @MatCond        UNIQUEIDENTIFIER = 0x00,
  @MatFldsFlag    BIGINT = 0,
  @MatCFlds       NVARCHAR (max) = ''
AS   
	SET NOCOUNT ON   

	---------------------    #OrderTypesTbl   ------------------------    
	-- ÌÏæá ÃäæÇÚ ÇáØáÈíÇÊ ÇáÊí Êã ÇÎÊíÇÑåÇ Ýí ÞÇÆãÉ ÃäæÇÚ ÇáØáÈÇÊ    
    CREATE TABLE #OrderTypesTbl
      (
		Type        UNIQUEIDENTIFIER,    
		Sec         INT,                  
		ReadPrice   INT,                  
         UnPostedSec INT
      )

    INSERT INTO #OrderTypesTbl
    EXEC prcGetBillsTypesList2
      @OrderTypesSrc

	-------------------------------------------------------------------   
	--  ÌÏæá ÇáãæÇÏ ÇáÊí ÊÍÞÞ ÇáÔÑæØ    
    CREATE TABLE #MatTbl
      (
    	MatGuid  UNIQUEIDENTIFIER,     
         Security INT
      )

    INSERT INTO #MatTbl
    EXEC prcGetMatsList
      @Mat,
      @Grp,
      -1,
      @MatCond

	-------------------------------------------------------------------   
	--	ÌÏæá ÇáãÓÊæÏÚÇÊ    
    DECLARE @StoreTbl TABLE
      (
         StoreGuid UNIQUEIDENTIFIER
      )

    INSERT INTO @StoreTbl
    SELECT Guid
    FROM   fnGetStoresList(@Store)

	-------------------------------------------------------------------    
	-- ÌÏæá ãÑÇßÒ ÇáßáÝÉ    
    DECLARE @CostTbl TABLE
      (
         CostGuid UNIQUEIDENTIFIER
      )
             
    INSERT INTO @CostTbl
    SELECT Guid
    FROM   fnGetCostsList(@Cost)

	IF ISNULL(@Cost, 0x0) = 0x0          
      INSERT INTO @CostTbl
      VALUES     (0x0)

	-------------------------------------------------------------------    
	-----------------------   #OrderedMats  ---------------------------    
	-- ÌÏæá ãæÇÏ ØáÈíÇÊ ÇáÈíÚ   
    SELECT ExBi.biGUID,
           ExBi.biMatPtr                                                       AS MatGuid,
           ( CASE ( dbo.fnConnections_GetLanguage() )
               WHEN 0 THEN ExBi.mtName
               ELSE ( CASE ExBi.mtLatinName
                        WHEN '' THEN ExBi.mtName
                        ELSE ExBi.mtLatinName
                      END )
             END )                                                             AS MatName,
           ( CASE @useUnit
               WHEN 1 THEN 1
               WHEN 2 THEN ( CASE ExBi.mtUnit2Fact
                               WHEN 0 THEN 1
                               ELSE 2
                             END )
               WHEN 3 THEN ( CASE ExBi.mtUnit3Fact
                               WHEN 0 THEN 1
                               ELSE 3
                             END )
					   ELSE ExBi.mtDefUnit 
             END )                                                             AS Unit,
           ( CASE @useUnit
               WHEN 1 THEN ExBi.mtUnity
               WHEN 2 THEN ( CASE ExBi.mtUnit2Fact
                               WHEN 0 THEN ExBi.mtUnity
                               ELSE ExBi.mtUnit2
                             END )
               WHEN 3 THEN ( CASE ExBi.mtUnit3Fact
                               WHEN 0 THEN ExBi.mtUnity
                               ELSE ExBi.mtUnit3
                             END )
					   ELSE ExBi.mtDefUnitName  
             END )                                                             AS UnitName,
           ( CASE @useUnit
               WHEN 1 THEN 1
               WHEN 2 THEN
                 CASE ExBi.mtUnit2Fact
                   WHEN 0 THEN 1
                   ELSE ExBi.mtUnit2Fact
                 END
               WHEN 3 THEN
                 CASE ExBi.mtUnit3Fact
                   WHEN 0 THEN 1
                   ELSE ExBi.mtUnit3Fact
                 END
                       ELSE ExBi.mtDefUnitFact  
             END )                                                             AS UnitFact,
           ( CASE @useUnit
               WHEN 1 THEN ExBi.biQty
               WHEN 2 THEN ExBi.biQty / ( CASE ExBi.mtUnit2Fact
                                            WHEN 0 THEN 1
                                            ELSE ExBi.mtUnit2Fact
                                          END )
               WHEN 3 THEN ExBi.biQty / ( CASE ExBi.mtUnit3Fact
                                            WHEN 0 THEN 1
                                            ELSE ExBi.mtUnit3Fact
                                          END )
                       ELSE ExBi.biQty / ExBi.mtDefUnitFact  
             END )                                                             AS OrderedQty,
           ISNULL((SELECT Sum(ISNULL(ORI.Qty, 0)) / ( CASE @useUnit
                                                        WHEN 1 THEN 1
                                                        WHEN 2 THEN
                                                          CASE ExBi.mtUnit2Fact
                                                            WHEN 0 THEN 1
                                                            ELSE ExBi.mtUnit2Fact
                                                          END
                                                        WHEN 3 THEN
                                                          CASE ExBi.mtUnit3Fact
                                                            WHEN 0 THEN 1
                                                            ELSE ExBi.mtUnit3Fact
                                                          END
										     ELSE ExBi.mtDefUnitFact  
                                                      END )
                   FROM   ori000 ORI
                   WHERE  ORI.POIGuid = ExBi.biGUID
                          AND ORI.TypeGuid = (SELECT TOP 1 OIT.Guid
                                              FROM   oit000 OIT
                                                     INNER JOIN oitvs000 OITVS
                                                             ON OIT.Guid = OITVS.ParentGuid
                                              WHERE  OITVS.OtGuid = ExBi.buType
                                                     AND OITVS.Selected = 1
                                                     AND OIT.Operation = 1
                                              ORDER  BY OIT.PostQty DESC)), 0) AS AcheivedQty,
		St.StoreGUID
    INTO   #SellMats
    FROM   vwExtended_bi AS ExBi
           INNER JOIN #OrderTypesTbl AS OTypes
                   ON ExBi.buType = OTypes.Type
           INNER JOIN #MatTbl AS Mats
                   ON ExBi.biMatPtr = Mats.MatGuid
           LEFT JOIN @CostTbl AS co
                  ON (( co.CostGuid = ( CASE ExBi.biCostPtr
                                          WHEN 0x00 THEN ExBi.buCostPtr
                                          ELSE ExBi.biCostPtr
                                        END ) )) --OR (co.CostGuid = ExBi.buCostPtr))
           INNER JOIN OrAddInfo000 AS Info
                   ON Info.ParentGuid = ExBi.buGUID
           LEFT JOIN @StoreTbl AS st
                  ON st.StoreGuid = ExBi.biStorePtr
    WHERE  ( ExBi.btType = 5 )
           AND ( ExBi.buDate BETWEEN @StartDate AND @EndDate )
           AND ( Info.Finished = 0 )
           AND ( Info.Add1 = '0' )
           AND ( ( @Store = st.StoreGuid )
                  OR ( @Store = 0x00 ) )
           AND ( ( @Cost = co.CostGuid )
                  OR ( @Cost = 0x00 ) )
           AND dbo.fnOrderApprovalState(EXbi.buGUID) IN ( 2, 3 ) -- 0 not approved, 1 partially approved, 2 fully approved, 3 No Approval Needed*/
			  
    SELECT s.MatGuid,
		s.MatName, 
		s.Unit, 
		s.UnitName, 
		s.UnitFact, 
           Sum(CASE
                 WHEN ( s.OrderedQty - s.AcheivedQty ) >= 0 THEN ( s.OrderedQty - s.AcheivedQty )
                 ELSE 0
               END) AS SumRemainedQty,
		s.StoreGUID
    INTO   #SellRemained
    FROM   #SellMats s
    GROUP  BY s.MatGuid,
		s.MatName, 
		s.Unit, 
		s.UnitName, 
		s.UnitFact,
		s.StoreGUID 

    DELETE FROM #SellRemained
    WHERE  SumRemainedQty = 0

	---------------------------------------------------------------------  	
	--SELECT * FROM #SellRemained
	--------------------------------------------------------------------- 
    SELECT ExBi.biGUID,
           ExBi.biMatPtr                                                       AS MatGuid,
           ( CASE ( dbo.fnConnections_GetLanguage() )
               WHEN 0 THEN ExBi.mtName
               ELSE ( CASE ExBi.mtLatinName
                        WHEN '' THEN ExBi.mtName
                        ELSE ExBi.mtLatinName
                      END )
             END )                                                             AS MatName,
           ( CASE @useUnit
               WHEN 1 THEN 1
               WHEN 2 THEN ( CASE ExBi.mtUnit2Fact
                               WHEN 0 THEN 1
                               ELSE 2
                             END )
               WHEN 3 THEN ( CASE ExBi.mtUnit3Fact
                               WHEN 0 THEN 1
                               ELSE 3
                             END )
					   ELSE ExBi.mtDefUnit 
             END )                                                             AS Unit,
           ( CASE @useUnit
               WHEN 1 THEN ExBi.mtUnity
               WHEN 2 THEN ( CASE ExBi.mtUnit2Fact
                               WHEN 0 THEN ExBi.mtUnity
                               ELSE ExBi.mtUnit2
                             END )
               WHEN 3 THEN ( CASE ExBi.mtUnit3Fact
                               WHEN 0 THEN ExBi.mtUnity
                               ELSE ExBi.mtUnit3
                             END )
					   ELSE ExBi.mtDefUnitName  
             END )                                                             AS UnitName,
           ( CASE @useUnit
               WHEN 1 THEN 1
               WHEN 2 THEN
                 CASE ExBi.mtUnit2Fact
                   WHEN 0 THEN 1
                   ELSE ExBi.mtUnit2Fact
                 END
               WHEN 3 THEN
                 CASE ExBi.mtUnit3Fact
                   WHEN 0 THEN 1
                   ELSE ExBi.mtUnit3Fact
                 END
                        ELSE ExBi.mtDefUnitFact  
             END )                                                             AS UnitFact,
           ( CASE @useUnit
               WHEN 1 THEN ExBi.biQty
               WHEN 2 THEN ExBi.biQty / ( CASE ExBi.mtUnit2Fact
                                            WHEN 0 THEN 1
                                            ELSE ExBi.mtUnit2Fact
                                          END )
               WHEN 3 THEN ExBi.biQty / ( CASE ExBi.mtUnit3Fact
                                            WHEN 0 THEN 1
                                            ELSE ExBi.mtUnit3Fact
                                          END )
                       ELSE ExBi.biQty / ExBi.mtDefUnitFact  
             END )                                                             AS OrderedQty,
           ISNULL((SELECT Sum(ISNULL(ORI.Qty, 0)) / ( CASE @useUnit
                                                        WHEN 1 THEN 1
                                                        WHEN 2 THEN
                                                          CASE ExBi.mtUnit2Fact
                                                            WHEN 0 THEN 1
                                                            ELSE ExBi.mtUnit2Fact
                                                          END
                                                        WHEN 3 THEN
                                                          CASE ExBi.mtUnit3Fact
                                                            WHEN 0 THEN 1
                                                            ELSE ExBi.mtUnit3Fact
                                                          END
										     ELSE ExBi.mtDefUnitFact  
                                                      END )
                   FROM   ori000 ORI
                   WHERE  ORI.POIGuid = ExBi.biGUID
                          AND ORI.TypeGuid = (SELECT TOP 1 OIT.Guid
                                              FROM   oit000 OIT
                                                     INNER JOIN oitvs000 OITVS
                                                             ON OIT.Guid = OITVS.ParentGuid
                                              WHERE  OITVS.OtGuid = ExBi.buType
                                                     AND OITVS.Selected = 1
                                                     AND OIT.Operation = 1
                                              ORDER  BY OIT.PostQty DESC)), 0) AS AcheivedQty,
           st.StoreGuid
    INTO   #PurchaseMats
    FROM   vwExtended_bi AS ExBi
           INNER JOIN #OrderTypesTbl AS OTypes
                   ON ExBi.buType = OTypes.Type
           INNER JOIN OrAddInfo000 AS Info
                   ON Info.ParentGuid = ExBi.buGUID
           INNER JOIN @StoreTbl AS st
                   ON st.StoreGuid = ExBi.biStorePtr
           LEFT JOIN @CostTbl AS co
                  ON (( co.CostGuid = ( CASE ExBi.biCostPtr
                                          WHEN 0x00 THEN ExBi.buCostPtr
                                          ELSE ExBi.biCostPtr
                                        END ) )) --OR (co.CostGuid = ExBi.buCostPtr))
    WHERE  ( ExBi.btType = 6 )
           AND ( Info.Finished = 0 )
           AND ( Info.Add1 = '0' )
           AND ( ExBi.biMatPtr IN (SELECT MatGuid
                                   FROM   #SellRemained) )
           AND ( ( @Store = st.StoreGuid )
                  OR ( @Store = 0x00 ) )
           AND ( ( @Cost = co.CostGuid )
                  OR ( @Cost = 0x00 ) )
           AND dbo.fnOrderApprovalState(EXbi.buGUID) IN ( 2, 3 ) -- 0 not approved, 1 partially approved, 2 fully approved, 3 No Approval Needed*/
					 
    SELECT p.MatGuid,
		p.MatName, 
		p.Unit, 
		p.UnitName, 
		p.UnitFact,		 
           Sum(p.OrderedQty - p.AcheivedQty) AS SumRemainedQty,
		p.StoreGuid
    INTO   #PurchaseRemained
    FROM   #PurchaseMats p
    GROUP  BY p.MatGuid,
		p.MatName, 
		p.Unit, 
		p.UnitName, 
              p.UnitFact,
		p.StoreGuid

    DELETE FROM #PurchaseRemained
    WHERE  SumRemainedQty = 0

	------------------------------------------------------------------- 
	--SELECT * FROM #PurchaseRemained
	-------------------------------------------------------------------
	SELECT 
			DISTINCT  biMatPtr AS MatGuid ,
			ISNULL(mtQty / mtDefUnitFact , 0)  AS Qty,
			mtUnitFact  As UnitFact
	INTO #MsTbl
	FROM 
		 vwExtended_bi ms
		INNER JOIN @StoreTbl st ON st.StoreGuid = ms.biStorePtr
	WHERE
		buDate BETWEEN @StartDate AND @EndDate
		AND btType = 1  
			 
	/*===============================================================*    
	 *                       R E S U L T S                           *    
	 *===============================================================*/	
    SELECT DISTINCT s.MatGuid,
		s.MatName, 
		s.Unit, 
		s.UnitFact, 
		s.UnitName, 
		(s.SumRemainedQty) AS SellRemainedQty,  
		(CASE WHEN ((ISNULL(p.SumRemainedQty, 0)>=0 )) THEN ( ISNULL(p.SumRemainedQty, 0)) ELSE 0 END)  AS PurchaseRemainedQty,
		(s.SumRemainedQty - ISNULL(p.SumRemainedQty, 0)) AS Diff, 
		 
		(CASE @Option  
			WHEN 1 THEN 0  
			WHEN 2 THEN mt.Low 
			WHEN 3 THEN mt.High 
			WHEN 4 THEN mt.OrderLimit 
		    ELSE 0 
                      END )                                                                                                          AS Limit,
                    ( s.SumRemainedQty - ISNULL(p.SumRemainedQty, 0) ) - Sum(ISNULL(ms.Qty * ms.UnitFact, 0) / s.UnitFact) + ( CASE @Option
			WHEN 1 THEN 0  
			WHEN 2 THEN mt.Low 
			WHEN 3 THEN mt.High 
			WHEN 4 THEN mt.OrderLimit 
                                                                                                                                 WHEN 5 THEN Sum(ISNULL(ms.Qty, 0))
		    ELSE 0 
                                                                                                                               END ) AS LackQty,
                    mt.Code                                                                                                          AS MatFldCode,
                    mt.LatinName                                                                                                     AS MatFldLatinName,
                    mt.BarCode                                                                                                       AS MatFldBarCode,
                    mt.Type                                                                                                          AS MatFldType,
                    mt.Dim                                                                                                           AS MatFldDim,
                    mt.Company                                                                                                       AS MatFldCompany,
                    mt.Color                                                                                                         AS MatFldColor,
                    mt.Provenance                                                                                                    AS MatFldProvenance,
                    mt.Quality                                                                                                       AS MatFldQuality,
                    mt.Model                                                                                                         AS MatFldModel,
                    mt.BarCode2                                                                                                      AS MatFldBarCode2,
                    mt.BarCode3                                                                                                      AS MatFldBarCode3,
                    mt.GroupGUID                                                                                                     AS MatFldGroup,
                    mt.Origin                                                                                                        AS MatFldOrigin
    INTO   #ResultUnAgg
    FROM   #SellRemained s
           LEFT JOIN #PurchaseRemained p
                  ON s.MatGuid = p.matguid
           INNER JOIN mt000 mt
                   ON s.MatGuid = mt.GUID
           LEFT JOIN #MsTbl ms
                  ON s.MatGuid = ms.MatGuid
           LEFT JOIN @StoreTbl st
                  ON ST.StoreGUID = s.StoreGuid
    WHERE  ( ( @Store = st.StoreGuid )
              OR ( @Store = 0x00 ) )
    GROUP  BY s.MatGuid,
		s.MatName, 
		s.Unit, 
		s.UnitFact, 
		s.UnitName, 
		s.SumRemainedQty, 
		p.SumRemainedQty, 
		mt.Low, 
		mt.High, 
		mt.OrderLimit,
		st.StoreGUID,
		mt.BarCode3,
		mt.BarCode2, 
		mt.Model,
              mt.Quality,
		mt.Provenance,
              mt.Code,
              mt.LatinName,
              mt.BarCode,
              mt.Type,
              mt.Dim,
              mt.Company,
		mt.Color,
		mt.GroupGUID, 
		mt.Origin
		   
		------------------------------------------------ 
		-- SELECT * FROM #ResultUnAgg 		
		------------------------------------------------
    SELECT DISTINCT MatGuid,
		MatName, 
		Unit, 
		UnitFact, 
		UnitName, 
                    Sum(SellRemainedQty)     AS SellRemainedQty,
		Sum(PurchaseRemainedQty) AS PurchaseRemainedQty,
		Sum(Diff) AS Diff, 
		Limit, 
                    Sum(LackQty)             AS LackQty,
		MatFldCode,
		MatFldLatinName,
		MatFldBarCode,
		MatFldType,
		MatFldDim,
		MatFldCompany,
		MatFldColor,
		MatFldProvenance,
		MatFldQuality,
		MatFldModel,
		MatFldBarCode2,
		MatFldBarCode3,
		MatFldGroup,
		MatFldOrigin
    INTO   #final
    FROM   #ResultUnAgg
    GROUP  BY MatGuid,
		MatName, 
		Unit, 
		UnitFact, 
		UnitName,	
		Limit,	
		MatFldCode,
		MatFldLatinName,
		MatFldBarCode,
		MatFldType,
		MatFldDim,
		MatFldCompany,
		MatFldColor,
		MatFldProvenance,
		MatFldQuality,
		MatFldModel,
		MatFldBarCode2,
		MatFldBarCode3,
		MatFldGroup,
		MatFldOrigin
		
    IF( @ShowAllReqMats = 0 )
	BEGIN
		DELETE FROM #FINAL	
          WHERE  LackQty <= 0
	END		 
	EXEC GetMatFlds @MatFldsFlag, @MatCFlds 
	SELECT  
		f.MatGuid,f.MatName,f.Unit,f.UnitFact,f.UnitName,f.SellRemainedQty,f.PurchaseRemainedQty,f.Diff,r.Qty As StoreQty,f.Limit,f.LackQty,  
		m.MatFldGuid,
		f.MatFldCode,
		f.MatFldLatinName,
		f.MatFldBarCode,
		f.MatFldType,
		f.MatFldDim,
		f.MatFldCompany,
		f.MatFldColor,
		f.MatFldProvenance,
		f.MatFldQuality,
		f.MatFldModel,
		f.MatFldBarCode2,
		f.MatFldBarCode3,
		f.MatFldOrigin,
		gr.Name as MatFldGroup	 
	FROM  
		#final f  
		INNER JOIN ##MatFlds m on m.MatFldGuid = f.MatGuid 
		INNER JOIN #MsTbl r ON r.MatGuid = f.MatGuid
		inner join gr000 gr on  f.MatFldGroup=gr.GUID
	ORDER BY f.MatName 

#########################################################################
#END
