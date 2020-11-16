################################## 
CREATE PROC prcGetSNInfo
	@IdTbl	UNIQUEIDENTIFIER, 
	@MatGuid UNIQUEIDENTIFIER,
	@stGuid UNIQUEIDENTIFIER,
	@Date DATETIME,
	@Dir INT 
AS 
	SET NOCOUNT ON
	CREATE TABLE #cSN (Number INT, [sn] NVARCHAR(255), [Guid] UNIQUEIDENTIFIER)
	
	INSERT INTO #cSN SELECT S.Number,S.[sn],  
		n.Guid
	FROM [SNc000] AS [N]  
	INNER JOIN InsertedSn AS S ON N.SN = S.SN   
	WHERE S.IdTbl = @IdTbl AND N.MatGuid = @MatGuid 
	DECLARE @UserGuid  [UNIQUEIDENTIFIER],@buDate [DateTime],@StName NVARCHAR(256)
	SELECT @StName = [NAME] FROM [vcSt] WHERE [Guid] = @stGuid
	CREATE TABLE #cbILL
	(
		[ID] INT IDENTITY(1,1),
		[SN] [NVARCHAR](100) COLLATE ARABIC_CI_AI,
		[btGuid]	UNIQUEIDENTIFIER,
		[btAbbrev] NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[btLatinAbbrev] NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[buNumber] 	FLOAT,
		[Price]		FLOAT,
		[Security]	[INT]
	)
	INSERT INTO #cbILL ([SN] ,[btGuid],[btAbbrev],[btLatinAbbrev],[buNumber],[Price],[Security])
	SELECT [SN] ,[buType],[btAbbrev],[btLatinAbbrev],[buNumber],[biPrice],[buSecurity] 
	FROM [SNT000] [t] INNER JOIN #cSN [csn] ON [csn].[Guid] = [t].[ParentGuid]
	INNER JOIN [vwBubi] AS [b] ON [t].[biGuid] = b.[biGuid]
	WHERE [buDirection] = @Dir AND (@stGuid= 0X00 AND [stGuid] = @stGuid)
	AND ((@Dir = 1 AND b.[buDate] >= @Date ) OR (@Dir = -1 AND b.[buDate] <= @Date ))
	ORDER BY csn.Number,b.[buDate],[buSortFlag],[buNumber]
	SET @UserGuid =  dbo.fnGetCurrentUserGUID()
	CREATE TABLE #MAX
	(
		[id] INT	
	)
	IF @Dir = -1
		INSERT INTO #MAX SELECT MAX(ID)  FROM #cbILL GROUP BY [SN]
	ELSE 
		INSERT INTO #MAX SELECT MIN(ID)  FROM #cbILL GROUP BY [SN]
	SELECT [SN],[btGuid] AS [buGuid],[btAbbrev], [btLatinAbbrev],[buNumber],[Price],case when [dbo].[fnGetUserBillSec_ReadPrice](@UserGUID , [btGuid]) < [Security]  then 1 else 0 end AS app,@StName AS stName
	FROM #MAX m INNER JOIN #cbILL s ON [s].[ID] = [m].[ID]
	
	WHERE [Security] <= dbo.fnGetUserBillSec_Browse(@UserGuid,[btGuid])
	SELECT [SN] FROM #cSN [c] INNER JOIN [snt000] [snt] ON [c].[Guid] = [snt].[ParentGuid] 
	INNER JOIN [vwbu] B ON [snt].[buGuid] = [b].[buGuid] 
	WHERE @stGuid= 0X00 AND [stGuid] = @stGuid
	GROUP BY [SN] HAVING SUM([buDirection]) <> CASE @Dir WHEN 1 THEN 0 ELSE 1 END
################################## 
CREATE PROC prcCheckSN 
	@Mend [BIT]
