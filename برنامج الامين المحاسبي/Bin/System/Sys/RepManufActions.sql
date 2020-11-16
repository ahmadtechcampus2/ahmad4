###########################################################
###RepManufActions 
###########################################################
CREATE PROCEDURE RepManufActions
/*	'1/1/2007', --@StartDate 
	'1/1/2009', --@EndDate  
	'00000000-0000-0000-0000-000000000000', --@FormGUID 
	'00000000-0000-0000-0000-000000000000', --@CostGUID 
	'8D856AC7-4DC3-484A-87F3-1B881B2F068A', --@CurrencyGUID 
	1.000000, --@CurrencyVal 
	'A8FEFC60-3961-4D97-B554-5DF3F70779E8', --@UserId 
	1 --@ShowDetail 
*/ 
	@StartDate DATETIME,			--   
	@EndDate DATETIME,				--   
	@FormGUID UNIQUEIDENTIFIER,		--   
	@CostGUID UNIQUEIDENTIFIER,		--   
	@CurrencyGUID UNIQUEIDENTIFIER,	--   
	@CurrencyVal FLOAT,				--   
	@UserId UNIQUEIDENTIFIER,		--  
	@ShowDetail int,					-- 1: Detailed, 0:not Detailed  
	@UsedUnit  int = 1
	--, @x int  
