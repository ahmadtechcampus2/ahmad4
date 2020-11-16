########################################################################
CREATE PROC repRentalAssets
		@AssGUID UNIQUEIDENTIFIER,    
		@GrpGUID UNIQUEIDENTIFIER,    
		@CostGUID UNIQUEIDENTIFIER,    
		@StoreGUID UNIQUEIDENTIFIER,    
		@StartDate DATETIME, 
		@EndDate DATETIME,    
		@CurGUID UNIQUEIDENTIFIER,    
		@CurVal  FLOAT 
AS    
	SET NOCOUNT ON    
	CREATE TABLE #Mat( mtNumber UNIQUEIDENTIFIER, mtSecurity INT)       
	-------------       
	insert into #Mat EXEC prcGetMatsList  0x0, @GrpGUID    
	-------------    
	CREATE TABLE #Cost( coGUID UNIQUEIDENTIFIER)        
	INSERT INTO #Cost SELECT GUID FROM fnGetCostsList( @CostGUID)        
	IF( @CostGUID = 0x0)   
		INSERT INTO #Cost VALUES( 0x0)   
	----------------------------------------------------------   
	DECLARE @m_AssGuid UNIQUEIDENTIFIER   
	SET @m_AssGuid  = ISNULL( @AssGUID, 0x0)   
	----------------------------------------------------------   
	CREATE TABLE #Store( stGUID UNIQUEIDENTIFIER)    
	INSERT INTO #Store SELECT GUID FROM fnGetStoresList( @StoreGUID)       
	CREATE TABLE #Result     
	(     
		buGUID					UNIQUEIDENTIFIER,     
		FromDate 				DATETIME,    
		ToDate					DATETIME, 
		buCostGUID				UNIQUEIDENTIFIER,    
		buStoreGUID				UNIQUEIDENTIFIER, 
		SN						NVARCHAR(1000) COLLATE Arabic_CI_AI,    
		SNGuid					UNIQUEIDENTIFIER,    
		MatGUID					UNIQUEIDENTIFIER,    
		Type					INT, -- 0 Input, 1 Output 
		Flag					INT, 
		TypeGuid				UNIQUEIDENTIFIER,    
		idNumber				INT IDENTITY (1,1) NOT NULL, 
	) 
	-- ÇáÍÑßÇÊ>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	  
	-- In Bill 
	INSERT INTO #Result    
		(buGUID, 
		FromDate, 
		ToDate, 
		buCostGUID, 
		buStoreGUID, 
		SN,
		SNGuid,  
		MatGUID, 
		Type, 
		Flag, 
		TypeGuid) 
	SELECT     
		BuBi.buGUID,    
		BuBi.buDate, 
		'1-1-1980', 
		BuBi.biCostPtr,    
		BuBi.biStorePtr, 
		SNC.SN, 
		SNC.Guid, 
		BuBi.biMatPtr, 
		0, 
		0, 
		bubi.buType 
	FROM     
		vwExtended_bi AS BuBi   
		INNER JOIN #Cost AS Cost ON Cost.coGUID = buBi.BiCostPtr    
		INNER JOIN #Store AS Store ON Store.stGUID = buBi.BiStorePtr    
		INNER JOIN #Mat AS mt ON BuBi.biMatPtr = mt.mtNumber   
		INNER JOIN vwAs AS Ass ON Ass.asParentGUID = mt.mtNumber 
		INNER JOIN SNT000 AS SNT ON bubi.biGuid = SNT.BiGuid 
		INNER JOIN SNC000 AS SNC ON SNC.GUID = SNT.ParentGuid 
		INNER JOIN vwMt AS vMt ON vMt.mtGuid = mt.mtNumber 
	WHERE    
		BuBi.buIsPosted = 1 
		AND BuBi.buDate <= @EndDate  
		AND BuBi.btIsInput = 1 
		AND( @m_AssGuid = 0x0 OR vMt.mtGUID = @m_AssGuid) 
	GROUP BY  
		BuBi.buGUID,    
		BuBi.buDate, 
		BuBi.biCostPtr,   
		SNC.Guid,  
		BuBi.biStorePtr,    
		SNC.SN, 
		BuBi.biMatPtr, 
		bubi.buType 
	--select 'In Bill' 
	--select res.*, bu.buNumber, btIsOutput, btIsInput, btName from #Result res inner join vwExtended_bi bu on res.buGuid = bu.buGuid 
	-- Out Bill 
 INSERT INTO #Result    
		(buGUID, 
		FromDate, 
		ToDate, 
		buCostGUID, 
		buStoreGUID, 
		SN,
		SnGuid,  
		MatGUID, 
		Type, 
		Flag, 
		TypeGuid) 
	SELECT     
		BuBi.buGUID,    
		BuBi.buDate,  
		'1-1-1980', 
		BuBi.biCostPtr,    
		BuBi.biStorePtr,    
		SNC.SN, 
		SNC.Guid,
		BuBi.biMatPtr, 
		1, 
		0, 
		bubi.buType 
	FROM     
		vwExtended_bi AS BuBi   
		INNER JOIN #Cost AS Cost ON Cost.coGUID = buBi.BiCostPtr    
		INNER JOIN #Store AS Store ON Store.stGUID = buBi.BiStorePtr    
		INNER JOIN #Mat AS mt ON BuBi.biMatPtr = mt.mtNumber   
		INNER JOIN vwAs AS Ass ON Ass.asParentGUID = mt.mtNumber 
		INNER JOIN SNT000 AS SNT ON bubi.biGuid = SNT.BiGuid 
		INNER JOIN SNC000 AS SNC ON SNC.GUID = SNT.ParentGuid 
		INNER JOIN vwMt AS vMt ON vMt.mtGuid = mt.mtNumber 
	WHERE    
		BuBi.buIsPosted = 1    
		AND BuBi.buDate <= @EndDate 
		AND BuBi.btIsOutput = 1 
		AND( @m_AssGuid = 0x0 OR vMt.mtGUID = @m_AssGuid) 
	GROUP BY 
		BuBi.buGUID,    
		BuBi.buDate,  
		BuBi.biCostPtr,    
		BuBi.biStorePtr,   		 
		SNC.SN, 
		SNC.Guid, 
		BuBi.biMatPtr, 
		bubi.buType 
