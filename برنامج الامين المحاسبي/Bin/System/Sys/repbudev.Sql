########################################
## fnGetReadyMatList
CREATE  FUNCTION fnGetReadyMatList(
					@StartDate DATETIME,
					@EndDate DATETIME,
					@ReadyBillType UNIQUEIDENTIFIER
)
RETURNS TABLE
AS
RETURN (
	SELECT
		mi.miParent AS ReadyManufPtr,
		fm.mnGUID AS ReadyFormPtr,
		mi.miMatGUID AS ReadyMatPtr,
		mt.mtName AS ReadyMatName,
		mt.mtCode AS ReadyMatCode,
		mi.miPrice AS ReadyMatUnitFact
	FROM	vwFm AS fm
		INNER JOIN vwMi AS mi
			ON fm.mnGUID = mi.miParent AND mi.miType = 0
			INNER JOIN vwMt AS mt
				ON mi.miMatGUID = mt.mtGUID
				INNER JOIN
				(
					SELECT * FROM vwMatQtys
					WHERE	(BillDate BETWEEN @StartDate AND @EndDate)
						AND BillType = @ReadyBillType
				) AS trmq
					ON mi.miMatGUID = trmq.ReadyMatPtr
	WHERE
		mi.miMatGUID = trmq.ReadyMatPtr AND
		mi.miParent = fm.mnGUID AND
		mi.miType = 0)
#############################################
## fnGetMatFormPtrs
CREATE FUNCTION fnGetMatFormPtrs ( @ItemPtr UNIQUEIDENTIFIER, @RepType INT)
RETURNS @Result TABLE ( FormPtr UNIQUEIDENTIFIER)
AS   
BEGIN 
--	return Forms Contain this Mat
--	RepType = 2 //Cost From Mx
--	RepType <> 2 // Mat From Mi
	if @RepType <> 2 
	BEGIN	 
		INSERT INTO @Result
		SELECT fm.mnGUID FROM vwMi AS mi
			INNER JOIN vwFm AS fm
				ON fm.mnGUID = mi.miParent
		WHERE   
		mi.miType = 0 AND 
		mi.miMatGUID = @ItemPtr 
	END 
	ELSE 
	BEGIN 
		INSERT INTO @Result  
		SELECT fm.mnGUID FROM vwMx AS mx 
			INNER JOIN vwfm AS fm
				ON fm.mnGUID = mx.mxParentGUID
		WHERE   		
			mx.mxAccountGUID = @ItemPtr 
	END 
	RETURN 
END 
#######################################
## fnGetFormReadyMatPtrs
CREATE  FUNCTION fnGetFormReadyMatPtrs ( @RawMatPtr UNIQUEIDENTIFIER, @RepType INT)   
RETURNS TABLE 
AS  
RETURN ( 
	SELECT mi.miMatGUID as ReadyMatPtr
	FROM vwMi as mi
		INNER JOIN vwFm AS fm
			ON fm.mnGUID = mi.miParent
	WHERE 
		mi.miType = 0	AND fm.fmGUID IN(
			SELECT *  
			FROM fnGetMatFormPtrs ( @RawMatPtr, @RepType))) 

############################################ fnGetReadyMatFormQtys
CREATE    FUNCTION fnGetReadyMatFormQtys (	
					@StartDate DATETIME,
					@EndDate DATETIME,
					@ReadyBillType UNIQUEIDENTIFIER) 
RETURNS TABLE  
AS 
RETURN( 
	SELECT	DISTINCT 
	mi.miParent AS ReadyManufPtr,
	fm.fmGUID AS ReadyFormPtr,
	mi.miMatGUID AS ReadyMatPtr,  
	mt.mtName AS ReadyMatName, 
	(CASE mi.miUnity  
		WHEN 1 THEN (CASE mt.mtDefUnit
				WHEN 1 THEN mi.miQty  
				WHEN 2 THEN mi.miQty / ISNULL( CASE mt.mtUnit2Fact WHEN 0 THEN 1 END, 1)  
				WHEN 3 THEN mi.miQty / ISNULL( CASE mt.mtUnit3Fact WHEN 0 THEN 1 END, 1)  
				END)  
		WHEN 2 THEN (CASE mt.mtDefUnit 
				WHEN 1 THEN mi.miQty * mt.mtUnit2Fact  
				WHEN 2 THEN mi.miQty  
				WHEN 3 THEN mi.miQty * mt.mtUnit2Fact / ISNULL( CASE mt.mtUnit3Fact WHEN 0 THEN 1 END, 1)  
				END)  
		WHEN 3 THEN (CASE mt.mtdefUnit
				WHEN 1 THEN mi.miQty * mt.mtUnit3Fact  
				WHEN 2 THEN mi.miQty * mt.mtUnit3Fact / ISNULL( CASE mt.mtUnit2Fact WHEN 0 THEN 1 END, 1)  
				WHEN 3 THEN mi.miQty END)  
				END) AS ReadyMatTotalQty, 
	(CASE mt.mtDefUnit
		WHEN 1 THEN mt.mtunity  
		WHEN 2 THEN mt.mtunit2 
		WHEN 3 THEN mt.mtunit3 
		END) AS ReadyMatUnit, 
	mi.miprice AS ReadyMatUnitFact				 
	FROM
		vwfm AS fm
			INNER JOIN vwmi AS mi  
			ON fm.mnGUID = mi.miParent AND mi.miType = 0  
				INNER JOIN vwmt AS mt  
				ON mi.miMatGUID = mt.mtGUID 
					INNER JOIN  
					( 
						SELECT * FROM vwMatQtys  
						WHERE	(BillDate BETWEEN @StartDate AND @EndDate) 
								AND BillType = @ReadyBillType 
					) AS trmq 
					ON mi.miMatGUID = trmq.ReadyMatPtr 
	WHERE  
	mi.miMatGUID = trmq.ReadyMatPtr 
	AND mi.mitype = 0 ) 
