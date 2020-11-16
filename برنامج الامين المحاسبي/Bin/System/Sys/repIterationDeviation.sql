###########################################################
CREATE PROCEDURE repIterationDeviation
(
	@RealCostAccount	UNIQUEIDENTIFIER = 0x0,
	@CostGuid			UNIQUEIDENTIFIER = 0x0,
	@FromDate			DATETIME	= '1-1-1980',
	@ToDate				DATETIME	= '1-1-9999',
	@WithOutCostCenter	INT = 0
)
AS
SET NOCOUNT ON 

DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();

	CREATE TABLE #Result
	(
		AccountGuid			UNIQUEIDENTIFIER,
		CostGuid			UNIQUEIDENTIFIER,
		CostName			NVARCHAR(250) COLLATE ARABIC_CI_AI,
		MatGuid				UNIQUEIDENTIFIER,
		UnitName			NVARCHAR(250) COLLATE ARABIC_CI_AI,
		MatCode				NVARCHAR(250) COLLATE ARABIC_CI_AI,
		MatName				NVARCHAR(250) COLLATE ARABIC_CI_AI,
		OutPut				FLOAT,
		CurrentCost			FLOAT,
		StandPrice			FLOAT,
		DivRation			FLOAT,
		RealCost			FLOAT,
		TotalRealCost		FLOAT,
		RealPrice			FLOAT,
		IterationDeviation	FLOAT,
		Deviation			FLOAT,
		UnitDeviation		FLOAT,
		UsedValue			FLOAT,
		RealPriceValue		FLOAT,
		SemiMatGuid			UNIQUEIDENTIFIER,
		SemiMatName			NVARCHAR(250) COLLATE ARABIC_CI_AI,
		PhaseNumber			INT,
		TYPE				INT
	)

	-----------------------------------------------------------------------------------

	IF (@WithOutCostCenter = 0)
	BEGIN
		INSERT INTO #Result (MatGuid, UnitName, MatCode, MatName, CostGuid, CostName, Output, CurrentCost, TYPE)
		SELECT BI.MatGUID, MT.Unity, MT.Code, CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END , BI.CostGUID, CASE WHEN @Lang > 0 THEN CASE WHEN co.LatinName = '' THEN co.Name ELSE co.LatinName END ELSE CO.Name END, SUM(BI.Qty), SUM(CASE BI.Unity WHEN 1 THEN BI.Qty
																											WHEN 2 THEN BI.Qty / MT.Unit2Fact
																											WHEN 3 THEN BI.Qty / MT.Unit3Fact END  * BI.Price), 0
		FROM BI000 BI INNER JOIN bu000 BU ON BU.GUID = BI.ParentGUID
			INNER JOIN bt000 BT ON BT.GUID = BU.TypeGUID 
			INNER JOIN mt000 MT ON MT.GUID = BI.MatGUID
			INNER JOIN co000 CO ON CO.GUID = BI.CostGUID
		WHERE BT.Type = 2 AND bt.SortNum = 5
			AND BU.Date BETWEEN @FromDate AND @ToDate
		GROUP BY BI.MatGuid, MT.Code, MT.Unity, CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END , BI.CostGuid, CASE WHEN @Lang > 0 THEN CASE WHEN co.LatinName = '' THEN co.Name ELSE co.LatinName END ELSE CO.Name END
		----------------------------------------------------------------------------------------
		UPDATE #Result SET DivRation =  CASE R.TotalPrice WHEN 0 THEN 100 ELSE CurrentCost / R.TotalPrice * 100 END
		FROM 
		(
			SELECT CostGuid, SUM(CurrentCost) TotalPrice
			FROM #Result
			GROUP BY CostGuid
		) AS R
		WHERE #Result.CostGuid = R.CostGuid
		
		----------------------------------------------------------------------------------------
		UPDATE #Result SET RealCost =  R.Balance * DivRation / 100
		FROM 
		(   
			SELECT EN.CostGUID, SUM(EN.Debit - EN.Credit)  Balance
			FROM en000 EN INNER JOIN ac000 AC ON AC.GUID = EN.AccountGUID
			INNER JOIN fnGetAccountsList(@RealCostAccount,0) F ON AC.GUID = F.GUID
			WHERE EN.Date BETWEEN @FromDate AND @ToDate
			GROUP BY EN.CostGUID
		) AS R
		WHERE #Result.CostGuid = R.CostGUID
		---------------------------------------------------------------------------------------------
	END
	ELSE
	BEGIN
		INSERT INTO #Result (MatGuid, UnitName, MatCode, MatName, Output, CurrentCost, TYPE)
		SELECT BI.MatGUID, Mt.Unity, MT.Code, CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END, SUM(BI.Qty), SUM(CASE BI.Unity WHEN 1 THEN BI.Qty
																					  WHEN 2 THEN BI.Qty / MT.Unit2Fact
																					  WHEN 3 THEN BI.Qty / MT.Unit3Fact END  * BI.Price), 0
		FROM BI000 BI INNER JOIN bu000 BU ON BU.GUID = BI.ParentGUID
			INNER JOIN bt000 BT ON BT.GUID = BU.TypeGUID 
			INNER JOIN mt000 MT ON MT.GUID = BI.MatGUID
		WHERE BT.Type = 2 AND bt.SortNum = 5
			AND BU.Date BETWEEN @FromDate AND @ToDate
		GROUP BY BI.MatGuid, MT.Code, MT.Unity, CASE WHEN @Lang > 0 THEN CASE WHEN mt.LatinName = ''  THEN mt.Name ELSE mt.LatinName END ELSE MT.Name END		
		----------------------------------------------------------------------------------------
		UPDATE #Result SET DivRation =  CASE R.TotalPrice WHEN 0 THEN 100 ELSE CurrentCost / R.TotalPrice * 100 END
		FROM 
		(
			SELECT SUM(CurrentCost) TotalPrice
			FROM #Result
		) AS R

		-----------------------------------------------------------------------------------------
		UPDATE #Result SET RealCost =  R.Balance * DivRation / 100
		FROM 
		(   
			SELECT SUM(EN.Debit - EN.Credit)  Balance
			FROM en000 EN INNER JOIN ac000 AC ON AC.GUID = EN.AccountGUID
			INNER JOIN fnGetAccountsList(@RealCostAccount,0) F ON AC.GUID = F.GUID
			WHERE EN.Date BETWEEN @FromDate AND @ToDate
		) AS R
	END
		----------------------------------------------------------------------------------------
	UPDATE #Result SET  StandPrice = CASE Output WHEN 0 THEN 0 ELSE CurrentCost / Output END
	UPDATE #Result SET	IterationDeviation = 0
	UPDATE #Result SET	TotalRealCost = ISNULL(RealCost, 0) + IterationDeviation
	UPDATE #Result SET	RealPrice = CASE Output WHEN 0 THEN 0 ELSE TotalRealCost / Output END
	UPDATE #Result SET	Deviation = TotalRealCost - CurrentCost
	UPDATE #Result SET	UnitDeviation = CASE Output WHEN 0 THEN 0 ELSE Deviation / Output END
	-----------------------------------------------------------------------------------------------
	CREATE TABLE #SemiOutput
	(
		ReadyMatGuid		UNIQUEIDENTIFIER,
		ReadyMatName		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		SemiMatGuid			UNIQUEIDENTIFIER,
		SemiMatName			NVARCHAR(250) COLLATE ARABIC_CI_AI,
		CostGuid			UNIQUEIDENTIFIER,
		CostName			NVARCHAR(250) COLLATE ARABIC_CI_AI,
		Quantity			FLOAT,
		UnitDeviation		FLOAT,
		UsedValue			FLOAT,
		RealPriceValue		FLOAT,
		Deviation			FLOAT
	)

	DECLARE @PhaseNumber INT
	DECLARE @MaxPhaseNumber INT

	SET @MaxPhaseNumber = (SELECT MAX(PhaseNumber) FROM MN000)
	SET @PhaseNumber = 1
 	-----------------------------------------------------------------------------------------------
	WHILE(@PhaseNumber <=  @MaxPhaseNumber)
	BEGIN
		IF (@WithOutCostCenter = 0)
		BEGIN
			DELETE #SemiOutput
			INSERT INTO #SemiOutput (ReadyMatName, ReadyMatGuid, CostName, CostGuid, SemiMatName, SemiMatGuid, Quantity, UsedValue)
			SELECT CASE WHEN @Lang > 0 THEN CASE WHEN MIMT.LatinName = '' THEN MIMT.Name ELSE MIMT.LatinName END ELSE MIMT.Name END , mimt.GUID, CASE WHEN @Lang > 0 THEN CASE WHEN co.LatinName = '' THEN co.Name ELSE co.LatinName END ELSE co.Name END, CO.GUID, CASE WHEN @Lang > 0 THEN CASE WHEN BIMT.LatinName = '' THEN BIMT.Name ELSE BIMT.LatinName END ELSE BIMT.Name END, BIMT.GUID,
				SUM(CASE ISNULL(RAWMI.ReadyMatGUID, 0x0)	
					WHEN 0x0 THEN RAWMI.Qty * MI.Percentage / 100 
					WHEN MI.MatGUID THEN RAWMI.Qty
					ELSE 0 END),
				SUM((CASE BI.Unity 
					WHEN 1 THEN BI.Qty
					WHEN 2 THEN BI.Qty / BIMT.Unit2Fact
					WHEN 3 THEN BI.Qty / BIMT.Unit3Fact END * BI.Price) * 
					CASE ISNULL(RAWMI.ReadyMatGUID, 0x0)	
					WHEN 0x0 THEN MI.Percentage / 100
					WHEN MI.MatGUID THEN 1
					ELSE 0 END)
			FROM MN000 MN INNER JOIN MB000 MB ON MB.ManGUID = MN.GUID
				INNER JOIN MI000 MI ON MI.ParentGUID = MN.GUID
				INNER JOIN bu000 BU ON BU.GUID = MB.BillGUID
				INNER JOIN bi000 BI ON BI.ParentGUID = BU.GUID
				INNER JOIN MI000 RAWMI ON RAWMI.ParentGUID = MN.GUID AND RAWMI.MatGUID = BI.MatGUID AND RAWMI.Number = BI.Number
				INNER JOIN co000 CO ON CO.GUID = BI.CostGUID
				INNER JOIN mt000 MIMT ON MIMT.GUID = MI.MatGUID
				INNER JOIN mt000 BIMT ON BIMT.GUID = BI.MatGUID
			WHERE MI.Type = 0 AND MN.Type = 1 AND MB.Type = 2 AND MN.PhaseNumber =  @PhaseNumber
				AND BU.Date BETWEEN @FromDate AND @ToDate
			GROUP BY CASE WHEN @Lang > 0 THEN CASE WHEN MIMT.LatinName = '' THEN MIMT.Name ELSE MIMT.LatinName END ELSE MIMT.Name END,MIMT.GUID, CASE WHEN @Lang > 0 THEN CASE WHEN co.LatinName = '' THEN co.Name ELSE co.LatinName END ELSE co.Name END , CO.GUID, CASE WHEN @Lang > 0 THEN CASE WHEN BIMT.LatinName = '' THEN BIMT.Name ELSE BIMT.LatinName END ELSE BIMT.Name END, BIMT.GUID

			------------------------------------------------------------------------------------------------------
			UPDATE #SemiOutput SET #SemiOutput.UnitDeviation = #Result.UnitDeviation 
			FROM #Result 
			WHERE #SemiOutput.SemiMatGuid = #Result.MatGuid 
			-------------------------------------------------------------------------
			UPDATE #SemiOutput SET #SemiOutput.RealPriceValue = #Result.RealPrice * Quantity
			FROM #Result 
			WHERE #SemiOutput.SemiMatGuid = #Result.MatGuid 
			-------------------------------------------------------------------------
			UPDATE #SemiOutput SET Deviation = RealPriceValue - UsedValue
			-------------------------------------------------------------------------
			UPDATE #Result SET IterationDeviation = R.IerationDeviation
			FROM 
			(
				SELECT ReadyMatGuid, CostGuid, SUM(RealPriceValue - UsedValue) IerationDeviation
				FROM #SemiOutput
				GROUP BY ReadyMatGuid, CostGuid
			) R
			WHERE MatGuid = ReadyMatGuid 
			-------------------------------------------------------------------------
			INSERT INTO #Result (MatGuid, MatName, SemiMatGuid, SemiMatName, CostGuid, CostName, Output, UnitDeviation, UsedValue, RealPriceValue, Deviation, TYPE)
			SELECT ReadyMatGuid, ReadyMatName, SemiMatGuid, SemiMatName, CostGuid, CostName, Quantity, UnitDeviation, UsedValue, RealPriceValue, Deviation, 1
			FROM #SemiOutput
			WHERE Quantity > 0
		END
		ELSE
		BEGIN
			DELETE #SemiOutput
			INSERT INTO #SemiOutput (ReadyMatName, ReadyMatGuid, SemiMatName, SemiMatGuid, Quantity, UsedValue)
			SELECT CASE WHEN @Lang > 0 THEN CASE WHEN MIMT.LatinName = '' THEN MIMT.Name ELSE MIMT.LatinName END ELSE MIMT.Name END , mimt.GUID, CASE WHEN @Lang > 0 THEN CASE WHEN BIMT.LatinName = '' THEN BIMT.Name ELSE BIMT.LatinName END ELSE BIMT.Name END, BIMT.GUID,
				SUM(CASE ISNULL(RAWMI.ReadyMatGUID, 0x0)	
					WHEN 0x0 THEN RAWMI.Qty * MI.Percentage / 100 
					WHEN MI.MatGUID THEN RAWMI.Qty
					ELSE 0 END),
				SUM((CASE BI.Unity 
					WHEN 1 THEN BI.Qty
					WHEN 2 THEN BI.Qty / BIMT.Unit2Fact
					WHEN 3 THEN BI.Qty / BIMT.Unit3Fact END * BI.Price) * 
					CASE ISNULL(RAWMI.ReadyMatGUID, 0x0)	
					WHEN 0x0 THEN MI.Percentage / 100 
					WHEN MI.MatGUID THEN 1
					ELSE 0 END)
			FROM MN000 MN INNER JOIN MB000 MB ON MB.ManGUID = MN.GUID
				INNER JOIN MI000 MI ON MI.ParentGUID = MN.GUID
				INNER JOIN bu000 BU ON BU.GUID = MB.BillGUID
				INNER JOIN bi000 BI ON BI.ParentGUID = BU.GUID
				INNER JOIN MI000 RAWMI ON RAWMI.ParentGUID = MN.GUID AND RAWMI.MatGUID = BI.MatGUID AND RAWMI.Number = BI.Number
				INNER JOIN mt000 MIMT ON MIMT.GUID = MI.MatGUID
				INNER JOIN mt000 BIMT ON BIMT.GUID = BI.MatGUID
			WHERE MI.Type = 0 AND MN.Type = 1 AND MB.Type = 2 AND MN.PhaseNumber =  @PhaseNumber
				AND BU.Date BETWEEN @FromDate AND @ToDate
			GROUP BY CASE WHEN @Lang > 0 THEN CASE WHEN MIMT.LatinName = '' THEN MIMT.Name ELSE MIMT.LatinName END ELSE MIMT.Name END,MIMT.GUID, CASE WHEN @Lang > 0 THEN CASE WHEN BIMT.LatinName = '' THEN BIMT.Name ELSE BIMT.LatinName END ELSE BIMT.Name END, BIMT.GUID
			------------------------------------------------------------------------------------------------------
			UPDATE #SemiOutput SET #SemiOutput.UnitDeviation = #Result.UnitDeviation 
			FROM #Result 
			WHERE #SemiOutput.SemiMatGuid = #Result.MatGuid 
			--------------------------------------------------------------------------
			UPDATE #SemiOutput SET #SemiOutput.RealPriceValue = #Result.RealPrice * Quantity
			FROM #Result 
			WHERE #SemiOutput.SemiMatGuid = #Result.MatGuid 
			-------------------------------------------------------------------------
			UPDATE #SemiOutput SET Deviation = RealPriceValue - UsedValue
			-------------------------------------------------------------------------
			UPDATE #Result SET IterationDeviation = R.IerationDeviation
			FROM 
			(
				SELECT ReadyMatGuid, CostGuid, SUM(RealPriceValue - UsedValue) IerationDeviation
				FROM #SemiOutput
				GROUP BY ReadyMatGuid, CostGuid
			) R
			WHERE MatGuid = ReadyMatGuid 
			-------------------------------------------------------------------------
			INSERT INTO #Result (MatGuid, MatName, SemiMatGuid, SemiMatName, Output, UnitDeviation, UsedValue, RealPriceValue, Deviation, TYPE)
			SELECT ReadyMatGuid, ReadyMatName, SemiMatGuid, SemiMatName, Quantity, UnitDeviation, UsedValue, RealPriceValue, Deviation, 1
			FROM #SemiOutput
			WHERE Quantity > 0
		END
		-------------------------------------------------------------------------------
		UPDATE #Result SET PhaseNumber = @PhaseNumber
		FROM #SemiOutput
		WHERE MatGuid = ReadyMatGuid 
		-------------------------------------------------------------------------------
		UPDATE #Result SET	TotalRealCost = ISNULL(RealCost, 0) + ISNULL(IterationDeviation, 0) WHERE TYPE = 0
		UPDATE #Result SET	RealPrice = CASE Output WHEN 0 THEN 0 ELSE TotalRealCost / Output END WHERE TYPE = 0
		UPDATE #Result SET	Deviation = ISNULL(TotalRealCost, 0) - CurrentCost WHERE TYPE = 0
		UPDATE #Result SET	UnitDeviation = CASE Output WHEN 0 THEN 0 ELSE Deviation / Output END WHERE TYPE = 0

		SET @PhaseNumber = @PhaseNumber + 1
	END
	IF (@WithOutCostCenter = 0)
	BEGIN
		SELECT * FROM #Result 
		INNER JOIN fnGetCostsList(@CostGuid) FCO ON FCO.GUID = CostGuid
		ORDER BY PhaseNumber, CostName, MatName, TYPE
	END
	ELSE
	BEGIN
		SELECT * FROM #Result 
		ORDER BY PhaseNumber, CostName, MatName, TYPE
	END
###########################################################
#END