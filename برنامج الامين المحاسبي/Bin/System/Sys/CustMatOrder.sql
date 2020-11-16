########################################################################################
CREATE FUNCTION fnGetMatCollectedFieldNameAndGroup (@Colect INT,
                                                    @Prefix NVARCHAR(10) = '')
RETURNS NVARCHAR(100)
AS
  BEGIN
      DECLARE @fld NVARCHAR(100)

      SET @fld=@Prefix + '.';

      IF @Colect = 1
        SET @fld = @fld + '[Dim]'
      ELSE IF @Colect = 2
        SET @fld = @fld + '[Pos] '
      ELSE IF @Colect = 3
        SET @fld = @fld + '[Origin] '
      ELSE IF @Colect = 4
        SET @fld = @fld + '[Company] '
      ELSE IF @Colect = 5
        SET @fld = @fld + '[Color] '
      ELSE IF @Colect = 6
        SET @fld = @fld + '[Model] '
      ELSE IF @Colect = 7
        SET @fld = @fld + '[Quality]'
      ELSE IF @Colect = 8
        SET @fld = @fld + '[Provenance]'
      ELSE IF @Colect = 9
        SET @fld = @fld + '[Name]'
      ELSE IF @Colect = 10
        SET @fld = @fld + '[LatinName]'
      ELSE IF @Colect = 11
        BEGIN
            SET @fld = '';
            SET @fld = 'gr.[Name]'
        END
      ELSE
        SET @fld = ''

      RETURN @fld
  END 
########################################################################################
CREATE PROCEDURE CustMatOrder @CustGuid       UNIQUEIDENTIFIER = 0x00,
                              @MatGuid        UNIQUEIDENTIFIER = 0x00,
                              @CostGuid       UNIQUEIDENTIFIER = 0x00,
                              @GroupGuid      UNIQUEIDENTIFIER = 0x00,
                              @StoreGuid      UNIQUEIDENTIFIER = 0x00,
                              @ReportSource   UNIQUEIDENTIFIER = 0x00,
                              @TypeGuid       UNIQUEIDENTIFIER = 0x00,
                              @StartDate      DATETIME = '1/1/1980',
                              @EndDate        DATETIME = '12/30/1980',
                              @UseUnit        INT = 1,
                              @DetailedReport INT = 1,

                              --@ResDirection BIT = 0  ,   
                              @isFinished     BIT = 0,
                              @isCancled      BIT = 0,
                              @MatCond        UNIQUEIDENTIFIER = 0x00,
                              @CustCondGuid   UNIQUEIDENTIFIER = 0x00,
                              @OrderCond      UNIQUEIDENTIFIER = 0x00,
                              @MatFldsFlag    BIGINT = 0,
                              @CustFldsFlag   BIGINT = 0,
                              @OrderFldsFlag  BIGINT = 0,
                              @MatCFlds       NVARCHAR (max) = '',
                              @CustCFlds      NVARCHAR (max) = '',
                              @OrderCFlds     NVARCHAR (max) = '',
                              @OrderIndex     INT = 0,
                              @Collect1       INT = 0,
                              @Collect2       INT = 0,
                              @Collect3       INT = 0
