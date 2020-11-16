###############################################################################
CREATE PROCEDURE prcGetManufacMaterialTree
@MATGUID    [UNIQUEIDENTIFIER],  
@ClassPtr 	[NVARCHAR] (255) = '', 
@PARENTPATH [NVARCHAR](max) = '' 
AS   
	EXECUTE prcNotSupportedInAzureYet
	/*
	SET NOCOUNT ON   
    DECLARE @MANFORM  [UNIQUEIDENTIFIER] 
    DECLARE @SELECTED UNIQUEIDENTIFIER 
    DECLARE @MAINSELECTED UNIQUEIDENTIFIER 
    DECLARE @MAINSELECTEDQTY FLOAT 
    DECLARE @MAT UNIQUEIDENTIFIER 
    DECLARE @CNT INT 
    DECLARE @PPATH [NVARCHAR](1000) 
    DECLARE @PARENTQTY FLOAT 
    DECLARE @PARENTQTYINFORM FLOAT 
    SELECT TOP 1 @MANFORM = [PARENTGUID]   
    FROM MI000 MI  
    INNER JOIN MN000 MN ON MN.GUID = MI.PARENTGUID  
    INNER JOIN FM000 FM ON FM.GUID = MN.FORMGUID  
    WHERE   MN.TYPE = 0 AND MI.TYPE = 0 AND MATGUID = @MATGUID  
        
                 
    IF (@PARENTPATH = '')  
    BEGIN  
				IF NOT EXISTS ( SELECT * FROM tempdb..sysobjects WHERE name = '##TREEBUFFER')  
                CREATE TABLE ##TREEBUFFER  
                (  
                    [SELECTEDGUID]                     [UNIQUEIDENTIFIER], 
                    [GUID]                     [UNIQUEIDENTIFIER],  
                    [PARENTGUID]         [UNIQUEIDENTIFIER],  
                    [MATGUID]            [UNIQUEIDENTIFIER],  
                    [ISHALFREADYMAT]   [BIT]                  ,  
                    [PATH]                   [NVARCHAR](1000)  ,  
                    [QTY]                [FLOAT]                ,  
                    [QtyInForm]                [FLOAT]                , 
					[Unit]			[INT],	  
                    [TYPE]                     [INT]                ,  
                    [IsSemiReadyMat]   [INT]   	--	, 
                )  
                SET @PARENTPATH = '0'  
				SET @MAINSELECTED = @MATGUID 
				SET @PARENTQTY = 1 
				SET @PARENTQTYINFORM = 1 
				SELECT @MAINSELECTEDQTY = MI.QTY 
						FROM MI000 MI 
					    INNER JOIN MN000 MN ON MN.Guid = MI.ParentGuid 
						WHERE MI.Type = 0 
						 	AND MI.MatGuid = @MAINSELECTED 
							AND MN.Type = 0 
    END 	 
	ELSE 
		SELECT @PARENTQTYINFORM = MI.QTY 
		FROM MI000 MI 
		INNER JOIN MN000 MN ON MN.Guid = MI.ParentGuid 
		WHERE MI.MatGuid = @MATGUID AND MI.Type = 0 AND MN.Type = 0	 
  
	SELECT @PARENTQTY = QTY FROM ##TREEBUFFER 
		WHERE MATGuid = @MATGUID 
	INSERT INTO ##TREEBUFFER 
    SELECT MI.[GUID], MI.[GUID] , MI.PARENTGUID , MI.MATGUID , DBO.ISHALFREADYMAT(MI.MATGUID) , @PARENTPATH + '.' + CAST( (DBO.ISHALFREADYMAT(MI.MATGUID) ) AS NVARCHAR(100)) + CAST( (MI.Number ) AS NVARCHAR(100)) , ( MI.Qty * @PARENTQTY / @PARENTQTYINFORM), MI.Qty, MI.Unity, MI.[TYPE] , CASE MI.MatGuid WHEN @MAINSELECTED THEN 1 ELSE 0 END
    FROM   MI000 MI 
	INNER JOIN MN000 MN ON MN.GUID = MI.PARENTGUID 
	INNER JOIN FM000 FM ON FM.GUID = MN.FORMGUID 
    WHERE MN.Type = 0 
			AND ( MI.TYPE = 1 OR (MI.MatGuid = @MAINSELECTED AND @ClassPtr <> '') )
			AND MI.PARENTGUID = @MANFORM 
	ORDER BY DBO.ISHALFREADYMAT(MI.MATGUID) 
       
SELECT TOP 1  
        @SELECTED = [GUID],  
        @MAT = [MATGUID],  
        @PPATH     = [PATH]  
    FROM ##TREEBUFFER  
    WHERE ISHALFREADYMAT = 1  
    ORDER BY [PATH]            
    IF(@SELECTED <> 0X0)  
    BEGIN  
        UPDATE ##TREEBUFFER SET [ISHALFREADYMAT] = 0 , [IsSemiReadyMat] = 1 WHERE GUID = @SELECTED  
        EXEC prcGetManufacMaterialTree @MAT, @ClassPtr, @PPATH  
    END  
    IF(@PARENTPATH = '0')  
    BEGIN  
        SET @CNT = (SELECT COUNT(*) FROM ##TREEBUFFER WHERE ISHALFREADYMAT = 1)  
        IF(@CNT = 0)  
        BEGIN  
             
				UPDATE ##TREEBUFFER 
				SET QtyInForm = MI.Qty 
				FROM MI000 MI, ##TREEBUFFER TREE, MN000 MN  
				WHERE TREE.IsSemiReadyMat = 1  
					AND MI.Type = 0  
					AND MI.MatGuid = TREE.MatGuid 
					AND MN.Guid = MI.ParentGuid 
					AND MN.Type = 0 
             
                SELECT @MAINSELECTED SelectedGuid ,[TREE].[GUID] ,[TREE].[PARENTGUID], @ClassPtr ClassPtr, [FM].[Name] AS FORMNAME, [MATGUID], [MT].[NAME] AS MATNAME,[TREE].[QTY] / @MAINSELECTEDQTY QTY,[TREE].[QtyInForm],[TREE].[PATH], [TREE].[Unit], [TREE].[IsSemiReadyMat]  
                FROM ##TREEBUFFER TREE  
                LEFT JOIN MN000 MN ON [MN].[GUID] = [TREE].[PARENTGUID]                   
                LEFT JOIN FM000 FM ON [FM].[GUID] = [MN].[FORMGUID]  
                LEFT JOIN MT000 MT ON [MT].[GUID] = [TREE].[MATGUID]  
                ORDER BY [TREE].[PATH]                 
	        DROP TABLE ##TREEBUFFER  
        END  
    END  
	*/
