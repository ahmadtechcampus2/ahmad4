###############################################
## repManufDev
## ÇäÍÑÇÝ ÊßÇáíÝ ÇáÊÕäíÚ
CREATE PROCEDURE repManufDev
	--@x int,
	@StartDate DATETIME,			-- 
	@EndDate DATETIME,				-- 
	@FormGUID UNIQUEIDENTIFIER,		-- 
	@CostGUID UNIQUEIDENTIFIER,		-- 
	@CurrencyGUID UNIQUEIDENTIFIER,	-- 
	@CurrencyVal FLOAT,				-- 
	@UserId UNIQUEIDENTIFIER,		-- 
	@RepType INT					-- 
AS    
SET NOCOUNT ON

DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();

CREATE TABLE #FormTbl(GUID UNIQUEIDENTIFIER, Security INT )	-- StandardMan 
CREATE TABLE #CostTbl( Guid UNIQUEIDENTIFIER, Security INT)  
IF (@FormGUID = 0x0) 
	INSERT INTO #FormTbl SELECT fmGUID, fmSecurity FROM vwFm 
ELSE 
	INSERT INTO #FormTbl SELECT fmGUID, fmSecurity FROM vwFm WHERE fmGUID = @FormGUID 
	 
IF (@CostGUID = 0x0)	 
BEGIN 
	INSERT INTO #CostTbl SELECT coGUID, coSecurity FROM vwCo 
	INSERT INTO #CostTbl SELECT 0x00, 1 
END 
else
	INSERT INTO #CostTbl		EXEC prcGetCostsList 		@CostGuid  
CREATE TABLE #Result	  
	(	   
		GUID		UNIQUEIDENTIFIER, 
		mtSecurity	int, 
		acSecurity	int, 
		StandardVal	FLOAT, 
		VirtualVal	FLOAT,
		ValueDifference	FLOAT
	)  
CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT])   
CREATE TABLE #MiQuantity 
				(	   
					mnGUID UNIQUEIDENTIFIER, 
					mnFormGUID UNIQUEIDENTIFIER, 
					miType INT, 
					miMatGUID UNIQUEIDENTIFIER, 
					mnQty FLOAT, 
					miQty FLOAT, 
					miStandardQty FLOAT 
				)  
CREATE TABLE #MxValues 
				(	   
					mnGUID UNIQUEIDENTIFIER, 
					mnFormGUID UNIQUEIDENTIFIER, 
					mxType INT, 
					mxAccountGUID UNIQUEIDENTIFIER, 
					mnQty FLOAT, 
					mxValue FLOAT, 
					mxStandardValue FLOAT 
				)  
------------------ RepType = 1 OR RepType = 0 ----------- 
IF (@RepType = 0 OR @RepType = 1) 
BEGIN 
	DECLARE  
		@mnGUID UNIQUEIDENTIFIER, 
		@mnFormGUID UNIQUEIDENTIFIER, 
		@miType INT, 
		@miMatGUID UNIQUEIDENTIFIER, 
		@mnQty FLOAT, 
		@miQty FLOAT 
	 
	DECLARE mi_Cursor CURSOR FOR 
	SELECT 
		mi.mnGUID, 
		mi.mnFormGUID, 
		mi.miType, 
		mi.miMatGUID, 
		mi.mnQty, 
		Sum(mi.miQTY) AS miQty	 
	FROM 
		vwMnMiMt AS mi 
			INNER JOIN #FormTbl as fm 
			ON fm.GUID = mi.mnFormGUID 
				INNER JOIN #CostTbl AS co  
				ON mi.miCostGUID = co.GUID 
	WHERE 
		mi.mnType = 1 AND 
		mi.miType = @RepType AND 
		mi.mnDate BETWEEN @StartDate AND @EnDDate 
	GROUP BY 
		mi.mnGUID, 
		mi.mnFormGUID, 
		mi.miType, 
		mi.miMatGUID, 
		mi.mnQty 
