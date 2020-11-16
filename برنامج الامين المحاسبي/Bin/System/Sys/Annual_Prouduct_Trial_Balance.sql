##############################################
CREATE PROCEDURE repAnnualProuductsTrialBalance
	@StartDate 		[DATETIME],
	@EndDate		[DATETIME],
	@MatGUID 		[UNIQUEIDENTIFIER],
	@GroupGUID 		[UNIQUEIDENTIFIER],
	@StoreGUID		[UNIQUEIDENTIFIER],
	@CostGUID 		[UNIQUEIDENTIFIER],
	@SrcTypesguid	[UNIQUEIDENTIFIER],
	@CurrencyGUID 	[UNIQUEIDENTIFIER],
	@PricePolicy 	[INT],
	@MatType 		[INT], --0 Service 1 Stored -1 all
	@UseUnit 		[INT], --1 First 2 Seccound 3 Third 
	@WithDetails	[INT] = 1,
	@ShowGroups		[INT] = 0,
	@Accum			[INT] = 0,
	@CurVal			[FLOAT]= 1,
	@Str			[NVARCHAR](max) = '',
	@MtCondGuid		[UNIQUEIDENTIFIER] = 0X00,
	@CustCondGuid	[UNIQUEIDENTIFIER] = 0X00
AS 
	SET NOCOUNT ON
	IF [dbo].[fnGetUserMaterialSec_Balance]([dbo].[fnGetCurrentUserGuid]()) <= 0 
		RETURN 
	
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER]) 
	CREATE TABLE [#StoreTbl](	[StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#Cust] ( [Number] [UNIQUEIDENTIFIER], [Sec] [INT])
	--Filling temporary tables 
	IF @MatType = -2  AND @ShowGroups = 1
	BEGIN
		INSERT INTO [#MatTbl] EXEC [prcGetMatsList] @MatGUID, @GroupGUID, -1, @MtCondGuid
	END
	ELSE
	BEGIN
		INSERT INTO [#MatTbl] EXEC [prcGetMatsList] @MatGUID, @GroupGUID, @MatType, @MtCondGuid
	END
	
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList] @SrcTypesguid--, @UserGuid 
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 	@StoreGUID 
	INSERT INTO [#CostTbl]			EXEC [prcGetCostsList] 		@CostGUID
	IF @CustCondGuid = 0x0
	BEGIN 
		INSERT INTO [#Cust] SELECT [cuGuid], [cuSecurity] FROM [vwCu] UNION ALL SELECT 0x0, 1
	END ELSE 
		INSERT INTO [#Cust] EXEC [prcGetCustsList]  NULL, NULL, @CustCondGuid
	DECLARE @Admin [INT], @UserGuid [UNIQUEIDENTIFIER], @cnt [INT]
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()
	SET @Admin = [dbo].[fnIsAdmin](ISNULL(@userGUID,0x00) )
	
	IF @Admin = 0
	BEGIN
		CREATE TABLE  [#GR2]([Guid] [UNIQUEIDENTIFIER])
		INSERT INTO [#GR2] SELECT [Guid] FROM [fnGetGroupsList](@GroupGUID)
		DELETE [r] FROM [#GR2] AS [r] INNER JOIN fnGroup_HSecList() AS [f] ON [r].[gUID] = [f].[GUID] where [f].[Security] > [dbo].[fnGetUserGroupSec_Browse](@UserGuid)
		DELETE [m] FROM [#MatTbl] AS [m]
		INNER JOIN [mt000] AS [mt] ON [MatGUID] = [mt].[Guid] 
		WHERE [mtSecurity] > [dbo].[fnGetUserMaterialSec_Browse](@UserGuid) 
		OR [Groupguid] NOT IN (SELECT [Guid] FRoM [#Gr2])
		SET @cnt = @@ROWCOUNT
		IF @cnt > 0
			INSERT INTO [#SecViol] values(7,@cnt)
		
	END
	DECLARE @mtCnt [INT]
	DECLARE @PStartDate [DATETIME],@PEndDate [DATETIME]
	DECLARE @c CURSOR
	DECLARE @mtGuid [UNIQUEIDENTIFIER]
	
	DECLARE @PricesTbl TABLE( [MtGUID] [UNIQUEIDENTIFIER], [MTPrice] [FLOAT]) 

	SELECT @mtCnt=COUNT(*) FROM [#MatTbl]
	CREATE TABLE [#T_Result] (	
				[btType] 		[INT] DEFAULT 11,		
				[btTypeGUID]	[UNIQUEIDENTIFIER],
				[MatPtr] 		[UNIQUEIDENTIFIER],
				[MtName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
				[MtCode]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
				[MtLatinName]	[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
				[biStorePtr]	[UNIQUEIDENTIFIER] ,
				[btDirection] 	[INT], 
				[biQty] 		[FLOAT] ,
				[biQty2]		[FLOAT] ,
				[biQty3] 		[FLOAT] ,
				[FixedBiPrice] 	[FLOAT] DEFAULT 0,
				[PricePolicyPrice] [FLOAT] DEFAULT 0,
				[MatSecurity] 	[INT],
				[Security]		[INT], 
				[UserSecurity] 	[INT],
				[mtUnitFact]	[FLOAT] DEFAULT 0,
				[GrpPtr] 		[UNIQUEIDENTIFIER],
				[Flag] 			[INT] ,
				[UnitName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
				[Unit2Name]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
				[Unit3Name]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
				[StartDate]		[DATETIME],
				[EndDate]		[DATETIME],
				[Path] [NVARCHAR](1000),
				[Root] [INT] DEFAULT 0,
				[Level] [INT] DEFAULT 0
			
				)
	IF (ISNULL(@CostGUID,0X00)=0X00) 
		INSERT INTO [#CostTbl] VALUES (0X00,0)
	DECLARE @PDate TABLE  ([StartDate] [DATETIME] DEFAULT '1/1/1980',[EndDate] [DATETIME])
	INSERT INTO @PDate SELECT *  FROM [fnGetStrToPeriod]( @STR )
	
	INSERT INTO [#T_Result]
			SELECT 
				[bu].[btBillType],
				[bu].[buType],
				[bu].[biMatPtr],
				[bu].[mtName],  
				[bu].[mtCode],  
				[bu].[mtLatinName],
				[bu].[biStorePtr],
				[btDirection],
				[Qty],
				[bu].[biCalculatedQty2],
				[bu].[biCalculatedQty3],
				[bu].[FixedbiTotal],
				0, -- PricePolicyPrice
				[bu].[mtSecurity],
				[bu].[buSecurity],
				[bu].[UserSecurity],
				[mtUnitFact],
				[bu].[mtGroup],
				0,
				[mtUint],
				[bu].[mtUnit2],
				[bu].[mtUnit3],
				[StartDate],
				[EndDate],
				'',
				0,
				0	
			FROM 
				(SELECT 
					[bi].[btBillType],
					[bi].[buType],
					[bi].[biMatPtr],
					[bi].[mtName],  
					[bi].[mtCode],  
					[bi].[mtLatinName],
					[bi].[biStorePtr],
					[btDirection],
					SUM(CASE @UseUnit 
						WHEN 0 THEN ([bi].[biQty] + [bi].[biBonusQnt])
						WHEN 1 THEN ([bi].[biQty] + [bi].[biBonusQnt]) / CASE [bi].[mtunit2Fact] WHEN 0 THEN 1 ELSE [bi].[mtunit2Fact] END 
						WHEN 2 THEN ([bi].[biQty] + [bi].[biBonusQnt]) / CASE [bi].[mtunit3Fact] WHEN 0 THEN 1 ELSE [bi].[mtunit3Fact] END  
						ELSE ([bi].[biQty] + [bi].[biBonusQnt]) / [bi].[mtDefUnitFact]
					END ) AS [Qty],
					SUM([bi].[biCalculatedQty2]) AS [biCalculatedQty2],
					SUM([bi].[biCalculatedQty3]) AS [biCalculatedQty3] ,
					
					SUM(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN  [bi].[FixedbiTotal] - CASE [btDirection] WHEN 1 THEN [bi].[FixedBiLCDisc] - [bi].[FixedBiLCExtra] ELSE 0 END ELSE 0 END) AS [FixedbiTotal],
					[mt].[mtSecurity],
					[bi].[buSecurity],
					[bt].[UserSecurity],
					[bi].[mtGroup],
					CASE @UseUnit
						WHEN 0 THEN [bi].[mtUnity]
						WHEN 1 THEN [bi].[mtUnit2]
						WHEN 2 THEN [bi].[mtUnit3]
						ELSE 
							CASE [bi].[mtDefUnit]
								WHEN 1 THEN [bi].[mtUnity]
								WHEN 2 THEN [bi].[mtUnit2]
								ELSE [bi].[mtUnit3]
							END
					END AS [mtUint],
					[bi].[mtUnit2],
					[bi].[mtUnit3],
					[StartDate],
					[EndDate],
					[bi].[biCostPtr],
					[bi].[buCustPtr],
					SUM(CASE @UseUnit 
						WHEN 0 THEN 1
						WHEN 1 THEN  CASE [bi].[mtunit2Fact] WHEN 0 THEN 1 ELSE [bi].[mtunit2Fact] END 
						WHEN 2 THEN CASE [bi].[mtunit3Fact] WHEN 0 THEN 1 ELSE [bi].[mtunit3Fact] END  
						ELSE [bi].[mtDefUnitFact]
					END )
					 AS [mtUnitFact]
				FROM 
					[fnExtended_bi_Fixed](@CurrencyGUID) AS [bi]
					INNER JOIN [#MatTbl] AS [mt] ON [mt].[MatGUID] = [bi].[biMatPtr]
					INNER JOIN [#BillsTypesTbl] AS [bt] ON [bt].[TypeGuid] = [bi].[buType]
					INNER JOIN @PDate AS [p] ON [bi].[buDate] BETWEEN [StartDate] AND [EndDate]
				WHERE 
					([buDate] BETWEEN @StartDate AND @EndDate )
						--AND [buIsPosted] = 1 
				GROUP BY
					[bi].[btBillType],
					[bi].[buType],
					[bi].[biMatPtr],
					[bi].[mtName],  
					[bi].[mtCode],  
					[bi].[mtLatinName],
					[bi].[biStorePtr],
					[mt].[mtSecurity],
					[bi].[buSecurity],
					[bt].[UserSecurity],
					[bi].[mtGroup],
					[bi].[mtUnity],
					[bi].[mtUnit2],
					[bi].[mtUnit3],
					[StartDate],
					[EndDate],
					[bi].[biCostPtr],
					[bi].[buCustPtr],
					[btDirection],
					[bi].[mtunit2Fact],
					[bi].[mtunit3Fact],
					[bi].[mtDefUnitFact],
					[bi].[mtDefUnit]
					) AS [bu]
				INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [bu].[biStorePtr]
				INNER JOIN [#CostTbl] AS [co] ON [co].[CostGUID] = [bu].[biCostPtr]
				INNER JOIN [#Cust] AS [cu] ON [cu].[Number] = [bu].[buCustPtr]
			
	EXEC [prcCheckSecurity]  @result = '#T_Result'
	CREATE TABLE [#t_Prices] ( [mtNumber] 	[UNIQUEIDENTIFIER], [APrice] [FLOAT])
	
	IF @MatType > 100
		SET @MatType = -1
	SET @c = CURSOR FAST_FORWARD FOR 
			SELECT  [StartDate] ,[EndDate] FROM @PDate

	-------------------------------------- Adding totalbalance rows ---------------------------------------------------------
	OPEN @c 	
	FETCH  FROM @c  INTO @PStartDate,@PEndDate
	WHILE @@FETCH_STATUS = 0
	BEGIN	
		TRUNCATE TABLE [#t_Prices]
		
		IF @PricePolicy = 121 
		BEGIN 
			EXEC [prcGetAvgPrice]	'1/1/1980',/*@PStartDate,*/@PEndDate,0X0,@GroupGUID,@StoreGUID, @CostGUID, @MatType, @CurrencyGUID, 1, @SrcTypesguid,0, 0
		END
		ELSE IF @PricePolicy = 122 
		BEGIN  
			EXEC [prcGetLastPrice]	'1/1/1980',/*@PStartDate,*/@PEndDate,0X0,@GroupGUID,@StoreGUID, @CostGUID, @MatType, @CurrencyGUID,  @SrcTypesguid,0, 0
		END
		ELSE
		BEGIN
			EXEC [prcGetMaxPrice]	'1/1/1980',/*@PStartDate,*/@PEndDate,0X0,@GroupGUID,@StoreGUID, @CostGUID, @MatType, @CurrencyGUID, @CurVal, @SrcTypesguid,0, 0
		END

		UPDATE [#T_Result]
		SET [PricePolicyPrice] = 
		(SELECT [APrice] FROM [#t_Prices] AS [t] where ([mtNumber] =[TR].[MatPtr]) ) * [mtUnitFact] * [biQty]
		FROM [#T_Result] AS [TR]
		WHERE ((@Accum = 0 AND [StartDAte] BETWEEN @PStartDate AND @PEndDate) OR (@Accum = 1 AND [EndDate] < =@PEndDate))
				AND [FLAG] = 0
				AND [btDirection] != -3 

		INSERT INTO [#T_Result]
			(	
			[MatPtr] ,
			[MtName],  
			[MtCode],  
			[MtLatinName],  
			[biQty],
			[biQty2],
			[biQty3] ,
			[FixedBiPrice],
			[PricePolicyPrice],
			[Flag] ,
			[GrpPtr],
			[UnitName],
			[Unit2Name],
			[Unit3Name],
			[btDirection],
			[StartDate],
			[EndDate]
			) 
		SELECT 
			[MatPtr] ,
			[MtName],  
			[MtCode],  
			[MtLatinName],
			SUM ([biQty] * [btDirection]),
			SUM([biQty2] * [btDirection]),	
			SUM([biQty3] * [btDirection]),
			SUM ( ISNULL([FixedBiPrice], 0) *  [btDirection]), 
			SUM ( ISNULL([PricePolicyPrice], 0) * [btDirection]), 
			1,
			[r].[GrpPtr],
			[r].[UnitName],
			[r].[Unit2Name],
			[r].[Unit3Name],
			-3,
			@PStartDate,
			@PEndDate
			FROM [#T_Result] AS [r] 
			--left JOIN [#t_Prices] AS [t] ON  [mtNumber] =[r].[MatPtr]
			--LEFT JOIN @PricesTbl AS [t] ON  [t].[MtGUID] =[r].[MatPtr]
			WHERE 
				((@Accum = 0 AND [StartDAte] BETWEEN @PStartDate AND @PEndDate) OR (@Accum = 1 AND [EndDate] < =@PEndDate))
				AND [FLAG] = 0
				AND [btDirection] != -3
			GROUP BY [r].[MatPtr],
				[r].[MtName],  
				[r].[MtCode],  
				[r].[MtLatinName],
				[r].[GrpPtr],
				[r].[UnitName],
				[r].[Unit2Name],
				[r].[Unit3Name]

		FETCH NEXT FROM @c   INTO @PStartDate,@PEndDate
	END 
	CLOSE @c
	DEAllOCATE @c

	UPDATE [#T_Result]
	SET [PricePolicyPrice] = [FixedBiPrice]
	WHERE ((@Accum = 0 AND [StartDAte] BETWEEN @PStartDate AND @PEndDate) OR (@Accum = 1 AND [EndDate] < =@PEndDate))
			AND [FLAG] = 0
			AND [btDirection] = -1 

	----------------------------------------------------------------------------------------------------------------


	IF (@WithDetails = 1)
		INSERT INTO [#T_Result]
				(
				[btType] ,		
				[btTypeGUID],
				[MtName]	,  
				[MtCode]	,  
				[MtLatinName],
				[btDirection],
				[Flag]
				)
			SELECT DISTINCT
				[BillType] ,		
				[bt].[Guid] ,
				[bt].[Name],  
				'',  
				[bt].[LatinName]	,
				CASE [BT].[bIsInput] WHEN 1 THEN 1 ELSE -1 END,
				25 
			FROM  
				[bt000] AS [bt] INNER JOIN	[#T_Result] AS [r] ON [r].[btTypeGUID] =[BT].[Guid]
	IF ((@mtCnt = 1)AND (@WithDetails =1) AND  ISNULL(@MatGUID,0x0)!=0X0)
	BEGIN
		SELECT 
				ISNULL([btType], 0)				AS [btType],
				ISNULL([btTypeGUID], 0x00)		AS [btTypeGUID],
				ISNULL([MatPtr], 0x00)			AS [MatPtr],
				ISNULL([MtName], '')			AS [MtName],
				ISNULL([MtCode], '')			AS [MtCode],
				ISNULL([MtLatinName], '')		AS [MtLatinName],
				ISNULL([STARTDATE], '1-1-1980') AS [STartDate],
				ISNULL([btDirection], 0)	AS [btDirection],
				ISNULL(SUM([biQty]), 0.0)	AS [Qty],
				ISNULL(SUM([biQty2]), 0.0)	AS [Qnt2],
				ISNULL(SUM([biQty3]), 0.0)	AS [Qnt3],
				ISNULL(SUM([FixedBiPrice]), 0.0)		AS [TotalPrice],
				ISNULL(SUM([PricePolicyPrice]), 0.0)	AS [PricePolicyPrice],
				ISNULL([UnitName], '')		AS [UnitName],
				ISNULL([Unit2Name], '' )	AS [Unit2Name],
				ISNULL([Unit3Name], '' )	AS [Unit3Name],
				ISNULL([Flag], 0)			AS [Flag]			
		FROM  
			[#T_Result] 
		GROUP BY
			[btDirection],
			[btType] ,		
			[btTypeGUID],
			[MatPtr] ,
			[MtName]	, 
			[MtCode]	,  
			[MtLatinName],
			[STARTDATE],
			[btDirection],
			[Flag],
			[UnitName],
			[Unit2Name],
			[Unit3Name]
		ORDER BY 
			[STARTDATE],
			[btType] ,		
			[btTypeGUID],
			[btDirection] DESC,
			[Flag]
		SELECT * FROM [#SecViol]
		RETURN
	END
	ELSE IF ((ISNULL(@MatGUID,0x0)=0X0) AND (@WithDetails =1))
	BEGIN
		DECLARE @GrpName [NVARCHAR] (256),@GrpLatinName [NVARCHAR] (256) ,@GrpCode [NVARCHAR]
		IF ISNULL(@GroupGUID,0X0)!=0X0
			SELECT @GrpName = [Name],@GrpLatinName = [LatinName], @GrpCode=[Code] FROM [gr000] WHERE [GUID] = @GroupGUID
		ELSE 
			UPDATE R
				SET [MtName] = '',
					[MtLatinName] = ''
			FROM [#T_Result] R
			WHERE [FLAG] <> 25

			SELECT 
				ISNULL([btType], 0)						AS [btType],		
				ISNULL([btTypeGUID], 0x00)				AS [btTypeGUID],
				@GroupGUID								AS [MatPtr],
				[MtName], 
				''										AS [MtCode],
				[MtLatinName],  
				ISNULL([STARTDATE], '1-1-1980')			AS [StartDate],
				ISNULL([btDirection], 0)				AS [btDirection],
				ISNULL(SUM([biQty]), 0.0)				AS [Qty],
				ISNULL(SUM([biQty2]), 0.0)				AS [Qnt2],
				ISNULL(SUM([biQty3]), 0.0)				AS [Qnt3],
				ISNULL(SUM([FixedBiPrice]), 0.0)		AS [TotalPrice],
				ISNULL(SUM([PricePolicyPrice]), 0.0)	AS [PricePolicyPrice],
				ISNULL([Flag], 0)						AS [Flag]
			FROM  
				[#T_Result] 
			GROUP BY
				[MtName],
				[MtLatinName],
				[btType] ,		
				[btTypeGUID],
				[btDirection],
				[STARTDATE],
				[btDirection],
				[Flag]
			ORDER BY 
				[STARTDATE],
				[btType] ,		
				[btTypeGUID],
				[btDirection] DESC,
				[Flag]
				
		SELECT * FROM [#SecViol]
		RETURN
	END
	ELSE
	BEGIN
	IF ( @ShowGroups = 0)
 		BEGIN
			SELECT 
					0										AS [btType],		
					0x00									AS [btTypeGUID] ,
					ISNULL([MatPtr], 0x00)					AS [MatPtr],
					ISNULL([MtName], '')					AS [MtName],  
					ISNULL([MtCode], '')					AS [MtCode],  
					ISNULL([MtLatinName], '')				AS [MtLatinName],  
					ISNULL([STARTDATE], '1-1-1980')			AS [StartDate],
					ISNULL([btDirection],0)					AS [btDirection] ,
					ISNULL(SUM([biQty]), 0.0)				AS [Qty],
					ISNULL(SUM([biQty2]), 0.0)				AS [Qnt2],
					ISNULL(SUM([biQty3]), 0.0)				AS [Qnt3],
					ISNULL(SUM([FixedBiPrice]), 0.0)		AS [TotalPrice],
					ISNULL(SUM([PricePolicyPrice]), 0.0)	AS [PricePolicyPrice],
					ISNULL([UnitName], '')					AS [UnitName],
					ISNULL([Unit2Name], '' )				AS [Unit2Name],
					ISNULL([Unit3Name], '' )				AS [Unit3Name]
				FROM  
					[#T_Result] 
				GROUP BY
					[MatPtr],
					[MtName],  
					[MtCode],  
					[MtLatinName],
					[STARTDATE],
					[btDirection],
					[UnitName],
					[Unit2Name],
					[Unit3Name]
				ORDER BY 
					[MtCode],
					[STARTDATE],
					[btDirection] DESC

				SELECT * FROM [#SecViol]
			END 		
	ELSE
	BEGIN
				CREATE TABLE [#Gr] ([Guid] [UNIQUEIDENTIFIER], [Path] VARCHAR(8000), [Level] INT, [Name] NVARCHAR(256), 
				[Code] NVARCHAR(256), [LatinName] NVARCHAR(256), [ParentGuid] [UNIQUEIDENTIFIER])							
				DECLARE @Level [INT],	@Sort2 [INT]
				SET @Sort2 = 1	
				INSERT INTO [#Gr] SELECT [f].[Guid],[f].[Path],[f].[Level]   ,[gr].[Name],[gr].[Code],[gr].[LatinName],[gr].[ParentGuid] FROM [fnGetGroupsOfGroupSorted]( @GroupGUID, @Sort2) AS [f] INNER JOIN [gr000] AS [gr] ON [gr].[Guid] = [f].[Guid]							
				UPDATE [r] SET  [Path] = [gr].[Path] FROM [#T_RESULT] AS [r] INNER JOIN [#Gr] AS [gr] ON [r].[GrpPtr] = [gr].[Guid]
				
				INSERT INTO [#T_RESULT]([MatPtr], [MtName], [MtCode], [MtLatinName], [btDirection],[StartDate],[biQty],[biQty2],[biQty3],[FixedBiPrice], [PricePolicyPrice],[GrpPtr], [Flag],[Root],[Level],[Path])
				SELECT [gr].[Guid],[gr].[Name],[gr].[Code],[gr].[LatinName],[btDirection],[StartDate]
				,SUM([biQty]) 
				,SUM([biQty2])
				,SUM([biQty3])
				,SUM([FixedBiPrice]) ,
				SUM([PricePolicyPrice]) [PricePolicyPrice],
				[gr].[ParentGuid], [Flag], 1,[gr].[Level],[gr].[Path]
				FROM [#T_RESULT] AS [r] INNER JOIN [#gr] AS [gr] ON [r].[GrpPTR] = [gr].[guid]
				GROUP BY 
					[gr].[Guid],[gr].[Name],[gr].[Code],[gr].[LatinName],[btDirection],[StartDate],[gr].[ParentGuid], [Flag],[gr].[Level],[gr].[Path]	
				
				SELECT @Level = MAX([Level]) FROM [#T_RESULT]
				WHILE (@Level > 0)
				BEGIN
					INSERT INTO [#T_RESULT]([MatPtr], [MtName], [MtCode], [MtLatinName], [btDirection],[StartDate],[biQty],[biQty2],[biQty3],[FixedBiPrice], [GrpPtr], [Flag],[Root],[Level],[Path])
					SELECT [gr].[Guid],[gr].[Name],[gr].[Code],[gr].[LatinName],[btDirection],[StartDate]
					,SUM([biQty]) 
					,SUM([biQty2])
					,SUM([biQty3])
					,SUM([FixedBiPrice]) , [gr].[ParentGuid], [Flag], 1,[gr].[Level],[gr].[Path]
					FROM [#T_RESULT] AS [r] JOIN [#gr] AS [gr] ON [r].[GrpPTR] = [gr].[guid]
					WHERE [R].[Level] = @Level
					GROUP BY 
						[gr].[Guid],[gr].[Name],[gr].[Code],[gr].[LatinName],[btDirection],[StartDate],[gr].[ParentGuid], [Flag],[gr].[Level],[gr].[Path]	
					SET @Level = @Level -1
				END 
				IF @MatType = -2 AND @ShowGroups = 1
				BEGIN
					DELETE t
					FROM 
						[#T_RESULT] t
						INNER JOIN mt000 mt on t.MatPtr = mt.[GUID]
				END
				SELECT 
					0										AS [btType],		
					0x00									AS [btTypeGUID],
					ISNULL([MatPtr], 0x00)					AS [MatPtr],
					ISNULL([MtName], '')					AS [MtName],  
					ISNULL([MtCode], '')					AS [MtCode],  
					ISNULL([MtLatinName], '')				AS [MtLatinName],  
					ISNULL([STARTDATE], '1-1-1980')			AS [StartDate],
					ISNULL([btDirection], 0)				AS [btDirection],
					ISNULL(SUM([biQty]), 0.0)				AS [Qty],
					ISNULL(SUM([biQty2]), 0.0)				AS [Qnt2],
					ISNULL(SUM([biQty3]), 0.0)				AS [Qnt3],
					ISNULL(SUM([FixedBiPrice]), 0.0)		AS [TotalPrice],
					ISNULL(SUM([PricePolicyPrice]), 0.0)	AS [PricePolicyPrice],
					ISNULL([Root], 0)						AS [Root] ,
					ISNULL([UnitName], '')					AS [UnitName],
					ISNULL([Unit2Name], '')					AS [Unit2Name],
					ISNULL([Unit3Name], '')					AS [Unit3Name]
				FROM  
					[#T_RESULT] 
				GROUP BY
					[MatPtr],
					[MtName],  
					[MtCode],  
					[MtLatinName],
					[STARTDATE],
					[btDirection],
					[ROOT],
					[Path],
					[UnitName],
					[Unit2Name],
					[Unit3Name]
				ORDER BY 
					[Path],
					[ROOT] DESC,
					[MtCode],
					[STARTDATE],
					[btDirection] DESC
			SELECT * FROM [#SecViol]

		END
	END
/*
prcConnections_add2 '„œÌ—'
exec  [repAnnualProuductsTrialBalance] '1/1/2004', '12/31/2004', 'ebd37920-ae2e-4a06-ac03-d7b8f1ec2db9', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '0dc143c7-8791-448f-96d5-dac44362e819', '04b7552d-3d32-47db-b041-50119e80dd52', 121, -1, 3, 1, 0, 0, 0, 1.000000, '1-1-2004,1-31-2004,2-1-2004,2-29-2004,3-1-2004,3-31-2004,4-1-2004,4-30-2004,5-1-2004,5-31-2004,6-1-2004,6-30-2004,7-1-2004,7-31-2004,8-1-2004,8-31-2004,9-1-2004,9-30-2004,10-1-2004,10-31-2004,11-1-2004,11-30-2004,12-1-2004,12-31-2004' 
*/
########################################
############
#END
