##################################################################################
CREATE VIEW vwHosSurgeryWorker
AS
SELECT
	S.Number, 
	S.GUID, 
	S.ParentGuid, 
	S.WorkerGUID, 
	S.WorkNature, 
	S.Ratio, 
	S.Income, 	
	S.[Desc],
	E.Code EmpCode,
	E.Name EmpName,
	E.LatinName EmpLatinName
FROM 
	HosSurgeryWorker000 S
		INNER JOIN  vwhosEmployee E ON  S.WorkerGUID = E.GUID
##################################################################################
#END

