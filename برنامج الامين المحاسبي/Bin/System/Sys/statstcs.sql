##########################################################################
CREATE PROC prcStatistics_List 
AS   
	SET NOCOUNT ON
	
	CREATE TABLE #t_buffer(   
		[Type]		[INT],    
		[Num]		[INT],   
		[Name]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,   
		[LatinName]	[NVARCHAR](255) COLLATE ARABIC_CI_AI,   
		[Count]		[FLOAT],   
		[SubCount]	[FLOAT])   
	-----------------------------------------------  
	-- cards 	type = 0  
	--				num = 0  mat  
	--				num = 1  group  
	--				num = 2  store  
	--				num = 3  Total Account 
	--				num = 4  account  
	--				num = 5  Customers  
	--				num = 6  Cost Point  
	--				num = 7  currancy  
	--				num = 11  manufacture
	--              num = 12  trans
	------------------------------  
	-- mats  
	INSERT INTO [#t_Buffer]   
		SELECT   
			0,  
			0,  
			'',  
			'',  
			Count(*),  
			0  
		FROM   
			[vwmt]  
	-----------------------------  
	-- groups  
	INSERT INTO [#t_Buffer]
		SELECT   
			0,  
			1,  
			'',  
			'',  
			Count(*),  
			0  
		FROM   
			[vwgr]  
	----------------------------------------------  
	-- stores  
	INSERT INTO [#t_Buffer]   
		SELECT   
			0,  
			2,  
			'',  
			'',  
			Count(*),  
			0  
		FROM   
			[vwst]  
	-------------------------------------------------  
	----------------------------------------------  
	-- manufactur  
	INSERT INTO [#t_Buffer]   
		SELECT   
			0,  
			11,  
			'',  
			'',  
			Count(*),  
			0  
		FROM   
			[mn000]  
		WHERE  
			[Type] <> 0
	-------------------------------------------------  
	-- accounts  
	INSERT INTO [#t_Buffer]  
		SELECT   
			0,  
			3,  
			'',  
			'',  
			count([actype]),  
			2  
		FROM  
			[vwac]  
	DECLARE @AccTbl Table ( [type] [INT]) 
	INSERT INTO @AccTbl VALUES (1) 
	INSERT INTO @AccTbl VALUES (2) 
	INSERT INTO @AccTbl VALUES (4) 
	INSERT INTO @AccTbl VALUES (8) 
	INSERT INTO #t_Buffer  
		SELECT   
			0,  
			4,  
			'',  
			'',  
			count([ac].[actype]),  
			[a].[type]  
		FROM  
			[vwac]  AS [AC] RIGHT JOIN @AccTbl AS [a] ON [ac].[acType] = [a].[type] 
		GROUP BY   
			[a].[type]  
	----------------------------------------------  
	-- customers  
		INSERT INTO [#t_Buffer]   
			SELECT   
				0,  
				5,  
				'',  
				'',  
				Count(*),  
				0  
			FROM   
				[vwcu]  
	----------------------------------------------  
	-- cost point  
		INSERT INTO [#t_Buffer]   
			SELECT   
				0,  
				6,  
				'',  
				'',  
				Count(*),  
				0  
			FROM   
				[vwco]  
	------------------------------  
	-- currencys  
	INSERT INTO [#t_Buffer]   
		SELECT   
			0,  
			7,  
			'',  
			'',  
			Count(*),  
			0  
		FROM   
			[vwmy]  
	--------------------------- 
	-- forms 
	INSERT INTO [#t_Buffer]   
		SELECT   
			0,  
			8,  
			'',  
			'',  
			Count(*),  
			0  
		FROM   
			[vwfm]  
	--------------------------------------------------- 
	-----Orders
   INSERT INTO [#t_Buffer]  
		SELECT   
		    6,  
			-1,  
			'',  
			'',  
			count(*),  
			1
		FROM  
			[vworders]

   INSERT INTO [#t_Buffer] 
		SELECT   
			6,  
		    [bt].[btSortNum],  
			CASE [bt].[btName] WHEN '' THEN [bt].[btLatinName] ELSE [bt].[btName] END,  
			CASE [bt].[btLatinName] WHEN '' THEN [bt].[btName] ELSE [bt].[btLatinName] END,  
			Count([bu].[buNumber]) [Count],  
			0
		FROM   
			[vwbu] AS [bu] RIGHT JOIN [vwbt] AS [bt] ON [bu].[buType] = [bt].[btGUID]
		WHERE   
			[bt].[btType] in (5, 6)
		GROUP BY
			[bt].[btName],
			[bt].[btLatinName],
			[bt].[btSortNum]
	
----------------------------------------------------------- 
-- Normal  Bills 		type = 1  
	INSERT INTO [#t_Buffer]   
		SELECT   
			1,  
			-1,  
			'',  
			'',  
			Count( *),  
			1  
		FROM   
			[vwbu] AS [bu] INNER JOIN [vwbt] AS [bt] ON [bu].[buType] = [bt].[btGUID]
		WHERE   
			[bt].[btType] = 1   

	INSERT INTO [#t_Buffer]   
		SELECT   
			1,  
			[bt].[btSortNum],  
			CASE [bt].[btName] WHEN '' THEN [bt].[btLatinName] ELSE [bt].[btName] END,  
			CASE [bt].[btLatinName] WHEN '' THEN [bt].[btName] ELSE [bt].[btLatinName] END,  
			Count([bu].[buNumber]),  
			0  
		FROM   
			[vwbu] AS [bu] RIGHT JOIN [vwbt] AS [bt] ON [bu].[buType] = [bt].[btGUID]
		WHERE   
			[bt].[btType] = 1 
		GROUP BY
			[bt].[btName],
			[bt].[btLatinName],
			[bt].[btSortNum]

	INSERT INTO [#t_Buffer]   
		SELECT   
			2,  
			256,  
			CASE [bt].[btName] WHEN '' THEN [bt].[btLatinName] ELSE [bt].[btName] END,  
			CASE [bt].[btLatinName] WHEN '' THEN [bt].[btName] ELSE [bt].[btLatinName] END,  
			Count([bu].[buNumber]),  
			0  
		FROM   
			[vwbu] AS [bu] RIGHT JOIN [vwbt] AS [bt] ON [bu].[buType] = [bt].[btGUID]
		WHERE   
			[bt].[btType] = 2 AND [bt].[btSortNum] = 1
		GROUP BY
			[bt].[btName],
			[bt].[btLatinName]

	INSERT INTO [#t_Buffer]   
		SELECT   
			2,  
			258,  
			CASE [bt].[btName] WHEN '' THEN [bt].[btLatinName] ELSE [bt].[btName] END,  
			CASE [bt].[btLatinName] WHEN '' THEN [bt].[btName] ELSE [bt].[btLatinName] END,  
			Count([bu].[buNumber]),  
			0  
		FROM   
			[vwbu] AS [bu] RIGHT JOIN [vwbt] AS [bt] ON [bu].[buType] = [bt].[btGUID]
		WHERE   
			[bt].[btType] = 2 AND [bt].[btSortNum] = 3
		GROUP BY
			[bt].[btName],
			[bt].[btLatinName]
-------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------
	INSERT INTO [#t_Buffer]   
		SELECT   
			2,  
			260,  
			CASE [bt].[btName] WHEN '' THEN [bt].[btLatinName] ELSE [bt].[btName] END,  
			CASE [bt].[btLatinName] WHEN '' THEN [bt].[btName] ELSE [bt].[btLatinName] END,  
			Count([bu].[buNumber]),  
			0  
		FROM   
			[vwbu] AS [bu] RIGHT JOIN [vwbt] AS [bt] ON [bu].[buType] = [bt].[btGUID]
		WHERE   
			[bt].[btType] = 2 AND [bt].[btSortNum] = 5
		GROUP BY
			[bt].[btName],
			[bt].[btLatinName]

	-------------------------------------------------------------------------------------
	-------------------------------«Œ—«Ã „Ê«œ «Ê·Ì…-------------------------------------
	INSERT INTO [#t_Buffer]   
		SELECT   
			2,  
			261,  
			CASE [bt].[btName] WHEN '' THEN [bt].[btLatinName] ELSE [bt].[btName] END,  
			CASE [bt].[btLatinName] WHEN '' THEN [bt].[btName] ELSE [bt].[btLatinName] END,  
			Count([bu].[buNumber]),  
			0  
		FROM   
			[vwbu] AS [bu] RIGHT JOIN [vwbt] AS [bt] ON [bu].[buType] = [bt].[btGUID]
		WHERE   
			[bt].[btType] = 2 AND [bt].[btSortNum] = 6
		GROUP BY
			[bt].[btName],
			[bt].[btLatinName]
	-------------------------------------------------------------------------------------

	INSERT INTO [#t_Buffer]   
		SELECT   
			2,  
			262,  
			CASE [bt].[btName] WHEN '' THEN [bt].[btLatinName] ELSE [bt].[btName] END,  
			CASE [bt].[btLatinName] WHEN '' THEN [bt].[btName] ELSE [bt].[btLatinName] END,  
			Count([bu].[buNumber]),  
			0  
		FROM   
			[vwbu] AS [bu] RIGHT JOIN [vwbt] AS [bt] ON [bu].[buType] = [bt].[btGUID]
		WHERE   
			[bt].[btType] = 2 AND [bt].[btSortNum] = 7
		GROUP BY
			[bt].[btName],
			[bt].[btLatinName]
-------------------------------------------------------------------------------------
	-------------------------------------------«·„‰«ﬁ·« -------------------------------------------
	---------------------------------------------------------------------------------------  
	INSERT INTO [#t_buffer]
		SELECT
		2,
		12,
		[BT].[NAME],
		[BT].[LatinName],
		COUNT([BU].[GUID]),
		0
		FROM [tt000] AS [TT]
		INNER JOIN [bt000] AS [BT] ON [BT].[GUID] = [TT].[InTypeGUID]
		LEFT JOIN [bu000] AS [BU] ON [BT].[GUID] = [BU].[TypeGUID]
		GROUP BY [BT].[NAME],[BT].[LatinName]
	--------------------------------------------------------------------------------------------
	-- manual entry 	type = 3  
	INSERT INTO [#t_Buffer]   
		SELECT   
			3,  
			-1,  
			'',  
			'',  
			Count([ceType]),  
			1  
		FROM   
			[vwce]  
	INSERT INTO [#t_Buffer]   
		SELECT   
			3,  
			0,  
			'',  
			'',  
			count(*),  
			0  
		from   
			[vwce] AS [ce] LEFT JOIN [vwer] AS [er] ON [ce].[ceGUID] = [er].[erEntryGUID]
		WHERE   
			[erParentGUID] IS NULL  
	------------------------------------------------------------------  
	-- entries	type = 4  
	INSERT INTO [#t_Buffer]   
		SELECT   
			4,  
			-1,  
			'',  
			'',  
			Count([ceType]),  
			1  
		FROM   
			[vwce] AS [ce] INNER JOIN [vwer] AS [er] ON [ce].[ceGUID] = [er].[erEntryGUID]
		WHERE   
			[er].[erParentType] = 4

	INSERT INTO [#t_Buffer]   
		SELECT   
			4,  
			0,  
			CASE [et].[etName] WHEN '' THEN [et].[etlatinname] ELSE [et].[etName] END,  
			CASE [et].[etlatinname] WHEN '' THEN [et].[etName] ELSE [et].[etlatinname] END,  
			count([py].[Number]),  
			0  
		from   
			[Py000] as [py] right join [vwet] as [et]  
			on [et].[etGUID] = [py].[TypeGUID] 
		group by   
			--et.number,  
			[et].[etname],  
			[et].[etlatinname]  
		--Order By   
			--et.number  


	----------------------------------------------------  
	-- checks type = 5  
	INSERT INTO [#t_Buffer]   
		SELECT   
			5,  
			-1,  
			'',  
			'',  
			Count([chNumber]),  
			1  
		FROM   
			[vwch] 
	INSERT INTO [#t_Buffer]   
		SELECT   
			5,  
			0,  
			case [nt].[ntName] when '' then [nt].[ntlatinname] else [nt].[ntName] End,  
			case [nt].[ntlatinname] when '' then [nt].[ntName] else [nt].[ntlatinname] END,  
			count([chNumber]),  
			0  
		from   
			[vwch] as [ch] right join [vwnt] as [nt]  
			on [nt].[ntGUID] = [ch].[chType]  
		group by   
			--nt.number,  
			[nt].[ntname],  
			[nt].[ntlatinname]  
		--Order By   
			--nt.number  
	select * from  [#t_Buffer] order by [type],[num]  
	DROP TABLE [#t_Buffer]  
##########################################################################
#END
