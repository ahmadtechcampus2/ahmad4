################################################################
CREATE PROCEDURE OrderMatsDetailes  
	@CustAccGuid UNIQUEIDENTIFIER = 0x00 ,       
	@MatGuid UNIQUEIDENTIFIER = 0x00 ,       
	@GroupGuid UNIQUEIDENTIFIER = 0x00 ,       
	@StoreGuid UNIQUEIDENTIFIER = 0x00 ,       
	@StartDate DATETIME = '1/1/1980' ,       
	@EndDate DATETIME = '1/1/1980',       
	@ReportSource UNIQUEIDENTIFIER = 0x00 ,       
	@TypeGuid UNIQUEIDENTIFIER = 0x00 ,       
	@UseUnit INT = 0 ,      
	@isDetailedReport BIT = 0 ,       
	@isServiceMat BIT = 0 ,     
	@isStoreMat BIT = 0  ,	   
	@isFinished BIT = 0  ,   
	@isCancled BIT = 0  ,   
	@MatCond	UNIQUEIDENTIFIER = 0x00,   
	@CustCondGuid	UNIQUEIDENTIFIER = 0x00,   
	@OrderCond	UNIQUEIDENTIFIER = 0x00,	   
	@MatFldsFlag	BIGINT = 0,
	@MatCFlds 	NVARCHAR (max) = '', 		   
	@CustCFlds 	NVARCHAR (max) = '', 		   
	@OrderCFlds 	NVARCHAR (max) = '',  
	@Collect1	INT = 0,   
	@Collect2	INT = 0,   
	@Collect3	INT = 0, 
	@OrderIndex INT = 0,
	@CostGuid  UNIQUEIDENTIFIER = 0x00
