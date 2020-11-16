###########################################################################
CREATE PROCEDURE prcGetEntryReleatedMaterials
	@EntryGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON;

	SELECT
		M.mtCode,
		M.mtName,
		M.mtLatinName,
		B.Qty,
		dbo.fnGetUnitName(M.mtGUID, B.Unity) AS UnitName
	FROM
		vwMt AS M
		JOIN bi000 AS B ON M.mtGUID = B.MatGUID
		JOIN en000 AS E ON E.BiGUID = B.[GUID]
	WHERE
		E.[GUID] = @EntryGuid;
###########################################################################
CREATE PROC prcGetVouchersToPrint
	@VoucherTypeID UNIQUEIDENTIFIER = 0x,
	@FromDate DATE,
	@ToDate DATE,
	@FilterByDate BIT,
	@FromNumber INT,
	@ToNumber INT
AS
	SET NOCOUNT ON

	SELECT
		CASE @VoucherTypeID WHEN 0x THEN 'سند قيد' ELSE ISNULL(ET.Name, N'') END AS TypeName,
		CASE @VoucherTypeID WHEN 0x THEN 'Journal Entry' ELSE ISNULL(ET.LatinName, N'') END AS TypeLatinName,
		ISNULL(ER.ParentGUID, 0x) AS OriginGuid,
		ISNULL(ER.ParentType, -1) AS OriginType,
		CASE @VoucherTypeID WHEN 0x THEN CE.ceNumber ELSE P.Number END AS ceNumber,
		CE.ceTypeGUID,
		CE.ceGUID,
		CE.ceDate,
		CE.ceCurrencyPtr,
		CE.ceCurrencyVal,
		CE.ceNotes,
		CE.ceBranch,
		P.GUID AS PYGuid,
		P.TypeGUID,
		P.AccountGUID,
		MY.Name AS ceCurrecnyName,
		CE.ceNumber AS EntryNumber
	INTO #Ce
	FROM
		vwCe AS CE 
		JOIN my000 AS MY ON CE.ceCurrencyPtr = MY.GUID
		LEFT JOIN er000 AS ER ON CE.ceGUID = ER.EntryGUID
		LEFT JOIN py000 AS P ON P.[GUID] = ER.ParentGUID
		LEFT JOIN et000 AS ET ON ET.GUID = P.TypeGUID
	WHERE 
		 ((@VoucherTypeID <> 0x AND @VoucherTypeID = P.TypeGUID)
		 AND ((@FilterByDate = 0 AND P.Number BETWEEN @FromNumber AND @ToNumber) OR @FilterByDate = 1)
		 )
		 OR ((@VoucherTypeID = 0x) 
		 AND ((@FilterByDate = 0 AND CE.ceNumber BETWEEN @FromNumber AND @ToNumber) OR @FilterByDate = 1)
		 )
		 AND ((@FilterByDate = 1 AND CE.ceDate BETWEEN @FromDate AND @ToDate) OR @FilterByDate = 0)

	SELECT * FROM #Ce;

	;WITH VatItems AS
	(
		SELECT
			EN.ParentVATGuid,
			SUM(EN.Debit) AS Debit,
			SUM(EN.Credit) AS Credit
		FROM
			en000 AS EN
			JOIN #Ce AS CE ON EN.ParentGUID = CE.ceGUID
		WHERE
			@VoucherTypeID <> 0x AND EN.ParentVATGuid <> 0x
		GROUP BY
			EN.ParentVATGuid
	)
	SELECT
		EN.Debit + ISNULL(VI.Debit, 0) AS PYDebit,
		EN.Credit + ISNULL(VI.Credit, 0) AS PYCredit,
		CASE ET.ShowDiscGrid
			WHEN 1 THEN 
				CASE 
					WHEN (ET.FldCredit > 0 AND EN.Debit > 0) OR ET.FldDebit > 0 AND EN.Credit > 0  THEN 1
					ELSE 0
				END
			ELSE 0
		END AS IsDiscRec,
		EN.*

	FROM
		vwEntryItems AS EN
		JOIN #Ce AS CE ON EN.ParentGUID = CE.ceGUID
		LEFT JOIN VatItems AS VI ON EN.GUID = VI.ParentVATGuid
		LEFT JOIN er000 AS ER ON ER.EntryGUID = CE.ceGUID
		LEFT JOIN py000 AS PY ON PY.GUID = ER.ParentGUID
		LEFT JOIN et000 AS ET ON ET.GUID = PY.TypeGUID
	WHERE
		((@VoucherTypeID <> 0x AND EN.AccountGUID <> CE.AccountGUID AND EN.ParentVATGuid = 0x) OR @VoucherTypeID = 0x)

###########################################################################
#END