#############################################
## fnGetReadyMatQtysOfRawMat
CREATE   FUNCTION fnGetReadyMatQtysOfRawMat (	
						@StartDate DATETIME, 
						@EndDate DATETIME, 
						@ReadyBillType UNIQUEIDENTIFIER,
						@RawMatPtr UNIQUEIDENTIFIER,
						@RepType INT)
RETURNS TABLE  
AS 
RETURN( 
	SELECT   
		MatFormQtys.ReadyFormPtr AS ReadyFormPtr,  
		MatTotalQtys.ReadyMatPtr AS ReadyMatPtr,  
		MatFormQtys.ReadyMatTotalQty AS ReadyMatFormQty,  
		MatTotalQtys.ReadyMatTotalQty AS ReadyMatTotalQty,  
		MatFormQtys.ReadyMatUnitFact AS ReadyMatUnitFact 
	FROM ( 	SELECT *  
		FROM fnGetFormReadyMatPtrs (@RawMatPtr,@RepType) 
		) AS MatPtrs  
	INNER JOIN  
	( 
		SELECT * FROM vwMatQtys
		WHERE	
			(BillDate BETWEEN @StartDate AND @EndDate) AND
			BillType = @ReadyBillType 
	) As MatTotalQtys 
	ON MatPtrs.ReadyMatPtr = MatTotalQtys.ReadyMatPtr 
	INNER JOIN  
	( SELECT * FROM fnGetReadyMatFormQtys ( 	
						@StartDate,  
						@EndDate,  
						@ReadyBillType)   
	) AS MatFormQtys 
	ON MatPtrs.ReadyMatPtr = MatFormQtys.ReadyMatPtr) 
#############################################
## fnGetRawMatStanderedQtys
CREATE FUNCTION fnGetRawMatStanderedQtys (	
		@StartDate DATETIME,				--
		@EndDate DATETIME,					--
		@ReadyBillType UNIQUEIDENTIFIER,	--
		@ItemPtr UNIQUEIDENTIFIER,			--
		@RepType INT,						--
		@CurVal float,						--
		@UserId UNIQUEIDENTIFIER)			--

RETURNS @Result TABLE ( 
		RawMatPtr UNIQUEIDENTIFIER,   
		RawMatName NVARCHAR(256) COLLATE ARABIC_CI_AI,
		RawMatCode NVARCHAR(256) COLLATE ARABIC_CI_AI,
		RawMatStanderedQty float,
		RawMatUnit NVARCHAR(256) COLLATE ARABIC_CI_AI)
