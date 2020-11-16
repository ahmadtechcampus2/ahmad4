###########################################################
CREATE  PROCEDURE prcTrnExCurrencyMove
	@ExchangeType [UNIQUEIDENTIFIER],
	@Currency [UNIQUEIDENTIFIER],
	@StartDate [DateTime],
	@EndDate [DateTime],
	@ShowOrgCe [INT] = 0				-- ≈ŸÂ«— √’· «·”‰œ
AS      
	SET NOCOUNT ON 

	DECLARE @isGenEntriesAccordingToUserAccounts BIT = 0
	SELECT @isGenEntriesAccordingToUserAccounts = CAST(value AS BIT) FROM op000 WHERE name = 'TrnCfg_Exchange_GenEntriesAccordingToUserAccounts'
	SET @isGenEntriesAccordingToUserAccounts = ISNULL(@isGenEntriesAccordingToUserAccounts, 0)
	
	CREATE TABLE 	[#Exchange_Entries](
			[CurrencyGuid] 	[UNIQUEIDENTIFIER],
			[CurrencyVal] 	[FLOAT],
			[CeGUID] 	[UNIQUEIDENTIFIER],    
			[enGUID] 	[UNIQUEIDENTIFIER], 
			[CeNumber] 	[INT],    
			[EnNumber] 	[INT],
			[Date] 		[DATETIME],    
			[AccGUID] 	[UNIQUEIDENTIFIER],    
			[CostGuid] 	[UNIQUEIDENTIFIER],
			[ExTypeGuid] 	[UNIQUEIDENTIFIER],
			[ExParentType]	[INT], 
			[AvgEffect] 	[INT], 
			[EnDebit] 	[FLOAT],
			[EnCredit] 	[FLOAT],
			[EnParentGuid]	[UNIQUEIDENTIFIER]
			)
	INSERT INTO #Exchange_Entries
	SELECT 
		[CurrencyGuid],
		[CurrencyVal],
		[CeGUID],
		[enGuid],
		[CeNumber],
		[EnNumber],
		[Date] ,    
		[AccGUID],
		[CostGuid],
		[ExTypeGuid],
		[ExParentType],
		[AvgEffect],	
		[Debit] / CurrencyVal,
		[Credit] / CurrencyVal,
		[ParentGuid]
	from FnTrnExCurrEntries(0x0, @Currency, @StartDate, @EndDate, 0, 0x0) as fn
	ORDER BY [Date], CeNumber	

	INSERT INTO #Exchange_Entries 
	SELECT  
		En.currencyguid, 
		evdet.EvaluatedVal, 
		Ce.Guid,
		En.Guid,
		Ce.Number,
		En.Number,
		En.[Date], 
		en.AccountGuid, 
		en.CostGuid,
		0x0,
		5, 
		1, 
		En.debit / en.currencyval,
		En.credit / en.currencyval,
		En.ParentGuid
	FROM en000 AS en 
	INNER JOIN ce000 AS ce ON ce.guid = en.parentguid 
	INNER JOIN TrnCurrencyAccount000 AS ac ON ac.AccountGuid = en.AccountGuid AND ac.CurrencyGuid = en.CurrencyGuid 
	INNER JOIN Er000 AS er ON er.EntryGuid = ce.Guid		
	INNER JOIN TrnAccountsEvl000 AS ev ON ev.Guid = er.ParentGuid
	INNER JOIN TrnAccountsEvlDetail000 AS evdet ON evdet.ParentGuid = ev.GUID AND en.AccountGuid = evdet.AccountGuid AND en.CurrencyGuid = evdet.CurrencyGuid 
	WHERE	ce.[date] BETWEEN @StartDate AND @EndDate 
		AND (@Currency = ac.CurrencyGuid) 
		AND (evdet.Balance <> 0)		
	Declare @Date1 DateTime,
		@initBalance float,
		@initAVG FLOAT
	
	set @Date1 = DateAdd(ss, -1, @StartDate)	
	select	
		@initAVG = IsNull(CurAvg, 0),
		@initBalance = IsNull(CurBalance, 0)
	FROM	FnTrnGetCurAverage2(@Currency, @Date1)
		
	
	Declare @Debit float,@Credit float,
		@CurBalance Float, @Avg Float,
		@NewAvg Float, @CurrencyVal Float,
		@EnGuid UNIQUEIDENTIFIER,
		@ExTypeGuid UNIQUEIDENTIFIER,
		@EnParentGuid UNIQUEIDENTIFIER,
		@Date DateTime,
		@ExParentType INT,
		@AvgEffect INT	
	Set @CurBalance = @initBalance
	set @Avg = @initAVG
	Declare @EnAvgTable Table (EnGuid UNIQUEIDENTIFIER,  CurAvg Float) 
	DECLARE AvgCursor CURSOR FORWARD_ONLY FOR  
	select 
		EnGuid,
		CurrencyVal,		
		EnDebit,
 		EnCredit,
		ExTypeGuid,
		ExParentType,
		AvgEffect,
		EnParentGuid
	From #Exchange_Entries 
	--WHERE (EnDebit / CurrencyVal) > 1 OR (EnCredit / CurrencyVal) > 1
	
	ORDER BY [date],CeNumber, EnNumber			
	OPEN AvgCursor 
	FETCH NEXT FROM AvgCursor INTO
			@EnGuid, 
			@CurrencyVal, 
			@Debit,
			@credit,
			@ExTypeGuid,
			@ExParentType,
			@AvgEffect,
			@EnParentGuid
	WHILE @@FETCH_STATUS = 0 
	BEGIN  
		--set @CurAmount =  @Amount / @CurrencyVal
		IF (@ExParentType = 5)
			SET @Avg = @CurrencyVal
		ELSE
		IF ((@Debit <> 0) AND (@EnParentGUID NOT IN (SELECT EntryGuid FROM TrnCloseCashier000))) -- ‘—«¡
		BEGIN 
			IF (@AvgEffect <> 0) 
			BEGIN
				Set @NewAvg = (@CurBalance * @Avg + @Debit * @CurrencyVal)
				Set @NewAvg = @NewAvg / (@CurBalance + @Debit)
				set @CurBalance =  @CurBalance + @Debit
				SET @Avg = @NewAvg
			END	
		END		
		ELSE IF ((@Debit = 0) AND (@EnParentGUID NOT IN (SELECT EntryGuid FROM TrnCloseCashier000))) -- „»Ì⁄
		Begin
			set @CurBalance	= @CurBalance - @Credit
			IF (@CurBalance < 0 )
			BEGIN
				SET @CurBalance = 0
				--SET @Avg = 0
			END		
		END
		
		if (@ExchangeType = 0x0 OR @ExchangeType = @ExTypeGuid)
			insert into @EnAvgTable
			values (@EnGuid, @Avg)
	
		FETCH NEXT FROM AvgCursor INTO 
			@EnGuid,
			@CurrencyVal, 
			@Debit,
			@credit,
			@ExTypeGuid,
			@ExParentType,
			@AvgEffect,
			@EnParentGuid
	END  
	CLOSE AvgCursor 
	DEALLOCATE AvgCursor	
	CREATE TABLE [#Result] (
			--[CurrencyGuid],
			--[CurrencyVal],
			[CeGUID] [UNIQUEIDENTIFIER],    
			[enGUID] [UNIQUEIDENTIFIER], 
			[CeNumber] [FLOAT],    
			[enNumber] [FLOAT],    
			[Date] [DATETIME],    
			[AccGUID] [UNIQUEIDENTIFIER],    
			[acCode] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[acName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[acLatinName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[CurrencyGuid] [UNIQUEIDENTIFIER],
			[CurrencyVal] [FLOAT],
			[ExchangeCurVal] [FLOAT],
			[CurAvg] [FLOAT],
			[CostGUID] [UNIQUEIDENTIFIER],    
			--[ExTypeGuid][UNIQUEIDENTIFIER],   
			--[ExTypeName][NVARCHAR](250) COLLATE ARABIC_CI_AI,
			--[ExLatinName][NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[enDebit]	[FLOAT],    
			[enCredit] [FLOAT], 
			--[enFixDebit] [FLOAT],    
			--[enFixCredit] [FLOAT],    
			--[enCurPtr] [UNIQUEIDENTIFIER],    
			--[enCurVal] [FLOAT] DEFAULT 0,    
			--ObverseGUID [UNIQUEIDENTIFIER],    
			[ObvacCode] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[ObvacName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[ObvacLatinName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
			
			[enNotes] [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
			[ceNotes] [NVARCHAR](250) COLLATE ARABIC_CI_AI,       
			[ceSecurity] [INT],    
			[accSecurity] [INT],  
			[ceParentGUID] [UNIQUEIDENTIFIER],     
			[ceRecType] [INT],
			[ParentNumber] [INT], 
			[ParentName] [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
			--[Class] [NVARCHAR](250) COLLATE ARABIC_CI_AI,									-- Consolidate Notes? 
			[Branch] [UNIQUEIDENTIFIER])   
	INSERT INTO [#Result]
	SELECT
		ex.[CeGUID],
		ex.[enGuid],
		ex.[CeNumber],
		ex.[EnNumber],
		Ex.[Date] ,    
		ex.[AccGUID],
		Ac.[Name],
		Ac.[Code],
		Ac.[LatinName],
		ex.[CurrencyGuid],
		ex.[CurrencyVal],
		ex.[CurrencyVal], -- ExchangeCurVal
		ISNULL(enAvg.[CurAvg],0),
		ex.[CostGuid],
		--ex.[ExTypeGuid],
		--exType.[Name],
		--exType.[LatinName],
		ex.[EnDebit],
		ex.[EnCredit],
		IsNull(obv.[Code], ''),
		IsNull(obv.[Name],''),
		IsNull(obv.[LatinName],''),
		En.[Notes],
		Ce.[Notes],
		Ce.[security],
		ac.[security],
		0x0,
		0,
		0,
		'',
		Ce.[Branch]
	
	FROM 	#Exchange_Entries AS Ex
	INNER JOIN EN000 AS EN ON EN.Guid = Ex.EnGuid
	INNER JOIN CE000 AS CE ON CE.Guid = En.ParentGuid
	INNER JOIN Ac000 as Ac on Ac.Guid = En.AccountGUID
	LEFT JOIN Ac000 as obv on obv.Guid = En.ContraAccGuid 
	LEFT JOIN @EnAvgTable as enAvg on enAvg.EnGuid = EN.Guid		
	WHERE
		ex.[DATE] Between @StartDate And @EndDate  
		AND 
		(@ExchangeType = 0x0 OR @ExchangeType = ex.ExTypeGuid OR @isGenEntriesAccordingToUserAccounts = 1)		
	IF( @ShowOrgCe = 1)
	BEGIN 
			UPDATE [#Result] SET 
				[ceParentGUID] = [er].[erParentGuid],  
				[ceRecType] = [er].[erParentType],  
				[ParentNumber] = [er].[erParentNumber]
			FROM
				[#Result] AS [Res] 
				INNER JOIN [VwEr] AS [er] 
				ON [Res].[ceGuid] = [er].[erEntryGuid]  
			-------------------------------------------
			UPDATE [#Result] SET 
				[ParentName] = [et].[Abbrev]
				--[ExchangeCurVal] = ex.PayCurrencyVal
			FROM
				[#Result] AS res
				inner join TrnExchange000 as ex on ex.GUid = res.[ceParentGUID]
				INNER JOIN TrnExchangeTypes000 AS [et]
					ON [ex].[TypeGuid] = [et].[Guid]
			where 
				ceRecType = 507
				AND ex.CancelEntryGuid = 0x0
			-------------------------------------------
			-------------------------------------------
			UPDATE [#Result] SET 
				[ExchangeCurVal] = ex.PayCurrencyVal
			FROM
				[#Result] AS res
				inner join TrnExchange000 as ex on ex.GUid = res.[ceParentGUID]
				INNER JOIN TrnExchangeTypes000 AS [et]
					ON [ex].[TypeGuid] = [et].[Guid]
			where 
				ceRecType = 507 AND PayCurrency = @Currency
				AND ex.CancelEntryGuid = 0x0
			-------------------------------------------
			-------------------------------------------
			UPDATE [#Result] SET 
				[ParentName] = '  ’›Ì— «·’‰œÊﬁ'  + [et].[Abbrev]
			FROM
				TrnCloseCashier000 as cl 
				INNER JOIN TrnExchangeTypes000 AS [et]
					ON [cl].[ExchangeTypeGuid] = [et].[Guid]
			where ceRecType = 517
			-------------------------------------------
			-------------------------------------------
			UPDATE [#Result] SET 
				[ParentName] = ' ﬁÌÌ„'  
			where ceRecType = 518
	END
	-------------------------------------------------------------------------------------    	
	select @initbalance AS InitBalance , @initAvg As InitAvg
	select 
		[Date],
		CurrencyGuid,
		CurrencyVal,
		ExchangeCurVal,
		CeGuid,
		AccGuid,
		acCode,
		acName,
		acLatinName,
		CurAvg,
		ISNULL(cost.[Name], '') as CostName,
		ISNULL(cost.[LatinName], '') as CostLatinName,
		ISNULL(cost.code, '') as CostCode, 
		--ExTypeName,
		--ExLatinName,
		enDebit,
		enCredit,
		ObVacCode,
		ObvacName,
		ObvacLatinName,
		EnNotes,
		CeNotes,
		CeParentGuid,
		CeNumber,
		ParentNumber,
		ParentName,
		ceRecType,
		Branch
	from #Result as res
	LEFT JOIN co000 as cost on cost.Guid = res.CostGuid 
	Order By [Date], CeNumber 
###########################################################
CREATE PROCEDURE prcTrnGetCurrAvg
	@Currency	UNIQUEIDENTIFIER,
	@EndDate	[DateTime]
	,@CurrAvg	Float out
AS    
	-- created only to get currency average value from prcTrnExCurrencyMove
	SET NOCOUNT ON 
	Declare @StartDate DateTime
	SELECT @StartDate = Cast(value as datetime) from op000 where name = 'AmnCfg_FPDate'

	CREATE TABLE 	[#Exchange_Entries](
			[CurrencyGuid] 	[UNIQUEIDENTIFIER],
			[CurrencyVal] 	[FLOAT],
			[CeGUID] 	[UNIQUEIDENTIFIER],    
			[enGUID] 	[UNIQUEIDENTIFIER], 
			[CeNumber] 	[INT],    
			[EnNumber] 	[INT],
			[Date] 		[DATETIME],    
			[AccGUID] 	[UNIQUEIDENTIFIER],    
			[CostGuid] 	[UNIQUEIDENTIFIER],
			[ExTypeGuid] 	[UNIQUEIDENTIFIER],
			[ExParentType]	[INT], 
			[AvgEffect] 	[INT], 
			[EnDebit] 	[FLOAT],
			[EnCredit] 	[FLOAT],
			[EnParentGuid]	[UNIQUEIDENTIFIER]
			)
	INSERT INTO #Exchange_Entries
	SELECT 
		[CurrencyGuid],
		[CurrencyVal],
		[CeGUID],
		[enGuid],
		[CeNumber],
		[EnNumber],
		[Date] ,    
		[AccGUID],
		[CostGuid],
		[ExTypeGuid],
		[ExParentType],
		[AvgEffect],	
		[Debit] / CurrencyVal,
		[Credit] / CurrencyVal,
		[ParentGuid]
	from 
		FnTrnExCurrEntries(0x0, @Currency, @StartDate, @EndDate, 0, 0x0) as fn
	ORDER BY 
		[Date], CeNumber	

	INSERT INTO #Exchange_Entries 
	SELECT  
		En.currencyguid, 
		evdet.EvaluatedVal, 
		Ce.Guid,
		En.Guid,
		Ce.Number,
		En.Number,
		En.[Date], 
		en.AccountGuid, 
		en.CostGuid,
		0x0,
		5, 
		1, 
		En.debit / en.currencyval,
		En.credit / en.currencyval,
		En.ParentGuid
	FROM 
		en000 AS en 
		INNER JOIN ce000 AS ce ON ce.guid = en.parentguid 
		INNER JOIN TrnCurrencyAccount000 AS ac ON ac.AccountGuid = en.AccountGuid AND ac.CurrencyGuid = en.CurrencyGuid 
		INNER JOIN Er000 AS er ON er.EntryGuid = ce.Guid		
		INNER JOIN TrnAccountsEvl000 AS ev ON ev.Guid = er.ParentGuid
		INNER JOIN TrnAccountsEvlDetail000 AS evdet ON evdet.ParentGuid = ev.GUID AND en.AccountGuid = evdet.AccountGuid AND en.CurrencyGuid = evdet.CurrencyGuid 
	WHERE	
		ce.[date] BETWEEN @StartDate AND @EndDate 
		AND (@Currency = ac.CurrencyGuid) 
		AND (evdet.Balance <> 0)		
	Declare 
		@Date1			DateTime,
		@initBalance	float,
		@initAVG		FLOAT
	
	SET @Date1 = DateAdd(ss, -1, @StartDate)	
	SELECT	
		@initAVG =		IsNull(CurAvg, 0),
		@initBalance =	IsNull(CurBalance, 0)
	FROM	
		FnTrnGetCurAverage2(@Currency, @Date1)
		
	
	Declare 
		@Debit float,@Credit float,
		@CurBalance Float, @Avg Float,
		@NewAvg Float, @CurrencyVal Float,
		@EnGuid UNIQUEIDENTIFIER,
		@ExTypeGuid UNIQUEIDENTIFIER,
		@EnParentGuid UNIQUEIDENTIFIER,
		@Date DateTime,
		@ExParentType INT,
		@AvgEffect INT	
	Set @CurBalance = @initBalance
	set @Avg = @initAVG
	Declare @EnAvgTable Table (EnGuid UNIQUEIDENTIFIER,  CurAvg Float) 
	DECLARE AvgCursor CURSOR FORWARD_ONLY FOR  
	
	select 
		EnGuid,
		CurrencyVal,		
		EnDebit,
 		EnCredit,
		ExTypeGuid,
		ExParentType,
		AvgEffect,
		EnParentGuid
	From #Exchange_Entries 
	
	ORDER BY [date],CeNumber, EnNumber			
	OPEN AvgCursor 
	FETCH NEXT FROM AvgCursor INTO
			@EnGuid, 
			@CurrencyVal, 
			@Debit,
			@credit,
			@ExTypeGuid,
			@ExParentType,
			@AvgEffect,
			@EnParentGuid
	WHILE @@FETCH_STATUS = 0 
	BEGIN  
		IF (@ExParentType = 5)
			SET @Avg = @CurrencyVal
		ELSE
		IF ((@Debit <> 0) AND (@EnParentGUID NOT IN (SELECT EntryGuid FROM TrnCloseCashier000))) -- ‘—«¡
		BEGIN 
			IF (@AvgEffect <> 0) 
			BEGIN
				Set @NewAvg = (@CurBalance * @Avg + @Debit * @CurrencyVal)
				Set @NewAvg = @NewAvg / (@CurBalance + @Debit)
				set @CurBalance =  @CurBalance + @Debit
				SET @Avg = @NewAvg
			END	
		END		
		ELSE IF ((@Debit = 0) AND (@EnParentGUID NOT IN (SELECT EntryGuid FROM TrnCloseCashier000))) -- „»Ì⁄
		Begin
			set @CurBalance	= @CurBalance - @Credit
			IF (@CurBalance < 0 )
			BEGIN
				SET @CurBalance = 0
			END		
		END
		
		insert into @EnAvgTable values (@EnGuid, @Avg)
		FETCH NEXT FROM AvgCursor INTO 
			@EnGuid,
			@CurrencyVal, 
			@Debit,
			@credit,
			@ExTypeGuid,
			@ExParentType,
			@AvgEffect,
			@EnParentGuid
	END  
	CLOSE AvgCursor 
	DEALLOCATE AvgCursor	
	CREATE TABLE [#Result] (
			[CeGUID] [UNIQUEIDENTIFIER],    
			[enGUID] [UNIQUEIDENTIFIER], 
			[CeNumber] [FLOAT],    
			[enNumber] [FLOAT],    
			[Date] [DATETIME],    
			[AccGUID] [UNIQUEIDENTIFIER],    
			[acCode] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[acName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[acLatinName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[CurrencyGuid] [UNIQUEIDENTIFIER],
			[CurrencyVal] [FLOAT],
			[ExchangeCurVal] [FLOAT],
			[CurAvg] [FLOAT],
			[CostGUID] [UNIQUEIDENTIFIER],    
			[enDebit]	[FLOAT],    
			[enCredit] [FLOAT], 
			[ObvacCode] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[ObvacName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[ObvacLatinName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[enNotes] [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
			[ceNotes] [NVARCHAR](250) COLLATE ARABIC_CI_AI,       
			[ceSecurity] [INT],    
			[accSecurity] [INT],  
			[ceParentGUID] [UNIQUEIDENTIFIER],     
			[ceRecType] [INT],
			[ParentNumber] [INT], 
			[ParentName] [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
			[Branch] [UNIQUEIDENTIFIER])   
	INSERT INTO [#Result]
	SELECT
		ex.[CeGUID],
		ex.[enGuid],
		ex.[CeNumber],
		ex.[EnNumber],
		Ex.[Date] ,    
		ex.[AccGUID],
		Ac.[Name],
		Ac.[Code],
		Ac.[LatinName],
		ex.[CurrencyGuid],
		ex.[CurrencyVal],
		ex.[CurrencyVal], -- ExchangeCurVal
		ISNULL(enAvg.[CurAvg],0),
		ex.[CostGuid],
		ex.[EnDebit],
		ex.[EnCredit],
		IsNull(obv.[Code], ''),
		IsNull(obv.[Name],''),
		IsNull(obv.[LatinName],''),
		En.[Notes],
		Ce.[Notes],
		Ce.[security],
		ac.[security],
		0x0,
		0,
		0,
		'',
		Ce.[Branch]
	
	FROM 	#Exchange_Entries AS Ex
	INNER JOIN EN000 AS EN ON EN.Guid = Ex.EnGuid
	INNER JOIN CE000 AS CE ON CE.Guid = En.ParentGuid
	INNER JOIN Ac000 as Ac on Ac.Guid = En.AccountGUID
	LEFT JOIN Ac000 as obv on obv.Guid = En.ContraAccGuid 
	LEFT JOIN @EnAvgTable as enAvg on enAvg.EnGuid = EN.Guid		
	WHERE
		ex.[DATE] Between @StartDate And @EndDate  
	-------------------------------------------------------------------------------------    	
	IF EXISTS(SELECT * FROM #Result)
		SELECT TOP 1 @CurrAvg = CurAvg	
		FROM 
			#Result AS res
		ORDER BY 
			[Date] Desc, CeNumber 
	ELSE
		SELECT @CurrAvg = CurrencyVal FROM my000 WHERE guid = @Currency

###########################################################
#END