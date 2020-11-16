########################################
CREATE PROCEDURE prcCutomersTaxingTools
	@CustGUID UNIQUEIDENTIFIER,
	@AccGUID UNIQUEIDENTIFIER,
	@CondGuid UNIQUEIDENTIFIER,
	@TaxType INT,
	@TaxCodeing INT,
	@CustLocGUID UNIQUEIDENTIFIER,
	@EditTaxCode BIT,
	@EditTaxLocation BIT,
	@ActionType INT,	-- 0: add & modify, 1: moddify only, 2: add only
	@UseReverseCharges BIT,
	@CustLoc NVARCHAR(100) = ''
AS
	SET NOCOUNT ON

	EXEC prcDisableTriggers 'cu000'

	CREATE TABLE [#TempCust] ( [Number] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#Cust] 
		( [Number] [UNIQUEIDENTIFIER] , 
		[Security] [INT], 
		[Num] [INT],
		[Name] nvarchar(250),
		[LatinName] nvarchar(250))
	CREATE TABLE [#CustLog] ( [GUID] [UNIQUEIDENTIFIER])

	INSERT INTO [#TempCust]( [Number], [Security]) EXEC [prcGetCustsList] @CustGUID, @AccGUID, @CondGuid

	INSERT INTO [#Cust] ( [Number] , [Security], [Num], [Name], [LatinName])
	SELECT
		[CUST].[Number] , 
		[CUST].[Security], 
		[CU].[Number],
		[CU].[CustomerName],
		[CU].[LatinName]
	FROM
		[#TempCust] AS CUST
		INNER JOIN cu000 AS CU ON CU.GUID = CUST.Number

	DECLARE 
		@UpdatedRowsCount INT,
		@InsertedRowsCount INT 
	
	SET @UpdatedRowsCount = 0
	SET @InsertedRowsCount = 0

	DECLARE @UserGuid	[UNIQUEIDENTIFIER]
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()

	IF @ActionType != 2
	BEGIN 
		IF @EditTaxCode > 0
		BEGIN
			UPDATE GCCCustomerTax000
			SET 
				TaxCode = CASE @EditTaxCode WHEN 1 THEN @TaxCodeing ELSE TAX.TaxCode END
			FROM 
				GCCCustomerTax000 TAX
				INNER JOIN [#Cust] c ON TAX.CustGUID = c.Number
			WHERE 
				TAX.TaxType = @TaxType
		
			SET @UpdatedRowsCount = @UpdatedRowsCount + @@ROWCOUNT
			
			IF EXISTS(SELECT * FROM OP000 WHERE [NAME] ='AmnCfg_UseLogging' AND [Value] = 1) 
			BEGIN 
				INSERT INTO  [#CustLog] ([GUID])
				SELECT 
					c.Number
				FROM 
					GCCCustomerTax000 TAX
					INNER JOIN [#Cust] c ON TAX.CustGUID = c.Number
				WHERE 
					TAX.TaxType = @TaxType
			END
		END 

		IF @EditTaxLocation = 1
		BEGIN 
			UPDATE cu000
			SET 
				GCCLocationGUID = @CustLocGUID,
				ReverseCharges = @UseReverseCharges,
				GCCCountry = @CustLoc
			FROM 
				cu000 cu
				INNER JOIN [#Cust] c ON cu.GUID = c.Number

			SET @UpdatedRowsCount = @UpdatedRowsCount + @@ROWCOUNT

			IF EXISTS(SELECT * FROM OP000 WHERE [NAME] ='AmnCfg_UseLogging' AND [Value] = 1) 
			BEGIN 
				INSERT INTO  [#CustLog] ([GUID])
				SELECT 
					c.Number
				FROM 
					cu000 cu
					INNER JOIN [#Cust] c ON cu.GUID = c.Number
				WHERE
					NOT EXISTS(SELECT [GUID] FROM [#CustLog] cl WHERE cl.[GUID] = c.Number)
			END
		END
	END 

	IF @ActionType != 1
	BEGIN 
		UPDATE cu000
		SET 
			GCCLocationGUID = @CustLocGUID,
			ReverseCharges = @UseReverseCharges,
			GCCCountry = @CustLoc
		FROM 
			cu000 cu
			INNER JOIN [#Cust] c ON cu.GUID = c.Number
			LEFT JOIN GCCCustomerTax000 t ON t.CustGUID = c.Number AND t.TaxType = @TaxType
		WHERE 
			t.GUID IS NULL
			
		IF EXISTS(SELECT * FROM OP000 WHERE [NAME] ='AmnCfg_UseLogging' AND [Value] = 1) 
		BEGIN 
			INSERT INTO  [#CustLog] ([GUID])
			SELECT 
				c.Number
			FROM 
				cu000 cu
				INNER JOIN [#Cust] c ON cu.GUID = c.Number
				LEFT JOIN GCCCustomerTax000 t ON t.CustGUID = c.Number AND t.TaxType = @TaxType
			WHERE 
				t.GUID IS NULL AND NOT EXISTS(SELECT [GUID] FROM [#CustLog] cl WHERE cl.[GUID] = c.Number)

			INSERT INTO  [#CustLog] ([GUID])
			SELECT 
				cu.Number
			FROM 
				#Cust cu
				LEFT JOIN GCCCustomerTax000 t ON t.CustGUID = cu.Number AND t.TaxType = @TaxType
			WHERE 
				t.GUID IS NULL AND NOT EXISTS(SELECT [GUID] FROM [#CustLog] cl WHERE cl.[GUID] = cu.Number)
		END

		INSERT INTO GCCCustomerTax000 (GUID, TaxType, TaxCode, TaxNumber, CustGUID)
		SELECT 
			NEWID(), 
			@TaxType, 
			@TaxCodeing, 
			'', 
			cu.Number 
		FROM 
			#Cust cu
			LEFT JOIN GCCCustomerTax000 t ON t.CustGUID = cu.Number AND t.TaxType = @TaxType
		WHERE 
			t.GUID IS NULL

		SET @InsertedRowsCount = @InsertedRowsCount + @@ROWCOUNT
	END
	
	IF EXISTS(SELECT * FROM [#CustLog])
	BEGIN
		INSERT INTO  LoG000 (Computer,[GUID],LogTime,RecGUID,RecNum,TypeGUID,Operation,OperationType,UserGUID,Notes)
		SELECT 
			host_Name(), 
			NEWID(), 
			GETDATE(), 
			c.Number, 
			c.Num, 
			0x00, 
			1026, 
			3, 
			@UserGUID, 
			dbo.fnStrings_get('GCC\UPDATECUSTOMERTAX', DEFAULT) + (case [dbo].[fnConnections_GetLanguage]() when 0 then [c].[Name] else [c].[LatinName]  end)
		FROM 
			[#CustLog] cl
			INNER JOIN [#Cust] c ON c.[Number] = cl.[GUID]
	END
	EXEC prcEnableTriggers 'cu000'

	SELECT 
		@UpdatedRowsCount AS [UpdatedRowsCount], 
		@InsertedRowsCount AS [InsertedRowsCount]
#############################
#END
