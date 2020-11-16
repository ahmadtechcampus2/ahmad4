########################################
CREATE PROCEDURE prcMaterialsTaxingTools
	@MatGuid UNIQUEIDENTIFIER,
	@GroupGuid UNIQUEIDENTIFIER,
	@MatCondGuid UNIQUEIDENTIFIER,
	@TaxType INT,
	@TaxCodeing INT,
	@TaxRatio FLOAT,
	@EditTaxCoding BIT,
	@ActionType INT,	-- 0: add & modify, 1: moddify only, 2: add only
	@IsCalcedByProfit BIT = 0
AS
	SET NOCOUNT ON
	
	IF @TaxRatio < 0
		SET @TaxRatio = 0

	CREATE TABLE [#TempMat] 
		( [mtNumber] [UNIQUEIDENTIFIER] ,
		[mtSecurity] [INT])

	CREATE TABLE [#Mat] 
		( [mtNumber] [UNIQUEIDENTIFIER] , 
		[mtSecurity] [INT], 
		[mtNum] [INT],
		[mtName] nvarchar(250),
		[mtLatinName] nvarchar(250),
		[mtCode] nvarchar(100))
	
	CREATE TABLE [#MatLog] ( [GUID] [UNIQUEIDENTIFIER])

	INSERT INTO [#TempMat] EXEC [prcGetMatsList] @MatGuid, @GroupGuid, -1, @MatCondGuid, 0

	INSERT INTO [#Mat] ( [mtNumber] , [mtSecurity], [mtNum], [mtName], [mtLatinName], [mtCode])
	SELECT
		[MAT].[mtNumber] , 
		[MAT].[mtSecurity], 
		[MT].[Number],
		[MT].[Name],
		[MT].[LatinName],
		[MT].[Code]
	FROM
		[#TempMat] AS MAT
		INNER JOIN mt000 AS MT ON MT.GUID = MAT.mtNumber

	DECLARE 
		@UpdatedRowsCount INT,
		@InsertedRowsCount INT 
	
	SET @UpdatedRowsCount = 0
	SET @InsertedRowsCount = 0

	DECLARE @UserGuid	[UNIQUEIDENTIFIER]
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()

	IF @ActionType != 2
	BEGIN 
		UPDATE GCCMaterialTax000
		SET 
			TaxCode = CASE @EditTaxCoding WHEN 1 THEN @TaxCodeing ELSE TAX.TaxCode END,
			Ratio = CASE @EditTaxCoding WHEN 1 THEN @TaxRatio ELSE TAX.Ratio END,
			ProfitMargin = 
				CASE @TaxType 
					WHEN 1 /*VAT*/ THEN 
						CASE (CASE @EditTaxCoding WHEN 1 THEN @TaxCodeing ELSE TAX.TaxCode END)
							WHEN 1 /*SR*/ THEN @IsCalcedByProfit 
							ELSE 0 
						END 
					ELSE 0 
				END 
		FROM 
			GCCMaterialTax000 TAX
			INNER JOIN #Mat MT ON TAX.MatGUID = MT.mtNumber
		WHERE 
			TAX.TaxType = @TaxType
			AND 
			((@EditTaxCoding = 1) OR ((@EditTaxCoding = 0) AND (TAX.TaxCode = @TaxCodeing)))

		SET @UpdatedRowsCount = @UpdatedRowsCount + @@ROWCOUNT

		IF EXISTS(SELECT * FROM OP000 WHERE [NAME] ='AmnCfg_UseLogging' AND [Value] = 1) 
		BEGIN 
			INSERT INTO  [#MatLog] ([GUID])
			SELECT 
				MT.mtNumber
			FROM 
				GCCMaterialTax000 TAX
				INNER JOIN #Mat MT ON TAX.MatGUID = MT.mtNumber
			WHERE 
				TAX.TaxType = @TaxType
				AND 
				((@EditTaxCoding = 1) OR ((@EditTaxCoding = 0) AND (TAX.TaxCode = @TaxCodeing)))
		END

	END

	IF @ActionType != 1
	BEGIN 
		IF EXISTS(SELECT * FROM OP000 WHERE [NAME] ='AmnCfg_UseLogging' AND [Value] = 1) 
		BEGIN 
			INSERT INTO  [#MatLog] ([GUID])
			SELECT 
				mt.mtNumber
			FROM 
				#Mat mt 
				LEFT JOIN GCCMaterialTax000 t ON t.MatGUID = mt.mtNumber AND t.TaxType = @TaxType
			WHERE 
				t.GUID IS NULL AND NOT EXISTS(SELECT [GUID] FROM [#MatLog] ml WHERE ml.[GUID] = mt.mtNumber)
		END

		INSERT INTO GCCMaterialTax000 (GUID, TaxType, TaxCode, Ratio, MatGUID, ProfitMargin)
		SELECT 
			NEWID(), 
			@TaxType, 
			@TaxCodeing, 
			@TaxRatio, 
			mtNumber, 
			(CASE @TaxType WHEN 1 /*VAT*/ THEN CASE @TaxCodeing WHEN 1 /*SR*/ THEN @IsCalcedByProfit ELSE 0 END ELSE 0 END) 
		FROM 
			#Mat mt 
			LEFT JOIN GCCMaterialTax000 t ON t.MatGUID = mt.mtNumber AND t.TaxType = @TaxType
		WHERE 
			t.GUID IS NULL

		SET @InsertedRowsCount = @InsertedRowsCount + @@ROWCOUNT
	END

	IF EXISTS(SELECT * FROM [#MatLog])
	BEGIN
		INSERT INTO  LoG000 (Computer,[GUID],LogTime,RecGUID,RecNum,TypeGUID,Operation,OperationType,UserGUID,Notes)
		SELECT 
			host_Name(), 
			NEWID(), 
			GETDATE(), 
			mt.mtNumber, 
			mt.mtNum, 
			0x00, 
			1025, 
			3, 
			@UserGUID, 
			dbo.fnStrings_get('GCC\UPDATEMATERIALTAX', DEFAULT) + mt.mtCode + N'-' + (case [dbo].[fnConnections_GetLanguage]() when 0 then [mt].[mtName] else [mt].[mtLatinName]  end)
		FROM 
			[#MatLog] ml
			INNER JOIN [#Mat] mt ON mt.[mtNumber] = ml.[GUID]
	END

	SELECT 
		@UpdatedRowsCount AS [UpdatedRowsCount], 
		@InsertedRowsCount AS [InsertedRowsCount]
#############################
#END