AS   
BEGIN   
	IF @RepType <>2   
	BEGIN   
		INSERT INTO @Result
		SELECT	mt.mtGUID AS RawMatPtr,   
			mt.mtname AS RawMatName,   
			mt.mtcode AS RawMatCode,   
			(CASE mi.miUnity
				WHEN 1 THEN (CASE mt.mtDefUnit
						WHEN 1 THEN SUM( mi.miQty * RawMatQty.ReadyMatTotalQty / RawMatQty.ReadyMatFormQty * RawMatQty.ReadyMatUnitFact / 100)   
						WHEN 2 THEN SUM(( mi.miQty / ISNULL( CASE mt.mtUnit2Fact WHEN 0 THEN 1 ELSE mt.mtUnit2Fact END,1) * ( RawMatQty.ReadyMatTotalQty / RawMatQty.ReadyMatFormQty) * ( RawMatQty.ReadyMatUnitFact / 100)))   
						ELSE SUM(( mi.miQty / ISNULL( CASE mt.mtUnit3Fact WHEN 0 THEN 1 ELSE mt.mtUnit3Fact END,1) * ( RawMatQty.ReadyMatTotalQty / RawMatQty.ReadyMatFormQty) * ( RawMatQty.ReadyMatUnitFact / 100)))   
						END)    
				WHEN 2 THEN (CASE mt.mtDefUnit
						WHEN 1 THEN SUM((( mi.miQty * mt.mtUnit2Fact) * ( RawMatQty.ReadyMatTotalQty / RawMatQty.ReadyMatFormQty) * ( RawMatQty.ReadyMatUnitFact / 100)))   
						WHEN 2 THEN SUM(( mi.miQty * ( RawMatQty.ReadyMatTotalQty / RawMatQty.ReadyMatFormQty) * ( RawMatQty.ReadyMatUnitFact / 100)))   
						ELSE SUM((( mi.miQty * mt.mtUnit2Fact / ISNULL( CASE mt.mtUnit3Fact WHEN 0 THEN 1 ELSE mt.mtUnit3Fact END, 1)) * ( RawMatQty.ReadyMatTotalQty / RawMatQty.ReadyMatFormQty) * ( RawMatQty.ReadyMatUnitFact / 100)))   
						END)    
				ELSE (CASE mt.mtDefUnit
						WHEN 1 THEN SUM((( mi.miQty * mt.mtUnit3Fact) * ( RawMatQty.ReadyMatTotalQty / RawMatQty.ReadyMatFormQty) * ( RawMatQty.ReadyMatUnitFact / 100)))   
						WHEN 2 THEN SUM(( mi.miQty * mt.mtUnit3Fact / ISNULL( CASE mt.mtUnit2Fact WHEN 0 THEN 1 ELSE mt.mtUnit2Fact END,1)) * ( RawMatQty.ReadyMatTotalQty / RawMatQty.ReadyMatFormQty) * ( RawMatQty.ReadyMatUnitFact / 100))   
						ELSE SUM( mi.miQty * ( RawMatQty.ReadyMatTotalQty / RawMatQty.ReadyMatFormQty) * ( RawMatQty.ReadyMatUnitFact / 100))   
						END)    
				END) AS RawMatStanderedQty ,   
			(CASE mt.mtDefUnit
				WHEN 1 THEN mt.mtUnity    
				WHEN 2 THEN mt.mtUnit2   
				ELSE mt.mtUnit3   
				END) AS RawMatUnit   
		FROM	vwFm AS fm    
			INNER JOIN vwMi AS mi
			ON fm.mnGUID = mi.miParent
				INNER JOIN vwMt AS mt
				ON mi.miMatGUID = mt.mtGUID
					INNER JOIN
					( SELECT * FROM fnGetReadyMatQtysOfRawMat( 	
								@StartDate,    
								@EndDate,    
								@ReadyBillType,    
								@ItemPtr,   
								@RepType )   
					) AS RawMatQty
					ON mi.miParent = RawMatQty.ReadyFormPtr
		WHERE 	   
			mi.miType = 0 --AND
			--dbo.fnGetBrowseSec( @UserId, 0x20002080) >= fm.fmSecurity
			-- (IDSC_REPORTS + RID_COSTREPSBASE + RID_FORMCARD) = 0x20002080 AND 
			--dbo.fnGetBrowseSec( @UserId, 0xf00) >= mt.mtSecurity  
		GROUP BY    
			mt.mtGUID,   
			mt.mtDefUnit,
			mt.mtName,    
			mt.Mtcode,    
			mt.MtFlag,   
			(CASE mt.mtDefUnit    
				WHEN 1 THEN mt.mtUnity
				WHEN 2 THEN mt.mtUnit2   
				ELSE mt.mtUnit3   
				END),
			mi.miUnity   
	END   
	ELSE   
	BEGIN   
		INSERT INTO @Result   
			SELECT	ac.acGUID,   
				ac.acName,   
				ac.acCode,   
				SUM( (CASE mx.mxType    
					WHEN 0 THEN
						mx.mxExtra * FormCostVal.ReadyMatTotalQty    
							/ FormCostVal.ReadyMatFormQty    
							* FormCostVal.ReadyMatUnitFact / 100    
							/ @CurVal   
					WHEN 1 THEN    
						mx.mxExtra    
							*  FormCostVal.ReadyMatUnitFact / 100    
							/ @CurVal   
					ELSE 0 END)) AS CostVal,   
				''		   
			FROM	vwMx AS mx    
				INNER JOIN vwAc AS ac    
				ON ac.acGUID = mx.mxAccountGUID   
				INNER JOIN    
				( SELECT * FROM fnGetReadyMatQtysOfRawMat( 	@StartDate,    
										@EndDate,    
										@ReadyBillType,    
										@ItemPtr,   
										@RepType)   
				) AS FormCostVal   
				ON mx.mxParentGUID = FormCostVal.ReadyFormPtr   
			WHERE    
				ac.acGUID = @ItemPtr   
				--AND dbo.fnGetBrowseSec( @UserId, 0xf02) >= ac.acSecurity  
			GROUP BY    
				ac.acGUID,   
				ac.acName,   
				ac.acCode   
	END   
	return   
