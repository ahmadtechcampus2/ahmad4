#######################################
CREATE PROCEDURE prcModifyCurValDifferences
	@SrcGuid AS [UNIQUEIDENTIFIER],
	@PeriodStartDate		AS [DATETIME],
	@PeriodEndDate			AS [DATETIME]
AS 
	SET NOCOUNT ON 
	
	DECLARE 
		@NormalEntry AS [INT], 
		@UserId AS [UNIQUEIDENTIFIER] 

	BEGIN TRAN 

	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT]) 
	CREATE TABLE [#NotesTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#ClctNotesTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])   
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#t1] ([t] [UNIQUEIDENTIFIER], [s] [UNIQUEIDENTIFIER], [c] [FLOAT], [d] [FLOAT]) 

	SELECT * INTO [#mh1] FROM [mh000] 
	INSERT INTO [#mh1] SELECT NEWID(),GUID,CURRENCYVAL,'1/1/1980' FROM My000 
	CREATE TABLE [#mh] 
	( 
		[ID] INT IDENTITY(1,1), 
		[DATE] [DATETIME], 
		[CurrencyGUID] [UNIQUEIDENTIFIER], 
		[CurrencyVal] [FLOAT] 
	) 
	 
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserID 
	INSERT INTO [#NotesTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserID 
	INSERT INTO [#ClctNotesTbl] EXEC [prcGetCollectNotesTypesList] @SrcGuid, @UserID 
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserID 
	INSERT INTO [#MH] ([DATE],CurrencyGUID,CurrencyVal) SELECT [DATE],[CurrencyGUID],[CurrencyVal] FROM [#mh1] ORDER BY CURRENcYGUID,[Date] 

	EXEC prcDisableTriggers 'ce000' 
	EXEC prcDisableTriggers 'en000' 
	DECLARE @Parms NVARCHAR(2000),@LgGuid UNIQUEIDENTIFIER 
	create table [#Src] ( [Type] uniqueidentifier) 
	INSERT INTO [#Src] 
		SELECT [Type] FROM [#BillTbl] 
		UNION ALL 
		SELECT [Type] FROM [#NotesTbl] 
		UNION ALL 
		SELECT [Type] FROM [#ClctNotesTbl] 
		UNION ALL 
		SELECT [Type] FROM [#EntryTbl] 
	EXEC  prcsetSrcStringLog @Parms OUTPUT 
	SELECT  [mh2].[Date] AS [StartDate],ISNULL(DATEADD(dd,- 1,[mh1].[Date]) ,'1/1/3000') AS [EndDate],[mh2].[CurrencyGUID],[mh2].[CurrencyVal],[my].[Name] AS [myName]  
	INTO [#mh2]  
	FROM  
		(#MH AS [mh1] RIGHT JOIN #MH AS [mh2] ON  [mh2].[CurrencyGUID] = [mh1].[CurrencyGUID] AND ([mh1].[id]- 1 ) = [mh2].[id]) 
		INNER JOIN [my000] AS [my] ON [my].[Guid] = [mh2].[CurrencyGuid] 
	 
	CREATE CLUSTERED INDEX [mhind] ON  [#mh2] ([StartDate],[EndDate],[CurrencyGUID]) 
	SET @NormalEntry = [dbo].[fnIsNormalEntry]( @SrcGuid) 
	SET @UserId = [dbo].[fnGetCurrentUserGUID]() 
	SELECT [en].* INTO [#en] FROM [en000] AS [en] INNER JOIN [#mh2]  AS [mh] 
			ON ([en].[Date] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [en].[CurrencyGuid] 
	WHERE  
			[en].[CurrencyVal] <> [mh].[CurrencyVal]
		AND ([en].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)

	-- Temp table for ce befor update.
	SELECT [ce].* INTO [#ce] FROM [ce000] AS [ce]
		WHERE GUID IN (Select ParentGUID from [#en])

	-- Temp table for py befor update.
	SELECT [py].* INTO [#py] FROM [py000] AS [py]
		WHERE GUID IN (Select ParentGUID from [er000] WHERE EntryGUID IN (SELECT GUID FROM [#ce])) 

	IF @NormalEntry = 1 
	BEGIN 
		--- differences in Items in ce000 
		UPDATE [ce]  
			SET  
				[Debit] = [ce].[Debit] / CASE [ce].[CurrencyVal] WHEN 0 THEN 1 ELSE [ce].[CurrencyVal] END * [mh].[CurrencyVal], 
				[Credit] = [ce].[Credit] / CASE [ce].[CurrencyVal] WHEN 0 THEN 1 ELSE [ce].[CurrencyVal] END * [mh].[CurrencyVal], 
				[CurrencyVal] = [mh].[CurrencyVal] 			 
		FROM 
			[ce000] AS [ce] INNER JOIN [#mh2]  AS [mh] 
			ON ([ce].[Date] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [ce].[CurrencyGuid] 			 
		WHERE  
			[ce].[CurrencyVal] <> [mh].[CurrencyVal] 
			AND [ce].[TypeGuid] = 0x0 
			AND ([ce].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)

		--- differences in Items in en000 
		DELETE bp
		FROM 
			[en000] AS [en] 
			INNER JOIN [bp000] bp ON (en.[GUID] = bp.DebtGUID) OR (en.[GUID] = bp.PayGUID)
			INNER JOIN [vwCeEn] AS [ce] ON [ce].[enguid] = [en].[GUID] 
			INNER JOIN [#mh2] AS [mh] ON ([ce].[enDate] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [ce].[enCurrencyPtr] 
		WHERE 
			[ce].[enCurrencyVal] <> [mh].[CurrencyVal] 
			AND [ce].[ceTypeGuid] = 0x0 
			AND [bp].[Type] = 0
			AND ([ce].[enDate] BETWEEN @PeriodStartDate AND @PeriodEndDate)

		UPDATE [en]  
			SET  
				[Debit] = [en].[Debit] / CASE [ce].[enCurrencyVal]  WHEN 0 THEN 1 ELSE [ce].[enCurrencyVal]  END * [mh].[CurrencyVal], 
				[Credit] = [EN].[Credit] / CASE [ce].[enCurrencyVal]  WHEN 0 THEN 1 ELSE [ce].[enCurrencyVal]  END * [mh].[CurrencyVal], 
				[CurrencyVal] = [mh].[CurrencyVal] 
		FROM 
			[en000] AS [en] INNER JOIN [vwCeEn] AS [ce] ON [ce].[enguid] = [en].[GUID] INNER JOIN [#mh2] AS [mh] 
			ON ([ce].[enDate] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [ce].[enCurrencyPtr] 
		WHERE 
			[ce].[enCurrencyVal] <> [mh].[CurrencyVal] 
			AND [ce].[ceTypeGuid] = 0x0 
			AND ([ce].[enDate] BETWEEN @PeriodStartDate AND @PeriodEndDate)
	END 

	-- «·”‰œ«  
	IF (SELECT COUNT(*) FROM [#EntryTbl]  )> 0 
	BEGIN 
		UPDATE [py]  
		SET [CurrencyVal] = [mh].[CurrencyVal] 
		FROM 
			[py000] AS [py] --INNER JOIN vwpy as vpy ON py.GUID = vpy.pyGUID -- this will consider branches 
			INNER JOIN [#EntryTbl] AS [et] ON [py].[TypeGUID] = [et].[Type] INNER JOIN [#mh2] AS [mh] 
			ON ([py].[Date] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [py].[CurrencyGuid] 
		WHERE  
			[py].[CurrencyVal] <> [mh].[CurrencyVal] 
			AND ([py].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)

		-- ﬁÌÊœ «·”‰œ«  
		UPDATE [ce]  
			SET  
				[Debit] = [ce].[Debit] / CASE [ce].[CurrencyVal]  WHEN 0 THEN 1 ELSE [ce].[CurrencyVal]  END * [mh].[CurrencyVal], 
				[Credit] = [ce].[Credit] / CASE [ce].[CurrencyVal]  WHEN 0 THEN 1 ELSE [ce].[CurrencyVal]  END * [mh].[CurrencyVal], 
				[CurrencyVal] = [mh].[CurrencyVal] 
		FROM 
			[ce000] AS [ce] 
			INNER JOIN [#EntryTbl] AS [et] ON [ce].[TypeGUID] = [et].[Type]  
			INNER JOIN [#mh2] AS [mh] 
			ON ([ce].[Date] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [ce].[CurrencyGuid] 
			-- INNER JOIN bu000 AS bu ON ce.TypeGuid = bu.TypeGuid INNER JOIN vwBu as vbu ON bu.GUID = vbu.buGUID -- this will consider branches 
		WHERE 
			[ce].[CurrencyVal] <> [mh].[CurrencyVal] 
			AND [ce].[TypeGuid] <> 0x0 
			AND ([ce].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)

		DELETE bp
		FROM 
			[en000] AS [en] 
			INNER JOIN [bp000] bp ON (en.[GUID] = bp.DebtGUID) OR (en.[GUID] = bp.PayGUID)
			INNER JOIN [vwCeEn] AS [ce] ON [ce].[enguid] = [en].[GUID]  
			INNER JOIN [#EntryTbl] AS [et] ON [ce].[ceTypeGUID] = [et].[Type]  
			INNER JOIN [#mh2] AS [mh] ON ([ce].[enDate] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [ce].[enCurrencyPtr] 
		WHERE 
			[ce].[enCurrencyVal] <> [mh].[CurrencyVal] 
			AND 
			[ce].[ceTypeGuid] <> 0x0	 
			AND 
			[bp].[Type] = 0
			AND ([ce].[enDate] BETWEEN @PeriodStartDate AND @PeriodEndDate)
		 
		-- ﬁÌÊœ «·”‰œ«  
		UPDATE [en]  
			SET  
				[Debit] = [en].[Debit] / CASE [ce].[enCurrencyVal]  WHEN 0 THEN 1 ELSE [ce].[enCurrencyVal]  END * [mh].[CurrencyVal], 
				[Credit] = [en].[Credit] / CASE [ce].[enCurrencyVal]  WHEN 0 THEN 1 ELSE [ce].[enCurrencyVal]  END * [mh].[CurrencyVal], 
				[CurrencyVal] = [mh].[CurrencyVal] 
		FROM 
			[en000] AS [en] INNER JOIN [vwCeEn] AS [ce] ON [ce].[enguid] = [en].[GUID]  
			INNER JOIN [#EntryTbl] AS [et] ON [ce].[ceTypeGUID] = [et].[Type]  
			INNER JOIN [#mh2] AS [mh] 
			ON ([ce].[enDate] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [ce].[enCurrencyPtr] 
		WHERE 
			[ce].[enCurrencyVal] <> [mh].[CurrencyVal] 
			AND [ce].[ceTypeGuid] <> 0x0	 
			AND ([ce].[enDate] BETWEEN @PeriodStartDate AND @PeriodEndDate)
	END 
	 
	--«·›Ê« Ì— 
	IF (SELECT COUNT(*) FROM [#BillTbl] )> 0 
	BEGIN 
		DELETE bp
		FROM 
			[bu000] AS [bu] 
			INNER JOIN [bp000] bp ON (bu.[GUID] = bp.DebtGUID) OR (bu.[GUID] = bp.PayGUID)
			INNER JOIN [vwBu] as [vbu] ON [bu].[GUID] = [vbu].[buGUID] -- this will consider branches 
			INNER JOIN [#BillTbl] AS [bt] ON [bu].[TypeGUID] = [bt].[Type]  
			INNER JOIN [#mh2] AS [mh] 
			ON ([bu].[Date] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [bu].[CurrencyGuid] 
		WHERE  
			[bu].[CurrencyVal] <> [mh].[CurrencyVal] 
			AND 
			[bp].[Type] = 0
			AND ([bu].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)

		UPDATE [bu000] 
			SET  
			[Total] = [bu].[Total] / CASE [bu].[CurrencyVal] WHEN 0 THEN 1 ELSE [bu].[CurrencyVal] END * [mh].[CurrencyVal], 
			[TotalDisc] = [bu].[TotalDisc] / CASE [bu].[CurrencyVal] WHEN 0 THEN 1 ELSE [bu].[CurrencyVal] END * [mh].[CurrencyVal], 
			[TotalExtra] = [bu].[TotalExtra] / CASE [bu].[CurrencyVal] WHEN 0 THEN 1 ELSE [bu].[CurrencyVal] END * [mh].[CurrencyVal], 
			[ItemsDisc] = [bu].[ItemsDisc] / CASE [bu].[CurrencyVal] WHEN 0 THEN 1 ELSE [bu].[CurrencyVal] END * [mh].[CurrencyVal], 
			[ItemsExtra] = [bu].[ItemsExtra] / CASE [bu].[CurrencyVal] WHEN 0 THEN 1 ELSE [bu].[CurrencyVal] END * [mh].[CurrencyVal], 
			[BonusDisc] = [bu].[BonusDisc] / CASE [bu].[CurrencyVal] WHEN 0 THEN 1 ELSE [bu].[CurrencyVal] END * [mh].[CurrencyVal], 
			[FirstPay] = [bu].[FirstPay] / CASE [bu].[CurrencyVal] WHEN 0 THEN 1 ELSE [bu].[CurrencyVal] END * [mh].[CurrencyVal],	 
			[Profits] = [bu].[Profits] / CASE [bu].[CurrencyVal] WHEN 0 THEN 1 ELSE [bu].[CurrencyVal] END * [mh].[CurrencyVal],	 
			[Vat] = [bu].[Vat] / CASE [bu].[CurrencyVal] WHEN 0 THEN 1 ELSE [bu].[CurrencyVal] END * [mh].[CurrencyVal],					 
			[CurrencyVal] = [mh].[CurrencyVal] 
		FROM 
			[bu000] AS [bu] INNER JOIN [vwBu] as [vbu] ON [bu].[GUID] = [vbu].[buGUID] -- this will consider branches 
			INNER JOIN [#BillTbl] AS [bt] ON [bu].[TypeGUID] = [bt].[Type]  
			INNER JOIN [#mh2] AS [mh] 
			ON ([bu].[Date] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [bu].[CurrencyGuid] 
		WHERE  
			[bu].[CurrencyVal] <> [mh].[CurrencyVal] 
			AND ([bu].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)
		EXEC prcDisableTriggers 'bi000' 
		update [bi000] SET 
				[currencyVal] = [mh].[CurrencyVal], 
				[Price] = ([Price] / (CASE WHEN [x].[biCurrencyVal] = 0 THEN 1 ELSE [x].[biCurrencyVal] END)) * [mh].[CurrencyVal], 
				[Discount] = ([Discount] / (CASE WHEN [x].[biCurrencyVal] = 0 THEN 1 ELSE [x].[biCurrencyVal] END)) * [mh].[CurrencyVal], 
				[BonusDisc] = ([BonusDisc] / (CASE WHEN [x].[biCurrencyVal] = 0 THEN 1 ELSE [x].[biCurrencyVal] END)) * [mh].[CurrencyVal], 
				[Extra] = ([Extra] / (CASE WHEN [x].[biCurrencyVal] = 0 THEN 1 ELSE [x].[biCurrencyVal] END)) *[mh].[CurrencyVal], 
				[Profits] = ([Profits] / (CASE WHEN [x].[biCurrencyVal] = 0 THEN 1 ELSE [x].[biCurrencyVal] END)) * [mh].[CurrencyVal], 
				[VAT] = ([VAT] / (CASE WHEN [x].[biCurrencyVal] = 0 THEN 1 ELSE [x].[biCurrencyVal] END)) * [mh].[CurrencyVal] 
			FROM 
				[vwextended_bi] [x] INNER JOIN [bi000] AS [bi] ON [x].[buGUID] = [bi].[ParentGUID] 
				INNER JOIN [#mh2] AS [mh] 
				ON ([x].[buDate] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [x].[biCurrencyPtr] 
			WHERE [x].[bicurrencyVal] <> [mh].[CurrencyVal] 
				AND ([x].[buDate] BETWEEN @PeriodStartDate AND @PeriodEndDate)
		EXEC prcEnableTriggers 'bi000' 
		--- select currencyGuid from bu000 
		-------------////////////di000 
		-- truncate table @t 
		 
		EXEC prcDisableTriggers 'di000' 
		UPDATE [di000] SET 
				[currencyVal] = [mh].[CurrencyVal], 
				[Discount] = ([Discount] / (CASE WHEN [x].[CurrencyVal] = 0 THEN 1 ELSE [x].[CurrencyVal] END)) * [mh].[CurrencyVal], 
				[Extra] = ([Extra] / (CASE WHEN [x].[CurrencyVal] = 0 THEN 1 ELSE [x].[CurrencyVal] END)) * [mh].[CurrencyVal] 
			FROM 
				[di000] [x] INNER JOIN [bu000] AS [bu] on [x].[ParentGuid] = [bu].[Guid]  
				INNER JOIN [#mh2] AS [mh] 
				ON ([bu].[Date] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [bu].[CurrencyGuid] 
			WHERE [x].[currencyVal] <> [mh].[CurrencyVal] 
				AND ([bu].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)
		EXEC prcEnableTriggers 'di000' 
		-- ﬁÌÊœ «·›Ê« Ì— 
		UPDATE [ce]  
			SET  
				[Debit] = [ce].[Debit] / CASE [ce].[CurrencyVal]  WHEN 0 THEN 1 ELSE [ce].[CurrencyVal]  END * [mh].[CurrencyVal], 
				[Credit] = [ce].[Credit] / CASE [ce].[CurrencyVal]  WHEN 0 THEN 1 ELSE [ce].[CurrencyVal]  END * [mh].[CurrencyVal], 
				[CurrencyVal] = [mh].[CurrencyVal] 
		FROM 
			[ce000] AS [ce] 
			INNER JOIN [#BillTbl] AS [bt] ON [ce].[TypeGUID] = [bt].[Type]  
			INNER JOIN [#mh2] AS [mh] 
			ON ([ce].[Date] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [ce].[CurrencyGuid] 
			-- INNER JOIN bu000 AS bu ON ce.TypeGuid = bu.TypeGuid INNER JOIN vwBu as vbu ON bu.GUID = vbu.buGUID -- this will consider branches 
		WHERE 
			[ce].[CurrencyVal] <> [mh].[CurrencyVal] 
			AND [ce].[TypeGuid] <> 0x0	 
			AND ([ce].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)
		-- ﬁÌÊœ «·›Ê« Ì— 
		UPDATE [en]  
			SET  
				[Debit] = [en].[Debit] / CASE [ce].[enCurrencyVal]  WHEN 0 THEN 1 ELSE [ce].[enCurrencyVal]  END * [mh].[CurrencyVal], 
				[Credit] = [en].[Credit] / CASE [ce].[enCurrencyVal]  WHEN 0 THEN 1 ELSE [ce].[enCurrencyVal]  END * [mh].[CurrencyVal], 
				[CurrencyVal] = [mh].[CurrencyVal] 
		FROM 
			[en000] AS [en] INNER JOIN [vwCeEn] AS [ce] ON [ce].[enguid] = [en].[GUID] 
			INNER JOIN [#BillTbl] AS [bt] ON [ce].[ceTypeGUID] = [bt].[Type]  
			INNER JOIN [#mh2] AS [mh] 
			ON ([ce].[enDate] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [ce].[enCurrencyPtr] 
		WHERE 
			[ce].[enCurrencyVal] <> [mh].[CurrencyVal] 
			AND [ce].[ceTypeGuid] <> 0x0	 
			AND ([ce].[enDate] BETWEEN @PeriodStartDate AND @PeriodEndDate)
	END 

	-- «·√Ê—«ﬁ «·„«·Ì… 
	IF (SELECT COUNT(*) FROM [#NotesTbl])> 0 
	BEGIN 
		UPDATE [ch] 
			SET [Val] = [ch].[Val] / CASE [ch].[CurrencyVal] WHEN 0 THEN 1 ELSE [ch].[CurrencyVal] END * [mh].[CurrencyVal], 
			[CurrencyVal] = [mh].[CurrencyVal]  
		FROM 
			[ch000] AS [ch] INNER JOIN [vwch] as [vch] ON [ch].[GUID] = [vch].[chGUID] -- this will consider branches 
			INNER JOIN [#NotesTbl] AS [nt] ON [ch].[TypeGUID] = [nt].[Type]  
			INNER JOIN [#mh2] AS [mh] 
			ON ([ch].[Date] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [ch].[CurrencyGuid] 
		WHERE  
			[ch].[CurrencyVal] <> [mh].[CurrencyVal] 
			AND ([ch].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)
		-- ﬁÌÊœ «·›Ê« Ì— 
		UPDATE [ce]  
			SET  
				[Debit] = [ce].[Debit] / CASE [ce].[CurrencyVal] WHEN 0 THEN 1 ELSE [ce].[CurrencyVal] END * [mh].[CurrencyVal], 
				[Credit] = [ce].[Credit] / CASE [ce].[CurrencyVal] WHEN 0 THEN 1 ELSE [ce].[CurrencyVal] END * [mh].[CurrencyVal], 
				[CurrencyVal] = [mh].[CurrencyVal] 
			 
		FROM 
			[ce000] AS [ce]  
			INNER JOIN [#NotesTbl] AS [nt] ON [ce].[TypeGUID] = [nt].[Type]  
			INNER JOIN [#mh2] AS [mh] 
			ON ([ce].[Date] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [ce].[CurrencyGuid] 
		WHERE 
			[ce].[CurrencyVal] <> [mh].[CurrencyVal] 
			AND [ce].[TypeGuid] <> 0x0	 
			AND ([ce].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)

		DELETE bp
		FROM 
			[en000] AS [en] 
			INNER JOIN [bp000] bp ON (en.[GUID] = bp.DebtGUID) OR (en.[GUID] = bp.PayGUID)
			INNER JOIN [vwCeEn] AS [ce] ON [ce].[enguid] = [en].[GUID] 
			INNER JOIN [#NotesTbl] AS [nt] ON [ce].[ceTypeGUID] = [nt].[Type]  
			INNER JOIN [#mh2] AS [mh] 
			ON ([enDate] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [ce].[enCurrencyPtr] 
		WHERE 
			[ce].[enCurrencyVal] <> [mh].[CurrencyVal] 
			AND [ce].[ceTypeGuid] <> 0x0	 
			AND [bp].[Type] = 0
			AND ([enDate] BETWEEN @PeriodStartDate AND @PeriodEndDate)

		UPDATE [en]  
			SET  
				[Debit] = [en].[Debit] / CASE [ce].[enCurrencyVal]  WHEN 0 THEN 1 ELSE [ce].[enCurrencyVal]  END * [mh].[CurrencyVal], 
				[Credit] = [en].[Credit] / CASE [ce].[enCurrencyVal]  WHEN 0 THEN 1 ELSE [ce].[enCurrencyVal]  END * [mh].[CurrencyVal], 
				[CurrencyVal] = [mh].[CurrencyVal] 
		FROM 
			[en000] AS [en] INNER JOIN [vwCeEn] AS [ce] ON [ce].[enguid] = [en].[GUID] 
			INNER JOIN [#NotesTbl] AS [nt] ON [ce].[ceTypeGUID] = [nt].[Type]  
			INNER JOIN [#mh2] AS [mh] 
			ON ([enDate] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [ce].[enCurrencyPtr] 
		WHERE 
			[ce].[enCurrencyVal] <> [mh].[CurrencyVal] 
			AND [ce].[ceTypeGuid] <> 0x0	 
			AND ([enDate] BETWEEN @PeriodStartDate AND @PeriodEndDate)
	END 

	-- RESTORE UNBALANCED ENTRYS VALUES
	UPDATE [py] SET 
		[CurrencyVal] = [p].[CurrencyVal] 
	FROM [py000] AS [py] INNER JOIN [#py] AS [p] ON [py].[Guid] =[p].[Guid]  
	WHERE [py].[GUID] IN
	(Select ParentGUID from [er000] WHERE EntryGUID IN
		(SELECT [ParentGUID] FROM [en000] GROUP BY [ParentGUID] HAVING ABS(SUM([Debit]) - SUM([Credit])) > [dbo].[fnGetZeroValuePrice]()) 
	)
	AND ([py].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)

	UPDATE [ce] SET 
		[Debit] = [c].[Debit], 
		[Credit] = [c].[Credit] , 
		[CurrencyVal] = [c].[CurrencyVal] 
	FROM [ce000] AS [ce] INNER JOIN [#ce] AS [c] ON [c].[Guid] =[ce].[Guid]  
	WHERE [ce].[Guid] IN
	(SELECT [ParentGUID] FROM [en000] GROUP BY [ParentGUID] HAVING ABS(SUM([Debit]) - SUM([Credit])) > [dbo].[fnGetZeroValuePrice]()) 
	AND ([ce].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)

	DELETE bp
	FROM 
		[en000] AS [en] 
		INNER JOIN [bp000] bp ON (en.[GUID] = bp.DebtGUID) OR (en.[GUID] = bp.PayGUID)
		INNER JOIN [#en] AS [e] ON [e].[Guid] =[en].[Guid]  
	WHERE 
		[en].[ParentGuid] IN(SELECT [ParentGUID] FROM [en000] GROUP BY [ParentGUID] HAVING ABS(SUM([Debit]) - SUM([Credit])) > [dbo].[fnGetZeroValuePrice]()) 
		AND [bp].[Type] = 0
		AND ([en].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)

	UPDATE [en] SET 
		[Debit] = [e].[Debit], 
		[Credit] = [e].[Credit] , 
		[CurrencyVal] = [e].[CurrencyVal] 
	FROM [en000] AS [en] INNER JOIN [#en] AS [e] ON [e].[Guid] =[en].[Guid]  
	WHERE [en].[ParentGuid] IN
	(SELECT [ParentGUID] FROM [en000] GROUP BY [ParentGUID] HAVING ABS(SUM([Debit]) - SUM([Credit])) > [dbo].[fnGetZeroValuePrice]()) 
	AND ([en].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)
	
	EXEC prcEnableTriggers 'en000' 
	EXEC prcEnableTriggers 'ce000' 

	EXEC [prcEntry_rePost] 
	IF @@ERROR <> 0 
		ROLLBACK TRAN 
	ELSE 
		COMMIT TRAN 
	EXEC prcCloseMaintenanceLog @LgGuid 
/* 
PRCCONNECTIONS_ADD2 '„œÌ—' 
exec  [prcModifyCurValDifferences] 0X00  
*/ 
##########################################
#END