--------------------------------------
	/*
	SELECT 
		mi.mnGUID, 
		mi.mnFormGUID, 
		mi.miType, 
		mi.miMatGUID, 
		mi.mnQty, 
		Sum(mi.miQTY) AS miQty	 
	FROM 
		vwMnMiMt AS mi 
			INNER JOIN #FormTbl as fm 
			ON fm.GUID = mi.mnFormGUID 
				INNER JOIN #CostTbl AS co  
				ON mi.miCostGUID = co.GUID 
	WHERE 
		mi.mnType = 1 AND 
		mi.miType = @RepType AND 
		mi.mnDate BETWEEN @StartDate AND @EnDDate 
	GROUP BY 
		mi.mnGUID, 
		mi.mnFormGUID, 
		mi.miType, 
		mi.miMatGUID, 
		mi.mnQty 
	*/
--------------------------------------	
 
	OPEN mi_Cursor 
	 
	FETCH NEXT FROM mi_Cursor 
		INTO 
			@mnGUID, 
			@mnFormGUID, 
			@miType, 
			@miMatGUID, 
			@mnQty, 
			@miQty 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		--------------------------- 
		DECLARE @MiStandardQty FLOAT 
		SET @MiStandardQty = 0.0 
		SELECT  
			@MiStandardQty = SUM(mi.miQty) 
		FROM 
			vwMnMiMt AS mi 
				-- IF COSTGUID to affect Forms 
				INNER JOIN #CostTbl AS co  
				ON mi.miCostGUID = co.GUID 
		WHERE 
			mi.mnType = 0 AND 
			mi.miType = @RepType AND 
			mi.mnFormGUID = @mnFormGUID AND 
			mi.miMatGUID = @miMatGUID 
		GROUP BY 
			mi.mnFormGUID, 
			mi.miType, 
			mi.miMatGUID 
	---------------------------------------------------------------
		/*
		SELECT * FROM #CostTbl
		SELECT  
			--@MiStandardQty = SUM(mi.miQty) 
			*
		FROM 
			vwMnMiMt AS mi 
				-- IF COSTGUID to affect Forms 
				INNER JOIN #CostTbl AS co  
				ON mi.miCostGUID = co.GUID 
		WHERE 
			mi.mnType = 0 AND 
			mi.miType = @RepType AND 
			mi.mnFormGUID = @mnFormGUID AND 
			mi.miMatGUID = @miMatGUID 
		/*
		GROUP BY 
			mi.mnFormGUID, 
			mi.miType, 
			mi.miMatGUID 
		*/
		*/
	---------------------------------------------------------------
		--PRINT @miStandardQty 
		---------------- 
		INSERT INTO #MiQuantity 
			( 
				mnGUID, 
				mnFormGUID, 
				miType, 
				miMatGUID, 
				mnQty, 
				miQty, 
				miStandardQty 
			) 
			VALUES 
			( 
				@mnGUID, 
				@mnFormGUID, 
				@miType, 
				@miMatGUID, 
				@mnQty, 
				@miQty, 
				@miStandardQty * @mnQty 
			) 
		----------------------------------------------------- 2 
			/*
			SELECT 
				@mnGUID, 
				@mnFormGUID, 
				@miType, 
				@miMatGUID, 
				@mnQty, 
				@miQty, 
				@miStandardQty * @mnQty 
			*/
		-------------------------------------------------------
		---------------- 
		---------------------------	 
		FETCH NEXT FROM mi_Cursor 
			INTO 
				@mnGUID, 
				@mnFormGUID, 
				@miType, 
				@miMatGUID, 
				@mnQty, 
				@miQty 
	END 
	CLOSE mi_Cursor 
	DEALLOCATE mi_Cursor 
	----------------------------- 
	INSERT INTO #Result 
		(	   
			GUID, 
			mtSecurity, 
			acSecurity, 
			StandardVal, 
			VirtualVal
		)  
		SELECT 
			miMatGUID AS GUID, 
			0, 
			0, 
			SUM(miStandardQty) AS StandardVal, 
			SUM(miQty) AS VirtualVal
		FROM 
			#MiQuantity 
		GROUP BY 
			miMatGUID 
