#####################################################################
CREATE PROCEDURE PrcFillRateOrder 
@ReportSource UNIQUEIDENTIFIER = 0x00,    
@OrderNumber INT = 0 ,    
@FromDate DATETIME = '1/1/1980' ,    
@ToDate DATETIME = '1/1/2100' ,    
@RepType int = 0, -- 0  Assembled , 1 Detailed    
@isFinished BIT = 0  ,  
@isCancled BIT = 0  ,  
@OrderCond	UNIQUEIDENTIFIER = 0x00,	   
@OrderFldsFlag	BIGINT = 0, 
@OrderIndex INT = 0	  ,
@OrderCFlds 	NVARCHAR (max) = ''	

AS    
	EXECUTE prcNotSupportedInAzureYet
	/*
	SET NOCOUNT ON
		--///////////////////////////////////////////////////////////////////////////////    
	-------Bill Resource ---------------------------------------------------------          
	CREATE TABLE #Src ( 
		Guid UNIQUEIDENTIFIER,  
		Sec INT, 
		ReadPrice INT,  
		UnPostedSec INT ,  
		OrderName NVARCHAR(15)COLLATE ARABIC_CI_AI default '', 
		OrderLatinName NVARCHAR(15) COLLATE ARABIC_CI_AI default '' 
	)    
	INSERT INTO #Src (Guid , Sec , ReadPrice , UnPostedSec) EXEC prcGetBillsTypesList2 @ReportSource    
	    
	UPDATE src SET OrderName = bt.Abbrev, OrderLatinName = bt.LatinAbbrev  
	FROM #Src AS src inner join bt000 AS bt ON src.Guid = bt.guid  
	CREATE TABLE #OrderCond ( 
		OrderGuid UNIQUEIDENTIFIER,  
		Security  INT 
	) 
	INSERT INTO #OrderCond (OrderGuid, Security) EXEC prcGetOrdersList @OrderCond    
	    
	-------------------------------------------------------------------        
	SELECT   
		bu.Guid OrderGuid,  
		bt.OrderName,  
		bt.OrderLatinName, 
		bu.Number  ,     
		bu.Date as OrderDate, 
		bi.Guid AS BiGuid,  
		mt.Guid as MatGuid,  
		mt.Code + '-' + mt.Name AS  MatName ,
		mt.Name as mtname,         
		SUM(CASE dbo.fnIsFinalState(bt.Guid, oit.Guid) WHEN 1 THEN ori.Qty ELSE 0 END ) AS RecievedQty 
		--SUM(CASE dbo.fnGetFinalState(bt.Guid) WHEN oit.Guid THEN ori.Qty ELSE 0 END ) AS RecievedQty     
	INTO #Result1    
	FROM #Src bt  
		INNER JOIN bu000  bu  ON bt.Guid = bu.TypeGuid  
		INNER JOIN #OrderCond cond ON cond.OrderGuid = bu.Guid	  
		INNER JOIN bi000  bi  ON bu.Guid = bi.ParentGuid    
		INNER JOIN mt000  mt  ON mt.Guid = bi.MatGuid    
		INNER JOIN ori000 ori ON bi.Guid = ori.POIGuid    
		INNER JOIN oit000 oit ON oit.Guid= ori.TypeGuid    
		INNER JOIN ORADDINFO000 OInfo ON bu.Guid = OInfo.ParentGuid	  
	WHERE 	     
	  	(@OrderNumber = 0 OR bu.Number = @OrderNumber)    
		AND  (OInfo.Finished =( Case @isFinished WHEN 0 THEN 0 else OInfo.Finished end  ) )  
		AND  (OInfo.Add1 =( Case @isCancled WHEN 0 THEN '0' else OInfo.Add1 end  ) )  
		AND bu.[Date] BETWEEN @FromDate AND @ToDate    
	  	AND ori.Qty > 0    
	GROUP BY   
		bu.Guid,  
		bi.Guid,  
		mt.Guid ,  
		mt.Code + '-' + mt.Name ,
		mt.Name,   
		bt.OrderName ,  
		bt.OrderLatinName, 
		bu.Number,	  
		bu.Date	   
		 
	SELECT  
		bi.Guid AS BiGuid,  
		bi.MatGuid as MatGuid ,  
		SUM( bi.Qty ) AS OrderedQty    
	INTO #Result2    
	FROM #Src bt  
		INNER JOIN bu000  bu  ON bt.Guid = bu.TypeGuid  
		INNER JOIN #OrderCond cond ON cond.OrderGuid = bu.Guid	    
		INNER JOIN bi000  bi  ON bu.Guid = bi.ParentGuid	  
		INNER JOIN ORADDINFO000 OInfo ON bu.Guid = OInfo.ParentGuid			          
	WHERE 	  
	  	( @OrderNumber = 0 OR bu.Number = @OrderNumber)    
		AND (OInfo.Finished =( Case @isFinished WHEN 0 THEN 0 else OInfo.Finished end  ) )  
		AND (OInfo.Add1 =( Case @isCancled WHEN 0 THEN '0' else OInfo.Add1 end  ) )  
		AND bu.[Date] BETWEEN @FromDate AND @ToDate   				    
	GROUP BY  bi.Guid, bi.MatGuid     
	 
	if @RepType = 0    
	BEGIN    
		SELECT t.BiGuid,t.MatGuid,t.MatName,t.OrderedQty,t.RecievedQty,t.mtname,
			   (t.RecievedQty/t.OrderedQty)*100 AS FILLRATE
	    INTO #Orders_Temp_Result_Grped
		FROM ( SELECT   
					00000000-0000-0000-0000-000000000000 AS BiGuid,  
					R1.MatGuid,  
					R1.MatName, 
					r1.mtname,
					SUM(R1.RecievedQty)AS RecievedQty ,  
					SUM(R2.OrderedQty) AS OrderedQty 
				FROM  
					#Result1 R1  
					INNER JOIN #Result2 R2 ON  R1.BiGuid= R2.BiGuid AND R1.MatGuid = R2.MatGuid    
				GROUP BY   
					R1.MatGuid,  
					R1.MatName,
					r1.mtname ) AS t
		
		if (@OrderIndex = 1) select * from #Orders_Temp_Result_Grped order by MtName
		if (@OrderIndex = 2) select * from #Orders_Temp_Result_Grped order by FILLRATE
		if (@OrderIndex = 3) select * from #Orders_Temp_Result_Grped order by FILLRATE DESC
	END    
	ELSE    
	BEGIN   
		EXEC GetOrderFlds @OrderFldsFlag, @OrderCFlds  
		SELECT DISTINCT
			R1.BiGuid,  
			R1.MatGuid,  
			R1.MatName,  
			R1.RecievedQty,
			R2.OrderedQty,
			(R1.RecievedQty/ R2.OrderedQty)* 100  AS FILLRATE,  
			R1.OrderName,  
			R1.OrderLatinName, 
			R1.Number, 
			R1.OrderDate, 
			R1.mtname,
			O.*
		INTO #Orders_Temp_Result
		FROM  
			#Result1 R1  
			INNER JOIN #Result2 R2 ON R1.BiGuid= R2.BiGuid AND  R1.MatGuid = R2.MatGuid 	  
			INNER JOIN ##OrderFlds O ON O.OrderFldGuid = R1.OrderGuid
			
		 
		if (@OrderIndex = 1) select * from #Orders_Temp_Result order by MtName
		if (@OrderIndex = 2) select * from #Orders_Temp_Result order by OrderName
		if (@OrderIndex = 3) select * from #Orders_Temp_Result order by OrderDate
		if (@OrderIndex = 4) select * from #Orders_Temp_Result order by FILLRATE
		if (@OrderIndex = 5) select * from #Orders_Temp_Result order by FILLRATE DESC
		
    END 
	*/
#########################################################################
#END