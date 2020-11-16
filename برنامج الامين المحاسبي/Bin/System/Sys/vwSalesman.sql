################################################################################
CREATE VIEW vwSalesman
AS
	SELECT 
		S.Number,
		Co.Code,
		Co.Name,
		S.Guid,
		ISNULL(D.Code, '') AS AsDepartmentCode,
		ISNULL(D.Name, '') AS DepartmentName,
		ISNULL(D.Guid, 0x0)	AS DepartmentID,
		S.Notes, 
		CASE DatePart(hour, S.StartTime) WHEN 0 THEN 
			24 * 60
		ELSE 
			DatePart(hour, S.StartTime) * 60
		END + DatePart(minute, S.StartTime)  AS StartTime,

		CASE FinishInNextDay WHEN 0 THEN 
			CASE DatePart(hour, S.EndTime) WHEN 0 THEN 
				24 * 60
			ELSE 
				DatePart(hour, S.EndTime) * 60
			END
		WHEN 1 THEN 
			(DatePart(hour, S.EndTime) + 24) * 60
		END + DatePart(minute, S.EndTime) AS EndTime,
		S.InWork,
		S.Security
	FROM Salesman000 S
	INNER JOIN Co000 Co ON S.Guid = Co.Guid
	LEFT JOIN Department000 D ON S.DepartmentID = D.Guid
################################################################################
#END
