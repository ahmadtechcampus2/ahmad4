#################################################################
CREATE PROC prcPDAStockTransfer_Init
AS 
	SET NOCOUNT ON

	IF EXISTS (select * from dbo.sysobjects where id = object_id(N'[dbo].[PDAStTr_Bu]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)  
		DROP TABLE PDAStTr_Bu

	CREATE TABLE PDAStTr_Bu(
		Guid		UNIQUEIDENTIFIER,
		TypeGuid	UNIQUEIDENTIFIER,
		StoreGuid	UNIQUEIDENTIFIER,
		Date		DateTime,
		Notes		NVARCHAR(200) COLLATE ARABIC_CI_AI,
		Number		INT,
		PRIMARY KEY (Guid)
	)

	IF EXISTS (select * from dbo.sysobjects where id = object_id(N'[dbo].[PDAStTr_Bi]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)  
		DROP TABLE PDAStTr_Bi

	CREATE TABLE PDAStTr_Bi(
		Number		INT,
		Guid		UNIQUEIDENTIFIER,
		ParentGuid	UNIQUEIDENTIFIER,
		StoreGuid	UNIQUEIDENTIFIER,
		MatGuid		UNIQUEIDENTIFIER,
		Qty			FLOAT,
		Unity		INT,
		Notes		NVARCHAR(200) COLLATE ARABIC_CI_AI,
		PRIMARY KEY (Guid)
	)
	IF EXISTS (select * from dbo.sysobjects where id = object_id(N'[dbo].[PDAStTr_Ts]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)  
		DROP TABLE PDAStTr_Ts

	CREATE TABLE PDAStTr_Ts(
		Guid		UNIQUEIDENTIFIER,
		OutBillGuid	UNIQUEIDENTIFIER,
		InBillGuid	UNIQUEIDENTIFIER,
		PRIMARY KEY (Guid)
	)
	

/*
	DELETE FROM PDAStTr_Bu
	DELETE FROM PDAStTr_Bi
	DELETE FROM PDAStTr_Ts
*/
#################################################################
CREATE PROC prcPDAStockTransfer_GetStores
	@DeviceName	NVARCHAR(100)
AS

	DECLARE @UserName	NVARCHAR(100)
	SELECT TOP 1 @UserName = LoginName From us000 Where bAdmin = 1  
	EXEC prcConnections_Add2 @UserName 
		
	DECLARE @StoreGuid	UNIQUEIDENTIFIER
	Select @StoreGuid	 = StoreGuid From pl000 WHERE PalmUserName = @DeviceName


	Select 
		st.Guid, st.Code, st.Name
	From 
		st000 AS st
		INNER JOIN dbo.fnGetStoresList(@StoreGuid) AS fn ON fn.Guid = st.Guid
	ORDER By 
		st.Code

-- Exec prcConnections_Add2 'ãÏíÑ'
-- Exec prcPDAStockTransfer_GetStores 'Test'
#################################################################
CREATE PROC prcPDAStockTransfer_GetMatsStores
	@DeviceName	NVARCHAR(100) 
AS 
	DECLARE @UserName	NVARCHAR(100) 
	SELECT TOP 1 @UserName = LoginName From us000 Where bAdmin = 1   
	EXEC prcConnections_Add2 @UserName  
		 
	DECLARE @StoreGuid	UNIQUEIDENTIFIER 
	Select @StoreGuid	 = PrivateStoreGuid From pl000 WHERE PalmUserName = @DeviceName 
	Select  
		ms.MatGuid, ms.StoreGuid, ms.Qty, 0 AS InQty, 0 AS OutQty
	From  
		ms000 AS ms
		INNER JOIN dbo.fnGetStoresList(@StoreGuid) AS fn ON fn.Guid = ms.StoreGuid 
	Where 
		ms.Qty > 0
	ORDER By 
		ms.StoreGuid	
#################################################################
CREATE PROC prcPDAStockTransfer_GetMats
	@DeviceName	NVARCHAR(100) 
AS 
	DECLARE @UserName	NVARCHAR(100) 
	SELECT TOP 1 @UserName = LoginName From us000 Where bAdmin = 1   
	EXEC prcConnections_Add2 @UserName  
		 
	DECLARE @ExportEmptyMaterial	BIT,
		@StoreGuid		UNIQUEIDENTIFIER
	Select @ExportEmptyMaterial = bExportEmptyMaterial, @StoreGuid = PrivateStoreGuid From pl000 WHERE PalmUserName = @DeviceName 

	SELECT 
		mt.Guid, mt.Code, mt.Name, mt.GroupGuid, ISNULL(ms.Qty, 0) AS Qty, mt.Unity, mt.Unit2, mt.Unit3, Unit2Fact, Unit3Fact, mt.Barcode, mt.Barcode2, mt.Barcode3, mt.Whole, mt.Half, mt.Vendor, mt.Export, mt.Retail, mt.EndUser, mt.LastPrice, mt.AvgPrice, mt.Whole2, mt.Half2, mt.Vendor2, mt.Export2, mt.Retail2, mt.EndUser2, mt.LastPrice2, (mt.AvgPrice * Unit2Fact) AS AvgPrice2, mt.Whole3, mt.Half3, mt.Vendor3, mt.Export3, mt.Retail3, mt.EndUser3, mt.LastPrice3, (mt.AvgPrice * Unit3Fact) AS AvgPrice3
	FROM 
		mt000 As mt 
		LEFT OUTER JOIN ms000 As ms On ms.MatGuid = mt.Guid AND ms.StoreGuid = @StoreGuid
	Where 
		(ISNULL(ms.Qty, 0) > 0 AND  @ExportEmptyMaterial = 0) OR (@ExportEmptyMaterial = 1)
#################################################################
CREATE PROC prcPDAStockTransfer_GetGroups
	@DeviceName	NVARCHAR(100) 
AS 

	SET NOCOUNT ON

	DECLARE @UserName	NVARCHAR(255) 
	SELECT TOP 1 @UserName = LoginName From us000 Where bAdmin = 1   
	EXEC prcConnections_Add2 @UserName
	--------------------------------------------------------------------
	DECLARE @ExportEmptyMaterial	BIT
	DECLARE @StoreGuid		UNIQUEIDENTIFIER

	Select
		@ExportEmptyMaterial = bExportEmptyMaterial, 
		@StoreGuid = PrivateStoreGuid 
	From
		pl000
	WHERE
		PalmUserName = @DeviceName
	--------------------------------------------------------------------
	DECLARE	 @GroupGUID UNIQUEIDENTIFIER
	Set @GroupGUID = 0x0
	SELECT     
		@GroupGUID = ISNULL([GroupGUID], 0x0)
 	FROM     
		[vwPl]    
	WHERE     
		[PalmUserName] = @DeviceName
	-----------------------------------
	CREATE TABLE #GroupTbl(               
		[grGUID] 	uniqueidentifier,      
		[ParentGUID] 	uniqueidentifier,      
		[Name] 		NVARCHAR(255)  COLLATE Arabic_CI_AI,      
		[Flag] 		int,    
		[Level] 	int    
	)
	------------------------------------    
	CREATE TABLE #MatTbl(      
		[GUID] 		uniqueidentifier,         
		[GroupGUID] 	uniqueidentifier
	)   	   
	------------------------------------    
	if (@GroupGUID = 0x0)
	Begin	
		INSERT INTO #GroupTbl
		SELECT [grGUID] , [grParent], [grName], 0, 0 From [vwGr]
	End
	else                       
	Begin
		INSERT INTO #GroupTbl
		SELECT [grGUID], [grParent], [grName], 0 , 0
		From [vwGr] 
		INNER JOIN dbo.fnGetGroupsOfGroup(@GroupGUID) AS f ON [vwGr].[grGUID] = f.GUID
	End
	------------------------------------    
	INSERT INTO #MatTbl                       
	(              
		[GUID],              
		[GroupGUID]
	)              
	SELECT                
		[mt].[mtGUID],               
		[mt].[mtGroup]			    
	FROM          
		[vwMt] AS mt
		INNER JOIN dbo.fnGetGroupsOfGroup(@GroupGUID) AS f ON [mt].[mtGroup] = [f].[GUID]   
	------------------------------------
	-- Delete Empty Group       
	while EXISTS (    
			SELECT 
				grGUID 
			FROM 
				#GroupTbl     
			WHERE     
				grGUID NOT IN (SELECT DISTINCT GroupGUID FROM #MatTbl) AND     
				grGUID NOT IN (SELECT DISTINCT ParentGUID FROM #GroupTbl)    
		      )    
		DELETE 
			#GroupTbl       
		WHERE       
			grGUID NOT IN (SELECT DISTINCT GroupGUID FROM #MatTbl) 
			AND
			grGUID NOT IN (SELECT DISTINCT ParentGUID FROM #GroupTbl)    

	UPDATE #GroupTbl SET ParentGUID = 0x0 WHERE grGUID = @GroupGUID  
	----------------------------------------------------------------------------

	-- Calc MatGroup Flag       
	UPDATE #GroupTbl       
	SET       
		Flag = 1,     
		[Level] = 2     
	WHERE       
		grGUID IN (SELECT GroupGUID FROM #MatTbl)       
	UPDATE #GroupTbl    
	SET       
		Flag = 0,     
		[Level] = 1     
	WHERE       
		grGUID IN (SELECT ParentGUID FROM #GroupTbl)  
	----------------------------------------------------------------------------
	SELECT 
		[grGUID], 
		[ParentGUID],    
		[Name],    
		[Flag],    
		[Level]  
	FROM 
		#GroupTbl

	DROP table #GroupTbl    
	DROP table #MatTbl
#################################################################

#END