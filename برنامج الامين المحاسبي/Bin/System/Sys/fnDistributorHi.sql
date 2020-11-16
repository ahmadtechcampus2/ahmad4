########################################
CREATE FUNCTION fnDistributorHi(@IsDistributor BIT,@PeriodGuid UNIQUEIDENTIFIER = 0x)
RETURNS @Result TABLE([name] NVARCHAR(MAX),[GUID] UNIQUEIDENTIFIER,[level] INT,[Qty] FLOAT)
AS
BEGIN
	IF @IsDistributor = 0
		INSERT INTO @Result VALUES('',0x00,1,0);
	WITH tree (GUID, name, level) AS  
	(
	  SELECT GUID, name, 2 AS level        
	  FROM DistHi000
	  WHERE ParentGUID = 0x00
	  UNION ALL
	  SELECT child.GUID, child.name, parent.level + 1
	  FROM DistHi000 AS child
	  JOIN tree AS parent ON parent.GUID = child.parentGUID
	)

	INSERT INTO @Result
	SELECT t.name,t.GUID,t.level, (SELECT ISNULL(SUM(dq.Qty),0) FROM DistTargetByGroupOrDistributorQty000 AS dq WHERE t.GUID = dq.DistGroupGUID AND dq.ParentGUID IN (SELECT GUID FROM DistTargetByGroupOrDistributorDetails000 WHERE ParentGUID IN (SELECT GUID FROM DistTargetByGroupOrDistributor000 WHERE PeriodGuid = @PeriodGuid)))
	FROM tree AS t 
	WHERE (@IsDistributor = 1 AND t.GUID IN (SELECT HierarchyGUID FROM [dbo].[vwDistributor])) OR (@IsDistributor = 0 AND t.level != (SELECT MAX(level) FROM tree))
	GROUP BY t.GUID, t.name, t.level
	ORDER BY level;
	RETURN
END
########################################
CREATE FUNCTION fnGetDistributorSalesAvg (
	@PeriodGUID		UNIQUEIDENTIFIER,
	@DistributorGUID UNIQUEIDENTIFIER
)
RETURNS @Result TABLE
( 
	MatGUID UNIQUEIDENTIFIER, 
	SalesAvgQty	 FLOAT
)  
AS
BEGIN
	DECLARE @PeriodStartDate DATETIME,  
	 		@StartDate 		 DATETIME,  
			@EndDate 		 DATETIME,  
			@CurrencyGUID 	 UNIQUEIDENTIFIER,  
			@brEnabled		 INT, 
			@BranchMask		 BIGINT,
			@CostGuid		 UNIQUEIDENTIFIER,
			@BranchGuid		 UNIQUEIDENTIFIER
	SELECT 
		@CostGuid = sm.CostGuid,
		@BranchMask = d.BranchMask
	FROM 
		Distributor000 AS d
		JOIN DistSalesMan000 AS sm ON sm.GUID = d.PrimSalesmanGUID
	WHERE 
		d.GUID = @DistributorGUID
	
	SELECT 
		@BranchGuid = ISNULL(Guid, 0x0) 
		FROM br000 
	WHERE 
		[dbo].[fnPowerOf2]([Number] - 1) = @BranchMask
	
	IF (@BranchGuid IS NULL)
		SET @BranchGuid = 0x0
			
	SELECT @PeriodStartDate = StartDate FROM vwPeriods WHERE GUID = @PeriodGUID  
	SELECT @EndDate   = DATEADD(day, -1, @PeriodStartDate)  
	SELECT @StartDate = DATEADD(month, -6, @EndDate)  
	SELECT @CurrencyGUID = GUID From my000 WHERE Number = 1  
	SET @brEnabled = [dbo].[fnOption_get]('EnableBranches', '1')  
	DECLARE @MatTbl	TABLE (GUID UNIQUEIDENTIFIER)    
	DECLARE @CustTbl TABLE (GUID UNIQUEIDENTIFIER, TradeChannelGUID UNIQUEIDENTIFIER, CustomerTypeGUID UNIQUEIDENTIFIER, DistGUID UNIQUEIDENTIFIER)    
	 
	INSERT INTO @CustTbl     
	SELECT DISTINCT    
		cu.cuGUID,    
		ISNULL(ce.TradeChannelGUID, 0x0),    
		ISNULL(ce.CustomerTypeGUID, 0x0),    
		0x00    
	FROM     
		vwCu AS cu 
		INNER JOIN vwac AS ac ON ac.acGuid = cu.cuAccount 
		LEFT JOIN DistCe000 AS ce ON cu.cuGUID = ce.CustomerGUID     
	WHERE     
		ISNULL(ce.State, 0) <> 1 
		AND ((acBranchMask & @BranchMask <> 0 AND @brEnabled = 1) OR 
			(@brEnabled <> 1)) 
	INSERT INTO @MatTbl     
	SELECT     
		mt.mtGUID    
	FROM     
		vwMt AS mt    
	Where	(brBranchMask & @BranchMask <> 0 AND @brEnabled = 1) OR 
			(@brEnabled <> 1) 
	DECLARE @CustMatMonthSales TABLE (CustGUID UNIQUEIDENTIFIER, MatGUID UNIQUEIDENTIFIER, [Month] INT, SalesQty FLOAT, BranchGUID UNIQUEIDENTIFIER)    
	DECLARE @PeriodsTbl TABLE (GUID UNIQUEIDENTIFIER, StartDate DATETIME, EndDate DATETIME)  
	  
	INSERT INTO @PeriodsTbl  
		SELECT  
			p.Guid,  
			p.StartDate,  
			p.EndDate  
		FROM vwperiods AS p  
		WHERE p.Guid = @PeriodGUID

	IF EXISTS (SELECT TOP 1 * FROM @PeriodsTbl)
	BEGIN
		DELETE FROM @CustMatMonthSales
		DECLARE @C CURSOR,  
			@CPeriodGuid	UNIQUEIDENTIFIER,  
			@CStartDate		DATETIME,  
			@CEndDate		DATETIME  
	SET @C = CURSOR FAST_FORWARD FOR SELECT Guid, StartDate, EndDate FROM @PeriodsTbl  
	OPEN @C FETCH FROM @C INTO @CPeriodGuid, @CStartDate, @CEndDate    
	WHILE @@FETCH_STATUS = 0    
		BEGIN     
			INSERT INTO @CustMatMonthSales    
				SELECT    
					bi.buCustPtr,    
					bi.biMatPtr,    
					DatePart(Month, bi.buDate),    
					Sum( CASE bi.btBillType WHEN 1 THEN bi.biQty WHEN 3 THEN bi.biQty * -1 ELSE 0 END),    
					CASE @brEnabled WHEN 1 THEN bi.buBranch ELSE 0x0 END    
				FROM    
					vwExtended_bi AS bi    
					INNER JOIN @CustTbl AS cu ON cu.GUID = bi.buCustPtr    
					INNER JOIN @MatTbl AS mt ON mt.GUID = bi.biMatPtr    
				WHERE    
					bi.buDate BETWEEN @CStartDate AND @CEndDate	AND    
					bi.btType = 1 AND (bi.btBillType = 1 OR bi.btBillType = 3) AND     
					(bi.buBranch = @BranchGuid OR @BranchGuid = 0x0) AND
					bi.buCostPtr = @CostGuid
				GROUP BY    
					bi.buCustPtr,    
					bi.biMatPtr,    
					DatePart(Month, bi.buDate),    
					CASE @brEnabled WHEN 1 THEN bi.buBranch ELSE 0x0 END  
			FETCH FROM @C INTO @CPeriodGuid, @CStartDate, @CEndDate    
		END	    
	CLOSE @C DEALLOCATE @C    
	END
