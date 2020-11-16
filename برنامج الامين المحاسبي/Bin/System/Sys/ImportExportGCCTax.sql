#################################################################
CREATE PROCEDURE prcIE_CreateTempGCCCustLocationsTable
AS
	IF EXISTS(SELECT NAME FROM SysObjects WHERE NAME = 'GCCCustLocations2')
		DROP TABLE [dbo].[GCCCustLocations2]
	CREATE TABLE [dbo].[GCCCustLocations2](
		[Number] [int] NULL DEFAULT ((0)),
		[GUID] [uniqueidentifier] NOT NULL DEFAULT (0x00),
		[Name] [nvarchar](250) NULL DEFAULT (''),
		[LatinName] [nvarchar](250) NULL DEFAULT (''),
		[ParentLocationGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[VATAccGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[ReturnAccGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[Classification] [int] NULL DEFAULT ((0)),
		[IsSubscribed] [bit] NULL DEFAULT ((0)),
		[SubscriptionDate] [datetime] NULL DEFAULT ('1/1/1980'),
		[IsSystem] [bit] NULL DEFAULT ((0)),
		CONSTRAINT PK_TmpGCCCustLocations_Id PRIMARY KEY (GUID)
	)
#################################################################
CREATE PROCEDURE prcIE_CreateTempGCCMaterialTaxTable
AS
	IF EXISTS(SELECT NAME FROM SysObjects WHERE NAME = 'GCCMaterialTax2')
		DROP TABLE [dbo].[GCCMaterialTax2]
	CREATE TABLE [dbo].[GCCMaterialTax2](
		[GUID] [uniqueidentifier] NOT NULL DEFAULT (0x00),
		[TaxType] [int] NULL DEFAULT ((0)),
		[TaxCode] [int] NULL DEFAULT ((0)),
		[Ratio] [float] NULL DEFAULT ((0)),
		[MatGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[ProfitMargin] [bit] NULL DEFAULT ((0)),
		CONSTRAINT PK_TmpGCCMaterialTax_Id PRIMARY KEY (GUID)
	)
#################################################################
CREATE PROCEDURE prcIE_CreateTempGCCCustomerTaxTable
AS
	IF EXISTS(SELECT NAME FROM SysObjects WHERE NAME = 'GCCCustomerTax2')
		DROP TABLE [dbo].[GCCCustomerTax2]
	CREATE TABLE [dbo].[GCCCustomerTax2](
		[GUID] [uniqueidentifier] NOT NULL DEFAULT (0x00),
		[TaxType] [int] NULL DEFAULT ((0)),
		[TaxCode] [int] NULL DEFAULT ((0)),
		[TaxNumber] [nvarchar](100) NULL DEFAULT (''),
		[CustGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		CONSTRAINT PK_TmpGCCCustomerTax_Id PRIMARY KEY (GUID)
	)
#################################################################
CREATE PROCEDURE prcIE_ImportGCCCustLocations
AS 
	SET NOCOUNT ON
	IF NOT EXISTS(SELECT [NAME] FROM [SysObjects] WHERE [NAME] = 'GCCCustLocations2')
		RETURN
	EXEC prcIE_ImportGCCTaxAccounts
	SELECT * INTO [#GCCCustLocations] FROM [GCCCustLocations2]

	--delete existing rows from the temp table
	DELETE gcl2 FROM [#GCCCustLocations] AS gcl2
	INNER JOIN GCCCustLocations000 AS gcl
	ON gcl.GUID = gcl2.GUID OR gcl.Name = gcl2.Name

	DECLARE @MaxNum [INT]
	SELECT @MaxNum = ISNULL(MAX([Number]),0) FROM [GCCCustLocations000]

	--insert new rows
	INSERT INTO [GCCCustLocations000]
		([Number]
		,[GUID]
		,[Name]
		,[LatinName]
		,[ParentLocationGUID]
		,[VATAccGUID]
		,[ReturnAccGUID]
		,[Classification]
		,[IsSubscribed]
		,[SubscriptionDate]
		,[IsSystem])
	SELECT 
		@MaxNum + (ROW_NUMBER() OVER(ORDER BY gcl.Number ASC))
		,[GUID]
		,[Name]
		,[LatinName]
		,[ParentLocationGUID]
		,[VATAccGUID]
		,[ReturnAccGUID]
		,[Classification]
		,[IsSubscribed]
		,[SubscriptionDate]
		,[IsSystem]
	FROM [#GCCCustLocations] AS gcl
#################################################################
CREATE PROCEDURE prcIE_ImportGCCCustomerTax
	@impCustGUID [uniqueidentifier],
	@crntCustGUID [uniqueidentifier]
AS 
	SET NOCOUNT ON
	IF NOT EXISTS(SELECT [NAME] FROM [SysObjects] WHERE [NAME] = 'GCCCustomerTax2')
		RETURN
	SELECT * INTO [#GCCCustomerTax] FROM [GCCCustomerTax2] AS gct2 WHERE gct2.CustGUID = @impCustGUID

	--insert new rows
	INSERT INTO [GCCCustomerTax000]
		([GUID]
        ,[TaxType]
        ,[TaxCode]
        ,[TaxNumber]
        ,[CustGUID])	
	SELECT 
		NEWID()
        ,[TaxType]
        ,[TaxCode]
        ,[TaxNumber]
        ,@crntCustGUID	
	FROM [#GCCCustomerTax] AS gct
#################################################################
CREATE PROCEDURE prcIE_ImportGCCTaxAccounts
AS 
	SET NOCOUNT ON
	IF NOT EXISTS(SELECT [NAME] FROM [SysObjects] WHERE [NAME] = 'GCCCustLocations2')
		RETURN
	SELECT * INTO [#GCCCustLocations] FROM [GCCCustLocations2]

	SELECT gcl.VATAccGUID, ROW_NUMBER() OVER (ORDER BY gcl.VATAccGUID) AS seqNumber INTO #vac FROM [#GCCCustLocations] AS gcl 
	LEFT JOIN GCCTaxAccounts000 AS gta ON gta.VATAccGUID = gcl.VATAccGUID
	WHERE gta.VATAccGUID IS NULL AND gcl.VATAccGUID != 0x00

	SELECT gcl.ReturnAccGUID, ROW_NUMBER() OVER (ORDER BY gcl.ReturnAccGUID) AS seqNumber INTO #rac FROM [#GCCCustLocations] AS gcl 
	LEFT JOIN GCCTaxAccounts000 AS gta ON gta.ReturnAccGUID = gcl.ReturnAccGUID
	WHERE gta.ReturnAccGUID IS NULL AND gcl.ReturnAccGUID != 0x00

	UPDATE gta2
	SET gta2.VATAccGUID = #vac.VATAccGUID
	FROM (
		SELECT GCCTaxAccounts000.[VATAccGUID], 
			CASE GCCTaxAccounts000.VATAccGUID 
				WHEN 0x00 THEN (ROW_NUMBER() OVER (PARTITION BY GCCTaxAccounts000.VATAccGUID ORDER BY GUID ASC)) 
				ELSE NULL 
			END AS seqNumber 
		FROM GCCTaxAccounts000) AS gta2
	INNER JOIN #vac ON #vac.seqNumber = gta2.seqNumber

	DECLARE @MaxNum [INT]
	SELECT @MaxNum = ISNULL(MAX([Number]),0) FROM [GCCTaxAccounts000]

	--delete existing rows from the vac table
	DELETE v FROM #vac AS v
	INNER JOIN GCCTaxAccounts000 AS gta	ON gta.VATAccGUID = v.VATAccGUID

	INSERT INTO [GCCTaxAccounts000]
           ([Number]
           ,[GUID]
           ,[VATAccGUID]
           ,[ReturnAccGUID]
           ,[ReverseChargesAccGUID]
           ,[ReturnReverseChargesAccGUID]
           ,[ExciseTaxAccGUID]
           ,[ReturnExciseTaxAccGUID])
	SELECT 
			@MaxNum + (ROW_NUMBER() OVER(ORDER BY #vac.seqNumber ASC))
			,NEWID()
			,#vac.VATAccGUID
			,0x00
			,0x00
			,0x00
			,0x00
			,0x00
	FROM #vac

	UPDATE gta2
	SET gta2.ReturnAccGUID = #rac.ReturnAccGUID
	FROM (
		SELECT *, 
			CASE GCCTaxAccounts000.ReturnAccGUID 
				WHEN 0x00 THEN (ROW_NUMBER() OVER (PARTITION BY GCCTaxAccounts000.ReturnAccGUID ORDER BY GUID ASC)) 
				ELSE NULL 
			END AS seqNumber 
		FROM GCCTaxAccounts000) AS gta2
	INNER JOIN #rac ON #rac.seqNumber = gta2.seqNumber

	SELECT @MaxNum = ISNULL(MAX([Number]),0) FROM [GCCTaxAccounts000]

	--delete existing rows from the rac table
	DELETE r FROM #rac AS r
	INNER JOIN GCCTaxAccounts000 AS gta	ON gta.ReturnAccGUID = r.ReturnAccGUID

	INSERT INTO [GCCTaxAccounts000]
           ([Number]
           ,[GUID]
           ,[VATAccGUID]
           ,[ReturnAccGUID]
           ,[ReverseChargesAccGUID]
           ,[ReturnReverseChargesAccGUID]
           ,[ExciseTaxAccGUID]
           ,[ReturnExciseTaxAccGUID])
	SELECT 
			@MaxNum + (ROW_NUMBER() OVER(ORDER BY #rac.seqNumber ASC))
			,NEWID()
			,0x00
			,#rac.ReturnAccGUID
			,0x00
			,0x00
			,0x00
			,0x00
	FROM #rac
#################################################################
CREATE PROCEDURE prcIE_IsSameCustomerTaxSettings
	@impCustGUID UNIQUEIDENTIFIER,
	@crntCustGUID UNIQUEIDENTIFIER,
	@impGCCLocationGUID UNIQUEIDENTIFIER,
	@impCustName NVARCHAR(MAX)
AS
	SET NOCOUNT ON
	IF NOT EXISTS(SELECT [NAME] FROM [SysObjects] WHERE [NAME] = 'GCCCustomerTax2')
		RETURN

	SELECT *, ROW_NUMBER() OVER(ORDER BY gct1.TaxType, gct1.TaxCode ASC) AS seqNumber INTO [#GCCCustomerTax1] FROM [GCCCustomerTax000] AS gct1 WHERE gct1.CustGUID = @crntCustGUID
	SELECT *, ROW_NUMBER() OVER(ORDER BY gct2.TaxType, gct2.TaxCode ASC) AS seqNumber INTO [#GCCCustomerTax2] FROM [GCCCustomerTax2]   AS gct2 WHERE gct2.CustGUID = @impCustGUID

	SELECT *
	INTO #Res
	FROM
	(	SELECT gct1.CustGUID AS crntCustGUID, gct2.CustGUID AS impCustGUID
		FROM [#GCCCustomerTax1] AS gct1
		LEFT JOIN #GCCCustomerTax2 AS gct2 
		ON	gct2.CustGUID = @impCustGUID
		AND gct1.CustGUID = @crntCustGUID
		AND gct2.TaxType = gct1.TaxType
		AND gct2.TaxCode = gct1.TaxCode
		AND gct2.seqNumber = gct1.seqNumber) AS gct3
	WHERE (gct3.impCustGUID IS NOT NULL) AND (gct3.crntCustGUID = @crntCustGUID)

	DECLARE @c1 INT
	DECLARE @c2 INT
	DECLARE @c3 INT

	SET @c1 = (SELECT COUNT(CustGUID) FROM [#GCCCustomerTax1] WHERE CustGUID = @crntCustGUID)
	SET @c2 = (SELECT COUNT(CustGUID) FROM [#GCCCustomerTax2] WHERE CustGUID = @impCustGUID)
	SET @c3 = (SELECT COUNT(crntCustGUID) FROM #Res)
	
	DECLARE @ResCustName NVARCHAR(MAX)
	SET @ResCustName = N''
	IF @c1 != @c2 OR @c2 != @c3 OR @c1 != @c3
	BEGIN
		SET @ResCustName = (@impCustName + N'_' + (SELECT Code FROM GCCTaxCoding000 gtco INNER JOIN (SELECT TOP(1) * FROM [#GCCCustomerTax2] ORDER BY TaxType, TaxCode) AS gct2 ON gct2.TaxType = gtco.TaxType AND gct2.TaxCode = gtco.TaxCode ))
	END
	ELSE
	BEGIN
		SELECT * INTO [#GCCCustLocations] FROM [GCCCustLocations2]
		DECLARE @ImpLocationName NVARCHAR(MAX)
		DECLARE @CrntLocationName NVARCHAR(MAX)
		SET @ImpLocationName = (SELECT Name FROM [#GCCCustLocations] WHERE GUID = @impGCCLocationGUID)
		SET @CrntLocationName = (SELECT gcl.Name FROM [GCCCustLocations000] AS gcl INNER JOIN cu000 AS cu ON cu.GCCLocationGUID = gcl.GUID WHERE cu.GUID = @crntCustGUID)
		IF @ImpLocationName != @CrntLocationName
			SET @ResCustName = @impCustName + N'_' + @ImpLocationName
	END
	SELECT @ResCustName AS CustomerName 
#################################################################
CREATE PROCEDURE prcIE_IsSameMaterialTaxSettings
AS
	SET NOCOUNT ON
	IF NOT EXISTS(SELECT [NAME] FROM [SysObjects] WHERE [NAME] = 'GCCMaterialTax2')
		RETURN
	SELECT * INTO [#GCCMaterialTax] FROM [GCCMaterialTax2]
	SELECT * INTO [#mt] FROM [mt2]

	SELECT (mt1.GUID) AS CrntGUID, ([#mt].GUID) AS ImpGUID INTO #sameMat 
	FROM mt000 AS mt1
	INNER JOIN [#mt] ON [#mt].GUID = mt1.GUID OR ([#mt].GUID != mt1.GUID AND [#mt].Code = mt1.Code)
	INNER JOIN (SELECT DISTINCT(MatGUID) FROM [GCCMaterialTax000]) AS gmt1 ON gmt1.MatGUID = mt1.GUID
	INNER JOIN (SELECT DISTINCT(MatGUID) FROM [#GCCMaterialTax]) AS gmt2 ON gmt2.MatGUID = [#mt].GUID

	SELECT gmt1.*, ROW_NUMBER() OVER(PARTITION BY gmt1.MatGUID ORDER BY gmt1.TaxType, gmt1.TaxCode ASC) AS seqNumber INTO [#GCCMaterialTax1] FROM [GCCMaterialTax000] AS gmt1 INNER JOIN #sameMat ON gmt1.MatGUID = #sameMat.CrntGUID
	SELECT gmt2.*, ROW_NUMBER() OVER(PARTITION BY gmt2.MatGUID ORDER BY gmt2.TaxType, gmt2.TaxCode ASC) AS seqNumber INTO [#GCCMaterialTax2] FROM [#GCCMaterialTax]   AS gmt2 INNER JOIN #sameMat ON gmt2.MatGUID = #sameMat.ImpGUID 

	SELECT DISTINCT(gmt4.crntMatGUID), SUM(gmt4.flg) OVER (PARTITION BY crntMatGUID) AS Total
	INTO #Res1
	FROM
	(
		SELECT gmt3.crntMatGUID, gmt3.impMatGUID, CASE WHEN gmt3.impMatGUID IS NULL THEN 0 ELSE 1 END AS flg
		FROM
		(	SELECT gmt1.MatGUID AS crntMatGUID, gmt2.MatGUID AS impMatGUID
			FROM [#GCCMaterialTax1] AS gmt1
			INNER JOIN #sameMat 
			ON #sameMat.CrntGUID = gmt1.MatGUID
			LEFT JOIN [#GCCMaterialTax2] AS gmt2 
			ON  gmt2.MatGUID = #sameMat.ImpGUID
			AND gmt2.TaxType = gmt1.TaxType
			AND gmt2.TaxCode = gmt1.TaxCode
			AND gmt2.seqNumber = gmt1.seqNumber
		) AS gmt3
	) AS gmt4

	SELECT DISTINCT(gmt4.crntMatGUID), SUM(gmt4.flg) OVER (PARTITION BY crntMatGUID) AS Total
	INTO #Res2
	FROM
	(
		SELECT gmt3.crntMatGUID, 1 AS flg
		FROM
		(	SELECT #sameMat.CrntGUID AS crntMatGUID
			FROM [#GCCMaterialTax1] AS gmt1
			INNER JOIN #sameMat 
			ON #sameMat.CrntGUID = gmt1.MatGUID
		) AS gmt3
	) AS gmt4

	SELECT DISTINCT(gmt4.crntMatGUID), SUM(gmt4.flg) OVER (PARTITION BY crntMatGUID) AS Total
	INTO #Res3
	FROM
	(
		SELECT gmt3.crntMatGUID, 1 AS flg
		FROM
		(	SELECT #sameMat.CrntGUID AS crntMatGUID
			FROM [#GCCMaterialTax2] AS gmt2
			INNER JOIN #sameMat 
			ON #sameMat.ImpGUID = gmt2.MatGUID
		) AS gmt3
	) AS gmt4

	SELECT ttbl.* 
	INTO #MatWithDiffTaxSettings
	FROM 
	(
		SELECT #Res1.crntMatGUID, #Res1.Total AS Total1, #Res2.Total AS Total2, #Res3.Total AS Total3
		FROM #Res1
		INNER JOIN #Res2 ON #Res2.crntMatGUID = #Res1.crntMatGUID
		INNER JOIN #Res3 ON #Res3.crntMatGUID = #Res2.crntMatGUID
	) AS ttbl
	WHERE ttbl.Total1 != ttbl.Total2 OR ttbl.Total1 != ttbl.Total3 OR ttbl.Total2 != ttbl.Total3

	SELECT mt.GUID AS GUID, mt.Name AS Name, mt.LatinName AS LatinName, gtco.Code AS Code, mt.Code AS MatCode
	INTO #NameCodeMat
	FROM #MatWithDiffTaxSettings AS mdt
	INNER JOIN #sameMat ON #sameMat.crntGUID = mdt.crntMatGUID
	INNER JOIN [#mt] AS mt ON mt.GUID = #sameMat.ImpGUID
	INNER JOIN #GCCMaterialTax2 AS gct2 ON gct2.MatGUID = #sameMat.ImpGUID
	INNER JOIN GCCTaxCoding000 AS gtco ON gtco.TaxType = gct2.TaxType AND gtco.TaxCode = gct2.TaxCode
	GROUP BY mt.GUID, gct2.TaxType, gct2.TaxCode, mt.LatinName, mt.Name, gtco.Code, mt.Code
	ORDER BY mt.GUID, gct2.TaxType, gct2.TaxCode, mt.LatinName, mt.Name, gtco.Code, mt.Code

	SELECT NEWID(), GUID, (Name + N'_' + Code), CASE LatinName WHEN '' THEN LatinName ELSE (LatinName + N'_' + Code) END, (MatCode + N'_' + Code) FROM #NameCodeMat
#################################################################
CREATE PROCEDURE prcIE_GetExportedGCCCustLocations
AS 
	SET NOCOUNT ON

	SELECT
		* 
	FROM 
		[GCCCustLocations000] 
	WHERE GUID IN (	SELECT cu.GCCLocationGUID FROM 
		cu000 AS cu
		INNER JOIN [ctbl] AS cu2 ON cu2.GUID = cu.GUID) 
	ORDER BY 
		Number
#################################################################
CREATE PROCEDURE prcIE_GetExportedGCCCustomerTax
AS 
	SET NOCOUNT ON
	SELECT gct.* FROM [GCCCustomerTax000] AS gct 
	INNER JOIN [ctbl] AS cu2 ON cu2.GUID = gct.CustGUID
#################################################################
CREATE PROCEDURE prcIE_GetExportedGCCMaterialTax
AS 
	SET NOCOUNT ON
	SELECT gmt.* FROM [GCCMaterialTax000] AS gmt 
	INNER JOIN [mtbl] AS mt2 ON mt2.GUID = gmt.MatGUID
#################################################################
#END