AS        
	EXECUTE prcNotSupportedInAzureYet
	/*
	SET NOCOUNT ON    
	--///////////////////////////////////////////////////////////////////////////////       
	      
	CREATE TABLE #SecViol(Type INT, Cnt INT)            
	-------Bill Resource ---------------------------------------------              
	-- „’«œ— «· ﬁ—Ì—         
	CREATE TABLE #Src ( Type UNIQUEIDENTIFIER, Sec INT,ReadPrice INT, UnPostedSec INT)        
	INSERT INTO #Src EXEC prcGetBillsTypesList2 @ReportSource        
	-------------------------------------------------------------------    
	-- ÃœÊ· «·„Ê«œ „⁄  ÕﬁÌﬁ ‘—Êÿ «·„Ê«œ    
	-- «·„Ê«œ «· Ì Ì„·ﬂ «·„” Œœ„ ’·«ÕÌ… ⁄·ÌÂ«        
	CREATE TABLE #MatTbl( MatGuid UNIQUEIDENTIFIER, mtSecurity INT)                
	DECLARE @MatType  INT         
	SET @MatType = 0        
	IF @isServiceMat & @isStoreMat = 1         
		SET @MatType = -1         
	ELSE IF @isServiceMat = 1         
		SET @MatType = 1        
	ELSE IF @isStoreMat = 1         
		SET @MatType = 0        
	INSERT INTO #MatTbl (MatGuid, mtSecurity) EXEC [prcGetMatsList]  @MatGuid, @GroupGuid , @MatType , @MatCond       
	-------------------------------------------------------------------    
	-- ÃœÊ· «·“»«∆‰ „⁄  ÕﬁÌﬁ ‘—Êÿ «·“»«∆‰    
	CREATE TABLE #CustTbl( CustGuid UNIQUEIDENTIFIER, [Security] [INT], CustomerName NVARCHAR(255) COLLATE ARABIC_CI_AI)            
	INSERT INTO [#CustTbl]	(CustGuid, [Security]) EXEC [prcGetCustsList] @CustAccGuid , 0X00, @CustCondGuid -- ÌÊÃœ Œÿ√ «—ÃÊ „—«Ã⁄… 	        
	    
	UPDATE C SET CustomerName = cu.CustomerName          
	FROM [#CustTbl] AS C INNER JOIN [CU000] AS [CU] ON [CU].GUID = C.CustGuid    	        
	-- ≈÷«›… “»Ê‰ ›«—€ ·Ã·» «·›Ê« Ì— «· Ì ·«  „·ﬂ “»Ê‰ ›Ì Õ«· «·„” Œœ„ ·„ ÌÕœœ “»Ê‰         
	-- „Õœœ ›Ì «· ﬁ—Ì—        
	IF (ISNULL(@CustAccGuid,0x0) = 0x00 ) AND (ISNULL(@CustCondGuid,0x0) = 0X0)    
		INSERT INTO [#CustTbl] Values(0x00,1,'')        
	-------------------------------------------------------------------     
	--  ÃœÊ· «·ÿ·»Ì«  „⁄  ÕﬁÌﬁ ‘—Êÿ «·ÿ·»Ì«     
	CREATE TABLE #OrderCond ( OrderGuid UNIQUEIDENTIFIER, [Security] [INT] )     
	INSERT INTO [#OrderCond](OrderGuid, [Security]) EXEC [prcGetOrdersList] @OrderCond	        
	-------------------------------------------------------------------     
             
	-- Õ«·«  «·ÿ·»Ì«          
	CREATE TABLE #TypeTbl ( Guid UNIQUEIDENTIFIER,         
				Name NVARCHAR(255) collate ARABIC_CI_AI,         
				LatinName NVARCHAR(255) collate ARABIC_CI_AI)           
	INSERT INTO #TypeTbl         
		SELECT idType, isnull( Name, ''),  isnull( LatinName, '')        
		FROM         
			RepSrcs src         
			left JOIN dbo.fnGetOrderItemTypes() AS fnType ON fnType.Guid = src.idType        
		WHERE         
			IdTbl = @TypeGuid         
		GROUP BY         
			idType, Name, LatinName        

	-------Store Table--------------------------------------------------        
	-- ÃœÊ· «·„” Êœ⁄«         
	CREATE TABLE  #StoreTbl ( Guid UNIQUEIDENTIFIER)                
	INSERT INTO #StoreTbl         
	SELECT Guid FROM fnGetStoresList( @StoreGuid)                
	----------------------------------------------------------------------   
	-------COST TABLE------------------------------------------------------------------------  
	CREATE TABLE [#CostTbl]( [CostGUID] UNIQUEIDENTIFIER, [Security] INT)
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID
	IF @CostGuid = 0x00
		INSERT INTO #CostTbl VALUES(0x00,0)
	----------------------------------------------------------------------  
	-- ÃœÊ· ﬂ«›… «·„Ê«œ «·„ÿ·Ê»… „Ã„⁄… Õ”» «·›« Ê—… Ê «·„«œ…         
	Select    
		bi.Matguid,   
		bi.Guid AS biGuid,    
		bu.Guid as buGuid,    
		Sum(bi.Qty) as OrderQty, 
		bt.bIsInput,
		bt1.Type AS BtGuid,   
		bu.date as buDate,    
		bu.Number AS buNumber,    
		bu.Cust_Name  as buCust_Name,   
		bu.CustGuid    
	INTO    
		#Ordered        
	FROM    
				   bi000    as bi          
		INNER JOIN bu000    as bu     on bi.parentguid = bu.[guid]        
		INNER JOIN #Src     as bt1    on bt1.Type = bu.TypeGuid       
		INNER JOIN #CustTbl as cu     on cu.CustGUID = bu.CustGUID    
		INNER JOIN #MatTbl  as mt     on bi.Matguid = mt.MatGUID   
		INNER JOIN #OrderCond OCond   ON bu.[Guid] =   OCond.OrderGuid    
		INNER JOIN ORADDINFO000 OInfo ON bu.[Guid] = OInfo.ParentGuid 
		INNER JOIN bt000	AS bt		ON bt.[Guid] = bu.TypeGuid
		INNER JOIN #CostTbl AS co		ON co.[CostGUID] = bu.CostGUID
		INNER JOIN #StoreTbl AS Store ON store.Guid = bu.StoreGUID 
	WHERE     
			bu.Date between @startdate and @endDate    
		AND (OInfo.Finished =( Case @isFinished WHEN 0 THEN 0 else OInfo.Finished end ))    
		AND (OInfo.Add1 =( Case @isCancled WHEN 0 THEN '0' else OInfo.Add1 end))    
	Group by    
		bi.Matguid,   
		bi.Guid,    
		bu.Guid,
		bt.bIsInput, 
		bt1.Type,   
		bu.date,    
		bu.Number,   
		bu.Cust_Name,   
		bu.CustGuid     
--select 'ordered' as ordered, * from #Ordered		
	-------------------------------------------------------------------------------        
	-- ﬂ«›… «·„Ê«œ «·„ÿ·Ê»… „⁄ ﬂ„Ì« Â« œ«Œ· ﬂ· Õ«·… „—  »Â«        
	SELECT     
		bi.MatGuid as MatGuid,   
		bu.guid as buGuid,         
		ori.TypeGuid as TypeGuid,   
		Sum(ori.Qty) as TypeQty,    
		ori.PoiGuid AS biGuid         
	INTO	   
		#STATE        
	FROM     
				   bi000    as bi          
		INNER join ori000   as ori    on bi.guid = ori.poiguid        
		INNER join bu000    as bu     on bi.parentguid = bu.guid        
		INNER JOIN #CustTbl as cu     on cu.CustGUID = bu.CustGUID    
		INNER JOIN #MatTbl  as mt     on bi.Matguid = mt.MatGUID    
		INNER JOIN #TypeTbl as type   on type.Guid = ori.typeguid     
		INNER JOIN #OrderCond OCond   ON bu.Guid =  OCond.OrderGuid    
		INNER JOIN ORADDINFO000 OInfo ON bu.Guid = OInfo.ParentGuid
		INNER JOIN #CostTbl AS co	  ON co.[CostGUID] = bu.CostGUID 
		INNER JOIN #StoreTbl AS Store ON store.Guid = bu.StoreGUID		         
	WHERE     
			ori.Date between @startdate and @endDate     
		AND (OInfo.Finished =( Case @isFinished WHEN 0 THEN 0 else OInfo.Finished end))    
		AND (OInfo.Add1 =( Case @isCancled WHEN 0 THEN '0' else OInfo.Add1 end))    
	GROUP BY     
		bi.MatGuid,
		bi.GUID,			   
		bu.guid /*, bt.guid*/,    
		ori.TypeGuid,    
		ori.PoiGuid          
	----------------------------------------------------------------------------   
	SELECT        
		O.MatGuid,    
		O.buGuid,   
		O.btGuid,   
		O.budate,    
		O.buNumber,    
		O.buCust_Name,        
		O.OrderQty,
		O.bIsInput,    
		O.biGuid,   
		O.CustGuid,    
		S.TypeQty,    
		S.TypeGuid       
	INTO    
		#Result      
	from    
		#Ordered O INNER JOIN #STATE S ON O.buGuid = S.buGuid AND O.biGuid = S.biGuid   
	----------------------------------------------------------------------------------   
	delete from #Result where TypeGuid is null        