--	select * from #result 
	--select 'Out Bill' 
	--select res.*, bu.buNumber, btIsOutput, btIsInput, btName from #Result res inner join vwExtended_bi bu on res.buGuid = bu.buGuid 
	--------------------------------------------------------------------
	CREATE TABLE #SnResult ( SNGuid UNIQUEIDENTIFIER)
	INSERT INTO #SnResult SELECT DISTINCT SNGuid  FROM #Result
	DECLARE @ADTbl TABLE( AdGUID UNIQUEIDENTIFIER, SNGuid UNIQUEIDENTIFIER,  DailyRent FLOAT) 
	INSERT INTO @ADTbl 
	SELECT    
		ad.GUID, 
		snc.Guid, 
		ISNULL( ad.DailyRental, 0)  
	FROM Ad000 AS ad  	INNER JOIN #SnResult res on res.SNGuid = ad.SnGuid 
						INNER JOIN SNC000 Snc on Snc.Guid = res.SnGuid 
	-------------------------------------------------------------------- 
	DECLARE @c_Result CURSOR  
	DECLARE     
		@OldIdNumber INT,     
		@IdNumber INT, 
		@OldSn NVARCHAR(1000),    
		@Sn NVARCHAR(1000), 
		@Date DATETIME, 
		@Type INT 
		   
	SET @OldSn  = ''   
	SET @Sn = ''   
		    
	SET @c_Result = CURSOR DYNAMIC FOR        
		SELECT     
			FromDate, 
			idNumber,  
			Sn, 
			Res.Type 
		FROM     
			#Result AS Res inner join bt000 bt on Res.TypeGuid = bt.Guid 
		ORDER BY    
			Sn, 
			FromDate, 
			bt.Type 

	OPEN @c_Result     
	FETCH NEXT FROM @c_Result INTO @Date, @IdNumber, @Sn, @Type 
	WHILE @@FETCH_STATUS = 0     
	BEGIN    
   		IF( ( (@OldSn <> '') AND ( @OldSn = @Sn) AND (@Type = 1))) 
		BEGIN 
			UPDATE #Result  
				SET ToDate = @Date, Flag = 1 
			WHERE  
				idNumber = @OldIdNumber 
		END 
		IF @Type = 0 
			SET @OldIdNumber = @IdNumber 
		SET @OldSn = @Sn 
		FETCH NEXT FROM @c_Result INTO @Date, @IdNumber, @Sn, @Type 
	END 
	CLOSE @c_Result
	DEALLOCATE @c_Result

	--  select 'after cursor' 
	--  select * from #Result 
	---------------------------------------------    
	UPDATE #Result SET ToDate = @EndDate WHERE Flag = 0 AND Type = 0 

	------------------------------------------------------ 
	DELETE Result FROM #Result Result INNER JOIN @ADTbl ADTbl ON Result.SNGuid = ADTbl.SNGuid 
	WHERE ToDate < @StartDate OR Type = 1 
	update #Result SET FromDate = @StartDate WHERE FromDate < @StartDate  
	--select 'end' 
	------------------------------------------------------- 
	SELECT     
		AdTbl.AdGuid 		AS AssDetailGUID,    
		Res.SN 			AS AssSn, 
		Mt.mtCode		AS AssAssetCode, 
		AdTbl.DailyRent * Ass.asCurrencyVal/ CASE WHEN ISNULL( @CurVal, 0) = 0 THEN 1 ELSE @CurVal END AS AssDailyRental,    
		Res.FromDate 		AS AssFromDate,    
		Res.ToDate 		AS AssToDate, 
		MIN( FLOOR(CAST(Res.ToDate AS FLOAT)) - FLOOR(CAST(Res.FromDate AS FLOAT)) ) AS DayCnt,
		MIN (AdTbl.DailyRent * Ass.asCurrencyVal/ CASE WHEN ISNULL( @CurVal, 0) = 0 THEN 1 ELSE @CurVal END)*( FLOOR(CAST(Res.ToDate AS FLOAT)) - FLOOR(CAST(Res.FromDate AS FLOAT)) ) AS RentVal,   
		Ass.asCurrencyGUID	AS AssCurrencyGUID,    
		Ass.asCurrencyVal	AS AssCurrencyVal, 
		Res.buCostGUID 		AS AssCostGUID,    
		Res.buStoreGUID 	AS AssStoreGUID, 
		ISNULL( co.coCode, '')	AS AssCostCode, 
		ISNULL( co.coName, '')	AS AssCostName, 
		st.stCode		AS AssStoreCode, 
		st.stName		AS AssStoreName ,
		MIN(CASE st.stCode WHEN NULL THEN '' ELSE st.stCode + '-' + st.stName END) AS AssStoreCodeName,
		ISNULL(MIN(CASE co.coCode WHEN NULL THEN '' ELSE co.coCode + '-' + co.coName END),'') AS AssCostCodeName,
		my.Code AS AssCurrencyCode
	FROM     
		#Result Res  
		INNER JOIN @ADTbl AS AdTbl ON Res.SNGuid = AdTbl.SNGuid    
		INNER JOIN vwAd AS ad ON AdTbl.AdGUID = ad.adGUID    
		INNER JOIN vwAs AS ass on ass.asGUID = ad.adAssGuid 
		INNER JOIN vwMt AS Mt on Mt.mtGUID = ass.asParentGuid 
		INNER JOIN vwSt AS St on St.stGUID = Res.buStoreGuid 
		LEFT JOIN vwCo AS co on co.coGUID = Res.buCostGuid 
		LEFT JOIN my000 AS my on my.GUID = Ass.asCurrencyGUID 
	GROUP BY 
		AdTbl.AdGuid, 
		Res.SN, 
		Mt.mtCode, 
		AdTbl.DailyRent * Ass.asCurrencyVal/ CASE WHEN ISNULL( @CurVal, 0) = 0 THEN 1 ELSE @CurVal END, 
		Res.FromDate, 
		Res.ToDate, 
		Ass.asCurrencyGUID, 
		Ass.asCurrencyVal, 
		Res.buCostGUID, 
		Res.buStoreGUID, 
		ISNULL( co.coCode, ''), 
		ISNULL( co.coName, ''), 
		st.stCode, 
		st.stName,
		my.Code 
	ORDER BY 
		Res.SN,     
		Len( Res.SN),  
		Res.ToDate 
	SET NOCOUNT OFF
########################################################################
#END