######################################################
CREATE PROCEDURE repCustomerMonthlyMove
	@StartDate			[DATETIME], 
	@EndDate			[DATETIME], 
	@Billtypes			[UNIQUEIDENTIFIER], 
	@Account			[UNIQUEIDENTIFIER], 
	@Cust				[UNIQUEIDENTIFIER], 
	@MatGroup			[UNIQUEIDENTIFIER], 
	@MatGUID			[UNIQUEIDENTIFIER], 
	@StoreGUID			[UNIQUEIDENTIFIER], 
	@CostGUID			[UNIQUEIDENTIFIER], 
   	@CurGUID			[UNIQUEIDENTIFIER], 
	@AccLevel			[INT], 
	@Period				[INT],
    @CusotmerConditionGuid		[UNIQUEIDENTIFIER] = 0x0,
	@MonthPeriodString	[NVARCHAR](max) ,
	@ShowQty			[INT], 
	@ShowBonus			[INT], 
	@InOut				[INT], 
	@UseUnit			[INT],
	@Posted				[INT],
	@MatCondGuid		[UNIQUEIDENTIFIER] = 0x00,
	@ShwEmpty			BIT = 0,
	@IncludeBonus		BIT = 0,
	@ShowMainAcc		BIT = 0,
	@GroupByPayType		BIT = 0