END -- end if	 
------------------ RepType = 2 -------------------------- 
IF (@RepType = 2) 
BEGIN 
	DECLARE  
		--@mnGUID UNIQUEIDENTIFIER, 
		--@mnFormGUID UNIQUEIDENTIFIER, 
		@mxType INT, 
		@mxAccountGUID UNIQUEIDENTIFIER, 
		--@mnQty FLOAT, 
		@mxValue FLOAT	 
	DECLARE mx_Cursor CURSOR FOR 
	SELECT 
		mx.mnGUID, 
		mx.mnFormGUID, 
		mx.mxType, 
		mx.mxAccountGUID, 
		mx.mnQty, 
		Sum(mx.mxExtra * mx.mxCurrencyVal / @CurrencyVal) AS mxValue	 
	FROM 
		vwMnMxAc AS mx 
			INNER JOIN #FormTbl as fm 
			ON fm.GUID = mx.mnFormGUID 
				INNER JOIN #CostTbl AS co  
				ON mx.mxCostGUID = co.GUID 
	WHERE 
		mx.mnType = 1 AND 
		mx.mnDate BETWEEN @StartDate AND @EnDDate 
	GROUP BY 
		mx.mnGUID, 
		mx.mnFormGUID, 
		mx.mxType, 
		mx.mxAccountGUID, 
		mx.mnQty 
	 
	OPEN mx_Cursor 
	 
	FETCH NEXT FROM mx_Cursor 
		INTO 
			@mnGUID, 
			@mnFormGUID, 
			@mxType, 
			@mxAccountGUID, 
			@mnQty, 
			@mxValue 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		--------------------------- 
		DECLARE @MxStandardValue FLOAT 
		SET @MxStandardValue = 0.0 
		SELECT  
			@MxStandardValue = SUM(mx.mxExtra  * mx.mxCurrencyVal / @CurrencyVal) 
		FROM 
			vwMnMxAc AS mx 
				-- IF COSTGUID to affect Forms 
				INNER JOIN #CostTbl AS co  
				ON mx.mxCostGUID = co.GUID 
		WHERE 
			mx.mnType = 0 AND 
			mx.mnFormGUID = @mnFormGUID AND 
			mx.mxAccountGUID = @mxAccountGUID 
		GROUP BY 
			mx.mnFormGUID, 
			mx.mxType, 
			mx.mxAccountGUID 
		---------------- 
		INSERT INTO #MxValues 
			( 
				mnGUID, 
				mnFormGUID, 
				mxType, 
				mxAccountGUID, 
				mnQty, 
				mxValue, 
				mxStandardValue 
			) 
			VALUES 
			( 
				@mnGUID, 
				@mnFormGUID, 
				@mxType, 
				@mxAccountGUID, 
				@mnQty, 
				@mxValue, 
				@mxStandardValue *(	CASE @mxType 
										WHEN 0 THEN @mnQty 
										WHEN 1 THEN 1		END 
									) 
			) 
		---------------- 
		---------------------------	 
		FETCH NEXT FROM mx_Cursor 
			INTO 
				@mnGUID, 
				@mnFormGUID, 
				@mxType, 
				@mxAccountGUID, 
				@mnQty, 
				@mxValue 
	END 
	CLOSE mx_Cursor 
	DEALLOCATE mx_Cursor 
	----------------------------- 
	INSERT INTO #Result 
		(	   
			GUID, 
			mtSecurity, 
			acSecurity, 
			StandardVal, 
			VirtualVal 
		)  
		SELECT 
			mxAccountGUID AS GUID, 
			0, 
			0, 
			SUM(mxStandardValue) AS StandardVal, 
			SUM(mxValue) AS VirtualVal 
		FROM 
			#MxValues 
		GROUP BY 
			mxAccountGUID 
END -- end if	 
------- return result  
if (@RepType = 0 OR @RepType = 1) 
	UPDATE #Result SET mtSecurity = mt.Security FROM #result AS r, mt000 AS mt WHERE mt.GUID = r.GUID 
if (@RepType = 2) 
	UPDATE #Result SET acSecurity = ac.Security FROM #result AS r, ac000 AS ac WHERE ac.GUID = r.GUID 

UPDATE #Result SET ValueDifference = r.VirtualVal - r.StandardVal FROM #result AS r

