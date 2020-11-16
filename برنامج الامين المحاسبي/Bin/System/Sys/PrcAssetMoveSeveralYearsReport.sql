######################################################
CREATE PROCEDURE PrcAssetMoveSeveralYearsReport
	@AssetDetailGuid	UNIQUEIDENTIFIER,
	@StartDate			DATETIME,
	@EndDate			DATETIME,
	@SrcsFlag			INT			
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Lang [INT];
	SET @Lang = dbo.fnConnections_GetLanguage();
	
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 

	CREATE TABLE #AssetDetailSecurity([adGuid] UNIQUEIDENTIFIER, [adSecurity]	INT) 

	INSERT INTO #AssetDetailSecurity([adGuid], [adSecurity])
	SELECT @AssetDetailGuid,
		   [ad].[adSecurity]
	  FROM vwAd AS [ad]
	 WHERE [ad].[adGuid] = @AssetDetailGuid
		   AND ([ad].[adInDate] <= @EndDate)

	CREATE TABLE #MasterResult(
		[adGuid]					UNIQUEIDENTIFIER,
		[DatabaseName]				NVARCHAR(256),
		[FromDate]					DATETIME,
		[ToDate]					DATETIME,
		[adInDate]					DATETIME,
		[adInVal]					FLOAT,
		[adTotAddVal]				FLOAT,
		[adTotDedVal]				FLOAT,
		[adTotalVal]				FLOAT,
		[adTotDepVal]				FLOAT,
		[adCurTotalVal]				FLOAT,
		[adTotMainVal]				FLOAT,
		[adScrapVal]				FLOAT,
		[asLifeExp]					FLOAT,  
		[adPurchaseOrder]			NVARCHAR(250),				
		[adModel]					NVARCHAR(250),					
		[adOrigin]					NVARCHAR(250),					
		[adCompany]					NVARCHAR(250),					
		[adManufDate]				DATETIME,				
		[adSupplier]				NVARCHAR(250),				
		[adLKind]					NVARCHAR(250),					
		[adLCNum]					NVARCHAR(250),					
		[adLCDate]					DATETIME,					
		[adImportPermit]			NVARCHAR(250),			
		[adArrvDate]				DATETIME,				
		[adArrvPlace]				NVARCHAR(250),				
		[adCustomStatement]			NVARCHAR(250),			
		[adCustomCost]				NVARCHAR(21),				
		[adCustomDate]				DATETIME,				
		[adContractGuaranty]		NVARCHAR(250),		
		[adContractGuarantyDate]	DATETIME,	
		[adContractGuarantyEndDate]	DATETIME,
		[adJobPolicy]				NVARCHAR(250),				
		[adNotes]					NVARCHAR(250),	
		[adDailyRental]				FLOAT,
		[adSite]					NVARCHAR(250),				
		[adGuarantee]				NVARCHAR(250),				
		[adGuarantyBeginDate]		DATETIME,		
		[adGuarantyEndDate]			DATETIME,			
		[adDepartment]				NVARCHAR(250),				
		[adBarCode]					NVARCHAR(250),
		[adEmployee]				NVARCHAR(250),
		[adPosDate]					DATETIME
	)

	CREATE TABLE #TotalsResult(
		[DatabaseName]		NVARCHAR(256),
		[DatabaseId]		SMALLINT,
		[IsPrev]			BIT,
		[adAddedVal]		FLOAT,
		[adDeductVal]		FLOAT,
		[adDeprectaionVal]	FLOAT,
		[adMaintainVal]		FLOAT
	)

	CREATE TABLE #DetailedResult
	(
		[DatabaseName]		NVARCHAR(256),
		[DatabaseId]		SMALLINT,
		[IsCurYear]			BIT,
		[buGuid]			UNIQUEIDENTIFIER,
		[Type]				INT,
		[TypeName]			NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[Num]				NVARCHAR(250),
		[Date]				DATETIME,
		[Value]				FLOAT,
		[MoveType]			INT,
		[Spec]				NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[StoreName]			NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[CostName]			NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[BranchName]		NVARCHAR(250) COLLATE ARABIC_CI_AI
	)
	
	EXEC [prcCheckAssetSecurity] @result = #AssetDetailSecurity

	IF EXISTS (SELECT (1) FROM #AssetDetailSecurity)
	BEGIN

		DECLARE @DataBaseName		 NVARCHAR(128)
		DECLARE @FirstPeriodDate	 DATETIME
		DECLARE @EndPeriodDate		 DATETIME
		DECLARE @firstLoop			 BIT
		DECLARE @Query				 NVARCHAR(300)
		DECLARE @PrevAdd			 FLOAT
		DECLARE @PrevDed			 FLOAT
		DECLARE @PrevDep			 FLOAT
		DECLARE @PrevMain			 FLOAT
		DECLARE @CurAdd				 FLOAT
		DECLARE @CurDed				 FLOAT
		DECLARE @CurDep				 FLOAT
		DECLARE @CurMain			 FLOAT
	
	
		DECLARE AllDatabases CURSOR FOR				 
		SELECT  [DatabaseName], [FirstPeriod], [EndPeriod] FROM FnGetReportDataSources(@StartDate, @EndDate) ORDER BY [FirstPeriod]
		OPEN AllDatabases;	    
		SET @firstLoop   = 1;
		FETCH NEXT FROM AllDatabases INTO @DataBaseName, @FirstPeriodDate, @EndPeriodDate;
		WHILE (@@FETCH_STATUS = 0)
		BEGIN  
	
			-- Set User Admin
			IF(@DataBaseName <> DB_NAME())
			BEGIN
			 DECLARE @SetUserAdmin  NVARCHAR(MAX) ='EXEC [' + @DataBaseName + '].[dbo].[NSPrcConnectionsAddAdmin]';
			 EXEC sp_executesql @SetUserAdmin;
			END
				
			-- Check Date
			IF (@FirstPeriodDate < @StartDate) 
			BEGIN
				SET @FirstPeriodDate = @StartDate;
			END

			IF (@EndPeriodDate > @EndDate)
			BEGIN
				SET @EndPeriodDate = @EndDate;
			END 
			--Detailed Result
			
			SET @Query = N'INSERT INTO #DetailedResult EXEC ['+@DataBaseName+'].[dbo].[PrcAssetMoveDetailsPerYear] '''+ CONVERT(NVARCHAR(38),@AssetDetailGuid)
				+''','''+CONVERT(NVARCHAR(38),@FirstPeriodDate)+''','''+CONVERT(NVARCHAR(38),@EndPeriodDate)
				+''','+CONVERT(NVARCHAR(38),@SrcsFlag);
	
			EXEC sp_executesql @Query;
			
			UPDATE #DetailedResult 
			   SET [IsCurYear] = 1
			 WHERE [DatabaseName] = DB_NAME()

			-- Total Details Result
	
			SELECT @CurAdd = SUM([Value]) 
			  FROM #DetailedResult 
			 WHERE [DatabaseName] = @DataBaseName AND [Type] = 0x004;
	
			SELECT @CurDed = SUM([Value]) 
			  FROM #DetailedResult 
			 WHERE [DatabaseName] = @DataBaseName AND [Type] = 0x008;
	
	 		SELECT @CurMain = SUM([Value]) 
			  FROM #DetailedResult 
			 WHERE [DatabaseName] = @DataBaseName AND [Type] = 0x010;
	
	 		SELECT @CurDep = SUM([Value]) 
			  FROM #DetailedResult 
			 WHERE [DatabaseName] = @DataBaseName AND [Type] = 0x002;
	
			SET @Query = N'INSERT INTO #TotalsResult 
						   EXEC ['+@DataBaseName+'].[dbo].[PrcAssetMoveTotalsPerYear] '''+CONVERT(NVARCHAR(38),@AssetDetailGuid)+''','''
						   +CONVERT(NVARCHAR(38),@FirstPeriodDate)+''','''+CONVERT(NVARCHAR(38),@EndPeriodDate)+''','+CONVERT(NVARCHAR(1),@firstLoop)+','
						   +CONVERT(VARCHAR(50),ISNULL(@CurAdd,0))+','+CONVERT(VARCHAR(50),ISNULL(@CurDed,0))+','+CONVERT(VARCHAR(50),ISNULL(@CurMain,0))+','
						   +CONVERT(VARCHAR(50),ISNULL(@CurDep,0));
			
			EXEC sp_executesql @Query;
		
			-- Master Result 
	
			SELECT @PrevAdd = [adAddedVal] 
			  FROM #TotalsResult 
			 WHERE [DatabaseName] = @DataBaseName AND [IsPrev] = 1;
	
			SELECT @PrevDed = [adDeductVal] 
			  FROM #TotalsResult 
			 WHERE [DatabaseName] = @DataBaseName AND [IsPrev] = 1;
	
	 		SELECT @PrevMain = [adMaintainVal] 
			  FROM #TotalsResult 
			 WHERE [DatabaseName] = @DataBaseName AND [IsPrev] = 1;
	
	 		SELECT @PrevDep = [adDeprectaionVal] 
			  FROM #TotalsResult 
			 WHERE [DatabaseName] = @DataBaseName AND [IsPrev] = 1;
	
			SET @Query = N'INSERT INTO #MasterResult
						   EXEC ['+@DataBaseName+'].[dbo].[PrcAssetMoveMasterPerYear] '''+CONVERT(NVARCHAR(38),@AssetDetailGuid)+''','''
						   +CONVERT(NVARCHAR(38),@FirstPeriodDate)+''','''+CONVERT(NVARCHAR(38),@EndPeriodDate)+''','+CONVERT(VARCHAR(50),@PrevAdd)+','
						   +CONVERT(VARCHAR(50),@PrevDed)+','+CONVERT(VARCHAR(50),@PrevMain)+','+CONVERT(VARCHAR(50),@PrevDep)+','
						   +CONVERT(VARCHAR(50),ISNULL(@CurAdd,0))+','+CONVERT(VARCHAR(50),ISNULL(@CurDed,0))+','+CONVERT(VARCHAR(50),ISNULL(@CurMain,0))+','
						   +CONVERT(VARCHAR(50),ISNULL(@CurDep,0));
	
			EXEC sp_executesql @Query;
		
			FETCH NEXT FROM AllDatabases INTO  @DataBaseName, @FirstPeriodDate, @EndPeriodDate;
			SET @firstLoop = 0;
		END
		CLOSE      AllDatabases;
		DEALLOCATE AllDatabases;
  
	END

--------- Final Result ---------	
					
	SELECT  [DatabaseName],	
			[FromDate],
			[ToDate],
			[adInDate],
			[adInVal],
			[adTotAddVal],
			[adTotDedVal],
			[adTotalVal],
			[adTotDepVal],
			[adCurTotalVal],
			[adTotMainVal],
			[adScrapVal],
			[asLifeExp],
			[adPurchaseOrder],			
			[adModel],					
			[adOrigin],					
			[adCompany],					
			[adManufDate],				
			[adSupplier],				
			[adLKind],					
			[adLCNum],					
			[adLCDate],					
			[adImportPermit],			
			[adArrvDate],				
			[adArrvPlace],				
			[adCustomStatement],			
			[adCustomCost],				
			[adCustomDate],				
			[adContractGuaranty],		
			[adContractGuarantyDate],	
			[adContractGuarantyEndDate],
			[adJobPolicy],				
			[adNotes],					
			[adDailyRental],
			[adSite],				
			[adGuarantee],				
			[adGuarantyBeginDate],		
			[adGuarantyEndDate],			
			[adDepartment],				
			[adBarCode],
			[adEmployee], 
			[adPosDate]						
	  FROM  #MasterResult
	 ORDER BY [FromDate] 
	
	SELECT [DatabaseName],
		   [DatabaseId],		
		   [IsPrev],			
		   [adAddedVal],		
		   [adDeductVal],		
		   [adDeprectaionVal],	
		   [adMaintainVal]		
	  FROM #TotalsResult

	SELECT [DatabaseName],
		   [DatabaseId],
		   ISNULL([IsCurYear],0) AS [IsCurYear],
		   [buGuid],	
		   [Type],
		   [TypeName],		
		   [Num],		
		   [Date],		
		   ISNULL([Value],0)	AS [Value],		
		   ISNULL([MoveType],0) AS [MoveType],	
		   [Spec],		
		   [StoreName],
		   [CostName],
		   [BranchName]
	 FROM  #DetailedResult
	 ORDER BY [Date], [MoveType]

	 DROP TABLE #MasterResult
	 DROP TABLE #TotalsResult
	 DROP TABLE #DetailedResult

END
######################################################
#END