AS 
	SET NOCOUNT ON  

	DECLARE @GUIDZero AS [UNIQUEIDENTIFIER]
	DECLARE @level1 INT   
	SET @GUIDZero = 0x0 
	DECLARE @ShowIncludeBonus BIT
	SET @ShowIncludeBonus = CASE WHEN @IncludeBonus > 0 OR @ShowBonus > 0 THEN 1 ELSE 0 END
	--------------------------------------------------------------------
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result](
			[Id] [INT],
			[Acc] [UNIQUEIDENTIFIER],
			[Cu] [UNIQUEIDENTIFIER],
			[CashQty] [FLOAT], 
			[ForwardQty] [FLOAT], 
			[NoteQty] [FLOAT], 
			[TotalQty] [FLOAT],
			[CashBonus] [FLOAT], 
			[ForwardBonus] [FLOAT], 
			[NoteBonus] [FLOAT], 
			[TotalBonus] [FLOAT],
			[CashPrice] [FLOAT], 
			[ForwardPrice] [FLOAT], 
			[NotePrice] [FLOAT],
			[TotalPrice] [FLOAT],
			[CustSecurity] [INT],
			[acSecurity] [INT],
			[Security] [INT],
			[mtSecurity] [INT],
			[userSecurity] [INT])
	DECLARE @MaxLevel [INT]
	--------------------------------------------------------------------	 
	-- ÕœÌœ «·› —«  ›Ì «· ﬁ—Ì— 
	DECLARE @PrdTbl TABLE(  
			[PeriodID] [INT],  
			[StartDate] [DATETIME],  
			[EndDate] [DATETIME]) 
	IF @Period <> 3 
	BEGIN
		set LANGUAGE 'arabic'
		INSERT INTO @PrdTbl SELECT [Period],[StartDate],[EndDate] FROM [dbo].[fnGetPeriod](@Period, @StartDate, @EndDate) 
		set LANGUAGE 'english' 
	END
	ELSE
	BEGIN
		INSERT INTO @PrdTbl SELECT 0, [StartDate], [EndDate] FROM [dbo].[fnGetStrToPeriod] (@MonthPeriodString)
	
		SELECT IDENTITY(INT, 1,1) AS [ID], [StartDate]
		INTO #TempPrd
		FROM @PrdTbl
		ORDER BY [StartDate]
		
		UPDATE @PrdTbl SET
			PeriodID = tp.[ID]
		FROM @PrdTbl AS p 
		INNER JOIN #TempPrd AS tp ON tp.[StartDate] = p.[StartDate]
	END
	DECLARE @ColNum AS [INT] 
	SELECT @ColNum = Count(PeriodID) FROM @PrdTbl 
	IF @ColNum > 255 
	BEGIN 
		DELETE FROM @PrdTbl 
		INSERT INTO @PrdTbl SELECT 1, @StartDate, @EndDate 
	END 
	------------------------------------------------------------------- 
	CREATE TABLE  [#Account_Tbl] 
	( 
		[GUID] [UNIQUEIDENTIFIER], 
		[Level] [INT] , 
		[Path] [NVARCHAR](max), 
		[Security] [INT],
		[ParentGUID] [UNIQUEIDENTIFIER],
		[CustGuid] UNIQUEIDENTIFIER,
		[acCode]	NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[acName]	NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[acLatinName]	NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[Type] tinyint
		) 

	IF @ShowMainAcc = 0
		INSERT INTO [#Account_Tbl]   
			SELECT   
				[fn].[GUID],   
				[fn].[Level],   
				[fn].[Path], 
				[acc].[Security], 
				[acc].[ParentGuid], 
				ISNULL(c.Guid,0x0),acc.Code,acc.Name,acc.LatinName,[acc].Type 
			FROM  
				[dbo].[fnGetAccountsList]( @Account, 1) AS [Fn]  
				INNER JOIN [Ac000] AS [acc] ON [Fn].[GUID] = [acc].[GUID] 
				LEFT JOIN [cu000] c ON ISNULL(c.AccountGuid,0x0) = [acc].[GUID]
			WHERE acc.NSons = 0 
	ELSE
		INSERT INTO [#Account_Tbl]   
			SELECT   
				[fn].[GUID],   
				[fn].[Level],   
				[fn].[Path], 
				[acc].[Security], 
				[acc].[ParentGuid], 
				ISNULL(c.Guid,0x0),acc.Code,acc.Name,acc.LatinName,[acc].Type 
			FROM  
				[dbo].[fnGetAccountsList]( @Account, 1) AS [Fn]  
				INNER JOIN [Ac000] AS [acc] ON [Fn].[GUID] = [acc].[GUID] 
				LEFT JOIN [cu000] c ON ISNULL(c.AccountGuid,0x0) = [acc].[GUID]
		SELECT 
			[fn].[Level],  
			[fn].[Path]
		INTO [#COL]
		FROM 
			[dbo].[fnGetAccountsList]( @Account, 1) AS [Fn] 
			INNER JOIN [Ac000] AS [acc] ON [Fn].[GUID] = [acc].[GUID]
			WHERE [Type] = 4
	IF EXISTS(SELECT * FROM  [#Account_Tbl] WHERE TYPE =4)
	BEGIN
		SELECT @MaxLevel = Max([level]) from [#Account_Tbl] where type =4
		
		SET @level1 = 0
		WHILE @level1 <= @MaxLevel
		BEGIN
			UPDATE A SET parentguid = b.[guid] from #Account_Tbl a inner join #Account_Tbl b on a.[level] = (b.[level] + 1) inner join ci000 c on b.guid = c.parentguid and a.guid = c.songuid
			WHERE b.[type] =4 and b.Level = @level1
			SET @level1 = @level1 + 1
		END
	END
	CREATE CLUSTERED INDEX [accInd] ON [#Account_Tbl]([GUID])
	-------Bill Resource --------------------------------------------------------- 
	CREATE TABLE [#Src] ( [Type] [UNIQUEIDENTIFIER], [Sec] [INT], [ReadPrice] [INT], [UnPostedSec] [INT])
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList2] @Billtypes  
	-------Mat Table---------------------------------------------------------- 
	CREATE TABLE [#MatTbl]( [mtNumber] [UNIQUEIDENTIFIER], [mtSecurity] [INT])   
	INSERT INTO [#MatTbl] EXEC [prcGetMatsList]  @MatGUID, @MatGroup ,-1,@MatCondGuid 
	select [mtNumber],[mtSecurity],
	CASE @UseUnit   
				WHEN 0 THEN 1 
				WHEN 1 THEN CASE WHEN [Unit2Fact] = 0 THEN 1 ELSE [Unit2Fact] END
				WHEN 2 THEN CASE WHEN [Unit3Fact] = 0 THEN 1 ELSE [Unit3Fact] END
				else
					CASE [DefUnit] 
						WHEN 1 THEN 1 
						WHEN 2 THEN CASE WHEN [Unit2Fact] = 0 THEN 1 ELSE [Unit2Fact] END
						WHEN 3 THEN CASE WHEN [Unit3Fact] = 0 THEN 1 ELSE [Unit3Fact] END
					END
				END UintFactor
			INTO [#MatTbl2]
			FROM [#MatTbl] [mt] INNER JOIN  [MT000] a ON a.[Guid] =  [mtNumber]  
	-------Store Table---------------------------------------------------------- 
	DECLARE @StoreTbl TABLE( [Number] [UNIQUEIDENTIFIER])   
	INSERT INTO @StoreTbl SELECT [Guid] FROM [fnGetStoresList]( @StoreGUID)   
	IF @StoreGUID = @GUIDZero OR @StoreGUID = 0x0 
		INSERT INTO @StoreTbl VALUES( @GUIDZero)  
    ------Cust Table---------------------------------------------------------- 
	DECLARE @CustTbl TABLE ( [CustGuid] [UNIQUEIDENTIFIER], [Sec] [INT])   
    INSERT INTO @CustTbl EXEC [prcGetCustsList]  @Cust, @Account, @CusotmerConditionGuid
	IF (@Account = 0X00) AND (@Cust = 0X00)
		INSERT INTO @CustTbl	VALUES (0X00,0)
	------Cost Table---------------------------------------------------------- 
	DECLARE @CostTbl TABLE( [Number] [UNIQUEIDENTIFIER]) 
	INSERT INTO @CostTbl SELECT [Guid] FROM [fnGetCostsList]( @CostGUID)   
	IF @CostGUID = @GUIDZero or @CostGUID IS NULL 
		INSERT INTO @CostTbl VALUES( @GUIDZero)  
	------------------------------------------------------------------------------
	INSERT INTO [#Result] 
	SELECT 
		[PeriodID],
		( CASE [BuCustPtr] WHEN @GUIDZero THEN[BuCustAcc] ELSE [AcTbl].[GUID] END), 
		[CustGuid],
		SUM(CASE WHEN @GroupByPayType = 1 THEN CASE WHEN [buPayType] = 0 THEN
			CASE @UseUnit WHEN 0 THEN [biQty] * @ShowQty
				WHEN 1 THEN [biQty2] * @ShowQty WHEN 2 THEN [biQty3] * @ShowQty
				WHEN 3 THEN [biQty] * @ShowQty/ CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END END ELSE 0 END * DIR ELSE 0 END ), 
		SUM(CASE WHEN @GroupByPayType = 1 THEN  
			CASE WHEN [buPayType] = 1 THEN  
			CASE @UseUnit 	WHEN 0 THEN [biQty] * @ShowQty 
				WHEN 1 THEN [biQty2] * @ShowQty WHEN 2 THEN [biQty3] * @ShowQty 
				WHEN 3 THEN [biQty] * @ShowQty/ CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END  END * DIR	ELSE 0 END ELSE 0 END), 
		SUM(CASE WHEN @GroupByPayType = 1 THEN  
			CASE WHEN [buPayType] > 1 THEN  
			CASE @UseUnit   
				WHEN 0 THEN [biQty] * @ShowQty 	WHEN 1 THEN [biQty2] * @ShowQty 
				WHEN 2 THEN [biQty3] * @ShowQty  
				WHEN 3 THEN [biQty] * @ShowQty/ CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END    
			END * DIR ELSE 0 END ELSE 0 END), 
		-- ShowTotal
		SUM(CASE @UseUnit   
			WHEN 0 THEN [biQty] * @ShowQty 	WHEN 1 THEN [biQty2] * @ShowQty 
			WHEN 2 THEN [biQty3] * @ShowQty 
			WHEN 3 THEN [biQty] * @ShowQty/ CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END    	END * DIR),
		---------------------------------
		SUM(CASE WHEN @GroupByPayType = 1 THEN  	CASE WHEN [buPayType] = 0 THEN  
			 [biBonusQnt] * @ShowIncludeBonus /UintFactor *DIR 
			ELSE 0 END ELSE 0 END), 
		SUM(CASE WHEN @GroupByPayType = 1 THEN  
			CASE WHEN [buPayType] = 1 THEN  [biBonusQnt] * @ShowIncludeBonus * UintFactor * DIR 
			ELSE 0 END ELSE 0 END ), 
		SUM(CASE WHEN @GroupByPayType = 1 THEN  
			CASE WHEN [buPayType] > 1 THEN  
			[biBonusQnt] * @ShowIncludeBonus/ UintFactor * DIR 
			ELSE 0 END ELSE 0 END), 
		-- Show Total
		SUM([biBonusQnt] * @ShowIncludeBonus  /UintFactor   * DIR),
		---------------------------------------------		
		SUM(CASE WHEN @GroupByPayType = 1 THEN  CASE WHEN [buPayType] = 0 THEN  DIR
						* ( [bill].[biQty] * ( [bill].[FixedbiUnitPrice] - [bill].[FixedbiUnitDiscount] + [bill].[FixedbiUnitExtra]) + [FixedBiVat])
				 	ELSE 0 END 	ELSE 0 END), 
		SUM(CASE WHEN @GroupByPayType = 1 THEN  CASE WHEN [buPayType] = 1 THEN  DIR 
						* ( [bill].[BiQty] * ( [bill].[FixedbiUnitPrice] - [bill].[FixedbiUnitDiscount] + [bill].[FixedbiUnitExtra])+ [FixedBiVat]) 
				 	ELSE 0 END ELSE 0 END), 
		SUM(CASE WHEN @GroupByPayType = 1 THEN  
					CASE WHEN [buPayType] > 1 THEN  
						DIR * ( [bill].[BiQty] * ( [bill].[FixedbiUnitPrice] - [bill].[FixedbiUnitDiscount] + [bill].[FixedbiUnitExtra])+ [FixedBiVat])
				 	ELSE 0 END 	ELSE 0 END),
		-- ShowTotal
		SUM(DIR	* ( [bill].[BiQty] * ( [bill].[FixedbiUnitPrice] - [bill].[FixedbiUnitDiscount] + [bill].[FixedbiUnitExtra]) + [FixedBiVat])),
			 	
		------------------------------------------------
		 [AcTbl].[Security],
		[AcTbl].[Security],
		[Bill].[buSecurity],
		[mt].[mtSecurity],
		SEC
	FROM
		[#Account_Tbl] AS [AcTbl]  RIGHT JOIN 
		(
			SELECT 
				[Per].[PeriodID],[BuCustPtr],BuCustAcc,
				[mtDefUnitFact],
				SUM([biQty]) [biQty] ,
				SUM([biQty2]) [biQty2],
				SUM([biQty3]) [biQty3],
				SUM(biBonusQnt) biBonusQnt,
				CASE b.[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END SEC,
				CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END DIR, 
				[buPayType],[FixedbiUnitPrice],[FixedbiUnitDiscount],[FixedbiUnitExtra],SUM([FixedBiVat]) [FixedBiVat],
				[biMatPtr],[buSecurity]
			FROM
				[dbo].[fnExtended_Bi_Fixed]( @CurGUID) B
				INNER JOIN [#Src] AS [Src] ON b.[buType] = [Src].[Type]
                INNER JOIN @CustTbl AS [cu] ON [BuCustPtr]= [CustGUID]
				INNER JOIN @CostTbl AS [Co] ON b.[BiCostPtr] = [Co].[Number] 
				INNER JOIN @StoreTbl AS [St] ON b.[BiStorePtr] = [St].[Number] 
				INNER JOIN @PrdTbl AS [Per] ON b.[buDate] BETWEEN [Per].[StartDate] AND [Per].[EndDate] 
    	WHERE 
				( @Cust = @GUIDZero OR B.[BuCustPtr] = @Cust) 
				AND B.[buDate] between @StartDate AND @EndDate 
				AND (  ( @Posted > 2) 
					OR ( @Posted = 1 AND B.[buIsPosted] = 1 )
					OR ( @Posted = 2 AND B.[buIsPosted] = 0 )  )
			GROUP BY
				[Per].PeriodID,[BuCustPtr],
				CASE b.[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END ,
				CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END, 
				[buPayType],[FixedbiUnitPrice],[FixedbiUnitDiscount],[FixedbiUnitExtra],[FixedBiVat],
				[biMatPtr],BuCustAcc,
				[mtDefUnitFact],[buSecurity]) AS [bill] ON [AcTbl].[CustGuid] = [Bill].[BuCustPtr] 
					INNER JOIN [#MatTbl2] AS [mt] ON [Bill].[biMatPtr] = [mt].[mtNumber] 
	WHERE  
		 [AcTbl].[CustGuid] <> 0x0
	GROUP BY
		[bill].PeriodID,
		( CASE [BuCustPtr] WHEN @GUIDZero THEN[BuCustAcc] ELSE [AcTbl].[GUID] END),
		[CustGuid],
		[AcTbl].[Security],
		[AcTbl].[Security],
		[Bill].[buSecurity],
		[mt].[mtSecurity],
		SEC	
	------------------------------------------------------------------------------------
	EXEC [prcCheckSecurity]
	------------------------------------------------------------------------------------
	------ First Result Table----------------------------------------------------------- 
	CREATE TABLE [#ResultTbl] ( 
			[PeriodID] [INT], 
			[AccPtr] [UNIQUEIDENTIFIER], 
			[CuPtr] [UNIQUEIDENTIFIER],
			[Path] [NVARCHAR](max), 
			[CashQty] [FLOAT], 
			[ForwardQty] [FLOAT], 
			[NoteQty] [FLOAT], 
			[TotalQty] [FLOAT],
			[CashBonus] [FLOAT], 
			[ForwardBonus] [FLOAT], 
			[NoteBonus] [FLOAT], 
			[TotalBonus] [FLOAT],
			[CashPrice] [FLOAT], 
			[ForwardPrice] [FLOAT], 
			[NotePrice] [FLOAT],
			[TotalPrice] [FLOAT],
			[VirtualRecPtr] [UNIQUEIDENTIFIER], 
			[ParentGuid] [UNIQUEIDENTIFIER])

	------ End Result Table Collected by Level--------------------------------- 
	SELECT @MaxLevel = MAX([Level]) - 1 FROM [#Account_Tbl] 
	INSERT INTO #ResultTbl 
	SELECT 
		[Res].[ID] , 
		[Res].[Acc], 
		[Res].[Cu], 
		[AcTbl].[Path], 
		SUM( [Res].[CashQty]) , 
		SUM( [Res].[ForwardQty]), 
		SUM( [Res].[NoteQty]), 
		SUM( [Res].[TotalQty]), 
		SUM( [Res].[CashBonus]), 
		SUM( [Res].[ForwardBonus]), 
		SUM( [Res].[NoteBonus]), 
		SUM( [Res].[TotalBonus]), 
		SUM( [Res].[CashPrice]), 
		SUM( [Res].[ForwardPrice]), 
		SUM( [Res].[NotePrice]),
		SUM( [Res].[TotalPrice]),
		NEWID(),
		AcTbl.ParentGUID
	FROM
		[#Result] AS [Res] 
		INNER JOIN [#Account_Tbl] AS [AcTbl] ON  [Res].[Acc] = [AcTbl].[GUID] AND ([AcTbl].[CustGuid] = [Res].[Cu])
	WHERE 
		([AcTbl].[CustGuid] = CASE WHEN ISNULL(@Cust, 0x0) <> 0x0 THEN @Cust ELSE [AcTbl].[CustGuid] END)
	GROUP BY 
		[Res].[Cu],
		[Res].[Acc], 
		[AcTbl].[Path], 
		[Res].[ID],
		AcTbl.ParentGUID
	-------------------------------------------------------------------------- 
	WHILE @MaxLevel >= 0 
	BEGIN 
		--******************************************* 
		INSERT INTO [#ResultTbl] 
		SELECT 
			ISNULL ([RS].[PeriodID],-1), 
			[AcTbl].[GUID], 
			[AcTbl].[CustGuid], 
			[AcTbl].[Path], 
			SUM(ISNULL([CashQty], 0)) , 
			SUM(ISNULL([ForwardQty], 0)), 
			SUM(ISNULL([NoteQty], 0)), 
			SUM(ISNULL([TotalQty], 0)), 
			SUM(ISNULL([CashBonus], 0)), 
			SUM(ISNULL([ForwardBonus], 0)) , 
			SUM(ISNULL([NoteBonus], 0)), 
			SUM(ISNULL([TotalBonus], 0)), 
			SUM(ISNULL([CashPrice], 0)), 
			SUM(ISNULL([ForwardPrice], 0)), 
			SUM(ISNULL([NotePrice], 0)),
			SUM(ISNULL([TotalPrice], 0)),
			NEWID(),
			AcTbl.ParentGUID
		FROM 
			[#Account_Tbl] AS [AcTbl] 
			INNER JOIN [#ResultTbl] AS RS ON [AcTbl].[GUID] = [RS].[ParentGuid]
		WHERE 
			[AcTbl].[Level] = @MaxLevel
		GROUP BY
			ISNULL ([RS].[PeriodID],-1),
			[AcTbl].[CustGuid], 
			[AcTbl].[GUID],  
			[AcTbl].[Path],
			[AcTbl].[ParentGUID]
		--******************************************************* 
		SET @MaxLevel = @MaxLevel - 1
	END	
	IF @ShwEmpty = 0
		DELETE @PrdTbl WHERE [PeriodID] not in (SELECT DISTINCT [PeriodID] FROM #ResultTbl)
	SELECT * FROM @PrdTbl

	DECLARE @MinLevel INT 
	SET @MinLevel = 0
	IF @ShowMainAcc > 0
	BEGIN 
		SET @MinLevel = ISNULL((
			SELECT MIN([acTbl].[Level])
			FROM 
				#ResultTbl AS [res] 
				INNER JOIN [#Account_Tbl] AS [acTbl] ON [Res].[AccPtr] = acTbl.GUID 
			WHERE  
				( @AccLevel = 0 OR [acTbl].[Level] < @AccLevel) 
				AND [CashQty] IS NOT NULL), 0)

		UPDATE ResTbl1
		SET 
			ResTbl1.ParentGuid = ResTbl2.VirtualRecPtr
		FROM 
			[#ResultTbl] AS ResTbl1
			INNER JOIN [#ResultTbl] AS ResTbl2 ON ResTbl1.ParentGuid = ResTbl2.AccPtr
		WHERE 
			(ResTbl2.AccPtr IS NOT NULL OR ResTbl2.AccPtr = ResTbl1.AccPtr) 
	END 

	SELECT 
		[PeriodID], 
		-- CASE WHEN [cu].[AccountGuid] IS NULL THEN '' ELSE [CustomerName] END AS [CustFld], 
		ISNULL([acTbl].CustGuid, 0x0) AS CustGUID,
		[AccPtr] AS [accGUID], 
		[res].[ParentGuid]  AS ParentAccountGUID,
		[acTbl].[acCode] AS [accCode], 
		[acTbl].[acName] AS [accName], 
		[acTbl].[acLatinName] AS [accLatinName], 
		[CashQty], 
		[ForwardQty], 
		[NoteQty], 
		[TotalQty],
		[CashBonus], 
		[ForwardBonus], 
		[NoteBonus], 
		[TotalBonus], 
		[CashPrice] AS [CashVal], 
		[ForwardPrice] AS [ForwardVal], 
		[NotePrice] AS [NoteVal],
		[TotalPrice] AS [TotalVal],
		CASE @ShowMainAcc 
			WHEN 0 THEN 0 
			ELSE (CASE WHEN [acTbl].[Level] = @MinLevel THEN 1 ELSE 0 END) 
		END AS [bMain],
		[acTbl].Type ,
		ISNULL (Cu.[CustomerName],'') AS CustName,
		ISNULL (Cu.[LatinName],'') AS CustLatinName,
		CASE ISNULL([acTbl].CustGuid, 0x0) WHEN 0x0 THEN  AccPtr ELSE [acTbl].CustGuid END AS RecGUID,
		VirtualRecPtr
	FROM 
		#ResultTbl AS [res] 
		INNER JOIN [#Account_Tbl] AS [acTbl] ON [Res].[AccPtr] = acTbl.GUID AND ISNULL([Res].CuPtr,0x0)= ISNULL([acTbl].CustGuid,0x0)
		LEFT JOIN [vbCu] AS [Cu] ON [cu].GUID = [res].CuPtr
	WHERE  
		( @AccLevel = 0 OR [acTbl].[Level] < @AccLevel) 
		AND [CashQty] IS NOT NULL 
	ORDER BY 
		[res].[Path], 
		[Cu].[CustomerName]

	SELECT * FROM [#SecViol]
##########################################################################
#END