END   
################################
## repManufBillDev
## ÇäÍÑÇÝ ÝæÇÊíÑ ÇáÊÕäíÚ
CREATE PROCEDURE repManufBillDev
			@StartDate DATETIME,  
			@EndDate DATETIME,  
			@MatGUID UNIQUEIDENTIFIER,  
			@GroupGUID UNIQUEIDENTIFIER,  
			@CostGUID UNIQUEIDENTIFIER,  
			@UserGUID UNIQUEIDENTIFIER,  
			@RepType INT,  
			@UseUnit FLOAT,
			@CurGUID UNIQUEIDENTIFIER,  
			@CurVal float,  
			@RawBillSrcs UNIQUEIDENTIFIER,  
			@ReadyBillSrcs UNIQUEIDENTIFIER,  
			@RawAccGUID UNIQUEIDENTIFIER,  
			@ReadyAccGUID UNIQUEIDENTIFIER  
AS  
SET NOCOUNT ON  
---- P L A N ------------------------------------------------------------------  
--	1	Calc ready material to find in ready Bills With Qty of Unit1  
--	2	Calc ready material to find in previous table and forms as ready material with form Qty  
--	3	Calc Percent Between Form And Bill Ready Material Qty >> Production Qty  
--	4	Calc raw material to find in itself forms with Qty  
--	5	Calc raw material to find in raw Bills and previous table(form contain ready material)  
--	6	the last table to include all qty (ReadyBill, ReadyForm, RawForm, RawBill)  
--	7	calc Result from the last table  
--	8	Calc Form cost value dependency Production Qty (Maltiple Percent Between Form And Bill Ready Material)   
--	9	Calc Bill extra cost for account to find in previous table  
--	10	the last table to include this values (StandardValue, ActualValue)  
-------------------------------------------------------------------------------  

DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();

CREATE TABLE #RawSrc( GUID UNIQUEIDENTIFIER, Sec INT, ReadPrice INT, IsOutPut INT)     
INSERT INTO #RawSrc(GUID , Sec, ReadPrice) EXEC prcGetBillsTypesList @RawBillSrcs  
CREATE TABLE #ReadySrc( GUID UNIQUEIDENTIFIER, Sec INT, ReadPrice INT, IsOutPut INT)     
INSERT INTO #ReadySrc(GUID , Sec, ReadPrice) EXEC prcGetBillsTypesList @ReadyBillSrcs  
CREATE TABLE #MatTbl(	GUID UNIQUEIDENTIFIER, mtSecurity INT) 
INSERT INTO #MatTbl		EXEC prcGetMatsList 		@MatGUID, @GroupGUID 
CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT])  
UPDATE #RawSrc  
	SET	IsOutPut = bt.bIsOutPut  
FROM  
	#RawSrc AS s, Bt000 AS bt  
WHERE  
	s.GUID = bt.GUID  
UPDATE #ReadySrc  
	SET	IsOutPut = bt.bIsOutPut  
FROM  
	#ReadySrc AS s, Bt000 AS bt  
WHERE  
	s.GUID = bt.GUID  
--SELECT * FROM #RawSrc  
--SELECT * FROM #ReadySrc  
SET @RawAccGUID = ISNULL(@RawAccGUID,0x0)  
SET @ReadyAccGUID = ISNULL(@ReadyAccGUID,0x0)  
SET @CostGUID = ISNULL(@CostGUID,0x0)  
----------- Cost Table  
CREATE TABLE #Cost (GUID uniqueidentifier, Security int)  
if (@CostGUID = 0x0)  
begin  
	INSERT INTO #Cost SELECT coGUID, coSecurity FROM vwCo  
	INSERT INTO #Cost VALUES(0x0, 1)  
end  
else  
BEGIN  
	INSERT INTO #Cost EXEC prcGetCostsList @CostGUID  
END  
--SELECT * FROM #Cost  
----------------------------  
----------- RawAcc Table  
CREATE TABLE #RawAcc (GUID uniqueidentifier, Security int, Level int)  
if (@RawAccGUID <> 0x0)  
	INSERT INTO #RawAcc EXEC prcGetAccountsList @RawAccGUID  
----------------------------  
----------- ReadyAcc Table  
CREATE TABLE #ReadyAcc (GUID uniqueidentifier, Security int, Level int)  
if (@ReadyAccGUID <> 0x0)  
	INSERT INTO #ReadyAcc EXEC prcGetAccountsList @ReadyAccGUID  
----------------------------  
CREATE TABLE #Result  
(  
	ManGUID			UNIQUEIDENTIFIER,  
	MatGUID			UNIQUEIDENTIFIER,
	mtSecurity		int,
	StandardQty 	FLOAT,  
	ActualQty 		FLOAT,  
	StandardPrice 	FLOAT,  
	ActualPrice		FLOAT,  
	dependMatGUID	UNIQUEIDENTIFIER  
)  
-- Ready Material From Bill With Qty in Unit 1  
CREATE TABLE #BillReadyMaterial(MatGUID uniqueidentifier, Qty FLOAT)  
if (@ReadyAccGUID = 0x0)  
	INSERT INTO #BillReadyMaterial   
	SELECT   
		bi.biMatPtr,  
		Sum(CASE bt.IsOutPut WHEN 1 THEN (bi.biQty * -1) ELSE bi.biQty END)  
	FROM  
		vwExtended_bi AS bi   
		INNER JOIN #Cost AS co ON bi.biCostPtr = co.GUID  
		INNER JOIN #ReadySrc AS bt ON bi.buType = bt.GUID  
	WHERE  
		bi.buDate BETWEEN @StartDate AND @EndDate  
	GROUP BY  
		bi.biMatPtr   