AS
	CREATE TABLE #SNT([Guid] [UNIQUEIDENTIFIER], [sntbuGuid] [UNIQUEIDENTIFIER],
						[buGuid] [UNIQUEIDENTIFIER],[stGuid] [UNIQUEIDENTIFIER] ,[biStorePtr] [UNIQUEIDENTIFIER])
	CREATE TABLE #scn([Guid] [UNIQUEIDENTIFIER], sn NVARCHAR(255), matGuid [UNIQUEIDENTIFIER], Qty FLOAT)
	
	INSERT INTO #SNT SELECT [snt].[Guid],[snt].[buGuid] AS [sntbuGuid],[bi].[buGuid],[stGuid],[biStorePtr]
	FROM [snt000] [snt] INNER JOIN [vwbubi] [bi] ON [bi].[biGuid] = [snt].[biGuid]
	WHERE  [snt].[buGuid]<>[bi].[buGuid] OR [stGuid]<>[biStorePtr]
	
	INSERT INTO #scn SELECT snc.[Guid],sn,matGuid, SUM([buDirection]) AS Qty 
	FROM [SNC000] snc INNER JOIN [snt000] snt ON snc.[Guid] = snt.[ParentGuid] INNER JOIN [vwbubi] [bi] ON [bi].[biGuid] = [snt].[biGuid]
	GROUP BY snc.[Guid],sn,matGuid,snc.Qty HAVING SUM([buDirection]) <> snc.Qty
	IF @Mend > 0
	BEGIN
		UPDATE s SET [buGuid] = B.[buGuid], [stGuid] = [biStorePtr]  FROM [snt000] s INNER JOIN #SNT b ON s.[Guid] = b.Guid
		UPDATE s SET [Qty] = b.Qty FROM  snc000 s INNER JOIN  #scn b ON s.[Guid] = b.Guid
		DELETE  [snt000] where parentguid not IN (SELECT [Guid] FROM [snc000])
	END
	SELECT SN,mtCode,mtName FROM #scn a INNER JOIN vwMt b ON b.mtGuid= a.MatGuid
	SELECT DISTINCT buFormatedNumber,buLatinFormatedNumber FROM #SNT a INNER JOIN [vwbu] b ON b.buguid =  a.buguid
################################## 
CREATE PROCEDURE prcGetContraSN
	@BuGuid [UNIQUEIDENTIFIER],
	@ItemNumber [INT],
	@Dir [INT]
