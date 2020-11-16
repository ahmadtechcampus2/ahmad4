################################################################################
CREATE PROCEDURE repManufCostMatCostCross
(
	@MatGuid UNIQUEIDENTIFIER = 0x0      ,
	@GrpGuid UNIQUEIDENTIFIER = 0x0      ,
	@CostGuid UNIQUEIDENTIFIER = 0x0	 ,
	@SrcTypesguid UNIQUEIDENTIFIER = 'A56F530D-846B-4C4B-801C-BFBF0DB78148', 
	@WithOutCostCenter INT  = 1,
	@UseUnit		   INT  = 1 , 
	@SortType			INT = 1 , 
	@FromDate DATETIME = '1-1-1980'      ,
	@ToDate DATETIME   = '1-1-2070'      ,
	@ShowTotal INT =1                    ,
	@WithSpecificCostCenter INT =1  
)
AS
SET NOCOUNT ON 

   IF  @WithOutCostCenter = 1 AND @WithSpecificCostCenter= 0
		EXEC prc_repManufWithOutCostCenter
			@MatGuid ,@GrpGuid,@CostGuid, @SrcTypesguid, @WithOutCostCenter, @UseUnit, @SortType, @FromDate,  @ToDate, @ShowTotal

   IF  @WithSpecificCostCenter= 1 AND  @WithOutCostCenter = 1
		EXEC prc_repManufWithCostCenter
			@MatGuid ,@GrpGuid,@CostGuid, @SrcTypesguid, @WithOutCostCenter, @UseUnit, @SortType, @FromDate,  @ToDate, @ShowTotal

   IF  @WithOutCostCenter = 0 
		EXEC prc_repManufWithCostCenter
			@MatGuid ,@GrpGuid,@CostGuid, @SrcTypesguid, @WithOutCostCenter, @UseUnit, @SortType, @FromDate,  @ToDate, @ShowTotal
