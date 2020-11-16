######################################################
CREATE PROCEDURE PrcAssetMoveTotalsPerYear
	@AssetDetailGuid	UNIQUEIDENTIFIER,
	@StartDate			DATETIME,
	@EndDate			DATETIME,
	@FirstLoop			BIT = 0,
	@CurAdd				FLOAT,
	@CurDed				FLOAT,
	@CurMain			FLOAT,
	@CurDep				FLOAT
AS
BEGIN
	SET NOCOUNT ON;
	
	CREATE TABLE #Result(
		[DatabaseId]		SMALLINT,
		[IsPrev]			BIT,
		[adAddedVal]		FLOAT,
		[adDeductVal]		FLOAT,
		[adDeprectaionVal]	FLOAT, 
		[adMaintainVal]		FLOAT
	)
	
	DECLARE @FirstPrevAdd		 FLOAT
	DECLARE @FirstPrevDed		 FLOAT
	DECLARE @FirstPrevDep		 FLOAT
	DECLARE @FirstPrevMain		 FLOAT

	IF (@FirstLoop = 1)
	BEGIN
		SELECT @FirstPrevAdd = ISNULL(SUM([axValue]),0)
		  FROM vwAx 
	 	 WHERE [axType] = 0 AND [axAssDetailGUID] = @AssetDetailGuid AND [axDate] < @StartDate
			
		SELECT @FirstPrevDed = ISNULL(SUM([axValue]),0)
		  FROM vwAx 
	 	 WHERE [axType] = 1 AND [axAssDetailGUID] = @AssetDetailGuid AND [axDate] < @StartDate
				
		SELECT @FirstPrevMain = ISNULL(SUM([axValue]),0)
		  FROM vwAx 
	 	 WHERE [axType] = 2 AND [axAssDetailGUID] = @AssetDetailGuid AND [axDate] < @StartDate
		
		SELECT @FirstPrevDep = ISNULL(SUM([dd].[ddValue]),0)
		  FROM vwDD AS [dd] INNER JOIN vbDP AS [dp] ON [dp].[GUID] = [dd].[ddParenrtGUID]
	 	 WHERE [dd].[ddADGUID] = @AssetDetailGuid AND [dp].[Date] < @StartDate				
	END
	ELSE
	BEGIN
		SET @FirstPrevAdd = 0
		SET @FirstPrevDed = 0
		SET @FirstPrevMain = 0
		SET @FirstPrevDep = 0 
	END

	INSERT INTO #Result ([IsPrev],[adAddedVal],[adDeductVal],[adDeprectaionVal],[adMaintainVal])
	SELECT	1,
			ISNULL(([ad].[adAddedVal] + @FirstPrevAdd),0),
			ISNULL(([ad].[adDeductVal] + @FirstPrevDed),0),
			ISNULL(([ad].[adDeprecationVal] + @FirstPrevDep),0),
			ISNULL(([ad].[adMaintenVal] + @FirstPrevMain),0)
	  FROM	vwAd AS [ad] 
	 WHERE	[ad].[adGuid] = @AssetDetailGuid

	INSERT INTO #Result ([DatabaseId],[IsPrev],[adAddedVal],[adDeductVal],[adDeprectaionVal],[adMaintainVal])
	SELECT	DB_ID(),
			0,
			ISNULL(@CurAdd,0),
			ISNULL(@CurDed,0),
			ISNULL(@CurDep,0),
			ISNULL(@CurMain,0)
	  FROM  vwAd AS [ad]
	 WHERE	[ad].[adGuid] = @AssetDetailGuid		

	SELECT	DB_NAME(),
			[DatabaseId],
			[IsPrev],
			[adAddedVal],
			[adDeductVal],
			[adDeprectaionVal],
			[adMaintainVal]
	  FROM	#Result

	DROP TABLE #Result
END
######################################################
#END