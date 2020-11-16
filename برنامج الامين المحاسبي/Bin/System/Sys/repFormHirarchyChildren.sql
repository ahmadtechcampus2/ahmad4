###########################################################
###fnGetUserFormSec_BrowseFunction
###########################################################
CREATE FUNCTION fnGetUserFormSec_Browse (@UserGUID [UNIQUEIDENTIFIER]) 
	RETURNS [INT] 
AS BEGIN 
	RETURN [dbo].[fnGetUserFormSec](@UserGUID, 1) 
END 
###########################################################
###repFormListFunction
###########################################################
CREATE FUNCTION fnGetFormList ( @FMGUID [UNIQUEIDENTIFIER], @Sorted [INT] = 0 /* 0: without sort, 1:Sort By Cod, 2:Sort By Name*/)  
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0, [Path] [VARCHAR](8000) COLLATE ARABIC_CI_AI)   
AS BEGIN  
	
		DECLARE @FatherBuf_S	TABLE([GUID] [UNIQUEIDENTIFIER],  [Level] [INT], [Path] [VARCHAR](8000) COLLATE ARABIC_CI_AI, [ID] [INT] IDENTITY( 1, 1))    
		DECLARE  @Continue_S [INT], @Level_S [INT]   
		SET @Level_S = 0    
		   
		SET @FMGUID = ISNULL(@FMGUID, 0x0)    
		IF @FMGUID = 0x0    
		BEGIN  
			INSERT INTO @FatherBuf_S ( [GUID], [Level], [Path]) SELECT [fm1].[GUID], @Level_S, ''  FROM [fm000] [fm1] WHERE ( ISNULL( [fm1].[ParentForm], 0x0) = 0x0 )  ORDER BY CASE @Sorted WHEN 1 THEN [Code] ELSE [Name] END   
			INSERT INTO @fatherBuf_s ( [GUID], [Level], [Path]) SELECT [fm1].[GUID],  @Level_S, ''   
			FROM   
				[fm000] [fm1]  
				LEFT JOIN [fm000] [fm2] ON [fm1].[ParentForm] = [fm2].[GUID]  
				LEFT JOIN @fatherBuf_s [f] ON [fm1].[GUID] = [f].[Guid]   
			WHERE   
				ISNULL( [fm1].[ParentForm], 0x0) != 0x0  
				AND [fm2].[GUID] IS NULL  
				AND [f].[Guid]IS NULL  
			ORDER BY   
				CASE @Sorted WHEN 1 THEN [fm1].[Code] ELSE [fm1].[Name] END  
		END  
		ELSE    
			INSERT INTO @FatherBuf_S ([GUID] , [Level], [Path]) SELECT [GUID], @Level_S, '' FROM [fm000] WHERE [GUID] = @FMGUID ORDER BY CASE @Sorted WHEN 1 THEN [Code] ELSE [Name] END   
		   
		UPDATE @FatherBuf_S  SET [Path] = CAST( ( 0.0000001 * ID) AS [VARCHAR](40))    
	   
		SET @Continue_S = 1    
		 
			WHILE @Continue_S <> 0    
			BEGIN    
				SET @Level_S = @Level_S + 1    
				INSERT INTO @FatherBuf_S([GUID],[Level],[Path])   
					SELECT   
						[fm].[GUID], @Level_S,[fb].[Path]   
					FROM   
						[fm000] AS [fm] INNER JOIN @FatherBuf_S AS [fb]   
						ON [fm].[ParentForm] = [fb].[GUID]    
					WHERE   
						[fb].[Level] = @Level_S - 1    
					ORDER BY   
						CASE @Sorted WHEN 1 THEN [Code] ELSE [Name] END   
				SET @Continue_S = @@ROWCOUNT    
				UPDATE @FatherBuf_S  SET [Path] = [Path] + CAST( ( 0.0000001 * [ID]) AS VARCHAR(40))  WHERE [Level] = @Level_S  
			END    
		 
		 
		INSERT INTO @Result SELECT [GUID], [Level], [Path] FROM @FatherBuf_S GROUP BY [GUID], [Level], [Path] ORDER BY [Path]  
	RETURN   
END 

###########################################################
###repFormHirarchyChildren 
###########################################################
CREATE PROCEDURE repFormHirarchyChildren 
	@FormGuid				  [UNIQUEIDENTIFIER] = 0x0,
	@ReadyGroupGuid 		  [UNIQUEIDENTIFIER] = 0x0,
	@RawGroupGuid 			  [UNIQUEIDENTIFIER] = 0x0,
	@CostGuid				  [UNIQUEIDENTIFIER] = 0x0,
	@ShowSemiManufMatForms	  INT      ,
	@SortType				  INT     ,
	@PriceType				  INT     ,
    @ShwExtraCost             INT
	
AS   
	SET NOCOUNT ON   