--select 'result' As '--Result--', * from #Result
	--------------------------------------------------------------------------------   
	--ﬂ«›… Õ«·«  «·ÿ·»Ì«  «·„” Œœ„… „⁄ √”„«¡Â«         
	SELECT DISTINCT    
		r.typeguid,    
		ISNULL(oit.name,'') as name,   
		ISNULL(oit.LatinName,'') as LatinName,   
		oit.postQty,
		oit.[Type] AS IsSalesType     
	FROM    
		#Result AS r LEFT JOIN oit000 AS oit ON  r.typeGuid = oit.guid  order by oit.postQty       
	------------------------------------------------------------------------------------   
	IF @Collect1 = 0 
		EXEC GetMatFlds @MatFldsFlag, @MatCFlds   
	-----------------------------------------------------------------------------------------   
	DECLARE @col1 NVARCHAR(100) SET @col1 = dbo.fnGetMatCollectedFieldName(@Collect1, DEFAULT)    
	DECLARE @col2 NVARCHAR(100) SET @col2 = dbo.fnGetMatCollectedFieldName(@Collect2, DEFAULT)    
	DECLARE @col3 NVARCHAR(100) SET @col3 = dbo.fnGetMatCollectedFieldName(@Collect3, DEFAULT)   
	-----------------------------------------------------------------------------------------  
	SELECT 
				mt.Guid, 
				mt.Dim,
				mt.Pos,
				mt.Origin,
				mt.Company,
				mt.Color,
				mt.Model,
				mt.Quality,
				mt.Provenance,
				mt.Name,
				mt.LatinName,
				mt.GroupGuid,
				mt.Unit2Fact,
				mt.Unit3Fact,
				mt.defunit,
				mt.Unity,
				mt.Unit2,
				mt.Unit3,
				gr.name grName
			INTO #mt
			FROM mt000  mt inner join gr000 gr on mt.GroupGuid = gr.Guid