AS   
	SET NOCOUNT ON   
	DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();
	CREATE TABLE #FormTbl(GUID UNIQUEIDENTIFIER, Security INT )	-- StandardMan    
	CREATE TABLE #CostTbl( Guid UNIQUEIDENTIFIER, Security INT)     
	IF (@FormGUID = 0x0)    
		INSERT INTO #FormTbl SELECT fmGUID, fmSecurity FROM vwFm WHERE fmSecurity <= dbo.fnGetUserFormSec(@UserId, 1)   
	ELSE    
		INSERT INTO #FormTbl SELECT fmGUID, fmSecurity FROM vwFm WHERE fmGUID = @FormGUID    
		    
	IF (@CostGUID = 0x0)	    
	BEGIN   
		INSERT INTO #CostTbl SELECT coGUID, coSecurity FROM vwCo   
		INSERT INTO #CostTbl SELECT 0x00, 1   
	END   
	ELSE   
		INSERT INTO #CostTbl		EXEC prcGetCostsList 		@CostGuid  
	   
	CREATE TABLE #Manufacture   
	(   
		ManGUID		uniqueidentifier,   
		FormGUID	uniqueidentifier,   
		Number		int,   
		[Date]		datetime,   
		Qty			float,   
		Unit		float,   
		Total		float,   
		Variation	float,   
		Lot			NVARCHAR(100),   
		ProductionTime float   
	)   
	CREATE TABLE #RawItems   
	(   
		ManGUID			uniqueidentifier,   
		FromGUID		uniqueidentifier,   
		ManQty			float,   
		MatGUID			uniqueidentifier,   
		Number			int,   
		ActualQty		float,   
		ActualPrice		float,   
		StandardQty		float,   
		StandardPrice	float,   
		QtyVariation	float,   
		PriceVariation	float,   
		Variation		float,   
		Unity			int,
	 
	)   
	CREATE TABLE #ProductItems   
	(   
		ManGUID			uniqueidentifier,   
		FromGUID		uniqueidentifier,   
		ManQty			float,   
		MatGUID			uniqueidentifier,   
		Number			int,   
		ActualQty		float,   
		ActualPrice		float,   
		StandardQty		float,   
		StandardPrice	float,   
		QtyVariation	float,   
		PriceVariation	float,   
		Variation		float,   
		Unity			int, 
	)   
	CREATE TABLE #Overheads   
	(   
		ManGUID			uniqueidentifier,   
		FromGUID		uniqueidentifier,   
		ManQty			float,   
		AccountGUID		uniqueidentifier,   
		Number			int,   
		ActualValue		float,   
		StandardValue	float,   
		Variation		float   
	)   
	-- Insert into tables   
	INSERT INTO #Manufacture   
	SELECT   
		mnGUID,   
		mnFormGUID,   
		mnNumber,   
		mnDate,   
		mnQty,   
		mnUnitPrice * mnCurrencyVal / @CurrencyVal,   
		mnTotalPrice * mnCurrencyVal / @CurrencyVal,   
		0				AS Variation,   
		mnLot,   
		mnProductionTime   
	FROM   
		vwMN AS mn   
		INNER JOIN #FormTbl AS fm ON fm.GUID = mn.mnFormGUID   
	WHERE   
		mnType = 1 AND   
		mn.mnDate BETWEEN @StartDate AND @EndDate   
		AND	dbo.fnGetUserManufBrowswSec(@UserId, 1) >= mnSecurity AND   
		(mn.mnOutCost IN (SELECT GUID FROM #CostTbl) OR   
		mn.mnInCost IN (SELECT GUID FROM #CostTbl))   
		   
	   
	INSERT INTO #RawItems   
	SELECT   
		mnGUID,   
		mnFormGUID,   
		mnQty,   
		miMatGUID,   
		MIN(miNumber),   
		Sum(miQty * mtDefUnitFact),   
		Sum((miPrice * miCurrencyVal / @CurrencyVal)) / mtDefUnitFact,   
		0,   
		0,   
		0,   
		0,   
		0,   
		1
	FROM   
		vwMnMiMt AS mi   
		INNER JOIN #Manufacture AS mn ON mn.ManGUID = mi.mnGUID   
	WHERE   
		mi.miType = 1   
	GROUP BY   
		mi.mnGUID,   
		mi.mnFormGUID,   
		mi.mnQty,   
		mi.miMatGUID,
		mi.mtDefUnitFact
	   
		   
	UPDATE #RawItems   
	SET   
		StandardQty = st.miQty * ac.ManQty,   
		StandardPrice = st.miPrice,   
		Unity = st.ShowInUnit   
	FROM   
		#RawItems AS ac, (SELECT mnFormGUID, miMatGUID, Sum(miQty * mtDefUnitFact) AS miQty, Sum((miPrice * miCurrencyVal / @CurrencyVal) / miUnitFact * miQty) / sum(miQty) AS miPrice, Min(miUnity) AS ShowInUnit FROM vwMnMiMt  WHERE mnType = 0 GROUP BY mnFormGUID, miMatGUID) AS st   
		WHERE   
			ac.FromGUID = st.MnFormGUID AND   
			ac.MatGUID = st.miMatGUID   
	--------------------------------------------- *****  
	--UPDATE #RawItems  
	--SET   
	--	ActualPrice = bi.Price  
	--FROM   
	--	#RawItems AS ac  
	--	INNER JOIN MB000 AS mb ON mb.ManGUID = ac.ManGUID AND Type = 0  
	--	INNER JOIN BU000 AS bu ON bu.GUID = mb.BillGUID  
	--	INNER JOIN Bi000 AS bi ON bi.ParentGUID = bu.GUID AND bi.MatGUID = ac.MatGUID  
	---------------------------------------------  
	--SELECT * FROM #RawItems   
	UPDATE #RawItems   
	SET   
		QtyVariation	= StandardPrice * (ActualQty - StandardQty),    
		PriceVariation	= ActualQty * (ActualPrice - StandardPrice),   
		Variation = ((ActualQty - StandardQty) * StandardPrice)+(ActualQty*(ActualPrice - StandardPrice))   
			   
	   
	INSERT INTO #ProductItems   
	SELECT   
		mnGUID,   
		mnFormGUID,   
		mnQty,   
		miMatGUID,   
		MIN(miNumber),   
		Sum(miQty * mtDefUnitFact), 
		Sum((miPrice * miCurrencyVal / @CurrencyVal) / miUnitFact * miQty) / sum(miQty),   
		0,   
		0,   
		0,   
		0,   
		0,   
		1 
	FROM   
		vwMnMiMt AS mi   
		INNER JOIN #Manufacture AS mn ON mn.ManGUID = mi.mnGUID   
	WHERE   
		mi.miType = 0   
	GROUP BY   
		mi.mnGUID,   
		mi.mnFormGUID,   
		mi.mnQty,   
		mi.miMatGUID   
	  
	 	UPDATE #ProductItems   
	 	set Unity = mi.miUnity
	 	from vwMnMiMt AS mi 
	 	where mi.mnGUID = ManGUID
	 	and mi.miMatGUID = MatGUID 
	 	
	 	
	  
	UPDATE #ProductItems   
	SET   
		StandardQty = st.miQty * ac.ManQty,   
		StandardPrice = st.miPrice   
	FROM   
		#ProductItems AS ac, (SELECT mnFormGUID, miMatGUID, Sum(miQty * mtDefUnitFact) AS miQty, Sum((miPrice * miCurrencyVal / @CurrencyVal) / miUnitFact * miQty) / sum(miQty) AS miPrice FROM vwMnMiMt  WHERE mnType = 0 GROUP BY mnFormGUID, miMatGUID) AS st   
		WHERE   
			ac.FromGUID = st.MnFormGUID AND   
			ac.MatGUID = st.miMatGUID   
	   
	UPDATE #ProductItems   
	SET   
		QtyVariation	= StandardPrice * (ActualQty - StandardQty),  
		PriceVariation	= ActualQty * (ActualPrice - StandardPrice),   
		Variation = ((ActualQty - StandardQty) * StandardPrice)+(ActualQty*(ActualPrice - StandardPrice))   
	   
	   
	   
	INSERT INTO #Overheads   
	SELECT   
		mnGUID,   
		mnFormGUID,   
		mnQty,   
		mxAccountGUID,   
		Min(mxNumber),   
		Sum((mxExtra * mxCurrencyVal / @CurrencyVal)),   
		0,   
		0   
	FROM   
		vwMnMxAc AS mx   
		INNER JOIN #Manufacture AS mn ON mn.ManGUID = mx.mnGUID   
	GROUP BY   
		mnGUID,   
		mnFormGUID,   
		mnQty,   
		mxAccountGUID   
	   
	   
	UPDATE #Overheads   
	SET   
		StandardValue = st.mxUnitExtra * ov.manQty + st.mxTotalExtra   
	FROM   
		#Overheads AS ov, (SELECT mnFormGUID, mxAccountGUID, Sum(case mxType WHEN 0 THEN (mxExtra * mxCurrencyVal / @CurrencyVal) WHEN 1 THEN 0 END) AS mxUnitExtra, Sum(case mxType WHEN 1 THEN (mxExtra * mxCurrencyVal / @CurrencyVal) WHEN 0 THEN 0 END) AS mxTotalExtra FROM vwMnMxAc  WHERE mnType = 0 GROUP BY mnFormGUID, mxAccountGUID) AS st   
		WHERE   
			ov.FromGUID = st.MnFormGUID AND   
			ov.AccountGUID = st.mxAccountGUID   
		   
	UPDATE #Overheads   
	SET   
		Variation = ActualValue - StandardValue   
	   
	UPDATE #Manufacture   
	SET   
		Variation = r.Variation   
	FROM   
		#Manufacture AS m, (SELECT ManGUID, SUM(Variation) AS Variation FROM #RawItems GROUP BY ManGUID) AS r   
	WHERE   
		m.ManGUID = r.ManGUID   
	UPDATE #Manufacture   
	SET   
		Variation = m.Variation + i.Variation   
	FROM   
		#Manufacture AS m, (SELECT ManGUID, SUM(Variation) AS Variation FROM #Overheads GROUP BY ManGUID) AS i   
	WHERE   
		m.ManGUID = i.ManGUID   
		DECLARE @t TAble   
		(   
			ManGUID			uniqueidentifier,   
			MatGUID			uniqueidentifier,			   
			--Code			NVARCHAR(100),   
			Name			NVARCHAR(250),   
			ActualQty		float,   
			ActualPrice		float,   
			StandardQty		float,   
			StandardPrice	float,   
			QtyVariation	float,   
			PriceVariation	float,   
			Variation		float,   
			Unity			NVARCHAR(100)   
		)   
		INSERT INTO @t   
		SELECT   
			m.ManGUID,   
			mt.GUID		AS MatGUID,   
			--mt.Code,   
			CASE WHEN @lang > 0 THEn CASE WHEN mt.LatinName ='' THEN  mt.Name ELSE mt.LatinName END ELSE mt.Name END AS Name,   
			isNULL (i.ActualQty /  NULLIF((case @UsedUnit WHEN 0 THEN CASE mt.DefUnit  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact WHEN 4 THEN CASE i.Unity  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END END),0),i.ActualQty) AS ActualQty,   
			ISNULL(i.ActualPrice * NULLIF(case @UsedUnit WHEN 0 THEN CASE mt.DefUnit  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact WHEN 4 THEN  CASE i.Unity  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END END, 0), i.ActualPrice) as ActualPrice,   
			isNULL (i.StandardQty /  NULLIF((case @UsedUnit WHEN 0 THEN CASE mt.DefUnit  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact WHEN 4  THEN  CASE i.Unity  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END END),0),i.StandardQty) AS StandardQty,   
			ISNULL(i.StandardPrice * NULLIF(case @UsedUnit WHEN 0 THEN CASE mt.DefUnit  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact  WHEN 4 THEN CASE i.Unity WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END END, 0), i.StandardPrice) as StandardPrice,   
			isNULL (i.QtyVariation /  NULLIF((case @UsedUnit WHEN 0 THEN CASE mt.DefUnit  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact WHEN 4 THEN  CASE i.Unity  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END END),0),i.QtyVariation) AS QtyVariation,   
			ISNULL(i.PriceVariation * NULLIF(case @UsedUnit WHEN 0 THEN CASE mt.DefUnit  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact WHEN 4 THEN  CASE i.Unity  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END END, 0), i.PriceVariation) as PriceVariation,   
			i.Variation,   
			isnull(NULLIF (case @UsedUnit WHEN 0 THEN CASE mt.DefUnit WHEN 1 THEN mt.Unity WHEN 2 THEN mt.Unit2 WHEN 3 THEN mt.Unit3 END WHEN 1 THEN mt.Unity WHEN 2 THEN mt.Unit2 WHEN 3 THEN mt.Unit3  WHEN 4 THEN  CASE i.Unity  WHEN 1 THEN mt.Unity WHEN 2 THEN mt.Unit2 WHEN 3 THEN mt.Unit3 END END , ''), mt.Unity ) AS Unity   
			FROM    
			#ProductItems AS i   
			INNER JOIN MT000 AS mt ON mt.GUID = i.MatGUID   
			INNER JOIN #Manufacture AS m ON m.ManGUID = i.ManGUID   
		ORDER BY m.[Date], m.ManGUID, i.Number   
	-------------------------------------------------
	UPDATE #Manufacture
	SET 
		Total = t.Total,
		Unit = t.Total / Qty
	FROM 
		(SELECT ManGUID, SUM(ActualPrice * ActualQty) Total FROM @t GROUP BY ManGUID) t
	WHERE #Manufacture.ManGUID = t.ManGUID
	-------------------------------------------------
	-- Return results   
	if (@ShowDetail = 1)   
	begin   
		-- 1 Manufactur   
		SELECT   
			mn.*,   
			fm.Code		AS FormCode,   
			CASE WHEN @lang > 0 THEn CASE WHEN fm.LatinName ='' THEN  fm.Name ELSE fm.LatinName END ELSE fm.Name END AS FormName   
		FROM    
			#Manufacture AS mn   
			INNER JOIN FM000 AS fm ON fm.GUID = mn.FormGUID   
		ORDER BY    
			mn.[Date],   
			mn.ManGUID   
		-- 2 Productions   
		SELECT * FROM @t   
		---- 3 Raw Material  
		--select MatGUID ,ManGuid ,FromGUID 
		--From #RawItems 
		--where MatGUID NOT IN(  
  --                           SELECT MatGUID 
  --                             FROM MI000 
  --                             WHERE ParentGUID 
  --                                   =  
  --                                   (  
  --                           SELECT GUID 
  --                             FROM MN000 
  --                             WHERE FormGUID 
  --                                   =  
  --                                   FromGUID 
  --                               AND type = 0 
  --                                   ) 
  --                         ) 
                            
		update #RawItems 
		set StandardQty = ManQty * dbo.fnGetAltMatQty(MatGUID,ManGUID ,FromGUID) 
		, StandardPrice = dbo.fnGetAltMatPrice(MatGUID) 
		,PriceVariation = ActualQty * (ActualPrice - dbo.fnGetAltMatPrice(MatGUID))  
		,QtyVariation   = dbo.fnGetAltMatPrice(MatGUID) * (ActualQty - ManQty * dbo.fnGetAltMatQty(MatGUID,ManGUID ,FromGUID)) 
		,Variation = (dbo.fnGetAltMatPrice(MatGUID) * (ActualQty - ManQty * dbo.fnGetAltMatQty(MatGUID,ManGUID ,FromGUID))) + (ActualQty * (ActualPrice - dbo.fnGetAltMatPrice(MatGUID)))
		where MatGUID NOT IN(  
                             SELECT MatGUID 
                               FROM MI000 
                               WHERE ParentGUID 
                                     =  
                                     (  
                             SELECT GUID 
                               FROM MN000 
                               WHERE FormGUID 
                                     =  
                                     FromGUID 
                                 AND type = 0 
                                     ) 
                           ) 
      
		SELECT   
			m.ManGUID,   
			mt.GUID		AS MatGUID,   
			mt.Code,   
			CASE WHEN @lang > 0 THEn CASE WHEN mt.LatinName ='' THEN  mt.Name ELSE mt.LatinName END ELSE mt.Name END AS Name,   
			isNULL (i.ActualQty / NULLIF((case @UsedUnit WHEN 0 THEN CASE mt.DefUnit  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact WHEN 4 THEN CASE i.Unity  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END END),0),i.ActualQty) AS ActualQty,   
			isNULL (i.StandardQty / NULLIF((case @UsedUnit WHEN 0 THEN CASE mt.DefUnit  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact WHEN 4 THEN CASE i.Unity  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END END),0),i.StandardQty) AS StandardQty,   
			ISNULL(i.ActualPrice * NULLIF((case @UsedUnit WHEN 0 THEN CASE mt.DefUnit  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact WHEN 4 THEN CASE i.Unity  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END END), 0), i.ActualPrice) as ActualPrice,   
			ISNULL(i.StandardPrice * NULLIF((case @UsedUnit WHEN 0 THEN CASE mt.DefUnit  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact WHEN 4 THEN CASE i.Unity  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END END), 0), i.StandardPrice) as StandardPrice,   
			isNULL (i.QtyVariation /NULLIF ((case @UsedUnit WHEN 0 THEN CASE mt.DefUnit  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact WHEN 4 THEN CASE i.Unity  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END END),0),i.QtyVariation) AS QtyVariation,   
			ISNULL(i.PriceVariation * NULLIF(case @UsedUnit WHEN 0 THEN CASE mt.DefUnit  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact WHEN 4 THEN CASE i.Unity  WHEN 1 THEN 1 WHEN 2 THEN mt.Unit2Fact WHEN 3 THEN mt.Unit3Fact END END, 0), i.PriceVariation) as PriceVariation,   
			i.Variation,   
			isnull(NULLIF (case @UsedUnit WHEN 0 THEN CASE mt.DefUnit WHEN 1 THEN mt.Unity WHEN 2 THEN mt.Unit2 WHEN 3 THEN mt.Unit3 END WHEN 1 THEN mt.Unity WHEN 2 THEN mt.Unit2 WHEN 3 THEN mt.Unit3  WHEN 4 THEN  CASE i.Unity  WHEN 1 THEN mt.Unity WHEN 2 THEN mt.Unit2 WHEN 3 THEN mt.Unit3 END END , ''), mt.Unity ) AS Unity   
		FROM    
			#RawItems AS i   
			INNER JOIN MT000 AS mt ON mt.GUID = i.MatGUID   
			INNER JOIN #Manufacture AS m ON m.ManGUID = i.ManGUID   
		ORDER BY m.[Date], m.ManGUID, i.Number   
		-- 4 OverHeads   
		SELECT   
			m.ManGUID,   
			ac.GUID		As AccountGUID,   
			ac.Code,   
			CASE WHEN @lang > 0 THEn CASE WHEN ac.LatinName ='' THEN  ac.Name ELSE ac.LatinName END ELSE ac.Name END AS Name,   
			o.ActualValue,   
			o.StandardValue,   
			o.Variation   
		FROM    
			#Overheads AS o   
			INNER JOIN AC000 AS ac ON ac.GUID = o.AccountGUID   
			INNER JOIN #Manufacture AS m ON m.ManGUID = o.ManGUID   
		ORDER BY m.[Date], m.ManGUID, o.Number   
	end   
	else   
	-- @ShowDetail = 0   
	begin   
		-- 1 Manufactur   
		SELECT   
			mn.*,   
			fm.Code		AS FormCode,   
			CASE WHEN @lang > 0 THEn CASE WHEN fm.LatinName ='' THEN  fm.Name ELSE fm.LatinName END ELSE fm.Name END AS FormName   
		FROM    
			#Manufacture AS mn   
			INNER JOIN FM000 AS fm ON fm.GUID = mn.FormGUID   
		ORDER BY    
			mn.[Date],   
			mn.Number   
			--mn.ManGUID   
	end   
###########################################################
#END
