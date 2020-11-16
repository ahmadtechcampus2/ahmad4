################################################################
CREATE PROCEDURE prcReadyOrdersRep
-- PARAMETERS 
	@Acc             UNIQUEIDENTIFIER = 0x0,
	@Mat             UNIQUEIDENTIFIER = 0x0, 
	@Grp             UNIQUEIDENTIFIER = 0x0,
	@Store           UNIQUEIDENTIFIER = 0x0,
	@StartDate       DATETIME = '01/01/1980',    
	@EndDate         DATETIME = '01/01/2015',  
	@OrderTypesSrc   UNIQUEIDENTIFIER = 0x0,
    @UseUnit         INT = 1,       
	@ResultOption    INT = 3, 
	@MatType         INT = 0,
	@MatCond	     UNIQUEIDENTIFIER = 0x0,
	@CustCondGuid	     UNIQUEIDENTIFIER = 0x0, 
	@OrderCond	     UNIQUEIDENTIFIER = 0x0,
	@MatFldsFlag	 BIGINT = 0, 			  
	@CustFldsFlag	 BIGINT = 0, 			  
	@OrderFldsFlag	 BIGINT = 0, 		  
	@MatCFlds        NVARCHAR (max) = '', 		  
	@CustCFlds 	     NVARCHAR (max) = '', 		  
	@OrderCFlds 	 NVARCHAR (max) = '',
	@CostGuid		 UNIQUEIDENTIFIER = 0x0

