########################################################
CREATE PROCEDURE prcPurchReqMatForPlanning
	@MatGuid		UNIQUEIDENTIFIER = 0x0,
	@GroupGuid		UNIQUEIDENTIFIER = 0x0,
	@StoreGuid		UNIQUEIDENTIFIER = 0x0,
	@EndDate		DATETIME,
	@MaterialUnit	INT = 3,
	@Amount			INT  = -1, 
	@SrcTypesguid	UNIQUEIDENTIFIER = 0x0,
	@ShwSemiManufacMat BIT = 0,
	@ExcludeExistingQty BIT = 0,
	@ReadyMatStoreGuid UNIQUEIDENTIFIER = 0x0
AS
	SET NOCOUNT ON	
	
	DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();
	CREATE TABLE [#Mat]([mtGuid] [UNIQUEIDENTIFIER], [mtSecurity] [INT])
	INSERT INTO [#Mat] EXEC [prcGetMatsList] @MatGuid, @GroupGuid ,0 ,0x

	CREATE TABLE [#BillsTypesTbl]([TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], [UnpstedSecurity] [INTEGER])
	if (@SrcTypesguid <> 0x)
	BEGIN
		INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList2] @SrcTypesguid
	END

	CREATE TABLE [#Orders]
	(
		MaterialGuid	UNIQUEIDENTIFIER,
		BillType		UNIQUEIDENTIFIER,
		[Required]		FLOAT,
		Achived			FLOAT,
		Remainder		FLOAT,
		Fininshed		INT,
		Cancle			INT
    )
	
	INSERT INTO [#Orders]
		SELECT * FROM [fnGetPurchaseOrderQuantities] (@EndDate, @MatGuid, @StoreGuid, 0)

	SELECT
		MT.mtGUID as mtGUID,
		MT.mtcode as mtcode ,
		CASE @MaterialUnit
			WHEN 0 THEN 1
			WHEN 1 THEN 2
			WHEN 2 THEN 3
			ELSE MT.mtDefUnit
		END AS UnitIndex,
		CASE @MaterialUnit
			WHEN 1 THEN
				CASE ISNULL(MT.mtUnit2Fact, 0)
					WHEN 0 THEN MT.mtDefUnitFact
					ELSE ISNULL(MT.mtUnit2Fact, 1)
				END
			WHEN 2 THEN
				CASE ISNULL(MT.mtUnit3Fact, 0)
					WHEN 0 THEN MT.mtDefUnitFact
					ELSE ISNULL(MT.mtUnit3Fact, 1)
				END
			WHEN 3 THEN
				CASE ISNULL(MT.mtDefUnitFact, 0)
					WHEN 0 THEN 1
					ELSE ISNULL(MT.mtDefUnitFact, 1)
				END
			ELSE 1
		END AS UnitFact,
		CASE CAST(@MaterialUnit AS VARCHAR)
			WHEN 1 THEN 
				CASE WHEN MT.mtUnit2 = '' THEN MT.mtDefUnitName ELSE MT.mtunit2 END
			WHEN 2 THEN 
				CASE WHEN MT.mtUnit3 = '' THEN MT.mtDefUnitName ELSE MT.mtUnit3 END
			WHEN 3 THEN MT.mtDefUnitName
			ELSE MT.mtUnity
		END AS Unit
	INTO #Units
	FROM
		vwMt AS MT
		INNER JOIN mt000 AS Mat ON MT.mtGuid = Mat.GUID

	-------------------------------------------------------------------
	DECLARE @SemiManGroup UNIQUEIDENTIFIER 
	SET @SemiManGroup = (SELECT [VALUE] from OP000 WHERE [NAME] ='man_semiconductGroup') 
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

	CREATE TABLE #PSI (Guid UNIQUEIDENTIFIER, FormGuid UNIQUEIDENTIFIER, Qty FLOAT)

	INSERT INTO #PSI
	SELECT PSI.GUID, PSI.FormGuid, PSI.Qty
	FROM 
		PSI000 AS PSI
		INNER JOIN 
		(
		SELECT
			DISTINCT fm.Guid AS FormGuid , 
			fm.Number AS FormNumber ,
			RANK () OVER (PARTITION BY mi.MatGuid ORDER BY fm.Number DESC) as Irank
		FROM
			MI000 AS mi
			INNER JOIN MN000 AS mn on mi.Parentguid = mn.Guid 
			INNER JOIN FM000 AS fm ON fm.Guid = mn.FormGuid 		
			INNER JOIN MT000 AS mt ON mt.Guid = mi.MatGuid
			INNER JOIN GR000 AS gr ON gr.Guid = mt.GroupGUID
				   
		WHERE
			 MI.[Type] = 0  -- „«œ… „’‰⁄… 
		) AS PSIMat ON PSI.FormGuid = PSIMat.FormGuid 
	WHERE 
		Irank =1
		AND psi.State= 0
		AND PSI.StartDate <= @EndDate
	-------------------------------------------------------------------
	SELECT
		U.mtCode As MaterialCode,
		Mat.mtGUID AS MaterialGuid,
		CASE WHEN @Lang > 0 THEN CASE WHEN Mat.mtLatinName = '' THEN Mat.mtName ELSE Mat.mtLatinName END ELSE Mat.mtName END AS MaterialName,
		U.UnitFact AS UnitFact,
		U.UnitIndex AS UnitIndex,
		U.Unit AS Unit,
		(
			Select ISNULL(SUM(QTY), 0) FROM MS000 WHERE (MS000.MatGUID = Mat.mtGuid)
					AND (MS000.StoreGUID = @StoreGuid OR @StoreGuid = 0x)
		) / U.UnitFact AS QTY,
		(
			Select ISNULL(SUM(Remainder), 0) FROM #Orders, #BillsTypesTbl
			WHERE (#Orders.MaterialGuid = Mat.mtGuid) AND (#Orders.BillType = #BillsTypesTbl.TypeGuid)
					AND (ISNULL(#Orders.Cancle, 0) = 0) AND (ISNULL(#Orders.Fininshed, 0) = 0)
		) / U.UnitFact AS Remaning,
		ISNULL(Mat.mtLow / U.UnitFact, 0) AS LowLimit,
		ISNULL(Mat.mtHigh / U.UnitFact, 0) AS HighLimit,
		ISNULL(Mat.mtOrder / U.UnitFact, 0) OrderLimit,
		(SUM(PSI.Qty * MI.QTY) + 
				CASE @Amount WHEN 0 THEN ISNULL(Mat.mtLow , 0)
					      WHEN 1 THEN ISNULL(Mat.mtOrder, 0) 
						  WHEN 2 THEN ISNULL(Mat.mtHigh, 0)
						  ELSE 0
				END) / U.UnitFact AS REQ
		INTO #ResultForPurchReqMatForPlanning 
		FROM 
			#PSI PSI
			INNER JOIN MN000 AS Mn ON MN.FormGuid = PSI.FormGuid 
			INNER JOIN MI000 AS mi ON mi.Parentguid = mn.Guid 
			INNER JOIN vwmt AS Mat ON Mat.mtGuid = mi.MatGuid 
			INNER JOIN #Units AS U ON U.mtGUID = Mat.mtGuid
		WHERE 
			Mi.Type = 1
			AND MN.Type = 0
		GROUP BY
		    U.mtCode, 
			Mat.mtGuid,
			CASE WHEN @Lang > 0 THEN CASE WHEN Mat.mtLatinName = '' THEN Mat.mtName ELSE Mat.mtLatinName END ELSE Mat.mtName END,
			U.unit, 
			U.UnitFact,
			Mat.mtLow, 
			Mat.mtHigh,
			Mat.mtOrder, 
			U.UnitFact, 
			U.UnitIndex,
			mi.MatGUID
	    ORDER BY
			U.mtCode, 
			CASE WHEN @Lang > 0 THEN CASE WHEN Mat.mtLatinName = '' THEN Mat.mtName ELSE Mat.mtLatinName END ELSE Mat.mtName END
    -----------------------------------------------------------------------------------
	IF @ExcludeExistingQty = 1
	BEGIN
		CREATE TABLE #ExcludeExistingEeadyQty(MatGuid UNIQUEIDENTIFIER, Qty FLOAT)

		CREATE TABLE #FormNeededMatQty (FormGuid UNIQUEIDENTIFIER, MatGuid UNIQUEIDENTIFIER, FormPercent FLOAT, Qty FLOAT)

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
		-----------------------------------------------------------
		INSERT INTO #NeededQtyOfMat
		SELECT MatGuid, SUM(Qty) 
		FROM
			(SELECT MatGuid, FormPercent, Qty, ROW_NUMBER() OVER (PARTITION BY FormGuid ORDER BY FormPercent DESC) MatRank
			FROM #FormNeededMatQty) R
		WHERE MatRank = 1
		GROUP BY MatGuid
	END
	---------------------------------------------------------------------------------
	IF (@ShwSemiManufacMat = 1 )
	BEGIN 
		IF @ExcludeExistingQty = 1
		BEGIN
			EXEC CalcQtyAfterExcludeExistingQtys 
		END

		EXEC GetRawMatQtyForPurchReqMatForPlanning 
		 
		
	 	SELECT
	 		RowTb.MaterialCode As MaterialCode,
			RowTb.MaterialGuid AS MaterialGuid,
			RowTb.MaterialName AS MaterialName,
			U.UnitFact AS UnitFact,
			U.UnitIndex AS UnitIndex,
			U.Unit AS Unit,
			(
				SELECT ISNULL(SUM(QTY), 0)
				FROM MS000
				WHERE (MS000.MatGUID = Mat.mtGuid)
					AND (MS000.StoreGUID = @StoreGuid OR @StoreGuid = 0x)
			) / U.UnitFact AS QTY,
			(
				SELECT ISNULL(SUM(Remainder), 0)
				FROM #Orders, #BillsTypesTbl
				WHERE
					(#Orders.MaterialGuid = Mat.mtGuid)
					AND (#Orders.BillType = #BillsTypesTbl.TypeGuid)
					AND (ISNULL(#Orders.Cancle, 0) = 0)
					AND (ISNULL(#Orders.Fininshed, 0) = 0)
			) / U.UnitFact AS Remaning,
			ISNULL(Mat.mtLow / U.UnitFact, 0) AS LowLimit,
			ISNULL(Mat.mtHigh / U.UnitFact, 0) AS HighLimit,
			ISNULL(Mat.mtOrder / U.UnitFact, 0) OrderLimit,
			MAx(RowTb.REQ) AS REQ	
		INTO #Result
		FROM 
			#ResultForPurchReqMatForPlanning AS RowTb
			INNER JOIN vwmt AS Mat  ON Mat.mtGuid = RowTb.MaterialGuid
		    INNER JOIN #Units AS U ON U.mtGUID = RowTb.MaterialGuid
			INNER JOIN #Mat AS Mt ON RowTb.MaterialGuid = Mt.mtGuid
		GROUP BY
			RowTb.MaterialCode,
			RowTb.MaterialGuid,
			RowTb.MaterialName,
			U.unit,
			U.UnitFact,
			Mat.mtGUID,
			mat.mtName,
			Mat.mtLow,
			U.mtCode,
			Mat.mtHigh,
			Mat.mtOrder,
			U.UnitFact, 
			U.UnitIndex
		--------------------------------------------------------------------------
		IF @ExcludeExistingQty = 1
		BEGIN
			UPDATE R SET REQ = CASE WHEN ERQ.Qty < 0 THEN 0 ELSE ERQ.Qty END
			FROM
				#Result R 
				INNER JOIN 
				(SELECT MatGuid, SUM(Qty) Qty 
				FROM #ExcludeExistingEeadyQty
				GROUP BY MatGuid) ERQ ON R.MaterialGuid = ERQ.MatGuid
		END
		--------------------------------------------------------------------------
		SELECT * FROM #Result
		ORDER BY MaterialCode, MaterialName
   	END 
	ELSE 
	BEGIN
		IF @ExcludeExistingQty = 1
		BEGIN
			UPDATE R SET REQ = REQ * NMQ.FormPercent
			FROM
				#FormNeededMatQty NMQ
				INNER JOIN MN000 AS MN ON MN.FORMGUID = NMQ.FormGuid
				INNER JOIN MI000 MI ON MI.ParentGUID = MN.GUID
				INNER JOIN #ResultForPurchReqMatForPlanning R ON R.MaterialGuid = MI.MatGUID
			WHERE
				MN.Type = 0 AND MI.Type = 1
			-----------------------------------------------------

			UPDATE MQ SET MQ.Qty = MQ.Qty - ((1 - FormPercent) * NQ.Qty)
			FROM 
				#FormNeededMatQty NQ INNER JOIN #MatQty MQ ON NQ.MatGuid = MQ.MatGUID
			WHERE
				NQ.FormPercent < 1
			-----------------------------------------------------

			UPDATE R SET REQ = REQ - CASE WHEN MQ.Qty < 0 THEN 0 ELSE MQ.Qty END
			FROM
				#ResultForPurchReqMatForPlanning R 
				INNER JOIN #MatQty MQ ON MQ.MatGUID = R.MaterialGuid

			UPDATE #ResultForPurchReqMatForPlanning SET REQ = 0 WHERE REQ < 0
		END
		SELECT
			Res.MaterialCode,
			Res.MaterialGuid,
			Res.MaterialName,
			Res.UnitFact,
			Res.UnitIndex,
			Res.Unit,
			Res.QTY,
			Res.Remaning,
			Res.LowLimit,
			Res.HighLimit,
			Res.OrderLimit,
			Res.REQ
       FROM
			#ResultForPurchReqMatForPlanning AS Res 
			INNER JOIN #Mat AS Mt ON Res.MaterialGuid = Mt.mtGuid
	   ORDER BY
			RES.MaterialCode
	END
########################################################
CREATE PROCEDURE GetRawMatQtyForPurchReqMatForPlanning
AS  
 SET NOCOUNT ON 
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
	CREATE Table #Result(
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

	SET @c = CURSOR FAST_FORWARD FOR SELECT MaterialGuid, REQ, UnitIndex FROM #ResultForPurchReqMatForPlanning
	OPEN @c FETCH FROM @c INTO @M_GUID, @M_Qty, @Unit 
	WHILE @@FETCH_STATUS = 0    
	BEGIN    
		INSERT INTO #Result(SelectedGuid, Guid, ParentGuid, ParentParentGUID, ClassPtr, FormName, MatGuid, MatName, Qty, QtyInForm, [Path], ParentPath, Unit, IsSemiReadyMat, NeededFormsCount, [IsResultOfFormWithMoreThanOneProducedMaterial])  
		EXEC prcGetManufacMaterialTree @M_GUID

		UPDATE #Result 
		SET Qty = @M_Qty * Qty 
		IF (SELECT COUNT(*) FROM #Result) > 0 
		BEGIN 
			INSERT INTO #RowMat 
				SELECT * 
				FROM #Result
				WHERE IsSemiReadyMat = 0
			
			UPDATE #RowMat 
			SET	G = 1
				,NeededFormsCount = (Qty / QtyInForm) 
			WHERE 
				G = 0 
				AND 
				SelectedGuid = @M_GUID 

			INSERT INTO #Result2
			SELECT * 
			FROM #RESULT
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
		
		DELETE #Result 
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

	 DELETE FROM #ResultForPurchReqMatForPlanning 

	INSERT INTO #ResultForPurchReqMatForPlanning
		SELECT 	RowTb.MatCode As MaterialCode,
				RowTb.MatGUID AS MaterialGuid,
				RowTb.MatName AS MaterialName,
				RowTb.CurUnit AS UnitFact,
				0,
				'',
				0,
				0,
				0,
				0,
				0
				,RowTb.Qty AS REQ
				
	    FROM 
	        #RowTable RowTb 
########################################################
CREATE PROCEDURE prcPurchReqMatForOrders 
	@MatGuid		UNIQUEIDENTIFIER = 0x0,
	@GroupGuid		UNIQUEIDENTIFIER = 0x0,
	@StoreGuid		UNIQUEIDENTIFIER = 0x0,
	@EndDate		DATETIME,
	@MaterialUnit	INT = 3,
	@Amount			INT  = -1, 
	@SrcTypesguid	UNIQUEIDENTIFIER = 0x0,
	@ShwSemiManufacMat BIT = 0,
	@ExcludeExistingQty BIT = 0,
	@ReadyMatStoreGuid UNIQUEIDENTIFIER = 0x0
AS
	SET NOCOUNT ON	
	DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();
	CREATE TABLE [#Mat]([mtGuid] [UNIQUEIDENTIFIER], [mtSecurity] [INT])
	INSERT INTO [#Mat] EXEC [prcGetMatsList] @MatGuid, @GroupGuid ,0 ,0x
	--
	CREATE TABLE #FormTbl([GUID] UNIQUEIDENTIFIER, MatGUID UNIQUEIDENTIFIER, MatType INT, GrpGuid UNIQUEIDENTIFIER)	
	INSERT INTO #FormTbl (GUID, MatGUID, MatType, GrpGuid)
		SELECT FrmGUID, MatGUID, 0, 0x0 FROM
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
			) AS TmpFormTbl
		WHERE TmpFormTbl.FrmRANK = 1
		ORDER BY Number			
	--
	CREATE TABLE [#BillsTypesTbl]([TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], [UnpstedSecurity] [INTEGER])
	IF (@SrcTypesguid <> 0x)
		INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList2] @SrcTypesguid
	
	CREATE TABLE [#BuyOrders] -- ÿ·»«  «·‘—«¡
	(
		MaterialGuid	UNIQUEIDENTIFIER,
		BillType		UNIQUEIDENTIFIER,
		[Required]		FLOAT,
		Achived			FLOAT,
		Remainder		FLOAT,
		Fininshed		int,
		Cancle			int
    )
	
    INSERT INTO [#BuyOrders] -- ÿ·»Ì«  «·‘—«¡
		SELECT * FROM [fnGetPurchaseOrderQuantities] (@EndDate, 0x0, 0x0, 0)	
	
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
		SELECT * FROM [fnGetPurchaseOrderQuantities] (@EndDate, 0x0, 0x0, 1)

	-------------------------------------------------------------------
	DECLARE @SemiManGroup UNIQUEIDENTIFIER 
	SET @SemiManGroup = (SELECT [VALUE] from OP000 WHERE [NAME] ='man_semiconductGroup') 
	--------------------------------------------------------------
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
	CREATE TABLE #RemainingOrderMats (MatGuid UNIQUEIDENTIFIER, RemainingQty FLOAT, StoreQty FLOAT)

	INSERT INTO #RemainingOrderMats
	SELECT
		DISTINCT S.MaterialGuid,
			ISNULL(SUM(S.Remainder), 0) AS Remining, -- «·„ »ﬁÌ „‰ ÿ·»Ì«  «·»Ì⁄
			(SELECT ISNULL(SUM(QTY), 0) FROM MS000 WHERE MS000.MatGUID = S.MaterialGuid) +
				(SELECT ISNULL(SUM(Remainder), 0)
				 FROM #BuyOrders AS BOrders, #BillsTypesTbl AS BillTbl
				 WHERE (BOrders.MaterialGuid = S.MaterialGuid) AND (BOrders.BillType = BillTbl.TypeGuid)
					AND ISNULL(BOrders.Cancle, 0) = 0 AND ISNULL(BOrders.Fininshed, 0) = 0)	AS StoreQTY -- «·„Œ“Ê‰ + «·„ »ﬁÌ „‰ ÿ·»Ì«  «·‘—«¡
			FROM
				--#MAT AS M
				#SaleOrders AS S 
				INNER JOIN #BillsTypesTbl AS B ON B.TypeGuid = S.BillType				
			WHERE (ISNULL(S.Fininshed, 0) = 0) And (ISNULL(S.Cancle, 0) = 0 )
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
	FETCH NEXT FROM @OrderMaterials INTO @mtGUID, @Rem, @StoreQty
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
				WHERE MI.Type = 0
					AND MN.FormGUID = @FmGuid
					AND F.MatType = 0 AND MN.Type =0 
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
					WHERE MI.Type = 0
						AND MN.FormGUID = @FmGuid
						AND F.MatType = 0 AND MN.Type =0 
					)
				INSERT INTO #Res1
					SELECT MI.MatGUID, (@Rem / @cnt) * MI.Qty
					FROM MI000 AS MI
						INNER JOIN MN000 AS MN ON MN.GUID = MI.ParentGUID
						INNER JOIN #FormTbl AS F ON F.GUID = MN.FormGUID
					WHERE MI.Type = 1							
						AND MN.FormGUID = @FmGuid
						AND F.MatType = 0	AND MN.Type =0 

					-----------------------------------------------------
					IF @ExcludeExistingQty = 1
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
					WHERE
						MI.Type = 0 AND MN.FormGUID = @FmGuid AND F.MatType = 0
						AND MN.Type =0 
								
				DECLARE @FormCntForOrder FLOAT, @MaterialGuid UNIQUEIDENTIFIER
				SET @FormCntForOrder = (SELECT MAX(REM / ISNULL(QTY, 1)) FROM #Qtys) -- Õ”«» ⁄œœ «·‰„«–Ã «·„ÿ·Ê»…
				SET @MaterialGuid = (Select TOP 1 MaterialGuid From #Qtys WHERE (REM / ISNULL(QTY, 1)) = @FormCntForOrder)					
						
				INSERT INTO #Res1
					SELECT DISTINCT MI.MatGUID, @FormCntForOrder * MI.Qty
					FROM MI000 AS MI
						INNER JOIN MN000 AS MN ON MN.GUID = MI.ParentGUID
						INNER JOIN #FormTbl AS F ON F.GUID = MN.FormGUID
					WHERE
						MI.Type = 1
						AND MN.FormGUID = @FmGuid				
						AND F.MatType = 0 AND MN.Type =0 
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
				SELECT 1 FROM MI000 AS MI
					INNER JOIN MN000 AS MN ON MN.GUID = MI.ParentGUID
					INNER JOIN #FormTbl AS F ON F.GUID = MN.FormGUID
				WHERE MI.Type = 1 AND MI.MatGUID = @MtGUID AND MN.Type =0 ))
		BEGIN
			INSERT INTO #Res1
			VALUES(@MtGUID, @Rem)
		END
	FETCH NEXT FROM @OrderMaterials INTO @mtGUID, @Rem, @StoreQty
	END
	CLOSE @OrderMaterials
	DEALLOCATE @OrderMaterials

	CREATE TABLE #Res2
	(
		MatGUID UNIQUEIDENTIFIER,
		QTY FLOAT
	)
	
	INSERT INTO #Res2
		SELECT MatGUID, SUM(Rem) FROM #Res1 GROUP BY MatGUID ORDER BY MatGUID

	DELETE FROM #BuyOrders
	
	INSERT INTO [#BuyOrders] -- ÿ·»Ì«  «·‘—«¡
		SELECT * FROM [fnGetPurchaseOrderQuantities] (@EndDate, 0x0, @StoreGuid, 0)	

	
		SELECT
			MT.mtGUID,
			MT.mtcode,
			CASE @MaterialUnit
				WHEN 0 THEN 1
				WHEN 1 THEN 2
				WHEN 2 THEN 3
				ELSE MT.mtDefUnit
			END AS UnitIndex,
			CASE @MaterialUnit
				WHEN 1 THEN
					CASE ISNULL(MT.mtUnit2Fact, 0)
						WHEN 0 THEN MT.mtDefUnitFact
						ELSE ISNULL(MT.mtUnit2Fact, 1)
					END
				WHEN 2 THEN
					CASE ISNULL(MT.mtUnit3Fact, 0)
						WHEN 0 THEN MT.mtDefUnitFact
						ELSE ISNULL(MT.mtUnit3Fact, 1)
					END
				WHEN 3 THEN
					CASE ISNULL(MT.mtDefUnitFact, 0)
						WHEN 0 THEN 1
						ELSE ISNULL(MT.mtDefUnitFact, 1)
					END
				ELSE 1
			END AS UnitFact,
			CASE CAST(@MaterialUnit AS VARCHAR)
				WHEN 1 THEN 
					CASE WHEN MT.mtUnit2 = '' THEN MT.mtDefUnitName ELSE MT.mtunit2 END
				WHEN 2 THEN 
					CASE WHEN MT.mtUnit3 = '' THEN MT.mtDefUnitName ELSE MT.mtUnit3 END
				WHEN 3 THEN MT.mtDefUnitName
				ELSE MT.mtUnity
			END AS Unit
			INTO #Units
		FROM
			vwMt AS MT
			INNER JOIN mt000 AS Mat ON MT.mtGuid = Mat.Guid
	
	
	SELECT
		U.mtCode As MaterialCode,
		Res.MatGUID AS MaterialGuid,
		CASE WHEN @Lang > 0 THEN CASE WHEN Mat.mtLatinName = '' THEN Mat.mtName ELSE Mat.mtLatinName END ELSE Mat.mtName END AS MaterialName,
		U.Unit AS Unit,
		U.UnitFact AS UnitFact,
		U.UnitIndex AS UnitIndex,
		(
			SELECT ISNULL(SUM(QTY), 0)
			FROM MS000 
			WHERE (MS000.MatGUID = Res.MatGUID) AND (MS000.StoreGUID = @StoreGuid OR @StoreGuid = 0x)
		) / U.UnitFact AS QTY,
		(
			SELECT ISNULL(SUM(Remainder), 0)
			FROM #BuyOrders AS BOrders, #BillsTypesTbl AS BillTbl
			WHERE (BOrders.MaterialGuid = Res.MatGUID) AND (BOrders.BillType = BillTbl.TypeGuid)
					AND ISNULL(BOrders.Cancle, 0) = 0 AND ISNULL(BOrders.Fininshed, 0) = 0
		) / U.UnitFact AS Remaning,
		ISNULL(Mat.mtLow / U.UnitFact, 0) AS LowLimit,
		ISNULL(Mat.mtHigh / U.UnitFact, 0) AS HighLimit,
		ISNULL(Mat.mtOrder / U.UnitFact, 0) OrderLimit,
		(CASE @Amount WHEN 0 THEN  IsNull(Res.QTY,0)+ ISNULL(Mat.mtLow , 0)
					  WHEN 1 THEN  IsNull(Res.QTY,0) + ISNULL(Mat.mtOrder, 0) 
					  WHEN 2 THEN   IsNull(Res.QTY,0) + ISNULL(Mat.mtHigh, 0)
					  ELSE  IsNull(Res.QTY,0)
          END ) / U.UnitFact AS REQ
    INTO #ResultForPurchReqMatForOrders		
	FROM
		#Res2 AS Res
		INNER JOIN vwmt AS Mat ON Mat.mtGUID = Res.MatGUID
		INNER JOIN #Units AS U ON U.mtGUID = Res.MatGUID
	GROUP BY
		U.mtCode,
		Res.MatGUID,
		CASE WHEN @Lang > 0 THEN CASE WHEN Mat.mtLatinName = '' THEN Mat.mtName ELSE Mat.mtLatinName END ELSE Mat.mtName END,
		U.unit,
		U.UnitFact,
		Mat.mtLow,
		Mat.mtHigh,
		Mat.mtOrder,
		Res.QTY,
		U.UnitFact,
		U.UnitIndex
	ORDER BY
		CASE WHEN @Lang > 0 THEN CASE WHEN Mat.mtLatinName = '' THEN Mat.mtName ELSE Mat.mtLatinName END ELSE Mat.mtName END ,
		U.mtCode
		
		---------------------------------------------------------------------------------------------
	IF @ExcludeExistingQty = 1
	BEGIN
		CREATE TABLE #ExcludeExistingEeadyQty(MatGuid UNIQUEIDENTIFIER, Qty FLOAT)

		CREATE TABLE #FormNeededMatQty (FormGuid UNIQUEIDENTIFIER, MatGuid UNIQUEIDENTIFIER, FormPercent FLOAT, Qty FLOAT)

		INSERT INTO #NeededQtyOfMat
		SELECT MatGuid, SUM(Qty) 
		FROM
			(SELECT MatGuid, FormPercent, Qty, RANK() OVER (PARTITION BY FormGuid ORDER BY FormPercent DESC) MatRank
			FROM #FormNeededMatQty) R
		WHERE MatRank = 1
		GROUP BY MatGuid
	END
		----------------------------------------------------------------------------------------
	if (@ShwSemiManufacMat = 1 ) 
	BEGIN
		IF @ExcludeExistingQty = 1
		BEGIN
			EXEC CalcQtyAfterExcludeExistingQtys 
		END

		EXEC GetRawMatQtyForPurchReqMatForOrders
		  
       SELECT 	RowTb.MaterialCode As MaterialCode,
				RowTb.MaterialGuid AS MaterialGuid,
				RowTb.MaterialName AS MaterialName,
				U.UnitFact AS UnitFact,
				U.UnitIndex AS UnitIndex,
				U.Unit AS Unit,
				(
					SELECT ISNULL(SUM(QTY), 0)
					FROM MS000 
					WHERE (MS000.MatGUID = RowTb.MaterialGuid) AND (MS000.StoreGUID = @StoreGuid OR @StoreGuid = 0x)
				) / U.UnitFact AS QTY,
				(
					SELECT ISNULL(SUM(Remainder), 0)
					FROM #BuyOrders AS BOrders, #BillsTypesTbl AS BillTbl
					WHERE (BOrders.MaterialGuid = RowTb.MaterialGuid) AND (BOrders.BillType = BillTbl.TypeGuid)
							AND ISNULL(BOrders.Cancle, 0) = 0 AND ISNULL(BOrders.Fininshed, 0) = 0
				) / U.UnitFact AS Remaning,
				ISNULL(Mat.mtLow / U.UnitFact, 0) AS LowLimit,
				ISNULL(Mat.mtHigh / U.UnitFact, 0) AS HighLimit,
				ISNULL(Mat.mtOrder / U.UnitFact, 0) OrderLimit,
				MAX(RowTb.REQ) AS REQ
				INTO #Result
	FROM 
	     #ResultForPurchReqMatForOrders RowTb INNER JOIN  vwmt AS Mat  ON Mat.mtGuid = RowTb.MaterialGuid
		                 INNER JOIN #Units AS U ON U.mtGUID = RowTb.MaterialGuid
						 INNER JOIN #Mat AS Mt ON RowTb.MaterialGuid = Mt.mtGuid
	GROUP BY
		RowTb.MaterialCode,
		RowTb.MaterialGuid,
		 RowTb.MaterialName,
		 U.unit,U.UnitFact,
		 Mat.mtGUID, mat.mtName,
		 Mat.mtLow, U.mtCode,
		 Mat.mtHigh,
		 Mat.mtOrder,
		 U.UnitFact, 
		 U.UnitIndex
		--------------------------------------------------------------------------
		IF @ExcludeExistingQty = 1
		BEGIN
			UPDATE R SET REQ = CASE WHEN ERQ.Qty < 0 THEN 0 ELSE ERQ.Qty END
			FROM
				#Result R 
				INNER JOIN 
				(SELECT MatGuid, SUM(Qty) Qty 
				FROM #ExcludeExistingEeadyQty 
				GROUP BY MatGuid) ERQ ON R.MaterialGuid = ERQ.MatGuid
		END
		--------------------------------------------------------------------------
		SELECT * FROM #Result
		ORDER BY MaterialCode, MaterialName
   
	END 
	ELSE 
	BEGIN
		IF @ExcludeExistingQty = 1
		BEGIN
			UPDATE R SET REQ = REQ * NMQ.FormPercent
			FROM
				#FormNeededMatQty NMQ
				INNER JOIN MN000 AS MN ON MN.FORMGUID = NMQ.FormGuid
				INNER JOIN MI000 MI ON MI.ParentGUID = MN.GUID
				INNER JOIN #ResultForPurchReqMatForOrders R ON R.MaterialGuid = MI.MatGUID
			WHERE
				MN.Type = 0 AND MI.Type = 1
			-----------------------------------------------------

			UPDATE MQ SET MQ.Qty = MQ.Qty - ((1 - FormPercent) * NQ.Qty)
			FROM 
				#FormNeededMatQty NQ INNER JOIN #MatQty MQ ON NQ.MatGuid = MQ.MatGUID
			WHERE
				NQ.FormPercent < 1
			-----------------------------------------------------

			UPDATE R SET REQ = REQ - CASE WHEN MQ.Qty < 0 THEN 0 ELSE MQ.Qty END
			FROM
				#ResultForPurchReqMatForOrders R 
				INNER JOIN #MatQty MQ ON MQ.MatGUID = R.MaterialGuid

			UPDATE #ResultForPurchReqMatForOrders SET REQ = 0 WHERE REQ < 0
		END

	   SELECT 	Res.MaterialCode,
				Res. MaterialGuid,
				Res.MaterialName,
				Res.UnitFact,
				Res.UnitIndex,
				Res.Unit,
				Res.QTY,
				Res.Remaning,
				Res.LowLimit,
				Res.HighLimit,
				Res.OrderLimit,
				Res.REQ
	  FROM #ResultForPurchReqMatForOrders Res 
	   INNER JOIN #Mat AS Mt ON Res.MaterialGuid = Mt.mtGuid
	END
########################################################
CREATE PROCEDURE GetRawMatQtyForPurchReqMatForOrders
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
	CREATE Table #Result(
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

	SET @c = CURSOR FAST_FORWARD FOR SELECT MaterialGuid, REQ, UnitIndex FROM #ResultForPurchReqMatForOrders
	OPEN @c FETCH FROM @c INTO @M_GUID, @M_Qty, @Unit 
	WHILE @@FETCH_STATUS = 0    
	BEGIN    
		INSERT INTO #Result(SelectedGuid, Guid, ParentGuid, ParentParentGUID, ClassPtr, FormName, MatGuid, MatName, Qty, QtyInForm, [Path], ParentPath, Unit, IsSemiReadyMat, NeededFormsCount, [IsResultOfFormWithMoreThanOneProducedMaterial])  
		EXEC prcGetManufacMaterialTree @M_GUID

		UPDATE #Result
		SET Qty = Qty * @M_Qty

		IF (SELECT COUNT(*) FROM #Result) > 0 
		BEGIN 
			INSERT INTO #RowMat 
				SELECT * 
				FROM #Result
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
			FROM #RESULT
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
			
			--SELECT @mtName = name 
			--FROM mt000 
			--WHERE Guid = @M_GUID 
			
			INSERT INTO #RowMat(SelectedGuid, Guid, ParentGuid, ParentParentGUID, ClassPtr, FormName, MatGuid, MatName, Qty, QtyInForm, [Path], [ParentPath], Unit, IsSemiReadyMat, NeededFormsCount, [IsResultOfFormWithMoreThanOneProducedMaterial])
			VALUES (@M_GUID, 0x0, 0x0, 0x0, '', '', @M_GUID, (SELECT mtName FROM vwMt WHERE [mtGUID] = @M_GUID), @M_Qty, 0, '', '', @Unit, 0, 0, 0) 
		END 
		
		DELETE #Result 
		FETCH FROM @c INTO @M_GUID, @M_Qty, @Unit 
	END      
	CLOSE @c DEALLOCATE @c    
--<<<<<<<<<<< Debug Section
--select '#RowMat', * from #RowMat

--SELECT MatGUID, MatName, [PATH], MAX(NeededFormsCount) AS MaxNeededFormsCount FROM #RowMat GROUP BY MatGUID, MatName, [PATH]

--select 
--	MatName ,
--	ParentGuid AS Form, --form
--	[path],
--	QtyInForm,
--	--Qty,
--	Max(NeededFormsCount)
--from #RowMat
--Group by
--	MatName,
--	ParentGuid, --form
--	[path],
--	QtyInForm--,
	--Qty,
	--NeededFormsCount


--SELECT '#Result2', * FROM #Result2

--select
--	r2.MatName,
--	SUM(r2.FinalQty)
--From
--(	
--	select 
--		r.MatName,
--		r.Form,
--		Max(r.FinalQty) As FinalQty
--	from
--	(
		--select
			
		--	Form,
		--	ParentParentGUID,
			
		--	Max(MaxNeededFormsCount) MaxNeededFormsCount
		--from
		--(
		--	select
		--		selectedGuid,
		--		MatGuid,
		--		MatName,
		--		ParentGUID AS Form,
		--		ParentParentGUID,
		--		[Path],
		--		ParentPath,
		--		MAX(NeededFormsCount) as MaxNeededFormsCount,
		--		QtyInForm --* MAX(NeededFormsCount) As FinalQty
		--	from 
		--		#Result2
		--	group by
		--		selectedGuid,
		--		MatGuid,
		--		MatName,
		--		ParentGUID,
		--		ParentParentGUID,
		--		[Path],
		--		ParentPath,
		--		QtyInForm
		--) r0
		--Group by
			
		--	Form,
		--	ParentParentGUID
			

--	) r
--	Group by
--		r.MatName,
--		r.Form
--) r2
--GROUP By
--	r2.MatName


	--SELECT 
	--	'RowMat', rm.*, res2.MaxNeededFormsCount 
	--FROM 
	--	#RowMat rm 
	--inner join 
	--(
	--	select
	--		MatGuid,
	--		MatName,
	--		ParentGUID AS Form,
	--		[Path],
	--		[ParentPath],
	--		MAX(NeededFormsCount) as MaxNeededFormsCount,
	--		QtyInForm * Max(NeededFormsCount) As FinalQty
	--	from 
	--		#Result2
	--	group by
	--		MatGuid,
	--		MatName,
	--		ParentGUID,
	--		[Path],
	--		[ParentPath],
	--		QtyInForm
	--) res2 ON res2.Form = rm.ParentParentGUID AND res2.[Path] = rm.[ParentPath]
--where rm.MatGuid ='39AF7F0E-C13E-4CCF-8246-4E76A45DB616'
--ORDER BY [PATH]
-->>>>>>>>>>>>>> End of Debug Section

	


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
		--X.QtyInForm * X.MaxNeededFormsCount,
		--X.QtyInForm * X.MaxNeededFormsCount,
		--X.QtyInForm * X.MaxNeededFormsCount,
		--X.QtyInForm * X.MaxNeededFormsCount,
		--X.QtyInForm * X.MaxNeededFormsCount,
		--X.QtyInForm * X.MaxNeededFormsCount,
		--X.QtyInForm * X.MaxNeededFormsCount,
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

	 DELETE FROM #ResultForPurchReqMatForOrders 

	INSERT INTO #ResultForPurchReqMatForOrders
		SELECT 	RowTb.MatCode As MaterialCode,
				RowTb.MatGUID AS MaterialGuid,
				RowTb.MatName AS MaterialName,
				RowTb.CurUnit AS UnitFact,
				0,
				'',
				0,
				0,
				0,
				0,
				0
				,RowTb.Qty AS REQ
				
	    FROM 
	        #RowTable RowTb 
########################################################
#END