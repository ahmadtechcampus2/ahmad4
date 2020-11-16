####################################################
###### prcPDABilling_InitMatSn
CREATE PROC prcPDABilling_InitMatSn
	@PDAGuid	UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON  
	DELETE DistDeviceSN000 WHERE DistributorGUID = @PDAGuid
	DECLARE @bExportSerialNum		BIT, 
			@StoreGuid				UNIQUEIDENTIFIER 
	SELECT @bExportSerialNum = ISNULL( [bExportSerialNum], 0), @StoreGuid = [PrivateStoreGUID]  
	FROM vwPl WHERE Guid = @PDAGuid 
	IF @bExportSerialNum = 0 
		RETURN 
		
	------------------------------------------------------------------------------------- 
	--------- From "repMatSn" Stored Procedure 
	CREATE TABLE #MatSn(  
		[ID]			[INT] IDENTITY(0,1),  
		[SN]			[NVARCHAR](255)  COLLATE ARABIC_CI_AI,  
		[snGuid]        [UNIQUEIDENTIFIER],  
		[mtGuid]		[UNIQUEIDENTIFIER],  
		[stGuid]		[UNIQUEIDENTIFIER],  
		[biGuid]        [UNIQUEIDENTIFIER],   
		[Direction]     [INT],  
	 )  
	INSERT INTO #MatSn( SN, snGuid, mtGuid, stGuid, biGuid, Direction ) 
	SELECT  
		  ISNULL([snc].[SN] , ''),		 
		  ISNULL([snc].[GUID] , 0x0),     
		  ISNULL([snc].[MatGuid] , 0x0),  
		  ISNULL([bi].[StoreGUID],0x0),	 
		  ISNULL([bi].[GUID],0x0),	
		  CASE bt.bIsInput WHEN 0 THEN -1 ELSE 1 END   AS Direction
		/* 
		  CASE bt.BillType  WHEN 0 THEN  1 	WHEN 1 THEN -1 	WHEN 2 THEN  1 	WHEN 3 THEN -1 	WHEN 4 THEN  1 	WHEN 5 THEN -1 	ELSE 0   END AS [Direction] 
		*/ 
	FROM [snc000] AS snc     
		  INNER JOIN [snt000]AS snt ON [snc].[GUID] = [snt].ParentGUID  
		  INNER JOIN [bu000] AS bu ON [snt].[buGuid] = [bu].[GUID]  
		  INNER JOIN [bi000] AS bi ON [snt].[biGUID] = [bi].[GUID]  
		  INNER JOIN [bt000] AS bt ON [bu].[TypeGUID] = [bt].[GUID]  
		  INNER JOIN [DistDeviceMt000] AS mt ON [snc].[MatGUID] = [mt].[mtGUID] AND mt.DistributorGuid = @PDAGuid AND snFlag = 1 
		  LEFT JOIN  [DistDeviceSt000] AS st ON [bi].[StoreGUID] = [st].[stGUID] AND st.DistributorGuid = @PDAGuid 
	WHERE  
		(bi.StoreGuid = @StoreGuid AND ISNULL(st.stGuid, 0x00) = 0x00) OR (ISNULL(st.stGuid, 0x00) <> 0x00 )			  
	ORDER BY [SN]  , bu.[Date] , [Direction]  , bu.Number