--  ﬁ—Ì—  ›’Ì·Ì         
IF @isDetailedReport  = 1         
BEGIN
	IF dbo.fnObjectExists('##t0') = 1   
		DROP TABLE ##t0   
	DECLARE @s NVARCHAR(max)  
	 
	SET @col1 = (CASE @Col1 WHEN '' THEN '' ELSE ' mt.' END) + @Col1 
	SET @col2 = (CASE @Col2 WHEN '' THEN '' ELSE ' mt.' END) + @Col2 
	SET @col3 = (CASE @Col3 WHEN '' THEN '' ELSE ' mt.' END) + @Col3 
	 
	SET @s = 'SELECT ' + @Col1 + (CASE @Col1 WHEN '' THEN '' ELSE ' AS Col1 , ' END)   
                       + @Col2 + (CASE @Col2 WHEN '' THEN '' ELSE ' AS Col2, ' END)   
                       + @Col3 + (CASE @Col3 WHEN '' THEN '' ELSE ' AS Col3, ' END)   
	SET @s = @s + CASE @Col1 WHEN '' THEN ' r.MatGuid as MatGuid, mt.Name as MatName, ' ELSE '' END + 
			'r.buguid as OrderGuid,
			r.biGuid AS biGuid,   
			r.CustGuid As CustGuid,       
			bt.Abbrev + '':'' + Convert(NVARCHAR(25),r.buNumber) as OrderName ,        
			r.buDate as OrderDate ,         
			r.buCust_Name as CustomerName, ' 
		+CASE @Col1 WHEN '' THEN '' ELSE 'SUM(' END 
		+'(case  '+CAST(@useUnit AS NVARCHAR(10))+' when 1 then OrderQty
			when 2 then OrderQty / (case mt.Unit2Fact when 0 then 1 else mt.Unit2Fact end)
			when 3 then OrderQty / (case mt.Unit3Fact when 0 then 1 else mt.Unit3Fact end)
			else OrderQty / (case mt.defunit 
								when 2 then mt.Unit2Fact       
								when 3 then mt.Unit3Fact       
								else 1 end) 
			end) '+CASE @Col1 WHEN '' THEN '' ELSE ') ' END +'AS OrderTotalQty,     
			r.TypeGuid as TypeGuid,'        
			+CASE @Col1 WHEN '' THEN '' ELSE 'SUM(' END 
			+' (case  '+CAST(@useUnit AS NVARCHAR(10))+'    when 1 then r.TypeQty          
			when 2 then r.TypeQty /        
				case mt.Unit2Fact when 0 then 1        
						  else mt.Unit2Fact end        
			when 3 then r.TypeQty  /        
				case mt.Unit3Fact when 0 then 1        
						   else  mt.Unit3Fact end       
			else r.TypeQty  / case mt.defunit when 2 then mt.Unit2Fact       
						     when 3 then mt.Unit3Fact       
						     else 1 end end) '+CASE @Col1 WHEN '' THEN '' ELSE ') ' END +' TypeQty  
			,(CASE '+ CAST(@useUnit AS VARCHAR(10)) +' 
				WHEN 1 THEN mt.Unity
				WHEN 2 THEN (CASE WHEN mt.Unit2Fact <> 0 THEN mt.Unit2 ELSE mt.Unity END)
				WHEN 3 THEN (CASE WHEN mt.Unit3Fact <> 0 THEN mt.Unit3 ELSE mt.Unity END)
				ELSE CASE mt.DefUnit 
						WHEN 2 THEN (CASE WHEN mt.Unit2Fact <> 0 THEN mt.Unit2 ELSE mt.Unity END)
						WHEN 3 THEN (CASE WHEN mt.Unit3Fact <> 0 THEN mt.Unit3 ELSE mt.Unity END)
					ELSE mt.Unity
					 END
			END) AS Unity
	INTO ##t0   
	FROM #Result as r   
		inner join bt000 as bt on bt.guid = r.btGuid   
		inner join #mt as mt on mt.guid = r.Matguid 
		
	GROUP BY '+  
		+ @Col1 + (CASE @Col1 WHEN '' THEN '' ELSE ' , ' END)   
        + @Col2 + (CASE @Col2 WHEN '' THEN '' ELSE ' , ' END)   
        + @Col3 + (CASE @Col3 WHEN '' THEN '' ELSE ' , ' END) +  
		CASE @Col1 WHEN '' THEN ' r.MatGuid, mt.Name, ' ELSE '' END + 
			'r.buguid,
			r.biGuid,  
			r.CustGuid,        
			bt.Abbrev + '':'' + Convert(NVARCHAR(25),r.buNumber),        
			r.buDate,         
			r.buCust_Name, '        
		+CASE @Col1 WHEN '' THEN ' (case  '+CAST(@useUnit AS NVARCHAR(10))+' when 1 then OrderQty         
			when 2 then OrderQty/        
				case mt.Unit2Fact when 0 then 1        
						  else mt.Unit2Fact end        
			when 3 then OrderQty /        
				case mt.Unit3Fact when 0 then 1        
						   else  mt.Unit3Fact end       
			else OrderQty / case mt.defunit when 2 then mt.Unit2Fact       
						     when 3 then mt.Unit3Fact       
						     else 1 end end), ' ELSE '' END 
			+' r.TypeGuid  ' 
			+CASE @Col1 WHEN '' THEN ', (case  '+CAST(@useUnit AS NVARCHAR(10))+'    when 1 then r.TypeQty          
			when 2 then r.TypeQty /        
				case mt.Unit2Fact when 0 then 1        
						  else mt.Unit2Fact end        
			when 3 then r.TypeQty  /        
				case mt.Unit3Fact when 0 then 1        
						   else  mt.Unit3Fact end       
			else r.TypeQty  / case mt.defunit when 2 then mt.Unit2Fact       
						     when 3 then mt.Unit3Fact       
						     else 1 end end) ' ELSE '' END 
			+ ',(CASE '+ CAST(@useUnit AS VARCHAR(10)) +' 
				WHEN 1 THEN mt.Unity
				WHEN 2 THEN (CASE WHEN mt.Unit2Fact <> 0 THEN mt.Unit2 ELSE mt.Unity END)
				WHEN 3 THEN (CASE WHEN mt.Unit3Fact <> 0 THEN mt.Unit3 ELSE mt.Unity END)
				ELSE CASE mt.DefUnit 
						WHEN 2 THEN (CASE WHEN mt.Unit2Fact <> 0 THEN mt.Unit2 ELSE mt.Unity END)
						WHEN 3 THEN (CASE WHEN mt.Unit3Fact <> 0 THEN mt.Unit3 ELSE mt.Unity END)
					ELSE mt.Unity
					END
			END)'   
						       
	EXEC (@s)  
	 
	IF @Collect1 = 0 
		SET @s = 'SELECT DISTINCT  r.*, M.*    
				  FROM ##t0 AS r   
						INNER JOIN ##MatFlds   AS M ON M.MatFldGuid = r.MatGuid' 
	           +' ORDER BY ' + CASE @OrderIndex  
		                    WHEN 1 THEN ' r.CustomerName ' 
							WHEN 2 THEN ' r.MatName ' 
							WHEN 3 THEN ' r.OrderName ' 
							WHEN 4 THEN ' r.OrderTotalQty ' 
							WHEN 5 THEN ' r.OrderDate ' 
							ELSE ' r.OrderName ' 
						END 
					+ ', r.OrderGuid'
	ELSE 
		SET @s = 'SELECT DISTINCT  r.*    
				  FROM ##t0 AS r' 
	           +' ORDER BY ' + CASE @OrderIndex  
		                    WHEN 1 THEN ' r.CustomerName ' 
							WHEN 2 THEN ' r.OrderName ' 
							WHEN 3 THEN ' r.OrderTotalQty ' 
							WHEN 4 THEN ' r.OrderDate ' 
							ELSE ' r.OrderName ' 
						END 
					+ ', r.OrderGuid'
						 
	EXEC (@s) 
		 
	IF dbo.fnObjectExists('##t0') = 1   
		DROP TABLE ##t0       