###############################################################################      
CREATE PROCEDURE repOrderedMaterialsPlans
	@OrderGuid		[UNIQUEIDENTIFIER] = 0x0,
	@BillType		[UNIQUEIDENTIFIER] = 0x0,
	@FromDate   	[DATETIME] = '2009-1-1',
	@ToDate     	[DATETIME] = '2010-10-31',
	@Detailed       [BIT] = 1
AS      
	SET NOCOUNT ON      
	--------------------------------------------------------------  
/*  
 ÕœÌœ „Ã„Ê⁄… «·„Ê«œ ‰’› «·„’‰⁄…  
*/  
	DECLARE @SemiManGroup UNIQUEIDENTIFIER   
		SET @SemiManGroup = (SELECT [Value] FROM op000 WHERE [Name] ='man_semiconductGroup')   
	CREATE TABLE #SemiManGroups
	(
		guid UNIQUEIDENTIFIER
	)
	INSERT INTO #SemiManGroups
	select * from fnGetGroupsList(@SemiManGroup)

	--------------------------------------------------------------  
/*  
 ÕœÌœ «”„ «·›∆… 
*/  
	DECLARE @ClassName NVARCHAR (255)   
		SET @ClassName = '' 
		SET @ClassName = (select notes from bu000 where guid = @OrderGuid)   
	--------------------------------------------------------------  