------------------------------------------------------------------------------------------  
	CREATE TABLE #temp1 ([SN] [NVARCHAR](255)  COLLATE ARABIC_CI_AI , _SUM [INT] , [ID] [INT])  
	INSERT INTO #temp1  
	SELECT ISNULL(SN,'') AS SN , SUM(Direction) AS [Direction] , MAX(ID) AS [GID]  
	FROM #MatSn 
	GROUP BY [SN] , [mtGuid]  
	DELETE FROM #temp1 WHERE _Sum = 0  
	------------------------------------------------------------------------------------ 
	--- Return first Result Set -- needed data  
	INSERT INTO DistDeviceSN000 (  
		Guid, Item, Sn, InGuid, OutGuid, Notes, MatGuid, DistributorGUID)     
	SELECT  
		snGuid,	0, SN.SN, sn.biGuid, 0x00, sn.stGuid, sn.mtGuid, @PDAGuid 
	FROM  
		[#MatSn] AS [sn] INNER JOIN [#temp1] AS [t] ON [sn].[Id] = [t].[Id]  
	  
/*
EXEC prcConnections_Add2 '„œÌ—'
EXEC prcPDABilling_InitMatSn '838E3185-036D-490B-9072-8DB2A17019B2'
Select * From DistDeviceSn000 Where DistributorGuid = '838E3185-036D-490B-9072-8DB2A17019B2'
*/
#################################################################
CREATE PROC prcPDABilling_InitMat
	@PDAGUID uniqueidentifier
AS        
	SET NOCOUNT ON        
	------------------------------------   
	DECLARE	
		@GroupGUID 			UNIQUEIDENTIFIER,  
		@MatCondId 				INT, 
		@MatCondGuid		UNIQUEIDENTIFIER,    
		@MatSortFld 			NVARCHAR(250),     
		@StoreGUID 				UNIQUEIDENTIFIER,  
		@bExportSerialNum 		BIT,     
		@bExportEmptyMaterial 		BIT,     
		@ExportStoreGuid 		UNIQUEIDENTIFIER,  
		@ExportStoreFlag		INT,  
		@CostGuid 			UNIQUEIDENTIFIER  
	SELECT    
		@GroupGUID 				= ISNULL( [GroupGUID], 0x0),    
		@MatCondId 				= ISNULL( [MatCondId], 0),    
		@MatCondGuid			= ISNULL( [MatCondGuid], 0x0),
		@MatSortFld 			= ISNULL( [MatSortFld], 0),    
		@StoreGUID 				= ISNULL( [PrivateStoreGUID], 0x0),    
		@bExportSerialNum 		= ISNULL( [bExportSerialNum], 0),    
		@bExportEmptyMaterial 	= ISNULL( [bExportEmptyMaterial], 0),    
		@ExportStoreGuid 		= ISNULL( [StoreGuid], 0x0),    
		@ExportStoreFlag 		= ISNULL( [ExportStoreFlag], 0),  
		@CostGuid 				= ISNULL( [CostGUID], 0x0)    
 	FROM    
		[vwPl]   
	WHERE    
		[GUID] = @PDAGUID    
	------------------------------------   
	CREATE TABLE #GroupTbl(              
		[GUID] 			uniqueidentifier,      
		[ParentGUID] 	uniqueidentifier,     
		[Name] 			NVARCHAR(255)  COLLATE Arabic_CI_AI,      
		[HasMats] 		int,
		[Level] 		int    
	)   
	------------------------------------   
	CREATE TABLE #MatCond ( [GUID] uniqueidentifier, [Security] INT)        
	INSERT INTO #MatCond EXEC prcPalm_GetMatsList @MatCondId, @MatCondGuid     
	------------------------------------   
	CREATE TABLE #MatTbl(     
		[GUID] 		uniqueidentifier,        
		[GroupGUID] 	uniqueidentifier,        
		[Code] 		NVARCHAR(255)  COLLATE Arabic_CI_AI,              
		[BarCode] 	NVARCHAR(255) COLLATE Arabic_CI_AI,               
		[BarCode2] 	NVARCHAR(255) COLLATE Arabic_CI_AI,               
		[BarCode3] 	NVARCHAR(255) COLLATE Arabic_CI_AI,               
		[Name] 		NVARCHAR(255) COLLATE Arabic_CI_AI,               
		[LatinName] 	NVARCHAR(255) COLLATE Arabic_CI_AI,           
		[Price1] 	float,               
		[Price2] 	float,               
		[Price3] 	float,               
		[Price4] 	float,               
		[Price5] 	float,               
		[Price6] 	float,               
		[Price1Unit2] 	Float,               
		[Price2Unit2] 	float,               
		[Price3Unit2] 	float,               
		[Price4Unit2] 	float,               
		[Price5Unit2] 	float,               
		[Price6Unit2] 	float,               
		[Price1Unit3] 	float,               
		[Price2Unit3] 	float,               
		[Price3Unit3] 	float,               
		[Price4Unit3] 	float,               
		[Price5Unit3] 	float,               
		[Price6Unit3] 	float,               
		[Unity] 	NVARCHAR(255) COLLATE Arabic_CI_AI,               
		[Unit2] 	NVARCHAR(255) COLLATE Arabic_CI_AI,               
		[Unit3] 	NVARCHAR(255) COLLATE Arabic_CI_AI,               
		[Unit2Fact] 	float,      
		[Unit3Fact] 	float,      
		[Qty] 		float,      
		[DefUnit] 	int,   
		[SNFlag]	INT,   
		[ForceInSN]	INT,   
		[ForceOutSN]	INT, 
		[MatTemplateGuid]	UNIQUEIDENTIFIER,
		[BonusOne]		FLOAT,	
		[Bonus]			FLOAT,	
		[VAT]			FLOAT	
	)   
	CREATE TABLE #MsTbl  
	(  
		[GUID] 		Uniqueidentifier,  
		[MatGUID] 	Uniqueidentifier,  
		[StoreGUID]	Uniqueidentifier,  
		[Qty]		FLOAT DEFAULT (0)  
	)  
	  
	------------------------------------   
	if (@GroupGUID = 0x0)                      
		INSERT INTO #GroupTbl                      
			SELECT [grGUID] , [grParent], [grName], 0, 0 From [vwGr]                      
	else                      
		INSERT INTO #GroupTbl        
			SELECT [grGUID], [grParent], [grName], 0 , 0     
			From [vwGr] INNER JOIN dbo.fnGetGroupsOfGroup(@GroupGUID) AS f ON [vwGr].[grGUID] = f.GUID   
	------------------------------------   
	INSERT INTO #MatTbl                      
	(             
		[GUID],             
		[GroupGUID],             
		[Code],             
		[BarCode],             
		[BarCode2],             
		[BarCode3],             
		[Name],             
		[LatinName],             
		[Price1],             
		[Price2],             
		[Price3],             
		[Price4],             
		[Price5],             
		[Price6],             
		[Price1Unit2],             
		[Price2Unit2],             
		[Price3Unit2],             
		[Price4Unit2],             
		[Price5Unit2],             
		[Price6Unit2],             
		[Price1Unit3],             
		[Price2Unit3],             
		[Price3Unit3],             
		[Price4Unit3],             
		[Price5Unit3],             
		[Price6Unit3],             
		[Unity],             
		[Unit2],             
		[Unit3],               
		[Unit2Fact],               
		[Unit3Fact],               
		[Qty],      
		[DefUnit],      
		[SNFlag],   
		[ForceInSN],   
		[ForceOutSN], 
		[MatTemplateGUID],   
		[BonusOne],	
		[Bonus],
		[VAT]
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
			Round([mt].[mtWhole], 2)	 AS Price1,              
			Round([mt].[mtHalf], 2)		 AS Price2,       
			Round([mt].[mtVendor], 2)	 AS Price3,   
			Round([mt].[mtExport], 2)	 AS Price4,   
			Round([mt].[mtRetail], 2)	 AS Price5,   
			Round([mt].[mtEndUser], 2)	 AS Price6,   
			Round([mt].[mtWhole2], 2)	 AS Price1Unit2,       
			Round([mt].[mtHalf2], 2)	 AS Price2Unit2,       
			Round([mt].[mtVendor2], 2)	 AS Price3Unit2,   
			Round([mt].[mtExport2], 2)	 AS Price4Unit2,   
			Round([mt].[mtRetail2], 2)	 AS Price5Unit2,   
			Round([mt].[mtEndUser2], 2)	 AS Price6Unit2,   
			Round([mt].[mtWhole3], 2)	 AS Price1Unit3,       
			Round([mt].[mtHalf3], 2)	 AS Price2Unit3,       
			Round([mt].[mtVendor3], 2)	 AS Price3Unit3,   
			Round([mt].[mtExport3], 2)	 AS Price4Unit3,   
			Round([mt].[mtRetail3], 2)	 AS Price5Unit3,   
			Round([mt].[mtEndUser3], 2)	 AS Price6Unit3,   
			[mt].[mtUnity],              
			[mt].[mtUnit2],              
			[mt].[mtUnit3],              
			[mt].[mtUnit2Fact],              
			[mt].[mtUnit3Fact],              
			0,      
			[mt].[mtDefUnit],   
			[mt].[mtSNFlag],   
			[mt].[mtForceInSN],   
			[mt].[mtForceOutSN], 
			0x0,
			[mt].[mtBonusOne],	
			[mt].[mtBonus],
			[mt].[mtVAT]
			   
		FROM         
			[vwMt] AS mt  
			INNER JOIN #MatCond AS [mTcn] ON [mTcn].[GUID] = [mt].[mtGUID]    
			INNER JOIN dbo.fnGetGroupsOfGroup(@GroupGUID) AS f ON [mt].[mtGroup] = [f].[GUID]          
	------------------------------------   
	DELETE DistDeviceST000 WHERE DistributorGUID = @PDAGUID   
	DELETE DistDeviceGR000 WHERE DistributorGUID = @PDAGUID   
	DELETE DistDeviceMT000 WHERE DistributorGUID = @PDAGUID   
	DELETE DistDeviceMS000 WHERE DistributorGUID = @PDAGUID   
	-- DELETE DistDeviceSN000 WHERE DistributorGUID = @PDAGUID   
	--------------------------------------  
	------------------------------------   
	----  ’œÌ— Ã—œ „” Êœ⁄ «·„‰œÊ»  
	INSERT INTO #MsTbl ( [GUID], [MatGUID], [StoreGUID], [Qty] ) 	  
	SELECT   
		newID(), [mt].[GUID], @StoreGUID, ISNULL([ms].[Qty], 0)  
	FROM   
		#MatTbl AS [mt]  
		LEFT JOIN [ms000] AS [ms] ON [mt].[GUID] = [ms].[MatGUID] AND [ms].[StoreGUID] = @StoreGUID 	  
	----  ’œÌ— Ã—œ „” Êœ⁄«  «·“»«∆‰	  
	INSERT INTO #MsTbl ( [GUID], [MatGUID], [StoreGUID], [Qty] ) 	  
	SELECT   
		newId(), [ms].[MatGUID], [ms].[StoreGUID], [ms].[Qty]  
	FROM   
		[ms000] AS ms  
		INNER JOIN #MatTbl AS mt ON [mt].[GUID] = [ms].[MatGUID]	  
		INNER JOIN [DistDeviceCu000] AS [cu] ON [cu].[StoreGUID] = [ms].[StoreGUID]   
	WHERE  [cu].[DistributorGUID] = @PDAGUID  
	  
	-------------------------------------  
	UPDATE #MatTbl SET [Qty] = [Total].[msQty]  
	FROM 	(  
			SELECT [matGuid] , SUM([ms].[Qty]) AS msQty   
			FROM #msTbl AS [ms] -- INNER JOIN #matTbl AS mt ON mt.GUID = ms.MatGUID   
			GROUP BY [matGUID]  
		) AS Total   
		INNER JOIN #MatTbl AS [mt] ON [mt].[GUID] = [Total].[matGUID]  
	------------------------------------   
	----- Delete Empty Material        
	IF (@bExportEmptyMaterial = 0)        
	BEGIN        
	--	DELETE #MatTbl WHERE Qty <= 0  
		 
		DELETE #MatTbl 
			FROM #MatTbl AS mt  
		WHERE Qty <=0 
	 
		DELETE #msTbl WHERE Qty <=0 
	END        
	------------------------------------   
	-- Delete Empty Group      
	while EXISTS (   
			SELECT GUID FROM #GroupTbl    
			WHERE    
				GUID NOT IN (SELECT DISTINCT GroupGUID FROM #MatTbl) AND    
				GUID NOT IN (SELECT DISTINCT ParentGUID FROM #GroupTbl)   
		      )   
		DELETE #GroupTbl      
		WHERE      
			GUID NOT IN (SELECT DISTINCT GroupGUID FROM #MatTbl) AND    
			GUID NOT IN (SELECT DISTINCT ParentGUID FROM #GroupTbl)   
	UPDATE #GroupTbl SET ParentGUID = 0x0 WHERE GUID = @GroupGUID      
	------------------------------------   
	-- Calc MatGroup Flag      
	UPDATE #GroupTbl      
	SET      
		[HasMats]  = 1,     
		[Level] = 2    
	WHERE      
		GUID IN (SELECT GroupGUID FROM #MatTbl)      
	UPDATE #GroupTbl   
	SET      
		[HasMats] = 0,     
		[Level] = 1    
	WHERE      
		GUID IN (SELECT ParentGUID FROM #GroupTbl)      
	------------------------------------   
	INSERT INTO DistDeviceGr000(   
		[grGUID],   
		[DistributorGUID],   
		[ParentGUID],   
		[Name],   
		[HasMats],    
		[Level]   
	)   
	SELECT   
		[GUID],   
		@PDAGUID,   
		[ParentGUID],   
		[Name],   
		[HasMats],    
		[Level]   
	FROM   
		#GroupTbl   
	------------------------------------   
	INSERT INTO DistDeviceMT000(      
		[mtGUID],   
		[DistributorGUID],   
		[GroupGUID],   
		[Code],   
		[Name],   
		[Qty],   
		[InQty],   
		[OutQty],   
		[Barcode],   
		[Barcode2],   
		[Barcode3],   
		[Unity],   
		[Unit2],   
		[Unit3],   
		[Price1],   
		[Price2],   
		[Price3],   
		[Price4],   
		[Price5],   
		[Price6],   
		[Price1Unit2],   
		[Price2Unit2],   
		[Price3Unit2],   
		[Price4Unit2],   
		[Price5Unit2],   
		[Price6Unit2],   
		[Price1Unit3],   
		[Price2Unit3],   
		[Price3Unit3],   
		[Price4Unit3],   
		[Price5Unit3],   
		[Price6Unit3],   
		[Unit2Fact],   
		[Unit3Fact],   
		[DefUnit],   
		[SNFlag],   
		[ForceInSN],   
		[ForceOutSN], 
		[MatTemplateGUID],
		[BonusOne],	
		[Bonus],
		[VAT]
	)   
	SELECT        
		[GUID],   
		@PDAGUID,   
		[GroupGUID],        
		[Code],        
		[Name],        
		[Qty],   
		0,   
		0,   
		[BarCode],        
		[BarCode2],        
		[BarCode3],        
		[Unity],        
		[Unit2],        
		[Unit3],        
		[Price1],        
		[Price2],        
		[Price3],        
		[Price4],        
		[Price5],        
		[Price6],        
		[Price1Unit2],        
		[Price2Unit2],        
		[Price3Unit2],        
		[Price4Unit2],        
		[Price5Unit2],        
		[Price6Unit2],        
		[Price1Unit3],        
		[Price2Unit3],        
		[Price3Unit3],        
		[Price4Unit3],        
		[Price5Unit3],        
		[Price6Unit3],        
		[Unit2Fact],        
		[Unit3Fact],        
		[DefUnit],   
		[SNFlag],   
		[ForceInSN],   
		[ForceOutSN], 
		[MatTemplateGUID],	   
		[BonusOne],	
		[Bonus],
		[VAT]
	FROM   
		#MatTbl AS [mt]  
	------------------------------------   
	INSERT INTO DistDeviceMS000  
		(  
			[GUID],  
			[DistributorGUID],  
			[MatGUID],  
			[StoreGUID],  
			[Qty],  
			[InQty],  
			[OutQty]  
		)  
	SELECT   
		[Guid],  
		@PDAGUID,  
		[MatGuid],  
		[StoreGUID],  
		[Qty],  
		0,  
		0  
	FROM   
		#msTbl  
	------------------------------------   
	------- GetSN Mats   
	------------------------------------   
	---  Export Stores  
	IF (@ExportStoreFlag = 1 AND @ExportStoreGUID <> 0x0)  
	BEGIN  
		INSERT INTO DistDeviceSt000	  
				(	  
					[stGuid],   
					[DistributorGuid],   
					[ParentGuid],   
					[CustGuid],   
					[Name]  
				)  
			SELECT   
					[fn].[Guid],   
					@PDAGuid,   
					[st].[stParent],   
					ISNULL([cu].[cuGuid], 0x0),   
					[st].[stName]   
			FROM   
				dbo.fnGetStoresList(@ExportStoreGuid) AS [fn]  
				INNER JOIN [vwSt]	AS [st] ON [st].[stGuid] = [fn].[Guid]  
				LEFT JOIN [vwcu]	AS [cu] ON [cu].[cuAccount] = [st].[stAccount]  
	END  
	DROP table #GroupTbl   
	DROP table #MatTbl   
	--------------------------------------  
/* 
EXEC prcPDABilling_InitMat 'F8CE62D7-8E6A-47A4-914B-BAA89AB433B2' 
SELECT * from DistDeviceMt000 
*/ 

#################################################################
#END