END        
ELSE    --@isDetailedReport  = 0     
BEGIN 	 
	-->>-----------------------------------------------------
	CREATE TABLE [#MQtys]      
	(       
		[MatGuid] 	[UNIQUEIDENTIFIER],       
		[Qty] 		[FLOAT]    
	)

	SELECT mt.MatGuid, ISNULL(bb.Qty, 0) AS Qty
	INTO #inTotal
	FROM
		#MatTbl AS mt
	LEFT JOIN 
		(SELECT bi.MatGuid, (SUM(bi.Qty) + SUM(bi.BonusQnt)) AS Qty     
		FROM		   bi000     AS bi
			INNER JOIN bu000     AS bu ON bi.ParentGuid = bu.Guid    
			INNER JOIN bt000     AS bt ON bu.TypeGuid   = bt.Guid 
			INNER JOIN #StoreTbl AS Store ON Store.GUID = bu.StoreGUID 
			  
		WHERE    
			bt.bIsInput = 1 AND bt.Type NOT IN (5, 6) AND bu.IsPosted = 1
			AND bu.[Date] BETWEEN @StartDate AND @EndDate 
		GROUP BY    
			bi.MatGuid  
		) AS bb ON bb.MatGuid = mt.MatGuid
	
	-----------------------------------------------------------------------------------------    
	SELECT mt.MatGuid, ISNULL(bb.Qty, 0) AS Qty
	INTO #outTotal
	FROM
		#MatTbl AS mt
	LEFT JOIN 
		(SELECT bi.MatGuid, (SUM(bi.Qty) + SUM(bi.BonusQnt)) AS Qty       
		FROM		   bi000     AS bi
			INNER JOIN bu000     AS bu ON bi.ParentGuid = bu.Guid    
			INNER JOIN bt000     AS bt ON bu.TypeGuid   = bt.Guid 
			INNER JOIN #StoreTbl AS Store ON Store.GUID = bu.StoreGUID  
		WHERE    
			bt.bIsInput = 0 AND bt.Type NOT IN (5, 6)  AND bu.IsPosted = 1
			AND bu.[Date] BETWEEN @StartDate AND @EndDate
		GROUP BY    
			bi.MatGuid
		) AS bb ON bb.MatGuid = mt.MatGuid
	-----------------------------------------------------------------------------------------	     
	INSERT INTO #MQtys      
	SELECT inTotal.MatGuid, ISNULL(inTotal.Qty, 0) - ISNULL(outTotal.Qty, 0)    
	FROM	       #inTotal  AS inTotal     
		INNER JOIN #outTotal AS outTotal ON inTotal.MatGuid = outTotal.MatGuid    
		    
	SELECT bi.MatGuid, 0 AS Qty    
	INTO #temp0    
	FROM		   bi000     AS bi        
		INNER JOIN bu000     AS bu ON bi.ParentGuid = bu.Guid    
		INNER JOIN bt000     AS bt ON bu.TypeGuid   = bt.Guid    
		INNER JOIN #MatTbl   AS mt ON bi.MatGuid    = mt.MatGuid
		INNER JOIN #StoreTbl AS Store ON Store.GUID = bu.StoreGUID    
	WHERE    
		bt.Type IN (5, 6) AND bu.IsPosted = 1
	SELECT DISTINCT *     
	INTO #temp1    
	FROM #temp0 t0    
	WHERE     
		(SELECT COUNT(*) FROM #MQtys WHERE t0.MatGuid = MatGuid) = 0    
	INSERT INTO #MQtys SELECT * FROM #temp1
	--<<-----------------------------------------------------------------------
--select '#MQtys',* from #MQtys

	DECLARE @ss NVARCHAR(max)  
	
	IF dbo.fnObjectExists('##Orders_temp1_1') = 1   
		DROP TABLE ##Orders_temp1_1
	 
			        
	-- ≈Ã„«·Ì «·„«œ… ›Ì ﬂ· «·ÿ·»«          
	SET @ss = 'Select ord.MatGuid, '+CASE @Col1 WHEN '' THEN ' ' ELSE @Col1 END + CASE @Col1 WHEN '' THEN '' ELSE ' AS Col1, ' END  
					   +CASE @Col2 WHEN '' THEN '' ELSE @Col2 END + CASE @Col2 WHEN '' THEN '' ELSE ' AS Col2,' END+ 
					   +CASE @Col3 WHEN '' THEN '' ELSE @Col3 END + CASE @Col3 WHEN '' THEN '' ELSE ' AS Col3,' END+ 
					   	' (CASE bIsInput WHEN 0 THEN 0 ELSE Sum('+CASE @Col1 WHEN '' THEN 'OrderQty'  
					                                 ELSE '(case  '+CAST(@useUnit AS NVARCHAR(10))+' when 1 then OrderQty
															when 2 then OrderQty / case mt.Unit2Fact when 0 then 1 else mt.Unit2Fact end         
															when 3 then OrderQty / case mt.Unit3Fact when 0 then 1 else  mt.Unit3Fact end        
															else OrderQty / case mt.defunit when 2 then mt.Unit2Fact  
																						when 3 then mt.Unit3Fact        
																						else 1 end end)'  
									      END +') END) AS pOrderTotalQty'+
						' ,(CASE bIsInput WHEN 1 THEN 0 ELSE Sum('+CASE @Col1 WHEN '' THEN 'OrderQty'  
					                                 ELSE '(case  '+CAST(@useUnit AS NVARCHAR(10))+' when 1 then OrderQty
															when 2 then OrderQty / case mt.Unit2Fact when 0 then 1 else mt.Unit2Fact end         
															when 3 then OrderQty / case mt.Unit3Fact when 0 then 1 else  mt.Unit3Fact end        
															else OrderQty / case mt.defunit when 2 then mt.Unit2Fact  
																						when 3 then mt.Unit3Fact        
																						else 1 end end)'  
									      END +') END) AS sOrderTotalQty'+			
		',MIN(CASE '+CAST(@useUnit AS NVARCHAR(10))+' 
				WHEN 1 THEN MQty.Qty
				WHEN 2 THEN MQty.Qty / (CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END)
				WHEN 3 THEN MQty.Qty / (CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END)
				ELSE MQty.Qty / (CASE mt.DefUnit WHEN 2 THEN (CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END)
									WHEN 3 THEN (CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END)
									ELSE 1 END)
			 END
		) AS StockQuantity ' 								      
	+ ',(CASE '+ CAST(@useUnit AS VARCHAR(10)) +' 
				WHEN 1 THEN mt.Unity
				WHEN 2 THEN (CASE WHEN mt.Unit2Fact <> 0 THEN mt.Unit2 ELSE mt.Unity END)
				WHEN 3 THEN (CASE WHEN mt.Unit3Fact <> 0 THEN mt.Unit3 ELSE mt.Unity END)
				ELSE CASE mt.DefUnit 
						WHEN 2 THEN (CASE WHEN mt.Unit2Fact <> 0 THEN mt.Unit2 ELSE mt.Unity END)
						WHEN 3 THEN (CASE WHEN mt.Unit3Fact <> 0 THEN mt.Unit3 ELSE mt.Unity END)
					ELSE mt.Unity
					 END
			END) AS Unity '
	+' INTO ##Orders_temp1_1       
	 FROM #Ordered ord 
	 
	 '
	+' INNER JOIN #MQtys AS MQty ON ord.MatGuid = MQty.MatGuid  INNER JOIN #mt mt ON mt.Guid = ord.MatGuid ' 
	+' GROUP BY 
			ord.MatGuid, bIsInput '+CASE @Col1 WHEN '' THEN ' ,ord.MatGuid ' ELSE ','+ @Col1 END  
				 +CASE @Col2 WHEN '' THEN '' ELSE ',' + @Col2 END
				 +CASE @Col3 WHEN '' THEN '' ELSE ',' + @Col3 END
				 + ',(CASE '+ CAST(@useUnit AS VARCHAR(10)) +' 
						WHEN 1 THEN mt.Unity
						WHEN 2 THEN (CASE WHEN mt.Unit2Fact <> 0 THEN mt.Unit2 ELSE mt.Unity END)
						WHEN 3 THEN (CASE WHEN mt.Unit3Fact <> 0 THEN mt.Unit3 ELSE mt.Unity END)
						ELSE CASE mt.DefUnit 
								WHEN 2 THEN (CASE WHEN mt.Unit2Fact <> 0 THEN mt.Unit2 ELSE mt.Unity END)
								WHEN 3 THEN (CASE WHEN mt.Unit3Fact <> 0 THEN mt.Unit3 ELSE mt.Unity END)
							ELSE mt.Unity
							 END
					END)'
				 