else  
	INSERT INTO #BillReadyMaterial   
	SELECT   
		bi.biMatPtr,  
		Sum(CASE bt.IsOutPut WHEN 1 THEN (bi.biQty * -1) ELSE bi.biQty END)  
	FROM  
		vwExtended_bi AS bi   
		INNER JOIN #Cost AS co ON bi.biCostPtr = co.GUID  
		INNER JOIN #ReadySrc AS bt ON bi.buType = bt.GUID  
		INNER JOIN #ReadyAcc AS ac ON bi.buMatAcc = ac.GUID  
	WHERE  
		bi.buDate BETWEEN @StartDate AND @EndDate  
	GROUP BY  
		bi.biMatPtr   
-------------------------------------------		  
--SELECT MatGUID, Qty, mtName FROM #BillReadyMaterial INNER JOIN vwmt ON mtGUID = MATGUID  
-------------------------------------------		  
-- Ready Material From Forms With Qty in Unit 1  
CREATE TABLE #FormReadyMaterial  
(  
	MatGUID uniqueidentifier,   
	ManufTemplateGUID uniqueidentifier,  
	FormQty FLOAT,  
	BillQty FLOAT  
)  
INSERT INTO #FormReadyMaterial  
SELECT  
	mi.miMatGUID,  
	mi.mnGUID,  
	mi.miQty * (CASE mi.miUnity WHEN 1 THEN 1 WHEN 2 THEN mi.mtUnit2Fact WHEN 3 THEN mi.mtUnit3Fact END),
	rm.Qty  
FROM  
	vwMnMiMt AS mi   
	INNER JOIN #BillReadyMaterial AS rm ON mi.miMatGUID = rm.MatGUID  
WHERE  
	mi.mnType = 0 AND  
	mi.miType = 0  
-------------------------------------------		  
--SELECT MatGUID, FormQty, BillQty, mtName FROM #FormReadyMaterial INNER JOIN vwmt ON mtGUID = MATGUID  
-------------------------------------------		  
-- in the interest of cost  
CREATE TABLE #ProductionPercent( ManGUID uniqueidentifier, [Percent] FLOAT)  
INSERT INTO #ProductionPercent  
SELECT  
	ManufTemplateGUID,  
	(BillQty/FormQty)  
FROM  
	#FormReadyMaterial  
--SELECT * FROM #ProductionPercent  
------------------------------------------------  
IF (@RepType = 0 OR @RepType = 1)  
BEGIN  
	-- Raw Material From Form With Quantity in Unit 1  
	CREATE TABLE #FormRawMaterial  
	(  
		RawMatGUID uniqueidentifier,  
		ManufTemplateGUID uniqueidentifier,  
		ReadyMatGUID uniqueidentifier,  
		RawFormQty FLOAT,  
		RawFormPrice FLOAT,  
		ReadyFormQty FLOAT,  
		ReadyBillQty FLOAT,  
		  
	)  
	INSERT INTO #FormRawMaterial  
	SELECT  
		mi.MatGUID,  
		mi.ParentGUID,  
		rm.MatGUID,  
		Sum(mi.Qty),
		Sum(mi.Price / (CASE mi.Unity WHEN 1 THEN 1 WHEN 2 THEN mt.mtUnit2Fact WHEN 3 THEN mt.mtUnit3Fact END)),  
		rm.FormQty,  
		rm.BillQty  
	FROM  
		Mi000 AS mi   
		INNER JOIN #FormReadyMaterial AS rm ON rm.ManufTemplateGUID = mi.ParentGUID  
		INNER JOIN #MatTbl AS mttbl ON mttbl.GUID = mi.MatGUID
		INNER JOIN vwMt AS mt On mt.mtGUID = mi.MatGUID  
	WHERE  
		mi.Type = 1  
	GROUP BY  
		mi.MatGUID,  
		mi.ParentGUID,  
		rm.MatGUID,  
		rm.FormQty,  
		rm.BillQty  
