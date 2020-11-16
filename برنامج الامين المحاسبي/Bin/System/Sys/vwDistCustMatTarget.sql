##################################################################################
CREATE VIEW vtDistDistributorTarget
AS 
	SELECT * FROM DistDistributorTarget000
##################################################################################
CREATE VIEW vbDistDistributorTarget
AS 
	SELECT * FROM vtDistDistributorTarget
##################################################################################
CREATE VIEW vwDistDistributorTarget
AS 
	SELECT * FROM vbDistDistributorTarget
##################################################################################

CREATE VIEW vtDistCustTarget
AS 
	SELECT * FROM DistCustTarget000
##################################################################################
CREATE VIEW vbDistCustTarget
AS 
	SELECT * FROM vtDistCustTarget
##################################################################################
CREATE VIEW vwDistCustTarget
AS
	SELECT
		c.GUID 			AS dtGUID, 
		c.PeriodGUID, 
		c.CustGUID, 
		c.CustCalcedTarget, 
		c.CustTarget, 
		c.TotalCustCalcedTarget, 
		c.TotalCustTarget, 
		c.Unity, 
		c.Notes, 
		c.Security,
		c.DistGUID,
		c.CurGuid,
		c.CurVal,
		c.BranchGUID,
		c.PriceType,
		c.CustDistRatio
	FROM 
		vbDistCustTarget		AS c 
##################################################################################

CREATE VIEW vtDistCustMatTarget
AS 
	SELECT * FROM DistCustMatTarget000
##################################################################################
CREATE VIEW vbDistCustMatTarget
AS 
	SELECT * FROM vtDistCustMatTarget
##################################################################################
CREATE VIEW vwDistCustMatTarget
AS 
	SELECT 
		d.GUID, 
		d.PeriodGUID, 
		d.CustGUID, 
		d.MatGUID, 
		d.CustRatio, 
		d.CustTarget, 
		d.Unit, 
		d.Notes, 
		d.Security, 
		d.ExpectedCustTarget,
		mt.mtName,
		c.cucustomerName
	FROM
		vbDistCustMatTarget AS d 
		INNER JOIN vwmt AS mt ON d.MatGuid = mt.mtGuid
		INNER JOIN vwCU AS c  ON d.CustGuid = c.cuGuid
##################################################################################
#END