--select @ss
	EXEC (@ss) 
--select 'orders_temp1_1', * from ##Orders_temp1_1

	IF dbo.fnObjectExists('##Orders_temp1') = 1   
		DROP TABLE ##Orders_temp1  
	--Collapsing to 1 row per Mat to avoid duplicate rows in final result set
	SET @ss=
	'SELECT MatGuid, '
		+CASE @Col1 WHEN '' THEN '' ELSE @Col1 + ' AS Col1, ' END
		+CASE @Col2 WHEN '' THEN '' ELSE @Col2 + ' AS Col2,' END
		+CASE @Col3 WHEN '' THEN '' ELSE @Col3 + ' AS Col3,' END
		+' SUM(pOrderTotalQty) As pOrderTotalQty, 
		SUM(sOrderTotalQty) AS sOrderTotalQty '
		+' ,StockQuantity ' 
		+ ', tmp1.Unity'
	+' INTO ##Orders_temp1 
	FROM ##Orders_temp1_1 tmp1'
	+CASE @Col1 WHEN '' THEN '' ELSE ' INNER JOIN #mt mt ON mt.'+@Col1+' = tmp1.Col1 AND tmp1.MatGuid = mt.Guid' END + 
	+' GROUP BY  MatGuid, StockQuantity '
	+ ', tmp1.Unity'
		+CASE @Col1 WHEN '' THEN '' ELSE ',' + @Col1 END 
		+CASE @Col2 WHEN '' THEN '' ELSE ',' + @Col2 END
		+CASE @Col3 WHEN '' THEN '' ELSE ',' + @Col3 END
