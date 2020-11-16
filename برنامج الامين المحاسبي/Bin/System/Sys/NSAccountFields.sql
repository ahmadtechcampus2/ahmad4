################################################################################
CREATE FUNCTION fnNSAccountEntryInfo(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @AccEntryInfo TABLE 
(
		AccCode				NVARCHAR(255),
		AccName				NVARCHAR(255),
		Amount				NVARCHAR(100),
		AmountType			NVARCHAR(255),
		CurrencyName		NVARCHAR(255),
		FixedValue			FLOAT,
		EQAmount			NVARCHAR(100),
		AccBeforBalance		NVARCHAR(100),
		AccAfterBalance		NVARCHAR(100),
		EnNote				NVARCHAR(1000),
		CeNumber			INT ,
		CeDate				DATE, 
		CostCenterName		NVARCHAR(255),
		BranchName			NVARCHAR(255),
		EntryType			NVARCHAR(255),
		CeNote				NVARCHAR(1000),
		ContraAccount		NVARCHAR(255)
)
AS 
BEGIN

	DECLARE @language INT = [dbo].[fnConnections_getLanguage]()
	DECLARE @txt_Debit  NVARCHAR(50) = (SELECT [dbo].[fnStrings_get]('NS\DEBIT', @language))
	DECLARE @txt_Credit NVARCHAR(50) = (SELECT [dbo].[fnStrings_get]('NS\CREDIT', @language))
	DECLARE @CurrencyCode NVARCHAR(50) = (SELECT MY.Code 
										  FROM en000 EN INNER JOIN my000 MY ON EN.CurrencyGUID = MY.[GUID] 
										  WHERE EN.[GUID] = @ObjectGuid)

	INSERT INTO @AccEntryInfo
	SELECT
		AC.Code,
		CASE @language WHEN 0 THEN AC.Name 
					   ELSE CASE AC.LatinName WHEN '' THEN AC.Name
											  ELSE AC.LatinName END END		  AS  AccName,

		[dbo].fnNSFormatMoneyAsNVARCHAR(CASE EN.Debit WHEN 0 THEN EN.Credit ELSE EN.Debit END / EN.CurrencyVal, @CurrencyCode),
		CASE EN.Debit WHEN 0 THEN @txt_Credit ELSE @txt_Debit END,

		CASE @language WHEN 0 THEN MY.Name 
					   ELSE CASE MY.LatinName WHEN '' THEN MY.Name
											  ELSE MY.LatinName END END		  AS  CurrName,

		EN.CurrencyVal,
		[dbo].fnNSFormatMoneyAsNVARCHAR(EN.CurrencyVal * (CASE EN.Debit WHEN 0 THEN EN.Credit ELSE EN.Debit END), @CurrencyCode),
		[dbo].fnNSFormatMoneyAsNVARCHAR((AC.Debit - AC.Credit) - (EN.Debit - EN.Credit), @CurrencyCode),
		[dbo].fnNSFormatMoneyAsNVARCHAR(AC.Debit - AC.Credit, @CurrencyCode),

		EN.Notes,
		CE.Number,
		CE.[Date],

		ISNULL(	CASE @language WHEN 0 THEN CO.Name 
					   ELSE CASE CO.LatinName WHEN '' THEN CO.Name
											  ELSE CO.LatinName END END, '')  AS CostName,

		ISNULL(CASE @language WHEN 0 THEN BR.Name 
					   ELSE CASE BR.LatinName WHEN '' THEN BR.Name
											  ELSE BR.LatinName END END, '')  AS BranchName,
											  
		ISNULL(CASE @language WHEN 0 THEN ET.Name 
					   ELSE CASE ET.LatinName WHEN '' THEN ET.Name
											  ELSE ET.LatinName END END, '') AS TypeName,
		CE.Notes,

		ISNULL(CASE @language WHEN 0 THEN ContraAc.Name 
					   ELSE CASE ContraAc.LatinName WHEN '' THEN ContraAc.Name
											  ELSE ContraAc.LatinName END END, '') AS ContraAccName

	FROM 
		en000 EN 
		INNER JOIN ac000 AC ON EN.AccountGUID = AC.[GUID] 
		INNER JOIN my000 MY ON EN.CurrencyGUID = MY.[GUID]
		INNER JOIN ce000 CE ON EN.ParentGUID = CE.[GUID]
		LEFT JOIN  co000 CO ON EN.CostGUID = CO.[GUID]
		LEFT JOIN  br000 BR ON CE.Branch = BR.[GUID]
		LEFT JOIN  et000 ET ON CE.TypeGUID = ET.[GUID]
		LEFT JOIN  ac000 ContraAc ON EN.ContraAccGUID = ContraAc.[GUID] 

	WHERE 
		EN.[GUID] = @ObjectGuid


	RETURN
END
################################################################################
CREATE FUNCTION fnNSGetEntryParent(@ObjectGuid UNIQUEIDENTIFIER, @messageGuid UNIQUEIDENTIFIER)
RETURNS @EntryParentInfo TABLE 
(
		ParentGUID		UNIQUEIDENTIFIER,
		ParentName		NVARCHAR(255)
)
AS 
BEGIN
	
	DECLARE @ParentType INT
    DECLARE @ParentGUID UNIQUEIDENTIFIER

	SELECT 
		@ParentType = ER.ParentType,
		@ParentGUID = ER.ParentGUID
	FROM 
		er000 ER 
		INNER JOIN ce000 CE ON ER.EntryGUID = CE.[GUID]
		INNER JOIN en000 EN ON EN.ParentGUID = CE.[GUID]
	WHERE 
		EN.[GUID] = @ObjectGuid


	IF(@ParentType = 5) ----- Cheque
	BEGIN 
		INSERT INTO 
			@EntryParentInfo 
		SELECT 
			@ParentGUID, 
			NT.Abbrev + ' - ' + CAST(CH.Number AS NVARCHAR(50))
		FROM 
			ch000 CH 
			INNER JOIN nt000 NT ON CH.TypeGUID = NT.[GUID]
		WHERE 
			CH.[GUID] = @ParentGUID

		RETURN
	END


	IF(@ParentType = 4) ----- Entry
	BEGIN
		INSERT INTO 
			@EntryParentInfo 
		SELECT 
			CE.[GUID],
			ET.Abbrev + ' - ' + CAST(CE.Number AS NVARCHAR(50))
		FROM 
			er000 ER 
			INNER JOIN ce000 CE ON ER.EntryGUID = CE.[GUID]
			INNER JOIN et000 ET ON CE.TypeGUID = ET.[GUID]
		WHERE 
			ER.ParentGUID = @ParentGUID

		RETURN
	END


	IF(@ParentType = 2) ----- Bill
	BEGIN
		INSERT INTO 
			@EntryParentInfo 
		SELECT
			@ParentGUID,
			BT.Abbrev + ' - ' + CAST(BU.Number AS NVARCHAR(50))
		FROM 
			bu000 BU 
			INNER JOIN bt000 BT ON BU.TypeGUID = BT.[GUID]
		WHERE 
			BU.[GUID] = @ParentGUID

		RETURN
	END


	INSERT INTO 
		@EntryParentInfo 
	SELECT
		0x0,
		''
	RETURN
END
################################################################################
#END