EXEC [prcCheckSecurity]   
if @RepType = 2			--Accounts 
	SELECT  
		r.GUID AS GUID, 
		CASE WHEN @Lang > 0 THEN CASE WHEN ac.acLatinName = '' THEN ac.acName ELSE ac.acLatinName END ELSE  ac.acName END AS Name, 
		ac.acCode AS code, 
		r.StandardVal AS StandardVal,  
		r.VirtualVal AS VirtualVal,
		r.ValueDifference
	FROM  
		#Result AS r  
		INNER JOIN vwAc AS ac ON r.GUID = ac.acGUID 
else	--Material 
	SELECT  
		r.GUID AS GUID, 
		CASE WHEN @Lang > 0 THEN CASE WHEN mt.mtLatinName = '' THEN mt.mtName ELSE mt.mtLatinName END ELSE mt.mtName END AS Name, 
		mt.mtCode AS code, 
		mt.mtDefUnitName AS Unity, 
		r.StandardVal AS StandardVal,  
		r.VirtualVal AS VirtualVal,
		r.ValueDifference
	FROM  
		#Result AS r  
		INNER JOIN vwMt AS mt ON r.GUID = mt.mtGUID 


SELECT  (Select ISNULL(SUM(r.StandardVal),0) from #Result r) as StandardValueTotal ,
		(Select ISNULL(SUM(r.VirtualVal),0) from #Result r) as ActualValueTotal,
		(Select ISNULL(SUM(r.ValueDifference),0) from #Result r) as ValueDifferenceTotal ,
		(Select ISNULL(SUM(r.ValueDifference),0) from #Result r where r.ValueDifference>0) as PoditiveDeviationTotal  ,
		(Select ISNULL(SUM(r.ValueDifference),0) from #Result r where r.ValueDifference<0) as NegativeDeviationTotal 
	
-- ÇáÃæáíÉ Úáì ãÑßÒ ßáÝÉ ÇáÎáÑÌ 
-- ÇáÌÇåÒÉ Úáì ÇáÏÎá 
-- ÇáÊßÇáíÝ Úáì ãÑßÒ ßáÝÉ ÇáÊßáÝÉ 
-- åá íÌÈ ÅÚÊãÇÏ ãÑßÒ ßáÝÉ ááäãæÐÌ Ãã ÝÞØ áÚãáíÉ ÇáÊÕäíÚ 
-- ãÇ åí ÇáãæÇÏ ÇáÊí íÌÈ Ãä ÊÙåÑ -- ßá ÇáãæÇÏ ÇáÊí íÍæíåÇ ÇáäãæÐÌ  - Ãã ßá ÇáãæÇÏ ÇáÊí ÊãÊ ÚáíåÇ ÚãáíÇÊ ÇáÊÕäíÚ 
-- 1 ÇáãæÇÏ ÇáÊí æÑÏÊ Ýí ÇáäãæÐÌ æ áã ÊÊã ÚáåÇ ÚãáíÇÊ ÊÕäíÚ áÇ ÍÇÌÉ áäÇ ÈåÇ 
-- 2 íÊã ÃÎÐ ÌãíÚ ÇáãæÇÏ ÇáÊí ÊãÊ ÚáíåÇ ÚãáíÇÊ ÊÕäíÚ æ Ýí ÍÇáÉ áã íßäáåÇ ÌÒÑ Ýí ÇáäãæÐÌ íÊã ÅÙåÇÑ ÇáßãíÉ ÇáÞíÇÓíÉ ÕÝÑ 
-- ãÇ åæ ÇáÚãá Ýí ÍÇáÉ Êã ÅäÌÇÒ ÚãáíÇÊ ÊÕäíÚ Ëã Êã ÊÛííÑ ÇáäãæÐÌ 
-- íÌÈ ÊÌÑíÈå Úáì ÇáæÍÏÇÊ 
-- RepType = 1 >>>> miType = 1 
-- RepType = 0 >>>> miType = 0 
-- RepType = 0 >>>> mxTable And AnyType 
-- Return Qty in Default unit 
##############################
#END