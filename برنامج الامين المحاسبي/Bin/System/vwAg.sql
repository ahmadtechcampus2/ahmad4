###########################################################################
CREATE VIEW vtAg
AS
	SELECT * FROM ag000

###########################################################################
CREATE VIEW vbAg
AS
	SELECT ag.*
	FROM vtAg AS Ag INNER JOIN vwBl AS bl ON ag.GUID = bl.blRefGUID

###########################################################################
CREATE VIEW vcAg
AS
	SELECT * FROM vbAg

###########################################################################
CREATE VIEW vdAg
AS
	SELECT DISTINCT * FROM vbAg

###########################################################################
CREATE VIEW vwAg
AS
	SELECT
		GUID AS agGUID,
		Number AS agNumber,
		Code AS agCode,
		[Name]AS agName,
		LatinName AS agLatinName,
		Notes AS agNotes,
		Security AS agSecurity,
		Type AS agType,
		AssAccGUID AS agAssAccPtr,
		DepAccGUID AS agDepAccPtr,
		AccuDepAccGUID AS agAccuDepAccPtr,
		OutAccGUID AS agOutAccPtr,
		CalcType AS agCalcType,
		ParentGUID AS agParent,
		CostGUID AS agCostJob,
		Num1 AS agNum1,
		Num2 AS agNum2,
		Num3 AS agNum3,
		Num4 AS agNum4,
		Num5 AS agNum5,
		Num6 AS agNum6,
		Str1 AS agStr1,
		Str2 AS agStr2,
		Str3 AS agStr3,
		Str4 AS agStr4,
		Date1 AS agDate1,
		Date2 AS agDate2
	FROM
		vdAg

###########################################################################
#END