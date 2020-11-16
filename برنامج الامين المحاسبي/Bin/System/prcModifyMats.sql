#############################################
CREATE PROCEDURE prcModifyMats
	@MatCode				[NVARCHAR](256),
	@MatName				[NVARCHAR](256),
	@MatLatinName			[NVARCHAR](256),
	@Barcode				[NVARCHAR](256),
	@Spec					[NVARCHAR](256),
	@GroupName				[NVARCHAR](256),
	@Dim					[NVARCHAR](256),
	@Origin					[NVARCHAR](256),
	@Pos					[NVARCHAR](256),
	@Company				[NVARCHAR](256),
	@Model					[NVARCHAR](256),
	@Quality				[NVARCHAR](256),
	@Provenance				[NVARCHAR](256),
	@Color					[NVARCHAR](256),

	@WholePrice				[NVARCHAR](256),
	@HalfPrice				[NVARCHAR](256),
	@RetailPrice			[NVARCHAR](256),
	@ExportPrice			[NVARCHAR](256),
	@VendorPrice			[NVARCHAR](256),
	@EndUserPrice			[NVARCHAR](256),
	@Max					[NVARCHAR](256),
	@Low					[NVARCHAR](256),
	@Vat					[NVARCHAR](256),
	@OrderLimit				[NVARCHAR](256),
	@ReGenerateCodeName		[BIT] = 0,
	@Code 					[NVARCHAR](1000) = '',
	@Name 					[NVARCHAR](1000) = '',
	@MatCondGuid			[UNIQUEIDENTIFIER] = 0X00,
	@HideMat			INT = -1