--------------------------------------------------------------
/*
DECLARATON 
*/	
   DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();
   DECLARE @COUNT INT 
   SET @ReadyGroupGuid = ISNULL(@ReadyGroupGuid, 0x0) 
	SET @RawGroupGuid = ISNULL(@RawGroupGuid, 0x0) 
	SET @CostGuid  = ISNULL(@CostGuid, 0x0)
	SET @FormGuid  = ISNULL(@FormGuid, 0x0)


	CREATE TABLE #RawMatTbl (
		FormGuid UNIQUEIDENTIFIER , --the GUID of Form
		ParentGuid UNIQUEIDENTIFIER , --the GUID of ManufacturedForm
		RawMatGUID UNIQUEIDENTIFIER , --the GUID of SemiMaterials
		FmNumber   INT --the Number Of Form 
	)
---------------------/* Insert  INTO RawMatTbl */---------------------	
	INSERT INTO #RawMatTbl 
       SELECT    mn.FormGuid as FormGuid,mn2.FormGUID as ParentGuid,mi1.MatGUID as MatGuid, fm.Number  
			FROM FM000 fm 
			     INNER JOIN [mn000] mn ON mn.FormGuid = fm.Guid 
				 INNER JOIN [mi000]  mi ON [mn].[Guid] = [mi].[parentguid]  
	             INNER JOIN  MI000 mi1 ON   mi1.MatGUID = mi.MatGUID
				 INNER JOIN  MN000 mn2 ON mn2.Guid = mi1.ParentGUID
				 INNER Join  FM000 fm2 ON fm2.Guid = mn2.FormGuid 
				 INNER JOIN  [mt000] mt ON mt.Guid = mi.MatGuid /* «·„«œ… „’‰⁄… */
				 INNER JOIN  GR000 Gr ON  Gr.Guid = mt.GroupGuid 
	        WHERE 
		      mi.type = 0 
			  AND
			  mi1.Type = 1 
			  AND
			  mn.type = 0 
			  AND
			  mn2.type = 0 
			  AND (mt.GroupGuid =(CASE mi.type WHEN 0 THEN  
										 mt.GroupGUID
												WHEN 1 THEN  
									(CASE @RawGroupGuid WHEN 0x0 THEN mt.GroupGUID ELSE @RawGroupGuid END ) END)
			  OR  gr.ParentGuid =(CASE mi.type WHEN 0 THEN  
												gr.ParentGUID
												WHEN 1 THEN  (CASE @RawGroupGuid WHEN 0x0 THEN gr.ParentGuid ELSE @RawGroupGuid END ) END)  
				   )
			GROUP BY mn2.FormGUID ,mi1.MatGUID,mn.FormGuid, fm.Number 
			ORDER BY fm.Number DESC 

	
--------------------------------------------------------------	 
/*
 ÕœÌœ „—«ﬂ“ «·ﬂ·›
*/
	CREATE TABLE #CostTbl( Guid UNIQUEIDENTIFIER, Security INT)   
 	IF (@CostGUID = 0x0)	  
	BEGIN 
		INSERT INTO #CostTbl SELECT mn.InCostGUID, Co.coSecurity 
				FROM vwCo Co , MN000 mn 
				GROUP BY mn.InCostGUID, Co.coSecurity 
	END 
	ELSE 
		INSERT INTO #CostTbl EXEC prcGetCostsList @CostGuid
---------------------/* Insert  INTO Result( FROM) */---------------------	
    CREATE TABLE [#Result](
			[Type]			[INT], -- All
			[Guid]			[UNIQUEIDENTIFIER], -- All
			[ParentGuid] 	[UNIQUEIDENTIFIER], -- All
			[Name]			[VARCHAR](250) COLLATE ARABIC_CI_AI, -- All
			[MatOrAccType]  [INT], -- Materials List And Accounts List
			[CurrenyVal]    [FLOAT], -- Materials List And Accounts List
			[Code]			[VARCHAR](250) COLLATE ARABIC_CI_AI, -- Only For Forms
			[PhaseNumber]   [INT],
			[CostCenter]    NVARCHAR(255),
			[OutCostCenter] NVARCHAR(255),
			[Percentage]	[FLOAT],
			[ReadyMatGUID]  [UNIQUEIDENTIFIER], 
			[Origin] 	    [VARCHAR](250) COLLATE ARABIC_CI_AI, -- Only Fr Main Material Info
			[Company]		[VARCHAR](250) COLLATE ARABIC_CI_AI, -- Only Fr Main Material Info 
			[Pos]			[VARCHAR](250) COLLATE ARABIC_CI_AI, -- Only Fr Main Material Info 
			[Dim]			[VARCHAR](250) COLLATE ARABIC_CI_AI, -- Only Fr Main Material Info 
			[Color]			[VARCHAR](250) COLLATE ARABIC_CI_AI, -- Only Fr Main Material Info 
			[Provenance]	[VARCHAR](250) COLLATE ARABIC_CI_AI, -- Only Fr Main Material Info 
			[Quality]		[VARCHAR](250) COLLATE ARABIC_CI_AI, -- Only Fr Main Material Info 
			[Model]			[VARCHAR](250) COLLATE ARABIC_CI_AI, -- Only Fr Main Material Info 
			[Price]			[FLOAT], -- Only For Materials List
			[Qty]			[FLOAT], -- Only For Materials List 
			[Unitno]		[INT], -- Only For Materials List 
			[Unity]	        [VARCHAR](100) COLLATE ARABIC_CI_AI, -- Only For Materials List 
			[Unit2]			[VARCHAR](100) COLLATE ARABIC_CI_AI, -- Only For Materials List 
			[Unit2fact]		[FLOAT], -- Only For Materials List 
			[Unit3]			[VARCHAR](100) COLLATE ARABIC_CI_AI, -- Only For Materials List 
			[Unit3fact]		[FLOAT], -- Only For Materials List 
			[Extra]			[FLOAT], -- Only For Accounts List
			[Discount]		[FLOAT], -- Only For Accounts List
			[Notes]			[VARCHAR](250) COLLATE ARABIC_CI_AI, -- Only For Accounts List
			[Total]	        [FLOAT], -- Only For Accounts List
			[Costname]		[VARCHAR](250) COLLATE ARABIC_CI_AI, -- Only For Accounts List 
			[Curname]		[VARCHAR](250) COLLATE ARABIC_CI_AI, -- Only For Accounts List	
			[MtSecurity] 	[INT],
			[AccSecurity]   [INT],
			[fmSecurity]    [INT]
			)

	
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]);   
	CREATE TABLE [#FormsList](   
			[Guid]			[UNIQUEIDENTIFIER],   
			) 