AS
	EXECUTE prcNotSupportedInAzureYet
	/*
	SET NOCOUNT ON 
	---------------------    #OrderTypesTbl   ------------------------  
	-- ÌÏæá ÃäæÇÚ ÇáØáÈíÇÊ ÇáÊí Êã ÇÎÊíÇÑåÇ Ýí ÞÇÆãÉ ÃäæÇÚ ÇáØáÈÇÊ  
	CREATE TABLE #OrderTypesTbl (  
		Type        UNIQUEIDENTIFIER,  
		Sec         INT,                
		ReadPrice   INT,                
		UnPostedSec INT)                
	INSERT INTO #OrderTypesTbl EXEC prcGetBillsTypesList2 @OrderTypesSrc  
	-------------------------------------------------------------------    
	-------------------------   #OrdersTbl   --------------------------    
	--  ÌÏæá ÇáØáÈíÇÊ ÇáÊí ÊÍÞÞ ÇáÔÑæØ  
	CREATE TABLE #OrdersTbl (  
    	        OrderGuid UNIQUEIDENTIFIER,   
		Security  INT)  
    
	INSERT INTO #OrdersTbl (OrderGuid, Security) EXEC prcGetOrdersList @OrderCond	       
	-------------------------------------------------------------------    
	-------------------------   #CustTbl   ---------------------------  
	-- ÌÏæá ÇáÒÈÇÆä ÇáÊí ÊÍÞÞ ÇáÔÑæØ  
	CREATE TABLE #CustTbl (  
    	CustGuid UNIQUEIDENTIFIER,   
		Security INT)  
	INSERT INTO #CustTbl EXEC prcGetCustsList NULL, @Acc, @CustCondGuid  
	IF (ISNULL(@Acc,0x0) = 0x00 ) AND (ISNULL(@CustCondGuid,0x0) = 0X0)
		INSERT INTO #CustTbl VALUES(0x0, 1)  
	-------------------------------------------------------------------  
	-------------------------------------------------------------------  
	--  ÌÏæá ÇáãæÇÏ ÇáÊí ÊÍÞÞ ÇáÔÑæØ  
	CREATE TABLE #MatTbl (  
    	MatGuid  UNIQUEIDENTIFIER,   
		Security INT)             
	INSERT INTO #MatTbl EXEC prcGetMatsList  @Mat, @Grp, -1, @MatCond                
	-------------------------------------------------------------------  
	-- Cost Table
	CREATE TABLE [#CostTbl]( [CostGUID] UNIQUEIDENTIFIER, [Security] INT)
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostGUID
	IF @CostGuid = 0x00
		INSERT INTO #CostTbl VALUES(0x00,0)
	-------------------------------------------------------------------  
	--	ÌÏæá ÇáãÓÊæÏÚÇÊ  
	DECLARE @StoreTbl TABLE (   
		[Guid] UNIQUEIDENTIFIER,
		[Name] NVARCHAR(250))   
	INSERT INTO @StoreTbl 
	SELECT 
		st.[Guid], 
		(CASE dbo.fnConnections_GetLanguage()
			WHEN 0 THEN st.[Name]
			ELSE 
				CASE st.LatinName
					WHEN '' THEN st.[Name]
					ELSE st.LatinName
				END
		END) AS [Name]
	FROM 
		dbo.fnGetStoresList(@Store) AS fn   
		INNER JOIN st000 AS st ON fn.[Guid] = st.[Guid] 
	-------------------------------------------------------------------
	-----------------------   #Detailes  --------------------------- 	 
	-- ÌÏæá ÇáãæÇÏ ÇáãØáæÈÉ  
	SELECT  
		ExBi.buType       AS SellTypeGuid,
		ExBi.btName       AS OrderName,
		ExBi.buGUID       AS OrderGuid,  
		ExBi.buNumber     AS OrderNumber, 
		ExBi.buDate       AS OrderDate, 
		ExBi.buCust_Name  AS CustName,  
		ExBi.biGUID       AS ItemGuid, 
		ExBi.mtName       AS MatName, 
		ExBi.buCustPtr    AS CustGuid, 
		ExBi.biMatPtr     AS MatGuid,
		ExBi.biStorePtr   AS StoreGuid,
		ST.Name           AS StoreName,
		
		(CASE @useUnit WHEN 1 then mtUnity 
					   WHEN 2 then (CASE mtUnit2Fact WHEN 0 then mtUnity ELSE mtUnit2 END) 
					   WHEN 3 then (CASE mtUnit3Fact WHEN 0 then mtUnity ELSE mtUnit3 END) 
					   ELSE mtDefUnitName 
		 END) AS UnitName,  
		 
		 (CASE @useUnit WHEN 1 then 1 
                        WHEN 2 then CASE mtUnit2Fact WHEN 0 then 1 ELSE mtUnit2Fact END 
                        WHEN 3 then CASE mtUnit3Fact WHEN 0 then 1 ELSE mtUnit3Fact END
                        ELSE mtDefUnitFact 
          END) AS UnitFact,
	    
        (CASE @useUnit WHEN 1 then ExBi.biQty  
                       WHEN 2 then ExBi.biQty / (CASE mtUnit2Fact WHEN 0 then 1 ELSE mtUnit2Fact END) 
                       WHEN 3 then ExBi.biQty / (CASE mtUnit3Fact WHEN 0 then 1 ELSE mtUnit3Fact END)   
                       ELSE ExBi.biQty / mtDefUnitFact 
         END) AS OrderedQty,
        
		(CASE @useUnit WHEN 1 then ISNULL(MS.Qty, 0)  
                       WHEN 2 then ISNULL(MS.Qty, 0) / (CASE mtUnit2Fact WHEN 0 then 1 ELSE mtUnit2Fact END) 
                       WHEN 3 then ISNULL(MS.Qty, 0) / (CASE mtUnit3Fact WHEN 0 then 1 ELSE mtUnit3Fact END)   
                       ELSE ISNULL(MS.Qty, 0) / mtDefUnitFact 
         END) AS StoreQty,
		
		(
			SELECT TOP 1 
				OIT.Guid AS FinalStateGuid
			FROM
				oit000 OIT
				INNER JOIN oitvs000 OITVS ON OIT.Guid = OITVS.ParentGuid
			WHERE OITVS.OtGuid = ExBi.buType AND OITVS.Selected = 1
			ORDER BY OIT.PostQty DESC
		) AS FinalStateGuid,
		Exbi.biUnitPrice AS UnitPrice
	INTO #Detailes  
	FROM  
				   vwExtended_bi AS ExBi
		INNER JOIN #OrderTypesTbl AS OTypes ON ExBi.buType      = OTypes.Type  
		INNER JOIN #OrdersTbl     AS Orders ON Orders.OrderGuid = ExBi.buGUID
		INNER JOIN #CustTbl       AS Custs  ON ExBi.buCustPtr   = Custs.CustGuid  
		INNER JOIN #MatTbl        AS Mats   ON ExBi.biMatPtr    = Mats.MatGuid
		INNER JOIN OrAddInfo000   AS Info   ON Info.ParentGuid  = Orders.OrderGuid
		INNER JOIN @StoreTbl      AS ST     ON ST.Guid          = ExBi.biStorePtr
		INNER JOIN [#CostTbl]	  AS co		ON co.CostGUID		= ExBi.biCostPtr
		LEFT  JOIN ms000          AS MS     ON ExBi.biStorePtr  = MS.StoreGuid AND  
		                                       ExBi.biMatPtr    = MS.MatGuid  
	WHERE  
		ExBi.btType = 5
		AND (ExBi.buDate BETWEEN @StartDate AND @EndDate)   
		AND (Info.Finished = 0)  
		AND (Info.Add1 = '0')
		AND (ExBi.mtType = CASE @MatType WHEN -1 THEN ExBi.mtType ELSE @MatType END)
	
	-- test	
	-- SELECT * FROM #Detailes
	
	SELECT 
		d.*,
		ISNULL(
			(SELECT SUM(ORI.Qty) / d.UnitFact 
			FROM ori000 ORI
			WHERE ORI.POIGuid = d.ItemGuid AND ORI.TypeGuid = d.FinalStateGuid)
		, 0) AS AchievedQty
	INTO #Achieved
	FROM #Detailes d
	
	-- test	
	-- SELECT * FROM #Achieved

	SELECT 
		d.*, 
		(CASE WHEN (d.OrderedQty - d.AchievedQty)>= 0 THEN(d.OrderedQty - d.AchievedQty) ELSE 0 END) AS RemainedQty
	INTO #Result
	FROM #Achieved d
	
	-- test	
	-- SELECT * FROM #Result

	EXEC GetMatFlds   @MatFldsFlag,   @MatCFlds  
	EXEC GetCustFlds  @CustFldsFlag,  @CustCFlds  
	EXEC GetOrderFlds @OrderFldsFlag, @OrderCFlds   

	IF @ResultOption = 1
	BEGIN
		SELECT OrderGuid, COUNT(*) AS ItemsCount
		INTO #ResultItemsCount
		FROM #Result
		WHERE 
			(RemainedQty <= StoreQty) AND (RemainedQty > 0)
		GROUP BY OrderGuid
		
		-- test	
		-- SELECT * FROM #ResultItemsCount
		
		SELECT ParentGUID AS OrderGuid, COUNT(*) AS ItemsCount
		INTO #OrderItemsCount
		FROM bi000 bi INNER JOIN #Result R ON R.ItemGuid = bi.GUID
		GROUP BY ParentGUID
		
		-- test	
		-- SELECT * FROM #OrderItemsCount
		
		SELECT R.*, M.*, C.*, O.*
		INTO #Final1
		FROM 
			#Result R
			INNER JOIN ##MatFlds   M ON M.MatFldGuid   = R.MatGuid 
			LEFT  JOIN ##CustFlds  C ON C.CustFldGuid  = R.CustGuid
			INNER JOIN ##OrderFlds O ON O.OrderFldGuid = R.OrderGuid
	 	WHERE
			(R.RemainedQty <= R.StoreQty) AND (R.RemainedQty > 0)
			AND (
				    (SELECT ItemsCount FROM #ResultItemsCount WHERE OrderGuid = R.OrderGuid)
			      = (SELECT ItemsCount FROM #OrderItemsCount  WHERE OrderGuid = R.OrderGuid)
			    )
		ORDER BY
			R.OrderDate,
			R.OrderName,
			R.OrderNumber 
		IF ((SELECT COUNT(*) FROM #Final1) <> 0)
		BEGIN
			SELECT 
				SUM(OrderedQty) AS TotalOrderedQty,
				SUM(StoreQty) AS TotalStoreQty,
				SUM(AchievedQty) AS TotalAchievedQty,
				SUM(RemainedQty) AS TotalRemainedQty  
			FROM #Final1  
	END
		ELSE
		BEGIN
			SELECT 
				OrderedQty AS TotalOrderedQty,
				StoreQty AS TotalStoreQty,
				AchievedQty AS TotalAchievedQty,
				RemainedQty AS TotalRemainedQty 
			FROM #Final1
		END
		SELECT * FROM #Final1 
	END
	ELSE IF @ResultOption = 2
	BEGIN 
		SELECT R.*, M.*, C.*, O.*
		INTO #Final2
		FROM 
			#Result R
			INNER JOIN ##MatFlds   M ON M.MatFldGuid   = R.MatGuid 
			LEFT  JOIN ##CustFlds  C ON C.CustFldGuid  = R.CustGuid
			INNER JOIN ##OrderFlds O ON O.OrderFldGuid = R.OrderGuid
	 	WHERE
			(R.RemainedQty <= R.StoreQty) AND (R.RemainedQty > 0)
		ORDER BY
			R.OrderDate,
			R.OrderName,
			R.OrderNumber 
		
		IF ((SELECT COUNT(*) FROM #Final2) <> 0)
		BEGIN
			SELECT 
				SUM(OrderedQty) AS TotalOrderedQty,
				SUM(StoreQty) AS TotalStoreQty,
				SUM(AchievedQty) AS TotalAchievedQty,
				SUM(RemainedQty) AS TotalRemainedQty 
			FROM #Final2 
		END
	ELSE
		BEGIN
			SELECT 
				OrderedQty AS TotalOrderedQty,
				StoreQty AS TotalStoreQty,
				AchievedQty AS TotalAchievedQty,
				RemainedQty AS TotalRemainedQty 
			FROM #Final2
		END
		SELECT * FROM #Final2 
	END
	ELSE -- 3: default
	BEGIN
		SELECT R.*, M.*, C.*, O.*
		INTO #Final3
		FROM 
			#Result R
			INNER JOIN ##MatFlds   M ON M.MatFldGuid   = R.MatGuid 
			LEFT  JOIN ##CustFlds  C ON C.CustFldGuid  = R.CustGuid
			INNER JOIN ##OrderFlds O ON O.OrderFldGuid = R.OrderGuid
	 	WHERE
			(R.StoreQty > 0) AND (R.RemainedQty > 0)
		ORDER BY
			R.OrderDate,
			R.OrderName,
			R.OrderNumber 
		IF ((SELECT COUNT(*) FROM #Final3) <> 0)
		BEGIN
			SELECT 
				SUM(OrderedQty) AS TotalOrderedQty,
				SUM(StoreQty) AS TotalStoreQty,
				SUM(AchievedQty) AS TotalAchievedQty,
				SUM(RemainedQty) AS TotalRemainedQty 
			FROM #Final3 
		END
		ELSE
		BEGIN
			SELECT 
				OrderedQty AS TotalOrderedQty,
				StoreQty AS TotalStoreQty,
				AchievedQty AS TotalAchievedQty,
				RemainedQty AS TotalRemainedQty 
			FROM #Final3
		END
		SELECT * FROM #Final3 
	END
	*/
################################################################
#END	