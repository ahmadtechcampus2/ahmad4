########################################################################
CREATE PROC repAssetOperations
		@GrpGUID UNIQUEIDENTIFIER,
		@AssGUID UNIQUEIDENTIFIER,
		@AssetDetailGUID UNIQUEIDENTIFIER,
		@StartDate DATETIME,
		@EndDate DATETIME,
		@Type INT,
		@CurGuid UNIQUEIDENTIFIER,
		@CurVal FLOAT
AS
	SET NOCOUNT ON
	CREATE TABLE #Mat ( mtGUID UNIQUEIDENTIFIER, mtSecurity INT)   
	INSERT INTO #Mat EXEC prcGetMatsList  NULL, @GrpGUID  
	
	SELECT 		
		ax.axNumber,
		ax.axType,
		ax.axGUID,
		ax.axAssDetailGUID,
		ad.adSN, 
		ax.axAccGuid,
		mat.mtCode,
		mat.mtName,
		ax.axNotes, 
		ax.axSpec, 
		([ax].[axValue]* [ax].[axCurrencyVal]) * [dbo].[fnCurrency_fix]( 1, [ax].[axCurrencyGUID], [ax].[axCurrencyVal], @CurGuid, [ax].[axDate]) AS axValue, 
		ax.axCurrencyGUID, 
		ax.axCurrencyVal, 
		ax.axDate, 
		ax.axEntryGUID, 
		ax.axEntryNum, 
		ax.axEntryDate, 
		ax.axSecurity
		--select * from vwas
	FROM 
		vwAX AS ax INNER JOIN vwAd AS ad 
		ON ax.axAssDetailGUID = ad.adGUID
		INNER JOIN vwAs AS ass 
		ON ad.adAssGuid = ass.asGUID
		INNER JOIN #Mat AS mt
		ON ass.asParentGuid = mt.mtGUID
		INNER JOIN vwMt AS mat
		ON mt.mtGUID = mat.mtGUID		
	WHERE
		ax.axDate BETWEEN @StartDate AND @EndDate
		AND (@AssGUID = 0x0 OR mat.mtGUID = @AssGUID)
		AND (@AssetDetailGUID = 0x0 OR ad.adGUID = @AssetDetailGUID)
		AND(  ( @Type & 1 = 1 AND ax.axType = 0)
		    OR( @Type & 2 = 2 AND ax.axType = 1)
		    OR( @Type & 4 = 4 AND ax.axType = 2))
	ORDER BY
		ass.asGUID, 
		ad.adGUID, 
		ax.axDate
###################################################################333
#END
