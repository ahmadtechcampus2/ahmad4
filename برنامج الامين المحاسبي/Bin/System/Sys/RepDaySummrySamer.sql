############################################################## 
CREATE PROC repDaySummurySamer
    @StartDate DateTime,
    @EndDate DateTime,
    @SrcTypesGuid UNIQUEIDENTIFIER,
    @StoreGuid UNIQUEIDENTIFIER,
    @CurrPtr UNIQUEIDENTIFIER,
    @PostedValue as int=-1,  --0,1,-1
    @TypeGroup AS INT=0 --0,1,2

 AS  
 	CREATE TABLE #SecViol(Type INT,Cnt INTEGER) 
	CREATE TABLE #BillsTypesTbl (TypeGuid UNIQUEIDENTIFIER,UserSecurity INTEGER,UserReadPtriceSecurity INT) 
	CREATE TABLE #StoreTbl (StoreGUID UNIQUEIDENTIFIER,Security INT) 
	  
	INSERT INTO  #BillsTypesTbl EXEC  prcGetBillsTypesList 	@SrcTypesguid 
	INSERT INTO  #StoreTbl EXEC prcGetStoresList 		@StoreGUID 
	Declare @Period Table(BDate DateTime)
	Declare @Date DateTime
	Set @Date=@StartDate   
	While(@Date<=@EndDate)
	Begin
		INSERT INTO @Period VALUES(@Date)
		SET @Date=@Date+1
	END 
	
	CREATE TABLE #Result(TypeGuid UNIQUEIDENTIFIER,buBillType int, 
			buDate DateTime,OrderNumber  NVARCHAR(200),StartDate DateTime,EndDate DateTime, 
			buTotal FLOAT,StoreGuid UNIQUEIDENTIFIER,Guid UNIQUEIDENTIFIER ) 
							 
	INSERT INTO #RESULT 
		SELECT DISTINCT   
			Bt.TypeGuid,wbt.btBillType,bu.buDate, 
			CASE @TypeGroup 
				WHEN 0 THEN 
					CAST(DAY(bu.buDate) AS NVARCHAR(20))+'/'+CAST(MONTH(bu.buDate) AS NVARCHAR(20))+'/'+CAST(YEAR(bu.buDate) AS NVARCHAR(20)) 
				WHEN 1 THEN 
					(select CAST(DAY(MIN(BDate)) AS NVARCHAR(10))+'-'+ CAST(MONTH(MIN(BDate)) AS NVARCHAR(10))+'-'+ CAST(YEAR(MIN(BDate)) AS NVARCHAR(10)) 
						FROM @Period P 
							WHERE (cast(Datepart(wk,bu.buDate) as NVARCHAR(10))+'-'+cast(year(bu.buDate) as NVARCHAR(10)))=(cast(DatePart(wk,BDate)as NVARCHAR(10))+'-'+cast(year(bDate) as NVARCHAR(10))))+'___'+
					(select CAST(DAY(MAX(BDate)) AS NVARCHAR(10))+'-'+ CAST(MONTH(MAX(BDate)) AS NVARCHAR(10))+'-'+ CAST(YEAR(MAX(BDate)) AS NVARCHAR(10)) 
						FROM @Period P 
						WHERE (cast(Datepart(wk,bu.buDate) as NVARCHAR(10))+'-'+cast(year(bu.buDate) as NVARCHAR(10)))=(cast(DatePart(wk,BDate)as NVARCHAR(10))+'-'+cast(year(bDate) as NVARCHAR(10))))
				 ELSE  
				 CAST (MONTH(bu.buDate) AS NVARCHAR(20))+'-'+ CAST (YEAR(bu.buDate) AS NVARCHAR(20)) 
			END, 
			CASE @TypeGroup  
				WHEN 0 THEN 
					bu.buDate 
				WHEN 1 THEN 
					(select MIN(BDate) FROM @Period P where (cast(Datepart(wk,bu.buDate) as NVARCHAR(10))+'-'+cast(year(bu.buDate) as NVARCHAR(10)))=(cast(DatePart(wk,BDate)as NVARCHAR(10))+'-'+cast(year(bDate) as NVARCHAR(10))))
				ELSE
					(select MIN(BDate) FROM @Period P where (cast(MONTH(bu.buDate) as NVARCHAR(10))+'-'+cast(year(bu.buDate) as NVARCHAR(10)))=(cast(MONTH(BDate)as NVARCHAR(10))+'-'+cast(year(bDate) as NVARCHAR(10))))
				END ,
				CASE @TypeGroup
					WHEN 0 THEN 
						bu.buDate 
					WHEN 1 THEN 
						(select MAX(BDate) FROM @Period P where (cast(Datepart(wk,bu.buDate) as NVARCHAR(10))+'-'+cast(year(bu.buDate) as NVARCHAR(10)))=(cast(DatePart(wk,BDate)as NVARCHAR(10))+'-'+cast(year(bDate) as NVARCHAR(10))))
					ELSE
						(select MAX(BDate) FROM @Period P where (cast(MONTH(bu.buDate) as NVARCHAR(10))+'-'+cast(year(bu.buDate) as NVARCHAR(10)))=(cast(MONTH(BDate)as NVARCHAR(10))+'-'+cast(year(bDate) as NVARCHAR(10))))
				END
				,SUM(bu.FixedBiTotal),St.StoreGuid,bu.buGuid 
	                            FROM fnExtended_bi_Fixed(@CurrpTr) bu 
	                            INNER JOIN #BillsTypesTbl Bt ON bu.buType=Bt.TypeGuid 
	                            INNER JOIN vwBt wbt ON bu.buType=wbt.btGUID 
	                            INNER JOIN #StoreTbl ST ON   ST.StoreGuid=bu.buStoreptr 
	                       WHERE  
	                        buDate BETWEEN @StartDate AND @EndDate  
	                        AND (bu.buIsPosted=@PostedValue OR @PostedValue=-1) 
	                        GROUP BY  
	                        Bt.TypeGuid,wbt.btBillType,bu.buDate,CASE @TypeGroup  
	                        WHEN 0 THEN CAST(DAY(bu.buDate) AS NVARCHAR(20))+'/'+CAST(MONTH(bu.buDate) AS NVARCHAR(20))+'/'+CAST(YEAR(bu.buDate) AS NVARCHAR(20)) 
	                        WHEN 1 THEN CAST(Datepart(WEEK,bu.buDate)  as NVARCHAR(20))+'/'+CAST(YEAR(bu.buDate) AS NVARCHAR(10)) 
	                        ELSE  
	                        CAST (MONTH(bu.buDate) AS NVARCHAR(20))+'/'+ CAST (YEAR(bu.buDate) AS NVARCHAR(20)) END 
	                        , bu.FixedBITotal,St.StoreGuid,bu.buGuid 
	                       --UPDATE #RESULT  A SET A.ORDERNUMBER=B.ORDERNUMBER INNER JOIN #RESULT AS B ON A.ORDERNUMBER=B.ORDERNUMBER1 
	                        
	
	  EXEC  prcCheckSecurity 
	   
	  SELECT TypeGuid,buBillType,OrderNumber,Sum(buTotal) as buTotal,StartDate,EndDate 
	      FROM #RESULT GROUP BY OrderNumber,StartDate,EndDate,buBillType, TypeGuid 
	      ORDER BY StartDate,buBillType,TypeGuid 
	  SELECT * FROM #SecViol     
	 DROP TABLE #Result 
	 DROP TABLE #SecViol 
	 DROP TABLE #BillsTypesTbl      
	 DROP TABLE #StoreTbl 
	  


############################################################## 
CREATE PROC repGetBilleTypeNameList
    @SrcTypesGuid UNIQUEIDENTIFIER,
    @StartDate  DATETIME,
    @EndDate    DATETIME
AS
 
   CREATE TABLE #BillsTypesTbl (TypeGuid UNIQUEIDENTIFIER,UserSecurity INTEGER,UserReadPtriceSecurity INT) 
   INSERT INTO  #BillsTypesTbl EXEC  prcGetBillsTypesList 	@SrcTypesguid 
  
   SELECT DISTINCT wbt.btGuid,wbt.btName,wbt.btLatinName,wbt.btbillType from vwBt wbt 
   INNER JOIN #BillsTypesTbl bt ON bt.TypeGuid=wbt.btGuid 
   INNER JOIN vwBu bu ON bu.buType=wbt.btGuid 
   WHERE bu.buDate Between @StartDate and @EndDate
   ORDER BY wbt.btbillType,wbt.btGuid 
#################################################################
#END                                                         