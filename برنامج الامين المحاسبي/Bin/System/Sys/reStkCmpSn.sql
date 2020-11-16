##########################################################################
CREATE PROCEDURE reStkCmpSn
		@SN				[NVARCHAR](256),
		@MatGUID		[UNIQUEIDENTIFIER] ,  
		@GroupGUID		[UNIQUEIDENTIFIER] ,  
		@StoreGUID		[UNIQUEIDENTIFIER] ,
		@CostGuid		[UNIQUEIDENTIFIER] ,  
		@CurrGuid		[UNIQUEIDENTIFIER] , 
		@StartDate		[DateTime] ,  
		@EndDate		[DateTime] ,
		@ShowEmptySN	[BIT],
		@IncludeSupSt	[BIT],
		@Price			[INT],
		@Sort			[INT],
		@Lang			[BIT] = 0
AS
	SET NOCOUNT ON
	DECLARE @UserGuid	[UNIQUEIDENTIFIER],@Row	[INT]
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	
	CREATE TABLE [#Store]( [Number] [UNIQUEIDENTIFIER] , [Security] [INT]) 
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#Mat] ( [mtNumber] [UNIQUEIDENTIFIER] , [mtSecurity] [INT])    
	INSERT INTO [#Mat] EXEC [prcGetMatsList]  @MatGuid, @GroupGuid 
	--Filling temporary tables 
	IF @IncludeSupSt = 0 AND @StoreGUID!=0X0 
		INSERT INTO [#Store] VALUES(@StoreGUID,0) 
	ELSE  
		INSERT INTO [#Store] EXEC [prcGetStoresList] @StoreGuid 
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID 
	CREATE TABLE [#bu]
	(
		[id]	[INT] IDENTITY(1,1),
		[biGuid] [UNIQUEIDENTIFIER],
		[Price]		[Float],
		[MtSecurity] [INT],
		[buDirection] [INT]
		
	)
	CREATE TABLE [#SN]
	(
		[SNId]		[INT] IDENTITY(1,1),
		[id]		[INT] ,
		[SN]		[NVARCHAR](1000)  COLLATE ARABIC_CI_AI, 
		[MatGuid]	[UNIQUEIDENTIFIER],
		[Cnt]		[INT],	
		[lenght]		[INT],	
		--[Price]	
	)
	IF @CostGuid = 0X00
		INSERT INTO [#CostTbl] VALUES(0X00,0)
	INSERT INTO [#bu]([biGuid],[Price],[MtSecurity],[buDirection])
		SELECT 
			[biGuid],
			CASE [buDirection]  WHEN -1 THEN 0
			ELSE CASE [buTotal] WHEN 0 THEN 0 ELSE ([biPrice] + [biExtra] - [biDiscount] +((([buTotalExtra]- [buItemsExtra]) - ([buTotalDisc] - [buItemsDisc])) * [biPrice] * [biQty] / [buTotal]))* [FixedCurrencyFactor] END
			END,[mt].[mtSecurity],[buDirection] 
		FROM [dbo].[fn_bubi_Fixed](@CurrGuid) AS [f] 
			INNER JOIN [#Mat] [mt] ON [mtNumber] = [biMatPtr]
			INNER JOIN [#Store] [st] ON [st].[Number] = [biStorePtr]
			INNER JOIN [#CostTbl] [co] ON [CostGUID] = [biCostPtr]
		WHERE [buDate] BETWEEN @StartDate AND @EndDate AND [buIsPosted] > 0
		ORDER BY [biMatPtr],[buDate],[buSortFlag],[buNumber]
		SET @UserGuid = dbo.fnGetCurrentUserGUID()
	CREATE CLUSTERED INDEX snbuIndex ON  [#bu]([ID])
	IF  EXISTS(SELECT * FROM [US000] WHERE [Guid] = @UserGuid AND bAdmin = 0)
	BEGIN
		DELETE [#bu] WHERE [MtSecurity]  > dbo.fnGetUserMaterialSec_Balance(@UserGuid) OR [MtSecurity]  >  dbo.fnGetUserMaterialSec_Browse(@UserGuid)
		SET @Row = @@ROWCOUNT
		IF (@Row > 0)
			INSERT INTO [#SecViol] VALUES(6,@Row)
	END 
	INSERT INTO [#SN] ([id],[SN],[MatGuid],[Cnt],[lenght]) SELECT MAX([Id]),[SN],[MatGuid],SUM([buDirection]),LEN([SN]) FROM [vcSNS] AS [SN] INNER JOIN [#bu] [b] ON [SN].[biGuid] = [b].[biGuid] WHERE @SN = '' OR [SN].[SN] = @SN GROUP BY [SN],[MatGuid]  HAVING SUM([buDirection])<> 0 ORDER BY SN
	SELECT [MatGuid], [SN],[Cnt],[bu].[id],[SNid],
			CASE @Lang WHEN 0 THEN [mt].[Name] ELSE CASE [mt].[LatinName]  WHEN '' THEN [mt].[Name] ELSE [mt].[LatinName] END END AS [mtName],
			CASE @Lang WHEN 0 THEN [mt].[CompositionName] ELSE CASE [mt].[CompositionLatinName]  WHEN '' THEN [mt].[CompositionName] ELSE [mt].[CompositionLatinName] END END AS [MtCompositionName],
			[mt].[Code] AS [mtCode],ISNULL([Price],0) AS [Price],[BarCode],[Color],[Provenance],[Quality],[Model],[Pos],[Dim],[mt].[VAT],[Spec],[Origin],[Company],
			CASE @Lang WHEN 0 THEN [gr].[Name] ELSE CASE [gr].[LatinName]  WHEN '' THEN [gr].[Name] ELSE [gr].[LatinName] END END AS [grName],[gr].[Code] AS [grCode],[mt].[Type],[Unity],[lenght]
	INTO [#Final]
	FROM		
		[#SN]  AS [SN]
		INNER JOIN [mt000] AS [mt] ON [mt].[Guid] = [MatGuid] 
		INNER JOIN [gr000] AS [gr] ON [gr].[Guid] = [mt].[GroupGuid]
		INNER JOIN [#bu] AS [bu] ON [bu].[Id] = [Sn].[Id]
	ORDER BY [bu].[id], [lenght],[SNid]
	IF @Price >0 AND @Price <> 15
		UPDATE [f] SET [Price] = [mtPrice]
		FROM [#Final] AS [f] INNER JOIN 
			[dbo].[fnGetMtPricesWithSec]( @Price , 121 , 0, @CurrGuid, @EndDate) [mt] ON [mt].[mtGUID] = [f].[MatGuid]
	DECLARE @Sql NVARCHAR(MAX)
	CREATE CLUSTERED INDEX finalind ON [#Final]([id], [lenght],[SNid])
	SET @Sql = 'SELECT * FROM 
		[#Final]
	ORDER BY'
	IF  @Sort = 0
		SET @Sql = @Sql +' [mtCode]'
	ELSE IF  @Sort = 1
		SET @Sql = @Sql +' [mtName]'
	ELSE IF  @Sort = 2
		SET @Sql = @Sql +' CAST([type] AS NVARCHAR(2))'
	ELSE IF  @Sort = 3
		SET @Sql = @Sql +' [Spec]'
	ELSE IF  @Sort = 4
		SET @Sql = @Sql +' [Color]'
	ELSE IF  @Sort = 5
		SET @Sql = @Sql +'  [Origin]'
	ELSE IF  @Sort = 6
		SET @Sql = @Sql +'  [Provenance]'
	ELSE IF  @Sort = 7
		SET @Sql = @Sql +'  [Pos]'
	ELSE IF  @Sort = 8
		SET @Sql = @Sql +'  [Quality]'
	ELSE IF  @Sort = 8
		SET @Sql = @Sql +' [Model]'
	ELSE IF  @Sort = 8
		SET @Sql = @Sql +' [Dim]'
	ELSE IF  @Sort = 8
		SET @Sql = @Sql +' [Company]'
	SET @Sql = @Sql +',[id]'
	IF @Price = 15
		SET @Sql = @Sql +',[Price]'
	SET @Sql = @Sql +',[lenght],[SNid]'
	EXEC (@Sql)
	SELECT * FROM #SecViol
/*
	PRCcONNECTIONS_ADD2'„œÌ—'
	EXEC  [reStkCmpSn] '', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '04b7552d-3d32-47db-b041-50119e80dd52', '1/1/2004', '4/5/2007', 0, 0, 1238900, 0, 0
*/
###############################################################################
#END