-- return list of forms under the selected form				 
-- return the main material information of the selected form 
	CREATE TABLE [#MatTbl]( [MatGUIDg] [UNIQUEIDENTIFIER], [mtSecurity] [INT])
		INSERT INTO [#MatTbl] EXEC [prcGetMatsList] 0x0, 0x0, 0x0,0x0
		     
	CREATE TABLE [#ACCTbl]( [AccGUIDg] [UNIQUEIDENTIFIER], [accSecurity] [INT], [level] [INT])
		INSERT INTO  [#ACCTbl] EXEC [prcGetAccountsList] 0x0 
	
	INSERT INTO [#Result]   
			SELECT
			1    
			,[fm].[fmGUID] 
			,NULL
			,CASE WHEN @lang > 0 THEN CASE WHEN [fm].[fmLatinName] = '' THEN  [fm].[fmName] ELSE [fm].[fmLatinName] END ELSE [fm].[fmName] END 
			,NULL
			,NULL
			,[fm].[fmCode]  --FormCode
			,mn.PhaseNumber
			, CASE WHEN @lang > 0 THEN CASE WHEN co.[coLatinName] = '' THEN  co.coName ELSE co.[coLatinName] END ELSE co.[coName] END 
			, CASE WHEN @lang > 0 THEN CASE WHEN co1.[coLatinName] = '' THEN  co1.coName ELSE co1.[coLatinName] END ELSE co1.[coName] END
			,0 --11
			,NULL --12
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL   
			,0
			,0
			,[fm].[fmSecurity]
			FROM   
				[vwFm] as [fm] 
				INNER JOIN [fnGetFormList](  @FormGuid , 1) AS [fn]   
					ON [fm].[fmGuid] = [fn].[Guid]  
                INNER JOIN MN000 MN 
				   ON  [fm].[fmGuid] = [mn].[FormGUID]
				INNER JOIN #CostTbl Cost 
				   ON Cost.GUID = [mn].[InCostGUID]
				INNER JOIN MI000 MI 
				  ON MI.ParentGUID = MN.Guid
				INNER JOIN mt000 MT 
				  ON Mt.GUID = MI.MatGUID  
				INNER JOIN Gr000 gr on gr.guid = mt.GroupGuid
				LEFT JOIN vwco co ON co.coGUID = mn.InCostGUID
				LEFT JOIn vwco co1 ON co1.coGuid = mn.OutCostGuid 
					WHERE ([fm].[fmGUID] = @FormGuid or @FormGuid = 0x0) 
					   AND (@ReadyGroupGuid = mt.GroupGuid OR @ReadyGroupGuid = Gr.ParentGuid OR @ReadyGroupGuid = 0x0 )
					   AND [mn].[Type]=0 AND [mi].[type]=0 
				GROUP BY fm.fmGUID, fm.fmCode ,CASE WHEN @lang > 0 THEN CASE WHEN [fm].[fmLatinName] = '' THEN  [fm].[fmName] ELSE [fm].[fmLatinName] END ELSE [fm].[fmName] END ,mn.PhaseNumber, CASE WHEN @lang > 0 THEN CASE WHEN co.[coLatinName] = '' THEN  co.coName ELSE co.[coLatinName] END ELSE co.[coName] END  ,CASE WHEN @lang > 0 THEN CASE WHEN co1.[coLatinName] = '' THEN  co1.coName ELSE co1.[coLatinName] END ELSE co1.[coName] END ,[fm].[fmSecurity] 
				
	   EXEC [prcCheckSecurity] 
        
		
		INSERT INTO [#FormsList]   
			SELECT    [form].[Guid]   
			FROM  #Result as [form]
			
			
			
	if (@ShowSemiManufMatForms = 1)
		BEGIN 

		CREATE TABLE #SemiForms ( SemiFormGuid UNIQUEIDENTIFIER ) 
		CREATE TABLE #Forms ( FORMGUID UNIQUEIDENTIFIER ) 
		INSERT INTO #Forms
			 SELECT distinct rawTb.FormGuid as FormGuid 
				From 
				     #RawMatTbl rawTb INNER JOIN fm000 fm ON fm.guid = rawtb.formguid and @FormGuid = rawTb.ParentGuid
					 
					 

			
			   
      DECLARE @COUNTER INT 
	  
	  SET @COUNTER = (SELECT COUNT(*) FROM #Forms)

	  
	 
	  DECLARE @SemiFormGuid UNIQUEIDENTIFIER 
	  SET @SemiFormGuid = (SELECT top 1 FORMGUID FROM #Forms)

	  WHILE (@COUNTER > 0)
	  BEGIN	
	   
	    INSERT INTO [#Result]   
			SELECT
			1    
			,[fm].[fmGUID]
			,NULL
			, CASE WHEN @lang > 0 THEN CASE WHEN [fm].[fmLatinName] = '' THEN  [fm].[fmName] ELSE [fm].[fmLatinName] END ELSE [fm].[fmName] END 
			,NULL
			,NULL
			,[fm].[fmCode]
			,mn.PhaseNumber
			, CASE WHEN @lang > 0 THEN CASE WHEN co.[coLatinName] = '' THEN  co.coName ELSE co.[coLatinName] END ELSE co.[coName] END 
			, CASE WHEN @lang > 0 THEN CASE WHEN co1.[coLatinName] = '' THEN  co1.coName ELSE co1.[coLatinName] END ELSE co1.[coName] END
			,0 --11
			,NULL --12
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL   
			,0
			,0
			,[fm].[fmSecurity]
			FROM   
				[vwFm] as [fm] 
				INNER JOIN [fnGetFormList](  @SemiFormGuid , 1) AS [fn]   
					ON [fm].[fmGuid] = [fn].[Guid]  
                INNER JOIN MN000 MN 
				   ON  [fm].[fmGuid] = [mn].[FormGUID]
				INNER JOIN #CostTbl Cost 
				   ON Cost.GUID = [mn].[InCostGUID]
				INNER JOIN MI000 MI 
				  ON MI.ParentGUID = MN.Guid
				INNER JOIN mt000 MT 
				  ON Mt.GUID = MI.MatGUID  
				INNER JOIN Gr000 gr on gr.guid = mt.GroupGuid
				LEFT JOIN vwco co ON co.coGUID = mn.InCostGUID
				LEFT JOIn vwco co1 ON co1.coGuid = mn.OutCostGuid 
			WHERE ([fm].[fmGUID] = @SemiFormGuid)
				  AND [mn].[Type] = 0 AND [mi].[type] = 0 
				  AND (@ReadyGroupGuid = mt.GroupGuid  OR  @ReadyGroupGuid = Gr.ParentGuid OR @ReadyGroupGuid = 0x0 )
            GROUP BY fm.fmGUID, fm.fmCode ,CASE WHEN @lang > 0 THEN CASE WHEN [fm].[fmLatinName] = '' THEN  [fm].[fmName] ELSE [fm].[fmLatinName] END ELSE [fm].[fmName] END , mn.PhaseNumber,
						CASE WHEN @lang > 0 THEN CASE WHEN co.[coLatinName] = '' THEN  co.coName ELSE co.[coLatinName] END ELSE co.[coName] END ,
						CASE WHEN @lang > 0 THEN CASE WHEN co1.[coLatinName] = '' THEN  co1.coName ELSE co1.[coLatinName] END ELSE co1.[coName] END ,[fm].[fmSecurity]    

	INSERT INTO #SemiForms
	SELECT distinct rawTb.FormGuid as SemiFormGuid 
			From #RawMatTbl rawTb INNER JOIN fm000 fm ON fm.guid = rawtb.formguid and @SemiFormGuid = rawTb.ParentGuid
	WHERE fm.GUID not in  (SELECT GUID FROM #Result WHERE Type = 1 )

	
	INSERT INTO #Forms
	SELECT distinct SemiFormGuid 
		FROM #SemiForms	

		delete FROM #Forms  
			WHERE FORMGUID = @SemiFormGuid
		delete FROM #SemiForms WHERE SemiFormGuid = @SemiFormGuid
		SET @SemiFormGuid = (SELECT top 1 FORMGUID FROM #Forms )
	
    EXEC [prcCheckSecurity] 
	
	 SET @COUNTER = (SELECT COUNT(*) FROM #Forms) 
	
	END 
		INSERT INTO [#FormsList]   
			SELECT    
			[form].[Guid]   
			FROM  #Result as [form]
         END 

        INSERT INTO [#Result]
	    SELECT 
			2
			,NULL
			,NULL
			,CASE WHEN @lang > 0 THEN CASE WHEN [mt000].[LatinName] = '' THEN  [mt000].[name] ELSE [mt000].[LatinName] END ELSE [mt000].[Name] END 
			,NULL
			,NULL
			,NULL
			,0
			,NULL
			,NULL
			,0 --11
			,NULL --12
			,[origin] 
			,[company] 
			,[pos] 
			,[dim] 
			,[color] 
			,[provenance] 
			,[quality] 
			,[model]  
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,0
			,0
			,0
		FROM [mi000]  
		INNER JOIN [mn000] ON [mn000].[Guid] = [mi000].[parentguid] 
		INNER JOIN [fm000] ON [fm000].[Guid] = [mn000].[FormGuid] 
		INNER JOIN [mt000] ON [mt000].[Guid] = [mi000].[matGuid]
		INNER JOIN GR000 GR ON GR.GUID = [mt000].GroupGuid
	WHERE ([fm000].[guid] = @FormGuid or @FormGuid = 0x0) AND [mn000].[Type]=0 
		  AND [mi000].[type]=0 
		  



    INSERT INTO [#Result]
	SELECT 
			3
			,Null
			,[fm000].[GUID] 
			,CASE WHEN @lang > 0 THEN CASE WHEN [mt000].[LatinName] = '' THEN  [mt000].[name] ELSE [mt000].[LatinName] END ELSE [mt000].[Name] END 
			,[mi000].[Type]
			,[mi000].[currencyval]  
			,NULL
			,0
			,NULL
			,NULL
			,[mi000].[percentage]
			,[mi000].[ReadyMatGUID]
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			, CASE [mi000].type 
						WHEN 1 THEN (CASE @PriceType WHEN 0 THEN [mi000].Price 
										 WHEN 1 THEN [mt000].AvgPrice * [mi000].CurrencyVal
										 ELSE [mt000].LastPrice * [mi000].CurrencyVal
									END) 
						WHEN 0 THEN ( select [dbo].[fnReCalcPrices]( [fm000].[Guid], @ReadyGroupGuid, @RawGroupGuid, [mi000].MatGuid,@PriceType, @ShwExtraCost) )
			  END  
			,[mi000].[Qty] 
			,[mi000].[unity] 
			,[mt000].[Unity] 
			,[mt000].[Unit2] 
			,[mt000].[Unit2fact] 
			,[mt000].[Unit3] 
			,[mt000].[Unit3fact] 
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,[mat].mtSecurity
			,0
			,0
		FROM [mi000]  
		INNER JOIN [mn000] ON [mn000].[Guid] = [mi000].[parentguid] AND [mn000].[type]=0  
		INNER JOIN [fm000] ON [fm000].[Guid] = [mn000].[FormGuid] 
		INNER JOIN [mt000] ON [mt000].[Guid] = [mi000].[matGuid] 
		INNER JOIN [#MatTbl] AS [mat] ON [mt000].[Guid] = [mat].MatGUIDg 
		INNER JOIN GR000 GR ON GR.GUID = [mt000].GroupGuid
		WHERE ([fm000].[guid] in ( SELECT [Guid] FROM [#FormsList] ) OR @FormGuid = 0x0) AND [mn000].[Type]=0 
		      AND 
			  (mt000.GroupGuid =(CASE mi000.type WHEN 0 THEN 
													mt000.GroupGUID
												 WHEN 1 THEN  
													(CASE @RawGroupGuid WHEN 0x0 THEN mt000.GroupGuid ELSE @RawGroupGuid END ) 
								 END)
              OR 
				GR.ParentGUID =(CASE mi000.type WHEN 0 THEN  
												  gr.ParentGUID
												WHEN 1 THEN 
													(CASE @RawGroupGuid WHEN 0x0 THEN GR.ParentGUID ELSE @RawGroupGuid END ) 
							    END)
				)
			
	INSERT INTO [#Result]
	SELECT 	
			4
			,NULL
			,[fm000].[GUID]
			,CASE WHEN @lang > 0 THEN CASE WHEN [ac000].[LatinName] = '' THEN  [ac000].[name] ELSE [ac000].[LatinName] END ELSE [ac000].[Name] END  
			,[mx000].[type] 
			,[mx000].[CurrencyVal]
			,NULL
			,0
			,NULL
			,NULL
			,0
			,[mx000].[ReadyMatGUID]
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,[mx000].[Extra]  / [mx000].[CurrencyVal]
			,[mx000].[Discount] 
			,[mx000].[Notes] 
			,[mx000].[CurrencyVal]*[mx000].[Extra] AS [total] 
			, CASE WHEN @lang > 0 THEN CASE WHEN [co000].[LatinName] = '' THEN  [co000].[name] ELSE [co000].[LatinName] END ELSE [co000].[name] END [costname] 
			, CASE WHEN @lang > 0 THEN CASE WHEN [my000].[LatinName] = '' THEN  [my000].[name] ELSE [my000].[LatinName] END ELSE [my000].[name] END [curname]  
			,0
			,[acc].[accSecurity]
			,0
		FROM [mn000] 
		INNER JOIN [fm000] ON [fm000].[Guid] = [mn000].[FormGuid] 
		INNER JOIN [mx000] ON [mn000].[GUID] = [mx000].[parentGUID] 
		INNER JOIN [ac000] ON [ac000].[GUID] = [mx000].[AccountGUID]
		INNER JOIN [#AccTbl] AS [acc] ON [acc].[AccGUIDg] = [ac000].[GUID]
		LEFT JOIN  [co000] ON [co000].[GUID] = [mx000].[CostGUID] 
		LEFT JOIN  [my000] ON [my000].[GUID] = [mx000].[CurrencyGUID]	  
	WHERE ([fm000].[guid] IN ( SELECT [Guid] FROM [#FormsList] ) OR @FormGuid = 0x0) 
		  AND 
		  [mn000].[Type]=0 
	  
	  
	DELETE FROM #result WHERE  Guid not in( SELECT res.ParentGuid FROM #Result res,#Result res1  
	WHERE res.type = 3 AND res.MatOrAccType = 1 
		  AND res1.type = 1 AND res1.Guid = res.Parentguid 

	)
		 
		 
   EXEC [prcCheckSecurity]
   
   
   SET @COUNT = (select COUNT(Guid)  From [#Result]  WHERE type = 1  ANd Guid <> 0x0 )
    IF ( @COUNT > 0 ) 
	
		SELECT 
		ISNULL([Type],-1)				AS Type,
		ISNULL([Guid],0x0)				AS Guid,
		ISNULL([ParentGuid],0x0)		AS ParentGuid,
		ISNULL([Name],'')				AS Name,
		ISNULL([MatOrAccType],-1)		AS MatOrAccType,
		ISNULL([CurrenyVal],0)			AS CurrenyVal,
		ISNULL([Code],'')				AS Code,
		ISNULL([PhaseNumber],-1)		AS PhaseNumber,
		ISNULL([CostCenter],'')			AS CostCenter,
		ISNULL([OutCostCenter],'')		AS OutCostCenter,
		ISNULL([Percentage],0)			AS Percentage,
		ISNULL([ReadyMatGUID],0x0)		AS ReadyMatGUID,
		ISNULL([Origin],'')				AS Origin, 	    
		ISNULL([Company],'')			AS Company,		
		ISNULL([Pos],'')				AS Pos,			
		ISNULL([Dim],'')				AS Dim,			
		ISNULL([Color],'')				AS Color,			
		ISNULL([Provenance],'')			AS Provenance,	
		ISNULL([Quality],'')			AS Quality,		
		ISNULL([Model],'')				AS Model,			
		ISNULL([Price],0)				AS Price,
		ISNULL([Qty],0)					AS Qty,
		ISNULL([Unitno],-1)				AS Unitno,
		ISNULL([Unity],'')				AS Unity,
		ISNULL([Unit2],'')				AS Unit2,
		ISNULL([Unit2fact],0)			AS Unit2fact,
		ISNULL([Unit3],'')				AS Unit3,
		ISNULL([Unit3fact],0)			AS Unit3fact,
		ISNULL([Extra],0)				AS Extra,
		ISNULL([Discount],0)			AS Discount,
		ISNULL([Notes],'')				AS Notes,
		ISNULL([Total],0)				AS Total,
		ISNULL([Costname],'')			AS Costname,
		ISNULL([Curname],'')			AS Curname,
		ISNULL([MtSecurity],-1)			AS MtSecurity,
		ISNULL([AccSecurity],-1)		AS AccSecurity,
		ISNULL([fmSecurity],-1)			AS fmSecurity
		FROM [#Result] res 
		ORDER BY res.type, (CASE @SortType WHEN 0 THEN res.Code END),CASE @SortType WHEN 1 THEN res.PhaseNumber END DESC ,CASE @SortType WHEN 2 THEN res.PhaseNumber END ASC 
	ELSE 
	 BEGIN 
		DELETE FROM [#Result]
		SELECT
		ISNULL([Type],-1)				AS Type,
		ISNULL([Guid],0x0)				AS Guid,
		ISNULL([ParentGuid],0x0)		AS ParentGuid,
		ISNULL([Name],'')				AS Name,
		ISNULL([MatOrAccType],-1)		AS MatOrAccType,
		ISNULL([CurrenyVal],0)			AS CurrenyVal,
		ISNULL([Code],'')				AS Code,
		ISNULL([PhaseNumber],-1)		AS PhaseNumber,
		ISNULL([CostCenter],'')			AS CostCenter,
		ISNULL([OutCostCenter],'')		AS OutCostCenter,
		ISNULL([Percentage],0)			AS Percentage,
		ISNULL([ReadyMatGUID],0x0)		AS ReadyMatGUID,
		ISNULL([Origin],'')				AS Origin, 	    
		ISNULL([Company],'')			AS Company,		
		ISNULL([Pos],'')				AS Pos,			
		ISNULL([Dim],'')				AS Dim,			
		ISNULL([Color],'')				AS Color,			
		ISNULL([Provenance],'')			AS Provenance,	
		ISNULL([Quality],'')			AS Quality,		
		ISNULL([Model],'')				AS Model,			
		ISNULL([Price],0)				AS Price,
		ISNULL([Qty],0)					AS Qty,
		ISNULL([Unitno],-1)				AS Unitno,
		ISNULL([Unity],'')				AS Unity,
		ISNULL([Unit2],'')				AS Unit2,
		ISNULL([Unit2fact],0)			AS Unit2fact,
		ISNULL([Unit3],'')				AS Unit3,
		ISNULL([Unit3fact],0)			AS Unit3fact,
		ISNULL([Extra],0)				AS Extra,
		ISNULL([Discount],0)			AS Discount,
		ISNULL([Notes],'')				AS Notes,
		ISNULL([Total],0)				AS Total,
		ISNULL([Costname],'')			AS Costname,
		ISNULL([Curname],'')			AS Curname,
		ISNULL([MtSecurity],-1)			AS MtSecurity,
		ISNULL([AccSecurity],-1)		AS AccSecurity,
		ISNULL([fmSecurity],-1)			AS fmSecurity 
		FROM [#Result] res 
	END

SELECT * FROM [#SecViol]
###########################################################
CREATE  FUNCTION  fnReCalcPrices
(
	@FormGuid UNIQUEIDENTIFIER,
	@ReadyGroupGuid UNIQUEIDENTIFIER,
	@RawGroupGuid UNIQUEIDENTIFIER,
	@ReadyMatGuid UNIQUEIDENTIFIER,
	@PriceType INT,
	@ShwExtraCost   INT
)
RETURNS FLOAT
AS
BEGIN
	DECLARE @TotalMatPrices  FLOAT
	DECLARE @TotalCostPrice FLOAT 
	DECLARE @TotalPrice FLOAT 
	DECLARE @Temp FLOAT 
	DECLARE @TotalLinkedMatPrices  FLOAT 
	DECLARE @TotalLinkedCostPrice FLOAT 
	DECLARE @TotalLinkedPrice FLOAT
	DECLARE @Result FLOAT  
	
	SET   @TotalMatPrices = (SELECT [dbo].[fnGetMatPrice] (@FormGuid, @RawGroupGuid, @PriceType ) )
	IF(@ShwExtraCost = 1)
	SET   @TotalCostPrice =  (SELECT [dbo].[fnGetUnit_TotalCostPrice] (@FormGuid, @RawGroupGuid ))
	ELSE
	     SET   @TotalCostPrice = 0
    SET @TotalPrice = ISNULL((@TotalMatPrices +@TotalCostPrice),0) 
	SET @Temp = (@TotalPrice * (SELECT   Percentage FROM mi000 mi 
										INNER JOIN mn000 mn on mn.guid = mi.parentGuid 
										INNER JOIN fm000 fm on fm.guid = mn.FormGuid 
WHERE  mn.FormGuid =@FormGuid ANd mi.type=0 
										        AND  mn.type = 0
										AND mi.MatGUID = @ReadyMatGuid
										)) / 100
	SET  @TotalLinkedMatPrices= (SELECT [dbo].[fnGetLinkedMatPrice] (@FormGuid, @RawGroupGuid,@ReadyMatGuid, @PriceType))   
	IF(@ShwExtraCost = 1)
	SET   @TotalLinkedCostPrice = (SELECT [dbo].[fnGetLinkedUnit_TotalCostPrice] (@FormGuid, @RawGroupGuid,@ReadyMatGuid) )  
	 ELSE
	     SET   @TotalLinkedCostPrice = 0
	SET @TotalLinkedPrice =(ISNULL(@TotalLinkedMatPrices,0 ) + ISNULL(@TotalLinkedCostPrice,0)) 
	SET @Result = (ISNULL(@Temp, 0) + @TotalLinkedPrice) / 
	 (SELECT  mi.Qty 
	 FROM mi000 mi INNER JOIN mn000 mn on mn.Guid = mi.ParentGuid 
				   INNER JOIN fm000 fm on fm.Guid = mn.FormGuid 
	where  mn.FormGuid = @FormGuid and mi.MatGuid = @ReadyMatGuid 
					AND mi.Type = 0 AND mn.type = 0 )
	
  RETURN ISNULL(@Result,0 )
END
###########################################################
CREATE function  fnGetMatPrice
(
    @FormGuid UNIQUEIDENTIFIER ,
	@RawGroupGuid UNIQUEIDENTIFIER ,
	@PriceType INT 
)
RETURNS FLOAT
AS
BEGIN 
DECLARE @Result FLOAT 
SELECT
     @Result =  IsNull(SUM(((CASE @PriceType WHEN 0 THEN [mi].Price 
										 WHEN 1 THEN [mt].AvgPrice * mi.CurrencyVal
										 ELSE [mt].LastPrice * mi.CurrencyVal
						END) ) * mi.Qty) , 0) 
						
	FROM 
		FM000 fm INNER JOIN MN000 mn ON mn.FormGUID = fm.Guid 
				 INNER JOIN MI000 mi ON mi.ParentGuid = mn.Guid 
				 INNER JOIN MI000 mi2 ON mi2.ParentGuid = mn.Guid  
				 INNER JOIN mt000 mt ON mi.MatGuid = mt.Guid 			 
				 INNER JOIN Gr000 gr ON gr.Guid = mt.GroupGuid  
				 
	WHERE		
		  (fm.Guid = @FormGuid OR @FormGuid = 0x0)
		AND 
		  mi.Type =1 /*«·„«œ… √Ê·Ì… */
		AND 
		  mn.Type = 0 
		AND
		  mi.readyMatGuid = 0x0 
		AND
		mi2.Type = 0/*«·„«œ… „’‰⁄… */
		AND 
  		(@RawGroupGuid = mt.GroupGuid  OR  @RawGroupGuid =gr.ParentGuid  OR @RawGroupGuid = 0x0)
		GROUP BY mi2.MatGUID
RETURN  @Result 
   END
###########################################################
CREATE function fnGetLinkedMatPrice
(
	@FormGuid UNIQUEIDENTIFIER ,
	@RawGroupGuid UNIQUEIDENTIFIER ,
	@ReadyMatGuid UNIQUEIDENTIFIER ,
	@PriceType INT
)
RETURNS FLOAT 
AS
BEGIN  
DECLARE   @Result FLOAT 
SELECT  
@Result = ISNULL(SUM(((CASE @PriceType WHEN 0 THEN [mi].Price 
										 WHEN 1 THEN [mt].AvgPrice * mi.CurrencyVal
										 ELSE [mt].LastPrice * mi.CurrencyVal
						END) ) * mi.Qty), 0) 
	FROM 
		FM000 fm INNER JOIN MN000 mn ON mn.FormGUID = fm.Guid 
				 INNER JOIN MI000 mi ON mi.ParentGuid = mn.Guid 
				 INNER JOIN MI000 mi2 ON mi2.ParentGuid = mn.Guid  
				 INNER JOIN mt000 mt ON mi.MatGuid = mt.Guid 			 
				 INNER JOIN gr000 gr ON gr.Guid = mt.Groupguid 
				 
	WHERE		
		  fm.Guid = @FormGuid 
		AND 
		  mi.Type =1 /*«·„«œ… √Ê·Ì… */
		AND 
		  mn.Type = 0 
		AND 
		(@RawGroupGuid  = mt.GroupGuid OR @RawGroupGuid = gr.ParentGuid OR  @RawGroupGuid = 0x0)
		AND
		mi.ReadyMatGuid = @ReadyMatGuid
		AND
		 mi2.Type = 0 /*«·„«œ… „’‰⁄… */
	Group by mi2.MatGuid 
  RETURN @Result 
  END
###########################################################
CREATE  function fnGetUnit_TotalCostPrice
(
	@FormGuid UNIQUEIDENTIFIER ,
	@RawGroupGuid UNIQUEIDENTIFIER 
)
RETURNS FLOAT 
AS 
BEGIN
DECLARE @Result FLOAT 
SELECT @Result = ISNULL(SUM(mx.Extra/ mx.CurrencyVal  ) , 0) 
	FROM 
		FM000 fm INNER JOIN MN000 MN ON MN.FormGUID = FM.Guid 
				 INNER JOIN MX000 MX ON MX.ParentGuid = MN.Guid 
	WHERE		
		  (fm.Guid = @FormGuid OR @FormGuid = 0x0)
		AND 
		  mn.Type = 0 
		AND
		  mx.ReadyMatGuid = 0x0 
	RETURN  @Result 
END  
###########################################################
CREATE FUNCTION fnGetLinkedUnit_TotalCostPrice
(
	@FormGuid UNIQUEIDENTIFIER ,
	@RawGroupGuid UNIQUEIDENTIFIER ,
	@ReadyMatGuid UNIQUEIDENTIFIER
)
RETURNS FLOAT 
AS
BEGIN 
DECLARE @Result FLOAT 
SELECT @Result = ISNULL(SUM(mx.Extra / mx.CurrencyVal ) , 0) 
	FROM 
		FM000 fm INNER JOIN MN000 MN ON MN.FormGUID = FM.Guid 
				 INNER JOIN MX000 MX ON MX.ParentGuid = MN.Guid 
	WHERE		
		  (fm.Guid = @FormGuid OR @FormGuid = 0x0 )
		AND 
		  mn.Type = 0 
		AND
		  mx.ReadyMatGuid = @ReadyMatGuid
RETURN	@Result
END
###########################################################
CREATE FUNCTION fnGetReadyMatName( @MatGuid UNIQUEIDENTIFIER = 0x0 )
  RETURNS NVARCHAR(255)
AS BEGIN
    DECLARE @readyMatName NVARCHAR(255)
		SET @readyMatName = (SELECT name FROM mt000 WHERE GUID = @MatGuid )
			
	RETURN @readyMatName
END
###########################################################
#END