AS
    SET NOCOUNT ON
	DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
    --///////////////////////////////////////////////////////////////////////////////   
    CREATE TABLE #SecViol
      (
         Type INT,
         Cnt  INT
      )

    -------Bill Resource ---------------------------------------------------------           
    CREATE TABLE #Src
      (
         Type           UNIQUEIDENTIFIER,
         Sec            INT,
         ReadPrice      INT,
         UnPostedSec    INT,
         OrderName      NVARCHAR(15) COLLATE ARABIC_CI_AI DEFAULT '',
         OrderLatinName NVARCHAR(15) COLLATE ARABIC_CI_AI DEFAULT ''
      )

    INSERT INTO #Src
                (Type,
                 Sec,
                 ReadPrice,
                 UnPostedSec)
    EXEC prcGetBillsTypesList2
      @ReportSource

    UPDATE src
    SET    OrderName = bt.Abbrev,
           OrderLatinName = bt.LatinAbbrev
    FROM   #Src AS src
           INNER JOIN bt000 AS bt
                   ON src.Type = bt.guid

    -------------------------------------------------------------------           
    CREATE TABLE #TypeTbl
      (
         Guid      UNIQUEIDENTIFIER,
         NAME      NVARCHAR(255) COLLATE ARABIC_CI_AI,
         LatinName NVARCHAR(255) COLLATE ARABIC_CI_AI,
		 OrderType INT
      )

    INSERT INTO #TypeTbl
    SELECT idType,
           ISNULL(NAME, ''),
           ISNULL(LatinName, ''),
		   [Type]
    FROM   RepSrcs src
           LEFT JOIN dbo.fnGetOrderItemTypes() AS fnType
                  ON fnType.Guid = src.idType
    WHERE  IdTbl = @TypeGuid
    GROUP  BY idType,
              NAME,
              LatinName,
			  [Type]

    -------------------------------------------------------------------    
    --  ÃœÊ· «·ÿ·»Ì«  „⁄  ÕÕﬁÌﬁ ‘—Êÿ «·ÿ·»Ì«    
    CREATE TABLE #OrderCond
      (
         OrderGuid  UNIQUEIDENTIFIER,
         [Security] [INT]
      )

    INSERT INTO [#OrderCond]
                (OrderGuid,
                 [Security])
    EXEC [prcGetOrdersList]
      @OrderCond

    -------------------------------------------------------------------    
    CREATE TABLE #CustTbl
      (
         Guid         UNIQUEIDENTIFIER,
         [Security]   [INT],
         CustomerName NVARCHAR(255) COLLATE ARABIC_CI_AI
      )

    INSERT INTO [#CustTbl]
                (Guid,
                 [Security])
    EXEC [prcGetCustsList]
      @CustGuid,
      0X00,
      @CustCondGuid -- Œÿ«   
    UPDATE C
    SET    CustomerName = cu.CustomerName
    FROM   [#CustTbl] AS C
           INNER JOIN [CU000] AS [CU]
                   ON [CU].GUID = C.GUID

    -- ≈÷«›… “»Ê‰ ›«—€ ·Ã·» «·›Ê« Ì— «· Ì ·«  „·ﬂ “»Ê‰ ›Ì Õ«· «·„” Œœ„ ·„ ÌÕœœ “»Ê‰      
    -- „Õœœ ›Ì «· ﬁ—Ì—     
    IF ( ISNULL(@CustGuid, 0x0) = 0x00 )
       AND ( ISNULL(@CustCondGuid, 0x0) = 0X0 )
      INSERT INTO [#CustTbl]
      VALUES     (0x00,
                  1,
                  '')

    -------Mat Table----------------------------------------------------------           
    CREATE TABLE #MatTbl
      (
         Guid       UNIQUEIDENTIFIER,
         mtSecurity INT,
         MatName    NVARCHAR(800) COLLATE ARABIC_CI_AI DEFAULT ''
      )

    INSERT INTO #MatTbl
                (Guid,
                 mtSecurity)
    EXEC prcGetMatsList
      @MatGuid,
      @GroupGuid,
      -1,
      @MatCond

    -- #matTbl Should be later modified when joining with bi to get right unity and unitfact      
    UPDATE mtTbl
    SET    MatName = (CASE @Lang WHEN 0 THEN Name ELSE (CASE LatinName WHEN N'' THEN Name ELSE LatinName END) END ) --+'-'+ Code      
    FROM   #MatTbl AS mtTbl
           INNER JOIN mt000 AS mt
                   ON mt.guid = mtTbl.guid

    -- SELECT '#MatTbl' 	SELECT * from #MatTbl     
    -------Store Table----------------------------------------------------------           
    CREATE TABLE #StoreTbl
      (
         Guid UNIQUEIDENTIFIER
      )

    INSERT INTO #StoreTbl
    SELECT Guid
    FROM   fnGetStoresList(@StoreGuid)

    ---------------------------------------------------------------------------     
    --EXEC prcCheckSecurity  
    -----------------------------------------------------------------------------------------  
    DECLARE @col1 NVARCHAR(100)

    SET @col1 = dbo.fnGetMatCollectedFieldNameAndGroup(@Collect1, 'mats')

    DECLARE @col2 NVARCHAR(100)

    SET @col2 = dbo.fnGetMatCollectedFieldNameAndGroup(@Collect2, 'mats')

    DECLARE @col3 NVARCHAR(100)

    SET @col3 = dbo.fnGetMatCollectedFieldNameAndGroup(@Collect3, 'mats')

    ----------------------------------------------------------------------------------------- 
    -- EXEC  [prcGetCostsList]
    -----------------------------------------------------------------------------------------
    CREATE TABLE [#CostTbl]
      (
         [CostGUID] UNIQUEIDENTIFIER,
         [Security] INT
      )

    INSERT INTO [#CostTbl]
    EXEC [prcGetCostsList]
      @CostGUID

    IF @costGuid = 0x00
      INSERT INTO #CostTbl
      VALUES     (0x00,
                  0)

    -----------------------------------------------------------------------------------------
    EXEC GetCustFlds
      @CustFldsFlag,
      @CustCFlds

    IF @DetailedReport = 1
      BEGIN
          EXEC GetMatFlds
            @MatFldsFlag,
            @MatCFlds

          EXEC GetOrderFlds
            @OrderFldsFlag,
            @OrderCFlds

          SELECT cu.CustomerName     AS Cust_Name,
                 mt.MatName ,
                 bu.Guid             OrderGuid,
                 bu.CustGuid,
                 bi.Guid             BiGuid,
                 bi.matguid,
                 bu.date             AS buDate,
                 src.OrderName,
				 [type].NAME OrderStateName,
				 [type].LatinName OrderStateLatinName,
				 [type].OrderType OrderStateOrderType,
                 src.OrderLatinName,
                 bu.Number           AS Number,
                 ori.typeGuid,
                 Sum(ori.Qty)        AS Qty,
                 bi.Qty              AS OrderQty,
                 bi.Notes            OrderItemNotes,
                 bi.ClassPtr         OrderItemClass,
				 CAST(ISNULL((CASE @Lang WHEN 0 THEN co.NAME ELSE (CASE co.LatinName WHEN N'' THEN co.NAME ELSE co.LatinName END) END ), '') AS NVARCHAR(MAX)) OrderItemCostName
          INTO   #custQty2
          FROM   bu000 AS bu
                 INNER JOIN #CostTbl
                         ON #CostTbl.CostGUID = bu.CostGUID
                 INNER JOIN #OrderCond OrCond
                         ON OrCond.OrderGuid = bu.Guid
                 INNER JOIN bi000 AS bi
                         ON bu.guid = bi.parentguid
                 LEFT JOIN co000 co
                        ON co.GUID = bi.CostGUID
                 INNER JOIN #Src AS src
                         ON src.type = bu.typeguid
                 INNER JOIN #MatTbl AS mt
                         ON mt.guid = bi.matguid
                 INNER JOIN mt000 AS mats
                         ON mt.Guid = mats.GUID
                 INNER JOIN #StoreTbl AS st
                         ON st.guid = bi.storeguid
                 INNER JOIN ori000 AS ori
                         ON ori.poiguid = bi.guid
                 INNER JOIN #TypeTbl AS type
                         ON ori.typeguid = type.Guid
                 INNER JOIN #CustTbl AS cu
                         ON cu.Guid = bu.CustGuid
                 INNER JOIN ORADDINFO000 OInfo
                         ON bu.Guid = OInfo.ParentGuid
          WHERE  ori.[Date] BETWEEN @StartDate AND @EndDate
                 AND ( OInfo.Finished = ( CASE @isFinished
                                            WHEN 0 THEN '0'
                                            ELSE OInfo.Finished
                                          END ) )
                 AND ( OInfo.Add1 = ( CASE @isCancled
                                        WHEN 0 THEN 0
                                        ELSE OInfo.Add1
                                      END ) )
          GROUP  BY bu.Guid,
                    bu.CustGuid,
                    cu.CustomerName,
                    bi.Guid,
                    bi.matguid,
					[type].NAME,
				    [type].LatinName,
				    [type].OrderType,
                    mt.MatName,
                    bu.date,
                    src.OrderName,
                    src.OrderLatinName,
                    bu.Number,
                    ori.typeGuid,
                    bi.Qty,
                    bi.Notes,
                    bi.ClassPtr,
                    (CASE @Lang WHEN 0 THEN co.NAME ELSE (CASE co.LatinName WHEN N'' THEN co.NAME ELSE co.LatinName END) END ) 

          --PRINT @SQL
          --EXEC (@SQL)
          --ORDER BY (@OrderIndex+1)
          --UPDATE #custQty2    
          --SET Qty = 0 WHERE Qty < 0     
          -- return first result set      
          SELECT DISTINCT r.typeguid,
                          ISNULL(oit.NAME, '')      AS NAME,
                          ISNULL(oit.LatinName, '') AS LatinName,
                          oit.postQty
          FROM   #custQty2 AS r
                 LEFT JOIN oit000 AS oit
                        ON r.typeGuid = oit.guid
          ORDER  BY oit.postQty

          IF dbo.fnObjectExists('##t0') = 1
            DROP TABLE ##t0

          DECLARE @s NVARCHAR(max)

          SET @s = 'SELECT ' + @Col1 + ( CASE @Col1
                                           WHEN '' THEN ''
                                           ELSE ' AS Col1, '
                                         END ) + @Col2 + ( CASE @Col2
                                                             WHEN '' THEN ''
                                                             ELSE ' AS Col2, '
                                                           END ) + @Col3 + ( CASE @Col3
                                                                               WHEN '' THEN ''
                                                                               ELSE ' AS Col3, '
                                                                             END )
          SET @s = @s + CASE @Col1 WHEN '' THEN ' MatGuid, MatName , ' ELSE '' END + 'BiGuid, OrderGuid, CustGuid, Cust_Name,buDate , OrderName , OrderLatinName , r.Number ,    
	(case  '
                   + Cast(@useUnit AS NVARCHAR(10)) + '   when 1 then mats.Unity       
			when 2 then      
				(case mats.Unit2Fact when 0 then mats.Unity      
					     else mats.Unit2 end )      
			when 3 then (case mats.Unit3Fact when 0 then mats.Unity      
					     else mats.Unit3 end)      
			else case mats.DefUnit when 1 then mats.Unity      
					     when 2 then Unit2      
					     else Unit3 end end) unity,      
	typeguid ,
	OrderStateName,
	OrderStateLatinName, 
	OrderStateOrderType,     
	(case  '
                   + Cast(@useUnit AS NVARCHAR(10)) + '   when 1 then ISNULL(r.Qty, 0.00)       
			when 2 then ISNULL(r.Qty, 0.00)/      
				case mats.Unit2Fact when 0 then 1      
						  else mats.Unit2Fact end      
			when 3 then ISNULL(r.Qty, 0.00) /      
				(case mats.Unit3Fact when 0 then 1      
						   else  mats.Unit3Fact end)     
			else ISNULL(r.Qty, 0.00) / case mats.defunit when 2 then mats.Unit2Fact     
						     when 3 then mats.Unit3Fact     
						     else 1 end end) Qty ,     
	(case  '
                   + Cast(@useUnit AS NVARCHAR(10))
                   + '   when 1 then ISNULL(r.OrderQty, 0.00)       
			when 2 then ISNULL(r.OrderQty, 0.00)/      
				case mats.Unit2Fact when 0 then 1      
						  else mats.Unit2Fact end      
			when 3 then ISNULL(r.OrderQty, 0.00) /      
				(case mats.Unit3Fact when 0 then 1      
						   else  mats.Unit3Fact end)     
			else ISNULL(r.OrderQty, 0.00) / case mats.defunit when 2 then mats.Unit2Fact     
						     when 3 then mats.Unit3Fact     
						     else 1 end end) OrderQty 
		, OrderItemNotes
		, OrderItemClass
		, OrderItemCostName
	INTO ##t0  
	FROM #custQty2 as r inner join mt000 as mats on mats.guid = r.MatGuid   
	INNER JOIN gr000 AS gr ON mats.GroupGuid = gr.Guid
	GROUP BY ' + @Col1 + ( CASE @Col1
                                             WHEN '' THEN ''
                                             ELSE ' , '
                                           END ) + @Col2 + ( CASE @Col2
                                                               WHEN '' THEN ''
                                                               ELSE ' , '
                                                             END ) + @Col3 + ( CASE @Col3
                                                                                 WHEN '' THEN ''
                                                                                 ELSE ' , '
                                                                               END ) + CASE @Col1
                                                                                         WHEN '' THEN ' BiGuid, MatGuid, MatName , '
                                                                                         ELSE ''
                                                                                       END + ' BiGuid, OrderGuid, CustGuid, Cust_Name,buDate , OrderName , OrderLatinName , r.Number ,    
	(case  ' + Cast(@useUnit AS NVARCHAR(10)) + '   when 1 then mats.Unity       
			when 2 then      
				(case mats.Unit2Fact when 0 then mats.Unity      
					     else mats.Unit2 end )      
			when 3 then (case mats.Unit3Fact when 0 then mats.Unity      
					     else mats.Unit3 end)      
			else case mats.DefUnit when 1 then mats.Unity      
					     when 2 then Unit2      
					     else Unit3 end end),      
	typeguid ,
	OrderStateName,
	OrderStateLatinName, 
	OrderStateOrderType,     
	(case  ' + Cast(@useUnit AS NVARCHAR(10)) + '   when 1 then ISNULL(r.Qty, 0.00)       
			when 2 then ISNULL(r.Qty, 0.00)/      
				case mats.Unit2Fact when 0 then 1      
						  else mats.Unit2Fact end      
			when 3 then ISNULL(r.Qty, 0.00) /      
				(case mats.Unit3Fact when 0 then 1      
						   else  mats.Unit3Fact end)     
			else ISNULL(r.Qty, 0.00) / case mats.defunit when 2 then mats.Unit2Fact     
						     when 3 then mats.Unit3Fact     
						     else 1 end end),     
	(case  ' + Cast(
                   @useUnit AS NVARCHAR(10)) + '   when 1 then ISNULL(r.OrderQty, 0.00)       
			when 2 then ISNULL(r.OrderQty, 0.00)/      
				case mats.Unit2Fact when 0 then 1      
						  else mats.Unit2Fact end      
			when 3 then ISNULL(r.OrderQty, 0.00) /      
				(case mats.Unit3Fact when 0 then 1      
						   else  mats.Unit3Fact end)     
			else ISNULL(r.OrderQty, 0.00) / case mats.defunit when 2 then mats.Unit2Fact     
						     when 3 then mats.Unit3Fact     
						     else 1 end end)
							 ,OrderItemNotes
							 ,OrderItemClass
							 ,OrderItemCostName
							 '

          EXEC (@s)

          IF dbo.fnObjectExists('##temp_____0') = 1
            DROP TABLE ##temp_____0

          IF @Col1 = ''
            BEGIN
                SET @s = ' SELECT DISTINCT r.*, ' + CASE @Col1 WHEN '' THEN ' M.*, ' ELSE '' END
                         + ' C.*, O.* INTO ##temp_____0 
				   FROM ##t0 as r ' + CASE @Col1 WHEN '' THEN ' INNER JOIN ##MatFlds M ON M.MatFldGuid = r.MatGuid ' ELSE '' END
                         + 'LEFT JOIN ##CustFlds C ON C.CustFldGuid = CustGuid  
					 JOIN ##OrderFlds O ON O.OrderFldGuid = OrderGuid  '
            END
          ELSE
            BEGIN
                SET @s = 'SELECT Col1, ' + ( CASE @Col2
                                               WHEN '' THEN ''
                                               ELSE 'Col2, '
                                             END ) + ( CASE @Col3
                                                         WHEN '' THEN ''
                                                         ELSE 'Col3, '
                                                       END ) + ' CAST(0x0 AS UNIQUEIDENTIFIER) AS BiGuid, CAST(0x0 AS UNIQUEIDENTIFIER) AS OrderGuid, CAST(0x0 AS UNIQUEIDENTIFIER) AS CustGuid, '''' AS Cust_Name, GETDATE() AS buDate , '''' AS OrderName , '''' AS OrderLatinName , 0 AS Number, 
						'''' AS unity, TypeGuid, SUM(Qty) AS Qty, SUM(Qty) AS OrderQty, CAST(0x0 AS UNIQUEIDENTIFIER) AS CustFldGUID, CAST(0x0 AS UNIQUEIDENTIFIER) AS OrderFldGUID 
		,OrderItemNotes
		,OrderItemClass
		,OrderItemCostName
				INTO ##temp_____0 
				FROM ##t0 
				GROUP BY 
				OrderItemNotes
				,OrderItemClass
				,OrderItemCostName
				,Col1, ' + ( CASE @Col2
                                            WHEN '' THEN ''
                                            ELSE 'Col2, '
                                          END ) + ( CASE @Col3
                                                      WHEN '' THEN ''
                                                      ELSE 'Col3, '
                                                    END ) + 'TypeGuid'
            END

          PRINT @s

          EXEC (@s)

          SET @s = ' SELECT * FROM ##temp_____0 ORDER BY '

          IF @Col1 = ''
            BEGIN
                SET @s = @s + + CASE @OrderIndex WHEN 1 THEN ' Cust_Name, buDate, MatName' WHEN 2 THEN ' MatName  ' WHEN 3 THEN ' OrderQty  ' WHEN 4 THEN ' buDate  ' END
            END
          ELSE
            BEGIN
                SET @s = @s + 'Col1' + ( CASE @Col2
                                           WHEN '' THEN ''
                                           ELSE ', Col2'
                                         END ) + ( CASE @Col3
                                                     WHEN '' THEN ''
                                                     ELSE ', Col3'
                                                   END )
            END

          EXEC (@s)

          IF dbo.fnObjectExists('##t0') = 1
            DROP TABLE ##t0

          IF dbo.fnObjectExists('##temp_____0') = 1
            DROP TABLE ##temp_____0
      END
    ELSE IF @DetailedReport = 0
      BEGIN
          IF dbo.fnObjectExists('##CustTypeQty') = 1
            DROP TABLE ##CustTypeQty

          DECLARE @ss NVARCHAR(max)

          SET @ss = 'SELECT ' + @Col1 + ( CASE @Col1
                                            WHEN '' THEN ''
                                            ELSE ' AS Col1, '
                                          END ) + @Col2 + ( CASE @Col2
                                                              WHEN '' THEN ''
                                                              ELSE ' AS Col2, '
                                                            END ) + @Col3 + ( CASE @Col3
                                                                                WHEN '' THEN ''
                                                                                ELSE ' AS Col3, '
                                                                              END )
                    --+ CASE @Col1 WHEN '' THEN '' ELSE '  ' END +
                    + ' bu.CustGuid, cu.CustomerName Cust_Name , ori.typeguid ,
	SUM ( 
	(case  ' + Cast(@useUnit AS NVARCHAR(10)) + '   when 1 then ISNULL(ori.Qty, 0.00)       
			when 2 then ISNULL(ori.Qty, 0.00)/      
				case mats.Unit2Fact when 0 then 1      
						  else mats.Unit2Fact end      
			when 3 then ISNULL(ori.Qty, 0.00) /      
				(case mats.Unit3Fact when 0 then 1      
						   else  mats.Unit3Fact end)     
			else ISNULL(ori.Qty, 0.00) / case mats.defunit when 2 then mats.Unit2Fact     
						     when 3 then mats.Unit3Fact     
						     else 1 end end)
	) AS Qty   
	INTO ##CustTypeQty     
	FROM bu000 AS bu    
		INNER JOIN #OrderCond OrCond ON  OrCond.OrderGuid = bu.Guid     
		INNER JOIN bi000 AS bi ON bu.guid  = bi.parentguid     
		INNER JOIN #Src AS  src ON src.type =  bu.typeguid      
		INNER JOIN #MatTbl AS mt ON mt.guid = bi.matguid
		INNER JOIN mt000 AS mats ON mats.Guid = mt.Guid    
		INNER JOIN gr000 AS gr ON mats.GroupGuid = gr.Guid
		INNER JOIN #StoreTbl AS  st ON st.guid = bi.storeguid       
		INNER JOIN ori000 AS  ori ON ori.poiguid = bi.guid     
		INNER JOIN #TypeTbl AS type ON  type.guid = ori.typeguid      
		INNER JOIN #CustTbl as cu on cu.Guid = bu.CustGuid      
		INNER JOIN ORADDINFO000 OInfo ON bu.Guid = OInfo.ParentGuid   
	WHERE   ori.date BETWEEN ''' + Cast(@StartDate AS NVARCHAR(50)) + ''' AND ''' + Cast(@EndDate AS NVARCHAR(50)) +
                    '''   
		AND  (OInfo.Finished =( Case ' + Cast
                              (@IsFinished AS NVARCHAR(50)) + ' WHEN 0 THEN 0 else OInfo.Finished end  ) )   
		AND (OInfo.Add1 =( Case ' + Cast(@IsCancled AS NVARCHAR(50)) + ' WHEN 0 THEN ''0'' else OInfo.Add1 end  ) )   
	GROUP BY bu.CustGuid, cu.CustomerName , ' + @Col1 + ( CASE @Col1
                                                                             WHEN '' THEN ''
                                                                             ELSE ','
                                                                           END ) + @Col2 + ( CASE @Col2
                                                                                               WHEN '' THEN ''
                                                                                               ELSE ','
                                                                                             END ) + @Col3 + ( CASE @Col3
                                                                                                                 WHEN '' THEN ''
                                                                                                                 ELSE ','
                                                                                                               END ) + ' ori.typeguid '

          EXEC (@ss)

          -- «·≈Ã„«·Ì      
          IF dbo.fnObjectExists('##CustTotal') = 1
            DROP TABLE ##CustTotal

          SET @ss = 'SELECT ' + @Col1 + ( CASE @Col1
                                            WHEN '' THEN ''
                                            ELSE ' AS Col1, '
                                          END ) + @Col2 + ( CASE @Col2
                                                              WHEN '' THEN ''
                                                              ELSE ' AS Col2, '
                                                            END ) + @Col3 + ( CASE @Col3
                                                                                WHEN '' THEN ''
                                                                                ELSE ' AS Col3, '
                                                                              END ) + ' bu.CustGuid , bu.Cust_Name ,
	SUM (isnull( 
	(case  ' + Cast(@useUnit AS NVARCHAR(10)) + '   when 1 then ISNULL(bi.Qty, 0.00)       
			when 2 then ISNULL(bi.Qty, 0.00)/      
				case mats.Unit2Fact when 0 then 1      
						  else mats.Unit2Fact end      
			when 3 then ISNULL(bi.Qty, 0.00) /      
				(case mats.Unit3Fact when 0 then 1      
						   else  mats.Unit3Fact end)     
			else ISNULL(bi.Qty, 0.00) / case mats.defunit when 2 then mats.Unit2Fact     
						     when 3 then mats.Unit3Fact     
						     else 1 end end)
	,0)) AS TotalQty     
	INTO ##CustTotal     
	FROM bu000 AS bu     
	INNER JOIN #OrderCond OrCond ON  OrCond.OrderGuid = bu.Guid    
	INNER JOIN bi000 AS bi ON bu.guid  = bi.parentguid     
	INNER JOIN #Src AS  src ON src.type =  bu.typeguid      
	INNER JOIN #StoreTbl AS  st ON st.guid = bi.storeguid   
	INNER JOIN #MatTbl AS mt ON mt.guid = bi.matguid       
	INNER JOIN #CustTbl as cu on cu.Guid = bu.CustGuid
	INNER JOIN mt000 AS mats ON mats.Guid = mt.Guid    
	INNER JOIN gr000 AS gr ON mats.GroupGuid = gr.Guid
	INNER JOIN ORADDINFO000 OInfo ON bu.Guid = OInfo.ParentGuid   
	WHERE   bu.date BETWEEN ''' + Cast(@StartDate AS NVARCHAR(50)) +
                    ''' AND ''' +
                    Cast(
                              @EndDate AS NVARCHAR(50)) + '''	      
	AND  (OInfo.Finished =( Case ' + Cast(@IsFinished AS NVARCHAR(50)) + ' WHEN 0 THEN 0 else OInfo.Finished end  ) )   
		AND (OInfo.Add1 =( Case ' + Cast(@IsCancled AS NVARCHAR(50)) +
                              ' WHEN 0 THEN ''0'' else OInfo.Add1 end  ) )   
	GROUP BY bu.CustGuid, bu.Cust_Name ' + ( CASE @Col1
                                                                WHEN '' THEN ''
                                                                ELSE ', '
                                                              END ) + @Col1 + ( CASE @Col2
                                                                                  WHEN '' THEN ''
                                                                                  ELSE ', '
                                                                                END ) + @Col2 + ( CASE @Col3
                                                                                                    WHEN '' THEN ''
                                                                                                    ELSE ', '
                                                                                                  END ) + @Col3

          EXEC (@ss)

          -----------------------------------------------------------------------------------------------------------------------   
          EXEC ('SELECT DISTINCT r.typeguid,
                oit.NAME      AS NAME,
                oit.LatinName AS LatinName,
                oit.postQty
FROM   ##CustTypeQty AS r
       LEFT JOIN oit000 AS oit
              ON r.typeguid = oit.guid
ORDER  BY oit.postQty')

          SET @ss = 'SELECT ' + ( CASE @Col1
                                    WHEN '' THEN ''
                                    ELSE 'r.Col1'
                                  END ) + ( CASE @Col1
                                              WHEN '' THEN ''
                                              ELSE ', '
                                            END ) + ( CASE @Col2
                                                        WHEN '' THEN ''
                                                        ELSE 'r.Col2'
                                                      END ) + ( CASE @Col2
                                                                  WHEN '' THEN ''
                                                                  ELSE ', '
                                                                END ) + ( CASE @Col3
                                                                            WHEN '' THEN ''
                                                                            ELSE 'r.Col3'
                                                                          END ) + ( CASE @Col3
                                                                                      WHEN '' THEN ''
                                                                                      ELSE ', '
                                                                                    END ) + ' r.CustGuid , r.Cust_Name , t1.TotalQty, r.typeguid , ISNULL(r.Qty, 0.00) AS Qty, C.*  
	FROM ##CustTypeQty AS r     
	INNER JOIN  ##CustTotal AS t1 ON t1.CustGuid = r.CustGuid ' + CASE @Col1
                                                                                     WHEN '' THEN ''
                                                                                     ELSE ' AND r.Col1 = t1.Col1 '
                                                                                   END + CASE @Col2
                                                                                           WHEN '' THEN ''
                                                                                           ELSE ' AND r.Col2 = t1.Col2 '
                                                                                         END + CASE @Col3
                                                                                                 WHEN '' THEN ''
                                                                                                 ELSE ' AND r.Col3 = t1.Col3 '
                                                                                               END + ' LEFT JOIN ##CustFlds C ON C.CustFldGuid = r.CustGuid  
	ORDER BY r.CustGuid '

          EXEC (@ss)

          IF dbo.fnObjectExists('##CustTypeQty') = 1
            DROP TABLE ##CustTypeQty

          IF dbo.fnObjectExists('##CustTotal') = 1
            DROP TABLE ##CustTotal
      END
    ELSE IF @DetailedReport = 2
      BEGIN
          IF dbo.fnObjectExists('##CustOrderTypeQty') = 1
            DROP TABLE ##CustOrderTypeQty

          DECLARE @str NVARCHAR(max)

          SET @str = 'SELECT ' + @Col1 + ( CASE @Col1
                                             WHEN '' THEN ''
                                             ELSE ' AS Col1, '
                                           END ) + @Col2 + ( CASE @Col2
                                                               WHEN '' THEN ''
                                                               ELSE ' AS Col2, '
                                                             END ) + @Col3 + ( CASE @Col3
                                                                                 WHEN '' THEN ''
                                                                                 ELSE ' AS Col3, '
                                                                               END ) + ' bu.CustGuid, bu.guid as orderguid, cu.CustomerName Cust_Name , ori.typeguid ,
	SUM ( 
	(case  ' + Cast(@useUnit AS NVARCHAR(10)) + '   when 1 then ISNULL(ori.Qty, 0.00)       
			when 2 then ISNULL(ori.Qty, 0.00)/      
				case mats.Unit2Fact when 0 then 1      
						  else mats.Unit2Fact end      
			when 3 then ISNULL(ori.Qty, 0.00) /      
				(case mats.Unit3Fact when 0 then 1      
						   else  mats.Unit3Fact end)     
			else ISNULL(ori.Qty, 0.00) / case mats.defunit when 2 then mats.Unit2Fact     
						     when 3 then mats.Unit3Fact     
						     else 1 end end)
	) AS Qty   
	INTO ##CustOrderTypeQty     
	FROM bu000 AS bu    
		INNER JOIN #OrderCond OrCond ON  OrCond.OrderGuid = bu.Guid     
		INNER JOIN bi000 AS bi ON bu.guid  = bi.parentguid     
		INNER JOIN #Src AS  src ON src.type =  bu.typeguid      
		INNER JOIN #MatTbl AS mt ON mt.guid = bi.matguid
		INNER JOIN mt000 AS mats ON mats.Guid = mt.Guid    
		INNER JOIN gr000 AS gr ON mats.GroupGuid = gr.Guid
		INNER JOIN #StoreTbl AS  st ON st.guid = bi.storeguid       
		INNER JOIN ori000 AS  ori ON ori.poiguid = bi.guid     
		INNER JOIN #TypeTbl AS type ON  type.guid = ori.typeguid      
		INNER JOIN #CustTbl as cu on cu.Guid = bu.CustGuid      
		INNER JOIN ORADDINFO000 OInfo ON bu.Guid = OInfo.ParentGuid   
	WHERE   ori.date BETWEEN ''' + Cast(@StartDate AS NVARCHAR(50)) +
                     ''' AND '''
                     + Cast(
                                @EndDate AS NVARCHAR(50)) + '''   
		AND  (OInfo.Finished =( Case ' + Cast(@IsFinished AS NVARCHAR(50)) + ' WHEN 0 THEN 0 else OInfo.Finished end  ) )   
		AND (OInfo.Add1 =( Case ' + Cast(@IsCancled AS NVARCHAR(50)) +
                                ' WHEN 0 THEN ''0'' else OInfo.Add1 end  ) )   
	GROUP BY bu.CustGuid, bu.guid, cu.CustomerName , ' + @Col1 + ( CASE @Col1
                                                                                       WHEN '' THEN ''
                                                                                       ELSE ','
                                                                                     END ) + @Col2 + ( CASE @Col2
                                                                                                         WHEN '' THEN ''
                                                                                                         ELSE ','
                                                                                                       END ) + @Col3 + ( CASE @Col3
                                                                                                                           WHEN '' THEN ''
                                                                                                                           ELSE ','
                                                                                                                         END ) + ' ori.typeguid '

          EXEC (@str)

          -- «·≈Ã„«·Ì      
          IF dbo.fnObjectExists('##CustOrderTotal') = 1
            DROP TABLE ##CustOrderTotal

          SET @str = 'SELECT ' + @Col1 + ( CASE @Col1
                                             WHEN '' THEN ''
                                             ELSE ' AS Col1, '
                                           END ) + @Col2 + ( CASE @Col2
                                                               WHEN '' THEN ''
                                                               ELSE ' AS Col2, '
                                                             END ) + @Col3 + ( CASE @Col3
                                                                                 WHEN '' THEN ''
                                                                                 ELSE ' AS Col3, '
                                                                               END ) + ' bu.CustGuid , bu.guid as orderguid, bu.date as budate, src.ordername, bu.number as ordernumber, bu.Cust_Name ,
	SUM (isnull( 
	(case  ' + Cast(@useUnit AS NVARCHAR(10)) + '   when 1 then ISNULL(bi.Qty, 0.00)       
			when 2 then ISNULL(bi.Qty, 0.00)/      
				case mats.Unit2Fact when 0 then 1      
						  else mats.Unit2Fact end      
			when 3 then ISNULL(bi.Qty, 0.00) /      
				(case mats.Unit3Fact when 0 then 1      
						   else  mats.Unit3Fact end)     
			else ISNULL(bi.Qty, 0.00) / case mats.defunit when 2 then mats.Unit2Fact     
						     when 3 then mats.Unit3Fact     
						     else 1 end end)
	,0)) AS TotalQty   
	INTO ##CustOrderTotal     
	FROM bu000 AS bu     
	INNER JOIN #OrderCond OrCond ON  OrCond.OrderGuid = bu.Guid    
	INNER JOIN bi000 AS bi ON bu.guid  = bi.parentguid     
	INNER JOIN #Src AS  src ON src.type =  bu.typeguid      
	INNER JOIN #StoreTbl AS  st ON st.guid = bi.storeguid   
	INNER JOIN #MatTbl AS mt ON mt.guid = bi.matguid       
	INNER JOIN #CustTbl as cu on cu.Guid = bu.CustGuid
	INNER JOIN mt000 AS mats ON mats.Guid = mt.Guid    
	INNER JOIN gr000 AS gr ON mats.GroupGuid = gr.Guid
	INNER JOIN ORADDINFO000 OInfo ON bu.Guid = OInfo.ParentGuid   
	WHERE   bu.date BETWEEN ''' + Cast(@StartDate AS NVARCHAR(50)) +
                     ''' AND '''
                     + Cast(
                                @EndDate AS NVARCHAR(50)) + '''	      
	AND  (OInfo.Finished =( Case ' + Cast(@IsFinished AS NVARCHAR(50)) + ' WHEN 0 THEN 0 else OInfo.Finished end  ) )   
		AND (OInfo.Add1 =( Case ' + Cast(@IsCancled AS NVARCHAR(50)) +
                     ' WHEN 0 THEN ''0'' else OInfo.Add1 end  ) )   
	GROUP BY bu.CustGuid, bu.guid, bu.date, src.ordername, bu.number, bu.Cust_Name ' + ( CASE @Col1
                                                                                                             WHEN '' THEN ''
                                                                                                             ELSE ', '
                                                                                                           END ) + @Col1 + ( CASE @Col2
                                                                                                                               WHEN '' THEN ''
                                                                                                                               ELSE ', '
                                                                                                                             END ) + @Col2 + ( CASE @Col3
                                                                                                                                                 WHEN '' THEN ''
                                                                                                                                                 ELSE ', '
                                                                                                                                               END ) + @Col3

          EXEC (@str)

          -----------------------------------------------------------------------------------------------------------------------   
          EXEC ('SELECT DISTINCT r.typeguid,
                oit.NAME      AS NAME,
                oit.LatinName AS LatinName,
                oit.postQty
FROM   ##CustOrderTypeQty AS r
       LEFT JOIN oit000 AS oit
              ON r.typeguid = oit.guid
ORDER  BY oit.postQty')

          SET @str = 'SELECT ' + ( CASE @Col1
                                     WHEN '' THEN ''
                                     ELSE 'r.Col1'
                                   END ) + ( CASE @Col1
                                               WHEN '' THEN ''
                                               ELSE ', '
                                             END ) + ( CASE @Col2
                                                         WHEN '' THEN ''
                                                         ELSE 'r.Col2'
                                                       END ) + ( CASE @Col2
                                                                   WHEN '' THEN ''
                                                                   ELSE ', '
                                                                 END ) + ( CASE @Col3
                                                                             WHEN '' THEN ''
                                                                             ELSE 'r.Col3'
                                                                           END ) + ( CASE @Col3
                                                                                       WHEN '' THEN ''
                                                                                       ELSE ', '
                                                                                     END ) + ' r.CustGuid , r.orderguid, t1.ordername, t1.budate, t1.ordernumber, r.Cust_Name , t1.TotalQty, r.typeguid , ISNULL(r.Qty, 0.00) AS Qty, O.*, C.*  
	FROM ##CustOrderTypeQty AS r     
	INNER JOIN  ##CustOrderTotal AS t1 ON t1.CustGuid = r.CustGuid AND t1.orderguid = r.orderguid ' + CASE
                     @Col1
                                       WHEN '' THEN ''
                                       ELSE ' AND r.Col1 = t1.Col1 '
                                     END + CASE @Col2
                                             WHEN '' THEN ''
                                             ELSE ' AND r.Col2 = t1.Col2 '
                                           END + CASE @Col3
                                                   WHEN '' THEN ''
                                                   ELSE ' AND r.Col3 = t1.Col3 '
                                                 END + ' LEFT JOIN ##CustFlds C ON C.CustFldGuid = r.CustGuid ' +
                     ' LEFT JOIN ##OrderFlds O ON O.OrderFldGuid = r.orderguid
	ORDER BY r.CustGuid '

          EXEC GetOrderFlds
            @OrderFldsFlag,
            @OrderCFlds

          EXEC (@str)

          IF dbo.fnObjectExists('##CustOrderTypeQty') = 1
            DROP TABLE ##CustOrderTypeQty

          IF dbo.fnObjectExists('##CustOrderTotal') = 1
            DROP TABLE ##CustOrderTotal
      END

    SELECT *
    FROM   #SecViol 
######################################################################################## 
#END
