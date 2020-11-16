#################################################################
CREATE PROC repAccountsWithStockBalance
		@EndDate DATETIME
AS
	SET NOCOUNT ON;
	/*
		Main values
	*/
	DECLARE 
		@StartDate DATETIME = '01-01-1980',
		@MaterialGuid UNIQUEIDENTIFIER = 0x0,
		@StoreGuid UNIQUEIDENTIFIER = 0x0,
		@PriceType INT = 6,
		/*
			1: Whole,
			2: Half,
			3: Vendor,
			4: Export,
			5: Retail,
			6: EndUser,
			7: LastPrice
		*/
		@MatUnit  INT = 0,
		/*  
			0: unit 1  
			1: unit 2  
			2: unit 3  
			3: default unit  
		*/ 
		@accGuid [uniqueidentifier] = 0X0, 
		@curGuid [uniqueidentifier] = 0x0,
		@CostGuid [UNIQUEIDENTIFIER] =0x0
		
	DECLARE @TotalStock FLOAT = 0,
			@TotalAccount FLOAT = 0
			
	DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
	
	CREATE TABLE #SecViol (Type INT, Cnt INT);
	DECLARE @Sec INT  
	SET @Sec = [dbo].[fnGetUserEntrySec_Browse]([dbo].[fnGetCurrentUserGUID](),0X00)  
	
	/* Stock calculations */
	CREATE TABLE #Stock (MaterialGuid UNIQUEIDENTIFIER, MaterialName NVARCHAR(MAX), Quantity FLOAT, UnitPrice FLOAT, Total FLOAT, MatSecurity INT);
	INSERT INTO #Stock
	SELECT
		Mt.Guid,
		CASE @Lang WHEN 0 THEN Mt.Name ELSE (CASE Mt.LatinName WHEN '' THEN Mt.Name ELSE Mt.LatinName END) END AS Name,
		SUM(
			ISNULL(
					(
						(CASE @MatUnit	WHEN 0 THEN Bi.Qty    
										WHEN 1 THEN (Bi.Qty/[Unit2Fact])      
										WHEN 2 THEN (Bi.Qty/[Unit3Fact])
										ELSE CASE [DefUnit]    
											WHEN 1 THEN Bi.Qty        
											WHEN 2 THEN (Bi.Qty/[Unit2Fact])        
											ELSE (Bi.Qty/[Unit3Fact]) END   
						END
						)
					*
					CASE Bt.bIsInput WHEN 0 THEN -1 ELSE 1 END
					)
			, 0)
		) AS Stock,
		CASE WHEN @PriceType = 1 THEN Mt.Whole
			WHEN @PriceType = 2 THEN Mt.Half
			WHEN @PriceType = 3 THEN Mt.Vendor
			WHEN @PriceType = 4 THEN Mt.Export
			WHEN @PriceType = 5 THEN Mt.Retail
			WHEN @PriceType = 6 THEN Mt.EndUser
			ELSE Mt.LastPrice
		END UnitPrice,
		0,
		Mt.Security
	FROM
		Mt000 Mt   
		LEFT JOIN Bi000 Bi ON Mt.Guid = Bi.MatGuid
		LEFT JOIN Bu000 Bu on Bu.Guid = Bi.ParentGuid   
		LEFT JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid   
	WHERE    
		(@StoreGuid = 0x0 OR Bi.StoreGuid = @StoreGuid)
		AND (@MaterialGuid = 0x0 OR Bi.MatGUID = @MaterialGuid)
		AND bt.bNoPost = 0
		AND Bu.Date BETWEEN @StartDate AND @EndDate
	GROUP BY   
		Mt.Guid,
		Mt.Name,
		Mt.LatinName,
		Mt.Whole,Mt.Half,Mt.Vendor,Mt.Export,Mt.Retail,Mt.EndUser,Mt.LastPrice,
		Mt.Security;
	
	UPDATE #Stock SET Total = UnitPrice * Quantity
		
	EXEC prcCheckSecurity @result = '#Stock';
	
	--SELECT * FROM #Stock;
	SET @TotalStock = (SELECT SUM(Total) FROM #Stock)
	
	/* Accounting calculations */
	SET @TotalAccount = (SELECT [dbo].[fnAccount_getBalance](@accGuid,@curGuid,@StartDate,@EndDate,@CostGuid) )
	
	
	SELECT * FROM #SecViol;
--prcConnections_add2 'Œ«·œ'
--repAccountsWithStock '01-01-2015'
--SELECT [dbo].[fnAccount_getBalance]('3F0F9AE6-553A-47AA-8C97-87CC8FC30B0F','FA36E398-BEA5-40D1-81F0-2C73C78598F1','01-01-2014','01-01-2015',0x0)

#################################################################
#END