-------------------------------------------		  
--SELECT r.*, mt1.mtName AS RawName, mt2.mtName AS ReadyName FROM #FormRawMaterial AS r INNER JOIN vwMt AS mt1 ON mt1.mtGUID = r.RawMatGUID INNER JOIN vwMt AS mt2 ON r.ReadyMatGUID = mt2.mtGUID  
-------------------------------------------		  
	-- Raw Materiall From Bill With Qty In Unit 1  
	CREATE TABLE #BillRawMaterial  
	(  
		RawMatGUID uniqueidentifier,  
		ManufTemplateGUID uniqueidentifier,  
		ReadyMatGUID uniqueidentifier,  
		RawFormQty FLOAT,  
		RawFormPrice FLOAT,  
		ReadyFormQty FLOAT,  
		ReadyBillQty FLOAT,  
		RawBillQty FLOAT,  
		RawBillPriceCost FLOAT  
	)  
	CREATE TABLE #BillRawMaterialTemp
	(
		GUID uniqueidentifier,  
		Qty FLOAT,  
		Price FLOAT  
	)
	IF (@RawAccGUID = 0x0)  
	BEGIN
		INSERT INTO #BillRawMaterialTemp
		SELECT   
			bi.biMatPtr,
			SUM(CASE bt.IsOutPut WHEN 1 THEN bi.biQty ELSE (bi.biQty * -1) END),
			SUM( (CASE bt.IsOutPut WHEN 1 THEN bi.biQty ELSE (bi.biQty * -1) END) * (bi.biUnitPrice))
		FROM  
			vwExtended_bi AS bi INNER JOIN #Cost AS co ON bi.biCostPtr = co.GUID
								INNER JOIN #RawSrc AS bt ON bt.GUID = bi.buType
		WHERE
			bi.buDate BETWEEN @StartDate AND @EndDate
		GROUP BY 
			bi.biMatPtr
		
		--select * from #BillRawMaterialTemp
	END
	ELSE  
	begin
		INSERT INTO #BillRawMaterialTemp
		SELECT   
			bi.biMatPtr,
			ISNULL(SUM(CASE bt.IsOutPut WHEN 1 THEN bi.biQty ELSE (bi.biQty * -1) END), 0),  
			ISNULL(SUM( (CASE bt.IsOutPut WHEN 1 THEN bi.biQty ELSE (bi.biQty * -1) END) * (bi.biUnitPrice)), 0 )
		FROM  
			vwExtended_bi AS bi
			INNER JOIN #Cost AS co ON bi.biCostPtr = co.GUID
			INNER JOIN #RawSrc AS bt ON bt.GUID = bi.buType
			INNER JOIN #RawAcc AS ac ON bi.buMatAcc = ac.GUID  
		WHERE
			bi.buDate BETWEEN @StartDate AND @EndDate
		GROUP BY 
			bi.biMatPtr
	end
-------------------------------------------		  
--SELECT r.*, mt1.mtName AS RawName FROM #BillRawMaterialTemp AS r INNER JOIN vwMt AS mt1 ON mt1.mtGUID = r.GUID ORDER BY mt1.mtName
-------------------------------------------		  
	INSERT INTO #BillRawMaterial  
	SELECT   
		ISNULL(frm.RawMatGUID, t.GUID),
		frm.ManufTemplateGUID,  
		ISNULL(frm.ReadyMatGUID, 0x0),
		ISNULL(frm.RawFormQty, 0),
		ISNULL(frm.RawFormPrice, 0),
		ISNULL(frm.ReadyFormQty, 0),
		ISNULL(frm.ReadyBillQty, 0),
		ISNULL(t.Qty, 0),
		ISNULL(t.Price, 0)
	FROM  
		#FormRawMaterial AS frm
		FULL JOIN #BillRawMaterialTemp AS t ON frm.RawMatGUID = t.GUID