/*  
«·Õ’Ê· ⁄·Ï ÃœÊ· ›ÌÂ «·„Ê«œ «·„ÿ·Ê»… + „⁄·Ê„«  ⁄‰ «·ÿ·»Ì… „À· «·ﬂ„Ì… «·„ÿ·Ê»…  
Ê Â–« «·ÃœÊ· ÂÊ «·ÃœÊ· «·√”«”Ì «·–Ì ”Ì Ê·œ „‰Â ÃœÊ· «·  
TMP  
Ê »«· «·Ì »«ﬁÌ «·Ãœ«Ê·  
*/  
	SELECT BI.MatGuid,BU.Notes ClassPtr, SUM(BI.Qty) AS QTY    
		INTO #OrderedMats 		    
			FROM BI000 BI   
		    INNER JOIN BU000 BU ON BU.GUID = BI.PARENTGUID   
		    INNER JOIN BT000 BT ON BT.GUID = BU.TYPEGUID   
		WHERE ( @OrderGuid = 0x0 OR BU.GUID = @OrderGuid )   
			  AND ( (@BillType = BT.Guid AND @OrderGuid <> 0x0) OR @BillType = 0x0 )
			  AND BT.TYPE IN (5, 6)   
			  AND BU.DATE >= @FromDate   
			  AND BU.DATE <= @ToDate   
		GROUP BY BI.MatGuid,BU.Notes  
	--------------------------------------------------------------  
/*  
≈‰‘«¡ ÃœÊ·  
TMP  
«·–Ì ÂÊ  ›ﬂÌﬂ ··„Ê«œ «·„ÊÃÊœ… ›Ì «·ÃœÊ· «·”«»ﬁ  
Ê «· ›ﬂÌﬂ Â‰« Ì‘„· «·„Ê«œ «·√Ê·Ì… Ê ‰’› «·„’‰⁄… »‘ﬂ· ‘Ã—Ì   
+   
«·ﬂ„Ì… «·„ÿ·Ê»… „‰ ﬂ· „‰ Â–Â «·„Ê«œ · €ÿÌ… «·ﬂ„Ì… «·„ÿ·Ê»… ›Ì «·ÿ·»Ì…  
*/  
	--IF EXISTS ( SELECT * FROM tempdb..sysobjects WHERE name = '#TMP')   
	--	DROP TABLE #TMP  
	CREATE TABLE #TMP  
                  (   
						[selectedGUID]                     [UNIQUEIDENTIFIER],   
                        [GUID]                     [UNIQUEIDENTIFIER],   
                        [PARENTGUID]         [UNIQUEIDENTIFIER],  
						[ClassPtr]           NVARCHAR (255) COLLATE ARABIC_CI_AI,  
						[FORMNAME]           NVARCHAR (255) COLLATE ARABIC_CI_AI,  
                        [MATGUID]            [UNIQUEIDENTIFIER],   
						[MATNAME]           NVARCHAR (255) COLLATE ARABIC_CI_AI,   
                        [QTY]                [FLOAT]                ,   
                        [QtyInForm]                [FLOAT]                ,   
                        [PATH]                   [NVARCHAR](1000)  ,   
						[Unit]			[INT],	   
                        [IsSemiReadyMat]   [INT],  
                  )   
	Declare @OrderedMatGuid UNIQUEIDENTIFIER   
	Declare @OrderedMatQty INT    
	Declare @OrderedClassPtr NVARCHAR (255) 
	Declare SellCur Cursor   FORWARD_ONLY FOR    
    Select   
    	MatGuid 
		,Qty  
		,ClassPtr 
	FROM #OrderedMats  
	OPEN SellCur  
		FETCH NEXT FROM SellCur INTO   
			@OrderedMatGuid 
			,@OrderedMatQty  
			,@OrderedClassPtr 
		WHILE @@FETCH_STATUS = 0  
    		BEGIN  
				INSERT INTO #TMP   
					EXEC prcGetManufacMaterialTree @OrderedMatGuid, @OrderedClassPtr, '' 
				FETCH NEXT FROM SellCur INTO   
					@OrderedMatGuid 
					,@OrderedMatQty  
					,@OrderedClassPtr 
			END  
	CLOSE SellCur   
	DEALLOCATE SellCur  
	--------------------------------------------------------------  
