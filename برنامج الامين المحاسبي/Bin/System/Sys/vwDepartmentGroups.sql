################################################################################
CREATE view vwDepartmentGroups
AS

	SELECT
		Gr.Code AS GroupCode,
		Gr.Name AS GroupName,
		ParentID,
		Gr.Guid AS GroupID,
		DG.Number
	FROM DepartmentGroups000 DG
	LEFT JOIN Gr000 Gr ON DG.GroupID = Gr.Guid
################################################################################
#END
	