################################################################################
CREATE PROCEDURE prc_repManufWithCostCenter
(
       @MatGuid UNIQUEIDENTIFIER = 0x0      ,
       @GrpGuid UNIQUEIDENTIFIER = 0x0      ,
       @CostGuid UNIQUEIDENTIFIER = 0x0  ,
       @SrcTypesguid UNIQUEIDENTIFIER = 'A56F530D-846B-4C4B-801C-BFBF0DB78148', 
       @WithOutCostCenter INT  = 1,
       @UseUnit                INT  = 1 , 
       @SortType                  INT = 1 , 
       @FromDate DATETIME = '1-1-1980'      ,
       @ToDate DATETIME   = '1-1-2070'     ,
       @ShowTotal INT =1 
)
AS
SET NOCOUNT ON 
	DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();
    SELECT GUID INTO #CostList from dbo.fnGetCostsList(@CostGuid)
       IF(@WithOutCostCenter = 1 AND ISNULL(@CostGuid, 0x0) = 0x0)
		INSERT INTO #CostList VALUES(@CostGuid)

		CREATE TABLE #MYRESULT
			(   Sort INT ,
			   CostName [NVARCHAR](255)  COLLATE Arabic_CI_AI , 
			   MatName [NVARCHAR](255)  COLLATE Arabic_CI_AI,
			   MatGuid uniqueidentifier,
			   MatCode [NVARCHAR](255)  COLLATE Arabic_CI_AI ,
		       MatUnit [NVARCHAR](255)  COLLATE Arabic_CI_AI,
			   StandardPrice FLOAT, 
			   StandardQty FLOAT, 
			   StandardValue FLOAT, 
			   ActualPrice FLOAT, 
			   ActualQty FLOAT, 
			   ActualValue FLOAT,
			   DefRQty FLOAT,
			   DefRPrice FLOAT
			)		   
	 SELECT 
            a.CostGuid
            , a.MatGuid
            , a.[CostName]
            , a.[MatName],a.[MatCode]
            , a.Ac_Qty
            , CASE a.Ac_Qty WHEN 0 THEN 0 ELSE (a.Ac_Total / a.Ac_Qty) END as Ac_Price 
            , a.Ac_Total
            ,1 AS Sort
	    ,0 AS DefRQty
	    ,0 AS DefRPrice
       INTO #ACTUAL_HSH
       FROM
       (
              SELECT 
                       q.CostGuid,
                       q.MatGuid,
                       q.CostName,
                       q.MatName,q.MatCode,
                       SUM(q.Ac_Qty)            Ac_Qty,
                       SUM(q.Ac_Qty * q.Price) Ac_Total
              FROM
              (
                     SELECT  
                            bu.CostGuid AS CostGuid 
                            , mt.Guid AS MatGuid
			    ,'NOCOSTCENTER' AS CostName
                            , CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END AS MatName, mt.Code AS MatCode
                            , -1 * (bi.QTY * ( CASE billTypes.BillType 
							WHEN 0 THEN  1 --ãÔÊÑíÇÊ
							WHEN 1 THEN -1 --ãÈíÚÇÊ
							WHEN 2 THEN -1 --ãÑÊÌÚ ãÔÊÑíÇÊ
							WHEN 3 THEN  1 --ãÑÊÌÚ ãÈíÚÇÊ
							WHEN 4 THEN  1 --ÇÏÎÇá
							WHEN 5 THEN -1 --ÇÎÑÇÌ
							ELSE 0 
						END  
					      )
				    ) as Ac_Qty
			    , bi.Price / CASE Bi.Unity When 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END Price
                            , billTypes.BillType
                      FROM 
			bt000 billTypes
			     INNER JOIN bu000 bu  ON bu.[TypeGUID]   = billTypes.[GUID]
			     INNER JOIN bi000 bi  ON bi.[ParentGUID] = bu.[GUID]
			     INNER JOIN mt000 mt  ON mt.[GUID]    = bi.[MatGUID]
			     INNER JOIN dbo.fnGetGroupsList (@GrpGuid) gr  ON gr.[GUID]    = mt.[GroupGUID]
			     INNER JOIN [RepSrcs]  bt  ON bt.[idType] = bu.[TypeGUID]
                      WHERE  billTypes.[Type] = 1 
			    AND 
			    bu.[Date] >= @FromDate 
			    AND 
			    bu.[Date] <= @ToDate  
			    AND 
			    [bt].IdTbl = @SrcTypesguid
			    AND 
			    ISNULL(bu.CostGuid, 0x0 ) = 0x0 AND  IsNULL(@CostGuid , 0x0) = 0x0
              )q
              GROUP BY q.CostGuid , q.MatGuid , q.CostName , q.MatName, q.MatCode
       ) a 
 UNION 
       SELECT 
	       a.CostGuid
	     , a.MatGuid
	     , a.[CostName]
	     , a.[MatName],a.[MatCode]
	     , a.Ac_Qty
	     , CASE a.Ac_Qty WHEN 0 THEN 0 ELSE (a.Ac_Total / a.Ac_Qty) END as Ac_Price 
	     , a.Ac_Total
	     ,2 AS Sort
	     ,0 AS DefRQty
	     ,0 AS DefRPrice
       FROM
       (
              SELECT 
                       q.CostGuid,
                       q.MatGuid,
                       q.CostName,
                       q.MatName,q.MatCode,
                       SUM(q.Ac_Qty)            Ac_Qty,
                       SUM(q.Ac_Qty * q.Price) Ac_Total
              FROM
              (
                      SELECT    
			    co.GUID AS CostGuid 
                            ,mt.Guid AS MatGuid
                            ,CASE WHEN @Lang > 0 THEN CASE WHEN co1.LatinName = ''  THEN co1.Name ELSE co1.LatinName END ELSE co1.Name END AS CostName
                            ,CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END AS MatName, mt.Code AS MatCode
                            ,-1 * (bi.QTY * ( CASE billTypes.BillType 
							WHEN 0 THEN  1 --ãÔÊÑíÇÊ
							WHEN 1 THEN -1 --ãÈíÚÇÊ
							WHEN 2 THEN -1 --ãÑÊÌÚ ãÔÊÑíÇÊ
							WHEN 3 THEN  1 --ãÑÊÌÚ ãÈíÚÇÊ
							WHEN 4 THEN  1 --ÇÏÎÇá
							WHEN 5 THEN -1 --ÇÎÑÇÌ
							ELSE 0 
                                                END  )
				  ) as Ac_Qty
			    ,bi.Price / CASE Bi.Unity When 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END Price
			    ,billTypes.BillType
                     FROM bt000 billTypes
                     INNER JOIN bu000 bu  ON bu.[TypeGUID]   = billTypes.[GUID]
                     INNER JOIN bi000 bi  ON bi.[ParentGUID] = bu.[GUID]
                     INNER JOIN #CostList co  ON co.[GUID]    = bu.[CostGUID] OR co.[GUID] = bi.[CostGUID]
                     INNER JOIN co000  co1 ON co1.[GUID]   = co.[Guid]
                     INNER JOIN mt000   mt  ON mt.[GUID]    = bi.[MatGUID]
                     INNER JOIN dbo.fnGetGroupsList (@GrpGuid) gr  ON gr.[GUID]    = mt.[GroupGUID]
                     INNER JOIN [RepSrcs] bt  ON bt.[idType] = bu.[TypeGUID]
                     WHERE  billTypes.[Type] = 1 
			   AND 
			    bu.[Date] >= @FromDate 
			   AND 
			   bu.[Date] <= @ToDate  
			   AND 
			   [bt].IdTbl = @SrcTypesguid
              )q
              GROUP BY q.CostGuid , q.MatGuid , q.CostName , q.MatName, q.MatCode
	) a

      

       SELECT   
	       a.CostGuid
	     , a.MatGuid
	     , a.[CostName]
	     , a.[MatName], a.[MatCode]
	     , a.STNDR_Qty
	     , (a.STNDR_Total / a.STNDR_Qty) as STNDR_Price
	     , a.STNDR_Total
	     , 1  AS Sort
	     ,0 AS DefRQty
	     ,0 AS DefRPrice
       INTO #STANDARD_HSH
       FROM
       (
       SELECT *  FROM(      
              SELECT  
                     bu.CostGuid AS CostGuid 
                     , mt.Guid AS MatGuid
                     ,'NOCOSTCENTER' AS CostName
                     , CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END AS MatName,mt.Code AS MatCode
                     , SUM(bi.Qty) as STNDR_Qty
                     , SUM(bi.Qty * bi.Price / CASE Bi.Unity When 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END) as STNDR_Total 
              FROM bt000 billTypes
              INNER JOIN bu000 bu ON bu.[TypeGUID] = billTypes.[GUID]
              INNER JOIN bi000 bi ON bi.[ParentGUID] = bu.[GUID]
              INNER JOIN mt000 mt ON mt.[GUID] = bi.[MatGUID]
              INNER JOIN dbo.fnGetGroupsList (@GrpGuid)  gr ON gr.[GUID] = mt.[GroupGUID]
              INNER JOIN [RepSrcs] bt ON bt.[idType] = bu.[TypeGUID]
              WHERE  
                      billTypes.BillType = 5 
		      AND 
		      billTypes.[Type] = 2 
		      AND 
		      bu.[Date] >= @FromDate 
		      AND 
		      bu.[Date] <= @ToDate  
		      AND 
		      [bt].IdTbl = @SrcTypesguid 
                      AND 
		      IsNULL(bu.CostGuid , 0x0) = 0x0 AND  IsNULL(@CostGuid , 0x0) = 0x0
              GROUP BY             
                     bu.CostGuid,
                     mt.Guid ,
                     CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END,mt.Code
			) as k
		GROUP BY 
                     k.CostGuid,
                     k.MatGuid ,
                     k.CostName,
                     k.MatName,
		     K.MatCode,
                     STNDR_Qty,
                     STNDR_Total
       ) a
       UNION 
       SELECT 
	       a.CostGuid
	     , a.MatGuid
	     , a.[CostName]
	     , a.[MatName],a.[MatCode]
	     , a.STNDR_Qty
	     , (a.STNDR_Total / a.STNDR_Qty) as STNDR_Price
	     , a.STNDR_Total
	     ,2 AS Sort
	     ,0 AS DefRQty
	    ,0 AS DefRPrice
       FROM
       (
              SELECT   
		     co.GUID AS CostGuid 
		     , mt.Guid AS MatGuid
		     , CASE WHEN @Lang > 0 THEN CASE WHEN co1.LatinName = ''  THEN co1.Name ELSE co1.LatinName END ELSE co1.Name END AS CostName
		     , CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END AS MatName,mt.Code AS MatCode
		     , SUM(bi.Qty) as STNDR_Qty
		     , SUM(bi.Qty * bi.Price / CASE Bi.Unity When 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END) as STNDR_Total 
              FROM bt000 billTypes
              INNER JOIN bu000 bu ON bu.[TypeGUID] = billTypes.[GUID]
              INNER JOIN bi000 bi ON bi.[ParentGUID] = bu.[GUID]
              INNER JOIN #CostList  co  ON co.[GUID]  = bu.[CostGUID] 
              INNER JOIN co000  co1 ON co1.[GUID] = co.[Guid]
              INNER JOIN mt000 mt  ON mt.[GUID] = bi.[MatGUID]
              INNER JOIN dbo.fnGetGroupsList (@GrpGuid)  gr ON gr.[GUID] = mt.[GroupGUID]
              INNER JOIN [RepSrcs] bt ON bt.[idType] = bu.[TypeGUID]
              WHERE  
			billTypes.BillType = 5 
			AND 
			billTypes.[Type] = 2 
			AND 
			bu.[Date] >= @FromDate 
			AND 
			bu.[Date] <= @ToDate 
			AND
			[bt].IdTbl = @SrcTypesguid
              GROUP BY co.[GUID] , mt.[GUID] , CASE WHEN @Lang > 0 THEN CASE WHEN co1.LatinName = ''  THEN co1.Name ELSE co1.LatinName END ELSE co1.Name END , CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END,mt.Code
       ) a
       
     
	SELECT  CostGuid
		, MatGuid
		, [CostName]
		, [MatName]
		, [MatCode]
		, [Sort]
		, [DefRQty]
		, [DefRPrice]
        INTO #allMat
        FROM #ACTUAL_HSH 
	
        UNION
        SELECT  CostGuid
                , MatGuid
                , [CostName]
                , [MatName]
		, [MatCode]
                , [Sort]
		, [DefRQty]
		, [DefRPrice]
        FROM #STANDARD_HSH
       
       

       SELECT  
	     a.CostName,
	     a.MatName,
	     a.MatGuid,
	     a.MatCode,
	     ISNULL(STNDR.STNDR_Price, 0) AS StandardPrice,
	     ISNULL(STNDR.STNDR_Qty ,0) AS StandardQty,
	     ISNULL(STNDR.STNDR_Total,0) AS StandardValue,
	     0 AS ActualPrice,
	     0 AS ActualQty,
	     0 AS ActualValue,
	     a.Sort ,
	     0 AS DefRQty,
	     0 AS DefRPrice
       INTO #RESULT
       FROM #allMat a
       LEFT JOIN #STANDARD_HSH STNDR ON a.CostGuid = STNDR.CostGuid AND a.MatGuid = STNDR.MatGuid

       UNION 

       SELECT  
		a.CostName,
		a.MatName,
		a.MatGuid,
		a.MatCode,
		0,
		0,
		0,
		ISNULL(Ac.Ac_Price ,0) AS ActualPrice,                
		ISNULL(Ac.Ac_Qty ,0) AS ActualQty,
		ISNULL(Ac.Ac_Total ,0) AS ActualValue,
		a.Sort,
		0 AS DefRQty,
		0 AS DefRPrice
       FROM #allMat a
       LEFT JOIN #ACTUAL_HSH Ac  ON a.CostGuid = Ac.CostGuid AND a.MatGuid = Ac.MatGuid
       
              
     IF (@ShowTotal = 1 ) 
     BEGIN
        INSERT INTO #RESULT
	  SELECT  'IDS_THETOTAL' CostName,
               res.MatName,res.MatGuid,res.MatCode,
               (CASE SUM(res1.StandardQty) WHEN 0 THEN 0 ELSE SUM(res.StandardValue) / SUM(res1.StandardQty) END) AS StandardPrice, 
               0 AS StandardQty,
               0 AS StandardValue,
               0 AS ActualPrice,                
               0 AS ActualQty,
               0 AS ActualValue,
               3 ,
	       0 AS DefRQty,
	       0 AS DefRPrice
         FROM 
	   #RESULT res  INNER JOIN #RESULT res1 on res.CostName = res1.CostName and res.MatName = res1.MatName
        GROUP BY res.MatName, res.MatGuid, res.MatCode
	   
        UNION
        SELECT  
	     'IDS_THETOTAL' CostName,
	     MatName,MatGuid,MatCode,
	     0 AS StandardPrice,
	     SUM(res.StandardQty) AS StandardQty,
	     0 AS StandardValue,
	     0 AS ActualPrice,                
	     0 AS ActualQty,
	     0 AS ActualValue,
	     3 ,
	     0 AS DefRQty,
	     0 AS DefRPrice
       FROM #RESULT res
       GROUP BY res.MatName, res.MatGuid, res.MatCode

        UNION
        SELECT  
	     'IDS_THETOTAL' CostName,
	     MatName,MatGuid,MatCode,
	     0 AS StandardPrice,
	     0 AS StandardQty,
	     SUM(res.StandardValue) AS StandardValue,
	     0 AS ActualPrice,                
	     0 AS ActualQty,
	     0 AS ActualValue,
	     3 ,
	     0 AS DefRQty,
	     0 AS DefRPrice
	FROM #RESULT res
        GROUP BY res.MatName, res.MatGuid, res.MatCode
	
        UNION
        SELECT  
	     'IDS_THETOTAL' CostName,
	     MatName,MatGuid,MatCode,
	     0 AS StandardPrice,
	     0 AS StandardQty,
	     0 AS StandardValue,
	     0 AS ActualPrice,                
	     SUM(res.ActualQty) AS ActualQty,
	     0 AS ActualValue,
	     3 ,
	     0 AS DefRQty,
	     0 AS DefRPrice
        FROM #RESULT res
        GROUP BY res.MatName, res.MatGuid, res.MatCode
       
        UNION
        SELECT
		'IDS_THETOTAL' CostName,
                res.MatName,res.MatGuid,res.MatCode,
                0 AS StandardPrice,
                0 AS StandardQty,
                0 AS StandardValue,
                (CASE SUM(res1.ActualQty) WHEN 0 THEN 0 ELSE SUM(res.ActualValue) / SUM(res1.ActualQty) END) AS ActualPrice,
                0 AS ActualQty,
                0 AS ActualValue,
                3 ,
		0 AS DefRQty,
		0 AS DefRPrice
        FROM #RESULT res  INNER JOIN #RESULT res1 ON res.CostName = res1.CostName AND res.MatName = res1.MatName
        GROUP BY res.MatName, res.MatGuid, res.MatCode
       
        UNION
        SELECT  
	      'IDS_THETOTAL' CostName,
	      MatName,MatGuid,MatCode,
	      0 AS StandardPrice,
	      0 AS StandardQty,
	      0 AS StandardValue,
	      0 AS ActualPrice,                
	      0 AS ActualQty,
	      SUM(res.ActualValue) AS ActualValue,
	      3 ,
	      0 AS DefRQty,
	      0 AS DefRPrice
        FROM #RESULT res
        GROUP BY res.MatName, res.MatGuid, res.MatCode
       
        UNION
        SELECT  
	      'IDS_THETOTAL' CostName,
	      MatName,MatGuid,MatCode,
	      0 AS StandardPrice,
	      0 AS StandardQty,
	      0 AS StandardValue,
	      0 AS ActualPrice,                
	      0 AS ActualQty,
	      0 AS ActualValue,
	      3 ,
	      ( (SUM(Res.ActualQty) - SUM(Res.StandardQty)) * 
				(CASE SUM(Res.StandardQty) WHEN 0 THEN 0 ELSE (SUM(Res.StandardValue) / SUM(Res.StandardQty)) END)
				 )as  DefRQty,
	     0 AS DefRPrice
        FROM #RESULT res
        GROUP BY res.MatName, res.MatGuid, res.MatCode
       
	UNION
        SELECT  
                      'IDS_THETOTAL' CostName,
                     MatName,MatGuid,MatCode,
                     0 AS StandardPrice,
                     0 AS StandardQty,
                     0 AS StandardValue,
                     0 AS ActualPrice,                
                      0 AS ActualQty,
                     0 AS ActualValue,
                     3 ,
		     0 AS DefRQty,
		     ((
			(CASE SUM(Res.StandardQty) WHEN 0 THEN 0 ELSE (SUM(Res.StandardValue) / SUM(Res.StandardQty)) END)
			- (CASE SUM(Res.ActualQty) WHEN 0 then 0 ELSE (SUM(Res.ActualValue) / SUM(Res.ActualQty))  END)
		        )
			 * SUM(Res.ActualQty)
		     ) as DefRPrice
        FROM #RESULT res
        GROUP BY res.MatName, res.MatGuid, res.MatCode
     END



       CREATE TABLE #TOTALRESULT
              (Sort int , CostName VARCHAR(256) COLLATE ARABIC_CI_AI, AllStandardPrice FLOAT, 
              AllStandardQty FLOAT, AllStandardValue FLOAT ,
              AllActualPrice FLOAT,AllActualQty FLOAT,
              AllActualValue FLOAT, DefRQty FLOAT, DefRPrice FLOAT  )
       
       UPDATE #RESULT SET StandardQty = Res.StandardQty / CASE @UseUnit  
							   WHEN 0 THEN 1 
                                                           WHEN 1 THEN (CASE Mt.Unit2Fact WHEN  0 THEN (CASE Mt.DefUnit WHEN 1 THEN 1 WHEN 3 THEN Mt.Unit3Fact END)  ELSE Mt.Unit2Fact END)
                                                           WHEN 2 THEN (CASE Mt.Unit3Fact WHEN  0 THEN (CASE Mt.DefUnit WHEN 1 THEN 1 WHEN 2 THEN Mt.Unit2Fact END)  ELSE Mt.Unit3Fact END)
                                                           ELSE 
                                                             CASE Mt.DefUnit WHEN 1 THEN 1 WHEN 2 THEN Mt.Unit2Fact WHEN 3 THEN Mt.Unit3Fact END 
                                                          END
       FROM #RESULT Res INNER JOIN  #allMat a ON Res.MatName = a.MatName 
			INNER JOIN mt000 Mt ON mt.Guid = a.MatGuid

       UPDATE #RESULT SET ActualQty = Res.ActualQty / CASE @UseUnit  
							WHEN 0 THEN 1 
							WHEN 1 THEN (CASE Mt.Unit2Fact WHEN  0 THEN (CASE Mt.DefUnit WHEN 1 THEN 1 WHEN 3 THEN Mt.Unit3Fact END)  ELSE Mt.Unit2Fact END)
							WHEN 2 THEN (CASE Mt.Unit3Fact WHEN  0 THEN (CASE Mt.DefUnit WHEN 1 THEN 1 WHEN 2 THEN Mt.Unit2Fact END)  ELSE Mt.Unit3Fact END)
                                                        ELSE 
                                                           CASE Mt.DefUnit WHEN 1 THEN 1 WHEN 2 THEN Mt.Unit2Fact WHEN 3 THEN Mt.Unit3Fact END 
                                                      END
	FROM #RESULT Res INNER JOIN  #allMat a ON Res.MatName = a.MatName 
			INNER JOIN mt000 Mt ON Mt.Guid = a.MatGuid

	   

       IF(ISNULL(@MatGuid, 0x0) <> 0x0) 
        BEGIN
              INSERT INTO #MYRESULT
              SELECT   Res.Sort AS Sort ,
		       Res.CostName AS CostName ,
		       Res.MatName AS MatName,mt.Guid AS MatGuid, mt.Code AS MatCode,
                       ISNULL(
                           CASE @UseUnit 
                                  WHEN 0 THEN mt.Unity
                                  WHEN 1 THEN CASE mt.Unit2 WHEN  '' THEN mtV.mtDefUnitName  ELSE mt.Unit2 END
                                  WHEN 2 THEN CASE mt.Unit3 WHEN  '' THEN mtV.mtDefUnitName ELSE mt.Unit3 END 
                                  ELSE mtV.mtDefUnitName    
                           END, '') AS MatUnit , 
                       (CASE SUM(Res.StandardQty) WHEN 0 THEN 0 ELSE (SUM(Res.StandardValue) / SUM(Res.StandardQty)) END) StandardPrice, 
                       SUM(Res.StandardQty) StandardQty, 
                       SUM(Res.StandardValue) StandardValue, 
                       (CASE SUM(Res.ActualQty) WHEN 0 then 0 ELSE (SUM(Res.ActualValue) / SUM(Res.ActualQty))  END) ActualPrice, 
                       SUM(Res.ActualQty) ActualQty, 
                       SUM(Res.ActualValue) ActualValue,
                       (( (SUM(Res.ActualQty)) - SUM(Res.StandardQty)) * 
				(CASE SUM(Res.StandardQty) WHEN 0 THEN 0 ELSE (SUM(Res.StandardValue) / SUM(Res.StandardQty)) END)
			)as  DefRQty,
			((CASE SUM(Res.ActualQty) WHEN 0 then 0 ELSE (SUM(Res.ActualValue) / SUM(Res.ActualQty))  END)
			- (CASE SUM(Res.StandardQty) WHEN 0 THEN 0 ELSE (SUM(Res.StandardValue) / SUM(Res.StandardQty)) END)
			* SUM(Res.ActualQty)) as DefRPrice
	     FROM #RESULT Res INNER JOIN mt000 mt ON mt.Guid = @MatGuid AND Res.MatName = CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END
                              INNER JOIN vwmt mtV ON @MatGuid = mtV.mtGuid
             WHERE  @MatGuid = mt.Guid
             GROUP BY Res.CostName, Res.MatName, mt.Guid,mt.Code, mt.Unity, mtV.mtDefUnitName, mt.Unit2, mt.Unit3,Res.Sort
        END
              
        ELSE 
        BEGIN
             INSERT INTO #MyRESULT
              SELECT  Res.Sort AS Sort, 
		      Res.CostName AS CostName,
		      Res.MatName AS MatName, 
		      mt.Guid AS MatGuid, 
		      mt.Code AS MatCode,
                      ISNULL(
                           CASE @UseUnit 
                                  WHEN 0 THEN mt.Unity
                                  WHEN 1 THEN CASE mt.Unit2 WHEN  '' THEN mtV.mtDefUnitName  ELSE mt.Unit2 END
                                  WHEN 2 THEN CASE mt.Unit3 WHEN  '' THEN mtV.mtDefUnitName ELSE mt.Unit3 END 
                                  ELSE mtV.mtDefUnitName    
                           END, '') AS MatUnit, 
                      (CASE SUM(Res.StandardQty) WHEN 0 THEN 0 ELSE (SUM(Res.StandardValue) / SUM(Res.StandardQty)) END) StandardPrice, 
                      SUM(Res.StandardQty) StandardQty, 
                      SUM(Res.StandardValue) StandardValue, 
                      (CASE SUM(Res.ActualQty) WHEN 0 then 0 ELSE (SUM(Res.ActualValue) / SUM(Res.ActualQty))  END) ActualPrice, 
                      SUM(Res.ActualQty) ActualQty, 
                      SUM(Res.ActualValue) ActualValue,
                      (( SUM(Res.ActualQty) - SUM(Res.StandardQty)) * 
			(CASE SUM(Res.StandardQty) WHEN 0 THEN 0 ELSE (SUM(Res.StandardValue) / SUM(Res.StandardQty)) END)) AS  DefRQty,
		     ((CASE SUM(Res.ActualQty) WHEN 0 then 0 ELSE (SUM(Res.ActualValue) / SUM(Res.ActualQty))  END)
			- (CASE SUM(Res.StandardQty) WHEN 0 THEN 0 ELSE (SUM(Res.StandardValue) / SUM(Res.StandardQty)) END)
			* SUM(Res.ActualQty)) as DefRPrice
	      FROM #RESULT Res 
                     INNER JOIN mt000 mt ON  Res.MatName = CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END 
                     INNER JOIN vwmt mtV ON mt.Guid = mtV.mtGuid
             GROUP BY Res.CostName, 
                      Res.MatName, 
		      mt.Guid,
		      mt.Code, 
		      mt.Unity, 
		      mtV.mtDefUnitName, 
		      mt.Unit2, 
		      mt.Unit3,
		      Res.Sort
        END

        IF (ISNULL(@MatGuid, 0x0) <> 0x0)
        BEGIN
              INSERT INTO #TOTALRESULT
              SELECT  Res.sort,
                      Res.CostName AS CostName,
                      (CASE SUM(Res.StandardQty) WHEN 0 then 0 ELSE (SUM(Res.StandardValue) / SUM(Res.StandardQty))  END) AllStandardPrice, 
                      SUM(Res.StandardQty) AllStandardQty, 
                      SUM(Res.StandardValue) AllStandardValue, 
                      (CASE SUM(Res.ActualQty) WHEN 0 then 0 ELSE (SUM(Res.ActualValue) / SUM(Res.ActualQty))  END) AllActualPrice, 
                      SUM(Res.ActualQty) AllActualQty, 
                      SUM(Res.ActualValue) AllActualValue,
		      SUM(Res.DefRQty) DefRQty,
		      SUM(Res.DefRPrice) DefRPrice
              FROM  #MyRESULT Res   INNER JOIN mt000 mt ON CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END = Res.MatName 
	   WHERE  mt.Guid = @MatGuid  AND Res.MatName = CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END
              GROUP BY Res.CostName, Res.sort
        END
        ELSE 
        BEGIN
              INSERT INTO #TOTALRESULT
              SELECT res.Sort,
                     Res.CostName AS CostName,
                     (CASE SUM(Res.StandardQty) WHEN 0 then 0 ELSE (SUM(Res.StandardValue) / SUM(Res.StandardQty))  END) 
                      AllStandardPrice, 
                      SUM(Res.StandardQty) AllStandardQty, 
                      SUM(Res.StandardValue) AllStandardValue, 
                      (CASE SUM(Res.ActualQty) WHEN 0 then 0 ELSE (SUM(Res.ActualValue) / SUM(Res.ActualQty))  END) 
                      AllActualPrice, 
                      SUM(Res.ActualQty) AllActualQty, 
                      SUM(Res.ActualValue) AllActualValue,
		      SUM(Res.DefRQty) DefRQty,
		      SUM(Res.DefRPrice) DefRPrice
              FROM  #MyRESULT Res   INNER JOIN mt000 mt ON CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END = Res.MatName 
              GROUP BY Res.CostName, res.sort
        END
	
        SELECT *   
	  FROM #MYRESULT res LEFT JOIN co000 co  on CASE WHEN @Lang > 0 THEN CASE WHEN co.LatinName = ''  THEN co.Name ELSE co.LatinName END ELSE co.Name END = res.CostName
	WHERE @CostGuid  = co.Guid OR @CostGuid = 0x0 
	ORDER BY res.sort,res.CostName,(CASE @SortType WHEN 1 THEN MatName ELSE  MatCode END)

        SELECT
		Res.sort,
                Res.CostName,
                Res.AllStandardPrice, 
                Res.AllStandardQty, 
                Res.AllStandardValue, 
                Res.AllActualPrice, 
                Res.AllActualQty, 
                Res.AllActualValue,
                Res.DefRQty,
		Res.DefRPrice
        FROM  #TOTALRESULT Res  
		LEFT JOIN co000 co  on CASE WHEN @Lang > 0 THEN CASE WHEN co.LatinName = ''  THEN co.Name ELSE co.LatinName END ELSE co.Name END  = res.CostName
	WHERE @CostGuid  = co.Guid OR @CostGuid = 0x0 
        ORDER BY Res.sort