--------  
	DECLARE @CustMatSales TABLE ( CustGUID UNIQUEIDENTIFIER, MatGUID UNIQUEIDENTIFIER, MonthCount INT, SalesQty FLOAT, MatSalesAvgQty float, StaticMatSalesAvgQty float, MatTargetQty float, TradeChannelTarget FLOAT, BranchGUID UNIQUEIDENTIFIER)    
	INSERT INTO @CustMatSales    
	SELECT    
		CustGUID,    
		MatGUID,    
		Count([Month]),    
		Sum(SalesQty),    
		0,    
		0,    
		0,    
		0,    
		BranchGuid    
	FROM    
		@CustMatMonthSales    
	GROUP BY    
		CustGUID,    
		MatGUID,    
		BranchGuid    
	------------------------------   
	INSERT INTO @CustMatSales    
		SELECT    
			0x0,    
			mt.Guid,   
			1,    
			0,	   
			0,    
			0,    
			0,    
			0,    
			@BranchGuid   
		FROM   
			@MatTbl AS mt   
			INNER JOIN mt000 AS mt2 ON mt.Guid = mt2.Guid   
		WHERE	mt.Guid NOT IN (SELECT MatGuid FROM @CustMatSales)   
	
	DECLARE @MatSales TABLE (MatGUID UNIQUEIDENTIFIER, SalesAvgQty FLOAT, BranchGUID UNIQUEIDENTIFIER)    
	INSERT INTO @MatSales   
	SELECT   
		MatGUID,   
		Sum(SalesQty / MonthCount),   
		BranchGuid   
	FROM   
		@CustMatSales   
	GROUP BY   
		MatGUID, BranchGuid   

	DECLARE @PeriodsMask INT,
			@C2 CURSOR
	SET @PeriodsMask = 0
	SET @C2 = CURSOR FAST_FORWARD FOR SELECT Guid FROM @PeriodsTbl
	OPEN @C2 FETCH FROM @C2 INTO @CPeriodGuid
	WHILE @@FETCH_STATUS = 0
		BEGIN
			SELECT @PeriodsMask = @PeriodsMask + [dbo].[fnPowerOf2]([Number] - 1) FROM vwPeriods WHERE Guid = @CPeriodGuid
			FETCH FROM @C2 INTO @CPeriodGuid
		END
	CLOSE @C2
	DEALLOCATE @C2
	INSERT INTO @Result
		SELECT    
			s.[MatGUID],   
			s.[SalesAvgQty] AS SalesAvgQty
		FROM   
			@MatSales AS s   
			INNER JOIN fnMtByUnit(1) AS mt ON mt.mtGUID = s.MatGUID   
		ORDER BY LEN(mt.[mtCode]), mt.[mtCode]   
	
	RETURN
END
/*  
select * from DBO.fnGetDistributorSalsAvg(0x0, 'CF812180-F036-486B-A4EF-71CFED2C0A54','86945365-345A-438A-B397-D2AA82CE4E9E')
*/
#############################
#END
