#########################################################
CREATE PROCEDURE prcPalm_GetUserMaterial
		@PalmUserName [NVARCHAR](250)   
AS   
	SET NOCOUNT ON   
	DECLARE @GroupGUID [uniqueidentifier]   
	DECLARE @MatCondId [int]   
	DECLARE @MatSortFld [NVARCHAR](250)   
	DECLARE @PrivateStoreGUID [uniqueidentifier]   
	DECLARE @bExportSerialNum [bit]   
	DECLARE @bExportEmptyMaterial [bit]   
	SELECT @GroupGUID = [GroupGUID], @MatCondId = [MatCondId], @MatSortFld = [MatSortFld], @PrivateStoreGUID = [PrivateStoreGUID], @bExportSerialNum = [bExportSerialNum], @bExportEmptyMaterial = [bExportEmptyMaterial] FROM [vwPl] WHERE [PalmUserName] = @PalmUserName  
	CREATE TABLE [#GroupTbl](         
		[ID] [uniqueidentifier],         
		[ParentID] [uniqueidentifier],         
		[Name] [NVARCHAR](255)  COLLATE Arabic_CI_AI, 
		[Flag] [int] 
	)                 
	CREATE TABLE [#MatCond]([GUID] [uniqueidentifier], [Security] [INT])   
	INSERT INTO [#MatCond] EXEC [prcPalm_GetMatsList] @MatCondId   
	CREATE TABLE [#MatTbl](         
		[GUID] [uniqueidentifier],   
		[GroupID] [uniqueidentifier],   
		[Code] [NVARCHAR](255)  COLLATE Arabic_CI_AI,         
		[BarCode] [NVARCHAR](255) COLLATE Arabic_CI_AI,          
		[BarCode2] [NVARCHAR](255) COLLATE Arabic_CI_AI,          
		[BarCode3] [NVARCHAR](255) COLLATE Arabic_CI_AI,          
		[Name] [NVARCHAR](255) COLLATE Arabic_CI_AI,          
		[LatinName] [NVARCHAR](255) COLLATE Arabic_CI_AI,      
		[Price1] [float],          
		[Price2] [float],          
		[Price1Unit2] [float],          
		[Price2Unit2] [float],          
		[Price1Unit3] [float],          
		[Price2Unit3] [float],          
		[Vendor] [float],          
		[Export] [float],          
		[Retail] [float],          
		[EndUser] [float] ,          
		[Unity] [NVARCHAR](255) COLLATE Arabic_CI_AI,          
		[Unit2] [NVARCHAR](255) COLLATE Arabic_CI_AI,          
		[Unit3] [NVARCHAR](255) COLLATE Arabic_CI_AI,          
		[Unit2Fact] [float], 
		[Unit3Fact] [float], 
		[Qty] [float], 
		[DefUnit] [int] 
	)                 
	CREATE TABLE [#MatResultTbl](         
		[ID]		[int], 
		[GroupID] [int], 
		[Code] [NVARCHAR](255)  COLLATE Arabic_CI_AI,         
		[BarCode] [NVARCHAR](255) COLLATE Arabic_CI_AI,          
		[BarCode2] [NVARCHAR](255) COLLATE Arabic_CI_AI,          
		[BarCode3] [NVARCHAR](255) COLLATE Arabic_CI_AI,          
		[Name] [NVARCHAR](255) COLLATE Arabic_CI_AI,          
		[LatinName] [NVARCHAR](255) COLLATE Arabic_CI_AI,      
		[Price1] [float],          
		[Price2] [float],          
		[Price1Unit2] [float],          
		[Price2Unit2] [float],          
		[Price1Unit3] [float],          
		[Price2Unit3] [float],          
		[Vendor] [float],          
		[Export] [float],          
		[Retail] [float],          
		[EndUser] [float],          
		[Unity] [NVARCHAR](255) COLLATE Arabic_CI_AI,          
		[Unit2] [NVARCHAR](255) COLLATE Arabic_CI_AI,          
		[Unit3] [NVARCHAR](255) COLLATE Arabic_CI_AI,          
		[Unit2Fact] [float],          
		[Unit3Fact] [float],          
		[Qty] [float],          
		[DefUnit] [int],          
		[MatIndex] [INT] IDENTITY(0,1) 
	)                 
	CREATE TABLE [#SerialList](   
			[MatGUID] [uniqueidentifier],   
			[SN] [NVARCHAR](100) COLLATE ARABIC_CI_AI,    
			[InCount] [Int],    
			[OutCount] [int]   
		)   
if (@GroupGUID = 0x0)                 
	INSERT INTO [#GroupTbl]                 
		SELECT [grGUID] , [grParent], [grName], 0 From [vwGr] 
else                 
	INSERT INTO [#GroupTbl]   
		SELECT [grGUID], [grParent], [grName], 0 
		From [vwGr] INNER JOIN [dbo].[fnGetGroupsOfGroup](@GroupGUID) AS [f] ON [vwGr].[grGUID] = [f].[GUID] 
--***** 
--SELECT * FROM #GroupTbl 
INSERT INTO [#MatTbl] 
(        
	[GUID],        
	[GroupID],        
	[Code],        
	[BarCode],        
	[BarCode2],        
	[BarCode3],        
	[Name],        
	[LatinName],        
	[Price1],        
	[Price2],        
	[Price1Unit2],        
	[Price2Unit2],        
	[Price1Unit3],        
	[Price2Unit3],        
	[Vendor],        
	[Export],        
	[Retail],        
	[EndUser],        
	[Unity],        
	[Unit2],        
	[Unit3],          
	[Unit2Fact],          
	[Unit3Fact],          
	[Qty], 
	[DefUnit] 
)        
	SELECT          
		[mt].[mtGUID],         
		[mt].[mtGroup],         
		[mt].[mtCode],         
		[mt].[mtBarCode],         
		[mt].[mtBarCode2],        
		[mt].[mtBarCode3],        
		[mt].[mtName],         
		[mt].[mtLatinName],         
		[mt].[mtWhole] AS [Price1],         
		[mt].[mtHalf] AS [Price2],  
		[mt].[mtWhole2] AS [Price1Unit2],  
		[mt].[mtHalf2] AS [Price2Unit2],  
		[mt].[mtWhole3] AS [Price1Unit3],  
		[mt].[mtHalf3] AS [Price2Unit3],  
		[mt].[mtVendor],         
		[mt].[mtExport],         
		[mt].[mtRetail],         
		[mt].[mtEndUser],         
		[mt].[mtUnity],         
		[mt].[mtUnit2],         
		[mt].[mtUnit3],         
		[mt].[mtUnit2Fact],         
		[mt].[mtUnit3Fact],         
		0, 
		[mt].[mtDefUnit] 
	FROM    
		[vwMt] AS [mt] INNER JOIN [#MatCond] AS [mTcn] ON [mTcn].[GUID] = [mt].[mtGUID]   
		INNER JOIN [dbo].[fnGetGroupsOfGroup](@GroupGUID) AS [f] ON [mt].[mtGroup] = [f].[GUID] 
UPDATE [#MatTbl] SET [Qty] = [msQty] 
	FROM [#MatTbl] INNER JOIN [vwMs] ON [GUID] = [msMatPtr] WHERE [msStorePtr] = @PrivateStoreGUID   
----- Delete Empty Material   
IF (@bExportEmptyMaterial = 0)   
BEGIN   
	DELETE [#MatTbl] WHERE [Qty] = 0   
END   
----- Delete Empty Group 
while EXISTS (SELECT * FROM #GroupTbl   WHERE   ID NOT IN (SELECT DISTINCT GroupID FROM #MatTbl) AND ID NOT IN (SELECT DISTINCT ParentID FROM #GroupTbl))
	DELETE #GroupTbl   
	WHERE   
		ID NOT IN (SELECT DISTINCT GroupID FROM #MatTbl) AND 
		ID NOT IN (SELECT DISTINCT ParentID FROM #GroupTbl)


UPDATE [#GroupTbl] SET [ParentID] = 0x0 WHERE [ParentID] = @GroupGUID 
DELETE [#GroupTbl] WHERE [ID] = @GroupGUID 
----- Calc MatGroup Flag 
DECLARE @MatGroup_ContainMat	[int] 
DECLARE @MatGroup_ContainGroup	[int] 
SET @MatGroup_ContainMat = 0x0001 
SET @MatGroup_ContainGroup = 0x0002 
UPDATE [#GroupTbl] 
SET 
	[Flag] = [Flag] | @MatGroup_ContainMat 
WHERE 
	[ID] IN (SELECT [GroupID] FROM [#MatTbl]) 
UPDATE [#GroupTbl] 
SET 
	[Flag] = [Flag] | @MatGroup_ContainGroup 
WHERE 
	[ID] IN (SELECT [ParentID] FROM [#GroupTbl]) 
----- Calc Serial Number   
IF (@bExportSerialNum = 1)   
BEGIN   
	CREATE TABLE [#InSerial] ([MatGUID] [uniqueidentifier], [SN] [NVARCHAR](100) COLLATE ARABIC_CI_AI, [InCount] [INT])   
	CREATE TABLE [#OutSerial] ([MatGUID] [uniqueidentifier], [SN] [NVARCHAR](100) COLLATE ARABIC_CI_AI, [OutCount] [INT])   
	   
	INSERT INTO [#InSerial]   
	SELECT   
		[sn].[MatGUID],   
		[sn].[SN],   
		Count([sn].[SN]) AS [InCount]   
	FROM   
		[bi000] AS [bi] INNER JOIN [SN000] AS [sn] ON [bi].[GUID] = [sn].[InGUID]   
		INNER JOIN [#MatTbl] AS [mt] ON [mt].[GUID] = [bi].[MatGUID]   
	WHERE   
		[bi].[StoreGUID] = @PrivateStoreGUID   
	GROUP BY   
		[sn].[MatGUID],   
		[sn].[SN]   
	   
	INSERT INTO [#OutSerial]   
	SELECT   
		[sn].[MatGUID],   
		[sn].[SN],   
		Count([sn].[SN]) AS [OutCount] 
	FROM   
		[bi000] AS [bi] INNER JOIN [SN000] AS [sn] ON [bi].[GUID] = [sn].[OutGUID]   
		INNER JOIN [#MatTbl] AS [mt] ON [mt].[GUID] = [bi].[MatGUID]   
	WHERE   
		[bi].[StoreGUID] = @PrivateStoreGUID   
	GROUP BY   
		[sn].[MatGUID],   
		[sn].[SN]   
	   
	INSERT INTO [#SerialList] 
	SELECT   
		[in].[MatGUID],   
		[in].[SN],   
		[in].[InCount],   
		ISNULL([out].[OutCount],0) AS [OutCount] 
	FROM   
		[#InSerial] AS [in] LEFT JOIN [#OutSerial] AS [out] ON [in].[MatGUID] = [out].[MatGUID] AND [in].[SN] = [out].[SN]	   
	DROP TABLE [#InSerial]   
	DROP TABLE [#OutSerial]   
END   
----- Return Result   
--SELECT * FROM #GroupTbl 
--------- 1   
	INSERT INTO [PalmGUID]   
	SELECT DISTINCT   
		[gr].[ID]   
	FROM   
		[#GroupTbl] AS [gr] LEFT JOIN [PalmGUID] AS [pg] ON [pg].[GUID] = [gr].[ID]   
	WHERE   
		[pg].[GUID] IS NULL   
	/* 
	INSERT INTO PalmGUID 
	SELECT DISTINCT   
		gr.ParentID   
	FROM   
		#GroupTbl AS gr LEFT JOIN PalmGUID AS pg ON pg.GUID = gr.ParentID   
	WHERE   
		pg.GUID IS NULL   
	*/ 
SELECT 
	[pg].[Number] AS [ID],  
	isnull([pg1].[Number] , 0) AS [ParentID],  
	[gr].[Name], 
	[gr].[Flag] 
FROM  
	[#GroupTbl] AS [gr]  
	INNER JOIN [PalmGUID] AS [pg] ON [pg].[GUID] = [gr].[ID]   
	LEFT JOIN [PalmGUID] AS [pg1] ON [pg1].[GUID] = [gr].[ParentID]   
--------- 2   
	INSERT INTO [PalmGUID]   
	SELECT DISTINCT   
		[mt].[GUID]   
	FROM   
		[#MatTbl] AS [mt] LEFT JOIN [PalmGUID] AS [pg] ON [pg].[GUID] = [mt].[GUID]   
	WHERE   
		[pg].[GUID] IS NULL   
----- 
if (ISNULL(@MatSortFld, '') <> '')   
begin   
	DECLARE @Str AS [NVARCHAR](2024)     
	SET @Str =    
	'INSERT INTO [#MatResultTbl]( 
			[ID], 
			[GroupID], 
			[Code], 
			[BarCode], 
			[BarCode2], 
			[BarCode3], 
			[Name], 
			[LatinName], 
			[Price1], 
			[Price2], 
			[Price1Unit2], 
			[Price2Unit2], 
			[Price1Unit3], 
			[Price2Unit3], 
			[Vendor], 
			[Export], 
			[Retail], 
			[EndUser], 
			[Unity], 
			[Unit2], 
			[Unit3], 
			[Unit2Fact], 
			[Unit3Fact], 
			[Qty], 
			[DefUnit] 
		) 
		SELECT    
			[pg1].[Number] AS [ID],   
			[pg2].[Number] AS [GroupID],   
			[Code],   
			[BarCode],   
			[BarCode2],   
			[BarCode3],   
			[Name],   
			[LatinName],   
			[Price1],   
			[Price2],   
			[Price1Unit2],   
			[Price2Unit2],   
			[Price1Unit3],   
			[Price2Unit3],   
			[Vendor],   
			[Export],   
			[Retail],   
			[EndUser],   
			[Unity],   
			[Unit2],   
			[Unit3],   
			[Unit2Fact],   
			[Unit3Fact],   
			[Qty], 
			[DefUnit] 
		FROM    
			[#MatTbl] AS [mt] 
			INNER JOIN [PalmGUID] AS [pg1] ON [pg1].[GUID] = [mt].[GUID]   
			INNER JOIN [PalmGUID] AS [pg2] ON [pg2].[GUID] = [mt].[GroupID]   
		ORDER BY '   
	SET @Str = @Str + @MatSortFld   
	--PRINT @Str  
	EXECUTE (@Str) 	     
end   
else 
	INSERT INTO [#MatResultTbl]( 
		[ID], 
		[GroupID], 
		[Code], 
		[BarCode], 
		[BarCode2], 
		[BarCode3], 
		[Name], 
		[LatinName], 
		[Price1], 
		[Price2], 
		[Price1Unit2], 
		[Price2Unit2], 
		[Price1Unit3], 
		[Price2Unit3], 
		[Vendor], 
		[Export], 
		[Retail], 
		[EndUser], 
		[Unity], 
		[Unit2], 
		[Unit3], 
		[Unit2Fact], 
		[Unit3Fact], 
		[Qty], 
		[DefUnit] 
	) 
	SELECT   
		[pg1].[Number] AS [ID],   
		[pg2].[Number] AS [GroupID],   
		[Code],   
		[BarCode],   
		[BarCode2],   
		[BarCode3],   
		[Name],   
		[LatinName],   
		[Price1],   
		[Price2],   
		[Price1Unit2],   
		[Price2Unit2],   
		[Price1Unit3],   
		[Price2Unit3],   
		[Vendor],   
		[Export],   
		[Retail],   
		[EndUser],   
		[Unity],   
		[Unit2],   
		[Unit3],   
		[Unit2Fact],   
		[Unit3Fact],   
		[Qty], 
		[DefUnit] 
	FROM   
		[#MatTbl] AS [mt]  
		INNER JOIN [PalmGUID] AS [pg1] ON [pg1].[GUID] = [mt].[GUID]   
		INNER JOIN [PalmGUID] AS [pg2] ON [pg2].[GUID] = [mt].[GroupID]   
---- 
	SELECT * FROM [#MatResultTbl] ORDER BY [MatIndex] 
--------- 3   
INSERT INTO [PalmGUID]   
SELECT DISTINCT   
	[sn].[MatGUID]   
FROM   
	[#SerialList] AS [sn]  
	LEFT JOIN [PalmGUID] AS [pg] ON [pg].[GUID] = [sn].[MatGUID]   
WHERE   
	[sn].[MatGUID] IS NULL   
SELECT    
	[pg].[Number] AS [MatPtr],   
	[sn].[SN]   
FROM   
	[#SerialList] AS [sn] INNER JOIN  
	[PalmGUID] AS [pg] ON [pg].[GUID] = [sn].[MatGUID]   
WHERE   
	([InCount] - [OutCount]) > 0    
ORDER BY   
	[MatPtr], [sn].[SN]   
---------- 4 
	SELECT   
		[mt].[MatIndex] AS [MatIndex],   
		[mt].[GroupID] AS [GroupID] 
	FROM   
		[#MatResultTbl] AS [mt]  
	ORDER BY [mt].[GroupID] ASC, [mt].[MatIndex]
	
------------ 
DROP table [#GroupTbl]                 
DROP table [#MatTbl]                 
DROP table [#MatResultTbl] 
DROP table [#SerialList] 
#########################################################
#END