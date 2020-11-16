########################################################################################
CREATE PROCEDURE prcLeadTime  
	@CustGuid UNIQUEIDENTIFIER = 0x00, 
	@MatGuid UNIQUEIDENTIFIER = 0x00, 
	@CostGuid UNIQUEIDENTIFIER = 0x00, 
	@GroupGuid UNIQUEIDENTIFIER = 0x00, 
	@StartDate DATETIME = '1/1/1980', 
	@EndDate DATETIME = '1/1/1980', 
	@BillSrcs UNIQUEIDENTIFIER = 0x00, 
	@TypeSrcs UNIQUEIDENTIFIER = 0x00, 
	@GroupResult BIT = 1, 
	@MatCond	UNIQUEIDENTIFIER = 0x00,   
	@CustCondGuid	UNIQUEIDENTIFIER = 0x00,   
	@OrderCond	UNIQUEIDENTIFIER = 0x00,	   
	@MatFldsFlag	BIGINT = 0, 			   
	@CustFldsFlag	BIGINT = 0, 			   
	@OrderFldsFlag	BIGINT = 0, 		   
	@MatCFlds 	NVARCHAR (max) = '', 		   
	@CustCFlds 	NVARCHAR (max) = '', 		   
	@OrderCFlds NVARCHAR (max) = '', 
	@OrderIndex	BIGINT = 0, 
	@StoreGuid	UNIQUEIDENTIFIER = 0x00
	/*,  
	--@Collect1	INT = 0,   
	--@Collect2	INT = 0,   
	--@Collect3	INT = 0*/    
