################################################################
CREATE PROCEDURE prcSPOrdersReport
-- PARAMETERS 
	@Acc             UNIQUEIDENTIFIER,        -- 1 «·Õ”«» 
	@Cost            UNIQUEIDENTIFIER,        -- 2 „—ﬂ“ «·ﬂ·›… 
	@Mat             UNIQUEIDENTIFIER,        -- 3 «·„«œ… 
	@Grp             UNIQUEIDENTIFIER,        -- 4 «·„Ã„Ê⁄… 
	@Store           UNIQUEIDENTIFIER,        -- 5 «·„” Êœ⁄ 
	@StartDate       DATETIME,                -- 6  «—ÌŒ «·»œ«Ì… 
	@EndDate         DATETIME,                -- 7  «—ÌŒ «·‰Â«Ì… 
	@OrderTypesSrc   UNIQUEIDENTIFIER,        -- 11 √‰Ê«⁄ «·ÿ·»«  
    @Unit            INT,                     -- 14 «·ÊÕœ… 
	@isFinished      BIT = 0,                 -- 15 ≈ŸÂ«— «·ÿ·»«  «·„‰ ÂÌ… 
	@isCanceled      BIT = 0,                 -- 16 ≈ŸÂ«— «·ÿ·»«  «·„·€Ì… 
	@MatCond	     UNIQUEIDENTIFIER = 0x00, -- 17 ‘—Êÿ «·„«œ… 
	@CustCondGuid	     UNIQUEIDENTIFIER = 0x00, -- 18 ‘—Êÿ «·“»Ê‰ 
	@OrderCond	     UNIQUEIDENTIFIER = 0x00,  -- 19 ‘—Êÿ «·ÿ·» 
	@MatFldsFlag	 BIGINT = 0, 			  
	@CustFldsFlag	 BIGINT = 0, 			  
	@OrderFldsFlag	 BIGINT = 0, 		  
	@MatCFlds 		 NVARCHAR (max) = '', 		  
	@CustCFlds 		 NVARCHAR (max) = '', 		  
	@OrderCFlds 	 NVARCHAR (max) = ''
