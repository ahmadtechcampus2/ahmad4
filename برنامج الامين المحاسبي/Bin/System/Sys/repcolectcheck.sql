##################################################################
CREATE FUNCTION fnCheck_GetCollectedValue(@CheckGUID UNIQUEIDENTIFIER) RETURNS FLOAT 
AS 
BEGIN 
	DECLARE @CollectedValue FLOAT 
	SET @CollectedValue = (
		SELECT 
			SUM([col].[Val]) AS [CollectedValue]
		FROM 
			[ColCh000] [col]
		WHERE 
			[ChGUID] = @CheckGUID)

	RETURN ISNULL( @CollectedValue, 0)
END	
##################################################################
CREATE VIEW vwCheckEntries
AS 
	SELECT 
		[CH].[GUID] AS [chGUID], 
		COUNT([ER].[PARENTNUMBER]) AS [ParentNumber]
	FROM 
		[CH000] AS [CH] 
		INNER JOIN [ER000] AS [ER] ON [ER].[PARENTGUID] = [CH].[GUID]
	GROUP 
		BY [CH].[GUID]
##################################################################
CREATE PROCEDURE repChequeOperations
	@BNum  NVARCHAR,
	@ChequeStates INT,
	@GenEntryOnInsert BIT,
	@NotGenEntryOnInsert BIT,
	@IsTransferred BIT,
	@IsNotTransferred BIT,
	@FileInt  NVARCHAR(100) = '', 
	@FileExt  NVARCHAR(100) = '', 
	@bFileDate AS BIT,
	@FileDate AS DATETIME,
	@CurrencyGuid AS UNIQUEIDENTIFIER,
	@BankGuid AS UNIQUEIDENTIFIER,
	@bNumRange AS BIT, 
	@FromNum AS INT, 
	@ToNum AS INT,
	@BillOnly INT,
	@BillType UNIQUEIDENTIFIER,
	@BillNumber INT,
	@GroupType INT = -1,
	@Note NVARCHAR = '',
	@DateCompareTo TINYINT,
	@StartDate DATETIME,
	@EndDate DATETIME,
	@IsStartDateSelected BIT,
	@IsEndDateSelected BIT,
	@SrcGUID UNIQUEIDENTIFIER,
	@AccPtr AS UNIQUEIDENTIFIER,
	@CostGUID AS UNIQUEIDENTIFIER, 
	@CustGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON ;

	DECLARE @lang INT = dbo.fnConnections_GetLanguage()
		
	DECLARE @UserGUID UNIQUEIDENTIFIER,
			@BNumLikeStr NVARCHAR(30);
	SET @BNumLikeStr = @BNum +'%';
	CREATE TABLE #SecViol([Type] INT, Cnt INT);
	
	CREATE TABLE #NotesTbl( 
		[Type] UNIQUEIDENTIFIER, 
		[Security] INT);
	CREATE TABLE #Result( 
		[Type] UNIQUEIDENTIFIER, 
		[Guid] UNIQUEIDENTIFIER,
		Number INT,
		[Security] INT,
		UserSecurity INT,
		Account UNIQUEIDENTIFIER,
		AccName NVARCHAR(250),
		[Date] DATETIME, 
		DueDate DATETIME, 
		ColDate DATETIME,
		Notes NVARCHAR(250),
		Notes2 NVARCHAR(250),
		Num NVARCHAR(250),
		CurPtr UNIQUEIDENTIFIER,
		CurVal FLOAT,
		CurCode NVARCHAR(250),
		Bank NVARCHAR(250),
		Dir INT,
		[State] INT,
		Val FLOAT,
		IntNumber NVARCHAR(250),
		FileInt NVARCHAR(250),
		FileExt NVARCHAR(250),
		FileDate DATETIME,
		OrgName NVARCHAR(250),
		CostGuid UNIQUEIDENTIFIER,
		CostName NVARCHAR(250),
		BranchGUID UNIQUEIDENTIFIER, 
		ContraAccGUID UNIQUEIDENTIFIER,
		ContraAccName NVARCHAR(250),
		NoteName NVARCHAR(250),
		CollectedValue FLOAT,
		RemainingValue FLOAT,
		ReturnedValue FLOAT,
		EntryGenerated INT,
		ManualGenerate BIT,
		StateDate DATETIME,
		GroupID INT,
		CustomerGUID UNIQUEIDENTIFIER,
		EndorseAccGUID UNIQUEIDENTIFIER,
		CustName NVARCHAR(250));
	
	SET @UserGUID = dbo.fnGetCurrentUserGUID();
	CREATE TABLE #NotesTypeTemp([Type] UNIQUEIDENTIFIER, [Security] INT);
	INSERT INTO #NotesTypeTemp EXEC prcGetNotesTypesList @SrcGuid, @UserGUID;
	INSERT INTO #NotesTbl SELECT * FROM #NotesTypeTemp ORDER BY [Type]
	DROP TABLE #NotesTypeTemp
	
	CREATE TABLE [#CustTbl] ([GUID] [UNIQUEIDENTIFIER], [Security] [INT])
	INSERT INTO  [#CustTbl] EXEC [dbo].[prcGetCustsList] @CustGUID, @AccPtr, 0x0
	INSERT INTO  [#CustTbl] SELECT 0x0, 0 

	;WITH H AS
	(
		SELECT
			ChequeGUID,
			[State],
			[Date]
		FROM 
			ChequeHistory000 H
		WHERE
			Number = (SELECT MAX(Number) FROM ChequeHistory000 WHERE ChequeGUID = H.ChequeGUID AND [State] = H.[State])
	),
	Accounts AS 
	(
		SELECT fn.[GUID], fn.[Level], fn.[Path], ac.Code + '-' + ac.Name AS AccName FROM dbo.fnGetAccountsList(@AccPtr, DEFAULT) AS fn 
		INNER JOIN ac000 ac ON fn.[GUID] = ac.[GUID]
		UNION ALL 
		-- توزيعية
		SELECT guid, 0, '', Code + '-' + Name AS AccName FROM ac000 WHERE @AccPtr = 0x AND Type = 8
	),
	Customers AS
	(
		SELECT c.GUID AS [cuGUID], 
		CASE @lang WHEN 0 THEN [cu].[cuCustomerName] ELSE (CASE [cu].[cuLatinName] WHEN '' THEN [cu].[cuCustomerName] ELSE [cu].[cuLatinName] END) END AS [cuName],
		cu.cuAccount
		FROM [#CustTbl] AS c LEFT JOIN vwcu AS cu ON cu.[cuGUID] = c.[GUID]  
	)
	INSERT INTO #Result
	SELECT
		ch.chType, 
		ch.chGuid,
		ch.chNumber, 
		ch.chSecurity,
		n.[Security],
		ch.chAccount, 
		AC.AccName,
		ch.chDate, 
		ch.chDueDate,  
		h.[Date], 
		ch.chNotes,  
		ch.chNotes2,  
		ch.chNum,  
		ch.chCurrencyPtr,
		ch.chCurrencyVal,  
		my.Code,  
		bk.BankName,
		ch.chDir,  
		ch.chState,  
		ch.chVal,  
		ch.chIntNumber,  
		ch.chFileInt,  
		ch.chFileExt,  
		ch.chFileDate,  
		ch.chOrgName,
		ch.chCost1GUID,
		co.Code + '-' + co.Name,
		ch.chBranchGUID, 
		(CASE ch.chAccount2GUID 
			WHEN 0x0 THEN 
				(CASE ch.chDir 
					WHEN 1 THEN nt.DefRecAccGUID 
					ELSE nt.DefPayAccGUID END) 
			ELSE ch.chAccount2GUID END
		) AS ContraAccGUID,
		a.Code + '-' + a.Name,
		(CASE dbo.fnConnections_GetLanguage() WHEN 0 THEN Abbrev ELSE (CASE LatinAbbrev WHEN '''' THEN Abbrev ELSE LatinAbbrev END) END) AS NoteName, 
		CASE 
			WHEN ch.chState = 2 THEN dbo.fnCheck_GetCollectedValue(ch.chGuid)
			WHEN ch.chState IN(1, 5, 8, 12) THEN ch.chVal 
			ELSE 0 
		END AS CollectedValue,
		CASE WHEN ch.chState IN(0, 2, 4, 7, 10, 11, 14) THEN ch.chVal - dbo.fnCheck_GetCollectedValue(ch.chGuid) ELSE 0 END AS RemainingValue,
		CASE WHEN ch.chState IN(3, 6, 9, 13) THEN ch.chVal ELSE 0 END AS ReturnedValue,
		-55 AS ParentNumber,
		nt.bManualGenEntry,
		h.[Date],
		DENSE_RANK() OVER(
			ORDER BY 
				(CASE @GroupType WHEN 1 THEN chNum END),
				(CASE @GroupType WHEN 2 THEN chFileInt END),
				(CASE @GroupType WHEN 3 THEN chFileExt END),
				(CASE @GroupType WHEN 4 THEN chDate END),
				(CASE @GroupType WHEN 5 THEN chColDate END),
				(CASE @GroupType WHEN 6 THEN chFileDate END),
				(CASE @GroupType WHEN 7 THEN chOrgName END),
				(CASE @GroupType WHEN 8 THEN chBankGuid END),
				(CASE @GroupType WHEN 9 THEN chCost1GUID END),
				(CASE @GroupType WHEN 10 THEN chAccount END),
				(CASE @GroupType WHEN 11 THEN chDir END),
				(CASE @GroupType WHEN 12 THEN chDueDate  END)) AS GroupId,
				cu.cuGUID,
				ch.EndorseAccGUID,
				cu.cuName		
	FROM
		vwch AS ch
		INNER JOIN #NotesTbl AS n ON ch.chType = n.Type 
		INNER JOIN nt000 AS nt ON nt.GUID = ch.chType
		INNER JOIN fnGetChequesByState(@ChequeStates) chSt ON chSt.chGuid = ch.chGuid
		LEFT JOIN vwExtended_bi bi ON bi.buGuid = ch.chParent AND @BillOnly = 1
		JOIN Accounts AC ON AC.GUID = ch.chAccount
		JOIN Customers cu ON cu.cuGUID = ch.chCustomerGUID AND (ISNULL(cu.cuAccount, 0x0) = 0x0 OR cu.cuAccount = AC.GUID )
		LEFT JOIN H h ON h.ChequeGuid = ch.chGuid AND h.[State] = ch.chState
		LEFT JOIN Bank000 bk ON bk.Guid = ch.chBankGuid
		LEFT JOIN my000 my ON my.[GUID] = ch.chCurrencyPtr
		LEFT JOIN co000 co ON co.[GUID] = ch.chCost1GUID
		LEFT JOIN ac000 a ON a.[GUID] = ch.chAccount2GUID
	WHERE
		((@GenEntryOnInsert = 1 AND nt.bAutoEntry = 1) OR (@NotGenEntryOnInsert = 1 AND nt.bAutoEntry = 0))
		AND ((@IsTransferred = 1 AND nt.bTransfer = 1) OR (@IsNotTransferred = 1 AND nt.bTransfer = 0))
		AND (@FileInt = '' OR ch.chFileInt = @FileInt)
		AND (@FileExt = '' OR ch.chFileExt = @FileExt)
		AND ((@bFileDate = 1 AND @FileDate = ch.chFileDate) OR @bFileDate = 0)
		AND ((@CurrencyGuid <> 0x AND @CurrencyGuid = ch.chCurrencyPtr) OR @CurrencyGuid = 0x)
		AND (@BankGuid = 0x OR ch.chBankGuid = @BankGuid)
		AND ((@bNumRange = 1 AND (ch.chNum BETWEEN   CAST(@FromNum AS NVARCHAR(50))  AND  CAST(@ToNum AS NVARCHAR(50)) )) OR @bNumRange = 0)
		AND ((@BillOnly = 1 AND bi.buType = @BillType AND bi.buNumber = @BillNumber) OR @BillOnly = 0)
		AND ((@Note <> '' AND ((ch.chNotes LIKE '%' + @Note + '%') OR (ch.chNotes2 LIKE '%' + @Note + '%'))) OR @Note = '')
		AND (@CostGUID = 0x  OR ch.chCost1GUID = @CostGUID)
		AND ([ch].[chNum] Like  @BNumLikeStr)
		AND (
			((@IsStartDateSelected = 1) AND (@IsEndDateSelected = 1) AND (CASE @DateCompareTo
				WHEN 0 THEN ch.chDate 
				WHEN 1 THEN ch.chDueDate
				ELSE ch.chColDate
			END BETWEEN @StartDate AND @EndDate)) 
			OR 
			((@IsStartDateSelected = 0) AND (@IsEndDateSelected = 1) AND (CASE @DateCompareTo
				WHEN 0 THEN ch.chDate 
				WHEN 1 THEN ch.chDueDate
				ELSE ch.chColDate
			END <= @EndDate)) 
			OR 
			((@IsStartDateSelected = 1) AND (@IsEndDateSelected = 0) AND (CASE @DateCompareTo
				WHEN 0 THEN ch.chDate 
				WHEN 1 THEN ch.chDueDate
				ELSE ch.chColDate
			END >= @StartDate)) 
			OR 
			((@IsStartDateSelected = 0) AND (@IsEndDateSelected = 0))
		);
	--@IsNoStartDate BIT,
	--@IsNoEndDate BIT,
	EXEC prcCheckSecurity @UserGUID;
		
	SELECT * FROM #Result ORDER BY Number;
	SELECT * FROM #SecViol;
	IF @GroupType > 0
	BEGIN 	
		CREATE TABLE #GroupedResult( 
			GNum NVARCHAR(250),
			GFileInt NVARCHAR(250),
			GFileExt NVARCHAR(250),
			GDate DATETIME, 
			GColDate DATETIME,
			GFileDate DATETIME,			
			GOrgName NVARCHAR(250),
			GBank NVARCHAR(250),
			GCostGuid UNIQUEIDENTIFIER,
			GAccount UNIQUEIDENTIFIER,			
			GDir INT,
			GDueDate DATETIME,
			GCurPtr UNIQUEIDENTIFIER,
			GCurVal FLOAT,
			GVal FLOAT,
			GCollectedValue FLOAT,
			GRemainingValue FLOAT,
			GReturnedValue FLOAT,
			ID INT)
		INSERT INTO #GroupedResult
		SELECT 
			(CASE @GroupType WHEN 1 THEN Num ELSE '' END) AS Num,
			(CASE @GroupType WHEN 2 THEN FileInt ELSE '' END) AS FileInt,
			(CASE @GroupType WHEN 3 THEN FileExt ELSE '' END) AS FileExt,
			(CASE @GroupType WHEN 4 THEN [Date] ELSE GETDATE() END) AS [Date],
			(CASE @GroupType WHEN 5 THEN ColDate ELSE GETDATE() END) AS ColDate,
			(CASE @GroupType WHEN 6 THEN FileDate ELSE GETDATE() END) AS FileDate,
			(CASE @GroupType WHEN 7 THEN OrgName ELSE '' END) AS OrgName,
			(CASE @GroupType WHEN 8 THEN Bank ELSE '' END) AS Bank,
			(CASE @GroupType WHEN 9 THEN CostGuid ELSE 0x0 END) AS CostGuid,
			(CASE @GroupType WHEN 10 THEN Account ELSE 0x0 END) AS Account,
			(CASE @GroupType WHEN 11 THEN Dir ELSE -1 END) AS Dir,
			(CASE @GroupType WHEN 12 THEN DueDate ELSE GETDATE() END) AS DueDate,
			CurPtr   AS GCurPtr,
			CurVal   AS GCurVal,
			SUM(Val) AS Val,
			SUM(CollectedValue),
			SUM(RemainingValue),
			SUM(ReturnedValue),
			GroupID 
		FROM 	
			#Result
		GROUP BY
			CurPtr, CurVal,
			(CASE @GroupType WHEN 1 THEN Num ELSE '' END),
			(CASE @GroupType WHEN 2 THEN FileInt ELSE '' END),
			(CASE @GroupType WHEN 3 THEN FileExt ELSE '' END),
			(CASE @GroupType WHEN 4 THEN [Date] ELSE GETDATE() END),
			(CASE @GroupType WHEN 5 THEN ColDate ELSE GETDATE() END),
			(CASE @GroupType WHEN 6 THEN FileDate ELSE GETDATE() END),
			(CASE @GroupType WHEN 7 THEN OrgName ELSE '' END),
			(CASE @GroupType WHEN 8 THEN Bank ELSE '' END),
			(CASE @GroupType WHEN 9 THEN CostGuid ELSE 0x0 END),
			(CASE @GroupType WHEN 10 THEN Account ELSE 0x0 END),
			(CASE @GroupType WHEN 11 THEN Dir ELSE -1 END),
			(CASE @GroupType WHEN 12 THEN DueDate ELSE GETDATE() END),
			GroupID;
		  SELECT * FROM #GroupedResult;
	END 
##################################################################
CREATE FUNCTION PartlyValue(@chequeguid UNIQUEIDENTIFIER)
RETURNS INT
AS 
BEGIN
	DECLARE  @value INT
		set @value=	(
			SELECT (SELECT chval FROM vwch WHERE chguid=@chequeguid) -  sum(val)  from colch000 
			where chGuid = @chequeguid
			)	
	RETURN @value; 
END
##################################################################
CREATE PROCEDURE prcCheckForAccruedNotes
	@PrevR INT,
	@PrevRC INT,
	@PrevRE INT,
	@PrevRUnderDis INT,
	@PrevRDis INT,
	@PrevRPart INT,
	@Prevp INT,
	@PrevpUn INT,
	@PrevpPart INT,
	@Dir INT,
	@Grouping INT
AS
	SELECT
		COUNT(*) AS [chCount], 
		CASE @Grouping WHEN 1 THEN [nt].[GUID]  END AS [TypeGuid], 
		CASE @Grouping WHEN 1 THEN [nt].[Name]  END AS [chName], 
		CASE @Grouping WHEN 1 THEN CASE [nt].[LatinName] WHEN '' THEN nt.Name ELSE nt.LatinName END END AS chLatinName,
		chDir,
		chState,
		SUM(val) as SumVal
	FROM 
		vwCh ch 
		INNER JOIN nt000 nt ON nt.GUID = ch.chType 
		INNER JOIN (SELECT 
						CASE WHEN chState = 2 THEN (SELECT dbo.PartlyValue(chguid))
							 ELSE chVal
						END AS val,
						chGUID
					FROM vwch
					) AS r ON r.chGUID = ch.chGUID
	WHERE
		val > 0
		AND
		chState IN 
		(
			CASE chdir WHEN 1 THEN CASE WHEN @PrevR >= 0 THEN 0 END ELSE CASE WHEN @Prevp >=0 THEN 0 END END ,
			CASE WHEN @PrevRC >= 0  then 7 END,
			CASE WHEN @PrevRE > = 0 THEN 4 END,
			CASE WHEN @PrevRUnderDis >=0 THEN 10 END,
			CASE WHEN @PrevRDis >=0 THEN 11 END,
			CASE chdir WHEN  1 THEN CASE WHEN @PrevRPart >=0 THEN 2 END ELSE CASE WHEN @PrevPPart>= 0 THEN 2 END END,
			CASE WHEN @PrevpUn >=0 THEN 14 END
		)
		AND chDueDate <= GetDate() +
			CASE chState  
				WHEN 0 THEN Case chdir when 1 then @PrevR  else @Prevp end 
				WHEN 2 THEN  Case chdir when 1 then @PrevRPart  else @PrevPPart end 
				WHEN 7 THEN @PrevRC 
				WHEN 4 THEN @PrevRE
				WHEN 10 THEN @PrevRUnderDis
				WHEN 11 THEN @PrevRDis
				WHEN 14 THEN @PrevpUn 
			END
		AND (chDir = @Dir OR @Dir = 0) 
	GROUP BY 
		CASE @Grouping WHEN 1 THEN nt.Name END,
		CASE @Grouping WHEN 1 THEN [nt].[GUID] END,
		CASE @Grouping WHEN 1 THEN CASE nt.LatinName WHEN '' THEN [nt].[Name] ELSE [nt].[LatinName] END END, 
		[chDir],
		chState
	ORDER BY 
		[chDir],
		chState
##################################################################
CREATE FUNCTION fnGetChequeLastHistoryState(@ChequeGUID UNIQUEIDENTIFIER, @ExcludeEdit BIT = 1)
	RETURNS INT
AS
BEGIN
	RETURN (SELECT ISNULL(MAX(Number), 0) FROM Chequehistory000 
		WHERE 
			(ChequeGUID = @ChequeGUID)
			AND 
			((@ExcludeEdit = 0) OR ((@ExcludeEdit = 1) AND (EventNumber != 34))))
END 
##################################################################
CREATE FUNCTION fnGetChequesByState(@ChequeStates INT)
RETURNS @Result TABLE(chGuid UNIQUEIDENTIFIER)
AS
BEGIN

	DECLARE 
		@NOT_RECEIVED INT = 1,
		@RETURNED_NOT_RECEIVED  INT = 2,
		@RECEIVED  INT = 4,
		@RECEIVED_PARTLY_OPEN  INT = 8,
		@RECEIVED_PARTLY_CLOSED  INT = 16,
		@UNDER_COLLECTION  INT = 32,
		@RECEIVED_COLLECTION  INT = 64,
		@RETURNED_COLLECTION  INT = 128,
		@ENDORSEMENT  INT = 256,
		@RECEIVED_ENDORSEMENT  INT = 512,
		@RETURNED_ENDORSEMENT  INT = 1024,
		@UNDER_DISCOUNTING  INT = 2048,
		@DISCOUNTED  INT = 4096,
		@RECEIVED_DISCOUNTING  INT = 8192,
		@RETURNED_DISCOUNTING  INT = 16384,
		@UNDELIVERED  INT = 32768,
		@NOT_PAID  INT = 65536,
		@RETURNED_NOT_PAID  INT = 131072,
		@PAID  INT = 262144,
		@PAID_PARTLY_OPEN  INT = 524288,
		@PAID_PARTLY_CLOSED  INT = 1048576,
		@NOT_RECEIVED_RELEASED INT = 33554432,
		@NOT_RECEIVED_ENDROSET INT = 67108864,
		@NOT_RECEIVED_COLLECT INT = 134217728,
		@NOT_RECEIVED_DISCOUNTED INT = 268435456;

	;WITH Colch AS
	(
		SELECT
			ChGUID,
			SUM(Val) AS AchievedValue
		FROM
			colch000 
		GROUP BY
			ChGUID
	)
	INSERT INTO @Result
	SELECT
		ch.chGuid
	FROM
		vwCh ch
		JOIN NT000 NT ON ch.chType = NT.GUID
		LEFT JOIN Colch ON Colch.ChGUID = ch.chGUID
	WHERE
	(
		-- نوع الورقة مقبوضة
		ch.chDir = 1
		AND
			(
				((@ChequeStates & @NOT_RECEIVED_RELEASED) = @NOT_RECEIVED_RELEASED 
					AND EXISTS(SELECT * FROM Chequehistory000 WHERE 
					ChequeGUID = ch.ChGUID 
					AND Number = dbo.fnGetChequeLastHistoryState(ch.ChGUID, DEFAULT)
					AND EventNumber = 33 AND NT.bCanFinishing = 0)
				)
				OR
				((@ChequeStates & @NOT_RECEIVED_ENDROSET) = @NOT_RECEIVED_ENDROSET 
					AND EXISTS(SELECT * FROM Chequehistory000 WHERE 
					ChequeGUID = ch.ChGUID 
					AND Number = dbo.fnGetChequeLastHistoryState(ch.ChGUID, DEFAULT)
					AND EventNumber = 9 AND NT.bCanFinishing = 0)
				)
				OR 
				((@ChequeStates & @NOT_RECEIVED_COLLECT) = @NOT_RECEIVED_COLLECT 
					AND EXISTS(SELECT * FROM Chequehistory000 WHERE 
					ChequeGUID = ch.ChGUID 
					AND Number = dbo.fnGetChequeLastHistoryState(ch.ChGUID, DEFAULT)
					AND EventNumber = 20 AND NT.bCanFinishing = 0)
				)
				OR 
				((@ChequeStates & @NOT_RECEIVED_DISCOUNTED) = @NOT_RECEIVED_DISCOUNTED 
					AND EXISTS(SELECT * FROM Chequehistory000 WHERE 
						ChequeGUID = ch.ChGUID 
						AND Number = dbo.fnGetChequeLastHistoryState(ch.ChGUID, DEFAULT)
						AND EventNumber = 23 AND NT.bCanFinishing = 0)
				)
				OR ((@ChequeStates & @RETURNED_NOT_RECEIVED) = @RETURNED_NOT_RECEIVED AND ch.chState = 3) -- استرداد للأصل من القبض
				OR ((@ChequeStates & @RECEIVED_PARTLY_OPEN) = @RECEIVED_PARTLY_OPEN AND ch.chState = 2 AND ch.chVal > Colch.AchievedValue) -- مقبوضة مفتوحة
				OR ((@ChequeStates & @RECEIVED) = @RECEIVED AND ch.chState = 1) --مقبوضة
				OR ((@ChequeStates & @RECEIVED_PARTLY_CLOSED) = @RECEIVED_PARTLY_CLOSED AND ch.chState = 2 AND ch.chVal = Colch.AchievedValue) -- مقبوضة مغلقة
				OR ((@ChequeStates & @UNDER_COLLECTION) = @UNDER_COLLECTION AND ch.chState = 7) -- برسم التحصيل
				OR ((@ChequeStates & @RECEIVED_COLLECTION) = @RECEIVED_COLLECTION AND ch.chState = 8) -- مقبوضة بتحصيل
				OR ((@ChequeStates & @RETURNED_COLLECTION) = @RETURNED_COLLECTION AND ch.chState = 9) -- مرتجعة من تحصيل
				OR ((@ChequeStates & @ENDORSEMENT) = @ENDORSEMENT AND ch.chState = 4) -- مظهرة
				OR ((@ChequeStates & @RECEIVED_ENDORSEMENT) = @RECEIVED_ENDORSEMENT AND ch.chState = 5) -- مقبوضة بتظهير
				OR ((@ChequeStates & @RETURNED_ENDORSEMENT) = @RETURNED_ENDORSEMENT AND ch.chState = 6) -- مرتجعة من التظهير
				OR ((@ChequeStates & @UNDER_DISCOUNTING) = @UNDER_DISCOUNTING AND ch.chState = 10) -- برسم الخصم
				OR ((@ChequeStates & @DISCOUNTED) = @DISCOUNTED AND ch.chState = 11) -- مخصومة
				OR ((@ChequeStates & @RECEIVED_DISCOUNTING) = @RECEIVED_DISCOUNTING AND ch.chState = 12) -- مقبوضة بخصم
				OR ((@ChequeStates & @RETURNED_DISCOUNTING) = @RETURNED_DISCOUNTING AND ch.chState = 13) -- مرتجعة من الخصم
				OR ((@ChequeStates & @NOT_RECEIVED) = @NOT_RECEIVED AND ch.chState = 0)
			)
		)
		OR
		(
		-- نوع الورقة مدفوعة
		ch.chDir = 2
		AND
		(
			((@ChequeStates & @UNDELIVERED) = @UNDELIVERED AND ch.chState = 14) -- لم تسلم 
			OR ((@ChequeStates & @NOT_PAID) = @NOT_PAID AND ch.chState = 0) -- لم تدفع
			OR ((@ChequeStates & @RETURNED_NOT_PAID) = @RETURNED_NOT_PAID AND ch.chState = 3) -- استرداد للأصل من الدفع
			OR ((@ChequeStates & @PAID) = @PAID AND ch.chState = 1) -- مدفوعة
			OR ((@ChequeStates & @PAID_PARTLY_OPEN) = @PAID_PARTLY_OPEN AND ch.chState = 2 AND ch.chVal > Colch.AchievedValue) -- مدفوعة جزئياً مفتوحة
			OR ((@ChequeStates & @PAID_PARTLY_CLOSED) = @PAID_PARTLY_CLOSED AND ch.chState = 2 AND ch.chVal = Colch.AchievedValue) -- متوحقة جزئياً مغلقة
		)
	);
	
	RETURN;
END
##################################################################
CREATE PROCEDURE prcCheck_GetCollectedValue
	@CheckGUID [UNIQUEIDENTIFIER]
AS 
	SET NOCOUNT ON 
	
	SELECT 
		SUM(
			[col].[Val]) AS [CollectedValue]
	FROM 
		[ColCh000] [col]
		-- INNER JOIN [ch000] [ch] ON [ch].[GUID] = [col].[ChGUID]
	WHERE 
		[ChGUID] = @CheckGUID
##################################################################
#END
