##################################################################################
CREATE FUNCTION fnGCCGetExciseTaxDueByTaxCode(@TaxDurationGuid [UNIQUEIDENTIFIER] = 0x0, @TaxCode [INT] = 0)
	
	RETURNS @Result TABLE 
	(
	[TaxGuid] UNIQUEIDENTIFIER,
	[TaxCode] INT,
	[Title] NVARCHAR(250),
	[Amount] FLOAT,
	[ExciseTaxDueAmount] FLOAT,
	[BillType] INT,
	[IsOutput] INT
	)

AS BEGIN
	
	DECLARE @language [INT] = [dbo].[fnConnections_getLanguage]() ;
	DECLARE @DurationStartDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_FPDate', DEFAULT))
	DECLARE @DurationEndDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_EPDate', DEFAULT))
	
	IF @TaxDurationGuid <> 0x0 
	BEGIN 
	SET @DurationStartDate = (SELECT StartDate FROM GCCTaxDurations000 WHERE GUID = @TaxDurationGuid)
	SET @DurationEndDate = (SELECT EndDate FROM GCCTaxDurations000 WHERE GUID = @TaxDurationGuid)
	END 

	INSERT INTO @Result
	SELECT 
		gccCode.GUID,
		gccCode.TaxCode,
		CASE WHEN @language <> 0 THEN gccCode.LatinName ELSE gccCode.Name END,
		ISNULL (SUM(vw.BiNetPrice), 0 ),
		SUM(vw.BiExciseTaxVal),
		vw.BillType,
		vw.BillTypeIsOutput
	FROM 
		vwGCCBillItemInfo vw
		INNER JOIN GCCTaxCoding000 gccCode ON gccCode.TaxCode = vw.BiExciseTaxCode
	WHERE 
		vw.BiExciseTaxCode = CASE WHEN @TaxCode = 0 THEN vw.BiExciseTaxCode  ELSE @TaxCode END
		AND (CAST(vw.BuDate AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 
		AND vw.BiExciseTaxVal <> 0
	GROUP by 
		vw.BillType,
		vw.BillTypeIsOutput,
		gccCode.GUID,
		gccCode.TaxCode,
		gccCode.LatinName,
		gccCode.Name
	ORDER BY 
		gccCode.TaxCode

	RETURN
END
##################################################################################
CREATE FUNCTION fnGCCGetExciseTaxDueByLocationType(@TaxDurationGuid [UNIQUEIDENTIFIER] = 0x0, @LocClassification [INT] = -1)  -- @LocationType = Local, GCC, O, LNR, OG
	
	RETURNS @Result TABLE 
	(
	[Classification] INT,
	[Amount] FLOAT,
	[ExciseTaxDueAmount] FLOAT,
	[BillType] INT, 
	[IsOutput] INT
	)

AS BEGIN
	
	DECLARE @language [INT] = [dbo].[fnConnections_getLanguage]() ;
	DECLARE @DurationStartDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_FPDate', DEFAULT))
	DECLARE @DurationEndDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_EPDate', DEFAULT))
	
	IF @TaxDurationGuid <> 0x0 
	BEGIN 
	SET @DurationStartDate = (SELECT StartDate FROM GCCTaxDurations000 WHERE GUID = @TaxDurationGuid)
	SET @DurationEndDate = (SELECT EndDate FROM GCCTaxDurations000 WHERE GUID = @TaxDurationGuid)
	END 

	INSERT INTO @Result
	SELECT 
		loc.Classification,
		ISNULL (SUM(vw.BiNetPrice), 0 ),
		SUM(vw.BiExciseTaxVal),
		vw.BillType,
		vw.BillTypeIsOutput
	FROM 
		vwGCCBillItemInfo vw
		INNER JOIN GCCCustLocations000 loc ON loc.GUID = vw.LocationGuid
	WHERE 
		loc.Classification = CASE WHEN @LocClassification = -1 THEN loc.Classification ELSE @LocClassification END
		AND (CAST(vw.BuDate AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 
		AND vw.BiExciseTaxVal <> 0
	GROUP by 
		vw.BillType,
		vw.BillTypeIsOutput,
		loc.Classification
	ORDER BY 
		loc.Classification

	RETURN
END
##################################################################################
CREATE FUNCTION fnGCCGetOutputExciseTaxDueLocation(@TaxDurationGuid [UNIQUEIDENTIFIER] = 0x0) 
	
	RETURNS @Result TABLE 
	(
	[Amount] FLOAT,
	[ExciseTaxDueAmount] FLOAT,
	[BillType] INT, 
	[IsOutput] INT
	)
AS BEGIN
	
	DECLARE @language [INT] = [dbo].[fnConnections_getLanguage]() ;
	DECLARE @DurationStartDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_FPDate', DEFAULT))
	DECLARE @DurationEndDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_EPDate', DEFAULT))
	
	IF @TaxDurationGuid <> 0x0 
	BEGIN 
	SET @DurationStartDate = (SELECT StartDate FROM GCCTaxDurations000 WHERE GUID = @TaxDurationGuid)
	SET @DurationEndDate = (SELECT EndDate FROM GCCTaxDurations000 WHERE GUID = @TaxDurationGuid)
	END 
	INSERT INTO @Result
	SELECT 
		ISNULL (SUM(vw.BiNetPrice), 0 ),
		SUM(vw.BiExciseTaxVal),
		vw.BillType,
		vw.BillTypeIsOutput
	FROM 
		vwGCCBillItemInfo vw
		INNER JOIN GCCCustLocations000 loc ON loc.GUID = vw.LocationGuid
	WHERE 
		(vw.BillType = 1 OR vw.BillType = 3)
		AND (CAST(vw.BuDate AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 
		AND vw.BiExciseTaxVal <> 0
		AND (EnType = 203 OR EnType = 204)
	GROUP by 
		vw.BillType,
		vw.BillTypeIsOutput

	RETURN
END
##################################################################################
CREATE FUNCTION fnGCCGetInputExciseTaxDueByTaxCode(@TaxDurationGuid [UNIQUEIDENTIFIER] = 0x0, @TaxCode [INT] = 0)
	
	RETURNS @Result TABLE 
	(
	[TaxGuid] UNIQUEIDENTIFIER,
	[TaxCode] INT,
	[Title] NVARCHAR(250),
	[Amount] FLOAT,
	[ExciseTaxDueAmount] FLOAT,
	[BillType] INT,
	[IsOutput] INT
	)
AS BEGIN
	
	DECLARE @language [INT] = [dbo].[fnConnections_getLanguage]() ;
	DECLARE @DurationStartDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_FPDate', DEFAULT))
	DECLARE @DurationEndDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_EPDate', DEFAULT))
	
	IF @TaxDurationGuid <> 0x0 
	BEGIN 
	SET @DurationStartDate = (SELECT StartDate FROM GCCTaxDurations000 WHERE GUID = @TaxDurationGuid)
	SET @DurationEndDate = (SELECT EndDate FROM GCCTaxDurations000 WHERE GUID = @TaxDurationGuid)
	END 
	INSERT INTO @Result
	SELECT 
		gccCode.GUID,
		gccCode.TaxCode,
		CASE WHEN @language <> 0 THEN gccCode.LatinName ELSE gccCode.Name END,
		ISNULL (SUM(vw.BiNetPrice), 0 ),
		SUM(vw.BiExciseTaxVal),
		vw.BillType,
		vw.BillTypeIsOutput
	FROM 
		vwGCCBillItemInfo vw
		INNER JOIN GCCTaxCoding000 gccCode ON gccCode.TaxCode = vw.BiExciseTaxCode
	WHERE 
		vw.BiExciseTaxCode = CASE WHEN @TaxCode = 0 THEN vw.BiExciseTaxCode  ELSE @TaxCode END
		AND (CAST(vw.BuDate AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 
		AND vw.BiExciseTaxVal <> 0
		AND (vw.BillType = 0 OR vw.BillType = 2)
		AND (EnType = 203 OR EnType = 204)
	GROUP by 
		vw.BillType,
		vw.BillTypeIsOutput,
		gccCode.GUID,
		gccCode.TaxCode,
		gccCode.LatinName,
		gccCode.Name
	ORDER BY 
		gccCode.TaxCode
	RETURN
END
##################################################################################
CREATE FUNCTION fnGCCGetInputExciseTaxDueLocation(@LocalLocation [INT] ,@TaxDurationGuid [UNIQUEIDENTIFIER] = 0x0) 
	
	RETURNS @Result TABLE 
	(
	[Amount] FLOAT,
	[ExciseTaxDueAmount] FLOAT,
	[BillType] INT, 
	[IsOutput] INT
	)
AS BEGIN
	
	DECLARE @language [INT] = [dbo].[fnConnections_getLanguage]() ;
	DECLARE @DurationStartDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_FPDate', DEFAULT))
	DECLARE @DurationEndDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_EPDate', DEFAULT))
	
	IF @TaxDurationGuid <> 0x0 
	BEGIN 
	SET @DurationStartDate = (SELECT StartDate FROM GCCTaxDurations000 WHERE GUID = @TaxDurationGuid)
	SET @DurationEndDate = (SELECT EndDate FROM GCCTaxDurations000 WHERE GUID = @TaxDurationGuid)
	END 
	INSERT INTO @Result
	SELECT 
		ISNULL (SUM(vw.BiNetPrice), 0 ),
		SUM(vw.BiExciseTaxVal),
		vw.BillType,
		vw.BillTypeIsOutput
	FROM 
		vwGCCBillItemInfo vw
		INNER JOIN GCCCustLocations000 loc ON loc.GUID = vw.LocationGuid
	WHERE 
		(vw.BillType = 0 OR vw.BillType = 2)
		AND loc.Classification = CASE WHEN  @LocalLocation = 1 THEN 0 ELSE loc.Classification END
		AND loc.Classification <> CASE WHEN  @LocalLocation = 0 THEN 0 ELSE -1 END
		AND (CAST(vw.BuDate AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 
		AND vw.BiExciseTaxVal <> 0
		AND (EnType = 203 OR EnType = 204)
	GROUP by 
		vw.BillType,
		vw.BillTypeIsOutput

	RETURN
END
##################################################################################
CREATE PROCEDURE prcGCCExciseTaxDueRep
	@TaxDurationGUID UNIQUEIDENTIFIER = 0x0
AS
	SET NOCOUNT ON
	DECLARE @language [INT] = [dbo].[fnConnections_getLanguage]() ;
	CREATE TABLE [#RESULT](
	[RecID] INT, 
	[Type] INT DEFAULT(0),  -- details, total
	[Title] NVARCHAR (250) DEFAULT(''),
	[Amount] FLOAT DEFAULT(0),
	[ExciseTaxDueAmount]	FLOAT DEFAULT(0),
	)
	-- Importation of Excis Goods from outside of UAE
	INSERT INTO  [#RESULT] (RecID,Amount,ExciseTaxDueAmount)
	SELECT 
		1,
		ISNULL( SUM ( CASE WHEN IsOutput = 1 THEN -1 * Amount ELSE Amount END), 0),
		ISNULL( SUM ( CASE WHEN IsOutput = 1 THEN -1 * ExciseTaxDueAmount ELSE ExciseTaxDueAmount END), 0)
	FROM dbo.fnGCCGetInputExciseTaxDueLocation (0 ,@TaxDurationGUID)

	-- Production of Excise Goods within UAE
	INSERT INTO  [#RESULT] (RecID,Amount,ExciseTaxDueAmount)
	SELECT 
		2,
		ISNULL(SUM ( CASE WHEN IsOutput = 1 THEN -1 * Amount ELSE Amount END), 0),
		ISNULL(SUM ( CASE WHEN IsOutput = 1 THEN -1 * ExciseTaxDueAmount ELSE ExciseTaxDueAmount END), 0)
	FROM dbo.fnGCCGetInputExciseTaxDueLocation (1 ,@TaxDurationGUID)
	-- Release of Excise Goods from a Designated Zone
	INSERT INTO  [#RESULT] (RecID)
	SELECT 
		3
		
	-- Stockpiling of Excise Goods in the UAE
	INSERT INTO  [#RESULT] (RecID)
	SELECT 
		4
	-- Tobacco and tobacco products
	INSERT INTO  [#RESULT] (RecID,Title,Amount,ExciseTaxDueAmount)
	SELECT 
		5,
		CASE WHEN @language <> 0 THEN MIN(taxCode.LatinName) ELSE  MIN(taxCode.Name) END,
		ISNULL(SUM ( CASE WHEN fn.IsOutput = 1 THEN -1 * Amount ELSE Amount END), 0),
		ISNULL(SUM ( CASE WHEN fn.IsOutput = 1 THEN -1 * ExciseTaxDueAmount ELSE ExciseTaxDueAmount END), 0)
	FROM 
	GCCTaxCoding000 taxCode 
	LEFT JOIN dbo.fnGCCGetInputExciseTaxDueByTaxCode(@TaxDurationGUID,9) fn ON fn.TaxCode = taxCode.TaxCode
	WHERE taxCode.TaxCode = 9 
	-- Carbonated drinks
	INSERT INTO  [#RESULT] (RecID,Title,Amount,ExciseTaxDueAmount)
	SELECT 
		6,
		CASE WHEN @language <> 0 THEN MIN(taxCode.LatinName) ELSE  MIN(taxCode.Name) END,
		ISNULL(SUM ( CASE WHEN fn.IsOutput = 1 THEN -1 * Amount ELSE Amount END), 0),
		ISNULL(SUM ( CASE WHEN fn.IsOutput = 1 THEN -1 * ExciseTaxDueAmount ELSE ExciseTaxDueAmount END), 0)
	FROM 
	GCCTaxCoding000 taxCode 
	LEFT JOIN dbo.fnGCCGetInputExciseTaxDueByTaxCode(@TaxDurationGUID,10) fn ON fn.TaxCode = taxCode.TaxCode
	WHERE taxCode.TaxCode = 10
	-- Energy drinks
	INSERT INTO  [#RESULT] (RecID,Title,Amount,ExciseTaxDueAmount)
	SELECT 
		7,
		CASE WHEN @language <> 0 THEN MIN(taxCode.LatinName) ELSE  MIN(taxCode.Name) END,
		ISNULL(SUM ( CASE WHEN fn.IsOutput = 1 THEN -1 * Amount ELSE Amount END), 0),
		ISNULL(SUM ( CASE WHEN fn.IsOutput = 1 THEN -1 * ExciseTaxDueAmount ELSE ExciseTaxDueAmount END), 0)
	FROM 
	GCCTaxCoding000 taxCode 
	LEFT JOIN dbo.fnGCCGetInputExciseTaxDueByTaxCode(@TaxDurationGUID,11) fn ON fn.TaxCode = taxCode.TaxCode
	WHERE taxCode.TaxCode = 11
	-- Total value of Excise Goods/ Due Tax
	INSERT INTO  [#RESULT] (RecID,ExciseTaxDueAmount,Type)
	SELECT 
		8,
		ISNULL(SUM(ExciseTaxDueAmount), 0),
		1 --total
		FROM [#RESULT]
		WHERE RecID = 1 OR RecID = 2

	INSERT INTO  [#RESULT] (RecID,Type)
	SELECT 
		9, -- Value of Tax declared in error and identified in the same month
		1 --total
	INSERT INTO  [#RESULT] (RecID,Type)
	SELECT 
		10, -- Value of Deductible Tax for Tax paid in error
		1 --total
	INSERT INTO  [#RESULT] (RecID,Type,Amount,ExciseTaxDueAmount)
	SELECT 
		11, --Value of other Deductible Tax
		1, --total
		ISNULL( SUM ( CASE WHEN IsOutput = 1 THEN -1 * Amount ELSE Amount END), 0),
		ISNULL( SUM ( CASE WHEN IsOutput = 1 THEN -1 * ExciseTaxDueAmount ELSE ExciseTaxDueAmount END), 0)
	FROM dbo.fnGCCGetOutputExciseTaxDueLocation(@TaxDurationGUID)

	INSERT INTO  [#RESULT] (RecID,Type)
	SELECT 
		12, --Value of under declared Tax for the previous tax period
		1 --total
	INSERT INTO  [#RESULT] (RecID,Type, ExciseTaxDueAmount)
	
	SELECT 
		13, --Total value of Payable Tax
		1, --total
		SUM (ExciseTaxDueAmount)
	FROM [#RESULT]
	WHERE 
		RecID = 8 OR RecID = 11
	
	SELECT * FROM [#RESULT]
##################################################################################
#END
