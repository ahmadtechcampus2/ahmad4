########################################################################
CREATE PROC repDeprecationAssets
		@ToDate DATETIME,           
		@AssGUID UNIQUEIDENTIFIER,
		@AdGUID UNIQUEIDENTIFIER,           
		@GrpGUID UNIQUEIDENTIFIER,           
		@CurGUID UNIQUEIDENTIFIER,           
		@CurVal  FLOAT,           
		@CostGUID UNIQUEIDENTIFIER,           
		@StoreGUID UNIQUEIDENTIFIER,
		@RepSource UNIQUEIDENTIFIER,
		@TypeAction INT,        
		@BranchGuid UNIQUEIDENTIFIER,        
		@BranchMask BIGINT,       
		@CalcMethod INT       
AS    
	IF @CalcMethod = 1 
	BEGIN 
		SET @ToDate = @ToDate - 1
	END

	DECLARE @YEARDAYS INT  
	SET  @YEARDAYS = 365   
	SET NOCOUNT ON           
	SET @BranchMask  = 0    
	----------------------------------------------------------          
	CREATE TABLE #Mat ( mtNumber UNIQUEIDENTIFIER, mtSecurity INT)              
	-------------              
	INSERT INTO #Mat EXEC prcGetMatsList @AssGUID, @GrpGUID       
	-------------           
	CREATE TABLE #Cost( coGUID UNIQUEIDENTIFIER)               
	INSERT INTO #Cost SELECT GUID FROM fnGetCostsList( @CostGUID)               
	IF( @CostGUID = 0x0)          
		INSERT INTO #Cost VALUES( 0x0)          
	----------------------------------------------------------          
	CREATE TABLE #Store( stGUID UNIQUEIDENTIFIER)           
	INSERT INTO #Store SELECT GUID FROM fnGetStoresList( @StoreGUID) 
	----------------------------------------------------------   
	CREATE TABLE [#SNALLlastcheck]  
	(  
	[GID]			[INT] ,
	[SN]			[NVARCHAR](255)  COLLATE ARABIC_CI_AI,
	[SNGuid]        [UNIQUEIDENTIFIER],
	[MatGuid]       [UNIQUEIDENTIFIER],  
	[MatName]       [NVARCHAR](255)  COLLATE ARABIC_CI_AI ,
	[StoreGuid]		[UNIQUEIDENTIFIER],
	[StoreName]		[NVARCHAR](255)  COLLATE ARABIC_CI_AI,  
	[BillTypeGuid]  [UNIQUEIDENTIFIER],
	[BillGuid]      [UNIQUEIDENTIFIER],
	[CustomerName]	[NVARCHAR](255)  COLLATE ARABIC_CI_AI,
	[BillDate]      [DATETIME],  
	[Bill]			[NVARCHAR](255)  COLLATE ARABIC_CI_AI ,
	[PRICE]			[FLOAT],
	[Number]		[FLOAT],
	[BranchGuid]	[UNIQUEIDENTIFIER],
	[CostGUID]		[UNIQUEIDENTIFIER],  
	[Direction]		[INT],
	[Gr_GUID]		[UNIQUEIDENTIFIER],
	[Ac_GUID]		[UNIQUEIDENTIFIER]  
	)

	INSERT INTO [#SNALLlastcheck]   ([GID],[SN],[SNGuid],[MatGuid],[MatName],[StoreGuid],[StoreName],[BillTypeGuid],[BillGuid],[CustomerName],[BillDate],[Bill],  
	[PRICE],[Number],[BranchGuid],[CostGUID],[Direction],[Gr_GUID],[Ac_GUID])      
	
	EXEC SN_lastcheck @AssGUID , 0x0 , 0x0 , 0x0 , '1980-1-1' , @ToDate , 0x0 
	----------------------------------------------------------                           
	CREATE TABLE #Result        
	(            
		Guid 					UNIQUEIDENTIFIER default NEWID(),      
		FromDate 				DATETIME,           
		ToDate					DATETIME,        
		SNGUID					UNIQUEIDENTIFIER,      
		ADGUID					UNIQUEIDENTIFIER,      
		InValue					FLOAT,        
		AddedVal				FLOAT,        
		DeductVal				FLOAT,        
		Type					INT, -- 0 Input, 1 Output        
		Flag					INT,    
		Number 					INT DEFAULT 0,    
		PrevDep					FLOAT DEFAULT 0,    
		AssVal					FLOAT DEFAULT 0,    
		CurrentDep				FLOAT DEFAULT 0,    
		TotalCurrentDep			FLOAT DEFAULT 0,    
		Life					FLOAT DEFAULT 0,       
		CostGuid				UNIQUEIDENTIFIER DEFAULT 0x0,  
		StoreGuid				UNIQUEIDENTIFIER DEFAULT 0x0,
		BranchGuid				UNIQUEIDENTIFIER DEFAULT 0x0
	)        
	-- In Bill        
	INSERT INTO #Result   (FromDate, ToDate, SNGuid, ADGUID, InValue, AddedVal, DeductVal, Type, Flag, Life, CostGuid, StoreGuid, BranchGuid)    
	SELECT       
		CASE WHEN @CalcMethod = 0 THEN dbo.fnAssetRoundToNextMonth(@CalcMethod, BuBi.buDate) ELSE (CASE WHEN BuBi.btBillType = 4 THEN dbo.fnAssetRoundToNextMonth(@CalcMethod, BuBi.buDate) - 1 ELSE dbo.fnAssetRoundToNextMonth(@CalcMethod, BuBi.buDate) END )END,    
		'1-1-1980',        
		SNC.GUID,    
		AD.GUID,          
		ad.InVal - ad.ScrapValue,    
		0,        
		0,        
		0,        
		0,    
		CASE WHEN Bap.Age IS NULL OR Bap.Age = 0 THEN CASE ad.Age WHEN 0 THEN Ass.asLifeExp ELSE ad.Age END ELSE Bap.Age END* (CASE @CalcMethod WHEN 0 THEN @YEARDAYS ELSE 12 END),    
		buBi.BiCostPtr,  
		buBi.BuStorePtr,
		CASE WHEN @BranchGuid = 0x0 THEN BuBi.buBranch ELSE @BranchGuid END
	FROM            
		vwExtended_bi AS BuBi     
		INNER JOIN #Cost  AS Cost  ON Cost.coGUID = buBi.BiCostPtr           
		INNER JOIN #Store AS Store ON Store.stGUID = buBi.BiStorePtr           
		INNER JOIN #Mat   AS mt    ON BuBi.biMatPtr = mt.mtNumber          
		INNER JOIN vwAs   AS Ass   ON Ass.asParentGUID = mt.mtNumber        
		INNER JOIN SNT000 AS SNT   ON bubi.biGuid = SNT.BiGuid        
		INNER JOIN SNC000 AS SNC   ON SNT.ParentGuid = SNC.Guid     
		INNER JOIN ad000  AS ad    ON SNC.Guid= ad.snGuid     
		INNER JOIN vwMt   AS vMt   ON vMt.mtGuid = mt.mtNumber
		LEFT JOIN RepSrcs RepSrc ON  RepSrc.idType = ad.Guid        
		LEFT  JOIN vcBap  AS Bap   ON Bap.ObjGUID = vMt.mtGroup and BuBi.buBranch = Bap.BranchGuid      
	WHERE           
		BuBi.buIsPosted = 1           
		AND BuBi.buDate <= @ToDate         
		AND BuBi.btIsInput = 1         
		AND( @BranchMask = 0 OR ( ( vMt.brBranchMask & @BranchMask) <> 0))        
		AND( @BranchGuid = 0x0 OR BuBi.buBranch = @BranchGuid)
		AND ( @AdGUID = ad.Guid OR @AdGUID = 0x0 )
		AND ( @RepSource = 0x0 OR RepSrc.IdTbl = @RepSource  )
	ORDER BY       
		SNC.SN,       
		BuBi.buDate,       
		BuBi.btType       
	-- Add Ax(added, deducted ..) info to In Operations 
	INSERT INTO #Result   (FromDate, ToDate, SNGuid, ADGUID, InValue, AddedVal, DeductVal, Type, Flag, Life, CostGuid, BranchGuid , StoreGuid)    
	select     
		CASE WHEN @CalcMethod = 0 THEN dbo.fnAssetRoundToNextMonth(@CalcMethod, ax.Date) ELSE dbo.fnAssetRoundToNextMonth(@CalcMethod, ax.Date) - 1 END,        
		'1-1-1980',        
		ad.SnGUID,         
		ad.Guid,     
		ad.InVal - ad.ScrapValue,    
		case ax.Type when 0 then ax.Value else 0 end,        
		case ax.Type when 1 then ax.Value else 0 end,        
		0,        
		0 ,    
		CASE WHEN Bap.Age IS NULL OR Bap.Age = 0 THEN CASE ad.Age WHEN 0 THEN Ass.LifeExp ELSE ad.Age END ELSE Bap.Age END* (CASE @CalcMethod WHEN 0 THEN @YEARDAYS ELSE 12 END),    
		ax.CostGuid  ,
		CASE WHEN @BranchGuid = 0x0 THEN ax.BranchGuid ELSE @BranchGuid END,
		SNlastcheck.StoreGuid
		from ax000 ax 	inner join ad000 ad on ad.guid = ax.AdGuid    
					  	inner join as000 ass on ad.ParentGuid = ass.Guid    
						inner join #Mat mt on ass.ParentGuid = mt.mtNumber    
						inner join mt000 mt1 on mt1.Guid = mt.mtNumber    
						inner join gr000 gr on gr.Guid = mt1.GroupGuid    
						LEFT  JOIN vcBap  AS Bap   ON Bap.ObjGUID = gr.Guid and ax.BranchGuid = Bap.BranchGuid      
						LEFT JOIN [#SNALLlastcheck]  AS  SNlastcheck ON SNlastcheck.SNGuid = ad.SnGuid        
		Where Date < @ToDate  
		AND ax.TYPE <> 2   
	-- Out Bill        
	INSERT INTO #Result   (FromDate, ToDate, SNGuid, ADGUID, InValue, AddedVal, DeductVal, Type, Flag, Life, CostGuid, StoreGUID, BranchGuid)    
	SELECT            
		CASE WHEN @CalcMethod = 0 THEN dbo.fnAssetRoundToNextMonth(@CalcMethod, BuBi.buDate) ELSE dbo.fnAssetRoundToNextMonth(@CalcMethod, BuBi.buDate) - 1 END,                 
		'1-1-1980',        
		SNC.Guid,    
		ad.Guid,          
		ad.InVal - ad.ScrapValue,      
		0,     
		0,       
		1,        
		0,    
		CASE WHEN Bap.Age IS NULL OR Bap.Age = 0 THEN CASE ad.Age WHEN 0 THEN Ass.asLifeExp ELSE ad.Age END ELSE Bap.Age END* (CASE @CalcMethod WHEN 0 THEN @YEARDAYS ELSE 12 END),    
		buBi.BiCostPtr,  
		buBi.buStorePtr,
		CASE WHEN @BranchGuid = 0x0 THEN BuBi.buBranch ELSE @BranchGuid END  
		  
	FROM            
		vwExtended_bi AS BuBi     
		INNER JOIN #Cost  AS Cost  ON Cost.coGUID = buBi.BiCostPtr           
		INNER JOIN #Store AS Store ON Store.stGUID = buBi.BiStorePtr           
		INNER JOIN #Mat   AS mt    ON BuBi.biMatPtr = mt.mtNumber          
		INNER JOIN vwAs   AS Ass   ON Ass.asParentGUID = mt.mtNumber        
		INNER JOIN SNT000 AS SNT   ON bubi.biGuid = SNT.BiGuid        
		INNER JOIN SNC000 AS SNC   ON SNT.ParentGuid = SNC.Guid     
		INNER JOIN ad000  AS ad    ON SNC.Guid= ad.snGuid     
		INNER JOIN vwMt   AS vMt   ON vMt.mtGuid = mt.mtNumber        
		LEFT  JOIN vcBap  AS Bap   ON Bap.ObjGUID = vMt.mtGroup and BuBi.buBranch = Bap.BranchGuid       
	WHERE           
		BuBi.buIsPosted = 1           
		AND BuBi.buDate <= @ToDate        
		AND BuBi.btIsOutput = 1        
		AND ( @BranchMask = 0 OR ( ( vMt.brBranchMask & @BranchMask) <> 0))        
		AND ( @BranchGuid = 0x0 OR BuBi.buBranch = @BranchGuid)         
	ORDER BY       
		SNC.SN,       
		BuBi.buDate,       
		BuBi.btType       
	-- Add Ax(added, deducted ..) info to out Operations 
--------------------------------------------------------    
	INSERT INTO #Result   (FromDate, ToDate, SNGuid, ADGUID, InValue, AddedVal, DeductVal, Type, Flag, Life, CostGuid, BranchGuid)    
	select     
		CASE WHEN @CalcMethod = 0 THEN dbo.fnAssetRoundToNextMonth(@CalcMethod, ax.Date) ELSE dbo.fnAssetRoundToNextMonth(@CalcMethod, ax.Date) - 1 END,       
		'1-1-1980',        
		ad.SnGUID,         
		ad.Guid,    
		ad.InVal - ad.ScrapValue,    
		case ax.Type when 0 then ax.Value else 0 end,        
		case ax.Type when 1 then ax.Value else 0 end,        
		1,        
		0 ,    
		CASE WHEN Bap.Age IS NULL OR Bap.Age = 0 THEN CASE ad.Age WHEN 0 THEN Ass.LifeExp ELSE ad.Age END ELSE Bap.Age END* (CASE @CalcMethod WHEN 0 THEN @YEARDAYS ELSE 12 END),    
		ax.CostGuid    ,
		CASE WHEN @BranchGuid = 0x0 THEN ax.BranchGuid ELSE @BranchGuid END
		from ax000 ax 	inner join ad000 ad on ad.guid = ax.AdGuid    
					  	inner join as000 ass on ad.ParentGuid = ass.Guid    
						inner join #Mat mt on ass.ParentGuid = mt.mtNumber    
						inner join mt000 mt1 on mt1.Guid = mt.mtNumber    
						inner join gr000 gr on gr.Guid = mt1.GroupGuid    
						LEFT  JOIN vcBap  AS Bap   ON Bap.ObjGUID = gr.Guid and ax.BranchGuid = Bap.BranchGuid      
		WHERE DATE < @ToDate  
		AND ax.TYPE <> 2   
-- Renumber the result  
CREATE table #T (Guid UNIQUEIDENTIFIER, Number Int identity(1, 1) )    
INSERT INTO #T (Guid )SELECT Guid FROM #Result ORDER BY type , FromDate    
UPDATE #Result SET Number = t.Number FROM #T t INNER JOIN #Result R on R.Guid = t.Guid    

------------------------------------------------------------------------------------------------------        
	DECLARE @ADTbl TABLE( 	AdGUID UNIQUEIDENTIFIER,        
							LastDepDate DATETIME,        
							InDate DATETIME,        
							ScrapValue FLOAT,        
							LastAddedVal FLOAT,        
							LastDeductVal FLOAT,        
							LastDepVal FLOAT       
						)        
	INSERT INTO @ADTbl        
		SELECT           
			DISTINCT ad.adGUID,           
			'1-1-1980',        
			ad.adInDate,        
			ad.adScrapValue,        
			ad.adAddedVal,        
			ad.adDeductVal,        
			ad.adDeprecationVal        
		FROM        
			vwAd AS ad  INNER JOIN SNC000 SNC ON SNC.Guid = ad.adSnGuid     
						INNER JOIN SNT000 SNT ON SNT.ParentGuid = SNC.Guid     
		WHERE        
			ad.adSNGuid IN ( SELECT DISTINCT SNGUID FROM #Result)        
	--------------------------------------------------------------------        
	UPDATE ADTbl SET ADTbl.LastDepDate = dd.MaxDepDate        
	FROM   
	@ADTbl ADTbl INNER JOIN         
		(SELECT dd.ADGUID AdGuid,    
		 MAX( dd.ToDate)MaxDepDate FROM DD000 dd INNER JOIN Dp000 dp On dp.Guid =dd.parentGuid      
			WHERE (dp.BranchGuid = 0x0 or dp.BranchGuid = @BranchGuid or @BranchGuid = 0x0)    
				  ---AND ( @StoreGuid <> 0x0 and dp.StoreGuid = @StoreGuid)   
		GROUP BY ADGUID ) dd 		ON ADTbl.AdGUID = dd.AdGUID       
	------------------------------------------------------		           
	DECLARE            
		@SnGuid Uniqueidentifier,    
		@OldSnGuid Uniqueidentifier,    
		@AddedVal FLOAT,    
		@DeductVal FLOAT,    
		    
		@Date DATETIME,        
		@Number INT,     
		@Type INT        
	DECLARE   c_Result CURSOR FOR     
	SELECT            
		FromDate,        
		SnGuid,    
		Number    
	FROM            
		#Result    
	where type = 1       
	ORDER BY           
		SnGuid,       
		FromDate    
	OPEN c_Result            
	FETCH NEXT FROM c_Result INTO @Date, @SnGuid, @Number    
	WHILE @@FETCH_STATUS = 0            
	BEGIN           
		SELECT @Number = MIN(Number) FROM #Result WHERE Number  <  @Number and Type = 0 and snGuid = @SnGuid and Flag != 1        
		UPDATE #Result   SET ToDate = @Date, Flag = 1  WHERE Number  = @Number        
		SET @OldSnGuid = @SnGuid    
		FETCH NEXT FROM c_Result INTO @Date, @SnGuid, @Number    
	END       
	close c_Result     
	DEALLOCATE c_Result     
	---------------------------------------------------------    
	UPDATE #Result SET ToDate = @ToDate WHERE Flag = 0 AND Type = 0        
	-------------------------------------------------------     
	UPDATE #Result SET     
		FromDate = ADT.LastDepDate
	FROM #Result R     
		INNER JOIN @ADTbl ADT ON R.ADGuid = ADT.adGuid        
	WHERE R.FromDate <= ADT.LastDepDate --AND  Type = 1      
	---------------------------------------------------------            
	UPDATE #Result SET     
		FromDate = ADT.InDate    
	FROM #Result R     
		INNER JOIN @ADTbl ADT ON R.ADGuid = ADT.adGuid        
	WHERE R.FromDate <= ADT.InDate AND  Type = 0    

	---------------------------------------------------------    
	DELETE From #Result WHERE ToDate = '1980-01-01' 
	-----------------------------------------------------------------    

	DECLARE   A_Result CURSOR FOR     
	SELECT  SnGuid, Number, AddedVal,DeductVal    
	FROM            
		#Result    
	ORDER BY   SnGuid, FromDate 
	SET @OldSnGuid = 0x0     
	DECLARE @RASum FLOAT    
	DECLARE @RDSum FLOAT    
	DECLARE @PrevAdd FLOAT    
	SET @RASum = 0    
	SET @RDSum = 0    
	OPEN A_Result            
	FETCH NEXT FROM A_Result INTO @SnGuid, @Number, @AddedVal, @DeductVal    
	SET @OldSnGuid = @SnGuid
	WHILE @@FETCH_STATUS = 0            
	BEGIN        
  
		if (@OldSnGuid = @SnGuid )     
		BEGIN    
			SET @RASum  = @RASum + @AddedVal    
			SET @RDSum  = @RDSum + @DeductVal    
			Update #Result   SET AddedVal = @RASum, DeductVal = @RDSum WHERE Number  = @Number    
		END ELSE     
		BEGIN     
			SET @RASum = 0    
			SET @RDSum = 0    
		END    
		SET @OldSnGuid = @SnGuid     
		FETCH NEXT FROM A_Result INTO @SnGuid, @Number, @AddedVal, @DeductVal    
	END       
	close A_Result     
	DEALLOCATE A_Result   
 
-----------------------------------------------------------------    
	UPDATE R      
			SET     
			R.AddedVal = R.AddedVal + ISNULL( AdT.LastAddedVal, 0),           
			R.DeductVal = R.DeductVal +ISNULL( AdT.LastDeductVal, 0),    
			R.PrevDep = R.PrevDep + ISNULL( AdT.LastDepVal, 0)  + ISNULL( ddDeprecationVal, 0)			    
	FROM          
		#Result R     
		INNER JOIN Ad000 AD ON R.SNGuid = AD.SNGuid        
		INNER JOIN @ADTbl ADT ON AD.Guid = ADT.adGuid        
		LEFT JOIN (  SELECT ddADGUID AS AdGUID, SUM( ddValue) AS ddDeprecationVal FROM vwDD GROUP BY ddADGUID ) AS DP ON DP.AdGUID = AdT.AdGUID         
-----------------------------------------------------------------    
	Update #Result  SET AssVal = INValue + AddedVal  - DeductVal    
-----------------------------------------------------------------    
	Update R SET     
		CurrentDep =     
			CASE WHEN @CalcMethod = 0 THEN	     
				(CASE R.Life WHEN 0 THEN 0 ELSE DATEDIFF( DAY , FromDate, ToDate)*AssVal /(R.Life) END)
			ELSE     
				(CASE (R.Life) WHEN 0 THEN 0 
							ELSE 
							( CASE DATEDIFF( MONTH , dbo.fnAssetFixStartDeprDate(@CalcMethod, FromDate) , ToDate ) WHEN 0 THEN 1 ELSE DATEDIFF( MONTH , dbo.fnAssetFixStartDeprDate(@CalcMethod, FromDate) , ToDate) END*AssVal /(R.Life) )END )
			END    
	FROM #Result R INNER JOIN Ad000 ad On ad.Guid = R.AdGuid     
					INNER JOIN as000 ass On ad.ParentGuid = ass.Guid     
----------------------------------------------------------------    
	delete from #Result  where FromDate = Todate   
	DECLARE   F_Result CURSOR FOR     
	SELECT  Guid, SnGuid, CurrentDep    
	FROM            
		#Result    
	ORDER BY   SnGuid, FromDate    
	SET @OldSnGuid = 0x0     
	DECLARE @DepSum FLOAT,     
			@Dep FLOAT,     
			@F_Guid UNIQUEIDENTIFIER    
	SET @DepSum = 0    
	OPEN F_Result            
	FETCH NEXT FROM F_Result INTO @F_Guid, @SnGuid, @Dep    
	SET  @OldSnGuid = @SnGuid    
	WHILE @@FETCH_STATUS = 0            
	BEGIN           
		if (@OldSnGuid = @SnGuid )     
		BEGIN    
			SET @DepSum  = @DepSum + @Dep    
		END     
		ELSE     
		BEGIN    
			SET @DepSum = @Dep    
		END    
		--print @DepSum   
		Update #Result   SET TotalCurrentDep = @DepSum WHERE Guid  = @F_Guid    
		Update #Result SET CurrentDep =  CurrentDep + inValue + addedVal - DeductVal -	PrevDep - TotalCurrentDep,    
			   				TotalCurrentDep = TotalCurrentDep + inValue + addedVal - DeductVal -	PrevDep - TotalCurrentDep    
		WHERE (Guid  = @F_Guid) AND (inValue + addedVal - DeductVal -	PrevDep - TotalCurrentDep < 0)    
		SET @OldSnGuid = @SnGuid    
		FETCH NEXT FROM F_Result INTO @F_Guid, @SnGuid, @Dep    
	END       
	CLOSE F_Result     
	DEALLOCATE F_Result     
-----------------------------------------------     
DELETE FROM #Result WHERE CurrentDep < 0.01     
--------------------------------------------------  update store guid  
UPDATE #Result SET StoreGuid = (SELECT dbo.fnSNLastCheckStore(SNGUID, ToDate))
--------------------------------------------------    
	SELECT           
		AdTbl.AdGuid 		AS adGUID,          
		Snc.Sn + '-'+ CASE  [dbo].fnConnections_GetLanguage() WHEN  1  THEN CASE mt.LatinName  WHEN  '' THEN mt.[Name] END ELSE mt.[Name] END AS adCodeName,      
		co.coGUID 		AS AssCostGUID,          
		co.coCode + '-'+ CASE  [dbo].fnConnections_GetLanguage() WHEN  1  THEN CASE coLatinName  WHEN  '' THEN coName END ELSE coName END AS coCodeName,      
		Res.FromDate 		AS FromDate,          
		--(CASE WHEN @CalcMethod = 0 THEN Res.ToDate ELSE Res.ToDate - 1 END) 		AS ToDate, 
				Res.ToDate 		AS ToDate,            
		Snc.Sn 			AS Sn,          
		CASE @CalcMethod WHEN 0 THEN @YEARDAYS ELSE 12 END / Res.Life  AS Percentage,      
		Res.Life		AS Life,       
		CASE @CalcMethod WHEN 0 THEN DATEDIFF(DAY , Res.FromDate, Res.ToDate) ELSE CASE DATEDIFF(MONTH , dbo.fnAssetFixStartDeprDate(@CalcMethod, FromDate), Res.ToDate)  WHEN 0 THEN 1 ELSE DATEDIFF(MONTH , dbo.fnAssetFixStartDeprDate(@CalcMethod, FromDate), Res.ToDate) END END AS Cnt,      
		Res.AddedVal		AS AddedVal,          
		Res.DeductVal		AS DeductVal,          
		Res.PrevDep	AS PrevDep,      
		Res.StoreGUID,  
		st.stName StoreName,  
		res.TotalCurrentDep  AS TotalCurrentDep,    
		res.CurrentDep  AS CurrentDep,    
		(inValue + AdTbl.ScrapValue + addedVal - DeductVal -	PrevDep - TotalCurrentDep) AS CurrentAssetValue,          
		Res.InValue + AdTbl.ScrapValue	AS InValue,  
		AdTbl.ScrapValue	AS ScrapValue,      
		ad.adInCurrencyGUID	AS CurrencyGUID,          
		case ad.adInCurrencyGUID when 0x0 then '' else my.myCode end	AS Currency,      
		ad.adInCurrencyVal	AS CurrencyVal,
		ad.adNotes AS Notes ,
		Res.BranchGuid AS BrGuid,
		mt.GUID As MatGuid         
	FROM           
		@ADTbl AS AdTbl INNER join #Result Res ON Res.AdGuid = adTbl.adGuid    
						INNER JOIN vwAd AS ad ON AdTbl.AdGUID = ad.adGUID      
						INNER JOIN SNC000 AS snc ON snc.GUID = ad.adSnGUID      
						INNER JOIN vwAs AS Ass ON ad.adAssGUID = ass.asGUID      
						INNER JOIN mt000 AS mt ON ass.asParentGUID = mt.GUID      
						LEFT JOIN  vwco AS co ON co.coGUID = res.CostGUID      
						LEFT JOIN  vwst AS st ON st.stGUID = res.StoreGUID      
						INNER JOIN vwMy AS my ON my.myGUID = ad.adInCurrencyGUID 
						LEFT JOIN [#SNALLlastcheck]  AS  SNlastcheck ON SNlastcheck.SNGuid = ad.adSnGuid           
	WHERE       
		DATEDIFF( Day , Res.FromDate, Res.ToDate) > 0   --and  (adStatus = 1)     
	ORDER BY      
		Len(SNC.SN), SNC.SN, Res.FromDate     
-----------------------------------------------     
	DROP TABLE #Mat        
	DROP TABLE #Cost    
	DROP TABLE #Store    
	DROP TABLE #Result        
	DROP table #T   
/*   
select * from vwst 
exec repDeprecationAssets     
		'6-1-2008', --toDate       
		'0899B3FC-297E-437B-BD02-0550FE04606A', --@AssGUID UNIQUEIDENTIFIER,         
		0x0, --@GrpGUID UNIQUEIDENTIFIER,         
		'68D98F49-509C-4BC4-8A2D-4FFED0CBA1E1', --@CurGUID UNIQUEIDENTIFIER,         
		1, --@CurVal  FLOAT,         
		0x0, --@CostGUID UNIQUEIDENTIFIER,         
		0x0, --'0EC41159-3D0C-4162-97DA-B0C0E15747DC', --'4E76FF55-1248-488F-B15E-995F78F91409', --@StoreGUID UNIQUEIDENTIFIER,         
		1,--@TypeAction INT,      
		0x0, --@BranchGuid UNIQUEIDENTIFIER,      
		0,--@BranchMask BIGINT ,     
		1--@CalcMethod INT = 0    
select * from Mt000  
select * from st000  
select * from My000  
*/
########################################################################
CREATE PROC PrcAssetDeleteDep  @GUID UNIQUEIDENTIFIER 
As 
	DECLARE @EntryGuid UNIQUEIDENTIFIER
	SELECT @EntryGuid = EntryGuid FROM dp000 WHERE Guid  = @GUID 
	DELETE FROM dd000 WHERE ParentGuid  = @GUID 
	DELETE FROM dp000 WHERE Guid  = @GUID 
	DELETE [er000] WHERE [ParentGuid] = @EntryGuid
	DELETE py000 WHERE Guid = @EntryGuid
########################################################################
CREATE FUNCTION fnAssetRoundToNextMonth(@CalcMethod int ,  @axDate DATETIME) 
RETURNS DATETIME 
AS 
BEGIN 
	DECLARE @D DATETIME  
	IF(@CalcMethod = 0)  
		SET @D = @axDate 
	ELSE 
	BEGIN 
		SET @D = @axDate
		WHILE ( DATEPART( DAY , @D) <> 1)
		BEGIN
				SET @D =  DATEADD(DAY , 1 , @D)
		END
	END 
	RETURN @D 
END
########################################################################
CREATE FUNCTION fnAssetFixStartDeprDate(@CalcMethod int ,  @axDate DATETIME) 
RETURNS DATETIME 
AS 
BEGIN 
	DECLARE @D DATETIME  
	IF(@CalcMethod = 0)  
		SET @D = @axDate 
	ELSE 
	BEGIN 
		SET @D = @axDate
		IF ( DATEPART( DAY , @D) = 1)
		BEGIN 
			SET @D =  DATEADD(DAY , -1 , @D)
		END
	END 
	RETURN @D 
END
########################################################################
#END