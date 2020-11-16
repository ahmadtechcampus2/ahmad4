CREATE PROC prcHosGetEntries
		@Account uniqueidentifier, 
		@CostGuid uniqueidentifier, 
		@FromDate DateTime,  
		@ToDate DateTime, 
		@PatientGuid uniqueidentifier = 0x0,
		@FileGuid uniqueidentifier = 0x0
AS 
	SET NOCOUNT ON 	
	
	DECLARE @NoDate DATETIME;

	SET @NoDate = '2100-01-01 00:00:00.000';

	CREATE TABLE #Result  
		( 
			[CeGUID] 	[UNIQUEIDENTIFIER], 
			[enGUID] 	[UNIQUEIDENTIFIER],  
			[CeNumber]	[INT], 
			[EnNumber]	[INT], 
			[AccGUID] 	[UNIQUEIDENTIFIER],     
			[CostGuid] 	[UNIQUEIDENTIFIER], 
			[DATE] 		[DATETIME], 
			[EnNotes] 	[NVARCHAR] (250) COLLATE Arabic_CI_AI, 
			[DEBIT]		[FLOAT], 
			[CREDIT]	[FLOAT], 
			[FileGuid] 	[UNIQUEIDENTIFIER], 
			[ceParentGUID] [UNIQUEIDENTIFIER],      
			[ceRecType] [INT],      
			[ParentNumber] [NVARCHAR](250),  
			[ParentName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,  
			[ceTypeGuid] [UNIQUEIDENTIFIER], 
			[ceSecurity] [INT],     
			[accSecurity] [INT] 
		) 
	DECLARE @Account_Tbl TABLE([GUID] [UNIQUEIDENTIFIER],[acSecurity] INT) 
	DECLARE @Cost_Tbl TABLE([GUID] [UNIQUEIDENTIFIER]) 

	IF (@PatientGuid = 0X0)	 
	BEGIN 
		INSERT INTO @Cost_Tbl  
			SELECT [GUID] 
			FROM [dbo].[fnGetCostsList] (@CostGuid) 
		INSERT INTO @Account_Tbl  
			SELECT FN.[GUID], ac.[Security]  
			FROM [dbo].[fnGetAccountsList]( @Account, 0) as FN 
			INNER JOIN [ac000] AS [ac] ON [Fn].[GUID] = [ac].[GUID] 
	END 
	ELSE 
	BEGIN	 
		INSERT INTO @Account_Tbl  
			SELECT  
				DISTINCT [F].[AccGuid], ac.[Security]  
			FROM VwHosFile as f 
			INNER JOIN [ac000] AS [ac] ON [F].[AccGuid] = [ac].[GUID]		 
			WHERE ((f.PatientGuid = @PatientGuid) OR (@PatientGuid = 0x0))
			AND ((f.Guid = @FileGuid) OR (@FileGuid = 0x0))  
	 
		INSERT INTO @Cost_Tbl  
			SELECT [CostGuid] 
			FROM VwHosFile as f 
			WHERE ((f.PatientGuid = @PatientGuid) OR (@PatientGuid = 0x0))
			AND ((f.Guid = @FileGuid) OR (@FileGuid = 0x0)) 
	END 
	INSERT INTO #Result 
		([CeGUID], [enGUID], [CeNumber], [EnNumber], [AccGUID], [CostGuid], [DATE], 
		[EnNotes], [DEBIT], [CREDIT], [FileGuid],[ceParentGUID],[ceRecType], 
		[ParentNumber],[ceTypeGuid], [ceSecurity], [accSecurity]) 
	SELECT 
		ce.[ceGuid], 
		en.[enGuid], 
		ce.[CeNumber], 
		en.[enNumber], 
		en.enAccount, 
		en.enCostPoint, 
		en.[enDate], 
		en.[enNotes], 
		en.[enDebit], 
		en.[enCredit], 
		f.Guid, 
		ISNULL([er].[erParentGuid], 0x0), 
		ISNULL([er].[erParentType], 0), 
		ISNULL([f].[code], ''), 
		ce.[ceTypeGuid], 
		ce.[ceSecurity],     
		acc.[acSecurity] 
	FROM [vwCe] AS ce 
		INNER JOIN [vwEn] AS en on en.[enParent] = ce.[ceGUID] 
 		INNER JOIN @Account_Tbl AS Acc on Acc.Guid = en.[enAccount] 
		INNER JOIN @Cost_Tbl AS co on co.Guid = en.[enCostPoint] 
		INNER JOIN HosPFile000 as f on f.accGuid = En.enAccount  
		LEFT JOIN [vwEr] AS [er] ON ce.[ceGuid] = [er].[erEntryGuid] 
	WHERE 
		((en.[enDate] <> @NoDate AND en.[enDate] between @FromDate AND @ToDate) OR (en.[enDate] = @NoDate))
	AND f.CostGuid = en.enCostPoint
	AND ((f.PatientGuid = @PatientGuid) OR (@PatientGuid = 0x0))
			AND ((f.Guid = @FileGuid) OR (@FileGuid = 0x0))
			
	 
	------------------------------------------- 
	UPDATE [#Result] SET  
		[ParentName] = '√ ⁄«» «·Ã—«Õ' 
	WHERE ceRecType = 202  
	------------------------------ 
	UPDATE [#Result] SET  
		[ParentName] = ' ﬂ·›… €—›… «·⁄„·Ì« ' 
	WHERE ceRecType = 304  
	------------------------------------------- 
	UPDATE [#Result] SET  
		[ParentName] = '≈ﬁ«„…' 
	WHERE ceRecType = 303 
	------------------------------------------- 
	UPDATE [#Result] SET  
		[ParentName] = '⁄„· ⁄«„' 
	WHERE ceRecType = 300 
	-------------------------------------------
	UPDATE [#Result] SET   
		[ParentName] = '”‰œ« '  
	WHERE ceRecType = 4 
	------------------------------------------- 
	UPDATE [#Result] SET  
		[ParentName] = 'ÿ·» √‘⁄…', 
		[ParentNumber] = radio.code 
	FROM 
		[#Result] AS [Res]  
		INNER JOIN [vwEr] AS [er] ON [Res].[ceGuid] = [er].[erEntryGuid]   
		INNER JOIN HosRadioGraphyOrder000 AS radio ON radio.Guid = [er].[erParentGuid] 
	WHERE ceRecType = 309 
	------------------------------------------- 
	UPDATE [#Result] SET  
		[ParentName] = CASE ceRecType WHEN 302 THEN '≈€·«ﬁ «·≈÷»«—…' 
				WHEN 301 THEN '«” ‘«—«  ÿ»Ì…' END 
	WHERE ceRecType = 302 OR ceRecType = 301	 
	------------------------------------------- 
	UPDATE [#Result] SET  
		[ParentName] = [et].[etAbbrev] 
	FROM  
		[#Result] AS [Res] INNER JOIN [vwEt] AS [et]  
		ON [Res].[ceTypeGUID] = [et].[etGuid] 
	------------------------------------------- 
	UPDATE [#Result] SET 
		[ParentName] = ISNULL( CASE [nt].[ntAbbrev] WHEN '' THEN [nt].[ntName] ELSE [nt].[ntAbbrev] END, '') 
	FROM  
		[#Result] AS [Res] INNER JOIN [vwNt] AS [nt] 
		ON [Res].[ceTypeGUID] = [nt].[ntGuid] 
	------------------------------------------ 
	--UPDATE [#Result] SET  
		--[ParentName] = [bt].[btAbbrev] 
	--FROM	[#Result] AS [Res] INNER JOIN [vwBt] AS [bt] 	ON [Res].[ceTypeGUID] = [bt].[btGuid] 
	------------------------------------------ 
	------------------------------------------ 
	UPDATE [#Result] SET  
		[ParentName] = '„” Â·ﬂ«  ⁄«„…', 
		[ceRecType] = 312 
	FROM 
		[#Result] AS [Res]  
		--INNER JOIN [vwBt] AS [bt] ON [Res].[ceTypeGUID] = [bt].[btGuid] 
		INNER JOIN hosConsumedMaster000 as cons on cons.BillGuid = Res.ceParentGUID 
	------------------------------------------ 
	------------------------------------------ 
	UPDATE [#Result] SET  
		[ParentName] = '„” Â·ﬂ«  «·⁄„·Ì…', 
		[ceRecType] = 310 
	FROM 
		[#Result] AS [Res]  
		--INNER JOIN [vwBt] AS [bt] ON [Res].[ceTypeGUID] = [bt].[btGuid] 
		INNER JOIN hosFSurgery000 as s on s.SurgeryBillGuid = RES.ceParentGUID 
	------------------------------------------ 
	------------------------------------------ 
	UPDATE [#Result] SET  
		[ParentName] = '„” Â·ﬂ«  «·„—Ì÷', 
		[ceRecType] = 311 
	FROM 
		[#Result] AS [Res]  
		--INNER JOIN [vwBt] AS [bt] ON [Res].[ceTypeGUID] = [bt].[btGuid] 
		INNER JOIN hosFSurgery000 as s on s.PatientBillGuid = RES.ceParentGUID 
	------------------------------------------ 
SELECT * FROM #Result 

