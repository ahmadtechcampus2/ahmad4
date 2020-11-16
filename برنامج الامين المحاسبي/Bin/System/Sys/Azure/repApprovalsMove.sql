##############################################################################
CREATE PROCEDURE repApprovalsMove
	@StartDate DATE,
	@EndDate DATE,
	@StoreGuid UNIQUEIDENTIFIER  = 0x0,
	@CustomerGuid UNIQUEIDENTIFIER = 0x0,
	@UserGuid UNIQUEIDENTIFIER = 0x0,
	@AccountGuid UNIQUEIDENTIFIER = 0x0,
	@CostGuid UNIQUEIDENTIFIER = 0x0,
	@OrderNumber INT,
	@OrderCond UNIQUEIDENTIFIER = 0x0,
	@OrderTypesSrc UNIQUEIDENTIFIER = 0x0,
	@CustFldsFlag BIGINT = 0,
	@OrderFldsFlag BIGINT = 0,
	@SortBy INT,
	@CustCFlds 		NVARCHAR (max) = '',
	@OrderCFlds		NVARCHAR (max) = '' 
AS
	EXECUTE prcNotSupportedInAzureYet
	/*
	SET NOCOUNT ON   
	--Customers Temp Table  
		CREATE Table #Cust (  
			[Guid] UNIQUEIDENTIFIER,  
			[Security] INT)

		SELECT 
			bu.buGuid, 
			SUM(bi.Qty) AS Qty
		INTO 
			#buTemp  
		FROM 
			vwbu AS bu   
	INNER JOIN bi000 AS bi ON bu.buGuid = bi.ParentGuid  
		GROUP BY 
			bu.buGuid

	INSERT INTO #Cust EXEC prcGetCustsList @CustomerGuid, @AccountGuid, NULL
	IF ((@CustomerGuid = 0x0) AND (@AccountGuid = 0x0)) 
		INSERT INTO #Cust VALUES (0x0, 1) 

	--Conditions Temp Table  
		CREATE Table #CondOrder (  
			[Guid] UNIQUEIDENTIFIER,  
			[Security] INT)
		  
	INSERT INTO #CondOrder EXEC prcGetOrdersList @OrderCond  
		CREATE Table #CostTbl ([Guid] UNIQUEIDENTIFIER)
		  
	INSERT INTO #CostTbl SELECT * FROM fnGetCostsList(@CostGuid) 
	IF (@CostGuid = 0x0) 
		INSERT INTO #CostTbl VALUES (0x0) 
	  
		EXEC GetOrderFlds @OrderFldsFlag   
		EXEC GetCustFlds @CustFldsFlag  

		SELECT 
			bu.buNumber AS Number,  
		   bu.buNotes,  
		   bu.buGuid AS OrderGuid,  
		   bu.buCustPtr As CustGuid,  
		   bu.buType,  
		   bu.butotal AS Total,  
		   buTemp.Qty AS Qty,  
		   bt.btGuid AS OrderTypeGuid,  
			us.usGuid AS UserGuid,  
		   us.usLoginName AS UserName,  
		   bu.buDate AS OrderDate,  
		   st.stGuid AS storeGUID,  
		   bt.btName + ': ' + CAST (bu.buNumber AS NVARCHAR(10)) AS buName,  
		   more.ADDATE AS DelieveryDate,  
		   cu.cuCustomerName AS CustomerName,  
		   st.stName AS StoreName,  
		   st.stSecurity AS StoreSecurity ,  
		   cust.Security AS CustSecurity,  
		   bt.btType,  
			oap.[Number] AS [Order],  
		   ordF.*,  
		   cusF.*,  
			isnull(oaps.IsApproved, 0) AS Approved  
		INTO #Orders     
		FROM   
			vwbu bu  
			INNER JOIN #buTemp AS buTemp ON buTemp.buGuid = bu.buGuid  
			INNER JOIN vwbt bt ON bu.buType = bt.btGuid AND bt.btType in (5, 6)		        
			-- INNER JOIN UsrApp000 up ON up.ParentGuid = bt.btGuid  
			-- LEFT JOIN orapp000 orapp ON orapp.OrderGuid = bu.buGuid AND orapp.UserGuid = up.UserGuid
			INNER JOIN OrderApprovals000 oap ON oap.OrderGuid = bu.buGuid
			OUTER APPLY dbo.fnGetLastApprovalState(oap.GUID) AS oaps 
			INNER JOIN dbo.fnGetStoresList (@StoreGuid) AS stl ON stl.Guid = bu.buStorePtr  
			INNER JOIN vwst AS st ON st.stGuid = stl.Guid  
			INNER JOIN #CostTbl As col ON col.Guid = bu.buCostPtr 
			INNER JOIN #Cust As cust ON (bu.buCustPtr = cust.Guid)  
			INNER JOIN RepSrcs As r ON (bu.buType = r.IdType) AND (@OrderTypesSrc = r.IdTbl)  
			INNER JOIN #CondOrder AS cndO ON cndO.Guid = bu.buGuid  
			LEFT JOIN ##OrderFlds AS ordF ON  (bu.buGuid = ordF.OrderFldGuid)  
			LEFT JOIN ##CustFlds AS cusF ON  ( bu.buCustPtr = cusF.CustFldGuid)  
			LEFT JOIN vwcu AS cu ON (cu.cuGuid = bu.buCustPtr)
			INNER JOIN OrAddInfo000 As more ON more.parentGuid = bu.buGuid  
			INNER JOIN vwus AS us ON us.usGuid = ISNULL(oaps.UserGuid, oap.UserGuid)
		WHERE   
			(oaps.IsApproved <> 1 OR oaps.IsApproved IS NULL )  
			AND (bu.buDate BETWEEN @StartDate AND @EndDate) 
			AND (bu.buNumber = @OrderNumber OR @OrderNumber = 0) 
			AND (more.Finished <> 1) --Finished Orders
			AND (more.Add1 <> 1) --Cancelled Orders
	-- #temp holds Order Numbers with the that must approve it	  
	SELECT OrderGuid,  
		   Min([Order]) AS [Order]  
	INTO #temp  
	FROM #orders AS o  
	GROUP BY OrderGuid  

	SELECT   
		o.*  
	INTO  
		#result  
	FROM  
		#orders o   
		INNER JOIN #temp t ON o.OrderGuid = t.OrderGuid AND o.[Order] = t.[Order]  
	
	--Delete Orders That approved by Managers  
	DELETE   
		#Result   
	FROM   
		#Result r   
		INNER JOIN MgrApp000 mngA ON r.OrderGuid = mngA.OrderGuid  
			CROSS APPLY dbo.fnGetLastApprovalState(mngA.GUID) AS oaps
		WHERE 
			oaps.IsApproved = 1

	CREATE TABLE #SecViol(Type INT, Cnt INT)  
	EXEC [prcCheckSecurity]    
	IF (@SortBy = 0)  
		SELECT * FROM #result AS r  
		WHERE (UserGuid = @UserGuid OR @UserGuid = 0x0)  
		ORDER BY r.OrderDate  
	ELSE  
		SELECT * FROM #result AS r  
		WHERE (UserGuid = @UserGuid OR @UserGuid = 0x0)  
		ORDER BY r.DelieveryDate  
	SELECT * FROM #SecViol  
	*/
####################################################################################
#END