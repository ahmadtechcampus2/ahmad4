#########################################################################
CREATE PROCEDURE GetPORawMaterials
	@POGuid UNIQUEIDENTIFIER = 0x00  
AS  
	SET NOCOUNT ON 
	--///////////////////////////////////////////////////////////////////////////////      
	CREATE TABLE #ManuMat (MatGuid UNIQUEIDENTIFIER, Qty FLOAT, Unit INT)
	INSERT INTO #ManuMat  
	SELECT 
		ppi.MatGuid, 
		SUM(bi.Qty),
		bi.Unity 
	FROM 
		ppo000 ppo   
		INNER JOIN ppi000 ppi ON ppo.Guid = ppi.ppoGuid  
		INNER JOIN bi000 bi ON bi.guid = ppi.soiguid  
	WHERE 
		ppo.Guid = @POGuid  
	GROUP BY 
		ppi.MatGuid, 
		bi.Unity

	CREATE Table #RowMat(
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
	    Unit int, 
	    IsSemiReadyMat int, 
		G int default 0,
		NeededFormsCount FLOAT,
		[IsResultOfFormWithMoreThanOneProducedMaterial] BIT
	)  
	CREATE Table #RowMat2(
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
	    Unit int, 
	    IsSemiReadyMat int, 
		G int default 0,
		NeededFormsCount FLOAT,
		[IsResultOfFormWithMoreThanOneProducedMaterial] BIT 
	)
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
		[IsResultOfFormWithMoreThanOneProducedMaterial] BIT
	)
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
		[IsResultOfFormWithMoreThanOneProducedMaterial] BIT
	)  

	DECLARE 
		@c CURSOR,    
		@M_GUID UNIQUEIDENTIFIER,   
		@M_Qty FLOAT,
		@Unit INT 

	SET @c = CURSOR FAST_FORWARD FOR SELECT MatGuid, Qty, Unit FROM #ManuMat  
	OPEN @c FETCH FROM @c INTO @M_GUID, @M_Qty, @Unit 
	WHILE @@FETCH_STATUS = 0    
	BEGIN    
		INSERT INTO #Result(
			SelectedGuid, 
			[Guid], 
			ParentGuid, 
			ParentParentGuid, 
			ClassPtr, 
			FormName, 
			MatGuid, 
			MatName, 
			Qty, 
			QtyInForm, 
			[Path], 
			ParentPath, 
			Unit, 
			IsSemiReadyMat, 
			NeededFormsCount, 
			[IsResultOfFormWithMoreThanOneProducedMaterial])
		EXEC prcGetManufacMaterialTree @M_GUID 
		
		IF (SELECT COUNT(*) FROM #Result) > 0 
		BEGIN 
			INSERT INTO #RowMat 
			SELECT 
				* 
			FROM 
				#Result
			WHERE
				IsSemiReadyMat = 0
						 
			UPDATE #RowMat 
			SET 
				G = 1, 
				NeededFormsCount = (@M_Qty * Qty / QtyInForm) 
			WHERE 
				G = 0 
				AND 
				SelectedGuid = @M_GUID 

			INSERT INTO #Result2
			SELECT 
				*
			FROM 
				#RESULT
			WHERE 
				IsSemiReadyMat = 1

			UPDATE
				#Result2
			SET
				NeededFormsCount = (@M_Qty * Qty / QtyInForm)
			WHERE 
				SelectedGuid = @M_GUID
		END 
		ELSE 
		BEGIN 
			DECLARE @mtName AS NVARCHAR(50) 
			
			INSERT INTO #RowMat(SelectedGuid, [Guid], ParentGuid, ParentParentGUID, ClassPtr, FormName, MatGuid, MatName, Qty, QtyInForm, [Path], [ParentPath], Unit, IsSemiReadyMat, NeededFormsCount, [IsResultOfFormWithMoreThanOneProducedMaterial])
			VALUES (@M_GUID, 0x0, 0x0, 0x0, '', '', @M_GUID, (SELECT mtName FROM vwMt WHERE [mtGUID] = @M_GUID), @M_Qty, 0, '', '', @Unit, 0, 0, 0) 
		END 
		DELETE #Result 
		FETCH FROM @c INTO @M_GUID, @M_Qty, @Unit 
	END      
	CLOSE @c DEALLOCATE @c    
	
	INSERT INTO #RowMat2
	SELECT
		*
	FROM
		#RowMat
	WHERE
		[IsResultOfFormWithMoreThanOneProducedMaterial] = 0
		AND
		[IsSemiReadyMat] = 0

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
					
			) res2 ON res2.Form = rm.ParentParentGUID --AND res2.[Path] = rm.[ParentPath]
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
		SUM(CASE WHEN R2.NeededFormsCount <> 0 THEN R2.QtyInForm * R2.NeededFormsCount ELSE R2.Qty END) AS Qty0,
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
#########################################################################
#END