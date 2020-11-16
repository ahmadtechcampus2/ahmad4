CREATE    PROCEDURE repDayMoveSummary_RedwanW  
	@StartDate 					DATETIME,   
	@EndDate 					DATETIME,   
	@SrcTypesGUID				UNIQUEIDENTIFIER,   
	@StoreGuid					UNIQUEIDENTIFIER,   
	@Show 						INT , -- 0 Expand  , 1 Summary .  
	@ViewType					INT , -- 1 Daily , 2 Weekly  , 3 Mounthly  
	@SavePeriod					INT , -- 0 Without period , 1 With period   
	@CurrencyGUID 				UNIQUEIDENTIFIER   
AS   
SET NOCOUNT ON
SET DATEFIRST 1    
CREATE TABLE  	#SecViol      ( Type INT, Cnt INTEGER)   
CREATE TABLE  	#BillsTypesTbl( TypeGuid UNIQUEIDENTIFIER, UserSecurity INTEGER, UserReadPriceSecurity INTEGER)   
CREATE TABLE  	#StoreTbl     ( StoreGUID UNIQUEIDENTIFIER, Security INT)  

INSERT INTO 	#BillsTypesTbl	EXEC prcGetBillsTypesList 	@SrcTypesguid--, @UserGuid   
INSERT INTO 	#StoreTbl		EXEC prcGetStoresList 		@StoreGUID   

CREATE TABLE 	#Result  
( 	  
	Period							INT,  
	btBillType						INT,  
	buType 							UNIQUEIDENTIFIER ,  
	buDate							DATETIME,  
	btName							NVARCHAR(250) COLLATE ARABIC_CI_AI,  
	PeriodStartDate					DATETIME,  
	PeriodEndDate					DATETIME,  
	FixedBiTotal					FLOAT,   
	Security						INT,   
	UserSecurity 					INT,   
	UserReadPriceSecurity			INT   
)	   
INSERT INTO #Result  
SELECT 	  
	p.Period ,  
	rv.btBillType,   
	rv.buType ,  
	rv.buDate ,  
	rv.btName ,  
	p.StartDate ,  
	p.EndDate 	,  
	rv.FixedBiTotal,    
	buSecurity ,   
	bt.UserSecurity ,   
	bt.UserReadPriceSecurity   
FROM 	  
	dbo.fnExtended_bi_Fixed(@CurrencyGUID) AS rv  
	INNER JOIN dbo.fnGetDatePeriod(@ViewType, @StartDate, @EndDate) AS p   
			ON rv.buDate BETWEEN p.StartDate AND p.EndDate  
	INNER JOIN #BillsTypesTbl AS bt   
			ON rv.buType = bt.TypeGuid	  
	INNER JOIN #StoreTbl AS bs  
 			ON rv.biStorePtr = bs.StoreGUID 

EXEC prcCheckSecurity  

CREATE TABLE #Result1  
( 	  
	BHbillType					INT ,  
	BHbuType 					UNIQUEIDENTIFIER ,  
	BHbtName					NVARCHAR(255) COLLATE ARABIC_CI_AI  
)
   
INSERT INTO #Result1   
SELECT   
	btBillType ,  
	CASE WHEN (GROUPING(buType) = 1) THEN  0x0  
	ELSE ISNULL(buType, 0x0 )  
	END ,   

	CASE WHEN (GROUPING(btName) = 1) THEN '«·„Ã„Ê⁄ '   
	ELSE ISNULL(btName, '€Ì— „⁄—Ê› ' )  
	END   
FROM #Result  
GROUP BY btbilltype, butype ,btName   WITH ROLLUP   

DELETE #Result1  
WHERE ( ( BHbtName = '«·„Ã„Ê⁄ ' AND BHbuType <> 0X0) OR ( BHbillType IS NULL))  


--return first result set .  
IF ( @Show = 0 )  
BEGIN  
	SELECT * FROM #Result1   
END   


--return second result set .  
IF ( @Show = 0 )  
BEGIN   
	SELECT BHbillType AS NbillType , (COUNT ( BHbtName )) AS NumOfFlds  
	FROM #Result1  
	GROUP BY BHbillType  
END   
ELSE IF (@Show = 1)  
BEGIN  
	SELECT btBilltype AS NbillType   
	FROM #Result  
	GROUP BY btBilltype  
END   


--return third result set .  
SELECT  *   
FROM fnGetDatePeriod(@ViewType, @StartDate, @EndDate)    

CREATE TABLE #Result2  
(  
	Per							INT,  
	btBillType					INT,  
	butype						UNIQUEIDENTIFIER,  
	Su							FLOAT  
)  
INSERT INTO #Result2   
SELECT  
	period ,	  
	btBillType ,  
	butype ,  
	SUM ( FixedBiTotal ) 
	  
FROM  
	#Result  
GROUP BY  
period ,btBillType , butype  

CREATE TABLE #Result3  
(  
	Per							INT,  
	btBillType					INT ,  
	butype						UNIQUEIDENTIFIER,  
	QtySum						FLOAT   
)  
INSERT   INTO #Result3  
SELECT   
	CASE WHEN (GROUPING(per) = 1) THEN  -1  
   	ELSE ISNULL(per, -1 )  
    	END   
	AS per,  
	CASE WHEN (GROUPING(btBillType) = 1) THEN  -1  
   	ELSE ISNULL(btBillType, -1 )  
    	END   
	AS butype,  
	  
	CASE WHEN (GROUPING(butype) = 1) THEN  0x0  
   	ELSE ISNULL(butype, 0x0 )  
    	END   
	AS butype,  
   	SUM(Su) AS QtySum   
FROM #Result2  
GROUP BY  per ,btBillType ,butype WITH ROLLUP  
DELETE #Result3   
WHERE btBillType = -1  

--return forth result set .  
IF ( @Show = 0 )  
BEGIN  
	SELECT per,btBillType ,butype,QtySum   
	FROM #Result3   
	ORDER BY per ,btBilltype  
END   
ELSE IF ( @Show = 1 )  
BEGIN   
	DELETE #Result3  
		WHERE ( butype <> 0X0)  
	SELECT per ,btBillType ,butype,QtySum  
	FROM #Result3   
	ORDER BY per ,btBilltype  
END   

--return fifth result set .  
SELECT * FROM #SecViol   

DROP TABLE #Result  
DROP TABLE #Result1  
DROP TABLE #Result2  
DROP TABLE #Result3  
DROP TABLE #SecViol   
--@StartDate 			DATETIME,   
--@EndDate 				DATETIME,   
--@SrcTypesGUID			UNIQUEIDENTIFIER,   
--@StoreGuid			UNIQUEIDENTIFIER,   
--@ViewType				INT , -- 1 Daily , 2 Weekly  , 3 Mounthly   
--@CurrencyGUID 		UNIQUEIDENTIFIER   
-- exec repDayMoveSummary_RedwanW '9/1/2003','9/16/2003',0x0,0x0,0,1,1,'81331C4D-E1FB-4F0A-B6C2-76122DFECA6B'  
-- select * from fnExtended_bi_Fixed('FD13063B-C8AC-4316-9615-649EE68D0B76')  
-- dbo.prcConnections_Add2 '„œÌ—'  