/*  
≈‰‘«¡ Ê „·∆ «·ÃœÊ· «·‰Â«∆Ì Ê ÂÊ —»ÿ «·ÃœÊ· «·”«»ﬁ   
»Œÿÿ «· ’‰Ì⁄ «·„‰›–…  
 Êﬂ„« ‰·«ÕŸ Â‰« «·Õﬁ· «·√Ê· „‰ «·ÃœÊ· Ì”«ÊÌ 0  
*/  
	CREATE TABLE #RESAULT  
                  (   
						[Type]                     [INT],   
                        [MatGuid]                     [UNIQUEIDENTIFIER], 
                        [ClassPtr]         NVARCHAR (255) COLLATE ARABIC_CI_AI,  
						[MatName]           NVARCHAR (255) COLLATE ARABIC_CI_AI,  
                        [QtyInForm]                [FLOAT]                ,   
                        [Unit]            [Int],   
						[Done]           [Float],   
                        [NotDone]                [FLOAT]                ,   
                        [FinalQty]                   [Float]  ,   
						[IsSemiReadyMat]			[INT],	   
                        [StartDate]   [DateTime],  
                        [TotalPlaned]   [Float],  
                        [TotalNonPlaned]   [Float],  
                        [MIGUID]         [UNIQUEIDENTIFIER], 
                        [PATH]                   [NVARCHAR](1000)  ,  
                  )   
	INSERT INTO #RESAULT  
	SELECT 0 Type, TMP.MatGuid, OrderedMats.ClassPtr, TMP.MatName, TMP.QtyInForm, TMP.Unit, ISNULL(SUM(SpiMat.Done), 0) Done, ( OrderedMats.Qty * TMP.Qty ) - ISNULL(SUM(SpiMat.Done), 0) NotDone, ( OrderedMats.Qty * TMP.Qty ) FinalQty, TMP.IsSemiReadyMat, '1980-1-1' StartDate, 0 TotalPlaned, 0 TotalNonPlaned, TMP.Guid MIGUID, TMP.PATH     
			FROM #TMP TMP  
			INNER JOIN #OrderedMats OrderedMats ON ( TMP.SelectedGuid = OrderedMats.MatGuid AND TMP.ClassPtr = OrderedMats.ClassPtr ) 
			INNER JOIN MN000 MN ON TMP.ParentGuid = MN.Guid  
			INNER JOIN FM000 FM ON MN.FormGuid = FM.Guid  
			LEFT JOIN (  
				SELECT MI.MatGuid, MI.ParentGuid, PSI.OrderNo ClassPtr, ( PSI.Done * MI.Qty ) Done   
					FROM MI000 MI  
	    			INNER JOIN MT000 MT ON MT.Guid = MI.MatGuid  
			 		INNER JOIN MN000 MN1 ON MN1.Guid = MI.ParentGuid  
			 		INNER JOIN FM000 FM1 ON MN1.FormGuid = FM1.Guid  
			 		INNER JOIN PSI000 PSI ON PSI.FormGuid = FM1.Guid  
			 		WHERE  MN1.Type = 0   
						   AND PSI.State = 1   
						   AND ( MI.Type = 0 OR MT.GroupGuid NOT IN ( SELECT * FROM #SemiManGroups ) )  
						   AND PSI.StartDate >= @FromDate  
						   AND PSI.StartDate <= @ToDate  
					  ) SpiMat   
			ON SpiMat.MatGuid = TMP.MatGuid AND OrderedMats.ClassPtr = SpiMat.ClassPtr AND (SpiMat.ParentGuid = MN.Guid OR TMP.IsSemiReadyMat = 1) 
		    WHERE ( @Detailed = 1 OR TMP.IsSemiReadyMat = 1 )  
	GROUP BY TMP.MatGuid, OrderedMats.ClassPtr,TMP.MatName, TMP.Unit, OrderedMats.Qty, TMP.Qty, TMP.IsSemiReadyMat, TMP.Path, TMP.Guid, TMP.QTYINFORM  
	ORDER BY TMP.Path	  
	--------------------------------------------------------------  
/*  
—»ÿ «·ÃœÊ· «·‰Â«∆Ì «·”«»ﬁ »Œÿÿ «· ’‰Ì⁄ «·„À» … Ê „·∆ «·‰ «∆Ã ›Ì «·ÃœÊ· «·‰Â«∆Ì  
 Êﬂ„« ‰·«ÕŸ Â‰« «·Õﬁ· «·√Ê· „‰ «·ÃœÊ· Ì”«ÊÌ 1  
*/  
INSERT INTO #RESAULT 
	SELECT 1 Type, RES.MatGuid, Res.ClassPtr, '', 0, 0, 0, 0, 0, 0,PSI.StartDate, SUM(MI.Qty * PSI.Qty) TotalPlaned, SUM(MI.Qty * PSI.Qty) TotalNonPlaned, RES.MIGuid, '' 
		FROM #RESAULT RES 
		INNER JOIN MI000 MI ON MI.MatGuid = RES.MatGuid 
		INNER JOIN MT000 MT ON MT.Guid = MI.MatGuid 
		INNER JOIN MN000 MN ON MI.ParentGuid = MN.Guid 
		INNER JOIN FM000 FM ON FM.Guid = MN.FormGuid 
		INNER JOIN PSI000 PSI ON ( PSI.FormGuid = FM.Guid AND PSI.OrderNo = Res.ClassPtr ) 
			WHERE MN.Type = 0 
			  AND (MI.Guid = Res.MIGuid OR RES.IsSemiReadyMat = 1) 
			  AND (MI.Type = 0 OR MT.groupGuid NOT IN ( SELECT * FROM #SemiManGroups ) ) 
			  AND PSI.State = 0 
			  AND ( @Detailed = 1 OR RES.IsSemiReadyMat = 1 ) 
			  AND PSI.StartDate >= @FromDate 
		      AND PSI.StartDate <= @ToDate 
	GROUP BY RES.MatGuid, RES.MatName, PSI.StartDate, RES.MIGuid, Res.ClassPtr 
  
	--------------------------------------------------------------  
/*  
‰ﬁÊ„ »Õ”«» „Ã„Ê⁄ «·ﬂ„Ì«  «·„Œÿÿ… ·„«œ… Ê ‰⁄œ· ›Ì ”ÿ— «·„«œ…   
*/  
	SELECT RES.MIGuid MiGuid, RES.ClassPtr ClassPtr, SUM(TotalPlaned) TotalPlaned  
		INTO #RESAULT1   
			FROM #RESAULT RES  
			WHERE RES.Type = 1   
	GROUP BY RES.MIGuid, RES.ClassPtr
	 
	UPDATE #RESAULT   
    	SET TotalPlaned =  RES1.TotalPlaned  
	    FROM #RESAULT RES, #RESAULT1 RES1  
	    WHERE RES1.MIGuid = RES.MIGuid AND RES1.ClassPtr = RES.ClassPtr AND RES.Type = 0  
	DROP TABLE #RESAULT1  
	--------------------------------------------------------------  
/*  
Õ”«» «·ﬂ„Ì«  €Ì— «·„Œÿÿ…  
*/  
	UPDATE #RESAULT   
		SET TotalNonPlaned = FinalQty - ( Done + TotalPlaned )  
	--------------------------------------------------------------  
/*  
«·‰ ÌÃ… «·‰Â«∆Ì…  
*/  
	SELECT * FROM #RESAULT  
	Order By Type, ClassPtr,Path 
################################################################################
#END