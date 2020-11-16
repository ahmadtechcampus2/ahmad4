########################################
## prcDistGetMatOfDistributor
CREATE PROCEDURE prcDistGetMatOfDistributor
		@PalmUserName NVARCHAR(250) 
AS
	SET NOCOUNT ON     

	DECLARE @DistributorGUID	uniqueidentifier,  
			@GroupGUID 			uniqueidentifier,  
			@MatCondGuid		uniqueidentifier,
			@MatCondId 			int,  
			@MatSortFld 		NVARCHAR(250),  
			@StoreGUID 			uniqueidentifier,  
			@bExportSerialNum 	bit,  
			@bExportEmptyMaterial	bit,
			@PrintPrice		INT  

	SELECT 
			@DistributorGUID 		= GUID,
			@GroupGUID 		 		= MatGroupGUID, 
			@MatCondId 				= MatCondId,
			@MatCondGuid			= MatCondGuid, 
			@MatSortFld 			= MatSortFld, 
			@StoreGUID 				= StoreGUID,
			@bExportSerialNum 		= ExportSerialNumFlag, 
			@bExportEmptyMaterial 	= ExportEmptyMaterialFlag, 
			@PrintPrice				= ISNULL(PrintPrice, 0)
	FROM 
		vwDistributor 
	WHERE 
		PalmUserName = @PalmUserName  

	CREATE TABLE #GroupTbl
		(           
			[ID] 		uniqueidentifier,  
			[ParentID] 	uniqueidentifier,  
			[Name] 		NVARCHAR(255)  COLLATE Arabic_CI_AI,  
			[Code] 		NVARCHAR(100)  COLLATE Arabic_CI_AI,
			[Flag] 		int,  
			[Level] 	int
		)       
	CREATE TABLE #MatTemplates 
		( 
			Guid		UNIQUEIDENTIFIER, 
			Number		INT, 
			Name		NVARCHAR(255) COLLATE ARABIC_CI_AI, 
			GroupGuid	UNIQUEIDENTIFIER 
		) 
	CREATE TABLE #TemplatesDetail 
		( 
			TemplateGuid	UNIQUEIDENTIFIER, 
			GroupGuid	UNIQUEIDENTIFIER 
		) 
           
	CREATE TABLE #MatCond( GUID uniqueidentifier, Security INT)     
	INSERT INTO #MatCond EXEC prcPalm_GetMatsList @MatCondId , @MatCondGuid  

	CREATE TABLE #MatTbl
		(  
			GUID 		uniqueidentifier,     
			GroupID 	uniqueidentifier,     
			Code 		NVARCHAR(255)  COLLATE Arabic_CI_AI,           
			BarCode 	NVARCHAR(255) COLLATE Arabic_CI_AI,            
			BarCode2 	NVARCHAR(255) COLLATE Arabic_CI_AI,            
			BarCode3 	NVARCHAR(255) COLLATE Arabic_CI_AI,            
			[Name] 		NVARCHAR(255) COLLATE Arabic_CI_AI,            
			[LatinName] NVARCHAR(255) COLLATE Arabic_CI_AI,        
			Price1 		float,            
			Price2 		float,            
			Price1Unit2 float,            
			Price2Unit2 float,            
			Price1Unit3 float,            
			Price2Unit3 float,            
			Vendor 		float,            
			Export 		float,            
			Retail 		float,            
			EndUser 	float ,            
			Unity 		NVARCHAR(255) COLLATE Arabic_CI_AI,            
			Unit2 		NVARCHAR(255) COLLATE Arabic_CI_AI,            
			Unit3 		NVARCHAR(255) COLLATE Arabic_CI_AI,            
			Unit2Fact 	float,   
			Unit3Fact 	float,   
			Qty 		float,   
			DefUnit 	int,
			BonusOne 	float, 
			Bonus 		float,
			MatTemplateGUID	UNIQUEIDENTIFIER,
			PrintPrice		FLOAT,
			PrintPriceUnit2	FLOAT,
			PrintPriceUnit3	FLOAT
		)  
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[PalmMatTbl]') and OBJECTPROPERTY(id, N'IsUserTable') = 1) 
		DROP TABLE PalmMatTbl 
	CREATE TABLE PalmMatTbl(  
		ID			int,   
		GroupID 	int,   
		Code 		NVARCHAR(255)  COLLATE Arabic_CI_AI,           
		BarCode 	NVARCHAR(255) COLLATE Arabic_CI_AI,            
		BarCode2 	NVARCHAR(255) COLLATE Arabic_CI_AI,            
		BarCode3 	NVARCHAR(255) COLLATE Arabic_CI_AI,            
		[Name] 		NVARCHAR(255) COLLATE Arabic_CI_AI,            
		[LatinName] NVARCHAR(255) COLLATE Arabic_CI_AI,        
		Price1 		float,            
		Price2 		float,            
		Price1Unit2 float,            
		Price2Unit2 float,            
		Price1Unit3 float,            
		Price2Unit3 float,            
		Vendor 		float,            
		Export 		float,            
		Retail 		float,            
		EndUser 	float ,            
		Unity 		NVARCHAR(255) COLLATE Arabic_CI_AI,            
		Unit2 		NVARCHAR(255) COLLATE Arabic_CI_AI,            
		Unit3 		NVARCHAR(255) COLLATE Arabic_CI_AI,            
		Unit2Fact 	float,            
		Unit3Fact 	float,            
		Qty 		float,            
		DefUnit 	int,            
		BonusOne 	float, 
		Bonus 		float,
		MatIndex 	INT IDENTITY(0,1),
		MatTemplateID	INT,	   
		PrintPrice 		float,            
		PrintPriceUnit2	float,            
		PrintPriceUnit3	float            
	) 

	if (@GroupGUID = 0x0)                   
		INSERT INTO #GroupTbl                   
			SELECT grGUID , grParent, grName, grCode, 0, 0 From vwGr                   
	else                   
		INSERT INTO #GroupTbl     
			SELECT grGUID, grParent, grName, grCode, 0 , 0
			From vwGr INNER JOIN dbo.fnGetGroupsOfGroup(@GroupGUID) AS f ON vwGr.grGUID = f.GUID   