AS
	SET NOCOUNT ON
	BEGIN TRAN
	DECLARE @MatCount [INT]
	CREATE TABLE [#MatTbl]( [MatGuid] [UNIQUEIDENTIFIER], [mtSecurity] [INT])
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		0x0, 0x0, -1,@MatCondGuid
	SET @MatCount = @@ROWCOUNT
	--select * from #MatTbl

	DECLARE @Empty [BIT]
	SET @Empty = 1
	DECLARE @UseComma [INT]
	SET @UseComma = 0
	DECLARE @s [NVARCHAR](max)
	SET @s = ' UPDATE [mt000] SET '
	IF ((ISNULL( @MatCode, '') <> '') AND (@MatCount = 1) AND (NOT EXISTS(SELECT * FROM [mt000] WHERE GUID NOT IN (SELECT [MatGuid] FROM [#MatTbl]))))
	BEGIN
		SET @s = @s + ' [Code] = N''' + @MatCode + ''''
		SET @UseComma = 1
		SET @Empty = 0
	END
	 

	IF ((ISNULL( @MatName, '') <> '') AND ((EXISTS( SELECT * FROM [op000] WHERE [Value] = '1' AND [Name] = 'AmnCfg_CanDuplicateMatName') ) OR((@MatCount = 1) AND (NOT EXISTS(SELECT * FROM [mt000] WHERE GUID NOT IN (SELECT [MatGuid] FROM [#MatTbl])))) ))
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' Name = N''' + @MatName + ''''
		SET @UseComma = 1
		SET @Empty = 0
	END
	IF ISNULL( @MatLatinName, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [LatinName] = N''' + @MatLatinName + ''''
		SET @UseComma = 1
		SET @Empty = 0
	END
	IF ISNULL( @Barcode, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [Barcode] = N''' + @Barcode + ''''
		SET @UseComma = 1
		SET @Empty = 0
	END
	IF ISNULL( @Spec, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [Spec] = N''' + @Spec + ''''
		SET @UseComma = 1
		SET @Empty = 0
	END
	IF ISNULL( @Dim, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [Dim] = N''' + @Dim + ''''
		SET @UseComma = 1
		SET @Empty = 0
	END
	IF ISNULL( @Origin, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [Origin] = N''' + @Origin + ''''
		SET @UseComma = 1
		SET @Empty = 0
	END
	IF ISNULL( @Pos, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [Pos] = N''' + @Pos + ''''
		SET @UseComma = 1
		SET @Empty = 0
	END
	IF ISNULL( @Company, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [Company] = N''' + @Company + ''''
		SET @UseComma = 1
		SET @Empty = 0
	END
	IF ISNULL( @Model, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [Model] = N''' + @Model + ''''
		SET @UseComma = 1
		SET @Empty = 0
	END	
	IF ISNULL( @Quality, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [Quality] = N''' + @Quality + ''''
		SET @UseComma = 1
		SET @Empty = 0
	END	
	IF ISNULL( @Provenance, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [Provenance] = N''' + @Provenance + ''''
		SET @UseComma = 1
		SET @Empty = 0
	END	
	IF ISNULL( @Color, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [Color] = N''' + @Color + ''''
		SET @UseComma = 1
		SET @Empty = 0
	END	

	IF ISNULL( @WholePrice, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [Whole] = ' + @WholePrice
		SET @UseComma = 1
		SET @Empty = 0
	END	
	IF ISNULL( @HalfPrice, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [Half] = ' + @HalfPrice
		SET @UseComma = 1
		SET @Empty = 0
	END	
	IF ISNULL( @RetailPrice, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [Retail] = ' + @RetailPrice
		SET @UseComma = 1
		SET @Empty = 0
	END	
	IF ISNULL( @ExportPrice, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [Export] = ' + @ExportPrice
		SET @UseComma = 1
		SET @Empty = 0
	END	
	IF ISNULL( @VendorPrice, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [Vendor] = ' + @VendorPrice
		SET @UseComma = 1
		SET @Empty = 0
	END			
	IF ISNULL( @EndUserPrice, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [EndUser] = ' + @EndUserPrice
		SET @UseComma = 1
		SET @Empty = 0
	END			
	IF ISNULL( @Max, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [High] = ' + @Max
		SET @UseComma = 1
		SET @Empty = 0
	END	
	IF ISNULL( @Low, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [Low] = ' + @Low
		SET @UseComma = 1
		SET @Empty = 0
	END	
	IF ISNULL( @OrderLimit, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [OrderLimit] = ' + @OrderLimit
		SET @UseComma = 1
		SET @Empty = 0
	END		
	IF ISNULL( @Vat, '') <> ''
	BEGIN
		IF @UseComma = 1
			SET @s = @s + ', '
		SET @s = @s + ' [VAT] = ' + @Vat
		SET @UseComma = 1
		SET @Empty = 0
	END					

	IF @Empty = 0
	BEGIN
		IF @ReGenerateCodeName = 1
			SELECT	[Guid] AS [Guid2],[Color] AS [COLOR2] ,[ORIGIN] AS [ORIGIN2],[POS] AS [POS2],[COMPANY] AS [COMPANY2],[PROVENANCE] AS [PROVENANCE2],[QUALITY] AS [QUALITY2], [MODEL] AS [MODEL2],[Dim] AS [dim2] INTO [#MT2] FROM [mt000] AS [mt] INNER JOIN [#MatTbl] AS [t] ON [mt].[Guid] = [t].[MatGuid] 
		SET @s = @s + ' FROM [mt000] AS [mt] INNER JOIN [#MatTbl] AS [t] ON [mt].[Guid] = [t].[MatGuid] ' 
		EXECUTE( @s)
	END
--- modify groups 
	IF ISNULL( @GroupName, '') <> ''
	BEGIN
		CREATE TABLE [#GrpTbl]( [GroupGuid] [UNIQUEIDENTIFIER])
		INSERT INTO [#GrpTbl] SELECT [GroupGuid] FROM [mt000] AS [mt] INNER JOIN [#MatTbl] AS [t] ON [mt].[Guid] = [t].[MatGuid]
		DECLARE @str [NVARCHAR](2000)
		SET @str = ' UPDATE [gr000] SET [Name] = ''' + @GroupName + ''''
		SET @str = @str + ' FROM [gr000] AS [gr] INNER JOIN [#GrpTbl] AS [g] ON [gr].[Guid] = [g].[GroupGuid]'
		EXECUTE( @str)
		INSERT INTO [#MatTbl]  SELECT [GroupGuid],-1 FROM [#GrpTbl] 
	END
	IF @HideMat = 1 OR @HideMat = 0
	BEGIN
		UPDATE [mt] SET [bHide] = @HideMat FROM [mt000] AS [mt] INNER JOIN [#MatTbl] AS [t] ON [mt].[Guid] = [t].[MatGuid]  
		SET @Empty = 0
	END
	
	IF @Empty = 0
	BEGIN
		SELECT [MatGuid] AS [Guid] , CASE [mtSecurity] WHEN -1 THEN 1 ELSE 0 END AS [Type] FROM [#MatTbl] 
	END
	IF @ReGenerateCodeName = 1 
	BEGIN
		IF  @Empty = 0
			EXEC [prcReGenerateMatCodeAndName] @Code,	@Name
		ELSE
			SELECT * FROM [#MatTbl] WHERE [mtSecurity] = 11
	END
	COMMIT
	
	--	select * from gr000
/*
	EXEC prcModifyMats '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 'деѕн', 1, 'color_code+quality_code+model_code+company_code+Dim_CODE', 'color + '' '' +  quality + '' '' +  model + '' '' +  company + '' '' +  Dim' 
	exec prcModifyMats '', '', '', '', '', '', '', '', '', '', '', '', '', '', '10', '', '', '', '', ''
*/

####################################################
#END