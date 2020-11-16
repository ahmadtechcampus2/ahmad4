###################################
CREATE PROCEDURE prcUpdateMatAcc
	@SN [BIT] = 0,
	@Term [BIT] = 0,
	@Flag [BIGINT] = 0
AS
	SET NOCOUNT ON
		
	CREATE TABLE [#GR]([objGuid]  [UNIQUEIDENTIFIER])
	CREATE TABLE [#ma]([Guid] [UNIQUEIDENTIFIER],[GroupGuid] [UNIQUEIDENTIFIER])
	INSERT INTO [#GR] SELECT DISTINCT [objGuid]  FROM [ma000] AS [ma]   
	INNER JOIN [IMPMAT2] AS [im] ON [im].[Guid] = [ma].[objGuid] 
	WHERE TYPE = 2 
	INSERT INTO [#ma] SELECT [mt].[Guid],[mt].[GroupGuid]  
					FROM [mt000] AS [mt] 
					INNER JOIN [#Gr] AS [gr] ON [gr].[objGuid] = [mt].[GroupGuid]
					INNER JOIN [IMPMAT2] AS [im] ON [mt].[Guid] = [im].[Guid] 
	CREATE CLUSTERED INDEX [impmind] ON [#ma]([Guid])
	DELETE [ma000] 
	FROM [ma000] AS [ma] INNER JOIN [IMPMAT2] AS [m] ON  [ma].[objGuid] = [m].[Guid]
	WHERE [ma].[Type] = 1
	
	INSERT INTO [ma000] SELECT DISTINCT 1,[m].[Guid],[BillTypeGUID],[MatAccGUID],[DiscAccGUID],[ExtraAccGUID],[VATAccGUID] ,[StoreAccGUID],[CostAccGUID],newid(),[BonusAccGUID],[BonusContraAccGUID],[CashAccGUID]
           	FROM [#ma] AS [m] INNER JOIN [ma000] AS [ma] ON [ma].[objGuid] = [m].[GroupGuid] 
	UPDATE [mt] SET [DefUnit] = 1 FROM [mt000] AS [mt] INNER JOIN [IMPMAT2] AS [im] ON [im].[Guid] = [mt].[Guid]
	WHERE ([mt].[DefUnit] = 2 AND [Unit2Fact] = 0) OR ([mt].[DefUnit] = 3 AND [Unit3Fact] = 0)
	UPDATE [mt] SET [Unit3FactFlag] = 1,[Unit3Fact] = 0 FROM [mt000] AS [mt] INNER JOIN [IMPMAT2] AS [im] ON [im].[Guid] = [mt].[Guid]
	WHERE ([mt].[Unit3] <> '' AND [Unit3Fact] <> 0 AND [Unit2FactFlag] = 1)
	ALTER TABLE [mt000] ENABLE TRIGGER trg_mt000_Assets,trg_mt000_CheckBalance
	IF @SN > 0
		UPDATE [mt] SET [ForceInSN] = 0,[ForceOutSN] = 0 FROM [mt000] AS [mt] INNER JOIN [IMPMAT2] AS [im] ON [im].[Guid] = [mt].[Guid]
		WHERE [mt].[SNFlag] = 0 
	IF @Term > 0
	BEGIN
		
		UPDATE [mt] SET [High] = [Low] FROM [mt000] AS [mt] INNER JOIN [IMPMAT2] AS [im] ON [im].[Guid] = [mt].[Guid]
		WHERE [High] < [Low]
		UPDATE [mt] SET [OrderLimit] = [High] FROM [mt000] AS [mt] INNER JOIN [IMPMAT2] AS [im] ON [im].[Guid] = [mt].[Guid]
		WHERE [High] < [OrderLimit] AND [OrderLimit] > 0
		UPDATE [mt] SET [OrderLimit] = [Low] FROM [mt000] AS [mt] INNER JOIN [IMPMAT2] AS [im] ON [im].[Guid] = [mt].[Guid]
		WHERE [Low] > [OrderLimit] AND [OrderLimit] > 0
	END 
	IF @Flag & 0x00000100 > 0
		UPDATE [mt] SET [Unit2] = '' FROM [mt000] AS [mt] INNER JOIN [IMPMAT2] AS [im] ON [im].[Guid] = [mt].[Guid]
		WHERE [Unit2Fact] = 0 AND [Unit2FactFlag] = 0 
	IF @Flag & 0x00000400 > 0
		UPDATE [mt] SET [Unit3] = '' FROM [mt000] AS [mt] INNER JOIN [IMPMAT2] AS [im] ON [im].[Guid] = [mt].[Guid]
		WHERE [Unit3Fact] = 0 AND [Unit3FactFlag] = 0 
	DROP TABLE [dbo].[IMPMAT2]
###################################
CREATE PROCEDURE repImpMatState
	@CantRepeateMatName [BIT] = 0,
	@UniquBarcode [BIT] = 1
AS
	SET NOCOUNT ON
	CREATE TABLE [#MatState]([Id] [INT],[Guid] [UNIQUEIDENTIFIER],[Flag] [INT],[Code] [NVARCHAR](256) COLLATE ARABIC_CI_AI)
	CREATE INDEX [CodeMatCrdImp] ON [dbo].[MatCrdImp]([Code])
	CREATE INDEX [BarCodeMatCrdImp] ON [dbo].[MatCrdImp]([BarCode])
	IF @CantRepeateMatName = 0
		CREATE INDEX [NameMatCrdImp] ON [dbo].[MatCrdImp]([Name])
	INSERT INTO [#MatState] SELECT [m].[Id],[mt].[Guid],0,'' FROM [dbo].[MatCrdImp] AS [m] INNER JOIN [dbo].[mt000] AS [mt] ON [mt].[Code] = [m].[Code]
	IF EXISTS (SELECT [CODE]  FROM [dbo].[MatCrdImp]  GROUP BY [CODE] HAVING COUNT(*) > 1)
		INSERT INTO [#MatState] SELECT [m].[Id],0X00,3,[m].[Code] FROM [dbo].[MatCrdImp] AS [m] INNER JOIN [dbo].[MatCrdImp] AS [mt] ON [mt].[Code] = [m].[Code] WHERE  [mt].[Id] <> [m].[Id]
	IF @UniquBarcode = 1 AND EXISTS (SELECT * FROM [MatCrdImp] WHERE [BarCode] <> '')
	BEGIN
		INSERT INTO [#MatState] SELECT [m].[Id],[mt].[Guid],2,'' FROM [dbo].[MatCrdImp] AS [m] INNER JOIN [dbo].[mt000] AS [mt] ON  [mt].[BarCode] = [m].[BarCode] WHERE [mt].[Code] <> [m].[Code] AND [m].[BarCode] <> ''
		INSERT INTO [#MatState] SELECT [m].[Id],0X00,2,'' FROM [dbo].[MatCrdImp] AS [m] INNER JOIN [dbo].[MatCrdImp] AS [mt] ON [mt].[BarCode] = [m].[BarCode] WHERE  [mt].[Id] <> [m].[Id] AND [m].[BarCode] <> ''
	END
	IF @CantRepeateMatName = 0  
	BEGIN
		INSERT INTO [#MatState] SELECT [m].[Id],[mt].[Guid],1,'' FROM [dbo].[MatCrdImp] AS [m] INNER JOIN [dbo].[mt000] AS [mt] ON  [mt].[Name] = [m].[Name] WHERE  [mt].[Code] <> [m].[Code]
		SELECT [m].[Id],[mt].[Name] INTO #I FROM [dbo].[MatCrdImp] AS [m] INNER JOIN [dbo].[MatCrdImp] AS [mt] ON [mt].[Name] = [m].[Name] WHERE  [mt].[Id] <> [m].[Id]
		DELETE I FROM #I I INNER JOIN (SELECT MIN(ID) ID FROM  #I GROUP BY [Name]) A  ON I.ID = A.ID
		INSERT INTO [#MatState] SELECT [Id],0X00,1,'' FROM #I
	END
	SELECT * FROM [#MatState] ORDER BY [Flag],[Code],[id]
	DROP TABLE [dbo].[MatCrdImp]
###################################
CREATE PROCEDURE prcProcessAssets
	@Update [INT]
AS
	SET NOCOUNT ON
	
	IF @Update = 1
		UPDATE [ass2]
		SET
			[CalcType] = [as].[CalcType],
			[LifeExp] = [as].[LifeExp],
			[AccGUID] = [as].[AccGUID],
			[DepAccGUID] = [as].[DepAccGUID],
			[AccuDepAccGUID] = [as].[AccuDepAccGUID],
			[Spec] = [as].[Spec],
			[Notes] = [as].[Notes],
			[ExpensesAccGUID] = [as].[ExpensesAccGUID],
			[RevaluationAccGUID] = [as].[RevaluationAccGUID],
			[CapitalProfitAccGUID] = [as].[CapitalProfitAccGUID],
			[CapitalLossAccGUID] = [as].[CapitalLossAccGUID],
			[CurrencyGUID] = [mt].[CurrencyGUID],
			[CurrencyVal] = [mt].[CurrencyVal]
				
		FROM [as000] AS [ass2] 
		INNER JOIN [ass] AS [as] ON [as].[ParentGUID] = [ass2].[ParentGUID]
		INNER JOIN [mt000] AS [mt] ON [mt].[GUID] = [as].[ParentGUID]
	INSERT INTO [as000] ([GUID],[Number],[Code],[Name],[LatinName],[ParentGUID],[CurrencyGUID],[CurrencyVal],[CalcType],[LifeExp],[AccGUID],[DepAccGUID],[AccuDepAccGUID],[Spec],[Notes],[Security],[ExpensesAccGUID],[RevaluationAccGUID],[CapitalProfitAccGUID],[CapitalLossAccGUID])
		SELECT NEWID(),
			ISNULL((SELECT Max(Number) from as000),0)+ 1,[mt].[Code],[mt].[Name],[mt].[LatinName],[as].[ParentGUID],[mt].[CurrencyGUID],[mt].[CurrencyVal],[as].[CalcType],[as].[LifeExp],[as].[AccGUID],[as].[DepAccGUID],[as].[AccuDepAccGUID],[as].[Spec],[as].[Notes],[mt].[Security],[as].[ExpensesAccGUID],[RevaluationAccGUID],[CapitalProfitAccGUID],[CapitalLossAccGUID] 
		FROM [ass] AS [as]  INNER JOIN [mt000] AS [mt] ON [mt].[Guid]  = [as].[ParentGUID]
		WHERE [as].[ParentGUID] NOT IN (SELECT [ParentGUID] FROM AS000)
	DROP TABLE [dbo].[ass]	
###################################
#END
