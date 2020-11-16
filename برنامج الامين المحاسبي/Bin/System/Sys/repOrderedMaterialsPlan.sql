###############################################################################
CREATE PROCEDURE prcGetManufacMaterialTree
	@MATGUID    [UNIQUEIDENTIFIER],  
	@ClassPtr 	[NVARCHAR] (255) = '', 
	@PARENTPATH [NVARCHAR](max) = '',
	@ParentParentGUID [UNIQUEIDENTIFIER] = 0x00,
	@NeededQty [INT] = 1
AS 
BEGIN  
	SET NOCOUNT ON   
	DECLARE @MAINFORM  [UNIQUEIDENTIFIER] 
	DECLARE @SELECTED UNIQUEIDENTIFIER 
	DECLARE @MAINSELECTED UNIQUEIDENTIFIER 
	DECLARE @MAINSELECTEDQTY FLOAT 
	DECLARE @MAT UNIQUEIDENTIFIER 
	DECLARE @CNT INT 
	DECLARE @PPATH [NVARCHAR](1000) 
	--DECLARE @PLEVEL INT
	DECLARE @PARENTQTY FLOAT 
	DECLARE @PARENTQTYINFORM FLOAT 
	
	SELECT TOP 1 
		@MAINFORM = [PARENTGUID]   
	FROM 
		MI000 MI  
		INNER JOIN MN000 MN ON MN.GUID = MI.PARENTGUID
		INNER JOIN FM000 FM on fm.Guid = mn.FormGuid 
	WHERE
		MN.TYPE = 0 
		AND 
		MI.TYPE = 0 
		AND 
		MATGUID = @MATGUID
	ORDER BY
		--MN.[Date] ,
		FM.Number desc