--select @ss	
	EXEC(@ss)
--select 'Orders_temp1', * from ##Orders_temp1	
	IF dbo.fnObjectExists('##Orders_temp2') = 1   
		DROP TABLE ##Orders_temp2  
	 -- select * from #temp1      
	-- ≈Ã„«·Ì «·„«œ… ›Ì ﬂ· Õ«·…       
	-- MIN is used just to skip putting the field in GROUP BY  
	SET @ss = 'Select '+CASE @Col1 WHEN '' THEN ' r.MatGuid ' ELSE @Col1 END + CASE @Col1 WHEN '' THEN ',' ELSE ' AS Col1, ' END 
					   +CASE @Col2 WHEN '' THEN '' ELSE @Col2 END + CASE @Col2 WHEN '' THEN '' ELSE ' AS Col2,' END+ 
					   +CASE @Col3 WHEN '' THEN '' ELSE @Col3 END + CASE @Col3 WHEN '' THEN '' ELSE ' AS Col3,' END+ 
					   ' TypeGuid , Sum('+CASE @Col1 WHEN '' THEN 'TypeQty'  
					                                 ELSE '(case  '+CAST(@useUnit AS NVARCHAR(10))+' when 1 then TypeQty           
															when 2 then TypeQty / case mt.Unit2Fact when 0 then 1 else mt.Unit2Fact end         
															when 3 then TypeQty  / case mt.Unit3Fact when 0 then 1 else  mt.Unit3Fact end        
															else TypeQty  / case mt.defunit when 2 then mt.Unit2Fact  
																						when 3 then mt.Unit3Fact        
																						else 1 end end)'  
									      END +') as TypeQty,
						r.bIsInput 
	into ##Orders_temp2         
	from #Result r '+CASE @Col1 WHEN '' THEN '' ELSE 
	' INNER JOIN #mt mt ON mt.Guid = r.MatGuid ' END+         
	'GROUP BY '+CASE @Col1 WHEN '' THEN ' r.MatGuid ' ELSE @Col1 END 
			   +CASE @Col2 WHEN '' THEN '' ELSE ',' END + CASE @Col2 WHEN '' THEN '' ELSE @Col2 END 
			   +CASE @Col3 WHEN '' THEN '' ELSE ',' END + CASE @Col3 WHEN '' THEN '' ELSE @Col3 END 
			   +', TypeGuid, r.bIsInput '
	 
	EXEC (@ss) 
