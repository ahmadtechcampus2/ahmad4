############################################################## 
CREATE PROCEDURE repCreateTmpMat
AS
	IF EXISTS(SELECT NAME FROM SysObjects WHERE NAME ='mt2')
		DROP TABLE [dbo].[mt2]
	CREATE TABLE [dbo].[mt2] (
		[Number] [float]    DEFAULT (0),
		[Name] [NVARCHAR] (250) COLLATE Arabic_CI_AI  DEFAULT (''),
		[Code] [NVARCHAR] (100) COLLATE Arabic_CI_AI  DEFAULT (''),
		[LatinName] [NVARCHAR] (250) COLLATE Arabic_CI_AI   DEFAULT (''),
		[BarCode] [NVARCHAR] (500) COLLATE Arabic_CI_AI  DEFAULT (''),
		[CodedCode] [NVARCHAR] (250) COLLATE Arabic_CI_AI   DEFAULT (''),
		[Unity] [NVARCHAR] (100) COLLATE Arabic_CI_AI  DEFAULT (''),
		[Spec] [NVARCHAR] (250) COLLATE Arabic_CI_AI DEFAULT (''),
		[Qty] [float] DEFAULT (0),
		[High] [float]  DEFAULT (0),
		[Low]  [float] DEFAULT (0),
		[Whole] [float] DEFAULT (0),
		[Half]  [float] DEFAULT (0),
		[Retail]  [float] DEFAULT (0),
		[EndUser] [float] DEFAULT (0),
		[Export]  [float] DEFAULT (0),
		[Vendor]  [float] DEFAULT (0),
		[MaxPrice]  [float] DEFAULT (0),
		[AvgPrice]  [float] DEFAULT (0),
		[LastPrice]   [float] DEFAULT (0),
		[PriceType] [float] DEFAULT (0),
		[SellType] [int]  DEFAULT (0),
		[BonusOne] [float] DEFAULT (0),
		[CurrencyVal] [float]  DEFAULT (0),
		[UseFlag] [float] DEFAULT (0),
		[Origin] [NVARCHAR] (250) COLLATE Arabic_CI_AI   DEFAULT (''),
		[Company] [NVARCHAR] (250) COLLATE Arabic_CI_AI  DEFAULT (''),
		[Type] [int]  DEFAULT (0),
		[Security] [int]  DEFAULT (0),
		[LastPriceDate] [DATETIME]  DEFAULT ('1/1/1980'),
		[Bonus] [float]  DEFAULT (0),
		[Unit2] [NVARCHAR] (100)  DEFAULT (''),
		[Unit2Fact] [float]  DEFAULT (0),
		[Unit3] [NVARCHAR] (100) COLLATE Arabic_CI_AI  DEFAULT (''),
		[Unit3Fact] [float]  DEFAULT (0),
		[Flag] [float]  DEFAULT (0),
		[Pos] [NVARCHAR] (250) COLLATE Arabic_CI_AI DEFAULT (''),
		[Dim] [NVARCHAR] (250) COLLATE Arabic_CI_AI DEFAULT (''),
		[ExpireFlag] [bit]  DEFAULT (0),
		[ProductionFlag] [bit]  DEFAULT (0),
		[Unit2FactFlag] [bit]  DEFAULT (0),
		[Unit3FactFlag] [bit]  DEFAULT (0),
		[BarCode2] [NVARCHAR] (500) COLLATE Arabic_CI_AI DEFAULT (''),
		[BarCode3] [NVARCHAR] (500) COLLATE Arabic_CI_AI  DEFAULT (''),
		[SNFlag] [bit]  DEFAULT (0),
		[ForceInSN] [bit]  DEFAULT (0),
		[ForceOutSN] [bit]  DEFAULT (0),
		[VAT] [float]  DEFAULT (0),
		[Color] [NVARCHAR] (250) COLLATE Arabic_CI_AI  DEFAULT (''),
		[Provenance] [NVARCHAR] (250) COLLATE Arabic_CI_AI  DEFAULT (''),
		[Quality] [NVARCHAR] (250) COLLATE Arabic_CI_AI DEFAULT (''),
		[Model] [NVARCHAR] (250) COLLATE Arabic_CI_AI  DEFAULT (''),
		[Whole2] [float]  DEFAULT (0),
		[Half2] [float]  DEFAULT (0),
		[Retail2] [float] DEFAULT (0),
		[EndUser2] [float] DEFAULT (0),
		[Export2] [float]  DEFAULT (0),
		[Vendor2] [float] DEFAULT (0),
		[MaxPrice2] [float]  DEFAULT (0),
		[LastPrice2] [float] DEFAULT (0),
		[Whole3] [float]  DEFAULT (0),
		[Half3] [float] DEFAULT (0),
		[Retail3] [float] DEFAULT (0),
		[EndUser3] [float]  DEFAULT (0),
		[Export3] [float]  DEFAULT (0),
		[Vendor3] [float] DEFAULT (0),
		[MaxPrice3] [float]  DEFAULT (0),
		[LastPrice3] [float]  DEFAULT (0),
		[GUID]  [UNIQUEIDENTIFIER]  CONSTRAINT G PRIMARY KEY DEFAULT (newid()),
		[GroupGUID] [UNIQUEIDENTIFIER] DEFAULT (0x00),
		[PictureGUID] [UNIQUEIDENTIFIER] DEFAULT (0x00),
		[CurrencyGUID] [UNIQUEIDENTIFIER]  DEFAULT (0x00),
		[DefUnit] [int]  DEFAULT (0),
		[bHide] [bit]  DEFAULT (0),
		[branchMask] [bigint]  DEFAULT (0),
		[GuidID] [UNIQUEIDENTIFIER] DEFAULT (0X00),
		[Assemble] [int] DEFAULT (0),
		[OrderLimit] [float] DEFAULT (0),
		[OldGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[NewGUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[CalPriceFromDetail] [bit] NULL DEFAULT ((0)),
		[ForceInExpire] [bit] NULL DEFAULT ((0)),
		[ForceOutExpire] [bit] NULL DEFAULT ((0)),
		[CreateDate] [datetime] NULL DEFAULT ('1/1/1980'),
		[IsIntegerQuantity] [bit] NULL DEFAULT ((0)),
		[ClassFlag] [bit] NULL DEFAULT ((0)),
		[ForceInClass] [bit] NULL DEFAULT ((0)),
		[ForceOutClass] [bit] NULL DEFAULT ((0)),
		[DisableLastPrice] [bit] NULL DEFAULT ((0)),
		[LastPriceCurVal] [float] NULL DEFAULT ((0)),
		[PrevQty] [float] NULL DEFAULT ((0)),
		[FirstCostDate] [datetime] NULL DEFAULT ('1/1/1980'),
		[HasSegments] [bit] NULL DEFAULT ((0)),
		[Parent] [uniqueidentifier] NULL DEFAULT (0x00),
		[IsCompositionUpdated] [bit] NULL DEFAULT ((0)),
		[InheritsParentSpecs] [bit] NULL DEFAULT ((0)),
		[CompositionName] [nvarchar](250) NULL DEFAULT (''),
		[CompositionLatinName] [nvarchar](250) NULL DEFAULT (''),
		[MovedComposite] [int] DEFAULT (0)
	)
############################################################## 
CREATE PROCEDURE rep_ImportMat
	@GUID 			[UNIQUEIDENTIFIER],
	@UpdateMatCard  [INT] = 0,
	@ByOnlyCode		[INT] = 0,
	@CanDupMatName	[INT] = 0,
	@RepeatedStr	[NVARCHAR](256) = N'مكرر',
	@ReTrance		[BIT] = 0
AS 
	SET NOCOUNT ON
	ALTER TABLE [mt000] DISABLE TRIGGER trg_mt000_Assets
	IF NOT EXISTS(SELECT [NAME] FROM [SysObjects] WHERE [NAME] ='mt2')
		RETURN
	SELECT *,[Guid] AS [OldGUID1] INTO [#mt] FROM [mt2]

	CREATE TABLE #GCCNewGUIDTbl (
    [NewGUID] UNIQUEIDENTIFIER, 
    [OldGUID] UNIQUEIDENTIFIER, 
	[NewName] NVARCHAR(MAX),
	[NewLatinName] NVARCHAR(MAX),
	[NewCode] NVARCHAR(MAX))        

	IF EXISTS(SELECT [Value] from [op000] WHERE [Name] = 'AmnCfg_EnableGCCTaxSystem' AND [Value] = 1)
	BEGIN
		INSERT INTO #GCCNewGUIDTbl EXEC prcIE_IsSameMaterialTaxSettings           

		SELECT 
		[#mt].*, 
		#GCCNewGUIDTbl.OldGUID AS MatOldGUID, 
		#GCCNewGUIDTbl.NewGUID AS MatNewGUID, 
		#GCCNewGUIDTbl.[NewName] AS MatNewName,
		#GCCNewGUIDTbl.[NewLatinName] AS MatNewLatinName, 
		#GCCNewGUIDTbl.[NewCode] AS MatNewCode		 
		INTO #MatDiffTax 
		FROM [#mt] 
		INNER JOIN #GCCNewGUIDTbl ON #GCCNewGUIDTbl.OldGUID = [#mt].GUID

		DELETE mt FROM #mt AS mt INNER JOIN #MatDiffTax ON #MatDiffTax.OldGUID = mt.GUID
	END

	SELECT * INTO [#mt1] FROM [mt2]
	
	IF @CanDupMatName = 0 AND @ReTrance = 0
	BEGIN
		IF EXISTS (SELECT * FROM [#mt] INNER JOIN [mt000] AS [mt] ON ([#mt].Name = [mt].Name AND [#mt].Code != [mt].Code AND [#mt].Parent  = 0x00  AND [mt].Parent  = 0x00))
		BEGIN
			RAISERROR (N'AmnE1001', 16, 1);
			RETURN
		END
	END

	--/////////////////////////////////////////////////////////////////////////////////////////////////////////////
	SELECT Xmlmt.Name XmlName ,m_mt.Name MyName ,Xmlmt.Type XmlType ,m_mt.Type MyType INTO #mt_SameCode_DefType 
	FROM #mt AS Xmlmt INNER JOIN mt000 AS m_mt ON (m_mt.GUID = Xmlmt.GUID OR (m_mt.Code = Xmlmt.Code COLLATE ARABIC_CI_AI)) AND Xmlmt.Type <> m_mt.Type
	WHERE dbo.[fnMaterial_IsUsed]([m_mt].[GUID]) != 0

	SELECT Xmlmt.Name XmlName ,m_mt.Name MyName,((Xmlmt.Assemble*2 )| m_mt.Assemble) AF, ((Xmlmt.ClassFlag*2)| m_mt.ClassFlag ) CF, ((Xmlmt.ExpireFlag*2)| m_mt.ExpireFlag ) EF
			,((Xmlmt.SNFlag*2)| m_mt.SNFlag) SF, ((Xmlmt.HasSegments*2)| m_mt.HasSegments) HS
	INTO #mt_SameCode_DefOption 
	FROM #mt AS Xmlmt INNER JOIN mt000 AS m_mt ON (m_mt.GUID = Xmlmt.GUID OR (m_mt.Code = Xmlmt.Code COLLATE ARABIC_CI_AI)) AND
	( Xmlmt.Assemble <> m_mt.Assemble OR Xmlmt.ClassFlag <> m_mt.ClassFlag OR Xmlmt.ExpireFlag <> m_mt.ExpireFlag OR Xmlmt.SNFlag <> m_mt.SNFlag OR Xmlmt.HasSegments <> m_mt.HasSegments)
	WHERE dbo.[fnMaterial_IsUsed]([m_mt].[GUID]) != 0

	IF @UpdateMatCard > 0
	BEGIN
		DECLARE @ErrStr [NVARCHAR](100)
		DECLARE @Data   [NVARCHAR](100)
		IF EXISTS (SELECT * FROM [#mt_SameCode_DefType ] )
		BEGIN
			SET @Data = (SELECT TOP(1) (XmlName+','+ MyName+','+ CONVERT([NVARCHAR](10),XmlType)+','+ CONVERT([NVARCHAR](10), MyType)) FROM #mt_SameCode_DefType )
			SET @ErrStr = N'AmnE1012 :' + @Data
			RAISERROR (@ErrStr, 16, 1);
			RETURN
		END
		IF EXISTS (SELECT * FROM [#mt_SameCode_DefOption] )
		BEGIN
			SET @Data = (SELECT TOP(1) (XmlName+','+ MyName+',' + CONVERT([NVARCHAR](10),AF)+',' + CONVERT([NVARCHAR](10),CF)+',' + CONVERT([NVARCHAR](10),EF)
			+',' + CONVERT([NVARCHAR](10),SF)+',' + CONVERT([NVARCHAR](10),HS)  ) FROM #mt_SameCode_DefOption )
			SET @ErrStr = N'AmnE1013 :' + @Data
			RAISERROR (@ErrStr, 16, 1);
			RETURN
		END
	END
--/////////////////////////////////////////////////////////////////////////////////////////////////////

	--for same guid
	SELECT [m].*,[mt].[Code] AS [mtCode] 
	INTO [#mtG] FROM [#mt] AS [m] 
	INNER JOIN [mt000] AS [mt] ON [m].[Guid] = [mt].[Guid]
	
	IF @ByOnlyCode = 0
		DELETE [mt] FROM [#mt] AS [mt] INNER JOIN [#mtG] AS [mtg] ON [mtg].[Guid] = [mt].[Guid]
	SELECT [mt].[Guid] AS [NewGuid1],[m].* INTO [#mtc] FROM [#mt] AS [m] INNER JOIN [mt000] AS [mt] ON ([m].[Code] COLLATE ARABIC_CI_AI) = ([mt].[Code] COLLATE ARABIC_CI_AI)
	DELETE [mt] FROM [#mt] AS [mt] INNER JOIN [#mtC] AS [mtc] ON ([mtc].[Code] COLLATE ARABIC_CI_AI) = ([mt].[Code] COLLATE ARABIC_CI_AI)
	
	IF @ByOnlyCode > 0
	BEGIN
		DELETE [#mtG] WHERE [mtCode] = [Code]
		UPDATE [m] SET  [Guid] = NEWID() FROM [#mtc] AS [m] INNER JOIN [#mtG] AS [mt] ON  ([m].[Code] COLLATE ARABIC_CI_AI) = ([mt].[Code] COLLATE ARABIC_CI_AI) AND [m].[Guid] <> [mt].[Guid]
		UPDATE [m] SET  [Guid] = NEWID() FROM [#mt] AS [m] INNER JOIN [#mtG] AS [mt] ON   [m].[Guid] = [mt].[Guid]
		TRUNCATE TABLE [#mtG]
		
	END

	CREATE TABLE [#OCode]
	(
		[OldGuid1] [UNIQUEIDENTIFIER],
		[NewGuid1] [UNIQUEIDENTIFIER],
		[Type] [INT],
		[OldCode] [NVARCHAR](256) COLLATE Arabic_CI_AI ,
		[Code] [NVARCHAR](256) COLLATE Arabic_CI_AI ,
		[Name] [NVARCHAR](256) COLLATE Arabic_CI_AI,
		[ForceOutSN] [BIT], 
		[ForceInSN] [BIT]
	)
	IF @ReTrance  = 0
	BEGIN
		IF EXISTS(SELECT [Value] from [op000] WHERE [Name] = 'AmnCfg_CanDuplicateMatName' AND [Value] = 0)
		BEGIN
			UPDATE [m] SET [Name] = [m].[Name] + ' ' + @RepeatedStr  FROM [#mt] AS [m] INNER JOIN [mt000] AS [mt] ON [mt].[Name] = [m].[Name] AND [mt].Parent  = 0x00  AND [m].Parent  = 0x00
		
			IF @UpdateMatCard > 0 
			BEGIN
				UPDATE [m] SET [Name] = [m].[Name] + ' ' + @RepeatedStr  FROM [#mtG] AS [m] INNER JOIN [mt000] AS [mt] ON [mt].[Name] = [m].[Name] AND [mt].Parent  = 0x00  AND [m].Parent  = 0x00 WHERE [mt].[Guid] <> [m].[Guid]
				UPDATE [m] SET [Name] = [m].[Name] + ' ' + @RepeatedStr  FROM [#mtC] AS [m] INNER JOIN [mt000] AS [mt] ON [mt].[Name] = [m].[Name] AND [mt].Parent  = 0x00  AND [m].Parent  = 0x00 WHERE [mt].[Code] <> [m].[Code]
			
			END 
		END
		UPDATE [m] SET [Barcode] = [m].[Barcode] + ' ' + @RepeatedStr  FROM [#mt] AS [m] INNER JOIN [mt000] AS [mt] ON [mt].[Barcode] = [m].[Barcode]  WHERE [m].[Barcode] <> ''
		UPDATE [m] SET [Barcode2] = [m].[Barcode2] + ' ' + @RepeatedStr  FROM [#mt] AS [m] INNER JOIN [mt000] AS [mt] ON [mt].[Barcode2] = [m].[Barcode2] WHERE [m].[Barcode2] <> '' AND [m].[Unit2] <> ''
		UPDATE [m] SET [Barcode3] = [m].[Barcode3] + ' ' + @RepeatedStr  FROM [#mt] AS [m] INNER JOIN [mt000] AS [mt] ON [mt].[Barcode3] = [m].[Barcode3] WHERE [m].[Barcode3] <> '' AND [m].[Unit3] <> ''
		IF @UpdateMatCard > 0 
		BEGIN
			UPDATE [m] SET [Barcode] = [m].[Barcode] + ' ' + @RepeatedStr  FROM [#mtG] AS [m] INNER JOIN [mt000] AS [mt] ON [mt].[Barcode] = [m].[Barcode] WHERE [m].[Barcode] <> '' AND  [mt].[Guid] <> [m].[Guid]
			UPDATE [m] SET [Barcode] = [m].[Barcode] + ' ' + @RepeatedStr  FROM [#mtC] AS [m] INNER JOIN [mt000] AS [mt] ON [mt].[Barcode] = [m].[Barcode] WHERE [m].[Barcode] <> '' AND [mt].[Code] <> [m].[Code]
		
			UPDATE [m] SET [Barcode2] = [m].[Barcode2] + ' ' + @RepeatedStr  FROM [#mtG] AS [m] INNER JOIN [mt000] AS [mt] ON [mt].[Barcode2] = [m].[Barcode2] WHERE [m].[Barcode2] <> '' AND [m].[Unit2] <> '' AND [mt].[Guid] <> [m].[Guid]
			UPDATE [m] SET [Barcode2] = [m].[Barcode2] + ' ' + @RepeatedStr  FROM [#mtC] AS [m] INNER JOIN [mt000] AS [mt] ON [mt].[Barcode2] = [m].[Barcode2] WHERE [m].[Barcode2] <> '' AND [m].[Unit2] <> '' AND [mt].[Code] <> [m].[Code]
		
			UPDATE [m] SET [Barcode3] = [m].[Barcode3] + ' ' + @RepeatedStr  FROM [#mtG] AS [m] INNER JOIN [mt000] AS [mt] ON [mt].[Barcode3] = [m].[Barcode3] WHERE [m].[Barcode3] <> '' AND [m].[Unit3] <> '' AND  [mt].[Guid] <> [m].[Guid]
			UPDATE [m] SET [Barcode3] = [m].[Barcode3] + ' ' + @RepeatedStr  FROM [#mtC] AS [m] INNER JOIN [mt000] AS [mt] ON [mt].[Barcode3] = [m].[Barcode3] WHERE [m].[Barcode3] <> '' AND [m].[Unit3] <> '' AND [mt].[Code] <> [m].[Code]
		END
	END
	INSERT INTO [#OCode] 
			SELECT [Guid],[NewGuid1],1,[Code],[Code],[Name],[ForceOutSN],[ForceInSN] FROM [#mtc]
		UNION ALL
			SELECT [Guid],[Guid],1,[mtCode],[Code],[Name],[ForceOutSN],[ForceInSN] FROM [#mtG] 
		UNION ALL
			SELECT [OldGUID1],[Guid],0,'',[Code],[Name],[ForceOutSN],[ForceInSN] FROM [#mt] 
	DECLARE @MaxNum [INT]
	DECLARE @MaxNumComposite [INT]
	SELECT @MaxNum = ISNULL(MAX([NUMBER]),0) FROM [mt000] WHERE Parent = 0x00
	SELECT @MaxNumComposite = ISNULL(MAX([NUMBER]),0) FROM [mt000] WHERE Parent != 0x00
	CREATE INDEX mt2indGuid ON [mt2]([GUID])
	IF @UpdateMatCard = 0  
	BEGIN
		IF EXISTS(SELECT * FROM [br000])
			UPDATE [mt000] SET 
					[branchMask] = [M].[branchMask] |[MT].[branchMask]
			FROM 
				[mt000] AS [MT] INNER JOIN [#mtG] AS [M] ON [mt].[GUID] = [M].[Guid]
			UPDATE [mt000] SET 
					[branchMask] = [M].[branchMask] |[MT].[branchMask]
			FROM 
				[mt000] AS [MT] INNER JOIN [#mtc] AS [M] ON [mt].[Code] = [M].[Code]
	END
	ELSE
	BEGIN
		UPDATE [mt000] SET 
							[Code] = [M].[Code] ,[Name] = [M].[Name] ,[LatinName] = [M].[LatinName] ,[BarCode] = [M].[BarCode], [CodedCode] = [M].[CodedCode], [Unity] = [M].[Unity], [Spec]= [M].[Spec],  [High] = [M].[High], [Low] = [M].[Low], [Whole] = [M].[Whole],
							[Half] = [M].[Half], [Retail] = [M].[Retail], [EndUser] = [M].[EndUser], [Export] = [M].[Export], [Vendor] = [M].[Vendor], [MaxPrice] = [M].[MaxPrice],
							[PriceType] = [M].[PriceType],[SellType] = [M].[SellType],[BonusOne] = [M].[BonusOne],[CurrencyVal] = [M].[CurrencyVal],[UseFlag] = [M].[UseFlag],[Origin]=[M].[Origin],[Company] = [M].[Company],[Type] = [M].[Type],
							[Security] = [M].[Security],[LastPriceDate] = [M].[LastPriceDate],[Bonus] = [M].[Bonus],[Unit2] = [M].[Unit2],[Unit2Fact] = [M].[Unit2Fact],[Unit3] = [M].[Unit3],
							[Unit3Fact] = [M].[Unit3Fact],[Flag] = [M].[Flag],[Pos] = [M].[Pos],Dim = [M].[Dim],ExpireFlag = [M].[ExpireFlag],[ProductionFlag] =[M].[ProductionFlag],
							[Unit2FactFlag] = [M].[Unit2FactFlag],[Unit3FactFlag] = [M].[Unit3FactFlag],[BarCode2] = [M].[BarCode2],
							[BarCode3] = [M].[BarCode3],[SNFlag] = [M].[SNFlag],ForceInSN = [M].[ForceInSN],ForceOutSN = [M].[ForceOutSN],VAT = [M].[VAT],[Color] = [M].[Color],[Provenance] = [M].[Provenance],[Quality] = [M].[Quality],
							[Model] = [M].[Model],[Whole2] = [M].[Whole2],[Half2] = [M].[Half2],[Retail2] = [M].[Retail2],[EndUser2]=[M].[EndUser2],[Export2] = [M].[Export2],
							[Vendor2] = [M].[Vendor2],[MaxPrice2] = [M].[MaxPrice2],[LastPrice2] = [M].[LastPrice2],[Whole3] = [M].[Whole3],[Half3] = [M].[Half3],[Retail3] = [M].[Retail3],
							[EndUser3] = [M].[EndUser3],[Export3] = [M].[Export3],[Vendor3] = [M].[Vendor3],[OrderLimit] = [M].[OrderLimit],
							[GroupGUID] = [M].[GroupGUID],[PictureGUID] = [M].[PictureGUID],[CurrencyGUID] = [M].[CurrencyGUID],[DefUnit] = [M].[DefUnit],[bHide] = [M].[bHide],[branchMask] = [M].[branchMask] |[MT].[branchMask],[Assemble] =[M].[Assemble],
							[ClassFlag] = [M].[ClassFlag], [ForceInClass] = [M].[ForceInClass], [ForceOutClass] = [M].[ForceOutClass], [HasSegments] = [M].[HasSegments]
				FROM 
					[mt000] AS [MT] INNER JOIN [#mtG] AS [M] ON [mt].[GUID] = [M].[Guid]
		UPDATE [mt000] SET 
							[Name] = [M].[Name] ,[LatinName] = [M].[LatinName] ,[BarCode] = [M].[BarCode], [CodedCode] = [M].[CodedCode], [Unity] = [M].[Unity], [Spec]= [M].[Spec],  [High] = [M].[High], [Low] = [M].[Low], [Whole] = [M].[Whole],
							[Half] = [M].[Half], [Retail] = [M].[Retail], [EndUser] = [M].[EndUser], [Export] = [M].[Export], [Vendor] = [M].[Vendor], [MaxPrice] = [M].[MaxPrice],
							[PriceType] = [M].[PriceType],[SellType] = [M].[SellType],[BonusOne] = [M].[BonusOne],[CurrencyVal] = [M].[CurrencyVal],[UseFlag] = [M].[UseFlag],[Origin]=[M].[Origin],[Company] = [M].[Company],[Type] = [M].[Type],
							[Security] = [M].[Security],[LastPriceDate] = [M].[LastPriceDate],[Bonus] = [M].[Bonus],[Unit2] = [M].[Unit2],[Unit2Fact] = [M].[Unit2Fact],[Unit3] = [M].[Unit3],
							[Unit3Fact] = [M].[Unit3Fact],[Flag] = [M].[Flag],[Pos] = [M].[Pos],Dim = [M].[Dim],ExpireFlag = [M].[ExpireFlag],[ProductionFlag] =[M].[ProductionFlag],
							[Unit2FactFlag] = [M].[Unit2FactFlag],[Unit3FactFlag] = [M].[Unit3FactFlag],[BarCode2] = [M].[BarCode2],
							[BarCode3] = [M].[BarCode3],[SNFlag] = [M].[SNFlag],ForceInSN = [M].[ForceInSN],ForceOutSN = [M].[ForceOutSN],VAT = [M].[VAT],[Color] = [M].[Color],[Provenance] = [M].[Provenance],[Quality] = [M].[Quality],
							[Model] = [M].[Model],[Whole2] = [M].[Whole2],[Half2] = [M].[Half2],[Retail2] = [M].[Retail2],[EndUser2]=[M].[EndUser2],[Export2] = [M].[Export2],
							[Vendor2] = [M].[Vendor2],[MaxPrice2] = [M].[MaxPrice2],[LastPrice2] = [M].[LastPrice2],[Whole3] = [M].[Whole3],[Half3] = [M].[Half3],[Retail3] = [M].[Retail3],
							[EndUser3] = [M].[EndUser3],[Export3] = [M].[Export3],[Vendor3] = [M].[Vendor3],[OrderLimit] = [M].[OrderLimit],
							[GroupGUID] = [M].[GroupGUID],[PictureGUID] = [M].[PictureGUID],[CurrencyGUID] = [M].[CurrencyGUID],[DefUnit] = [M].[DefUnit],[bHide] = [M].[bHide],[branchMask] = [M].[branchMask] |[MT].[branchMask],[Assemble] =[M].[Assemble],
							[ClassFlag] = [M].[ClassFlag], [ForceInClass] = [M].[ForceInClass], [ForceOutClass] = [M].[ForceOutClass], [HasSegments] = [M].[HasSegments]
				FROM 
					[mt000] AS [MT] INNER JOIN [#mtc] AS [M] ON [mt].[Code] = [M].[Code]
	END

	INSERT INTO [MT000]
		(
		[Number], [Name] , [Code] , [LatinName] , [BarCode], [CodedCode], [Unity], [Spec], [High], [Low], [Whole], [Half], [Retail], [EndUser], 
		[Export], [Vendor], [LastPrice], [PriceType], [SellType], [BonusOne], [CurrencyVal], 
		[UseFlag], [Origin], [Company], [Type], [Security], [LastPriceDate], [Bonus], 
		[Unit2], [Unit2Fact], [Unit3], [Unit3Fact], [Flag], [Pos], [Dim], [ExpireFlag], [ProductionFlag], 
		[Unit2FactFlag], [Unit3FactFlag], [BarCode2] , 
		[BarCode3] , [SNFlag], [ForceInSN], [ForceOutSN], [VAT], [Color] , [Provenance], [Quality], 
		[Model], [Whole2], [Half2] , [Retail2], [EndUser2], [Export2], [Vendor2], [MaxPrice2], 
		[LastPrice2], [Whole3], [Half3] , 	[Retail3], [EndUser3], [Export3], [Vendor3], [MaxPrice3], [LastPrice3], [GUID], 
		[GroupGUID], [PictureGUID], [CurrencyGUID], [DefUnit], [bHide], [branchMask], [Assemble],[OrderLimit], [OldGUID], [NewGUID], [CalPriceFromDetail], [ForceInExpire],
		[ForceOutExpire], [CreateDate],	[IsIntegerQuantity] ,[ClassFlag], [ForceInClass], [ForceOutClass], [DisableLastPrice], [LastPriceCurVal], [PrevQty], [FirstCostDate],
		[HasSegments], [Parent], [IsCompositionUpdated], [InheritsParentSpecs], [CompositionName], [CompositionLatinName]
		) 
		SELECT  CASE mt.Parent WHEN 0x00 THEN [mt].[Number]+@MaxNum ELSE [mt].[Number]+@MaxNumComposite END,[mt].[Name] ,[mt].[Code] ,[mt].[LatinName] ,[mt].[BarCode],[mt].[CodedCode],[mt].[Unity],[mt].[Spec],[mt].[High],[mt].[Low],[mt].[Whole],[mt].[Half],[mt].[Retail],[mt].[EndUser],
				[mt].[Export],[mt].[Vendor],[mt].[LastPrice],[mt].[PriceType],[mt].[SellType],[mt].[BonusOne],[mt].[CurrencyVal],
				[mt].[UseFlag],[mt].[Origin],[mt].[Company],[mt].[Type],[mt].[Security],[mt].[LastPriceDate],[mt].[Bonus],
				[mt].[Unit2],[mt].[Unit2Fact],[mt].[Unit3],[mt].[Unit3Fact],[mt].[Flag],[mt].[Pos],[mt].[Dim],[mt].[ExpireFlag],[mt].[ProductionFlag],
				[mt].[Unit2FactFlag],[mt].[Unit3FactFlag],[mt].[BarCode2] ,
				[mt].[BarCode3] ,[mt].[SNFlag],[mt].[ForceInSN],[mt].[ForceOutSN],[mt].[VAT],[mt].[Color] ,[mt].[Provenance],[mt].[Quality],
				[mt].[Model],[mt].[Whole2],[mt].[Half2] ,[mt].[Retail2],[mt].[EndUser2],[mt].[Export2],[mt].[Vendor2],[mt].[MaxPrice2],
				[mt].[LastPrice2],[mt].[Whole3],[mt].[Half3] ,[mt].[Retail3],[mt].[EndUser3],[mt].[Export3],[mt].[Vendor3],[mt].[MaxPrice3],[mt].[LastPrice3],[mt].[GUID],
				[mt].[GroupGUID],[mt].[PictureGUID],[mt].[CurrencyGUID],[mt].[DefUnit],[mt].[bHide],[mt].[branchMask],[mt].[Assemble],[mt].[OrderLimit],
				[mt].[OldGUID1], [mt].[NewGUID], [mt].[CalPriceFromDetail], [mt].[ForceInExpire], [mt].[ForceOutExpire], [mt].[CreateDate], [mt].[IsIntegerQuantity], 
				[mt].[ClassFlag], [mt].[ForceInClass], [mt].[ForceOutClass], [mt].[DisableLastPrice], [mt].[LastPriceCurVal], [mt].[PrevQty], [mt].[FirstCostDate], 
				[mt].[HasSegments], 
				CASE 
				WHEN [mt].[Parent] IS NOT NULL THEN
					CASE
					WHEN [mt2].[GUID] IS NOT NULL THEN
						[mt2].[GUID]
					ELSE
						[mt].[Parent]
					END
				ELSE
					[mt].[Parent]
				END
				, [mt].[IsCompositionUpdated], [mt].[InheritsParentSpecs], [mt].[CompositionName], [mt].[CompositionLatinName]
		FROM [#MT] AS [mt] 
		LEFT JOIN [#MT1] AS [mt1] ON mt1.GUID = mt.Parent
		LEFT JOIN [mt000] AS [mt2] ON (([mt2].GUID = [mt1].GUID AND [mt2].HasSegments = 1 AND [mt1].HasSegments = 1) OR (([mt2].GUID != [mt1].GUID) AND ([mt2].Code = [mt1].Code COLLATE SQL_Latin1_General_CP1_CS_AS) AND ([mt2].HasSegments = 1 AND [mt1].HasSegments = 1)))
	IF @ReTrance = 0
	BEGIN
		SELECT [OldGuid1] AS [OGuid],[NewGuid1] AS [NGuid],[Type] AS [UPDATED],[Code],[Name],[OldCode],[ForceOutSN],[ForceInSN]  FROM [#OCode]
	END

	IF EXISTS(SELECT [Value] from [op000] WHERE [Name] = 'AmnCfg_EnableGCCTaxSystem' AND [Value] = 1)
		BEGIN
			IF (@ReTrance = 0)
				BEGIN
					SELECT * INTO [#GCCMaterialTax] FROM [GCCMaterialTax2]	

					INSERT INTO [GCCMaterialTax000]
						([GUID]
						,[TaxType]
						,[TaxCode]
						,[Ratio]
						,[MatGUID]
						,[ProfitMargin])	
					SELECT 
						NEWID()
						,[TaxType]
						,[TaxCode]
						,[Ratio]
						,[mt].GUID
						,[ProfitMargin]
					FROM [#GCCMaterialTax] AS gmt
					INNER JOIN [#MT] AS [mt] ON [mt].[OldGUID1] = gmt.[MatGUID]

					INSERT INTO [MT000]
						(
						[Number], [Name] , [Code] , [LatinName] , [BarCode], [CodedCode], [Unity], [Spec], [High], [Low], [Whole], [Half], [Retail], [EndUser], 
						[Export], [Vendor], [LastPrice], [PriceType], [SellType], [BonusOne], [CurrencyVal], 
						[UseFlag], [Origin], [Company], [Type], [Security], [LastPriceDate], [Bonus], 
						[Unit2], [Unit2Fact], [Unit3], [Unit3Fact], [Flag], [Pos], [Dim], [ExpireFlag], [ProductionFlag], 
						[Unit2FactFlag], [Unit3FactFlag], [BarCode2] , 
						[BarCode3] , [SNFlag], [ForceInSN], [ForceOutSN], [VAT], [Color] , [Provenance], [Quality], 
						[Model], [Whole2], [Half2] , [Retail2], [EndUser2], [Export2], [Vendor2], [MaxPrice2], 
						[LastPrice2], [Whole3], [Half3] , 	[Retail3], [EndUser3], [Export3], [Vendor3], [MaxPrice3], [LastPrice3], [GUID], 
						[GroupGUID], [PictureGUID], [CurrencyGUID], [DefUnit], [bHide], [branchMask], [Assemble],[OrderLimit]
						) 
						SELECT [mt].[Number]+@MaxNum,[mt].[MatNewName] ,[mt].MatNewCode ,[mt].MatNewLatinName ,[mt].[BarCode],[mt].[CodedCode],[mt].[Unity],[mt].[Spec],[mt].[High],[mt].[Low],[mt].[Whole],[mt].[Half],[mt].[Retail],[mt].[EndUser],
								[mt].[Export],[mt].[Vendor],[mt].[LastPrice],[mt].[PriceType],[mt].[SellType],[mt].[BonusOne],[mt].[CurrencyVal],
								[mt].[UseFlag],[mt].[Origin],[mt].[Company],[mt].[Type],[mt].[Security],[mt].[LastPriceDate],[mt].[Bonus],
								[mt].[Unit2],[mt].[Unit2Fact],[mt].[Unit3],[mt].[Unit3Fact],[mt].[Flag],[mt].[Pos],[mt].[Dim],[mt].[ExpireFlag],[mt].[ProductionFlag],
								[mt].[Unit2FactFlag],[mt].[Unit3FactFlag],[mt].[BarCode2] ,
								[mt].[BarCode3] ,[mt].[SNFlag],[mt].[ForceInSN],[mt].[ForceOutSN],[mt].[VAT],[mt].[Color] ,[mt].[Provenance],[mt].[Quality],
								[mt].[Model],[mt].[Whole2],[mt].[Half2] ,[mt].[Retail2],[mt].[EndUser2],[mt].[Export2],[mt].[Vendor2],[mt].[MaxPrice2],
								[mt].[LastPrice2],[mt].[Whole3],[mt].[Half3] ,[mt].[Retail3],[mt].[EndUser3],[mt].[Export3],[mt].[Vendor3],[mt].[MaxPrice3],[mt].[LastPrice3],[mt].[MatNewGUID],
								[mt].[GroupGUID],[mt].[PictureGUID],[mt].[CurrencyGUID],[mt].[DefUnit],[mt].[bHide],[mt].[branchMask],[mt].[Assemble],[mt].[OrderLimit]
						FROM [#MatDiffTax] AS [mt] 
					
					INSERT INTO [GCCMaterialTax000]
						([GUID]
						,[TaxType]
						,[TaxCode]
						,[Ratio]
						,[MatGUID]
						,[ProfitMargin])	
					SELECT 
						NEWID()
						,[TaxType]
						,[TaxCode]
						,[Ratio]
						,[mt].MatNewGUID
						,[ProfitMargin]
					FROM [#GCCMaterialTax] AS gmt
					INNER JOIN [#MatDiffTax] AS [mt] ON [mt].MatOldGUID = gmt.[MatGUID]

					INSERT INTO [#OCode]
					(
						[OldGuid1],
						[NewGuid1],
						[Type],
						[OldCode],
						[Code],
						[Name],
						[ForceOutSN], 
						[ForceInSN]
					)
					SELECT
						MatOldGUID,
						MatNewGUID,
						[Type],
						[Code],
						[Code],
						[Name],
						[ForceOutSN], 
						[ForceInSN]
					FROM [#MatDiffTax]
				END
		END
	-- SELECT [OldGuid1] AS [OGuid],[NewGuid1] AS [NGuid],[Type] AS [UPDATED],[Code],[Name],[OldCode],[ForceOutSN],[ForceInSN]  FROM [#OCode]
	ALTER TABLE [mt000] ENABLE TRIGGER trg_mt000_Assets
	IF EXISTS(SELECT * FROM  [mt2] WHERE [Type] = 2)
	BEGIN
		
		UPDATE [mt2] SET [Guid] = [mt].[Guid]  FROM [mt2] AS [m] INNER JOIN [#mtc] AS [mt] ON [mt].[Code] = [M].[Code] 
	END 
############################################################## 
CREATE PROCEDURE repImpPostGenBill
	@Post	[INT],
	@GenEntry [INT]
AS
	IF NOT EXISTS(SELECT * FROM [dbo].[sysobjects] WHERE [NAME] = 'impBill2')
		RETURN 
	DECLARE @c CURSOR
	DECLARE @buGuid [UNIQUEIDENTIFIER],@btAutoEntry [INT],@btAutoPost [INT]
	SELECT [im].[GUID],[btAutoEntry],[bt].[bAutoPost] 
	INTO #bu
	FROM [impBill2] AS [im] 
				INNER JOIN [vwBu] AS [bu] ON [bu].[buGuid] = [im].[GUID] 
				INNER JOIN [bt000] AS [bt] ON [bu].[buType] = [bt].[GUID]
		ORDER BY [buDate],[buSortFlag],[buNumber]
	SET @c = CURSOR FAST_FORWARD FOR 
		 SELECT * FROM #bu
	
	OPEN @c 	
	FETCH  FROM @c  INTO @buGuid,@btAutoEntry,@btAutoPost
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @Post = 1 AND @btAutoPost = 1
		BEGIN
			UPDATE [bu000] SET [ISPOSTED] =1 WHERE GUID = @buGuid 
			--EXEC [prcBill_post] @buGuid,0
		END
		IF @GenEntry =1 and @btAutoEntry = 1
			exec [prcBill_genEntry] @buGuid 
		FETCH  FROM @c  INTO @buGuid,@btAutoEntry,@btAutoPost

	END
	CLOSE @c
	DEALLOCATE @c
	/*ALTER TABLE bu000 DISABLE TRIGGER trg_bu000_post
	IF @Post = 1 
		UPDATE bu SET ISPOSTED = 1 FROM [bu000] [bu] INNER JOIN  #bu B ON B.Guid = bu.Guid WHERE b.[bAutoPost] = 1
	ALTER TABLE bu000 ENABLE TRIGGER trg_bu000_post*/
	DROP TABLE [dbo].[impBill2]
############################################################## 
CREATE PROCEDURE prcupDateGlnCustGuid
AS 
	SET NOCOUNT ON
	SELECT [newGuid],[Guid]
	INTO #cst
	FROM dbo.TEMPGLN a INNER JOIN [cu000] b ON a.[BarCode] = b.[BarCode] WHERE b.Guid <> [newGuid] AND a.[BarCode] <> ''
	IF @@ROWCOUNT = 0
		GOTO ENDP
		EXEC prcDisableTriggers  'cu000'
	
	
	UPDATE cu SET [Guid] = [newGuid] FROM [cu000] cu INNER JOIN #cst a ON [cu].[Guid] = a.[Guid] 
	ALTER TABLE [cu000] ENABLE TRIGGER ALL	
	DECLARE @Sql NVARCHAR(1000),@col NVARCHAR(100),@tbl NVARCHAR(100),@c CURSOR
	SET @c = CURSOR FAST_FORWARD FOR  
		SELECT a.name,b.name FROM syscolumns a 
		INNER JOIN sysobjects b ON b.id = a.id
		WHERE a.name LIKE '%cust%' AND a.name NOT like '%acc%' AND b.xtype = 'U' and a.xtype = 36
	OPEN @c FETCH FROM @c INTO  @col,@tbl
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		SET @Sql = 'ALTER TABLE ' + @tbl + ' DISABLE TRIGGER ALL ' + CHAR(13)
		SET @Sql = @Sql + 'UPDATE a SET ' + @col + '=[newGuid]  FROM ' + @tbl + ' a INNER JOIN #cst b ON b.Guid = a.' + @col + CHAR(13)
		SET @Sql = @Sql + 'ALTER TABLE ' + @tbl + ' ENABLE TRIGGER ALL ' + CHAR(13)
		EXEC(@Sql)
		FETCH FROM @c INTO  @col,@tbl
	END
	CLOSE @c DEALLOCATE @c
	ENDP:
	SET @Sql = 'SELECT [ID] FROM dbo.TEMPGLN a INNER JOIN [cu000] b ON  b.Guid = [newGuid]'
	EXEC(@Sql)
	DROP TABLE dbo.TEMPGLN
#################################################################
#END     