###############################################################################
CREATE PROCEDURE prc_repManufWithOutCostCenter
(
	@MatGuid UNIQUEIDENTIFIER = 0x0      ,
	@GrpGuid UNIQUEIDENTIFIER = 0x0      ,
	@CostGuid UNIQUEIDENTIFIER = 0x0	 ,
	@SrcTypesguid UNIQUEIDENTIFIER = 'A56F530D-846B-4C4B-801C-BFBF0DB78148', 
	@WithOutCostCenter INT  = 1,
	@UseUnit		   INT  = 1 , 
	@SortType			INT = 1 , 
	@FromDate DATETIME = '1-1-1980'      ,
	@ToDate DATETIME   = '1-1-2070'      ,
        @ShowTotal INT =1  
)
AS
SET NOCOUNT ON 
	DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();
	SELECT GUID INTO #CostList from dbo.fnGetCostsList(@CostGuid)
	IF(@WithOutCostCenter = 1 AND ISNULL(@CostGuid, 0x0) = 0x0)
		INSERT INTO #CostList VALUES(@CostGuid)
 


 CREATE TABLE #MYRESULT(   Sort INT ,
			   CostName [VARCHAR](255)  COLLATE Arabic_CI_AI , 
			   MatName [VARCHAR](255)  COLLATE Arabic_CI_AI,
			   MatGuid uniqueidentifier,
			   MatCode [VARCHAR](255)  COLLATE Arabic_CI_AI,
			   MatUnit [VARCHAR](255)  COLLATE Arabic_CI_AI,
			   StandardPrice FLOAT, 
			   StandardQty FLOAT, 
			   StandardValue FLOAT, 
			   ActualPrice FLOAT, 
			   ActualQty FLOAT, 
			   ActualValue FLOAT,
			   DefRQty FLOAT,
			   DefRPrice FLOAT
			 )
	--ÝÚáí
	SELECT 
			  a.CostGuid
			, a.MatGuid
			, a.[CostName]
			, a.[MatName],a.[MatCode]
			, a.Ac_Qty
			, CASE a.Ac_Qty WHEN 0 THEN 0 ELSE (a.Ac_Total / a.Ac_Qty) END as Ac_Price 
			, a.Ac_Total
			,1 AS Sort 
			,0 AS DefRQty
			,0 AS DefRPrice
	INTO #ACTUAL_HSH
	FROM
	(
		SELECT 
			  q.CostGuid,
			  q.MatGuid,
			  q.CostName,
			  q.MatName,q.MatCode,
			  SUM(q.Ac_Qty)		Ac_Qty,
			  SUM(q.Ac_Qty * q.Price) Ac_Total
		FROM
		(
			SELECT 
			       bu.CostGuid AS CostGuid 
				 , mt.Guid AS MatGuid
				 ,'' AS CostName
				 , CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END AS MatName,mt.Code AS MatCode
				 , -1 * (bi.QTY * ( CASE billTypes.BillType 
							WHEN 0 THEN  1 --ãÔÊÑíÇÊ
							WHEN 1 THEN -1 --ãÈíÚÇÊ
							WHEN 2 THEN -1 --ãÑÊÌÚ ãÔÊÑíÇÊ
							WHEN 3 THEN  1 --ãÑÊÌÚ ãÈíÚÇÊ
							WHEN 4 THEN  1 --ÇÏÎÇá
							WHEN 5 THEN -1 --ÇÎÑÇÌ
							ELSE 0 
							END  )) as Ac_Qty,
	             bi.Price / CASE Bi.Unity When 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END Price,
				 billTypes.BillType
			FROM bt000 billTypes
			INNER JOIN bu000  bu  ON bu.[TypeGUID]   = billTypes.[GUID]
			INNER JOIN bi000  bi  ON bi.[ParentGUID] = bu.[GUID]
			INNER JOIN mt000  mt  ON mt.[GUID]    = bi.[MatGUID]
			INNER JOIN dbo.fnGetGroupsList (@GrpGuid) gr  ON gr.[GUID]    = mt.[GroupGUID]
			INNER JOIN [RepSrcs] bt  ON bt.[idType] = bu.[TypeGUID]
			WHERE  billTypes.[Type] = 1 AND bu.[Date] >= @FromDate AND bu.[Date] <= @ToDate  AND [bt].IdTbl = @SrcTypesguid
		)q
		GROUP BY q.CostGuid , q.MatGuid , q.CostName , q.MatName, q.MatCode
	) a

	
	
