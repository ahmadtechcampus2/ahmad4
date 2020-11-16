###############################################################################
CREATE PROCEDURE repMaterialsGivingInPlan
	@MatGuid			UNIQUEIDENTIFIER = 0x0,	-- «·„«œ…
	@GroupGuid			UNIQUEIDENTIFIER = 0x0,	-- „Ã„Ê⁄… «·„Ê«œ «·√Ê·Ì…
	@OutStoreGuid		UNIQUEIDENTIFIER = 0x0,	-- „” Êœ⁄ «·≈Œ—«Ã
	@FromDate   		DATETIME = '1990-1-1',
	@ToDate     		DATETIME = '2999-1-1',    
	@UseUnit			TINYINT = 3, -- «·ÊÕœ… «·≈› —«÷Ì…
	@MatsToSpendOption	TINYINT = 0, -- ŒÌ«—«  «·ﬂ„Ì… «·„ÿ·Ê» ’—›Â«
	@MatsSpendOptions	TINYINT = 1, -- ŒÌ«—«  ’—› «·„Ê«œ
	@PlanGuid			UNIQUEIDENTIFIER = 0x0,	-- —„“ «·Œÿ…
	@FormGuid			UNIQUEIDENTIFIER = 0x0,	-- «·‰„Ê–Ã
	@FormCnt			INT = 1, -- ⁄œœ «·‰„«–Ã
	@CustGuid			UNIQUEIDENTIFIER =  0x0, -- «·“»Ê‰
	@OrderTypeGuid		UNIQUEIDENTIFIER =  0x0, -- ‰Ê⁄ «·ÿ·»Ì…
	@OrderGuid			UNIQUEIDENTIFIER =  0x0, -- «·ÿ·»Ì…
	@CostCenter			UNIQUEIDENTIFIER =  0x0, -- „—ﬂ“ «·ﬂ·›…
	@GenBillOrTrn		INT = 0, -- ŒÌ«—  Ê·Ìœ ›« Ê—… = 1  Ê·Ìœ „‰«ﬁ·… = 0 
	@ShwSemiManufacMat	INT = 0, -- ŒÌ«—  ›ﬂÌﬂ «·„Ê«œ ‰’› «·„’‰⁄…
	@ReadyGroupGuid		UNIQUEIDENTIFIER = 0x0, -- „Ã„Ê⁄… «·„Ê«œ «·Ã«Â“…
	@InStoreGuid		UNIQUEIDENTIFIER = 0x0, -- „” Êœ⁄ «·≈œŒ«·
	@ExcludeExistingQty BIT = 0,
	@ReadyMatStoreGuid UNIQUEIDENTIFIER = 0x0