--select @MAINFORM

	IF (@PARENTPATH = '')  --
	BEGIN  
		IF NOT EXISTS (SELECT * FROM tempdb..sysobjects WHERE name = '##TREEBUFFER')  
		CREATE TABLE ##TREEBUFFER  
		(  
			[SELECTEDGUID]          [UNIQUEIDENTIFIER],
			[GUID]                  [UNIQUEIDENTIFIER],
			[PARENTGUID]			[UNIQUEIDENTIFIER], -- Form GUID
			[ParentParentGUID]		[UNIQUEIDENTIFIER], -- Parent Form GUID
			[MATGUID]				[UNIQUEIDENTIFIER],
			[ISHALFREADYMAT]		[BIT],
			[PATH]                  [NVARCHAR](1000),
			[PARENTPATH]            [NVARCHAR](1000),
			--[LEVEL]					[INT],
			[QTY]					[FLOAT],
			[QtyInForm]             [FLOAT],
			[Unit]					[INT],
			[TYPE]                  [INT],
			[IsSemiReadyMat]		[INT],
			[NeededFormsCountTemp]	[FLOAT],
			[IsResultOfFormWithMoreThanOneProducedMaterial] [BIT]
		)  
		SET @PARENTPATH = '0' 
		--SET @PLEVEL = 0 
		SET @MAINSELECTED = @MATGUID 
		SET @PARENTQTY = 1 
		SET @PARENTQTYINFORM = 1 
		
		--SELECT 
		SET 	@MAINSELECTEDQTY =( SELECT TOP 1  MI.QTY 
		FROM 
			MI000 MI 
			INNER JOIN MN000 MN ON MN.[Guid] = MI.ParentGuid 
			INNER JOIN FM000 FM on fm.Guid = mn.FormGuid 
		WHERE 
			MI.[Type] = 0
			AND 
			MN.[Type] = 0 
			AND 
			MI.MatGuid = @MAINSELECTED 
		ORDER BY
			--MN.[Date] ,
			Fm.Number desc
			)
	END 	 
	ELSE 
	BEGIN
		--SELECT 
		SET	@PARENTQTYINFORM = (SELECT TOP 1 MI.QTY 
		FROM 
			MI000 MI 
			INNER JOIN MN000 MN ON MN.Guid = MI.ParentGuid 
			INNER JOIN FM000 FM on fm.Guid = mn.FormGuid 
		WHERE
			MI.Type = 0 
			AND 
			MN.Type = 0
			AND
			MI.MatGuid = @MATGUID
		ORDER BY
			--MN.[Date] ,
			FM.Number desc
			)
	END

	SELECT 
		@PARENTQTY = QTY 
	FROM 
		##TREEBUFFER 
	WHERE 
		MATGuid = @MATGUID 
		
	INSERT INTO ##TREEBUFFER 
	SELECT 
		MI.[GUID], --just a placeholder
		MI.[GUID], 
		MI.PARENTGUID, 
		@ParentParentGUID,
		MI.MATGUID, 
		DBO.ISHALFREADYMAT(MI.MATGUID), 
		@PARENTPATH + '.' + CAST((DBO.ISHALFREADYMAT(MI.MATGUID)) AS NVARCHAR(100)) + CAST((MI.Number) AS NVARCHAR(100)), 
		@PARENTPATH,
		(MI.Qty * @PARENTQTY / CASE WHEN @PARENTQTYINFORM <> 0 THEN @PARENTQTYINFORM ELSE 1 END), 
		MI.Qty, 
		MI.Unity, 
		MI.[TYPE], 
		CASE MI.MatGuid WHEN @MAINSELECTED THEN 1 ELSE 0 END, 
		(@PARENTQTY / CASE WHEN @PARENTQTYINFORM <> 0 THEN @PARENTQTYINFORM ELSE 1 END),
		CASE WHEN (SELECT COUNT(MI2.MatGUID) ProducedMatsCount FROM MI000 MI2 WHERE MI2.[TYPE] = 0 AND MI2.PARENTGUID = MI.ParentGUID) > 1 THEN 1 ELSE 0 END
	FROM   
		MI000 MI 
		INNER JOIN MN000 MN ON MN.GUID = MI.PARENTGUID 
		INNER JOIN FM000 FM ON FM.GUID = MN.FORMGUID 
	WHERE 
		MN.Type = 0 
		AND 
		(MI.TYPE = 1 OR (MI.MatGuid = @MAINSELECTED AND @ClassPtr <> ''))
		AND 
		MI.PARENTGUID = @MAINFORM 
	ORDER BY 
		DBO.ISHALFREADYMAT(MI.MATGUID) 

	SELECT TOP 1  
		@SELECTED = [GUID],  
		@MAT = [MATGUID],  
		@PPATH = [PATH],
		@ParentParentGUID = [ParentGUID] 
	FROM 
		##TREEBUFFER  
	WHERE 
		ISHALFREADYMAT = 1  
	ORDER BY 
		[PATH]            
	
	IF (@SELECTED <> 0X0)  
	BEGIN  
		UPDATE ##TREEBUFFER 
		SET 
			[ISHALFREADYMAT] = 0, 
			[IsSemiReadyMat] = 1 
		WHERE 
			[GUID] = @SELECTED  

		EXEC prcGetManufacMaterialTree @MAT, @ClassPtr, @PPATH, @ParentParentGUID
	END  

	IF (@PARENTPATH = '0')  
	BEGIN  
		SET @CNT = (SELECT COUNT(*) FROM ##TREEBUFFER WHERE ISHALFREADYMAT = 1)  
		IF(@CNT = 0)  
		BEGIN
			UPDATE ##TREEBUFFER 
			SET 
				QtyInForm = MI.Qty 
			FROM 
				MI000 MI, 
				##TREEBUFFER TREE, 
				MN000 MN  
			WHERE 
				TREE.IsSemiReadyMat = 1  
				AND MI.Type = 0  
				AND MI.MatGuid = TREE.MatGuid 
				AND MN.Guid = MI.ParentGuid 
				AND MN.Type = 0 
             
			SELECT 
				@MAINSELECTED SelectedGuid,
				[TREE].[GUID],
				[TREE].[PARENTGUID], 
				[TREE].[ParentParentGUID],
				@ClassPtr ClassPtr, 
				[FM].[Name] AS FORMNAME, 
				[MATGUID], 
				[MT].[NAME] AS MATNAME,
				([TREE].[QTY] / @MAINSELECTEDQTY) * @NeededQty QTY,
				[TREE].[QtyInForm],
				[TREE].[PATH], 
				[TREE].[PARENTPATH], 
				--[TREE].[Level],
				[TREE].[Unit], 
				[TREE].[IsSemiReadyMat], 
				(([TREE].[QTY] / @MAINSELECTEDQTY) / [TREE].[QtyInForm]) * @NeededQty AS [NeededFormsCountTemp],
				[TREE].[IsResultOfFormWithMoreThanOneProducedMaterial]
				--,
				--(DBO.ISHALFREADYMAT(@MATGUID))
			FROM 
				##TREEBUFFER TREE  
				LEFT JOIN MN000 MN ON [MN].[GUID] = [TREE].[PARENTGUID]                   
				LEFT JOIN FM000 FM ON [FM].[GUID] = [MN].[FORMGUID]  
				LEFT JOIN MT000 MT ON [MT].[GUID] = [TREE].[MATGUID]  
			ORDER BY 
				[TREE].[PATH]                 
			
			DROP TABLE ##TREEBUFFER  
		END  
	END  
END
###############################################################################   
CREATE PROCEDURE repOrderedMaterialsPlans
	@OrderGuid		UNIQUEIDENTIFIER = 0x0,
	@FromDate   	DATETIME = '2009-1-1',
	@ToDate     	DATETIME = '2010-10-31',
	@Detailed       BIT = 1,
	@SrcTypes       UNIQUEIDENTIFIER = 0x0, -- „’«œ— «· ﬁ—Ì— 
	@CustomerName  UNIQUEIDENTIFIER = 0x0
	
AS      
	SET NOCOUNT ON      

	if (@OrderGuid <> 0x0 )
	SET @SrcTypes =0x0

	CREATE TABLE [#BillsTypesTbl]
	(
	      [TypeGuid] [UNIQUEIDENTIFIER], 
		  [UserSecurity] [INTEGER], 
		  [UserReadPriceSecurity] 
		  [INTEGER],
		  [UnPostedSecurity] [INTEGER]
	)

    IF (@SrcTypes <> 0x0)
	   INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList2] @SrcTypes
	

	
	CREATE TABLE [#SaleOrders] -- ÿ·»«  «·»Ì⁄
	(
		MaterialGuid	UNIQUEIDENTIFIER,
		BillType		UNIQUEIDENTIFIER,
		[Required]		FLOAT,
		Achived			FLOAT,
		Remainder		FLOAT,
		Fininshed		int,
		Cancle			int
    )			
	
	

	INSERT INTO [#SaleOrders] -- ÿ·»Ì«  «·»Ì⁄
		SELECT * FROM dbo.[fnGetPurchaseOrderQty] (@ToDate, 0x0, 0x0, 1)	
	
		
    CREATE TABLE #OrderedMats
	(
	   CustomerName VARCHAR (255) COLLATE ARABIC_CI_AI,  
	   MatGuid      UNIQUEIDENTIFIER ,
	   ClassPtr     VARCHAR (255) COLLATE ARABIC_CI_AI,
	   OrderGuid    UNIQUEIDENTIFIER ,  
	   DDATE        DATETIME, 
	   QTY          FLOAT
	)  
	-------------------------------------------------------------
	DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();
	--------------------------------------------------------------  
	IF ( @CustomerName <> 0x0 )
	BEGIN
	 if ( @OrderGuid <> 0x0 ) 
	 BEGIN 
	   INSERT INTO #OrderedMats 		    	
	   SELECT CASE @Lang WHEN 0 THEN ISNULL(CU.CustomerName,'') ELSE CASE WHEN ISNULL(CU.LatinName,'') = '' THEN ISNULL(CU.CustomerName,'') ELSE ISNULL(CU.LatinName,'') END END AS CustomerName,BI.MatGuid,CASE @Lang WHEN 0 THEN bt.Name ELSE CASE WHEN bt.LatinName = '' THEN bt.Name ELSE bt.LatinName END END  +' - '+ CAST(bu.Number as NVARCHAR(MAX)) ClassPtr,
	          BU.guid OrderGuid, OrderInfo.ADDATE  DDATE, SUM(BI.Qty) AS QTY    
			FROM BI000 BI   
		    INNER JOIN BU000 BU ON BU.GUID = BI.PARENTGUID   
		    INNER JOIN BT000 BT ON BT.GUID = BU.TYPEGUID   
			INNER JOIN cu000 CU ON CU.guid = @CustomerName AND CU.CustomerName = BU.Cust_Name
			INNER JOIN orAddInfo000 OrderInfo ON OrderInfo.ParentGuid = BU.GUID
		WHERE  @OrderGuid = bu.GUID
			  AND @SrcTypes = 0X0
			  AND BT.TYPE IN (5)   
			  AND @Detailed = 1
			  AND OrderInfo.Finished = 0 
			  AND OrderInfo.Add1 = 0
		GROUP BY CASE @Lang WHEN 0 THEN ISNULL(CU.CustomerName,'') ELSE CASE WHEN ISNULL(CU.LatinName,'') = '' THEN ISNULL(CU.CustomerName,'') ELSE ISNULL(CU.LatinName,'') END END ,BI.MatGuid,CASE @Lang WHEN 0 THEN bt.Name ELSE CASE WHEN bt.LatinName = '' THEN bt.Name ELSE bt.LatinName END END  +' - '+ CAST(bu.Number as NVARCHAR(MAX)),BU.guid,OrderInfo.ADDATE
	END 
	 ELSE IF (@OrderGuid = 0X0 )
	 BEGIN
	  INSERT INTO #OrderedMats 		    	
	   SELECT CASE @Lang WHEN 0 THEN ISNULL(CU.CustomerName,'') ELSE CASE WHEN ISNULL(CU.LatinName,'') = '' THEN ISNULL(CU.CustomerName,'') ELSE ISNULL(CU.LatinName,'') END END AS CustomerName,BI.MatGuid,CASE @Lang WHEN 0 THEN bt.Name ELSE CASE WHEN bt.LatinName = '' THEN bt.Name ELSE bt.LatinName END END  +' - '+ CAST(bu.Number as NVARCHAR(MAX)) ClassPtr,
	          BU.guid OrderGuid, OrderInfo.ADDATE  DDATE, SUM(BI.Qty) AS QTY    
		FROM BI000 BI   
		    INNER JOIN BU000 BU ON BU.GUID = BI.PARENTGUID   
		    INNER JOIN BT000 BT ON BT.GUID = BU.TYPEGUID 
			INNER JOIN [#BillsTypesTbl] BillTypesTbl ON BillTypesTbl.TypeGuid = bt.guid
			INNER JOIN cu000 CU ON CU.guid = @CustomerName AND CU.CustomerName = BU.Cust_Name
			INNER JOIN orAddInfo000 OrderInfo ON OrderInfo.ParentGuid = BU.GUID
		WHERE  @SrcTypes <> 0X0
			  AND BT.TYPE IN (5)   
			  AND @Detailed = 1
			  AND BU.DATE >= @FromDate   
			  AND BU.DATE <= @ToDate   
			  AND OrderInfo.Finished = 0 
			  AND OrderInfo.Add1 = 0
		GROUP BY CASE @Lang WHEN 0 THEN ISNULL(CU.CustomerName,'') ELSE CASE WHEN ISNULL(CU.LatinName,'')= '' THEN ISNULL(CU.CustomerName,'') ELSE ISNULL(CU.LatinName,'') END END,BI.MatGuid,CASE @Lang WHEN 0 THEN bt.Name ELSE CASE WHEN bt.LatinName = '' THEN bt.Name ELSE bt.LatinName END END  +' - '+ CAST(bu.Number as NVARCHAR(MAX)),BU.guid,OrderInfo.ADDATE
		 
	 END 
	  
		INSERT INTO #OrderedMats 		    
		SELECT CASE @Lang WHEN 0 THEN ISNULL(CU.CustomerName,'') ELSE CASE WHEN ISNULL(CU.LatinName,'') = '' THEN ISNULL(CU.CustomerName,'') ELSE ISNULL(CU.LatinName,'') END END AS CustomerName,BI.MatGuid,'' ClassPtr,bu.guid OrderGuid, OrderInfo.ADDATE  DDATE, SUM(BI.Qty) AS QTY    
		FROM BI000 BI   
		      INNER JOIN BU000 BU ON BU.GUID = BI.PARENTGUID   
		      INNER JOIN BT000 BT ON BT.GUID = BU.TYPEGUID 
			  INNER JOIN [#BillsTypesTbl] BillTypesTbl ON BillTypesTbl.TypeGuid = bt.guid
              INNER JOIN orAddInfo000 OrderInfo ON OrderInfo.ParentGuid = BU.GUID
			  INNER JOIN CU000 CU on CU.guid = @CustomerName and CU.CustomerName = bu.Cust_Name
		WHERE  (@OrderGuid =0x0 OR @OrderGuid = BU.GUID )
			  AND @SrcTypes<>0x0 
			  AND BT.TYPE IN (5)
		      AND @Detailed = 0 AND @SrcTypes <> 0x0 
			  AND BU.DATE >= @FromDate AND BU.DATE <= @ToDate  
			  AND OrderInfo.Finished = 0 AND OrderInfo.Add1 = 0
        GROUP BY CASE @Lang WHEN 0 THEN ISNULL(CU.CustomerName,'') ELSE CASE WHEN ISNULL(CU.LatinName,'') = '' THEN ISNULL(CU.CustomerName,'') ELSE ISNULL(CU.LatinName,'') END END ,BI.MatGuid,bu.guid,OrderInfo.ADDATE
		END
	ELSE
	BEGIN
	IF ( @OrderGuid <> 0x0 )
	BEGIN
		INSERT INTO #OrderedMats 		    
	           SELECT CASE @Lang WHEN 0 THEN ISNULL(CU.CustomerName,'') ELSE CASE WHEN ISNULL(CU.LatinName,'') = '' THEN ISNULL(CU.CustomerName,'') ELSE ISNULL(CU.LatinName,'') END END AS CustomerName,BI.MatGuid,
	                  CASE @Lang WHEN 0 THEN bt.Name ELSE CASE WHEN bt.LatinName = '' THEN bt.Name ELSE bt.LatinName END END  +' - '+ CAST(bu.Number as NVARCHAR(MAX)) ClassPtr, 
		              bu.guid OrderGuid,OrderInfo.ADDATE  DDATE, 
		              SUM(BI.Qty) AS QTY    
		       FROM BI000 BI   
		             INNER JOIN BU000 BU ON BU.GUID = BI.PARENTGUID   
		             INNER JOIN BT000 BT ON BT.GUID = BU.TYPEGUID 
			         INNER JOIN orAddInfo000 OrderInfo ON OrderInfo.ParentGuid = BU.GUID
					 LEFT JOIN CU000 CU ON CU.GUID  = BU.CustGUID
			  WHERE   @OrderGuid = BU.GUID 
				      AND @SrcTypes =0x0
					  AND BT.TYPE IN (5)   
			          AND @Detailed = 1
					  AND OrderInfo.Finished = 0 AND OrderInfo.Add1 = 0
		GROUP BY CASE @Lang WHEN 0 THEN ISNULL(CU.CustomerName,'') ELSE CASE WHEN ISNULL(CU.LatinName,'') = '' THEN ISNULL(CU.CustomerName,'') ELSE ISNULL(CU.LatinName,'') END END , 
		BI.MatGuid, 
		CASE @Lang WHEN 0 THEN bt.Name ELSE CASE WHEN bt.LatinName = '' THEN bt.Name ELSE bt.LatinName END END  +' - '+ CAST(bu.Number as NVARCHAR(MAX)),bu.guid,OrderInfo.ADDATE
		END  
	ELSE IF ( @OrderGuid = 0x0 ) 
		BEGIN 
		INSERT INTO #OrderedMats 		    
	           SELECT CASE @Lang WHEN 0 THEN ISNULL(CU.CustomerName,'') ELSE CASE WHEN ISNULL(CU.LatinName,'') = '' THEN ISNULL(CU.CustomerName,'') ELSE ISNULL(CU.LatinName,'') END END AS CustomerName,BI.MatGuid,
	                  CASE @Lang WHEN 0 THEN bt.Name ELSE CASE WHEN bt.LatinName = '' THEN bt.Name ELSE bt.LatinName END END  +' - '+ CAST(bu.Number as NVARCHAR(MAX)) ClassPtr, 
		              bu.guid OrderGuid,OrderInfo.ADDATE  DDATE, 
		              SUM(BI.Qty) AS QTY    
		       FROM BI000 BI   
		             INNER JOIN BU000 BU ON BU.GUID = BI.PARENTGUID   
		             INNER JOIN BT000 BT ON BT.GUID = BU.TYPEGUID 
			         INNER JOIN [#BillsTypesTbl] BillTypesTbl ON BillTypesTbl.TypeGuid = bt.guid
					 INNER JOIN orAddInfo000 OrderInfo ON OrderInfo.ParentGuid = BU.GUID
					 LEFT JOIN CU000 CU ON CU.GUID  = BU.CustGUID
			  WHERE    @SrcTypes <> 0x0
					  AND BT.TYPE IN (5)   
			          AND @Detailed = 1
					  AND BU.DATE >= @FromDate   AND BU.DATE <= @ToDate   
					  AND OrderInfo.Finished = 0 AND OrderInfo.Add1 = 0
		GROUP BY CASE @Lang WHEN 0 THEN ISNULL(CU.CustomerName,'') ELSE CASE WHEN ISNULL(CU.LatinName,'') = '' THEN ISNULL(CU.CustomerName,'') ELSE ISNULL(CU.LatinName,'') END END,BI.MatGuid, CASE @Lang WHEN 0 THEN bt.Name ELSE CASE WHEN bt.LatinName = '' THEN bt.Name ELSE bt.LatinName END END  +' - '+ CAST(bu.Number as NVARCHAR(MAX)),bu.guid,OrderInfo.ADDATE
		END 				
	
		INSERT INTO #OrderedMats 		    
		SELECT CASE @Lang WHEN 0 THEN ISNULL(CU.CustomerName,'') ELSE CASE WHEN ISNULL(CU.LatinName,'') = '' THEN ISNULL(CU.CustomerName,'') ELSE ISNULL(CU.LatinName,'') END END AS CustomerName,BI.MatGuid,
		       '' ClassPtr,bu.guid OrderGuid,
	           OrderInfo.ADDATE  DDATE, SUM(BI.Qty) AS QTY    
		
			FROM BI000 BI   
		      INNER JOIN BU000 BU ON BU.GUID = BI.PARENTGUID   
		      INNER JOIN BT000 BT ON BT.GUID = BU.TYPEGUID 
			  INNER JOIN [#BillsTypesTbl] BillTypesTbl ON BillTypesTbl.TypeGuid = bt.guid
              INNER JOIN orAddInfo000 OrderInfo ON OrderInfo.ParentGuid = BU.GUID
			  LEFT JOIN CU000 CU ON CU.GUID  = BU.CustGUID
		WHERE  (@OrderGuid =0x0 OR @OrderGuid = BU.GUID )
			   AND @SrcTypes<>0x0 AND BT.TYPE IN (5)   
		       AND @Detailed = 0
			   AND BU.DATE >= @FromDate AND BU.DATE <= @ToDate     
			   AND OrderInfo.Finished = 0 AND OrderInfo.Add1 = 0
        GROUP BY CASE @Lang WHEN 0 THEN ISNULL(CU.CustomerName,'') ELSE CASE WHEN ISNULL(CU.LatinName,'') = '' THEN ISNULL(CU.CustomerName,'') ELSE ISNULL(CU.LatinName,'') END END ,BI.MatGuid,bu.guid,OrderInfo.ADDATE  
		

		END
		
		
CREATE TABLE #TMP ( 
					
                        [MATGUID]            [UNIQUEIDENTIFIER],   
					[Number]			 [INT], 
                    [GUID]               [UNIQUEIDENTIFIER],   
                    [PARENTGUID]         [UNIQUEIDENTIFIER],  
					[ClassPtr]           NVARCHAR (MAX) COLLATE ARABIC_CI_AI,  
					[FORMNAME]           NVARCHAR (MAX) COLLATE ARABIC_CI_AI,  
                    [MATNAME]            NVARCHAR (MAX) COLLATE ARABIC_CI_AI,   
                        [QTY]                [FLOAT]                ,   
                    [QtyInForm]          [FLOAT]                ,  
                    [PATH]               [VARCHAR](1000)  ,   
					[Unit]			     [INT],	   
                    [IsSemiReadyMat]     [INT],  
					[rank]				 [INT]
                  )   
			

		

				INSERT INTO #TMP   
				  SELECT   distinct mi.MatGuid, fm.Number,mi.guid, fm.guid,''
				          , fm.Name ,CASE @Lang WHEN 0 THEN  mt.Name ELSE CASE WHEN  mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END END , 0 --StoreQty
				          ,mi.Qty,'',mi.unity,1 ,RANK() OVER (PARTITION BY mi.MatGuid ORDER BY fm.Number DESC)

				 FROM 
						mn000 mn inner join mi000 mi on mn.guid = mi.parentguid 
						INNER JOIN fm000 fm on fm.guid = mn.formguid 
						INNER JOIN #OrderedMats orders on orders.MatGuid = mi.matguid
						inner join mt000 mt on mt.GUID = mi.MatGUID
					WHERE MI.Type = 0 AND MN.Type = 0 
					
					
					SELECT * 
					INTO #tt 
					FROM #TMP WHERE rank = 1 

	CREATE TABLE #RESAULT  
                  (   
						[Type]                     [INT],   
						[CustomerName]             VARCHAR (255) COLLATE ARABIC_CI_AI,   
						[MatGuid]                  [UNIQUEIDENTIFIER], 
                        [ClassPtr]                 VARCHAR (255) COLLATE ARABIC_CI_AI,  
						[OrderGuid]				   UNIQUEIDENTIFIER, 
						[ADDate]			       [DATETIME],
						[MatName]                  VARCHAR (255) COLLATE ARABIC_CI_AI,  
                        [QtyInForm]                [FLOAT]                ,   
                        [Unit]					   [Int],   
						[Done]					   [Float], --StoreQty  
                        [NotDone]                  [FLOAT], --AchievedQty
                        [FinalQty]                 [Float]  ,   
						[IsSemiReadyMat]		   [INT],	   
                        [TotalPlaned]              [Float],  
                        [TotalNonPlaned]           [Float],  
                        [MIGUID]                   [UNIQUEIDENTIFIER], 
                        [PATH]                     [VARCHAR](1000)    
                  ) 
				
				  INSERT INTO #RESAULT 
				  SELECT   0 Type ,
						'' CustomerName,
						TMP.MatGuid, 
						'',
						0x0,
						OrderedMats.DDATE,
						TMP.MatName,
					    TMP.QtyInForm,
						TMP.Unit, 
						MAX(Sales.Achived),
						 (Select ISNULL(SUM(QTY), 0) FROM MS000 WHERE (MS000.MatGUID = TMP.MatGuid)) NotDone,
						 OrderedMats.Qty  FinalQty,
						 '1',
						IsNull( Plans.TotalPlaned ,0) TotalPlaned,
						 0  TotalNonPlaned,
						TMP.Guid MIGUID, 
						TMP.PATH    
						FROM 
					#tt TMP INNER JOIN #OrderedMats OrderedMats ON ( TMP.MatGuid = OrderedMats.MatGuid)
						  INNER JOIN MN000 MN ON TMP.ParentGuid = MN.FormGuid  
						  INNER JOIN FM000 FM ON MN.FormGuid = FM.Guid 
						  LEFT JOIN PSI000 PSI on psi.formGuid= fm.GUID
						  INNER JOIN #SaleOrders Sales ON Sales.MaterialGuid = OrderedMats.MatGuid
						  INNER JOIN [#BillsTypesTbl] billType ON billtype.typeguid = sales.BillType
				   LEFT JOIN ( 
						 SELECT MI.MatGuid, MI.ParentGuid,PSI.FormGuid AS FF, SUM(PSI.QTY * MI.Qty ) TotalPlaned   
						  FROM MI000 MI  
							   INNER JOIN MT000 MT ON MT.Guid = MI.MatGuid  
							   INNER JOIN MN000 MN1 ON MN1.Guid = MI.ParentGuid  
							   INNER JOIN FM000 FM1 ON MN1.FormGuid = FM1.Guid
							   INNER JOIN PSI000 PSI ON PSI.FormGuid = FM1.Guid   
							WHERE  MN1.Type = 0  AND PSI.State = 0 AND MI.Type = 0
								  AND PSI.StartDate >= @FromDate  
								  AND PSI.StartDate <= @ToDate 
							GROUP BY MI.MatGuid, MI.ParentGuid, PSI.FormGuid
				  	) Plans
							ON Plans.MatGuid = TMP.MatGuid AND TMP.PARENTGUID = Plans.FF
		GROUP BY  TMP.MatGuid,
					 OrderedMats.DDATE, TMP.MatName,
					 TMP.Unit, OrderedMats.Qty  ,
					  TMP.Qty,
					 TMP.Path, TMP.Guid, TMP.QTYINFORM, 
					 Plans.TotalPlaned
		ORDER BY TMP.Path

	
		; WITH sumOrder AS
		(SELECT SUM(tt.OrderQty) as OrderQty,tt.MatGuid AS MatGuid FROM  
									  ( 
									   SELECT bt.guid AS BTGuid, SUM(orders.QTY) OrderQty, orders.MatGuid 
										FROM #OrderedMats orders inner join 
											BU000 BU on   BU.GUID   = orders.OrderGuid
											INNER JOIN BT000 BT ON BT.GUID = BU.TYPEGUID 
											LEFT JOIN [#BillsTypesTbl] BillTypesTbl ON BillTypesTbl.TypeGuid = bt.guid
										GROUP BY orders.MatGuid,bt.GUID
										)tt 
										GROUP BY tt.MatGuid
                  )   
		
		UPDATE  #RESAULT
		SET FinalQty = ( SELECT OrderQty FROM  sumOrder WHERE  sumOrder.MatGuid = #RESAULT.MatGuid)

		
		
	SELECT res.Type,
			   res.CustomerName,
			   res.MatGuid,
			   res.ClassPtr,
			   res.OrderGuid,
			   res.ADDATE,
			   res.MatName,
			   res.QtyInForm,
			   res.Unit, 
			   Max(res.Done) AS Done,
			   MAX(res.NotDone) NotDone,
			   Max(res.FinalQty) AS FinalQty,
			   res.IsSemiReadyMat, -- «·„«œ… ‰’› «·„’‰⁄… 
			   Max(res.TotalPlaned) TotalPlaned,
			   MAx(res.TotalNonPlaned) TotalNonPlaned,--«Ã„·Ì €Ì— «·„Œÿÿ 
			   res.MIGUID, 
			   res.PATH  
		INTO #NotDetailedResult
		FROM #RESAULT res  
	    WHERE res.Type = 0
		GROUP BY res.Type,res.CustomerName,res.MatGuid,res.ClassPtr,res.OrderGuid,res.ADDATE,res.MatName 
			  ,res.QtyInForm,res.Unit,res.IsSemiReadyMat,res.MIGUID, res.PATH  

 
 
	--------------------------------
	-- Detailed = 1 
	INSERT INTO #RESAULT  
		SELECT 1 Type ,
			OrderedMats.CustomerName,
			TMP.MatGuid, 
			OrderedMats.ClassPtr,
			OrderedMats.OrderGuid,
			OrderedMats.DDATE,-- «—ÌŒ «· ”·Ì„ 
			TMP.MatName,--«”„ «·„«œ… 
			TMP.QtyInForm,
			TMP.Unit, 
			ISNULL(SpiMat.Done, 0) Done, --«·ﬂ„Ì… «·„‰›–…
			0 NotDone,--«·ﬂ„Ì… €Ì— «·„‰›–…
			( OrderedMats.Qty) FinalQty,
			TMP.IsSemiReadyMat, -- «·„«œ… ‰’› «·„’‰⁄… 
			IsNull( Plans.TotalPlaned ,0) TotalPlaned,--«Ã„«·Ì «·„Œÿÿ
			0  TotalNonPlaned,--«Ã„·Ì €Ì— «·„Œÿÿ 
			TMP.Guid MIGUID, 
			TMP.PATH    
		FROM 
			#tt TMP INNER JOIN #OrderedMats OrderedMats ON ( TMP.MatGuid = OrderedMats.MatGuid)
				  INNER JOIN MN000 MN ON TMP.ParentGuid = MN.FormGuid  
			INNER JOIN FM000 FM ON MN.FormGuid = FM.Guid  
				  LEFT JOIN PSI000 PSI on psi.formGuid= fm.GUID
				  INNER JOIN #SaleOrders Sales ON Sales.MaterialGuid = OrderedMats.MatGuid
				  LEFT JOIN [#BillsTypesTbl] billType ON billtype.typeguid = sales.BillType
			LEFT JOIN (  
					  SELECT MI.MatGuid, MI.ParentGuid, PSI.orderNumGuid OrderGuid,PSI.FormGuid AS FF,
							SUM(PSI.QTY * MI.Qty) Done   
					FROM MI000 MI  
	    			INNER JOIN MT000 MT ON MT.Guid = MI.MatGuid  
			 		INNER JOIN MN000 MN1 ON MN1.Guid = MI.ParentGuid  
			 		INNER JOIN FM000 FM1 ON MN1.FormGuid = FM1.Guid  
			 		INNER JOIN PSI000 PSI ON PSI.FormGuid = FM1.Guid  
						WHERE  MN1.Type = 0  AND PSI.State = 1 AND ( MI.Type = 0 )
						   AND PSI.StartDate >= @FromDate  
						   AND PSI.StartDate <= @ToDate  
							GROUP BY MI.MatGuid, MI.ParentGuid,  PSI.orderNumGuid ,PSI.FormGuid 
					  ) SpiMat   
						ON SpiMat.MatGuid = TMP.MatGuid AND TMP.PARENTGUID = SpiMat.FF
						AND (SpiMat.ParentGuid = MN.Guid OR TMP.IsSemiReadyMat = 1) 
			            AND (SpiMat.OrderGuid = OrderedMats.OrderGuid)
				  LEFT JOIN ( 
					SELECT MI.MatGuid, MI.ParentGuid, PSI.orderNumGuid OrderGuid,PSI.FormGuid AS FF,
					       SUM( PSI.QTY * MI.Qty ) TotalPlaned   
					FROM MI000 MI  
						   INNER JOIN MT000 MT ON MT.Guid = MI.MatGuid  
						   INNER JOIN MN000 MN1 ON MN1.Guid = MI.ParentGuid  
						   INNER JOIN FM000 FM1 ON MN1.FormGuid = FM1.Guid  
						   INNER JOIN PSI000 PSI ON PSI.FormGuid = FM1.Guid 
					WHERE  MN1.Type = 0  AND PSI.State = 0 AND MI.Type = 0  
								  AND PSI.StartDate >= @FromDate  
								  AND PSI.StartDate <= @ToDate 
							GROUP BY MI.MatGuid, MI.ParentGuid, PSI.orderNumGuid,PSI.FormGuid
							) Plans
							ON Plans.MatGuid = TMP.MatGuid AND Plans.FF = TMP.PARENTGUID
								AND (Plans.ParentGuid = MN.Guid OR TMP.IsSemiReadyMat = 1) 
								AND (Plans.OrderGuid = OrderedMats.OrderGuid)
		GROUP BY OrderedMats.CustomerName, TMP.MatGuid, OrderedMats.ClassPtr,
					 OrderedMats.OrderGuid,OrderedMats.DDATE, TMP.MatName,
					 TMP.Unit, OrderedMats.Qty, TMP.Qty, TMP.IsSemiReadyMat, 
					 TMP.Path, TMP.Guid, TMP.QTYINFORM,SpiMat.Done ,Plans.TotalPlaned
	ORDER BY TMP.Path	  

  	

	SELECT res.Type,
			   res.CustomerName,
			   res.MatGuid,
			   res.ClassPtr,
			   res.OrderGuid,
			   res.ADDATE,
			   res.MatName,
			   res.QtyInForm,
			   res.Unit, 
			   Max(res.Done) AS Done,
			   MAX(res.NotDone) NotDone,
			   Max(res.FinalQty) AS FinalQty,
			   res.IsSemiReadyMat, -- «·„«œ… ‰’› «·„’‰⁄… 
			   Max(res.TotalPlaned) TotalPlaned,
			   MAx(res.TotalNonPlaned) TotalNonPlaned,--«Ã„·Ì €Ì— «·„Œÿÿ 
			   res.MIGUID, 
			   res.PATH  
		INTO #DetailedResult
		FROM #RESAULT res  
	    WHERE res.Type = 1
		GROUP BY res.Type,res.CustomerName,res.MatGuid,res.ClassPtr,res.OrderGuid,res.ADDATE,res.MatName 
			  ,res.QtyInForm,res.Unit,res.IsSemiReadyMat,res.MIGUID, res.PATH  
		
	 

		 CREATE TABLE #NEXTRESULT
		 (
		   FormGuid UNIQUEIDENTIFIER,
		   MatGuid	UNIQUEIDENTIFIER,
		   ParentGuid UNIQUEIDENTIFIER,
		   OrderGuid UNIQUEIDENTIFIER,
		   StartDate DATETIME,
		   QtyInPlan FLOAT ,
		   TotalQtyInPlan FLOAT
		 )
		
		if ( @Detailed  = 0 )
		BEGIN 
		INSERT INTO #NEXTRESULT
		SELECT PSI.FormGuid As FormGuid,
			   MI.MatGuid AS MatGuid,
			   MI.ParentGuid AS ParentGuid,
			   0x0 AS OrderGuid ,
			   PSI.StartDate AS StartDate, 
			   SUM(PSI.Qty * MI.Qty) AS QtyInPlan ,
			   0  
        	FROM MI000 MI  
			   INNER JOIN MT000 MT ON MT.Guid = MI.MatGuid  
			   INNER JOIN MN000 MN1 ON MN1.Guid = MI.ParentGuid  
			   INNER JOIN FM000 FM1 ON MN1.FormGuid = FM1.Guid  
			   INNER JOIN PSI000 PSI ON PSI.FormGuid = FM1.Guid  
			   INNER JOIN #tt TMP ON Tmp.PARENTGUID = PSI.FormGuid AND TMP.MATGUID =  MI.MatGuid 
		  WHERE  MN1.Type = 0  AND PSI.State = 0 AND  MI.Type = 0 
				 AND PSI.StartDate >= @FromDate  
				 AND PSI.StartDate <= @ToDate 
			GROUP BY PSI.FormGuid,PSI.StartDate,MI.MatGuid,MI.ParentGuid	
			END 
		ELSE 
		BEGIN 
		INSERT INTO #NEXTRESULT
		SELECT PSI.FormGuid As FormGuid,
			   MI.MatGuid AS MatGuid,
			   MI.ParentGuid AS ParentGuid,
			   PSI.OrderNumGuid AS OrderGuid,
			   PSI.StartDate AS StartDate, 
			   SUM(PSI.Qty * MI.Qty) AS QtyInPlan ,
			   0  
       	FROM MI000 MI  
		INNER JOIN MT000 MT ON MT.Guid = MI.MatGuid 
			   INNER JOIN MN000 MN1 ON MN1.Guid = MI.ParentGuid  
			   INNER JOIN FM000 FM1 ON MN1.FormGuid = FM1.Guid  
			   INNER JOIN PSI000 PSI ON PSI.FormGuid = FM1.Guid
			   INNER JOIN #OrderedMats OrderedMats ON Mt.Guid  = OrderedMats.MatGuid
			   INNER JOIN #tt TMP ON Tmp.PARENTGUID = PSI.FormGuid AND TMP.MATGUID =  MI.MatGuid 
			   AND OrderedMats.OrderGuid = PSI.OrderNumGuid
		 WHERE  MN1.Type = 0  AND PSI.State = 0 AND  MI.Type = 0 
			  AND PSI.StartDate >= @FromDate 
		      AND PSI.StartDate <= @ToDate 
		GROUP BY PSI.FormGuid,PSI.StartDate, PSI.OrderNumGuid,MI.MatGuid,MI.ParentGuid	-- order by PSI.	    
		ORDER BY PSI.orderNumGuid
			END 

			;WITH sumQtyInTotalPlan AS 
			(
			  SELECT SUM(QtyInPlan) AS QtyInPlan,StartDate  AS StartDate
				FROM #NEXTRESULT
				GROUP BY StartDate
			)
	 
	 UPDATE #NEXTRESULT 
	 SET TotalQtyInPlan = (SELECT QtyInPlan FROM sumQtyInTotalPlan WHERE #NEXTRESULT.StartDate = StartDate   )

		  if (@Detailed = 1 )
		  BEGIN 
   		      SELECT * FROM #DetailedResult 
				WHERE Type = 1
				order by ClassPtr 

			SELECT FormGuid,
				MatGuid,
				StartDate ,
				QtyInPlan,
				OrderGuid,
				TotalQtyInPlan
		   FROM #NEXTRESULT
		END
		  ELSE 
		  BEGIN
		  UPDATE #NotDetailedResult 
		  SET Done = (SELECT  SUM(Sales.Achived) 
					FROM #SaleOrders Sales 
							INNER JOIN [#BillsTypesTbl] billType ON billtype.typeguid = sales.BillType
					WHERE #NotDetailedResult.MatGuid = Sales.MaterialGuid 
					GROUP BY Sales.MaterialGuid
				   )
			
			SELECT res.Type,
			   res.CustomerName,
			   res.MatGuid,
			   res.ClassPtr,
			   res.OrderGuid,
			   CONVERT(DATETIME, '1990-1-1') ADDate , 
			   res.MatName,
			   res.QtyInForm,
			   res.Unit, 
			   Max(res.Done) AS Done,
			   Max(res.NotDone) As NotDone,
			   MAx(res.FinalQty) AS FinalQty,
			   res.IsSemiReadyMat, -- «·„«œ… ‰’› «·„’‰⁄… 
			   Max(res.TotalPlaned) TotalPlaned,
			   MAx(res.TotalNonPlaned) TotalNonPlaned,--«Ã„·Ì €Ì— «·„Œÿÿ 
			   res.MIGUID, 
			   res.PATH  
		FROM  #NotDetailedResult res 
		WHERE res.Type = 0
		GROUP BY res.Type,res.CustomerName,res.MatGuid,res.ClassPtr,res.OrderGuid,res.MatName 
				,res.QtyInForm,res.Unit,res.IsSemiReadyMat,res.MIGUID, res.PATH
  
	 
		SELECT FormGuid,
				MatGuid,
				StartDate ,
				QtyInPlan,
				OrderGuid,
				TotalQtyInPlan
		   FROM #NEXTRESULT
		  END 
###############################################################################
#END