--	--ãÚíÇÑí
	SELECT 
			  a.CostGuid
			, a.MatGuid
			, a.[CostName]
			, a.[MatName], a.[MatCode]
			, a.STNDR_Qty
			, (a.STNDR_Total / a.STNDR_Qty) as STNDR_Price
			, a.STNDR_Total
			,1 AS Sort 
			,0 AS DefRQty
			,0 AS DefRPrice
	INTO #STANDARD_HSH
	FROM
	(
	select *  from(	
		SELECT 
		       bu.CostGuid AS CostGuid 
			 , mt.Guid AS MatGuid
			 ,'' AS CostName
			 , CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END AS MatName, mt.Code AS MatCode 
			 , SUM(bi.Qty) as STNDR_Qty
			 , SUM(bi.Qty * bi.Price / CASE Bi.Unity When 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END) as STNDR_Total 
		FROM bt000 billTypes
		INNER JOIN bu000 bu						      ON bu.[TypeGUID] = billTypes.[GUID]
		INNER JOIN bi000 bi						      ON bi.[ParentGUID] = bu.[GUID]
		INNER JOIN mt000 mt						      ON mt.[GUID] = bi.[MatGUID]
		INNER JOIN dbo.fnGetGroupsList (@GrpGuid)  gr ON gr.[GUID] = mt.[GroupGUID]
		INNER JOIN [RepSrcs] bt ON bt.[idType] = bu.[TypeGUID]
		WHERE	
			 billTypes.BillType = 5 AND billTypes.[Type] = 2 AND bu.[Date] >= 
			 @FromDate AND bu.[Date] <= @ToDate  AND [bt].IdTbl = @SrcTypesguid 
		GROUP BY 		
			bu.CostGuid,
			mt.Guid ,
			CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END, mt.Code
		) as k
		GROUP BY 
			k.CostGuid,
			k.MatGuid ,
			k.CostName,
			k.MatName,K.MatCode,
			STNDR_Qty ,
			STNDR_Total
	 ) a
	
	
	
	SELECT 	  CostGuid
		, MatGuid
		, [CostName]
		, [MatName], [MatCode]
		, [Sort]
		, [DefRQty]
		, [DefRPrice]
	INTO #allMat
	FROM #ACTUAL_HSH
    UNION
	SELECT 	  CostGuid
		, MatGuid
		, [CostName]
		, [MatName]
		, [MatCode]
		, [Sort]
		, [DefRQty]
		, [DefRPrice]
	FROM #STANDARD_HSH
	
	 
       SELECT  
                a.CostName,
                a.MatName,
		a.MatGuid,
		a.MatCode,
		ISNULL(STNDR.STNDR_Price, 0) AS StandardPrice,
                ISNULL(STNDR.STNDR_Qty ,0) AS StandardQty,
                ISNULL(STNDR.STNDR_Total,0) AS StandardValue,
                0 AS ActualPrice,
                0 AS ActualQty,
                0 AS ActualValue,
	        a.Sort ,
		0 AS DefRQty,
		0 AS DefRPrice
       INTO #RESULT
       FROM #allMat a
       LEFT JOIN #STANDARD_HSH STNDR ON a.CostGuid = STNDR.CostGuid AND a.MatGuid = STNDR.MatGuid

       UNION 

       SELECT  
                a.CostName,
                a.MatName,
		a.MatGuid,
		a.MatCode,
                0,
                0,
                0,
                ISNULL(Ac.Ac_Price ,0) AS ActualPrice,                
                ISNULL(Ac.Ac_Qty ,0) AS ActualQty,
                ISNULL(Ac.Ac_Total ,0) AS ActualValue,
		a.Sort,
		0 AS DefRQty,
		0 AS DefRPrice
       FROM #allMat a
       LEFT JOIN #ACTUAL_HSH Ac ON a.CostGuid = Ac.CostGuid AND a.MatGuid = Ac.MatGuid
       
              

	CREATE TABLE #TOTALRESULT(Sort int ,
			   CostName VARCHAR(256) COLLATE ARABIC_CI_AI,
			   AllStandardPrice FLOAT, 
			   AllStandardQty FLOAT,
			   AllStandardValue FLOAT ,
			   AllActualPrice FLOAT,
			   AllActualQty FLOAT,
			   AllActualValue FLOAT, 
			   DefRQty FLOAT, 
			   DefRPrice FLOAT  
			)
	
	UPDATE #RESULT SET StandardQty = Res.StandardQty / CASE @UseUnit  
								WHEN 0 THEN 1 
								WHEN 1 THEN (CASE Mt.Unit2Fact WHEN  0 THEN (CASE Mt.DefUnit WHEN 1 THEN 1 WHEN 3 THEN Mt.Unit3Fact END)  ELSE Mt.Unit2Fact END)
								WHEN 2 THEN (CASE Mt.Unit3Fact WHEN  0 THEN (CASE Mt.DefUnit WHEN 1 THEN 1 WHEN 2 THEN Mt.Unit2Fact END)  ELSE Mt.Unit3Fact END)
								ELSE 
								CASE Mt.DefUnit WHEN 1 THEN 1 WHEN 2 THEN Mt.Unit2Fact WHEN 3 THEN Mt.Unit3Fact END 
							   END
	FROM #RESULT Res INNER JOIN  #allMat a ON Res.MatName = a.MatName 
			INNER JOIN mt000 Mt ON mt.Guid = a.MatGuid

	UPDATE #RESULT SET ActualQty = Res.ActualQty / CASE @UseUnit  
								WHEN 0 THEN 1 
								WHEN 1 THEN (CASE Mt.Unit2Fact WHEN  0 THEN (CASE Mt.DefUnit WHEN 1 THEN 1 WHEN 3 THEN Mt.Unit3Fact END)  ELSE Mt.Unit2Fact END)
								WHEN 2 THEN (CASE Mt.Unit3Fact WHEN  0 THEN (CASE Mt.DefUnit WHEN 1 THEN 1 WHEN 2 THEN Mt.Unit2Fact END)  ELSE Mt.Unit3Fact END)
								ELSE 
								CASE Mt.DefUnit WHEN 1 THEN 1 WHEN 2 THEN Mt.Unit2Fact WHEN 3 THEN Mt.Unit3Fact END 
						       END
	FROM #RESULT Res INNER JOIN  #allMat a ON Res.MatName = a.MatName 
			 INNER JOIN mt000 Mt ON Mt.Guid = a.MatGuid



	IF(ISNULL(@MatGuid, 0x0) <> 0x0) 
	BEGIN
	  INSERT INTO #MYRESULT
		SELECT  Res.Sort AS Sort ,
			Res.CostName AS CostName ,
                        Res.MatName AS MatName,
			mt.Guid AS MatGuid, 
			mt.Code AS MatCode,
			ISNULL(
				CASE @UseUnit 
					WHEN 0 THEN mt.Unity
					WHEN 1 THEN CASE mt.Unit2 WHEN  '' THEN mtV.mtDefUnitName  ELSE mt.Unit2 END
					WHEN 2 THEN CASE mt.Unit3 WHEN  '' THEN mtV.mtDefUnitName ELSE mt.Unit3 END 
					ELSE mtV.mtDefUnitName    
			        END, '') AS MatUnit ,
			(CASE SUM(Res.StandardQty) WHEN 0 THEN 0 ELSE (SUM(Res.StandardValue) / SUM(Res.StandardQty)) END) StandardPrice, 
                        SUM(Res.StandardQty) StandardQty, 
                        SUM(Res.StandardValue) StandardValue, 
                        (CASE SUM(Res.ActualQty) WHEN 0 then 0 ELSE (SUM(Res.ActualValue) / SUM(Res.ActualQty))  END) ActualPrice, 
                        SUM(Res.ActualQty) ActualQty, 
                        SUM(Res.ActualValue) ActualValue,
                        ((SUM(Res.ActualQty) - SUM(Res.StandardQty)) * 
					(CASE SUM(Res.StandardQty) WHEN 0 THEN 0 ELSE (SUM(Res.StandardValue) / SUM(Res.StandardQty)) END)
					 )
			as  DefRQty,
			(((CASE SUM(Res.ActualQty) WHEN 0 then 0 ELSE (SUM(Res.ActualValue) / SUM(Res.ActualQty))  END)
					- (CASE SUM(Res.StandardQty) WHEN 0 THEN 0 ELSE (SUM(Res.StandardValue) / SUM(Res.StandardQty)) END))
					  *
			SUM(Res.ActualQty)
			) as DefRPrice
		FROM #RESULT Res    INNER JOIN mt000 mt ON mt.Guid = @MatGuid AND mt.Name = Res.MatName
				    INNER JOIN vwmt mtV ON @MatGuid = mtV.mtGuid
		WHERE @MatGuid = mtV.mtGuid AND @MatGuid = mt.Guid
		GROUP BY Res.CostName,Res.MatName, mt.Guid,mt.Code, mt.Unity, mtV.mtDefUnitName, mt.Unit2, mt.Unit3,Res.Sort
			
        END
	ELSE 
	   BEGIN
		INSERT INTO #MYRESULT
		SELECT    
			Res.Sort AS Sort ,
			Res.CostName AS CostName ,
                        Res.MatName AS MatName,
			mt.Guid AS MatGuid, mt.Code AS MatCode,
			ISNULL(
				CASE @UseUnit 
					WHEN 0 THEN mt.Unity
					WHEN 1 THEN CASE mt.Unit2 WHEN  '' THEN mtV.mtDefUnitName  ELSE mt.Unit2 END
					WHEN 2 THEN CASE mt.Unit3 WHEN  '' THEN mtV.mtDefUnitName ELSE mt.Unit3 END 
					ELSE mtV.mtDefUnitName    
			        END, '') AS MatUnit ,
			(CASE SUM(Res.StandardQty) WHEN 0 THEN 0 ELSE (SUM(Res.StandardValue) / SUM(Res.StandardQty)) END) StandardPrice, 
                        SUM(Res.StandardQty) StandardQty, 
                        SUM(Res.StandardValue) StandardValue, 
                        (CASE SUM(Res.ActualQty) WHEN 0 then 0 ELSE (SUM(Res.ActualValue) / SUM(Res.ActualQty))  END) ActualPrice, 
                        SUM(Res.ActualQty) ActualQty, 
                        SUM(Res.ActualValue) ActualValue,
                        (( SUM(Res.ActualQty) - SUM(Res.StandardQty)) * 
			  (CASE SUM(Res.StandardQty) WHEN 0 THEN 0 ELSE (SUM(Res.StandardValue) / SUM(Res.StandardQty)) END)
			)  as  DefRQty,
			(((CASE SUM(Res.ActualQty) WHEN 0 then 0 ELSE (SUM(Res.ActualValue) / SUM(Res.ActualQty))  END)
			   - (CASE SUM(Res.StandardQty) WHEN 0 THEN 0 ELSE (SUM(Res.StandardValue) / SUM(Res.StandardQty)) END))
			  * SUM(Res.ActualQty)
			) as DefRPrice
		FROM  #RESULT Res INNER JOIN mt000 mt ON CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END = Res.MatName 
				  INNER JOIN vwmt mtV ON Res.MatName = CASE WHEN @Lang > 0 THEN CASE WHEN mtV.mtLatinName = ''  THEN mtV.mtName ELSE mtV.mtLatinName END ELSE mtV.mtName END
		GROUP BY Res.CostName, Res.MatName, mt.Guid,mt.Code, mt.Unity, mtV.mtDefUnitName, mt.Unit2, mt.Unit3,Res.Sort
			
	   END

	SELECT * 
	FROM #MYRESULT res
	ORDER BY CostName,(CASE @SortType WHEN 1 THEN MatName END), (CASE @SortType WHEN 2 THEN MatCode END)

	IF (ISNULL(@MatGuid, 0x0) <> 0x0)
	BEGIN
		INSERT INTO #TOTALRESULT
		 SELECT  res.sort,
			 '' AS CostName,
		      	 (CASE SUM(Res.StandardQty) WHEN 0 then 0 ELSE (SUM(Res.StandardValue) / SUM(Res.StandardQty))  END) 
                         AllStandardPrice, 
                         SUM(Res.StandardQty) AllStandardQty, 
                         SUM(Res.StandardValue) AllStandardValue, 
                         (CASE SUM(Res.ActualQty) WHEN 0 then 0 ELSE (SUM(Res.ActualValue) / SUM(Res.ActualQty))  END) 
                          AllActualPrice, 
                         SUM(Res.ActualQty) AllActualQty, 
                         SUM(Res.ActualValue) AllActualValue,
			 SUM(Res.DefRQty) DefRQty,
			 SUM(Res.DefRPrice) DefRPrice
		FROM  #MyRESULT Res   INNER JOIN mt000 mt ON CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END = Res.MatName 
		  WHERE  mt.Guid = @MatGuid  AND Res.MatName = CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END
		GROUP BY Res.CostName, res.sort
	END
	ELSE 
	BEGIN
		INSERT INTO #TOTALRESULT
		SELECT  
		     res.Sort,
		     '' AS CostName,
		     (CASE SUM(Res.StandardQty) WHEN 0 then 0 ELSE (SUM(Res.StandardValue) / SUM(Res.StandardQty))  END) 
		     AllStandardPrice, 
		     SUM(Res.StandardQty) AllStandardQty, 
		     SUM(Res.StandardValue) AllStandardValue, 
		     (CASE SUM(Res.ActualQty) WHEN 0 then 0 ELSE (SUM(Res.ActualValue) / SUM(Res.ActualQty))  END) 
		     AllActualPrice, 
		     SUM(Res.ActualQty) AllActualQty, 
		     SUM(Res.ActualValue) AllActualValue,
		     SUM(Res.DefRQty) DefRQty,
		     SUM(Res.DefRPrice) DefRPrice
		FROM  #MyRESULT Res   INNER JOIN mt000 mt ON CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END = Res.MatName 
		GROUP BY Res.CostName, res.sort
	END

	SELECT   res.sort,
		'' AS CostName,
		Res.AllStandardPrice, 
		Res.AllStandardQty, 
		Res.AllStandardValue, 
		Res.AllActualPrice, 
		Res.AllActualQty, 
		Res.AllActualValue,
		Res.DefRQty,
		Res.DefRPrice
	FROM  #TOTALRESULT Res  
################################################################################	
#END