AS	
	SET NOCOUNT ON;
	CREATE TABLE [#SN]([Guid] [UNIQUEIDENTIFIER], [Item] FLOAT)
	
	DECLARE @stGuid [UNIQUEIDENTIFIER] ,@UserGuid  [UNIQUEIDENTIFIER],@buDate [DateTime],@StName NVARCHAR(256), @BiGuid [UNIQUEIDENTIFIER]
	SELECT @BiGuid = [biGUID], @buDate = [buDate] FROM vwExtended_bi WHERE [buGUID] = @BuGuid AND [biNumber] = @ItemNumber 
	
	INSERT INTO [#SN] SELECT [c].[Guid] ,[t].[Item]
	FROM (SELECT * FROM [SNT000] where [buGUID] = @BuGuid ) [t] INNER JOIN [SNC000] [c] ON [c].[Guid] = [t].[ParentGuid] WHERE [biGuid] = @BiGuid
	CREATE CLUSTERED INDEX SNI ON [#SN]([Guid],[Item])
	SET @UserGuid =  dbo.fnGetCurrentUserGUID()
	
	SELECT @stGuid = StoreGuid FROM [bi000] WHERE [Guid] = @BiGuid
	SELECT @StName = [NAME] FROM [vcSt] WHERE [Guid] = @stGuid
	CREATE TABLE #MAX
	(
		[id] INT	
	)
	CREATE TABLE #ContraSN
	(
		[id] INT IDENTITY(1,1),
		[SNGuid]	UNIQUEIDENTIFIER,
		[btGuid]	UNIQUEIDENTIFIER,
		[btAbbrev] NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[btLatinAbbrev] NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[buNumber] 	FLOAT,
		[Price]		FLOAT,
		[Item]		INT,
		[Security]	[INT]
	)
	INSERT INTO #ContraSN ([SNGuid],[btGuid],[btAbbrev],[btLatinAbbrev],[buNumber],[Price],[Item],[Security])	
	SELECT [s].[Guid],[buType],[btAbbrev],[btLatinAbbrev],[buNumber],[biPrice],[S].[Item],[buSecurity]
	FROM [SNT000] [t] 
	INNER JOIN [#SN] [S] ON [S].[Guid] = [t].[ParentGuid]
	INNER JOIN [vwBubi] [b] ON [b].[biGuid] = [t].[biGuid]
	WHERE [buDirection] = -@Dir 
	AND ((@Dir = -1 AND [b].[buDate] <= @buDate) OR (@Dir = 1 AND [b].[buDate] >= @buDate))
	AND [biStorePtr] = @stGuid
	ORDER BY [b].[buDate],[buSortFlag],[buNumber],[s].[Item]
	CREATE CLUSTERED INDEX [sncntra] ON #ContraSN([Id])
	IF @Dir = -1
		INSERT INTO #MAX SELECT MAX(ID)  FROM #ContraSN GROUP BY [SNGuid]
	ELSE 
		INSERT INTO #MAX SELECT MIN(ID)  FROM #ContraSN GROUP BY [SNGuid]
	SELECT [SNGuid],[btGuid] [buType],[Item],[btAbbrev], [btLatinAbbrev],[buNumber],[Price],case when [dbo].[fnGetUserBillSec_ReadPrice](@UserGUID , [btGuid]) < [Security]  then 1 else 0 end AS app,@stGuid [stGuid],@StName AS stName, @BiGuid AS biGuid 
	FROM #MAX m INNER JOIN #ContraSN s ON [s].[ID] = [m].[ID]
	
	WHERE [Security] <= dbo.fnGetUserBillSec_Browse(@UserGuid,[btGuid])
/*
prcConnections_add2 'æÇÆá'
exec [prcGetContraSN] '902fdec9-5d28-44c0-8f6f-84ded1907d8f', -1
select * from [SNT000] where buguid = '208F928C-BFCA-4175-B515-2D7EA8AAC39C'
*/
#####################################
CREATE PROCEDURE prcQtySN
	@BuGuid [UNIQUEIDENTIFIER],
	@ItemNumber [INT],
	@Dir [INT]
AS	
	SET NOCOUNT ON

	IF ISNULL(@BuGuid, 0x) = 0x
		RETURN

	CREATE TABLE [#SN]([Guid] [UNIQUEIDENTIFIER], [Item] FLOAT)
	
	DECLARE @BiGuid [UNIQUEIDENTIFIER]
	SELECT @BiGuid = BiGuid FROM vwExtended_bi WHERE [buGUID] = @BuGuid AND [biNumber] = @ItemNumber 

	DECLARE @stGuid [UNIQUEIDENTIFIER] ,@UserGuid  [UNIQUEIDENTIFIER],@buDate [DateTime],@StName NVARCHAR(256)
	select @buDate = [Date] FROM bu000 WHERE GUID = (SELECT PARENTGUID FROM bi000 WHERE GUID = @BiGuid)
	INSERT INTO [#SN] SELECT [c].[Guid] ,[t].[Item]
	FROM (SELECT * FROM [SNT000] WHERE [buGUID] = @BuGuid ) [t] INNER JOIN [SNC000] [c] ON [c].[Guid] = [t].[ParentGuid] WHERE [biGuid] = @BiGuid
	CREATE CLUSTERED INDEX SNI ON [#SN]([Guid],[Item])
	SET @UserGuid =  dbo.fnGetCurrentUserGUID()
	
	SELECT @stGuid = StoreGuid FROM [bi000] WHERE [Guid] = @BiGuid
	SELECT @StName = [NAME] FROM [vcSt] WHERE [Guid] = @stGuid
	CREATE TABLE #MAX
	(
		[id] INT	
	)
	CREATE TABLE #ContraSN
	(
		[id] INT IDENTITY(1,1),
		[SNGuid]	UNIQUEIDENTIFIER,
		[btGuid]	UNIQUEIDENTIFIER,
		[btAbbrev] NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[btLatinAbbrev] NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[buNumber] 	FLOAT,
		[Price]		FLOAT,
		[Item]		INT,
		[Security]	[INT]
	)
	INSERT INTO #ContraSN ([SNGuid],[btGuid],[btAbbrev],[btLatinAbbrev],[buNumber],[Price],[Item],[Security])	
	SELECT [s].[Guid],[buType],[btAbbrev],[btLatinAbbrev],[buNumber],[biPrice],[S].[Item],[buSecurity]
	FROM [SNT000] [t] 
	INNER JOIN [#SN] [S] ON [S].[Guid] = [t].[ParentGuid]
	INNER JOIN [vwBubi] [b] ON [b].[biGuid] = [t].[biGuid]
	WHERE [buDirection] = -@Dir 
	AND ((@Dir = -1 AND [b].[buDate] <= @buDate) OR (@Dir = 1 AND [b].[buDate] >= @buDate))
	AND [biStorePtr] = @stGuid
	ORDER BY [b].[buDate],[buSortFlag],[buNumber],[s].[Item]
	CREATE CLUSTERED INDEX [sncntra] ON #ContraSN([Id])
	IF @Dir = -1
		INSERT INTO #MAX SELECT MAX(ID)  FROM #ContraSN GROUP BY [SNGuid]
	ELSE 
		INSERT INTO #MAX SELECT MIN(ID)  FROM #ContraSN GROUP BY [SNGuid]
	
	SELECT SUM(cnt) cnt FROM (SELECT distinct ISNULL(count(*),0) as cnt
	FROM #MAX m INNER JOIN #ContraSN s ON [s].[ID] = [m].[ID]
	WHERE [Security] <= dbo.fnGetUserBillSec_Browse(@UserGuid,[btGuid])
	UNION ALL
	SELECT  distinct ISNULL(count(*),0)
	FROM  [#SN] [S] 
	INNER JOIN AD000 a on a.snguid=s.GUID  --
	LEFT  JOIN dd000 dd on dd.ADGUID=a.GUID 
	LEFT  JOIN AssetPossessionsFormItem000 AS pi ON [a].[GUID] = [pi].[AssetGuid]
	LEFT  JOIN AssetUtilizeContract000 AS au ON [a].[GUID] = [au].[Asset]
	WHERE dd.GUID<> 0x0 OR UseFlag <> 0 OR pi.AssetGuid <> 0x0 OR au.Asset <> 0x0
	 ) as res
#####################################
CREATE PROCEDURE prcUnusedSN
	@BuGuid [UNIQUEIDENTIFIER],
	@ItemNumber [INT],
	@QtyToDelete [INT]
AS
BEGIN
	DECLARE @BiGuid [UNIQUEIDENTIFIER]
	SELECT @BiGuid = BiGuid FROM vwExtended_bi WHERE [buGUID] = @BuGuid AND [biNumber] = @ItemNumber 

	SELECT TOP(@QtyToDelete) SnGuid AS GUID, SN AS sn
	  FROM AD000 AS [ad]
		   INNER JOIN [SNT000] AS [snt] ON [snt].[ParentGUID] = [ad].[SnGuid]
		   LEFT  JOIN AssetPossessionsFormItem000 AS pi ON [ad].[GUID] = [pi].[AssetGuid]
		   LEFT  JOIN AssetUtilizeContract000 AS au ON [ad].[GUID] = [au].[Asset]
	 WHERE [snt].[biGUID] = @BiGuid AND ([ad].[UseFlag] = 0 OR [pi].[AssetGuid] = 0x0 OR [au].[Asset] = 0x0)
END
#########################################################################
#END