--	select * from #BillRawMaterial
-------------------------------------------		  
--SELECT * FROM #BillRawMaterial
--SELECT r.*, mt1.mtName AS RawName, mt2.mtName AS ReadyName FROM #BillRawMaterial AS r INNER JOIN vwMt AS mt1 ON mt1.mtGUID = r.RawMatGUID INNER JOIN vwMt AS mt2 ON r.ReadyMatGUID = mt2.mtGUID ORDER BY mt1.mtName
-------------------------------------------		  
	--/////////////////////
	--DELETE #BillRawMaterial WHERE ReadyFormQty = 0 OR RawBillQty = 0
	--///////////////////// 
	-- Calc Result  
	IF (@RepType = 0)	-- Raw Material  
	BEGIN  
		INSERT INTO #Result  
		SELECT  
			(SELECT top 1 ManufTemplateGUID FROM #BillRawMaterial AS rm WHERE rm.RawMatGUID = RawMatGUID ) AS ManufTemplateGUID,  
			RawMatGUID,  
			0,
			Sum(RawFormQty * CASE ReadyFormQty WHEN 0 THEN 0 ELSE (ReadyBillQty/ReadyFormQty) END) AS StandardVal,  
			avg(RawBillQty) AS VirtualVal,  
			CASE Sum(RawFormQty) WHEN 0 THEN 0 ELSE (Sum(RawFormPrice * RawFormQty) / Sum(RawFormQty)) END AS StandardUnitPrice,  
			avg(CASE RawBillQty WHEN 0 THEN 0 ELSE (RawBillPriceCost / RawBillQty) END) AS ActualUnitPrice,			  
			0x0  
		FROM  
			#BillRawMaterial 
		GROUP BY   
			RawMatGUID
		
		UPDATE #Result SET mtSecurity = mt.Security
		FROM
			#Result AS r, mt000 AS mt
		WHERE
			mt.GUID = r.MatGUID
	--- Return Result  
		EXEC prcCheckSecurity
		SELECT  
			fm.fmGUID AS FormGUID,  
			r.MatGUID AS GUID,  
			mt.mtCode AS Code,  
			CASE WHEN @Lang > 0 THEN CASE when  mt.mtLatinName = '' THEN mt.mtName ELSE mt.mtLatinName END ELSE mt.mtName END AS Name,  
			(r.StandardQty  /
			(CASE @UseUnit
			WHEN 0 THEN 1
			WHEN 1 THEN  ISNULL(NULLIF(mt.mtUnit2Fact, 0), 1)
 			WHEN 2 THEN  ISNULL(NULLIF(mt.mtUnit3Fact, 0), 1)
			ELSE ISNULL(NULLIF(mt.mtDefUnitFact, 0), 1) END)) AS StandardQty,  
			(r.ActualQty  / (CASE @UseUnit
			WHEN 0 THEN 1
			WHEN 1 THEN  ISNULL(NULLIF(mt.mtUnit2Fact, 0), 1)
			WHEN 2 THEN  ISNULL(NULLIF(mt.mtUnit3Fact, 0), 1)
			ELSE ISNULL(NULLIF(mt.mtDefUnitFact, 0), 1) END)) AS ActualQty,    
			(r.StandardPrice * mt.mtDefUnitFact) AS StandardPrice,  
			(r.ActualPrice * mt.mtDefUnitFact) AS ActualPrice,
			CASE @UseUnit
			WHEN 0 THEN mt.[mtUnity]
			WHEN 1 THEN   ISNULL(NULLIF(mt.[mtUnit2], ''), mt.[mtUnity])
			WHEN 2 THEN   ISNULL(NULLIF(mt.[mtUnit3], ''), mt.[mtUnity])
			ELSE mt.[mtDefUnitName] END
			AS [UnitName]   
		FROM   
			#Result AS r   
			INNER JOIN vwMt AS mt ON mt.mtGUID = r.MatGuid  
			INNER JOIN vwFm AS fm ON r.ManGUID = fm.mnGUID
			INNER JOIN #MatTbl on r.MatGUID =  #MatTbl.GUID  
	  
	END  
	  
	IF (@RepType = 1)	-- Ready Material  
	BEGIN  
		INSERT INTO #Result
		SELECT  
			ManufTemplateGUID,  
			ReadyMatGUID,  
			0,
			Sum(ReadyFormQty * (RawBillQty/RawFormQty)) AS StandardVal,  
			Avg(ReadyBillQty) AS VirtualVal,  
			0,  
			0,		  
			RawMatGUID  
		FROM  
			#BillRawMaterial  
		WHERE
			RawFormQty > 0
		GROUP BY  
			ManufTemplateGUID,  
			RawMatGUID,  
			ReadyMatGUID  
	  
		UPDATE #Result SET mtSecurity = mt.Security
		FROM
			#Result AS r, mt000 AS mt
		WHERE
			mt.GUID = r.MatGUID
	--- Return Result  
		EXEC prcCheckSecurity
		SELECT  
			fm.fmGUID AS FormGUID,  
			r.MatGUID AS GUID,  
			mt1.mtCode AS Code,  
			CASE WHEN @Lang > 0 THEN CASE when  mt1.mtLatinName = '' THEN mt1.mtName ELSE mt1.mtLatinName END ELSE mt1.mtName END AS Name,  
			(r.StandardQty  / (CASE @UseUnit
		    WHEN 0 THEN  1
			WHEN 1 THEN  ISNULL(NULLIF(mt1.mtUnit2Fact, 0), 1)
			WHEN 2 THEN  ISNULL(NULLIF(mt1.mtUnit3Fact, 0), 1)
			ELSE ISNULL(NULLIF(mt1.mtDefUnitFact, 0), 1) END)) AS StandardQty,  
			(r.ActualQty  / (CASE @UseUnit
			WHEN 0 THEN  1
			WHEN 1 THEN  ISNULL(NULLIF(mt1.mtUnit2Fact, 0), 1)
			WHEN 2 THEN  ISNULL(NULLIF(mt1.mtUnit3Fact, 0), 1)
			ELSE mt1.mtDefUnitFact END)) AS ActualQty,  
			(r.StandardPrice * mt1.mtDefUnitFact) AS StandardPrice,  
			(r.ActualPrice * mt1.mtDefUnitFact) AS ActualPrice,  
			CASE @UseUnit
			WHEN 0 THEN mt1.[mtUnity]
			WHEN 1 THEN mt1.[mtUnit2] 
			WHEN 2 THEN mt1.[mtUnit3] 
			ELSE mt1.[mtDefUnitName] END
			AS [UnitName],  
			r.dependMatGUID AS DependMatGUID,  
			CASE WHEN @Lang > 0 THEN CASE when  mt2.mtLatinName = '' THEN mt2.mtName ELSE mt2.mtLatinName END ELSE mt2.mtName END AS DependName  
		FROM   
			#Result AS r   
			INNER JOIN vwMt AS mt1 ON mt1.mtGUID = r.MatGuid  
			INNER JOIN vwMt AS mt2 ON mt2.mtGUID = r.dependMatGUID  
			INNER JOIN vwFm AS fm ON r.ManGUID = fm.mnGUID  
		ORDER BY  
			Name,  
			dependMatGUID  
	END  
END  
IF(@RepType = 2)  
BEGIN  
	-- Extra Cost From Form With Val In Currency 1  
	--SELECT * FROM #ProductionPercent  
	CREATE TABLE #FormCost  
	(  
		AccGUID uniqueidentifier,  
		Value FLOAT  
	)  
	INSERT INTO #FormCost  
	SELECT  
		mxAccountGUID,  
		Sum(CASE mxType WHEN 1 THEN (mxExtra * mxCurrencyVal / @CurVal) WHEN 0 THEN (mxExtra * mxCurrencyVal / @CurVal) * pr.[percent] END)  
	FROM  
		vwMnMxAc AS mx   
		INNER JOIN #ProductionPercent AS pr ON pr.ManGUID = mx.mnGUID  
		INNER JOIN #Cost AS co ON co.GUID = mx.mxCostGUID  
	WHERE  
		mnType = 0  
	GROUP BY  
		mx.mxAccountGUID  
	--SELECT fc.*, ac.acName FROM #FormCost AS fc INNER JOIN vwAc AS ac ON AccGUID = ac.acGUID  
	-- Extra Cost From Bill With Val In Currency 1  
	CREATE TABLE #BillCost  
	(  
		AccGUID uniqueidentifier,  
		Value FLOAT  
	)  
	INSERT INTO #BillCost  
	SELECT  
		diAccountGUID,  
		Sum(diExtra * diCurrencyVal / @CurVal)  
	FROM  
		vwExtended_Di AS di   
		INNER JOIN #Cost AS co ON co.GUID = di.diCostGUID  
		INNER JOIN (SELECT DISTINCT AccGUID FROM #FormCost) AS fc ON fc.AccGUID = di.diAccountGUID  
	WHERE  
		di.buDate BETWEEN @StartDate AND @EndDate  
	GROUP BY  
		diAccountGUID  
	--SELECT bc.*, ac.acName FROM #BillCost AS bc INNER JOIN vwAc AS ac ON AccGUID = ac.acGUID  
	-- Form Cost With Bill Cost In Currency 1  
	CREATE TABLE #FormBillCost
	(  
		AccGUID uniqueidentifier,
		acSecurity int,
		StandaredVal FLOAT,  
		ActualVal FLOAT  
	)	  
	INSERT INTO #FormBillCost  
	SELECT  
		fc.AccGUID,
		0,
		fc.Value AS StandaredVal,  
		bc.Value  
	FROM  
		#FormCost AS fc  
		INNER JOIN #BillCost AS bc ON bc.AccGUID = fc.AccGUID  
	--SELECT fb.*, ac.acName FROM #FormBillCost AS fb INNER JOIN vwAc AS ac ON AccGUID = ac.acGUID  
	-- return result  
	DECLARE @g Uniqueidentifier  
	SET @g = 0x0  
	
	
	UPDATE #FormBillCost SET acSecurity = ac.Security
	FROM
		#FormBillCost AS r, ac000 AS ac
	WHERE
		ac.GUID = r.accGUID
	--- Return Result  
	EXEC prcCheckSecurity null, 0, 0, '#FormBillCost'
	
	SELECT  
		@g AS FormGUID,  
		AccGUID AS GUID,  
		CASE WHEN @Lang > 0 THEN CASE WHEN ac.acLatinName = '' THEN ac.acName ELSE ac.acLatinName END ELSE ac.acName END AS Name,  
		ac.acCode AS Code,  
		StandaredVal AS StandardQty,  
		ActualVal AS ActualQty,
		CONVERT(VARCHAR(250), '') AS UnitName  
	FROM  
		#FormBillCost AS fb  
		INNER JOIN vwAc AS ac ON ac.acGUID = fb.AccGUID   
END  

/*

repManufBillDev '1/1/2007', --@StartDate
				'1/3/2008', --@EndDate
				'00000000-0000-0000-0000-000000000000', --@MatGUID
				'00000000-0000-0000-0000-000000000000', --@GroupGUID
				'00000000-0000-0000-0000-000000000000', --@CostGUID
				'12726eae-e786-499b-bd7f-894d887c1cf9', --@UserGUID
				1, --@RepType
				'1e6533d3-ce02-43c9-817c-63771abeb9f5', --@CurGUID
				1.000000, --@CurVal
				'077632d3-b9fc-44b4-9a08-ff9e5e5b6877', --@RawBillSrcs
				'bfae5d2b-6967-447b-bcea-8767b4bbb00c', --@ReadyBillSrcs
				'00000000-0000-0000-0000-000000000000', --@RawAccGUID
				'00000000-0000-0000-0000-000000000000'--@ReadyAccGUID
*/
#############################
#END