AS
	SET NOCOUNT ON
	DECLARE @lang INT = [dbo].[fnConnections_GetLanguage]();
	-- ŒÌ«—«  ’—› «·„Ê«œ
	IF (@MatsSpendOptions = 1) -- «·ﬂ„Ì… «·„ÿ·Ê»… · ‰›Ì– Œÿ… «·≈‰ «Ã
	BEGIN
		SET @FormCnt	= 1
		SET @CustGuid	= 0x0
		SET @OrderTypeGuid	= 0x0
	END
	ELSE IF (@MatsSpendOptions = 2) -- «·ﬂ„Ì… «·„ÿ·Ê»… · ‰›Ì– ﬂ„Ì… „Õœœ…
	BEGIN
		SET @PlanGuid  = 0X0
		SET @CustGuid  = 0X0
		SET @OrderTypeGuid = 0X0
		SET @ReadyGroupGuid = 0x0
		IF (@FormCnt = 0)
			BEGIN
				SET @FormCnt = 1
			END
	END
	ELSE -- «·ﬂ„Ì… «·„ÿ·Ê»… · ‰›Ì– ÿ·»Ì«  «·»Ì⁄
	BEGIN
		SET @PlanGuid = 0x0
		SET @FormCnt  = 1
	END
	
	-- «·„Ê«œ «· «»⁄… ·„Ã„Ê⁄… «·„Ê«œ «·Ã«Â“… «·„Œ «—…
	CREATE TABLE #READYMAT (GUID UNIQUEIDENTIFIER, SECUERITY INT)
	INSERT INTO #READYMAT EXEC prcGetMatsList 0x0, @ReadyGroupGuid, 0, 0x0
	
	CREATE TABLE #FormTbl([GUID] UNIQUEIDENTIFIER, MatGUID UNIQUEIDENTIFIER, MatType INT, GrpGuid UNIQUEIDENTIFIER)
	IF (@MatsSpendOptions = 3)
	BEGIN
		IF (@FormGuid = 0x0)
		BEGIN
			INSERT INTO #FormTbl (GUID, MatGUID)
			SELECT FrmGUID, MatGUID FROM
				(
				SELECT
					MI.MatGuid,
					FM.Number,
					FM.GUID AS FrmGUID,
					RANK() OVER (PARTITION BY MI.MatGuid ORDER BY FM.Number DESC) AS FrmRANK
				FROM MI000 AS MI  
					INNER JOIN MN000 AS MN ON MN.GUID = MI.PARENTGUID  
					INNER JOIN FM000 AS FM ON FM.GUID = MN.FORMGUID  
				WHERE MN.TYPE = 0
					AND MI.TYPE = 0
					AND FM.IsHideForm = 0
					AND MI.MatGUID IN (SELECT DISTINCT GUID FROM #READYMAT)
				) AS TmpFormTbl
			WHERE TmpFormTbl.FrmRANK = 1
			ORDER BY Number			
		END
		ELSE
		BEGIN
			INSERT INTO #FormTbl (GUID, MatGUID, MatType, GrpGuid)
			SELECT DISTINCT FM.GUID, MI.MatGUID, 0, 0x0
			FROM FM000 AS FM
				INNER JOIN MN000 AS MN ON MN.FormGuid = FM.GUID
				INNER JOIN MI000 AS MI ON MI.ParentGUID = MN.GUID
			WHERE FM.GUID = @FormGuid AND FM.IsHideForm = 0 AND MI.Type = 0	AND MN.Type = 0 		
		END
		UPDATE #FormTbl
		SET MatType = 0, GrpGuid = @ReadyGroupGuid
	END
	ELSE
	BEGIN	
		IF (@FormGuid = 0x0)
		BEGIN
			INSERT INTO #FormTbl (GUID)
			SELECT Distinct FrmGUID FROM
				(
					SELECT
						MI.MatGuid,
						FM.Number,
						FM.GUID AS FrmGUID,
						RANK() OVER (PARTITION BY MI.MatGuid ORDER BY FM.Number DESC) AS FrmRANK
					FROM MI000 AS MI  
						INNER JOIN MN000 AS MN ON MN.GUID = MI.PARENTGUID  
						INNER JOIN FM000 AS FM ON FM.GUID = MN.FORMGUID  
					WHERE MN.TYPE = 0
						AND MI.TYPE = 0
						AND FM.IsHideForm = 0
						AND MI.MatGUID IN (SELECT DISTINCT GUID FROM #READYMAT)
				) AS TmpFormTbl
			WHERE TmpFormTbl.FrmRANK = 1
		END
		ELSE
		BEGIN
			INSERT INTO #FormTbl (GUID)
			SELECT DISTINCT FM.GUID
			FROM FM000 AS FM
				INNER JOIN MN000 AS MN ON MN.FormGuid = FM.GUID
				INNER JOIN MI000 AS MI ON MI.ParentGUID = MN.GUID
			WHERE FM.GUID = @FormGuid AND FM.IsHideForm = 0 AND MI.Type = 0	AND MN.Type= 0 		
		END
		UPDATE #FormTbl
		SET MatType = 0
	END
	-- ÃœÊ· «·„Ê«œ «·√Ê·Ì… Õ”» «·„«œ… «·√Ê·Ì… Ê„Ã„Ê⁄… «·„Ê«œ «·√Ê·Ì…
	CREATE TABLE #Matrials (GUID UNIQUEIDENTIFIER, UnitFact FLOAT, UnitName NVARCHAR(255), SECURITY INT)
	INSERT INTO #Matrials(GUID, SECURITY) EXEC prcGetMatsList 0x0, 0x0
		
    CREATE TABLE #Mat (GUID UNIQUEIDENTIFIER, UnitFact FLOAT, UnitName NVARCHAR(255), SECURITY INT)
	INSERT INTO #Mat(GUID, SECURITY) EXEC prcGetMatsList @MatGuid, @GroupGuid
		
	UPDATE mt
	SET
		mt.UnitFact =
			CASE
				WHEN @UseUnit = 0 THEN 1
				WHEN @UseUnit = 1 OR (@UseUnit = 3 AND mat.mtDefUnit = 2) THEN
					CASE mat.mtUnit2Fact
						WHEN 0 THEN 1 
						ELSE mat.mtUnit2Fact
					END 
				 WHEN @UseUnit = 2 OR (@UseUnit = 3 AND mat.mtDefUnit = 3) THEN 
					CASE mat.mtUnit3Fact 
						WHEN 0 THEN (CASE mat.mtDefUnit WHEN 2 THEN mat.mtUnit2Fact ELSE 1 END) 
						ELSE mat.mtUnit3Fact 
					END 
				 ELSE 1
			END,
		mt.UnitName =
			 CASE
				WHEN @UseUnit = 0 THEN mat.mtUnity
				WHEN @UseUnit = 1 THEN
					CASE mat.mtUnit2
						WHEN '' THEN mat.mtDefUnitName
						ELSE mat.mtUnit2
					END
				 WHEN @UseUnit = 2 THEN
					CASE mat.mtUnit3
						WHEN '' THEN mat.mtDefUnitName
						ELSE mat.mtUnit3
					END
				 ELSE mat.mtDefUnitName
			END
	FROM 
		vwMt mat
		INNER JOIN #Matrials mt ON mt.Guid = mat.mtGuid
	
		
			
	CREATE TABLE #Stores (Guid UNIQUEIDENTIFIER, Security INT)
	INSERT INTO #Stores Exec prcGetStoresList @OutStoreGuid
	--------------------------------------------------------------
	CREATE TABLE #OrdersGuid (Guid UNIQUEIDENTIFIER)
	INSERT INTO #OrdersGuid
		SELECT GUID
		FROM vwOrders 
		WHERE (BtGuid = @OrderTypeGuid OR @OrderTypeGuid = 0x0)
			AND (GUID = @OrderGuid OR @OrderGuid = 0x0)
	--------------------------------------------------------------
/*
„—ﬂ“ «·ﬂ·›… Â‰« ÂÊ „—ﬂ“ ﬂ·›… Œ—Ã ‰„Ê–Ã «· ’‰Ì⁄
*/
	/*DECLARE	@CostCenter UNIQUEIDENTIFIER
	SET @CostCenter = 0x0 
	SELECT @CostCenter = OutCostGuid from MN000 MN
				  WHERE FORMGUID = @FormGuid 
						AND @FormGuid <> 0x0 
						AND MN.TYPE = 0*/
	--------------------------------------------------------------
/*
 ÕœÌœ „Ã„Ê⁄… «·„Ê«œ ‰’› «·„’‰⁄…
*/
	DECLARE @SemiManGroup UNIQUEIDENTIFIER 
	SET @SemiManGroup = (SELECT [VALUE] from OP000 WHERE [NAME] ='man_semiconductGroup') 
	--------------------------------------------------------------
	CREATE TABLE [#SaleOrders] -- ÿ·»«  «·»Ì⁄
	(
    MaterialGuid	UNIQUEIDENTIFIER,
    BillGUID		UNIQUEIDENTIFIER,
    BillType		UNIQUEIDENTIFIER,
    [Required]		FLOAT,
    Achived			FLOAT,
    Remainder		FLOAT,
    Fininshed		INT,
    Cancle			INT
    )	
    		
	INSERT INTO [#SaleOrders] -- ÿ·»Ì«  «·»Ì⁄
		SELECT *
		FROM [fnGetOrdersQty] (@FromDate, @ToDate, 0x0, 0x0, 1, @CustGuid, @OrderGuid)
	
	--------------------------
	/*
	Õ”«» —ﬁ„ «·ÿ·»
	*/
	/*DECLARE @OrderNumber VARCHAR (255)
	SELECT @OrderNumber = Notes FROM bu000 WHERE Guid = @OrderTypeGuid*/
	--------------------------------------------------------------
	--select * from mi000
	/*
	Â‰« ‰Õœœ «·„Ê«œ Ê ‰Õ’· ⁄·Ï «·ﬂ„Ì… «·Ê«Ã» ’—›Â«
	*/

	-------------------------------------------------------------------
	CREATE TABLE #NonRawMats (MatGUID UNIQUEIDENTIFIER)
	CREATE TABLE #MatQty (MatGUID UNIQUEIDENTIFIER, Qty FLOAT)
	
	IF @ExcludeExistingQty = 1
	BEGIN
		INSERT INTO #NonRawMats
		SELECT DISTINCT MI.MatGUID
		FROM
			MI000 MI INNER JOIN MN000 MN ON MI.ParentGUID = MN.GUID
		WHERE 
			MN.Type = 0 AND MI.Type = 0
		--------------------------------------------------------------------
		INSERT INTO #MatQty
		SELECT BI.MatGUID, SUM(BI.Qty * CASE BT.bIsInput WHEN 1 THEN 1 ELSE -1 END) MatQty
		FROM
			fnGetStoresList(@ReadyMatStoreGuid) ST 
			INNER JOIN BI000 BI ON ST.Guid = BI.StoreGUID
			INNER JOIN BU000 BU ON BU.GUID = BI.ParentGuid
			INNER JOIN BT000 BT ON BT.GUID = BU.TypeGUID
			INNER JOIN #NonRawMats NR ON NR.MatGUID = BI.MatGUID
		WHERE
			BU.IsPosted = 1
		GROUP BY
			BI.MatGUID
	END

	CREATE TABLE #NeededQtyOfMat (MatGuid UNIQUEIDENTIFIER, Qty FLOAT)
	-------------------------------------------------------------------

	DECLARE @orderCount INT
	SELECT @orderCount = COUNT (Guid) FROM #OrdersGuid

	IF (@MatsSpendOptions = 1)
	BEGIN
		CREATE TABLE #PSI (Guid UNIQUEIDENTIFIER, FormGuid UNIQUEIDENTIFIER, Qty FLOAT)

		INSERT INTO #PSI
		SELECT distinct PSI.GUID, FM.GUID, PSI.Qty
		FROM 
			PSI000 PSI
			INNER JOIN MNPS000 AS MNPS ON MNPS.GUID = PSI.PARENTGUID
			INNER JOIN #FormTbl AS FM ON FM.GUID = PSI.FORMGUID
			INNER JOIN MN000 AS MN ON MN.FORMGUID = FM.GUID
			INNER JOIN MI000 AS MI ON MI.ParentGUID = MN.GUID
			INNER JOIN MT000 AS MT ON MT.GUID = MI.MATGUID
			INNER JOIN #Matrials AS mats ON mats.Guid = MT.Guid
			
			--INNER JOIN #OrdersGuid AS ORD ON ((ORD.Guid = PSI.orderNumGuid) OR (@orderCount = 0))
			WHERE   MN.TYPE = 0 
					AND (PSI.StartDate >= @FromDate OR @MatsSpendOptions = 2 OR @PlanGuid <> 0x0)
					AND (PSI.StartDate <= @ToDate OR @MatsSpendOptions = 2 OR @PlanGuid <> 0x0)
					AND MI.Type = 1 -- „Ê«œ √Ê·Ì…
					AND (PSI.State = 0) -- Õ«·… «·Œÿ… «„« „À» … √Ê „‰›–…
					--AND (FM.GUID IN (SELECT GUID FROM #FormTbl) OR @FormGuid = 0x0 OR FM.GUID = @FormGuid)
					--AND FM.GUID in (select GUID from #FormTbl)
					--AND ( ISNULL(@SemiManGroup, 0x0) = 0x0 OR MT.GROUPGUID NOT IN (SELECT * FROM fnGetGroupsList(@SemiManGroup))) -- ÌÃ» √‰ ·«  ﬂÊ‰ «·„«œ… ‰’› „’‰⁄…
					AND (@OrderGuid = 0x0 OR PSI.OrderNumGuid = @OrderGuid) -- ›ﬁÿ ﬁ·„ «·Œÿ… ··›∆… «·„Õœœ…
					AND (@PlanGuid = MNPS.GUID OR @PlanGuid = 0X0)
					AND ( EXISTS(SELECT GUID FROM #OrdersGuid AS ORD WHERE ORD.Guid = PSI.orderNumGuid)
							OR NOT EXISTS(SELECT GUID FROM #OrdersGuid) OR @OrderGuid = 0x0)
		-------------------------------------------------------------------------
		SELECT MT.GUID, MT.Code,CASE WHEN @lang > 0 THEN CASE WHEN Mt.LatinName = '' THEN MT.Name ELSE Mt.LatinName END ELSE  MT.Name END AS Name, SUM(PSI.Qty * MI.QTY) QtyHasToBeGiven
		INTO #QtyHasToBeGivenInPlan
		FROM 
			#PSI AS PSI
			INNER JOIN MN000 AS MN ON MN.FORMGUID = PSI.FormGuid
			INNER JOIN MI000 AS MI ON MI.ParentGUID = MN.GUID
			INNER JOIN MT000 AS MT ON MT.GUID = MI.MATGUID
			INNER JOIN #Matrials AS Mats ON Mats.Guid = MT.Guid
		WHERE 
			MN.Type = 0 AND MI.Type = 1
		GROUP BY 
			MT.GUID, MT.Code, CASE WHEN @lang > 0 THEN CASE WHEN Mt.LatinName = '' THEN MT.Name ELSE Mt.LatinName END ELSE  MT.Name END
	END
	ELSE IF(@MatsSpendOptions = 2)
	BEGIN
		SELECT MT.GUID, MT.Code, CASE WHEN @lang > 0 THEN CASE WHEN Mt.LatinName = '' THEN MT.Name ELSE Mt.LatinName END ELSE  MT.Name END AS Name, SUM(MI.QTY) QtyHasToBeGiven
		INTO #QtyHasToBeGivenInForm
		FROM 			
			#FormTbl AS FM
			INNER JOIN MN000 MN ON MN.FORMGUID = FM.GUID
			INNER JOIN MI000 MI ON MI.ParentGUID = MN.GUID
			INNER JOIN MT000 MT ON MT.GUID = MI.MATGUID
			INNER JOIN #Matrials AS mats ON mats.Guid = MT.Guid
		WHERE MN.Type = 0 AND					
			MI.Type = 1 -- „Ê«œ √Ê·Ì…
		GROUP BY MT.GUID, MT.Code,CASE WHEN @lang > 0 THEN CASE WHEN Mt.LatinName = '' THEN MT.Name ELSE Mt.LatinName END ELSE  MT.Name END
	END
	ELSE
	BEGIN
		CREATE TABLE #RemainingOrderMats (MatGuid UNIQUEIDENTIFIER, RemainingQty FLOAT, StoreQty FLOAT)

		INSERT INTO #RemainingOrderMats
		SELECT
			DISTINCT S.MaterialGuid,
			ISNULL(SUM(S.Remainder), 0) AS Remining, -- «·„ »ﬁÌ „‰ ÿ·»Ì«  «·»Ì⁄
			(SELECT ISNULL(SUM(QTY), 0) FROM MS000 WHERE MS000.MatGUID = S.MaterialGuid) AS StoreQTY -- «·„Œ“Ê‰
	 		 FROM #SaleOrders AS S			
				INNER JOIN bt000 AS B ON B.GUID = S.BillType								
			 WHERE (ISNULL(S.Fininshed, 0) = 0)
				And (ISNULL(S.Cancle, 0) = 0 )
				AND S.BillType = @OrderTypeGuid
				--AND (S.BillGUID = @OrderGuid OR S.BillGUID = 0x0)
			 GROUP BY S.MaterialGuid

		IF @ExcludeExistingQty = 1 AND @ShwSemiManufacMat = 0
		BEGIN
			UPDATE R SET RemainingQty = CASE WHEN RemainingQty - ISNULL(MQ.Qty, 0) < 0 THEN 0 ELSE RemainingQty - ISNULL(MQ.Qty, 0) END
			FROM 
				#RemainingOrderMats R 
				LEFT JOIN #MatQty MQ ON MQ.MatGUID = R.MatGuid
		END

		DECLARE @OrderMaterials CURSOR 
		SET @OrderMaterials  = CURSOR FOR 
		SELECT MatGuid, RemainingQty, StoreQty 
		FROM #RemainingOrderMats

		CREATE TABLE #Res1
		(
			MatGUID UNIQUEIDENTIFIER,
			Rem FLOAT
		)
		
		DECLARE @MtGUID UNIQUEIDENTIFIER, @Rem FLOAT, @StoreQty FLOAT
		OPEN @OrderMaterials
		FETCH NEXT FROM @OrderMaterials INTO @MtGUID, @Rem, @StoreQty
		
		WHILE @@FETCH_STATUS = 0
		BEGIN			
			DECLARE @FmGuid UNIQUEIDENTIFIER
			-- Â· „Ê«œ ÿ·» «·»Ì⁄ ·Â« ‰„Ê–Ã  ’‰Ì⁄
			SET @FmGuid = (SELECT TOP 1 GUID FROM #FormTbl WHERE MatGUID = @MtGUID)
				IF (@FmGuid <> 0x0)
				BEGIN
					DECLARE @MatCount INT
					SET @MatCount =
						(
						SELECT COUNT( DISTINCT (MI.MatGUID))
						FROM MI000 AS MI
							INNER JOIN MN000 AS MN ON MN.GUID = MI.ParentGUID
							INNER JOIN #FormTbl AS F ON F.GUID = MN.FormGUID
						WHERE MI.Type = 0 AND MN.type= 0 
							AND MN.FormGUID = @FmGuid
							AND F.MatType = 0
						)
											
					IF(@MatCount = 1) -- «·‰„Ê–Ã ÌÕ ÊÌ ⁄·Ï „«œ… Ã«Â“… Ê«Õœ… ›ﬁÿ
					BEGIN
						DECLARE @cnt FLOAT
						SET @cnt =
						(
						SELECT SUM(MI.QTY)
						FROM MI000 AS MI
							INNER JOIN MN000 AS MN ON MN.GUID = MI.ParentGUID
							INNER JOIN #FormTbl AS F ON F.GUID = MN.FormGUID
						WHERE MI.Type = 0 AND Mn.Type = 0
							AND MN.FormGUID = @FmGuid
							AND F.MatType = 0
						)
						INSERT INTO #Res1
						SELECT MI.MatGUID, (@Rem / @cnt) * MI.Qty
						FROM MI000 AS MI
							INNER JOIN MN000 AS MN ON MN.GUID = MI.ParentGUID
							INNER JOIN #FormTbl AS F ON F.GUID = MN.FormGUID
						WHERE MI.Type = 1	AND MN.type= 0 						
							AND MN.FormGUID = @FmGuid
							AND F.MatType = 0	
						-----------------------------------------------------
						IF @ShwSemiManufacMat = 1 AND @ExcludeExistingQty = 1
						BEGIN
							INSERT INTO #neededQtyOfMat
							SELECT @MtGUID, @Rem
						END
						-----------------------------------------------------
					END
					ELSE  -- «·‰„Ê–Ã ÌÕ ÊÌ ⁄·Ï √ﬂÀ— „‰ „«œ… Ã«Â“…
					BEGIN
						CREATE TABLE #Qtys (MaterialGuid UNIQUEIDENTIFIER, QTY FLOAT, REM FLOAT) -- Â· ÌÕ ÊÌ «·‰„Ê–Ã ⁄·Ï √ﬂÀ— „‰ „«œ… ÷„‰ ÿ·»Ì«  «·»Ì⁄
						INSERT INTO #Qtys
						SELECT DISTINCT MI.MatGuid, MI.Qty AS QTY , SaleOrders.Remainder
						FROM MI000 AS MI
							INNER JOIN #SaleOrders AS SaleOrders ON SaleOrders.MaterialGuid = MI.MatGUID
							INNER JOIN MN000 AS MN ON MN.GUID = MI.ParentGUID
							INNER JOIN #FormTbl AS F ON F.GUID = MN.FormGUID
						WHERE MN.Type= 0 AND 
							MI.Type = 0 AND MN.FormGUID = @FmGuid AND F.MatType = 0
								
						DECLARE @FormCntForOrder FLOAT, @MaterialGuid UNIQUEIDENTIFIER
						/*SET @FormCntForOrder = (SELECT MAX(ROUND(REM / QTY, 0)) FROM #Qtys) -- Õ”«» ⁄œœ «·‰„«–Ã «·„ÿ·Ê»…*/
						SET @FormCntForOrder = (SELECT MAX(REM / ISNULL(QTY, 1)) FROM #Qtys) -- Õ”«» ⁄œœ «·‰„«–Ã «·„ÿ·Ê»…
						SET @MaterialGuid = (Select TOP 1 MaterialGuid From #Qtys WHERE (REM / ISNULL(QTY, 1)) = @FormCntForOrder)					
						
						INSERT INTO #Res1
						SELECT DISTINCT MI.MatGUID, @FormCntForOrder * MI.Qty
						FROM MI000 AS MI
							INNER JOIN MN000 AS MN ON MN.GUID = MI.ParentGUID
							INNER JOIN #FormTbl AS F ON F.GUID = MN.FormGUID
						WHERE
							MI.Type = 1 AND MN.type= 0 
							AND MN.FormGUID = @FmGuid
							--AND MI.ParentGUID IN (SELECT DISTINCT ParentGUID FROM MI000 WHERE MatGUID = @MaterialGuid AND TYPE = 0)
							AND F.MatType = 0
						-----------------------------------------------------
						IF @ShwSemiManufacMat = 1 AND @ExcludeExistingQty = 1
						BEGIN
							INSERT INTO #neededQtyOfMat
							SELECT @MaterialGuid, ISNULL((SELECT TOP 1 REM FROM #Qtys WHERE MaterialGuid = @MaterialGuid), 0)
						END
						-----------------------------------------------------
						DROP TABLE #Qtys
					END
					UPDATE #FormTbl Set MatType = 1 WHERE GUID = @FmGuid OR MatGUID = @MtGUID OR MatGUID = @MaterialGuid
				END
				ELSE
					IF (EXISTS(
							SELECT 1
							FROM MI000 AS MI
								INNER JOIN MN000 AS MN ON MN.GUID = MI.ParentGUID
								INNER JOIN #FormTbl AS F ON F.GUID = MN.FormGUID
							WHERE MN.Type= 0 AND MI.Type = 1 AND MI.MatGUID = @MtGUID))
					BEGIN
					PRINT 0
						INSERT INTO #Res1
						VALUES(@MtGUID, @Rem)
					END
			FETCH NEXT FROM @OrderMaterials INTO @MtGUID, @Rem, @StoreQty
		END
		CLOSE @OrderMaterials
		DEALLOCATE @OrderMaterials

		SELECT MT.GUID, MT.Code, MT.Name, SUM(Res.Rem) QtyHasToBeGiven
		INTO #QtyHasToBeGivenInOrder	
		FROM #Res1 AS Res
			INNER JOIN MT000 AS MT ON Res.MatGUID = MT.GUID
		GROUP BY
			MT.GUID, MT.Code, MT.Name
	END
	--------------------------------------------------------------
	CREATE TABLE #QtyHasToBeGiven (Guid UNIQUEIDENTIFIER, Code NVARCHAR(255), Name NVARCHAR(255), QtyHasToBeGiven FLOAT)
	IF (@MatsSpendOptions = 1)
	BEGIN
		INSERT INTO #QtyHasToBeGiven
		SELECT *
		FROM #QtyHasToBeGivenInPlan
	END
	ELSE IF (@MatsSpendOptions = 2)
	BEGIN
		INSERT INTO #QtyHasToBeGiven
		SELECT *
		FROM #QtyHasToBeGivenInForm
	END
	ELSE
	BEGIN
		INSERT INTO #QtyHasToBeGiven
		SELECT *
		FROM #QtyHasToBeGivenInOrder
	END
	--------------------------------------------------------------
	/*
	Â‰« ‰Õ”» «·ﬂ„Ì… «·„’—Ê›… ··„Ê«œ
	*/
	SELECT 
		BI.MatGuid, 
		SUM( 
			CASE BT.BILLTYPE 
				WHEN 0 THEN BI.QTY 
				WHEN 3 THEN BI.QTY 
				WHEN 4 THEN BI.QTY 
				WHEN 1 THEN -BI.QTY 
				WHEN 2 THEN -BI.QTY 
				WHEN 5 THEN -BI.QTY 
			END) 
		AS QtyHasBeenGiven
	INTO #QtyHasBeenGiven
	FROM
		BI000 AS BI
		INNER JOIN BU000 AS BU ON BU.GUID = BI.ParentGuid
		INNER JOIN BT000 AS BT ON BT.GUID = BU.TypeGUID	
		INNER JOIN #QtyHasToBeGiven AS QtyHasToBeGiven ON QtyHasToBeGiven.GUID = BI.MatGuid
	WHERE
		(Bu.Date >= @FromDate OR @MatsSpendOptions = 2)
		AND (BU.Date <= @ToDate OR @MatsSpendOptions = 2)
		AND BU.isposted = 1 -- Õ’—« «·›Ê« Ì— «·„—Õ·…
		AND (@InStoreGUID = 0x0 OR BU.StoreGUID = @InStoreGuid)		
		AND (@CostCenter = 0x0 OR (BU.CostGUID = @CostCenter AND BI.CostGUID = 0x0)OR (@CostCenter = BI.CostGUID AND BU.CostGUID <> @CostCenter))
		--AND (@OrderGuid = 0x0 OR BI.ClassPtr = @OrderNumber) -- ›ﬁÿ ﬁ·„ «·›« Ê—… ··›∆… «·„Õœœ…
	GROUP BY BI.MatGuid
	
	IF (@GenBillOrTrn = 1)
	BEGIN
		UPDATE #QtyHasBeenGiven
		SET QtyHasBeenGiven = 0
	END
	--------------------------------------------------------------	
	/*
	Â‰« ‰Õ”» «·„Œ“Ê‰
	*/
	SELECT
		MAT.Guid AS MatGuid,
		(SELECT ISNULL(SUM(QTY), 0)
		 FROM MS000 AS MS
		 WHERE MS.MatGUID = MAT.Guid
			AND (MS.StoreGUID = @OutStoreGuid OR MS.StoreGUID = 0x0)
		) AS QtyInStore
	INTO #QtyInStore
	FROM #Matrials AS MAT
	--------------------------------------------------------------
	/*
	«·‰ ÌÃ… «·‰Â«∆Ì… »œÊ‰  ›ﬂÌﬂ
	*/
	/*
	Â‰« √÷›‰« ··‰ ÌÃ… Ê”ÿÌ ”⁄— «·„«œ…
	*/
	SELECT 
		QtyHasToBeGiven.GUID, 
		QtyHasToBeGiven.Code, 
		QtyHasToBeGiven.Name,
		mats.UnitName ,
		MT.AvgPrice,
		ISNULL(QtyHasBeenGiven, 0) AS QtyHasBeenGiven,
		ISNULL(QtyHasToBeGiven, 0) * CASE @MatsSpendOptions WHEN 2 THEN @FormCnt ELSE 1 END AS QtyHasToBeGiven, 
		ISNULL(QtyInStore, 0) AS QtyInStore,
		mats.UnitFact , 
		CASE @MatsToSpendOption 
			WHEN 0 THEN 
				CASE
					WHEN QtyInStore > 0 THEN
						CASE
							WHEN QtyInStore >= QtyHasToBeGiven * (CASE @MatsSpendOptions WHEN 2 THEN @FormCnt ELSE 1 END)
								THEN QtyHasToBeGiven * (CASE @MatsSpendOptions WHEN 2 THEN @FormCnt ELSE 1 END)
							ELSE QtyInStore 
						END 
					ELSE 0 
				END
			WHEN 1 THEN
				CASE 
					WHEN QtyInStore > 0 THEN 
						CASE 
							WHEN ((QtyHasToBeGiven * (CASE @MatsSpendOptions WHEN 2 THEN @FormCnt ELSE 1 END)) - ISNULL(QtyHasBeenGiven, 0)) < 0 THEN 0
							WHEN QtyInStore >= (QtyHasToBeGiven * (CASE @MatsSpendOptions WHEN 2 THEN @FormCnt ELSE 1 END) - ISNULL(QtyHasBeenGiven, 0))
								THEN (QtyHasToBeGiven * (CASE @MatsSpendOptions WHEN 2 THEN @FormCnt ELSE 1 END) - ISNULL(QtyHasBeenGiven, 0))
							ELSE QtyInStore 
						END
					ELSE 0
				END 
			ELSE 0
		END	AS QtyToSpend
	INTO #Result	
	FROM  
		#QtyHasToBeGiven AS QtyHasToBeGiven
		INNER JOIN MT000 MT ON MT.GUID = QtyHasToBeGiven.GUID
		INNER JOIN #Matrials  as mats  ON mats.GUID = MT.GUID 
		LEFT JOIN #QtyHasBeenGiven AS QtyHasBeenGiven ON QtyHasBeenGiven.MatGUID = QtyHasToBeGiven.GUID
		LEFT JOIN #QtyInStore AS QtyInStore ON QtyInStore.MatGUID = QtyHasToBeGiven.GUID	
/*-----------------------------------------------------------------------------------------------	*/
	SELECT res.GUID AS MatGuid , 
		   res.Code,
		   res.Name,
		   res.UnitName, 
		   res.AvgPrice,
		   res.QtyHasBeenGiven,
		   res.QtyHasToBeGiven,
		   res.QtyInStore,
		   res.UnitFact,
		   res.QtyToSpend,
		   @UseUnit as UnitIndex
	INTO #ResultForPlanning
	FROM #Result AS res 
	ORDER BY res.Code

	UPDATE mt
	SET
		mt.UnitFact =
			CASE
				WHEN @UseUnit = 0 THEN 1
				WHEN @UseUnit = 1 OR (@UseUnit = 3 AND mat.mtDefUnit = 2) THEN
					CASE mat.mtUnit2Fact
						WHEN 0 THEN 1 
						ELSE mat.mtUnit2Fact
					END 
				 WHEN @UseUnit = 2 OR (@UseUnit = 3 AND mat.mtDefUnit = 3) THEN 
					CASE mat.mtUnit3Fact 
						WHEN 0 THEN (CASE mat.mtDefUnit WHEN 2 THEN mat.mtUnit2Fact ELSE 1 END) 
						ELSE mat.mtUnit3Fact 
					END 
				 ELSE 1
			END,
		mt.UnitName =
			 CASE
				WHEN @UseUnit = 0 THEN mat.mtUnity
				WHEN @UseUnit = 1 THEN
					CASE mat.mtUnit2
						WHEN '' THEN mat.mtDefUnitName
						ELSE mat.mtUnit2
					END
				 WHEN @UseUnit = 2 THEN
					CASE mat.mtUnit3
						WHEN '' THEN mat.mtDefUnitName
						ELSE mat.mtUnit3
					END
				 ELSE mat.mtDefUnitName
			END
	FROM 
		vwMt mat
		INNER JOIN #Mat mt ON mt.Guid = mat.mtGuid
	---------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------
	IF @ExcludeExistingQty = 1
	BEGIN
		CREATE TABLE #ExcludeExistingEeadyQty(MatGuid UNIQUEIDENTIFIER, Qty FLOAT)

		CREATE TABLE #FormNeededMatQty (FormGuid UNIQUEIDENTIFIER, MatGuid UNIQUEIDENTIFIER, FormPercent FLOAT, Qty FLOAT)

		IF @MatsSpendOptions = 1
		BEGIN
			INSERT INTO #FormNeededMatQty
			SELECT 
				PSI.FormGuid, MI.MatGUID, 
				(PSI.Qty * MI.Qty - CASE WHEN ISNULL(MQ.Qty, 0) < 0 THEN 0 ELSE ISNULL(MQ.Qty, 0) END) / (PSI.Qty * MI.QTY),
				(PSI.Qty * MI.Qty)
			FROM 
				(SELECT FormGuid, SUM(Qty) Qty FROM #PSI GROUP BY FormGuid) PSI
				INNER JOIN MN000 AS MN ON MN.FORMGUID = PSI.FormGuid
				INNER JOIN MI000 AS MI ON MI.ParentGUID = MN.GUID
				LEFT JOIN #MatQty MQ ON MQ.MatGUID = MI.MatGUID
			WHERE 
				MN.Type = 0 AND MI.Type = 0
			------------------------------------------------------------
		END
		ELSE IF @MatsSpendOptions = 2
		BEGIN
			INSERT INTO #FormNeededMatQty
			SELECT FM.GUID, MI.MatGUID,
			(@FormCnt * MI.Qty - CASE WHEN ISNULL(MQ.Qty, 0) < 0 THEN 0 ELSE ISNULL(MQ.Qty, 0) END) / (@FormCnt * MI.Qty),
			(@FormCnt * MI.Qty)
			FROM 
				FM000 AS FM 
				INNER JOIN MN000 AS MN ON MN.FORMGUID = FM.GUID
				INNER JOIN MI000 MI ON MI.ParentGUID = MN.GUID
				LEFT JOIN #MatQty MQ ON MQ.MatGUID = MI.MatGUID
			WHERE
				FM.GUID = @FormGuid AND MN.TYPE = 0 AND MI.Type = 0
		END
		-----------------------------------------------------------

		INSERT INTO #NeededQtyOfMat
		SELECT MatGuid, SUM(Qty) 
		FROM
			(SELECT MatGuid, FormPercent, Qty, ROW_NUMBER() OVER (PARTITION BY FormGuid ORDER BY FormPercent DESC) MatRank
			FROM #FormNeededMatQty) R
		WHERE MatRank = 1
		GROUP BY MatGuid
	END
	
	---------------------------/*  ›ﬂÌﬂ «·„Ê«œ ‰’› «·„’‰⁄… */ ---------------------------------
	IF (@ShwSemiManufacMat = 1)
	BEGIN 
		IF @ExcludeExistingQty = 1
		BEGIN
			EXEC CalcQtyAfterExcludeExistingQtys 
		END

	  EXEC GetRawMatQtyForControlPlanning

	   UPDATE #ResultForPlanning 
	   SET UnitIndex  = @UseUnit
		

     SELECT res.MatGuid  , 
		   res.Code,
		   res.Name,
		   mt.UnitName, 
		   ISNULL(MAX(res.AvgPrice), 0 )as AvgPrice,
		   ISNULL(MAX(res.QtyHasBeenGiven), 0 ) as QtyHasBeenGiven,
		   ISNULL(MAX(res.QtyHasToBeGiven), 0 ) as QtyHasToBeGiven,
		   ISNULL(MAX(res.QtyInStore), 0 ) as QtyInStore,
		   mt.UnitFact,
		   ISNULL(MAX(res.QtyToSpend), 0 ) as QtyToSpend
     INTO #Res 
	 FROM #ResultForPlanning res  INNER JOIN #Mat mt ON mt.GUID = res.MatGuid
   GROUP BY res.MatGuid , res.Code, res.Name, mt.UnitName, mt.UnitFact
   
	IF @ExcludeExistingQty = 1
	BEGIN
		UPDATE R SET QtyHasToBeGiven = CASE WHEN ERQ.Qty < 0 THEN 0 ELSE ERQ.Qty END
		FROM
			#Res R 
			INNER JOIN 
			(SELECT MatGuid, SUM(Qty) Qty 
			FROM #ExcludeExistingEeadyQty 
			GROUP BY MatGuid) ERQ ON R.MatGuid = ERQ.MatGuid
	END

  --------------------------------------------------------------
	/*
	Â‰« ‰Õ”» «·ﬂ„Ì… «·„’—Ê›… ··„Ê«œ
	*/
    SELECT 
		BI.MatGuid, 
		SUM( 
			CASE BT.BILLTYPE 
				WHEN 0 THEN BI.QTY 
				WHEN 3 THEN BI.QTY 
				WHEN 4 THEN BI.QTY 
				WHEN 1 THEN -BI.QTY 
				WHEN 2 THEN -BI.QTY 
				WHEN 5 THEN -BI.QTY 
			END) 
		AS QtyHasBeenGiven
	INTO #NewQtyHasBeenGiven
	FROM
		BI000 AS BI
		INNER JOIN BU000 AS BU ON BU.GUID = BI.ParentGuid
		INNER JOIN BT000 AS BT ON BT.GUID = BU.TypeGUID	
		INNER JOIN #Res AS QtyHasToBeGiven ON QtyHasToBeGiven.MatGuid = BI.MatGuid
	WHERE
		(Bu.Date >= @FromDate OR @MatsSpendOptions = 2)
		AND (BU.Date <= @ToDate OR @MatsSpendOptions = 2)
		AND BU.isposted = 1 -- Õ’—« «·›Ê« Ì— «·„—Õ·…
		AND (@InStoreGUID = 0x0 OR BU.StoreGUID = @InStoreGuid)		
		AND (@CostCenter = 0x0 OR (BU.CostGUID = @CostCenter AND BI.CostGUID = 0x0)OR (@CostCenter = BI.CostGUID AND BU.CostGUID <> @CostCenter))
		--AND (@OrderGuid = 0x0 OR BI.ClassPtr = @OrderNumber) -- ›ﬁÿ ﬁ·„ «·›« Ê—… ··›∆… «·„Õœœ…
	GROUP BY BI.MatGuid
	IF (@GenBillOrTrn = 1)
	BEGIN
		UPDATE #NewQtyHasBeenGiven
		SET QtyHasBeenGiven = 0
	END
	-------------------------------------------
	SELECT
			RowTb.MatGuid AS GUID ,
		 RowTb.Code , 
		 RowTb.Name,
		 mats.UnitName,
		 MT.AvgPrice,
		 ISNULL(QtyHasBeenGiven.QtyHasBeenGiven, 0) as QtyHasBeenGiven, 
		 MAX(RowTb.QtyHasToBeGiven) AS QtyHasToBeGiven, 
		 ISNULL(QtyInStore.QtyInStore, 0) as QtyInStore,
		 mats.UnitFact, 
		CASE @MatsToSpendOption 
			WHEN 0 THEN 
				CASE
					WHEN QtyInStore.QtyInStore > 0 THEN
						CASE
							WHEN QtyInStore.QtyInStore >= QtyHasToBeGiven --* (CASE @MatsSpendOptions WHEN 2 THEN @FormCnt ELSE 1 END)
								THEN QtyHasToBeGiven --* (CASE @MatsSpendOptions WHEN 2 THEN @FormCnt ELSE 1 END)
							ELSE QtyInStore.QtyInStore 
						END 
					ELSE 0 
				END
			WHEN 1 THEN
				CASE 
					WHEN QtyInStore.QtyInStore > 0 THEN 
						CASE 
							WHEN ((QtyHasToBeGiven) --* (CASE @MatsSpendOptions WHEN 2 THEN @FormCnt ELSE 1 END))
							 - ISNULL(QtyHasBeenGiven.QtyHasBeenGiven, 0)) < 0 THEN 0
							WHEN QtyInStore.QtyInStore >= (QtyHasToBeGiven * 
							(CASE @MatsSpendOptions WHEN 2 THEN @FormCnt ELSE 1 END) - ISNULL(QtyHasBeenGiven.QtyHasBeenGiven, 0))
								THEN (QtyHasToBeGiven --* (CASE @MatsSpendOptions WHEN 2 THEN @FormCnt ELSE 1 END)
								 - ISNULL(QtyHasBeenGiven.QtyHasBeenGiven, 0))
							ELSE QtyInStore.QtyInStore 
						END
					ELSE 0
				END 
			ELSE 0
		END	AS QtyToSpend
	FROM  
		#Res RowTb 
		INNER JOIN MT000 MT ON MT.GUID = RowTb.MatGuid
		INNER JOIN #Mat AS Mats ON Mats.GUID = MT.GUID
	    LEFT JOIN #NewQtyHasBeenGiven AS QtyHasBeenGiven ON QtyHasBeenGiven.MatGUID = RowTb.MatGuid
		LEFT JOIN #QtyInStore AS QtyInStore ON QtyInStore.MatGUID = RowTb.MatGuid
	  GROUP BY 
				RowTb.MatGuid  ,
				RowTb.Code , 
				RowTb.Name,
				mats.UnitName,
				MT.AvgPrice,
				QtyHasBeenGiven.QtyHasBeenGiven, RowTb.QtyHasToBeGiven
				,QtyInStore.QtyInStore,
				mats.UnitFact--, 
				--QtyInStore.QtyInStore
		ORDER BY
		RowTb.Code
	END 
	ELSE 
	BEGIN
		IF @ExcludeExistingQty = 1 AND @ShwSemiManufacMat = 0
		BEGIN
			UPDATE R SET QtyHasToBeGiven = QtyHasToBeGiven * NMQ.FormPercent
			FROM
				#FormNeededMatQty NMQ
				INNER JOIN MN000 AS MN ON MN.FORMGUID = NMQ.FormGuid
				INNER JOIN MI000 MI ON MI.ParentGUID = MN.GUID
				INNER JOIN #Result R ON R.Guid = MI.MatGUID
			WHERE
				MN.Type = 0 AND MI.Type = 1
			-----------------------------------------------------

			UPDATE MQ SET MQ.Qty = MQ.Qty - ((1 - FormPercent) * NQ.Qty)
			FROM 
				#FormNeededMatQty NQ INNER JOIN #MatQty MQ ON NQ.MatGuid = MQ.MatGUID
			WHERE
				NQ.FormPercent < 1

			UPDATE R SET QtyHasToBeGiven = QtyHasToBeGiven - CASE WHEN MQ.Qty < 0 THEN 0 ELSE MQ.Qty END
			FROM
				#Result R 
				INNER JOIN #MatQty MQ ON MQ.MatGUID = R.Guid

			UPDATE #Result SET QtyHasToBeGiven = 0 WHERE QtyHasToBeGiven < 0
		END
		---------------------------------------------------------
		SELECT   res.GUID  , 
			   res.Code,
			   res.Name,
			   mt.UnitName, 
			   ISNULL(res.AvgPrice, 0 )as AvgPrice,
			   ISNULL(res.QtyHasBeenGiven, 0 ) as QtyHasBeenGiven,
			   ISNULL(res.QtyHasToBeGiven, 0 ) as QtyHasToBeGiven,
			   ISNULL(res.QtyInStore, 0 ) as QtyInStore,
			   mt.UnitFact,
			   ISNULL(res.QtyToSpend, 0 ) as QtyToSpend
		FROM #Result res  INNER JOIN #Mat mt ON mt.GUID = res.Guid
		ORDER BY res.Code
	END
################################################################################
CREATE PROCEDURE prcManufacturingPlan_GetBillsInfo  
	@BillTypeGuid     [UNIQUEIDENTIFIER] =  0x0    

AS    
	SET NOCOUNT ON    

DECLARE @BillGuid       [UNIQUEIDENTIFIER]
DECLARE @CurPtr         [UNIQUEIDENTIFIER]
DECLARE @BillNumber     [INT]

SET	   @BillGuid		    =  NEWID()
SET	   @CurPtr				= (SELECT TOP 1 Guid			FROM my000	WHERE [CurrencyVal] = 1)
SELECT @BillNumber	        = ISNULL(MAX(Number),  0 ) + 1	FROM bu000	WHERE  TypeGuid  = @BillTypeGuid

SELECT @CurPtr AS CurPtr,@BillNumber AS BillNumber
################################################################################
CREATE PROCEDURE GetRawMatQtyForControlPlanning
AS  
 SET NOCOUNT ON 
	--///////////////////////////////////////////////////////////////////////////////      
	CREATE Table #RowMat(
		SelectedGuid UNIQUEIDENTIFIER, 
                     Guid UNIQUEIDENTIFIER, 
                     ParentGuid UNIQUEIDENTIFIER,
					 ParentParentGUID UNIQUEIDENTIFIER,
                     ClassPtr NVARCHAR(255),
                     FormName NVARCHAR(255), 
                     MatGuid UNIQUEIDENTIFIER,   
	                 MatName NVARCHAR(255), 
	                 Qty Float, 
	                 QtyInForm Float, 
	                 [Path] NVARCHAR(1000),
					 [ParentPath] NVARCHAR(1000), 
	                 Unit int, 
	                 IsSemiReadyMat int, 
					 G int default 0,
					 NeededFormsCount FLOAT,
					 [IsResultOfFormWithMoreThanOneProducedMaterial] BIT )  
	CREATE Table #RowMat2(
		SelectedGuid UNIQUEIDENTIFIER, 
                     Guid UNIQUEIDENTIFIER, 
                     ParentGuid UNIQUEIDENTIFIER, 
					 ParentParentGUID UNIQUEIDENTIFIER,
                     ClassPtr NVARCHAR(255),
                     FormName NVARCHAR(255), 
                     MatGuid UNIQUEIDENTIFIER,   
	                 MatName NVARCHAR(255), 
	                 Qty Float, 
	                 QtyInForm Float, 
	                 [Path] NVARCHAR(1000), 
					 [ParentPath] NVARCHAR(1000),
	                 Unit int, 
	                 IsSemiReadyMat int, 
					 G int default 0,
					 NeededFormsCount FLOAT,
					 [IsResultOfFormWithMoreThanOneProducedMaterial] BIT )
	CREATE TABLE #RowMat3(
		MatGUID UNIQUEIDENTIFIER,
		MatName	NVARCHAR(255),
		MatLatinName NVARCHAR(255),
		MatCode	NVARCHAR(255),
		Qty0 FLOAT,
		CurUnit INT
	) 
	CREATE Table #Result1(
				SelectedGuid UNIQUEIDENTIFIER, 
				[Guid] UNIQUEIDENTIFIER, 
				ParentGuid UNIQUEIDENTIFIER,
				ParentParentGUID UNIQUEIDENTIFIER, --Parent Form GUID
				ClassPtr NVARCHAR(255),
				FormName NVARCHAR(255), 
				MatGuid UNIQUEIDENTIFIER,   
				MatName NVARCHAR(255), 
				Qty Float, 
				QtyInForm Float, 
				[Path] NVARCHAR(1000), 
				[ParentPath] NVARCHAR(1000),
				Unit INT, 
				IsSemiReadyMat INT, 
				G INT DEFAULT 0,
				NeededFormsCount FLOAT,
				[IsResultOfFormWithMoreThanOneProducedMaterial] BIT) 
	CREATE Table #Result2(
				SelectedGuid UNIQUEIDENTIFIER, 
				[Guid] UNIQUEIDENTIFIER, 
				ParentGuid UNIQUEIDENTIFIER,
				ParentParentGUID UNIQUEIDENTIFIER, 
				ClassPtr NVARCHAR(255),
				FormName NVARCHAR(255), 
				MatGuid UNIQUEIDENTIFIER,   
				MatName NVARCHAR(255), 
				Qty Float, 
				QtyInForm Float, 
				[Path] NVARCHAR(1000), 
				[ParentPath] NVARCHAR(1000),
				Unit INT, 
				IsSemiReadyMat INT, 
				G INT DEFAULT 0,
				NeededFormsCount FLOAT,
				[IsResultOfFormWithMoreThanOneProducedMaterial] BIT) 
	DECLARE 
		@c CURSOR,    
		@M_GUID UNIQUEIDENTIFIER,   
		@M_Qty FLOAT,
		@Unit INT

	SET @c = CURSOR FAST_FORWARD FOR SELECT MatGuid, QtyHasToBeGiven, UnitIndex FROM #ResultForPlanning
	OPEN @c FETCH FROM @c INTO @M_GUID, @M_Qty, @Unit 
	WHILE @@FETCH_STATUS = 0    
	BEGIN    
		INSERT INTO #Result1(SelectedGuid, Guid, ParentGuid, ParentParentGUID, ClassPtr, FormName, MatGuid, MatName, Qty, QtyInForm, [Path], ParentPath, Unit, IsSemiReadyMat, NeededFormsCount, [IsResultOfFormWithMoreThanOneProducedMaterial])  
		EXEC prcGetManufacMaterialTree @M_GUID

		UPDATE #Result1
		SET Qty = Qty * @M_Qty

		IF (SELECT COUNT(*) FROM #Result1) > 0 
		BEGIN 
			INSERT INTO #RowMat 
				SELECT * 
				FROM #Result1
				WHERE IsSemiReadyMat = 0
			
			UPDATE #RowMat 
			SET	G = 1
				,NeededFormsCount = ( Qty / QtyInForm) 
			WHERE 
				G = 0 
				AND 
				SelectedGuid = @M_GUID 

			INSERT INTO #Result2
			SELECT * 
			FROM #RESULT1
			WHERE IsSemiReadyMat = 1

			UPDATE
				#Result2
			SET
				NeededFormsCount = (Qty / QtyInForm)
			WHERE SelectedGuid = @M_GUID
		END 
		ELSE 
		BEGIN 
			DECLARE @mtName AS NVARCHAR(50) 
			
		
			
			INSERT INTO #RowMat(SelectedGuid, Guid, ParentGuid, ParentParentGUID, ClassPtr, FormName, MatGuid, MatName, Qty, QtyInForm, [Path], [ParentPath], Unit, IsSemiReadyMat, NeededFormsCount, [IsResultOfFormWithMoreThanOneProducedMaterial])
			VALUES (@M_GUID, 0x0, 0x0, 0x0, '', '', @M_GUID, (SELECT mtName FROM vwMt WHERE [mtGUID] = @M_GUID), @M_Qty, 0, '', '', @Unit, 0, 0, 0) 
		END 
		
		DELETE #Result1 
		FETCH FROM @c INTO @M_GUID, @M_Qty, @Unit 
	END      
	CLOSE @c DEALLOCATE @c    

	-- Mixing Both ways
	-- Mark raw mats those are result of a form with more than one (ready/ semi ready) materials to apply MAX to them
	-- then apply the SUM

	INSERT INTO #RowMat2
	SELECT
		*
	FROM
		#RowMat
	WHERE
		[IsResultOfFormWithMoreThanOneProducedMaterial] = 0
		AND
		[IsSemiReadyMat] = 0

	
   UPDATE #RowMat2
		SET Unit = 1 


	if (( SELECT COUNT(R.COUNTER) FROM (
				SELECT COUNT(ParentGuid) COUNTER 
				FROM #RowMat2 
					WHERE ParentParentGuid = 0x0 
				GROUP BY ParentGuid 
				)R ) > 1 ) 
	BEGIN 
		UPDATE #RowMat2
		SET Qty = RR.Qty FROM (SELECT SUM(R.QTY) Qty , R.MatGuid MatGuid
					 FROM #RowMat2 R  
					 group by R.MatGuid 
					)RR
					WHERE  RR.MatGuid = #RowMat2.MatGuid
		END 
	DELETE FROM #RowMat
	WHERE
		[IsResultOfFormWithMoreThanOneProducedMaterial] = 0
		AND
		[IsSemiReadyMat] = 0

	INSERT INTO #RowMat3
	SELECT
		X.MatGuid,
		X.MatName,
		Mt.mtLatinName,
		Mt.mtCode,
		X.QtyInForm * X.MaxNeededFormsCount,
		X.Unit
	FROM
	(
		SELECT
			MatGuid,
			MatName,
			[Path],
			QtyInForm,
			Unit,
			Max(NeededFormsCount) MaxNeededFormsCount
		FROM 
			#RowMat
		WHERE
			[ParentParentGUID] = 0x00
		GROUP BY
			MatGuid,
			MatName,
			[Path],
			QtyInForm,
			Unit	
	) X INNER JOIN vwMt Mt ON Mt.[mtGUID] = X.MatGuid



	DELETE FROM #RowMat
	WHERE
		[ParentParentGUID] = 0x00



	INSERT INTO #RowMat3
	SELECT
		R2.MatGuid,
		R2.MatName AS MatName,
		MT.LatinName AS MatLatinName,
		MT.Code AS MatCode,
		MAX(R2.QtyInForm * R2.NeededFormsCount) As Qty0,
		R2.Unit AS CurUnit
	FROM
	(
		SELECT
			rm.MatGUID,
			rm.MatName,
			rm.Unit,
			rm.QtyInForm,
			res2.MaxSumMaxMax NeededFormsCount
		FROM 
			#RowMat rm 
			INNER JOIN 
			(
				SELECT
					Form,
					MAX(SumMaxNeededFormsCount) MaxSumMaxMax
				FROM
				(
					SELECT
						MatGuid,
						MatName,
						Form,
						QtyInForm,
						SUM(MaxNeededFormsCount) SumMaxNeededFormsCount
					FROM
					(
						SELECT
							MatGuid,
							MatName,
							Form,
							ParentParentGUID,
							QtyInForm,
							MAX(MaxNeededFormsCount) MaxNeededFormsCount
						FROM
						(
							SELECT
								MatGuid,
								MatName,
								ParentGUID AS Form,
								ParentParentGUID,
								[Path],
								[ParentPath],
								QtyInForm,
								MAX(NeededFormsCount) as MaxNeededFormsCount
							FROM 
								#Result2
							GROUP BY
								MatGuid,
								MatName,
								ParentGUID,
								ParentParentGUID,
								[Path],
								[ParentPath]
								,QtyInForm
						) H
						GROUP BY
							MatGuid,
							MatName,
							Form,
							ParentParentGUID,
							QtyInForm
					) H2
					GROUP BY
						MatGuid,
						MatName,
						Form,
						QtyInForm
				) H3
				GROUP BY
					Form
					
			) res2 ON res2.Form = rm.ParentParentGUID 
		WHERE 
			[IsResultOfFormWithMoreThanOneProducedMaterial] = 1
		GROUP BY
			rm.MatGUID,
			rm.MatName,
			rm.QtyInForm,
			rm.Unit,
			res2.MaxSumMaxMax
	) R2
		INNER JOIN Mt000 MT ON R2.MatGUID = MT.[GUID]
	GROUP BY
		R2.MatGUID,
		R2.MatName,
		MT.LatinName,
		MT.Code,
		R2.Unit

	INSERT INTO #RowMat3
	SELECT
		R2.MatGUID,
		MT.Name AS MatName,
		MT.LatinName AS MatLatinName,
		MT.Code AS MatCode,
		MAX(R2.Qty) AS Qty0,
		R2.Unit AS CurUnit
	FROM
		#RowMat2 R2
		INNER JOIN MT000 MT ON R2.MatGUID = MT.[GUID]
	GROUP BY
		R2.MatGUID,
		MT.Name,
		MT.LatinName,
		MT.Code,
		R2.Unit


	
	SELECT 
		r3.MatGuid, 
		r3.MatName, 
		r3.MatLatinName, 
		r3.MatCode,
		SUM(r3.Qty0) AS Qty, 
		r3.CurUnit
	INTO #RowTable	   
	FROM 
		#RowMat3 r3  
	GROUP BY
		r3.MatGuid, 
		r3.MatName, 
		r3.MatLatinName, 
		r3.MatCode,
		r3.CurUnit
	ORDER BY
		r3.MatName
		
	
	UPDATE #RowTable 
   SET Qty = 
			(
				SELECT SUM(RowTb.Qty) 
				FROM 
					#RowTable RowTb
					WHERE  RowTb.MatGuid = #RowTable.MatGuid
					GROUP BY RowTb.MatGUID
					
				)

	 DELETE FROM #ResultForPlanning 

	INSERT INTO #ResultForPlanning
		SELECT 	
				RowTb.MatGUID AS MatGuid,
				RowTb.MatCode As Code,
				RowTb.MatName AS Name,
				'',
				0,
				0,
				RowTb.Qty AS QtyHasToBeGiven,
				0,
		        RowTb.CurUnit AS UnitFact,
				0,
				0
		FROM 
	        #RowTable RowTb 
################################################################################
CREATE PROC CalcQtyAfterExcludeExistingQtys
AS
BEGIN
 
	DECLARE @NonRawMat CURSOR  
	DECLARE @NonRawMatGuid UNIQUEIDENTIFIER
	DECLARE @NeededQty FLOAT

	SET @NonRawMat = CURSOR FAST_FORWARD FOR 
	SELECT matguid, qty
	FROM #neededQtyOfMat
	
	OPEN @NonRawMat
	FETCH FROM @NonRawMat INTO @NonRawMatGuid, @NeededQty

	WHILE @@FETCH_STATUS = 0    
	BEGIN  
		EXEC CalcRawMaterialQtyForReadyMat @NonRawMatGuid, @NeededQty 
		FETCH FROM @NonRawMat INTO @NonRawMatGuid, @NeededQty
	END

	CLOSE @NonRawMat
	DEALLOCATE @NonRawMat
END
################################################################################
CREATE PROC CalcRawMaterialQtyForReadyMat
	@MatGuid UNIQUEIDENTIFIER,
	@NeededQty FLOAT
AS
BEGIN
	
	CREATE Table #MatTree
	(
		SelectedGuid UNIQUEIDENTIFIER, 
		[Guid] UNIQUEIDENTIFIER, 
		ParentGuid UNIQUEIDENTIFIER,
		ParentParentGUID UNIQUEIDENTIFIER,
		ClassPtr NVARCHAR(255),
		FormName NVARCHAR(255) COLLATE ARABIC_CI_AI, 
		MatGuid UNIQUEIDENTIFIER,   
		MatName NVARCHAR(255), 
		Qty Float, 
		QtyInForm Float, 
		[Path] NVARCHAR(1000), 
		[ParentPath] NVARCHAR(1000) COLLATE ARABIC_CI_AI,
		Unit INT, 
		IsSemiReadyMat INT, 
		NeededFormsCount FLOAT,
		[IsResultOfFormWithMoreThanOneProducedMaterial] BIT) 

	INSERT INTO #MatTree
	EXEC prcGetManufacMaterialTree @MatGuid
	-----------------------------------------------------------------

	CREATE TABLE #FormTreeTbl
	(
		FormGuid UNIQUEIDENTIFIER, 
		FormName NVARCHAR(255) COLLATE ARABIC_CI_AI, 
		[ParentPath] NVARCHAR(1000) COLLATE ARABIC_CI_AI,
		[Guid] UNIQUEIDENTIFIER, 
		ParentGUID UNIQUEIDENTIFIER,
		FormQty Float, 
	)

	INSERT INTO #FormTreeTbl
	SELECT 
		DISTINCT FM.GUID, FM.Name, ParentPath, ParentGuid, ParentParentGUID, @NeededQty
	FROM 
		#MatTree R
		INNER JOIN FM000 FM ON FM.Name = R.FormName
	ORDER BY ParentPath
	---------------------------------------------------------------------

	DECLARE @FormGuid UNIQUEIDENTIFIER
	DECLARE @TGuid UNIQUEIDENTIFIER
	DECLARE @TParentGuid UNIQUEIDENTIFIER
	DECLARE @FormPercent FLOAT = 1
	DECLARE @ParentPath NVARCHAR(MAX)
	DECLARE @ExcludedMatGuid UNIQUEIDENTIFIER
	DECLARE @ExcludedQty FLOAT

	DECLARE @FormTree CURSOR 
	SET @FormTree = CURSOR FOR
	SELECT 
		GUID, ParentGUID, FormGuid, ParentPath
	FROM 
		#FormTreeTbl
	ORDER BY 
		ParentPath

	OPEN @FormTree
	FETCH NEXT FROM @FormTree INTO @TGuid, @TParentGuid, @FormGuid, @ParentPath
	
	WHILE @@FETCH_STATUS = 0
	BEGIN	

		SELECT TOP 1 @ExcludedMatGuid = MatGuid, @ExcludedQty = MatQty, @FormPercent = FormPercent
		FROM
			(SELECT MI.MatGUID, TT.FormQty * ISNULL(R.Qty, 1) MatQty,
				CASE TT.FormQty WHEN 0 THEN 0 ELSE
				(TT.FormQty * ISNULL(R.Qty, 1) - CASE WHEN MT.Qty < 0 THEN 0 ELSE ISNULL(MT.Qty, 0) END) / 
				(TT.FormQty * ISNULL(R.Qty, 1)) END FormPercent
			FROM 
				FM000 AS FM 
				INNER JOIN MN000 AS MN ON MN.FORMGUID = FM.GUID
				INNER JOIN MI000 MI ON MI.ParentGUID = MN.GUID
				INNER JOIN #FormTreeTbl TT ON TT.FormGuid = FM.GUID
				LEFT JOIN #MatTree R ON R.MatGuid = MI.MatGUID
				LEFT JOIN #MatQty MT ON MT.MatGUID = MI.MatGUID
			WHERE
				FM.Guid = @FormGuid 
				AND tt.ParentGUID = @TParentGuid
				AND MN.TYPE = 0 
				AND MI.Type = 0) R
		ORDER BY
			FormPercent DESC

		SET @FormPercent = CASE WHEN @FormPercent < 0 THEN 0 ELSE @FormPercent END

		IF @FormPercent < 1
		BEGIN
			UPDATE #MatQty SET Qty = Qty - ((1 - @FormPercent) * @ExcludedQty)
			WHERE
				MatGUID = @ExcludedMatGuid
		END

		UPDATE #FormTreeTbl SET FormQty = FormQty * @FormPercent 
		WHERE left(ParentPath, len(@ParentPath)) = @ParentPath

		FETCH NEXT FROM @FormTree INTO @TGuid, @TParentGuid, @FormGuid, @ParentPath
	END

	CLOSE @FormTree
	DEALLOCATE @FormTree
	------------------------------------------------------------------
	INSERT INTO #ExcludeExistingEeadyQty
	SELECT  
		R.MatGuid, SUM(R.Qty * FQ.FormQty)
	FROM 
		#FormTreeTbl FQ 
		INNER JOIN #MatTree R ON R.FormName = FQ.FormName AND R.ParentPath = FQ.ParentPath
	GROUP BY
		R.MatGuid
END
################################################################################
#END