--SELECT * FROM #GroupTbl   

	INSERT INTO #MatTemplates 
		SELECT DISTINCT 
			t.Guid, t.Number, t.Name, t.GroupGuid 
		FROM DistMatTemplates000 AS t 
			INNER JOIN DistDd000 AS Dd ON Dd.ObjectGuid = t.Guid  
		WHERE 	Dd.DistributorGuid  = @DistributorGUID	AND 
			Dd.ObjectType = 3 
		ORDER BY t.Number 

	DECLARE @CTemplates	CURSOR, 
		@TGuid	UNIQUEIDENTIFIER, 
		@GGuid	UNIQUEIDENTIFIER 
	SET @CTemplates = CURSOR FAST_FORWARD FOR 
		SELECT Guid, GroupGuid FROM #MatTemplates ORDER BY Number 
	OPEN @CTemplates FETCH FROM @CTemplates INTO @TGuid, @GGuid 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		INSERT INTO #TemplatesDetail 
			 SELECT @TGuid, Guid FROM fnGetGroupsList( @GGuid)  
		FETCH FROM @CTemplates INTO @TGuid, @GGuid 
	END 
	CLOSE @CTemplates DEALLOCATE @CTemplates 
	---------------------------------------------------------------------------------------
	--- New For Dist Prices
	--- ÃÂ«“ «·»«·„ ÌÕ„· ›ﬁÿ ”⁄—Ì‰ „‰ »ÿ«ﬁ… «·„«œ… ·–·ﬂ Ì „  Ã«Â· »«ﬁÌ «·√”⁄«— «·„Õœœ… ÊÌ√Œ– √Ê· ”⁄—Ì‰ „‰ «·ﬁ«∆„… ›ﬁÿ
	DECLARE @Price1 INT, @Price2 INT
	SELECT @Price1 = PriceId From dbo.fnDistGetDistPrices( @DistributorGUID) WHERE Id = 1
	SELECT @Price2 = PriceId From dbo.fnDistGetDistPrices( @DistributorGUID) WHERE Id = 2
	SET @Price1 = ISNULL(@Price1, 0) 
	SET @Price2 = ISNULL(@Price2, 0) 
	IF @Price1 = 0 AND @Price2 = 0  -- Ê–·ﬂ ··»Ì«‰«  «·ﬁœÌ„… «· Ì ·«  ÕÊÌ √”⁄«— „Õœœ… ›Ì ﬁ«∆„… «·√”⁄«— «·„Õœœ… ›Ì »ÿ«ﬁ… ÊÕœ… «· Ê“Ì⁄
	BEGIN
		SET @Price1 = 1
		SET @Price2 = 2
	END
	---------------------------------------------------------------------------------------

	INSERT INTO #MatTbl                   
	(          
		GUID,          
		GroupID,          
		Code,          
		BarCode,          
		BarCode2,          
		BarCode3,          
		[Name],          
		LatinName,          
		Price1,          
		Price2,          
		Price1Unit2,          
		Price2Unit2,          
		Price1Unit3,          
		Price2Unit3,          
		Vendor,          
		Export,          
		Retail,          
		EndUser,          
		Unity,          
		Unit2,          
		Unit3,            
		Unit2Fact,            
		Unit3Fact,            
		Qty,   
		DefUnit,
		BonusOne,
		Bonus,
		MatTemplateGUID,
		PrintPrice,
		PrintPriceUnit2,
		PrintPriceUnit3	
	)          
	SELECT            
		mt.mtGUID,           
		mt.mtGroup,           
		mt.mtCode,           
		mt.mtBarCode,           
		mt.mtBarCode2,          
		mt.mtBarCode3,          
		mt.mtName,           
		mt.mtLatinName,  
		/*         
		mt.mtWhole AS Price1,           
		mt.mtHalf AS Price2,    
		mt.mtWhole2 AS Price1Unit2,    
		mt.mtHalf2 AS Price2Unit2,    
		mt.mtWhole3 AS Price1Unit3,    
		mt.mtHalf3 AS Price2Unit3,    
		*/
		Price1 = CASE @Price1 WHEN 1 THEN mt.mtWhole WHEN 2 THEN mt.mtHalf WHEN 3 THEN mtVendor WHEN 4 THEN mtExport WHEN 5 THEN mtRetail WHEN 6 THEN mtEndUser ELSE 0 END, -- mtWhole END,
		Price2 = CASE @Price2 WHEN 1 THEN mt.mtWhole WHEN 2 THEN mt.mtHalf WHEN 3 THEN mtVendor WHEN 4 THEN mtExport WHEN 5 THEN mtRetail WHEN 6 THEN mtEndUser ELSE 0 END, -- mtHalf END,
		Price1Unit2 = CASE @Price1 WHEN 1 THEN mt.mtWhole2 WHEN 2 THEN mt.mtHalf2 WHEN 3 THEN mtVendor2 WHEN 4 THEN mtExport2 WHEN 5 THEN mtRetail2 WHEN 6 THEN mtEndUser2 ELSE 0 END, -- mtWhole2 END,
		Price2Unit2 = CASE @Price2 WHEN 1 THEN mt.mtWhole2 WHEN 2 THEN mt.mtHalf2 WHEN 3 THEN mtVendor2 WHEN 4 THEN mtExport2 WHEN 5 THEN mtRetail2 WHEN 6 THEN mtEndUser2 ELSE 0 END, -- mtHalf2 END,
		Price1Unit3 = CASE @Price1 WHEN 1 THEN mt.mtWhole3 WHEN 2 THEN mt.mtHalf3 WHEN 3 THEN mtVendor3 WHEN 4 THEN mtExport3 WHEN 5 THEN mtRetail3 WHEN 6 THEN mtEndUser3 ELSE 0 END, -- mtWhole3 END,
		Price2Unit3 = CASE @Price2 WHEN 1 THEN mt.mtWhole3 WHEN 2 THEN mt.mtHalf3 WHEN 3 THEN mtVendor3 WHEN 4 THEN mtExport3 WHEN 5 THEN mtRetail3 WHEN 6 THEN mtEndUser3 ELSE 0 END, -- mtHalf3 END,
		mt.mtVendor,           
		mt.mtExport,           
		mt.mtRetail,           
		mt.mtEndUser,           
		mt.mtUnity,           
		mt.mtUnit2,           
		mt.mtUnit3,           
		mt.mtUnit2Fact,           
		mt.mtUnit3Fact,           
		0,   
		mt.mtDefUnit,
		mt.mtBonusOne,
		mt.mtBonus,
		ISNULL(td.TemplateGUID, 0x0),
		PrintPrice =	  CASE @PrintPrice WHEN 4 THEN [mt].[mtWhole] WHEN 8 THEN [mt].[mtHalf] WHEN 16 THEN [mt].[mtExport] 
									  WHEN 32 THEN [mt].[mtVendor] WHEN 64 THEN [mt].[mtRetail] WHEN 128 THEN [mt].[mtEndUser] 
									  ELSE -1
						END,
		PrintPriceUnit2 = CASE @PrintPrice WHEN 4 THEN [mt].[mtWhole2] WHEN 8 THEN [mt].[mtHalf2] WHEN 16 THEN [mt].[mtExport2] 
									  WHEN 32 THEN [mt].[mtVendor2] WHEN 64 THEN [mt].[mtRetail2] WHEN 128 THEN [mt].[mtEndUser2] 
									  ELSE -1
						END,
		PrintPriceUnit3 = CASE @PrintPrice WHEN 4 THEN [mt].[mtWhole3] WHEN 8 THEN [mt].[mtHalf3] WHEN 16 THEN [mt].[mtExport3] 
									  WHEN 32 THEN [mt].[mtVendor3] WHEN 64 THEN [mt].[mtRetail3] WHEN 128 THEN [mt].[mtEndUser3] 
									  ELSE -1
						END
	FROM      
		vwMt AS mt 
		INNER JOIN #MatCond AS mTcn ON mTcn.GUID = mt.mtGUID 
		INNER JOIN dbo.fnGetGroupsOfGroup(@GroupGUID) AS f ON mt.mtGroup = f.GUID       
		LEFT JOIN DistMe000 AS me ON me.MtGUID = mt.mtGUID 
		LEFT JOIN #TemplatesDetail AS td ON td.GroupGuid = mt.mtGroup
	WHERE  
		me.State = 0 OR me.State IS NULL 


	UPDATE #MatTbl SET Qty = msQty                   
		FROM #MatTbl INNER JOIN vwMs ON GUID = msMatPtr WHERE msStorePtr = @StoreGUID     
	----- Delete Empty Material     
	IF (@bExportEmptyMaterial = 0)     
	BEGIN     
		DELETE #MatTbl WHERE Qty = 0     
	END     
	----- Delete Empty Group   
	UPDATE #GroupTbl SET ParentID = 0x0 WHERE ParentID = @GroupGUID   
	DELETE #GroupTbl WHERE ID = @GroupGUID 
	while EXISTS (SELECT * FROM #GroupTbl   WHERE   ID NOT IN (SELECT DISTINCT GroupID FROM #MatTbl) AND ID NOT IN (SELECT DISTINCT ParentID FROM #GroupTbl)) 
		DELETE #GroupTbl    
		WHERE    
			ID NOT IN (SELECT DISTINCT GroupID FROM #MatTbl) AND  
			ID NOT IN (SELECT DISTINCT ParentID FROM #GroupTbl) 
	----- Calc MatGroup Flag   
	UPDATE #GroupTbl   
	SET   
		Flag = 1, 
		[Level] = 2 
	WHERE   
		ID IN (SELECT GroupID FROM #MatTbl)   
	UPDATE #GroupTbl   
	SET   
		Flag = 0, 
		[Level] = 1 
	WHERE   
		ID IN (SELECT ParentID FROM #GroupTbl)   
	----- Calc Serial Number     
	CREATE TABLE #SerialList
	(     
		MatGUID 	uniqueidentifier,     
		SN 			NVARCHAR(100) COLLATE ARABIC_CI_AI,      
		InCount 	Int,      
		OutCount 	int     
	)     
	IF (@bExportSerialNum = 1)     
	BEGIN     
		CREATE TABLE #InSerial (MatGUID uniqueidentifier, SN NVARCHAR(100) COLLATE ARABIC_CI_AI, InCount INT)     
		CREATE TABLE #OutSerial (MatGUID uniqueidentifier, SN NVARCHAR(100) COLLATE ARABIC_CI_AI, OutCount INT)     
		     
		INSERT INTO #InSerial     
		SELECT     
			sn.MatPtr,     
			sn.SN,     
			Count(sn.SN) AS InCount     
		FROM     
			vwbi AS bi 
			INNER JOIN vwSN AS sn ON bi.biGUID = sn.InItem     
			INNER JOIN #MatTbl AS mt ON mt.GUID = bi.biMatPtr     
		WHERE     
			bi.biStorePtr = @StoreGUID     
		GROUP BY     
			sn.MatPtr,     
			sn.SN     
		     
		INSERT INTO #OutSerial     
		SELECT     
			sn.MatPtr,     
			sn.SN,     
			Count(sn.SN) AS OutCount     
		FROM     
			vwbi AS bi 
			INNER JOIN vwSN 	AS sn ON bi.biGUID = sn.OutItem     
			INNER JOIN #MatTbl 	AS mt ON mt.GUID = bi.biMatPtr     
		WHERE     
			bi.biStorePtr = @StoreGUID     
		GROUP BY     
			sn.MatPtr,     
			sn.SN     
		     
		INSERT INTO #SerialList     
		SELECT     
			[in].MatGUID,     
			[in].SN,     
			[in].InCount,     
			ISNULL([out].OutCount,0) AS OutCount     
		FROM     
			#InSerial AS [in] LEFT JOIN #OutSerial AS [out] ON [in].MatGUID = [out].MatGUID AND [in].SN = [out].SN	     
		DROP TABLE #InSerial     
		DROP TABLE #OutSerial     
	END     
----- Return Result     
--SELECT * FROM #GroupTbl   
--------- 1     
	INSERT INTO PalmGUID     
	SELECT DISTINCT     
		gr.ID     
	FROM     
		#GroupTbl AS gr LEFT JOIN PalmGUID AS pg ON pg.GUID = gr.ID     
	WHERE     
		pg.GUID IS NULL     

	INSERT INTO PalmGUID     
	SELECT DISTINCT     
		mt.GUID     
	FROM     
		#MatTemplates AS mt LEFT JOIN PalmGUID AS pg ON pg.GUID = mt.GUID     
	WHERE     
		pg.GUID IS NULL  

--------- 
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[PalmGroupTbl]') and OBJECTPROPERTY(id, N'IsUserTable') = 1) 
		DROP TABLE PalmGroupTbl 
	CREATE TABLE PalmGroupTbl ( 
		GUID 		uniqueidentifier, 
		ParentGUID  uniqueidentifier, 
		[ID] 		int,
		[ParentID] 	int,
		[Code] 		NVARCHAR(100) COLLATE ARABIC_CI_AI,
		[Index] 	int IDENTITY(0, 1) 
	) 
	
--SELECT code, ID, ParentID, 0, 0 FROM #GroupTbl ORDER BY code
	
	INSERT INTO PalmGroupTbl SELECT ID, ParentID, 0, 0, [Code] FROM #GroupTbl ORDER BY Code
	
	UPDATE PalmGroupTbl SET [ID] = pg.Number 
	FROM PalmGUID AS pg, PalmGroupTbl AS pgt 
	WHERE  
		pgt.GUID = pg.GUID 
	UPDATE PalmGroupTbl SET [ParentID] = pg.Number 
	FROM PalmGUID AS pg, PalmGroupTbl AS pgt 
	WHERE  
		pgt.ParentGUID = pg.GUID 
	SELECT   
		pg.Number AS ID,    
		isnull(pg1.Number , 0) AS ParentID,    
		gr.Name,   
		gr.Flag,  
		gr.Level, 
		pgt.[Index] 
	FROM    
		#GroupTbl AS gr    
		INNER JOIN PalmGUID AS pg ON pg.GUID = gr.ID     
		LEFT JOIN PalmGUID AS pg1 ON pg1.GUID = gr.ParentID     
		INNER JOIN PalmGroupTbl AS pgt ON pgt.GUID = gr.ID 
	ORDER BY 
		pgt.[Index] 
--------- 2     
	INSERT INTO PalmGUID     
	SELECT DISTINCT     
		mt.GUID     
	FROM     
		#MatTbl AS mt LEFT JOIN PalmGUID AS pg ON pg.GUID = mt.GUID     
	WHERE     
		pg.GUID IS NULL  
-----   
	-- PRINT @MatSortFld 
	if (ISNULL(@MatSortFld, '') <> '')     
	begin     
		DECLARE @Str AS NVARCHAR(2048)       
		SET @Str =      
		'INSERT INTO PalmMatTbl(   
				ID,   
				GroupID,   
				Code,   
				BarCode,   
				BarCode2,   
				BarCode3,   
				[Name],   
				[LatinName],   
				Price1,   
				Price2,   
				Price1Unit2,   
				Price2Unit2,   
				Price1Unit3,   
				Price2Unit3,   
				Vendor,   
				Export,   
				Retail,   
				EndUser,   
				Unity,   
				Unit2,   
				Unit3,   
				Unit2Fact,   
				Unit3Fact,   
				Qty,   
				DefUnit,
				BonusOne,
				Bonus,
				MatTemplateID,
				PrintPrice,
				PrintPriceUnit2,
				PrintPriceUnit3
			)   
			SELECT      
				pg1.Number AS ID,     
				pg2.Number AS GroupID,     
				Code,     
				BarCode,     
				BarCode2,     
				BarCode3,     
				[Name],     
				[LatinName],     
				Price1,     
				Price2,     
				Price1Unit2,     
				Price2Unit2,     
				Price1Unit3,     
				Price2Unit3,     
				Vendor,     
				Export,     
				Retail,     
				EndUser,     
				Unity,     
				Unit2,     
				Unit3,     
				Unit2Fact,     
				Unit3Fact,     
				Qty,   
				DefUnit,
				BonusOne, 
				Bonus,
				pg3.Number	AS MatTemplateID,
				PrintPrice,
				PrintPriceUnit2,
				PrintPriceUnit3
			FROM      
				#MatTbl AS mt   
				INNER JOIN PalmGUID AS pg1 ON pg1.GUID = mt.GUID     
				INNER JOIN PalmGUID AS pg2 ON pg2.GUID = mt.GroupID 
				INNER JOIN PalmGUID AS pg3 ON pg3.GUID = mt.MatTemplateGUID 
			ORDER BY '     
		SET @Str = @Str + @MatSortFld     
		-- PRINT @MatSortFld 
		-- PRINT @Str    
		EXECUTE (@Str) 	       
	end     
	else   
		INSERT INTO PalmMatTbl(   
			ID,   
			GroupID,   
			Code,   
			BarCode,   
			BarCode2,   
			BarCode3,   
			[Name],   
			[LatinName],   
			Price1,   
			Price2,   
			Price1Unit2,   
			Price2Unit2,   
			Price1Unit3,   
			Price2Unit3,   
			Vendor,   
			Export,   
			Retail,   
			EndUser,   
			Unity,   
			Unit2,   
			Unit3,   
			Unit2Fact,   
			Unit3Fact,   
			Qty,   
			DefUnit,
			BonusOne, 
			Bonus,
			MatTemplateID,
			PrintPrice,	
			PrintPriceUnit2,	
			PrintPriceUnit3	
		)   
		SELECT     
			pg1.Number AS ID,     
			pg2.Number AS GroupID,     
			Code,     
			BarCode,     
			BarCode2,     
			BarCode3,     
			[Name],     
			[LatinName],     
			Price1,     
			Price2,     
			Price1Unit2,     
			Price2Unit2,     
			Price1Unit3,     
			Price2Unit3,     
			Vendor,     
			Export,     
			Retail,     
			EndUser,     
			Unity,     
			Unit2,     
			Unit3,     
			Unit2Fact,     
			Unit3Fact,     
			Qty,   
			DefUnit,
			BonusOne, 
			Bonus,
			pg3.Number AS MatTemplateID,
			PrintPrice,
			PrintPriceUnit2,
			PrintPriceUnit3
		FROM     
			#MatTbl AS mt    
			INNER JOIN PalmGUID AS pg1 ON pg1.GUID = mt.GUID     
			INNER JOIN PalmGUID AS pg2 ON pg2.GUID = mt.GroupID     
			INNER JOIN PalmGUID AS pg3 ON pg3.GUID = mt.MatTemplateGUID
----   
	SELECT * FROM PalmMatTbl ORDER BY MatIndex   
--------- 3     
	INSERT INTO PalmGUID     
	SELECT DISTINCT     
		sn.MatGUID     
	FROM     
		#SerialList AS sn    
		LEFT JOIN PalmGUID AS pg ON pg.GUID = sn.MatGUID     
	WHERE     
		sn.MatGUID IS NULL     
---------- 4   
	SELECT     
		mt.MatIndex AS MatIndex,     
		mt.GroupID AS GroupID   
	FROM     
		PalmMatTbl AS mt    
	ORDER BY [mt].[GroupID] ASC, [mt].[MatIndex] ASC
--------   
	SELECT      
		mt.MatIndex AS MatIndex,      
		mt.Barcode AS Barcode
	FROM
		PalmMatTbl AS mt
	ORDER BY [mt].[Barcode] ASC
--------   
	SELECT      
		mt.MatIndex AS MatIndex,      
		mt.Barcode2 AS Barcode
	FROM
		PalmMatTbl AS mt
	ORDER BY [mt].[Barcode2] ASC
--------   
	SELECT      
		mt.MatIndex AS MatIndex,      
		mt.Barcode3 AS Barcode
	FROM
		PalmMatTbl AS mt
	ORDER BY [mt].[Barcode3] ASC
--------  
	/* 
	SELECT      

		pg.Number AS MatPtr,     
		sn.SN     
	FROM     
		#SerialList AS sn INNER JOIN    
		PalmGUID AS pg ON pg.GUID = sn.MatGUID     
	WHERE     
		(InCount - OutCount) > 0      
	ORDER BY     
		MatPtr, sn.SN     
	*/ 
------------   
	DROP table #GroupTbl
	DROP table #MatTbl                   
	DROP table #SerialList   
/*
prcConnections_Add2 '„œÌ—'
EXEC prcDistGetMatOfDistributor 'Inventory2'
*/
#############################
#END
