########################################
## prcDistGetTemplatesOfDistributor
CREATE PROCEDURE prcDistGetTemplatesOfDistributor
	@PalmUserName NVARCHAR(250) 
AS   
	SET NOCOUNT ON                 
	DECLARE @ProfileGUID  	UNIQUEIDENTIFIER   
	DECLARE @StoreGUID 	UNIQUEIDENTIFIER   
	DECLARE @CostGUID	UNIQUEIDENTIFIER   
	SELECT @ProfileGUID = GUID, @StoreGUID = StoreGUID FROM Distributor000 WHERE PalmUserName = @PalmUserName   
	SELECT @CostGuid = CostGuid 
	FROM DistSalesman000	AS Ds
		INNER JOIN Distributor000 AS d ON (d.CurrSaleMan = 1 AND d.PrimSalesManGuid = ds.GUID)  OR (d.CurrSaleMan = 1 AND d.AssisSalesManGuid = ds.GUID)
	WHERE d.Guid = @ProfileGUID

	CREATE TABLE #TemplateTbl(         
		Type int,          
		[ID] uniqueidentifier,         
		[Name] NVARCHAR(255)  COLLATE Arabic_CI_AI,         
		LatinName NVARCHAR(255)  COLLATE Arabic_CI_AI,         
		bIsOutput int,   
		DefPrice int, 
		[bPrintReceipt] [int], 
		[GenEntry] [int], 
		[PostToStock] [int] 
	)                 
	   
	INSERT INTO  #TemplateTbl   
		SELECT   
			1 ,   
			bt.btGUID AS ID,   
			bt.btName,   
			bt.btLatinName,      
			bt.btIsOutput,   
			bt.btDefPrice, 
			[bt].[btPrintReceipt], 
			CASE [bt].[btNoEntry] WHEN 1 THEN 0 ELSE 1 END, 
			CASE [bt].[btNoPost] WHEN 1 THEN 0 ELSE 1 END 
		FROM          
			vwBt AS bt INNER JOIN DistDD000 AS dd ON bt.btGUID = dd.ObjectGUID 
		WHERE                  
			bt.btType =  1 AND   
			dd.ObjectType = 1 AND 
			dd.DistributorGUID = @ProfileGUID   
	    
	INSERT INTO  #TemplateTbl            
		SELECT         
			2,         
			et.etGUID AS ID,         
			et.etName,       
			et.etLatinName,      
			0,   
			0, 
			0, 
			0, 
			0 
		FROM          
			vwEt AS et INNER JOIN DistDD000 AS pd ON et.etGUID = pd.ObjectGUID 
		WHERE                  
			pd.ObjectType = 2 AND 
			pd.DistributorGUID = @ProfileGUID 
	INSERT INTO PalmGUID   
	SELECT DISTINCT   
		tm.ID   
	FROM   
		#TemplateTbl AS tm LEFT JOIN PalmGUID AS pg ON pg.GUID = tm.ID 
	WHERE   
		pg.GUID IS NULL 
	-- result 1 
	SELECT    
		Type,   
		pg.Number AS ID,   
		[Name],   
		LatinName,   
		bIsOutput,   
		DefPrice, 
		[bPrintReceipt], 
		[GenEntry], 
		[PostToStock] 
	 FROM    
		#TemplateTbl AS tm    
		INNER JOIN PalmGUID as pg ON pg.GUID = tm.ID    
	ORDER BY Type ASC, bIsOutput DESC, Name ASC   
	-- Result 2 -- Options 
	declare @CurMonthlyPeriod uniqueidentifier 
	declare @StartDate datetime 
	declare @EndDate datetime 
	DECLARE @Target float 
	DECLARE @Realized float 
	SET @CurMonthlyPeriod = 0x0 
	SELECT @CurMonthlyPeriod = ISNULL(CAST(Value AS uniqueidentifier), 0x0) FROM Op000 WHERE Name = 'DistCfg_Coverage_CurMonthlyPeriod' 
	SELECT @StartDate = StartDate, @EndDate = EndDate FROM BDP000 WHERE GUID = @CurMonthlyPeriod 
	 
	SELECT @Target = ISNULL(GeneralTargetVal, 0) FROM DistDistributorTarget000 WHERE PeriodGUID = @CurMonthlyPeriod AND DistGUID = @ProfileGUID 

	SELECT @Realized = SUM(ISNULL(butotal, 0)) + SUM(ISNULL(butotalExtra, 0)) - SUM(ISNULL(butotalDisc, 0))
	FROM vwBu 
	WHERE 
		-- buStorePtr = @StoreGUID AND 
		buCostPtr = @CostGuid	AND
		buDate Between @StartDate  AND @EndDate 
		AND buDirection = -1	

	SET @Target = ISNULL(@Target, 0) 
	SET @Realized = ISNULL(@Realized, 0) 
	SELECT TOP 1  
		*,  
		@StartDate AS TargetFromDate,  
		@EndDate AS TargetToDate,  
		@Target AS Target,  
		@Realized AS Realized,  
		ItemDiscType,  
		CAST(DATEPART(Day, GetDate()) AS NVARCHAR(2)) + '-' +  CAST(DATEPART(Month, GetDate()) AS NVARCHAR(2)) + '-' + Cast(DAtepart(Year, GetDate()) AS NVARCHAR(4)) + '-' + Cast(DATEPART(Hour, GetDate()) AS NVARCHAR(4)) AS SyncDate 
	FROM Distributor000 WHERE PalmUserName = @PalmUserName 
	DROP TABLE #TemplateTbl   

-- EXEC prcDistGetTemplatesOfDistributor 'Palm'
#############################
#END