AS 
	EXECUTE prcNotSupportedInAzureYet
	/*
	SET NOCOUNT ON 
	---------------------    #OrderTypesTbl   ------------------------  
	-- ÃœÊ· √‰Ê«⁄ «·ÿ·»Ì«  «· Ì  „ «Œ Ì«—Â« ›Ì ﬁ«∆„… √‰Ê«⁄ «·ÿ·»«   
	CREATE TABLE #OrderTypesTbl (  
		Type        UNIQUEIDENTIFIER,  
		Sec         INT,                
		ReadPrice   INT,                
		UnPostedSec INT)                
	INSERT INTO #OrderTypesTbl EXEC prcGetBillsTypesList2 @OrderTypesSrc  
	-------------------------------------------------------------------           
	-------------------     @OrderStatesTbl   -------------------------  
	-- ÃœÊ· Õ«·«  «·ÿ·»  
	DECLARE @OrderStatesTbl TABLE (   
		StateGuid  UNIQUEIDENTIFIER,  
		Name       NVARCHAR(255) COLLATE ARABIC_CI_AI,  
		LatinName  NVARCHAR(255) COLLATE ARABIC_CI_AI,  
		Operation INT,  
		PostQty    INT)        
	    
	INSERT INTO @OrderStatesTbl      
		SELECT Guid,   
               Name,   
               LatinName,   
               Operation,   
			   PostQty  
		FROM 
			fnGetOrderItemTypes() 
		ORDER BY Number 
	-------------------------------------------------------------------	   
	-------------------------   #OrdersTbl   --------------------------    
	--  ÃœÊ· «·ÿ·»Ì«  «· Ì  Õﬁﬁ «·‘—Êÿ  
	CREATE TABLE #OrdersTbl (  
    	OrderGuid UNIQUEIDENTIFIER,   
		Security  INT)  
    
	INSERT INTO #OrdersTbl (OrderGuid, Security) EXEC prcGetOrdersList @OrderCond	       
	-------------------------------------------------------------------    
	-------------------------   #CustTbl   ---------------------------  
	-- ÃœÊ· «·“»«∆‰ «· Ì  Õﬁﬁ «·‘—Êÿ  
	CREATE TABLE #CustTbl (  
    	CustGuid UNIQUEIDENTIFIER,   
		Security INT)  
	INSERT INTO #CustTbl EXEC prcGetCustsList NULL, @Acc, @CustCondGuid  
	IF (ISNULL(@Acc,0x0) = 0x00 ) AND (ISNULL(@CustCondGuid,0x0) = 0X0)
		INSERT INTO #CustTbl VALUES(0x0, 1)  
	-------------------------------------------------------------------  
	-------------------------------------------------------------------  
	--  ÃœÊ· «·„Ê«œ «· Ì  Õﬁﬁ «·‘—Êÿ  
	CREATE TABLE #MatTbl (  
    	MatGuid  UNIQUEIDENTIFIER,   
		Security INT)             
	INSERT INTO #MatTbl EXEC prcGetMatsList  @Mat, @Grp, -1, @MatCond                
	-------------------------------------------------------------------  
	-------------------------------------------------------------------  
	--	ÃœÊ· «·„” Êœ⁄«   
	DECLARE @StoreTbl TABLE (  
		StoreGuid UNIQUEIDENTIFIER)  
	INSERT INTO @StoreTbl SELECT Guid FROM fnGetStoresList(@Store)  
	-------------------------------------------------------------------  
	-------------------------------------------------------------------  
	-- ÃœÊ· „—«ﬂ“ «·ﬂ·›…  
	DECLARE @CostTbl TABLE (  
		CostGuid UNIQUEIDENTIFIER)  
           
	INSERT INTO @CostTbl SELECT Guid FROM fnGetCostsList(@Cost)  
	IF ISNULL(@Cost, 0x0) = 0x0        
		INSERT INTO @CostTbl VALUES(0x0)     
	-------------------------------------------------------------------  
	-----------------------   #OrderedMats  ---------------------------  
	-- ÃœÊ· «·„Ê«œ «·„ÿ·Ê»…  
	SELECT DISTINCT  
		BT.Guid      AS TypeGuid,  
		BT.bIsInput  AS IsInput,  
		BU.Guid      AS OrderGuid,  
		BU.Number    AS OrderNumber,  
		BU.Cust_Name AS Customer,  
		BI.Guid      AS ItemGuid,  
		BI.MatGuid   AS OrderedMat,  
        BI.Qty       AS OrderQty  
	INTO #OrderedMats  
	FROM  
		           bt000          AS BT 	  
		INNER JOIN #OrderTypesTbl AS OTypes ON BT.Guid          = OTypes.Type  
		INNER JOIN bu000          AS BU     ON OTypes.Type      = BU.TypeGuid  
		INNER JOIN @CostTbl       AS Costs  ON BU.CostGuid      = Costs.CostGuid  
		INNER JOIN #OrdersTbl     AS Orders ON Orders.OrderGuid = BU.Guid  
		INNER JOIN bi000          AS BI     ON BI.ParentGuid    = Orders.OrderGuid  
		INNER JOIN #CustTbl       AS Custs  ON BU.CustGuid      = Custs.CustGuid  
		INNER JOIN #MatTbl        AS Mats   ON BI.MatGuid       = Mats.MatGuid  
		INNER JOIN OrAddInfo000   AS Info   ON Info.ParentGuid  = Orders.OrderGuid  
		INNER JOIN ori000         AS ORI    ON ORI.POIGuid      = BI.Guid  
	WHERE  
		(ORI.Date BETWEEN @StartDate AND @EndDate)   
		AND (Info.Finished = (CASE @isFinished WHEN 0 THEN 0 ELSE Info.Finished END))  
		AND (Info.Add1 = (CASE @isCanceled WHEN 0 THEN '0' ELSE Info.Add1 END))  
	-------------------------------------------------------------------  
    SELECT DISTINCT  
		BT.Guid             AS TypeGuid,  
		BT.bIsInput         AS IsInput,  
		BU.Guid             AS OrderGuid,  
		BI.Guid             AS ItemGuid,  
		BT.Abbrev + '-' + CONVERT(NVARCHAR(10), Ordered.OrderNumber) AS TypeName,  
		Ordered.Customer,  
		Ordered.OrderedMat  AS MatGuid,  
		MT.Name             AS Mat,  
		(CASE @Unit    
			WHEN 2 THEN MT.Unit2 
			WHEN 3 THEN MT.Unit3 
			WHEN 4 THEN 
				CASE MT.DefUnit 
					WHEN 2 THEN MT.Unit2 
					WHEN 3 THEN MT.Unit3 
					ELSE MT.Unity 
				END    
			ELSE MT.Unity       
		END) AS UnitName,  
		ST.Name             AS Store,  
		MS.Qty              AS QtyInStore,  
		Ordered.OrderQty,  
		BU.Date             AS OrderDate, 
		BU.CustGuid 
	INTO #info  
	FROM  
		           bt000          AS BT 	  
		INNER JOIN bu000          AS BU      ON BT.Guid            = BU.TypeGuid  
		INNER JOIN bi000          AS BI      ON BI.ParentGuid      = BU.Guid   
		INNER JOIN mt000          AS MT      ON BI.MatGuid         = MT.Guid  
		INNER JOIN st000          AS ST      ON BI.StoreGuid       = ST.Guid  
		LEFT  JOIN ms000          AS MS      ON BI.StoreGuid       = MS.StoreGuid AND  
		                                        BI.MatGuid         = MS.MatGuid  
		INNER JOIN #OrderTypesTbl AS OTypes  ON OTypes.Type        = BT.Guid      
		INNER JOIN #OrdersTbl     AS Orders  ON Orders.OrderGuid   = BU.Guid  
		INNER JOIN @CostTbl       AS Costs   ON Costs.CostGuid     = BU.CostGuid  
		INNER JOIN #CustTbl       AS Custs   ON Custs.CustGuid     = BU.CustGuid  
		INNER JOIN @StoreTbl      AS Stores  ON Stores.StoreGuid   = BU.StoreGuid  
		INNER JOIN #OrderedMats   AS Ordered ON Ordered.OrderedMat = BI.MatGuid       AND  
											    Ordered.TypeGuid   = OTypes.Type      AND  
												Ordered.OrderGuid  = Orders.OrderGuid  AND
												Ordered.ItemGuid   = BI.Guid 
		INNER JOIN OrAddInfo000   AS Info    ON Info.ParentGuid    = Orders.OrderGuid  
	WHERE  
		(BU.Date BETWEEN @StartDate AND @EndDate)  
		AND (Info.Finished = (CASE @isFinished WHEN 0 THEN 0 ELSE Info.Finished END))  
		AND (Info.Add1 = (CASE @isCanceled WHEN 0 THEN '0' ELSE Info.Add1 END))  
	-------------------------------------------------------------------  
	-- ÃœÊ· »«·„Ê«œ «·„—Õ·… „‰ Õ«·… ≈·Ï Õ«·… √Œ—Ï „⁄  «—ÌŒ «· —ÕÌ·  
	SELECT DISTINCT  
		Ordered.TypeGuid,  
		Ordered.IsInput,  
		Ordered.OrderGuid,  
		ORI1.POIGuid        AS ItemGuid,  
		ORI1.Number         AS OpNumber,  
		Ordered.OrderedMat,  
		ORI1.Date           AS DeportationDate,  
		ORI2.Qty            AS DeportedQty,  
		ORI1.TypeGuid       AS SrcState,  
		ORI2.TypeGuid       AS DestState  
	INTO #Deported  
	FROM  
		 		   ori000        AS ORI1   
		INNER JOIN ori000        AS ORI2    ON ORI1.POIGuid = ORI2.POIGuid  
		INNER JOIN #OrderedMats  AS Ordered ON ORI1.POIGuid = Ordered.ItemGuid  
	WHERE  
		    (ORI1.Qty  = 0 - ORI2.Qty)   
		AND (ORI2.Qty  > 0)              
		AND (ORI1.Date = ORI2.Date)  
		AND (ORI1.Number = ORI2.Number - 1)         
		AND (ORI1.Date BETWEEN @StartDate AND @EndDate)  
		AND (ORI1.POGuid IN (SELECT OrderGuid FROM #info))    
		AND (ORI1.Number <> 0)  
		AND (ORI2.Number <> 0) 
	 
	DECLARE @in BIT,  
			@bt UNIQUEIDENTIFIER,  
			@bu UNIQUEIDENTIFIER,  
			@it UNIQUEIDENTIFIER,  
			@nm INT,  
		    @mt UNIQUEIDENTIFIER,  
		    @dt DATETIME,  
			@oq FLOAT  
	DECLARE i CURSOR FOR SELECT TypeGuid, IsInput, OrderGuid, ItemGuid, MatGuid, OrderDate, OrderQty FROM #info  
	OPEN i  
		FETCH NEXT FROM i INTO @bt, @in, @bu, @it, @mt, @dt, @oq  
		WHILE @@FETCH_STATUS = 0  
		BEGIN  
			DECLARE @FirstState UNIQUEIDENTIFIER
			
			SELECT TOP 1 @FirstState = oit.guid
			FROM oit000 oit INNER JOIN oitvs000 vs ON oit.GUID = vs.ParentGuid
			WHERE vs.OTGUID = @bt AND vs.Selected = 1 AND oit.Type = 1 - @in
			ORDER BY oit.PostQty
		
			INSERT INTO #Deported VALUES (@bt, @in, @bu, @it, 0, @mt, @dt, @oq, NULL, @FirstState)  
			FETCH NEXT FROM i INTO @bt, @in, @bu, @it, @mt, @dt, @oq  
		END  
	CLOSE i  
	DEALLOCATE i  
	-------------------------------------------------------------------  
	-------------------------------------------------------------------  
	-- ÃœÊ· »ﬂ„Ì«  «·„Ê«œ ›Ì ﬂ· Õ«·… Õ”» «· «—ÌŒ  
	DECLARE @MatsQtyInStatesByDate TABLE (  
		TypeGuid  UNIQUEIDENTIFIER,  
		IsInput   BIT,  
		OrderGuid UNIQUEIDENTIFIER,  
		ItemGuid  UNIQUEIDENTIFIER,  
		Number    INT,  
		MatGuid   UNIQUEIDENTIFIER,  
		Qty       FLOAT,  
		StateGuid UNIQUEIDENTIFIER,  
		OnDate    DATETIME)  
	  
	DECLARE @dq FLOAT,  
		    @fs UNIQUEIDENTIFIER,  
		    @ts UNIQUEIDENTIFIER  
	DECLARE @Temp TABLE (  
		TypeGuid  UNIQUEIDENTIFIER,  
		OrderGuid UNIQUEIDENTIFIER,  
		ItemGuid   UNIQUEIDENTIFIER,  
		QtyInState FLOAT,  
		StateGuid  UNIQUEIDENTIFIER)  
	-- TODO: speed up the following loop  
	DECLARE c CURSOR FOR SELECT * FROM #Deported  
	OPEN c  
		FETCH NEXT FROM c INTO @bt, @in, @bu, @it, @nm, @mt, @dt, @dq, @fs, @ts  
		WHILE @@FETCH_STATUS = 0  
		BEGIN  
			  
			DECLARE @AddedQtys FLOAT  
			DECLARE @DeportedQtys FLOAT  
			DECLARE @QtyInStateOnDate FLOAT  
			  
			IF @fs IS NOT NULL  
			BEGIN  
				DELETE FROM @Temp  
				INSERT INTO @Temp  
					SELECT TypeGuid, OrderGuid, ItemGuid, SUM(DeportedQty), DestState  
					FROM #Deported  
					WHERE OpNumber        <= @nm AND  
						  DeportationDate <= @dt AND  
						  ItemGuid         = @it AND  
						  DestState        = @fs  
					GROUP BY TypeGuid, OrderGuid, ItemGuid, DestState  
	  
				SELECT @AddedQtys = QtyInState FROM @Temp  
	  
				DELETE FROM @Temp  
				INSERT INTO @Temp  
					SELECT TypeGuid, OrderGuid, ItemGuid, SUM(DeportedQty), SrcState  
					FROM #Deported  
					WHERE OpNumber        <= @nm AND  
						  DeportationDate <= @dt AND  
						  ItemGuid         = @it AND  
						  SrcState         = @fs  
					GROUP BY TypeGuid, OrderGuid, ItemGuid, SrcState  
	  
				SELECT @DeportedQtys = QtyInState FROM @Temp  
	  
				SET @QtyInStateOnDate = @AddedQtys - @DeportedQtys  
	  
				INSERT INTO @MatsQtyInStatesByDate VALUES (@bt, @in, @bu, @it, @nm, @mt, @QtyInStateOnDate, @fs, @dt)  
			END  
			DELETE FROM @Temp  
			INSERT INTO @Temp  
				SELECT TypeGuid, OrderGuid, ItemGuid, SUM(DeportedQty), DestState  
				FROM #Deported  
				WHERE OpNumber        <= @nm AND  
				      DeportationDate <= @dt AND  
					  ItemGuid         = @it AND  
					  DestState        = @ts  
				GROUP BY TypeGuid, OrderGuid, ItemGuid, DestState  
			SELECT @AddedQtys = QtyInState FROM @Temp  
			DELETE FROM @Temp  
			INSERT INTO @Temp  
				SELECT TypeGuid, OrderGuid, ItemGuid, SUM(DeportedQty), SrcState  
				FROM #Deported  
				WHERE OpNumber        <= @nm AND  
					  DeportationDate <= @dt AND  
					  ItemGuid         = @it AND  
					  SrcState         = @ts  
				GROUP BY TypeGuid, OrderGuid, ItemGuid, SrcState  
			IF ((SELECT COUNT(*) FROM @Temp) = 0)  
				SET @DeportedQtys = 0  
			ELSE  
				SELECT @DeportedQtys = QtyInState FROM @Temp  
			SET @QtyInStateOnDate = @AddedQtys - @DeportedQtys  
			INSERT INTO @MatsQtyInStatesByDate VALUES (@bt, @in, @bu, @it, @nm, @mt, @QtyInStateOnDate, @ts, @dt)  
			FETCH NEXT FROM c INTO @bt, @in, @bu, @it, @nm, @mt, @dt, @dq, @fs, @ts  
		END  
	CLOSE c  
	DEALLOCATE c  
	-------------------------------------------------------------------  
	/*===============================================================*  
	 *                       R E S U L T S                           *  
	 *===============================================================*/  
	-- Result 0  
	/*	  
	StateGuid | Name | LatinName | Operation | PostQty  
	-----------------------------------------------------------------  
	          |      |           |            |         
	*/  
	SELECT *   
	FROM @OrderStatesTbl  
	WHERE (StateGuid IN (SELECT SrcState FROM #Deported)) OR (StateGuid IN (SELECT DestState FROM #Deported))
	-- Result 1  
	/*	  
	TypeGuid | IsInput | OrderGuid |ItemGuid | TypeName | Customer | MatGuid | Mat (code-name) | UnitName | Store | QtyInStore | OrderQty | OrderDate  
	----------------------------------------------------------------------------------------------------------------------------------------  
	         |         |           |         |          |          |         |                 |          |       |            |          |              
	*/ 
	EXEC GetMatFlds   @MatFldsFlag,   @MatCFlds  
	EXEC GetCustFlds  @CustFldsFlag,  @CustCFlds  
	EXEC GetOrderFlds @OrderFldsFlag, @OrderCFlds   
	SELECT   
		TypeGuid,  
		IsInput,   
		OrderGuid,  
		ItemGuid,   
		TypeName,   
		Customer,  
 		MatGuid,   
		Mat,   
		UnitName,  
		Store,   
		(QtyInStore / CASE @Unit   
						WHEN 2 THEN CASE ISNULL(MT.mtUnit2Fact, 0)   WHEN 0 THEN 1 ELSE MT.mtUnit2Fact   END      
						WHEN 3 THEN CASE ISNULL(MT.mtUnit3Fact, 0)   WHEN 0 THEN 1 ELSE MT.mtUnit3Fact   END      
						WHEN 4 THEN CASE ISNULL(MT.mtDefUnitFact, 0) WHEN 0 THEN 1 ELSE MT.mtDefUnitFact END     
						ELSE 1      
					  END)  
		AS QtyInStore,  
		(OrderQty / CASE @Unit   
						WHEN 2 THEN CASE ISNULL(MT.mtUnit2Fact, 0)   WHEN 0 THEN 1 ELSE MT.mtUnit2Fact   END      
						WHEN 3 THEN CASE ISNULL(MT.mtUnit3Fact, 0)   WHEN 0 THEN 1 ELSE MT.mtUnit3Fact   END      
						WHEN 4 THEN CASE ISNULL(MT.mtDefUnitFact, 0) WHEN 0 THEN 1 ELSE MT.mtDefUnitFact END     
						ELSE 1      
					  END)  
		AS OrderQty,   
		OrderDate, 
		M.*, 
		C.*, 
		O.* 
	INTO #info2 
	FROM #info AS info INNER JOIN vwMt AS MT ON info.MatGuid = MT.mtGuid 
					   INNER JOIN ##MatFlds M ON M.MatFldGuid = info.MatGuid 
					   LEFT  JOIN ##CustFlds C ON C.CustFldGuid = info.CustGuid 
					   INNER JOIN ##OrderFlds O ON O.OrderFldGuid = info.OrderGuid 
	ORDER BY IsInput, TypeGuid, OrderGuid, ItemGuid  
	 
	SELECT DISTINCT * FROM #info2 ORDER BY IsInput, TypeGuid, OrderGuid, ItemGuid 
	-- Result 2  
	/*	  
	TypeGuid | IsInput | OrderGuid |ItemGuid | OpNumber | OrderedMat | DeportationDate | DeportedQty | SrcState | DestState   
	----------------------------------------------------------------------------------------------------------------------------------  
	         |          |          |         |          |            |                 |             |          |        
	*/
	SELECT   
		TypeGuid,   
		IsInput,   
		OrderGuid,  
		ItemGuid,   
		OpNumber,  
		OrderedMat,   
		DeportationDate,  
		(DeportedQty / CASE @Unit   
						WHEN 2 THEN CASE ISNULL(MT.mtUnit2Fact, 0)   WHEN 0 THEN 1 ELSE MT.mtUnit2Fact   END      
						WHEN 3 THEN CASE ISNULL(MT.mtUnit3Fact, 0)   WHEN 0 THEN 1 ELSE MT.mtUnit3Fact   END      
						WHEN 4 THEN CASE ISNULL(MT.mtDefUnitFact, 0) WHEN 0 THEN 1 ELSE MT.mtDefUnitFact END     
						ELSE 1      
					  END)  
		AS DeportedQty,   
		SrcState,   
		DestState    
	FROM #Deported AS D INNER JOIN vwMt AS MT ON D.OrderedMat = MT.mtGuid   
    ORDER BY IsInput, TypeGuid, OrderGuid, ItemGuid, OpNumber, DeportationDate, OrderedMat  
	-- Result 3  
	/*	  
	TypeGuid | IsInput | OrderGuid |ItemGuid | Number | MatGuid | Qty | StateGuid | OnDate  
	---------------------------------------------------------------------------------------  
	         |         |           |         |        |         |     |           |    
	*/  
	SELECT   
		TypeGuid,   
		IsInput,  
		OrderGuid,  
		ItemGuid,  
		Number,  
		MatGuid,  
		(Qty / CASE @Unit   
			 	 WHEN 2 THEN CASE ISNULL(MT.mtUnit2Fact, 0)   WHEN 0 THEN 1 ELSE MT.mtUnit2Fact   END      
				 WHEN 3 THEN CASE ISNULL(MT.mtUnit3Fact, 0)   WHEN 0 THEN 1 ELSE MT.mtUnit3Fact   END      
				 WHEN 4 THEN CASE ISNULL(MT.mtDefUnitFact, 0) WHEN 0 THEN 1 ELSE MT.mtDefUnitFact END     
				 ELSE 1      
			   END)  
		AS Qty,  
		StateGuid,  
		OnDate  
	FROM @MatsQtyInStatesByDate AS MQS INNER JOIN vwMt AS MT ON MQS.MatGuid = MT.mtGuid   
	ORDER BY IsInput, TypeGuid, OrderGuid, ItemGuid, Number, MatGuid, OnDate  
	*/  
	/*  
	EXECUTE prcSPOrdersReport   
             '00000000-0000-0000-0000-000000000000',  
             '00000000-0000-0000-0000-000000000000',  
			 '00000000-0000-0000-0000-000000000000',  
			 '00000000-0000-0000-0000-000000000000',  
			 '00000000-0000-0000-0000-000000000000',  
             '3/17/2009 0:0:0.0',                     
             '3/24/2010 23:59:59.998',               
             '00000000-0000-0000-0000-000000000000',  
			 0,  
			 0,                                       
             0,                                       
             '00000000-0000-0000-0000-000000000000',  
             '00000000-0000-0000-0000-000000000000',  
             '00000000-0000-0000-0000-000000000000'   
	*/
	  
################################################################
#END	