AS 
	EXECUTE prcNotSupportedInAzureYet
	/*
	SET NOCOUNT ON  
	--///////////////////////////////////////////////////////////////////////////////    
	---------------------    #BtTbl   ------------------------  
	-- ÃœÊ· √‰Ê«⁄ «·ÿ·»Ì«  «· Ì  „ «Œ Ì«—Â« ›Ì ﬁ«∆„… √‰Ê«⁄ «·ÿ·»«   
	CREATE TABLE #BtTbl (  
		Type        UNIQUEIDENTIFIER,  
		Sec         INT,                
		ReadPrice   INT,                
		UnPostedSec INT)                
	INSERT INTO #BtTbl EXEC prcGetBillsTypesList2 @BillSrcs 
	----------------------------------------------------------------------------------------- 
	-- EXEC  [prcGetCostsList] 
	----------------------------------------------------------------------------------------- 
	CREATE TABLE [#CostTbl]( [CostGUID] UNIQUEIDENTIFIER, [Security] INT)  
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID 
	IF @costGuid = 0x00        
		INSERT INTO #CostTbl VALUES(0x00,0)     
		 
	------------------------------------------------------------------- 
	-------------------     #OitTbl   -------------------------  
	-- ÃœÊ· Õ«·«  «·ÿ·»  
	DECLARE @OitTbl TABLE (   
		StateGuid  UNIQUEIDENTIFIER,  
		Name       NVARCHAR(255) COLLATE ARABIC_CI_AI,  
		LatinName  NVARCHAR(255) COLLATE ARABIC_CI_AI,  
		Operation INT,  
		PostQty    INT)        
	    
	INSERT INTO @OitTbl      
		SELECT IdType, Name, LatinName, Operation, PostQty  
		FROM 
			RepSrcs AS t1  
			INNER JOIN dbo.fnGetOrderItemTypes() AS t2 
			ON t1.IdType = t2.Guid  
		WHERE IdTbl = @TypeSrcs 
		ORDER BY PostQty 
	-------------------------------------------------------------------	   
	-------------------------   #OrdersCondTbl   ---------------------- 
	--  ÃœÊ· «·ÿ·»Ì«  «· Ì  Õﬁﬁ «·‘—Êÿ  
	CREATE TABLE #OrdersCondTbl (  
    	OrderGuid UNIQUEIDENTIFIER,   
		Security  INT)  
    
	INSERT INTO #OrdersCondTbl (OrderGuid, Security) EXEC prcGetOrdersList @OrderCond	       
	-------------------------------------------------------------------  
   
	-------------------------   #CustTbl   ---------------------------  
	-- ÃœÊ· «·“»«∆‰ «· Ì  Õﬁﬁ «·‘—Êÿ  
	CREATE TABLE #CustTbl (  
    	CustGuid UNIQUEIDENTIFIER,   
		Security INT)  
	INSERT INTO #CustTbl EXEC prcGetCustsList @CustGuid, NULL, @CustCondGuid  -- Œÿ√ 
	IF (ISNULL(@CustGuid,0x0) = 0x00 ) AND (ISNULL(@CustCondGuid,0x0) = 0X0)
		INSERT INTO #CustTbl VALUES(0x0, 1)  
	-------------------------------------------------------------------  
	---------------------------   #MatTbl   ---------------------------- 
	--  ÃœÊ· «·„Ê«œ «· Ì  Õﬁﬁ «·‘—Êÿ  
	CREATE TABLE #MatTbl (  
    	MatGuid  UNIQUEIDENTIFIER,   
		Security INT)             
	INSERT INTO #MatTbl EXEC prcGetMatsList  @MatGuid, @GroupGuid, -1, @MatCond                
	------------------------------------------------------------------- 
	-------Store Table----------------------------------------------------------   
	DECLARE @StoreTbl TABLE( [GUID] [UNIQUEIDENTIFIER] )
	INSERT INTO @StoreTbl SELECT [Guid] FROM [fnGetStoresList]( @StoreGUID)
	-------------------------------------------------------------------
	------------------------  #bi  --------------------------- 
	SELECT  
		bt.Guid AS BtGuid, 
		bu.Guid AS BuGuid, 
		bt.Abbrev + '-' + CAST(bu.Number AS NVARCHAR(10)) AS BuName, 
		bu.Date AS BuDate, 
		bi.Guid AS BiGuid, 
		bi.MatGuid AS MatGuid, 
		mt.Name    AS MatName, 
		bu.CustGuid, 
		bu.Cust_Name AS CustName 
	INTO #bi 
	FROM  
		bt000 AS bt 
		INNER JOIN #BtTbl 		   AS bts ON bt.Guid       = bts.Type 
		INNER JOIN bu000  		   AS bu  ON bu.TypeGuid   = bts.Type 
		INNER JOIN #CostTbl        AS co  ON co.CostGUID   = bu.CostGUID 
		INNER JOIN #OrdersCondTbl  AS buc ON buc.OrderGuid = bu.Guid 
		INNER JOIN @StoreTbl	   AS st  ON st.[GUID]	   = bu.StoreGUID
		 
		INNER JOIN bi000 AS bi ON bi.ParentGuid = bu.Guid 
		INNER JOIN mt000 AS mt ON mt.Guid = bi.MatGuid 
		INNER JOIN #CustTbl AS cu  ON cu.CustGuid = bu.CustGuid	 
		INNER JOIN #MatTbl  AS mat ON mat.MatGuid = bi.MatGuid 
	WHERE  
		bu.Date BETWEEN @StartDate AND @EndDate 
	-------------------------------------------------------------------------- 
	 
	------------------------------     #ori     ------------------------------ 
	SELECT  
		ori.POIGuid  AS BiGuid, 
		ori.TypeGuid, 
		bi.CustGuid, 
		(CASE oit.PostQty  
			WHEN (SELECT MAX(PostQty)  
				  FROM @OitTbl  
                  WHERE StateGuid IN (SELECT DISTINCT TypeGuid  
								      FROM ori000 
									  WHERE POIGuid = ori.POIGuid 
                                      ) 
                  )  
            THEN MAX(ori.Date)  
			ELSE MIN(ori.Date)  
		 END) AS OriDate 
	INTO #ori 
	FROM  
		           ori000  AS ori 
		INNER JOIN #bi     AS bi  ON bi.BiGuid     = ori.POIGuid 
		INNER JOIN @OitTbl AS oit ON oit.StateGuid = ori.TypeGuid	 
	GROUP BY  
		ori.POIGuid, bi.CustGuid, ori.TypeGuid, oit.PostQty 
	--------------------------------------------------------------------------- 
	SELECT DISTINCT 
		bi.BtGuid, 
		bi.BuGuid, 
		bi.BuName, 
		bi.BuDate, 
		bi.BiGuid, 
		bi.MatGuid, 
		bi.MatName, 
		bi.CustGuid, 
		bi.CustName, 
		ori.TypeGuid, 
		ori.OriDate, 
		DATEDIFF(day,  
				 (SELECT MIN(OriDate) FROM #ori WHERE BiGuid = bi.BiGuid), 
				 (SELECT MAX(OriDate) FROM #ori WHERE BiGuid = bi.BiGuid) 
		)+ CASE (SELECT COUNT(*) FROM #ori o WHERE o.BiGuid = bi.BiGuid) WHEN 1 THEN 0 ELSE 1 END AS Days 
	INTO #Detailed 
	FROM  
		#bi AS bi 
		INNER JOIN #ori AS ori ON ori.BiGuid = bi.BiGuid 
	ORDER BY  
		bi.BtGuid, 
		bi.BuGuid, 
		bi.BiGuid 
	------------------------------------------------------- 
	EXEC GetMatFlds   @MatFldsFlag,   @MatCFlds  
	EXEC GetCustFlds  @CustFldsFlag,  @CustCFlds  
	------------------------------------------------------- 
	IF @GroupResult = 1 
	BEGIN 
		SELECT DISTINCT 
			d.BuGuid, 
			d.MatGuid, 
			d.MatName, 
			d.CustGuid, 
			d.CustName, 
			d.Days 
		INTO #DistinctDetailed 
		FROM  
			#Detailed AS d 
		SELECT 
			d.MatGuid, 
			d.MatName, 
			d.CustGuid, 
			d.CustName, 
			AVG(d.Days) AS Days 
		INTO #Grouped 
		FROM  
			#DistinctDetailed AS d 
		GROUP BY d.MatGuid, d.MatName, d.CustGuid, d.CustName			 
		 
		SELECT DISTINCT 
			M.*, 
			g.*, 
			C.* 
		FROM  
			#Grouped AS g 
			INNER JOIN ##MatFlds   M ON M.MatFldGuid   = g.MatGuid 
			LEFT  JOIN ##CustFlds  C ON C.CustFldGuid  = g.CustGuid 
		ORDER BY g.MatName, g.CustName 
	END 
	ELSE 
	BEGIN 
		-------------------------------------------------- 
		EXEC GetOrderFlds @OrderFldsFlag, @OrderCFlds   
		-------------------------------------------------- 
		-- result 0 
		SELECT * FROM @OitTbl ORDER BY PostQty 
		-- result 1
		
	
		SELECT DISTINCT 
			d.*, 
			M.*, 
			C.*, 
			O.* 
		INTO #TEMP 
		FROM  
			#Detailed AS d 
			INNER JOIN ##MatFlds   M ON M.MatFldGuid   = d.MatGuid 
			LEFT  JOIN ##CustFlds  C ON C.CustFldGuid  = d.CustGuid 
			INNER JOIN ##OrderFlds O ON O.OrderFldGuid = d.BuGuid 
			--«·›—“ Õ”» —À„ «·ÿ·»Ì… Ê «—ÌŒÂ« 
		DECLARE @s AS  NVARCHAR(max);
		SET @s = 'SELECT * FROM  #TEMP  ORDER BY   '+
		CASE @OrderIndex WHEN 0 THEN ' BuName '
		WHEN 1 THEN ' BuDate ' END
		EXEC (@s);
	END 
	*/
--EXECUTE  [prcLeadTime] '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '1/1/2010 0:0:0.0', '10/23/2010 23:59:47.951', 'b34e0507-0463-4fe1-bf4b-a415a6075544', 'e44176e8-bd76-4339-b0fc-c72f5ea92902', 0, '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 0, 0, 0, '', '', '', 0
########################################################################################
#END