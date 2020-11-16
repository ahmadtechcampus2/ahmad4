CREATE PROC PrcMaterialMoveByExpireDateReport
	@materialGuid UNIQUEIDENTIFIER =0x00
	,@groupGuid	UNIQUEIDENTIFIER =0x00
	,@storeGuid  UNIQUEIDENTIFIER =0x00
	,@toDate		DATETIME ='12-12-2016'
	,@materialUnit  INT =3
	/* 
		0: unit 1 
		1: unit 2 
		2: unit 3 
		3: default unit 
	*/ 
	,@materialConditionGuid  UNIQUEIDENTIFIER	=0x00 
	,@periodType INT	 =1
	,@lang INT = 0
	/* 
		0: daily 
		1: monthly 
		2: yearly  
	*/ 
	 
AS 
	SET NOCOUNT ON 
	 
	CREATE TABLE [#matTable]( [MatGuid] [UNIQUEIDENTIFIER], [mtSecurity] [INT])   
	INSERT INTO [#matTable]	 
	EXEC [prcGetMatsList]  
		@materialGuid 
		,@groupGuid 
		,-1  -- (0 Mat store), (1 Mat service), (-1 ALL Mats Types)    
		,@materialConditionGuid   
	CREATE TABLE [#StoreTable]([StoreGuid] [UNIQUEIDENTIFIER], [Security] [INT])   
	INSERT INTO [#StoreTable] 
	EXEC [prcGetStoresList]  @StoreGuid   		 
	 
	CREATE TABLE #matInventory_expireDate 
	( 
		[MatGuid]		UNIQUEIDENTIFIER 
		,[ExpireDate]DATETIME 
		,Qty		FLOAT 
		,Qty2		FLOAT 
		,Qty3		FLOAT 
	) 
	INSERT INTO #matInventory_expireDate 
	SELECT 
		bi.MatGuid 
		,CASE @periodType  
			WHEN 0 THEN bi.[ExpireDate] 
			WHEN 1 THEN CAST 
					(CAST(YEAR(bi.[ExpireDate]) AS [NVARCHAR](4)) + '-' + CAST(MONTH(bi.[ExpireDate]) AS [NVARCHAR](2)) + '-1' 
					AS DATETIME)  
			WHEN 2 THEN CAST 
					(CAST(YEAR(bi.[ExpireDate]) AS [NVARCHAR](4)) + '-1-1'  
					AS DATETIME) 
		END AS [ExpireDate] 
		,SUM(bi.Qty * CASE bt.bIsInput	WHEN 1 THEN 1 ELSE -1 END) AS Qty 
		,SUM( 
			( 
				CASE bi.Qty2  
					WHEN 0 THEN [bi].[Qty] / (CASE WHEN [mt].[Unit2Fact] = 0 THEN 1 ELSE [mt].[Unit2Fact] END) 
					ELSE bi.Qty2 
				END 
			) 
			*	 
			CASE bt.bIsInput	WHEN 1 THEN 1 ELSE -1 END 
		)AS Qty2 
			 
		,SUM( 
			( 
				CASE bi.Qty3  
					WHEN 0 THEN [bi].[Qty] / (CASE WHEN [mt].[Unit3Fact] = 0 THEN 1 ELSE [mt].[Unit3Fact] END) 
					ELSE bi.Qty3 
				END 
			) 
			*	 
			CASE bt.bIsInput	WHEN 1 THEN 1 ELSE -1 END 
		)AS Qty3 
	FROM 
		bi000 AS bi 
		INNER JOIN mt000 AS mt ON mt.[Guid] = bi.[MatGuid] 
		INNER JOIN bu000 AS bu ON bu.[Guid] = bi.ParentGuid AND bi.ExpireDate <> '1-1-1980'
		INNER JOIN bt000 AS bt ON bt.[Guid] = bu.TypeGuid  
		INNER JOIN #StoreTable AS st ON st.StoreGuid = bi.StoreGuid 
	WHERE bi.[ExpireDate] <= @toDate 			 
	GROUP BY  
		bi.MatGuid  
		,CASE @periodType  
			WHEN 0 THEN bi.[ExpireDate] 
			WHEN 1 THEN CAST 
					(CAST(YEAR(bi.[ExpireDate]) AS [NVARCHAR](4))+ '-' + CAST(MONTH(bi.[ExpireDate]) AS [NVARCHAR](2)) + '-1' 
					AS DATETIME)  
			WHEN 2 THEN CAST 
					(CAST(YEAR(bi.[ExpireDate]) AS [NVARCHAR](4))+ '-1-1'  
					AS DATETIME) 
		END 
	 
	DECLARE @Date DATETIME 
			,@sql NVARCHAR(max) 
	DECLARE cur CURSOR FOR 
	SELECT  
		DISTINCT([ExpireDate]) 
	FROM 
		#matInventory_expireDate 
	ORDER BY [ExpireDate]	 
		 
	SELECT @sql = '' 
	OPEN cur 
	FETCH NEXT FROM cur INTO @Date 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		SELECT @sql = @sql + '[' + CONVERT(NVARCHAR(10), @Date, 105) +'],' -- dd-mm-yy 
		FETCH NEXT FROM cur INTO @Date 
	END 
	CLOSE cur 
	DEALLOCATE cur 
	IF RIGHT(@sql, 1) = ',' 
      SET @sql = STUFF(@sql, LEN(@sql), 1, ' ') 

	SELECT  
		mt.[Guid]		AS mtGuid 
		,CASE @Lang WHEN 0 THEN mt.Name ELSE CASE mt.LatinName WHEN '' THEN mt.Name ELSE mt.LatinName END END as [MtName]
		
		,mt_inv.[ExpireDate] AS [ExpireDateChar] 
		,ISNULL( 
			CASE @materialUnit 	 
				WHEN 0 THEN mt_inv.Qty 
				WHEN 1 THEN mt_inv.Qty2 
				WHEN 2 THEN mt_inv.Qty3 
				WHEN 3 THEN  
					CASE mt.DefUnit 
						WHEN 1 THEN mt_inv.Qty 
						WHEN 2 THEN mt_inv.Qty2 
						WHEN 3 THEN mt_inv.Qty3 
					END 
				ELSE 0	 
			END			  
			, 0) AS Qty 
	 
	INTO #table	 
	FROM  
		mt000 AS mt 
		INNER JOIN gr000 AS gr ON gr.[Guid] = mt.[GroupGuid] 
		INNER JOIN #matTable ON #matTable.[MatGuid] = mt.[Guid] 
		LEFT JOIN #matInventory_expireDate AS mt_inv ON mt_inv.[MatGuid] = mt.[Guid]  
	WHERE mt_inv.Qty > 0	

	 
	SELECT * FROM #table AS mt order by [ExpireDateChar] ,mtName

	SELECT  
		DISTINCT([ExpireDate]) 
	FROM 
		#matInventory_expireDate 