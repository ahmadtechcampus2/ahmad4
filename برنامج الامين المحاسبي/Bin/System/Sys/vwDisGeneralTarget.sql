######################################################################
CREATE VIEW vtDisGeneralTarget
AS 
	SELECT * FROM DisGeneralTarget000
######################################################################
CREATE VIEW vbDisGeneralTarget
AS 
	SELECT * FROM vtDisGeneralTarget
######################################
CREATE VIEW vwDisGeneralTarget
AS
	SELECT
		t.GUID,
		t.PeriodGUID,
		t.StartDate,
		t.EndDate,
		t.MatGUID, 
		t.Qty,
		t.Unit,
		t.SalesQty,
		t.SalesUnit,
		t.Notes, 
		t.Security,
		t.BranchGuid,
		t.PeriodsMask,
		m.Name AS MatName
	FROM 
		vbDisGeneralTarget AS t 
		INNER JOIN mt000 AS m ON t.MatGUID = m.Guid
######################################
CREATE VIEW vtDistCustClassesTarget
AS 
	SELECT * FROM DistCustClassesTarget000
#############################################
CREATE VIEW vbDistCustClassesTarget
AS 
	SELECT * FROM vtDistCustClassesTarget
#############################################
CREATE VIEW vwDistCustClassesTarget
AS
	SELECT 
		CcT.Guid		AS Guid,
		CcT.PeriodGuid	AS PeriodGuid,
		Cc.Guid			AS CustClassGuid,
		Cc.Name			AS CustClassName,
		Cc.Number		AS CustClassNumber,	
		tp.Guid			AS MatTemplateGuid,
		tp.Name			AS MatTemplateName,
		tp.Number		AS MatTemplateNumber,
		Cct.CurGuid		AS CurGuid,
		Cct.CurVal		AS CurVal,
		Cct.TargetVal	AS TargetVal,
		CcT.BranchGuid	AS BranchGuid
	FROM vbDistCustClassesTarget	AS CcT
		INNER JOIN DistMatTemplates000	AS tp	ON tp.Guid = CcT.MatTemplateGuid	
		INNER JOIN DistCustClasses000	AS Cc	ON Cc.Guid = CcT.CustCLassGuid		
###################################################################
CREATE VIEW vtDisTChTarget
AS 
	SELECT * FROM DisTChTarget000
######################################
CREATE VIEW vbDisTChTarget
AS 
	SELECT * FROM vtDisTChTarget
######################################
CREATE VIEW vwDisTChTarget
AS
	SELECT * FROM vbDisTChTarget 
###################################################################
#END