--select '##Orders_temp2', * from ##Orders_temp2	      
	IF dbo.fnObjectExists('##t1') = 1   
		DROP TABLE ##t1   
	
	SET @ss = 'SELECT DISTINCT ' + CASE @Col1 WHEN '' THEN ' r.MatGuid, mt.Name MatName, ' ELSE ' t1.Col1, ' END   
                        + CASE @Col2 WHEN '' THEN '' ELSE ' t1.Col2, ' END   
                        + CASE @Col3 WHEN '' THEN '' ELSE ' t1.Col3, ' END   
			 + CASE @Col1 WHEN '' THEN ' (case  '+CAST(@useUnit AS NVARCHAR(10))+' 
											when 1 then (CASE t2.bIsInput WHEN 0 THEN t1.sOrderTotalQty ELSE t1.pOrderTotalQty END)           
											when 2 then (CASE t2.bIsInput WHEN 0 THEN t1.sOrderTotalQty ELSE t1.pOrderTotalQty END) / (case mt.Unit2Fact when 0 then 1 else mt.Unit2Fact end)
											when 3 then (CASE t2.bIsInput WHEN 0 THEN t1.sOrderTotalQty ELSE t1.pOrderTotalQty END)  / (case mt.Unit3Fact when 0 then 1 else  mt.Unit3Fact end)
											else (CASE t2.bIsInput WHEN 0 THEN t1.sOrderTotalQty ELSE t1.pOrderTotalQty END)  / case mt.defunit when 2 then mt.Unit2Fact when 3 then mt.Unit3Fact else 1 end 
										end) ' 
						ELSE ' (CASE t2.bIsInput WHEN 0 THEN t1.sOrderTotalQty ELSE t1.pOrderTotalQty END) ' 
						END + ' AS OrderTotalQty , '
		+ CASE @Col1 WHEN '' THEN ' (case '+CAST(@useUnit AS NVARCHAR(10))+' when 1 then t2.TypeQty           
			when 2 then t2.TypeQty /         
				case mt.Unit2Fact when 0 then 1         
						  else mt.Unit2Fact end         
			when 3 then t2.TypeQty  /         
				case mt.Unit3Fact when 0 then 1         
						   else  mt.Unit3Fact end        
			else t2.TypeQty  / case mt.defunit when 2 then mt.Unit2Fact        
						     when 3 then mt.Unit3Fact        
						     else 1 end end) ' ELSE ' t2.TypeQty' END + ' TypeQty , '
		+'t2.TypeGuid '
		+' ,t1.StockQuantity' 
		+' ,t1.Unity'
	+' INTO ##t1  
	FROM ' 
	   +' #Result as r inner join #mt as mt on mt.guid = r.Matguid inner join ' 
	   +' ##Orders_temp1 as t1 '+' on r.MatGuid = t1.MatGuid ' 
	   +' inner join ##Orders_temp2 as t2 on ' 
	   +CASE @Col1 WHEN '' THEN ' r.matguid = t2.matguid ' ELSE ' t1.Col1 = t2.Col1 ' END  
	   +CASE @Col2 WHEN '' THEN '' ELSE ' AND t1.Col1 = t2.Col1 ' END  
	   +CASE @Col3 WHEN '' THEN '' ELSE ' AND t1.Col1 = t2.Col1 ' END  
	   +CASE @Col1 WHEN '' THEN ' and r.typeguid = t2.typeguid ' ELSE '' END
	
	+' GROUP BY r.MatGuid, mt.Name,'  
		 + CASE @Col1 WHEN '' THEN '' ELSE ' t1.Col1, ' END   
         + CASE @Col2 WHEN '' THEN '' ELSE ' t1.Col2, ' END   
         + CASE @Col3 WHEN '' THEN '' ELSE ' t1.Col3, ' END   
	 	 + CASE @Col1 WHEN '' THEN ' (CASE  '+CAST(@useUnit AS NVARCHAR(10))+' 
											WHEN 1 THEN (CASE t2.bIsInput WHEN 0 THEN t1.sOrderTotalQty ELSE t1.pOrderTotalQty END)           
											WHEN 2 THEN (CASE t2.bIsInput WHEN 0 THEN t1.sOrderTotalQty ELSE t1.pOrderTotalQty END) / (CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END)
											WHEN 3 THEN (CASE t2.bIsInput WHEN 0 THEN t1.sOrderTotalQty ELSE t1.pOrderTotalQty END) / (CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END)
											ELSE (CASE t2.bIsInput WHEN 0 THEN t1.sOrderTotalQty ELSE t1.pOrderTotalQty END)  / (CASE mt.defunit WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact ELSE 1 END)
									 END), ' 
					ELSE ' (CASE t2.bIsInput WHEN 0 THEN t1.sOrderTotalQty ELSE t1.pOrderTotalQty END), ' 
					END
		+ CASE @Col1 WHEN '' THEN ' (case '+CAST(@useUnit AS NVARCHAR(10))+' when 1 then t2.TypeQty           
			when 2 then t2.TypeQty /         
				case mt.Unit2Fact when 0 then 1         
						  else mt.Unit2Fact end         
			when 3 then t2.TypeQty  /         
				case mt.Unit3Fact when 0 then 1         
						   else  mt.Unit3Fact end        
			else t2.TypeQty  / case mt.defunit when 2 then mt.Unit2Fact        
						     when 3 then mt.Unit3Fact        
						     else 1 end end), ' ELSE ' t2.TypeQty,' END 
		+' t2.TypeGuid '
		+' ,t1.StockQuantity'  
		+' ,t1.Unity'
	+ ' ORDER BY '+CASE @Col1 WHEN '' THEN ' mt.Name  '  
							 ELSE ' t1.Col1 '   
								  + CASE @Col2 WHEN '' THEN '' ELSE ', ' END + CASE @Col2 WHEN '' THEN '' ELSE ' t1.Col2 ' END   
								  + CASE @Col3 WHEN '' THEN '' ELSE ', ' END + CASE @Col3 WHEN '' THEN '' ELSE ' t1.Col3 ' END  
						     END 
--select @ss
	EXEC (@ss) 
--select '##t1', * from ##t1	
	IF @Col1 = '' 
		SET @ss = 'SELECT DISTINCT r.*, M.* From ##t1 as r INNER JOIN ##MatFlds   AS M ON M.MatFldGuid = r.MatGuid ' 
		
	ELSE  
		SET @ss = 'SELECT DISTINCT * FROM ##t1' 

	EXEC (@ss) 
	 
	IF dbo.fnObjectExists('##t1') = 1   
		DROP TABLE ##t1   
	IF dbo.fnObjectExists('##Orders_temp1_1') = 1   
		DROP TABLE ##Orders_temp1_1 
	IF dbo.fnObjectExists('##Orders_temp1') = 1   
		DROP TABLE ##Orders_temp1 
	IF dbo.fnObjectExists('##Orders_temp2') = 1   
		DROP TABLE ##Orders_temp2     
END   
SELECT * FROM #SecViol
*/
################################################################
#END	


