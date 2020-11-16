#####################################################
CREATE PROCEDURE prcGetCurValDifferences
	@SrcGuid AS [UNIQUEIDENTIFIER],
	@PeriodStartDate		AS [DATETIME],
	@PeriodEndDate			AS [DATETIME]
AS
	SET NOCOUNT ON
	CREATE TABLE [#R]
	(
		--Type			INTEGER,
		--Number		FLOAT,
		[RecType]		[INTEGER], -- 0 ce, 1 bu, 2 py, 3 ch
		[ceGuid]		[UNIQUEIDENTIFIER],
		[ceTypeGuid]	[UNIQUEIDENTIFIER],
		[CurrencyName]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[ceCurrencyVal]	[FLOAT],
		[mhCurrencyVal]	[FLOAT],
		[ceEqu]			[FLOAT],
		[mhEqu]			[FLOAT]
	)
	DECLARE @NormalEntry AS [INT],
	@UserId AS [UNIQUEIDENTIFIER]

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
	
	SELECT  [mh2].[Date] AS [StartDate],ISNULL(DATEADD(dd,- 1,[mh1].[Date]) ,'1/1/3000') AS [EndDate],[mh2].[CurrencyGUID],[mh2].[CurrencyVal],[my].[Name] AS [myName] 
	INTO [#mh2] 
	FROM 
	(#MH AS [mh1] RIGHT JOIN #MH AS [mh2] ON  [mh2].[CurrencyGUID] = [mh1].[CurrencyGUID] AND ([mh1].[id]- 1 ) = [mh2].[id])
	INNER JOIN [my000] AS [my] ON [my].[Guid] = [mh2].[CurrencyGuid]
	
	CREATE CLUSTERED INDEX [mhind] ON  [#mh2] ([StartDate],[EndDate],[CurrencyGUID])
	SET @NormalEntry = [dbo].[fnIsNormalEntry]( @SrcGuid)
	SET @UserId = [dbo].[fnGetCurrentUserGUID]()


-- select * from mh000
	IF @NormalEntry = 1
	BEGIN
		--- differences in Items in ce000
		INSERT INTO [#R]
		SELECT
			--ce.Type,
			--ce.Number,
			0, -- RecType 
			[ce].[Guid] AS [ceGuid],
			[ce].[TypeGuid]AS [ceTypeGuid],
			[myName],
			[ce].[CurrencyVal] AS [ceCurrencyVal],
			[mh].[CurrencyVal] AS [mhCurrencyVal],
			1 / CASE [ce].[CurrencyVal] WHEN 0 THEN 1 ELSE [ce].[CurrencyVal] END,
			1 / CASE [mh].[CurrencyVal] WHEN 0 THEN 1 ELSE [mh].[CurrencyVal] END
		FROM
			[ce000] AS [ce] INNER JOIN [#mh2]  AS [mh]
			ON ([ce].[Date] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [ce].[CurrencyGuid]
			
		WHERE 
			[ce].[CurrencyVal] <> [mh].[CurrencyVal]
			AND [ce].[TypeGuid] = 0x0
			AND ([ce].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)

		--- differences in Items in en000
		INSERT INTO [#R]
		SELECT
			--ce.Type,
			--ce.Number,
			0, -- RecType 
			[ce].[ceGuid] AS [ceGuid],
			[ce].[ceTypeGuid]AS [ceTypeGuid],
			[myName],
			[ce].[enCurrencyVal] AS [ceCurrencyVal],
			[mh].[CurrencyVal] AS [mhCurrencyVal],
			1 / CASE [ce].[enCurrencyVal] WHEN 0 THEN 1 ELSE [ce].[enCurrencyVal] END,
			1 / CASE [mh].[CurrencyVal] WHEN 0 THEN 1 ELSE [mh].[CurrencyVal] END
		FROM
			[vwCeEn] AS [ce] INNER JOIN [#mh2] AS [mh]
			ON ([ce].[enDate] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [ce].[enCurrencyPtr]
		WHERE
			[ce].[enCurrencyVal] <> [mh].[CurrencyVal]
			AND [ce].[ceTypeGuid] = 0x0
			AND ([ce].[enDate] BETWEEN @PeriodStartDate AND @PeriodEndDate)
-- select * from vwCeEn
	END
	-- «·”‰œ« 
	IF (SELECT COUNT(*) FROM [#EntryTbl]  )> 0
	BEGIN
		INSERT INTO [#R]
		SELECT
			2, --RecType
			[py].[Guid] AS [ceGuid],
			[py].[TypeGuid] AS [ceTypeGuid],
			[myName],
			[py].[CurrencyVal] AS [ceCurrencyVal],
			[mh].[CurrencyVal] AS [mhCurrencyVal],
			1 / CASE [py].[CurrencyVal] WHEN 0 THEN 1 ELSE [py].[CurrencyVal] END,
			1 / CASE [mh].[CurrencyVal] WHEN  0 THEN 1 ELSE [mh].[CurrencyVal] END
		FROM
			[py000] AS [py] --INNER JOIN vwpy as vpy ON py.GUID = vpy.pyGUID -- this will consider branches
			INNER JOIN [#EntryTbl] AS [et] ON [py].[TypeGUID] = [et].[Type] INNER JOIN [#mh2] AS [mh]
			ON ([py].[Date] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [py].[CurrencyGuid]
			
		WHERE 
			[py].[CurrencyVal] <> [mh].[CurrencyVal]
			AND ([py].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)

		-- ﬁÌÊœ «·”‰œ« 
		INSERT INTO [#R]
		SELECT
			0, -- RecType 
			[ce].[Guid] AS [ceGuid],
			[ce].[TypeGuid] AS [ceTypeGuid],
			[myName],
			[ce].[CurrencyVal] AS [ceCurrencyVal],
			[mh].[CurrencyVal] AS [mhCurrencyVal],
			1 / CASE [ce].[CurrencyVal] WHEN 0 THEN 1 ELSE [ce].[CurrencyVal] END,
			1 / CASE [mh].[CurrencyVal] WHEN 0 THEN 1 ELSE [mh].[CurrencyVal] END
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
		--- differences in Items in en000

		INSERT INTO [#R]
		SELECT
			0, --RecType
			[ce].[Guid] AS [ceGuid],
			[ce].[TypeGuid] AS [ceTypeGuid],
			[myName],
			[ce].[CurrencyVal] AS [ceCurrencyVal],
			[mh].[CurrencyVal] AS [mhCurrencyVal],
			1 / CASE [ce].[CurrencyVal] WHEN 0 THEN 1 ELSE [ce].[CurrencyVal] END,
			1 / CASE [mh].[CurrencyVal] WHEN  0 THEN 1 ELSE [mh].[CurrencyVal] END
		FROM
			[py000] AS [pyt] --INNER JOIN vwpy as vpy ON py.GUID = vpy.pyGUID -- this will consider branches
			INNER JOIN [#EntryTbl] AS [et] ON [pyt].[TypeGUID] = [et].[Type] 
			INNER JOIN [#mh2] AS [mh]
			ON ([pyt].[Date] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [pyt].[CurrencyGuid]
			INNER JOIN [er000] As er On [er].[ParentGuid] = [pyt].[GUID]
			INNER JOIN [ce000] As ce On [Ce].[Guid] = [er].[EntryGUID]
		WHERE 
			[pyt].[CurrencyVal] <> [mh].[CurrencyVal]
			AND ([pyt].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)

		-- ﬁÌÊœ «·”‰œ« 
		INSERT INTO [#R]
		SELECT
			0, -- RecType 
			[ce].[ceGuid] AS [ceGuid],
			[ce].[ceTypeGuid] AS [ceTypeGuid],
			[myName],
			[ce].[enCurrencyVal] AS [ceCurrencyVal],
			[mh].[CurrencyVal] AS [mhCurrencyVal],
			1 / CASE [ce].[enCurrencyVal] WHEN 0 THEN 1 ELSE [ce].[enCurrencyVal] END,
			1 / CASE [mh].[CurrencyVal] WHEN 0 THEN 1 ELSE [mh].[CurrencyVal] END
		FROM
			[vwCeEn] AS [ce]
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
		INSERT INTO [#R]
		SELECT
			1, --RecType
			[bu].[Guid] AS [ceGuid],
			[bu].[TypeGuid] AS [ceTypeGuid],
			[myName],
			[bu].[CurrencyVal] AS [ceCurrencyVal],
			[mh].[CurrencyVal] AS [mhCurrencyVal],
			1 / CASE [bu].[CurrencyVal] WHEN 0 THEN 1 ELSE [bu].[CurrencyVal] END,
			1 / CASE [mh].[CurrencyVal] WHEN 0 THEN 1 ELSE [mh].[CurrencyVal] END
		FROM
			[bu000] AS [bu] INNER JOIN [vwBu] as [vbu] ON [bu].[GUID] = [vbu].[buGUID] -- this will consider branches
			INNER JOIN [#BillTbl] AS [bt] ON [bu].[TypeGUID] = [bt].[Type] 
			INNER JOIN [#mh2] AS [mh]
			ON ([bu].[Date] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [bu].[CurrencyGuid]
			
		WHERE 
			[bu].[CurrencyVal] <> [mh].[CurrencyVal]
			AND ([bu].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)

		-- ﬁÌÊœ «·›Ê« Ì—
		INSERT INTO [#R]
		SELECT
			0, -- RecType 
			[ce].[Guid] ,
			[ce].[TypeGuid],
			[myName],
			[ce].[CurrencyVal] AS [ceCurrencyVal],
			[mh].[CurrencyVal] AS [mhCurrencyVal],
			1 / CASE [ce].[CurrencyVal] WHEN 0 THEN 1 ELSE [ce].[CurrencyVal] END,
			1 / CASE [mh].[CurrencyVal] WHEN 0 THEN 1 ELSE [mh].[CurrencyVal] END
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
--------------differences in Items
		-- ﬁÌÊœ «·›Ê« Ì—
		INSERT INTO [#R]
		SELECT
			0, -- RecType 
			[ce].[ceGuid] AS [ceGuid],
			[ce].[ceTypeGuid] AS [ceTypeGuid],
			[myName],
			[ce].[enCurrencyVal] AS [ceCurrencyVal],
			[mh].[CurrencyVal] AS [mhCurrencyVal],
			1 / CASE [ce].[enCurrencyVal] WHEN 0 THEN 1 ELSE [ce].[enCurrencyVal] END,
			1 / CASE [mh].[CurrencyVal] WHEN 0 THEN 1 ELSE [mh].[CurrencyVal] END
		FROM
			[vwCeEn] AS [ce]
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
		INSERT INTO [#R]
		SELECT
			3, --RecType
			[ch].[Guid] AS [ceGuid],
			[ch].[TypeGuid] AS [ceTypeGuid],
			[myName],
			[ch].[CurrencyVal] AS [ceCurrencyVal],
			[mh].[CurrencyVal] AS [mhCurrencyVal],
			1 / CASE [ch].[CurrencyVal] WHEN 0 THEN 1 ELSE [ch].[CurrencyVal] END,
			1 / CASE [mh].[CurrencyVal] WHEN 0 THEN 1 ELSE [mh].[CurrencyVal] END
		FROM
			[ch000] AS [ch] INNER JOIN [vwch] as [vch] ON [ch].[GUID] = [vch].[chGUID] -- this will consider branches
			INNER JOIN [#NotesTbl] AS [nt] ON [ch].[TypeGUID] = [nt].[Type] 
			INNER JOIN [#mh2] AS [mh]
			ON ([ch].[Date] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [ch].[CurrencyGuid]
		WHERE 
			[ch].[CurrencyVal] <> [mh].[CurrencyVal]
			AND ([ch].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)

		-- ﬁÌÊœ «·›Ê« Ì—
		INSERT INTO [#R]
		SELECT
			0, -- RecType 
			[ce].[Guid] AS [ceGuid],
			[ce].[TypeGuid] AS [ceTypeGuid],
			[myName],
			[ce].[CurrencyVal] AS [ceCurrencyVal],
			[mh].[CurrencyVal] AS [mhCurrencyVal],
			1 / CASE [ce].[CurrencyVal] WHEN 0 THEN 1 ELSE [ce].[CurrencyVal] END,
			1 / CASE [mh].[CurrencyVal] WHEN 0 THEN 1 ELSE [mh].[CurrencyVal] END
		FROM
			[ce000] AS [ce] 
			INNER JOIN [#NotesTbl] AS [nt] ON [ce].[TypeGUID] = [nt].[Type] 
			INNER JOIN [#mh2] AS [mh]
			ON ([ce].[Date] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [ce].[CurrencyGuid]
		WHERE
			[ce].[CurrencyVal] <> [mh].[CurrencyVal]
			AND [ce].[TypeGuid] <> 0x0	
			AND ([ce].[Date] BETWEEN @PeriodStartDate AND @PeriodEndDate)

----differences in items
		INSERT INTO [#R]
		SELECT
			0, -- RecType 
			[ce].[ceGuid] AS [ceGuid],
			[ce].[ceTypeGuid] AS [ceTypeGuid],
			[myName],
			[ce].[enCurrencyVal] AS [ceCurrencyVal],
			[mh].[CurrencyVal] AS [mhCurrencyVal],
			1 / CASE [ce].[enCurrencyVal] WHEN 0 THEN 1 ELSE [ce].[enCurrencyVal] END,
			1 / CASE [mh].[CurrencyVal] WHEN 0 THEN 1 ELSE [mh].[CurrencyVal] END
		FROM
			[vwCeEn] AS [ce] 
			INNER JOIN [#NotesTbl] AS [nt] ON [ce].[ceTypeGUID] = [nt].[Type] 
			INNER JOIN [#mh2] AS [mh]
			ON ([enDate] BETWEEN [mh].[StartDate] AND  [mh].[EndDate]) AND [mh].[CurrencyGuid] = [ce].[enCurrencyPtr]
		WHERE
			[ce].[enCurrencyVal] <> [mh].[CurrencyVal]
			AND [ce].[ceTypeGuid] <> 0x0	
			AND ([enDate] BETWEEN @PeriodStartDate AND @PeriodEndDate)

	END

--- return result set
	SELECT * FROM [#R]

	SELECT 
		bp.* 
	FROM 
		bp000 bp 
		INNER JOIN [#R] r ON bp.DebtGUID = r.ceGuid OR bp.PayGUID = r.ceGuid
	UNION ALL
	SELECT 
		bp.*
	FROM 
		bp000 bp 
		INNER JOIN [en000] en ON bp.DebtGUID = en.GUID OR bp.PayGUID = en.GUID
		INNER JOIN [#R] r ON en.ParentGUID = r.ceGuid

/*
PRCcONNECTIONS_ADD2 '„œÌ—'
EXEC [prcGetCurValDifferences] 0X00
*/
####################################
#END