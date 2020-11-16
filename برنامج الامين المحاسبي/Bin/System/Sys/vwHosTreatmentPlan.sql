#########################################################################
CREATE VIEW  vwHosTreatmentPlan
AS
SELECT 
	T.Guid,
	T.Number,	
	T.Code, 
	T.FileGUID,		F.Code FileCode, 	F.[Name] [FileName],	F.[LatinName] [FileLatinName],
	T.MatGUID,	mt.Code MatCode, mt.[Name] MatName, mt.LatinName matLatinName,
	T.StoreGUID, st.Code StoreCode, st.[Name] StoreName, st.LatinName StoreLatinName,
	T.Dose,	
	T.Every,	
	T.Qty,	
	T.Unity,
	T.StartTime,	
	T.Priority,	
	T.Status,	
	T.Notes,
	T.Security,
	T.BillGuid
FROM HosTreatmentPlan000 As T INNER JOIN vwHosFile F ON F.GUID = T.FileGUID
															INNER JOIN mt000 mt ON mt.GUID = T.MatGUID
															INNER JOIN st000 st ON st.GUID = T.StoreGUID
#########################################################################
CREATE    VIEW  vwHosTreatmentPlanDetails
AS
SELECT 
	TD.Guid,
	T.Number,	
	T.Code,
	T.BillGuid,
	T.FileGUID,		F.Code FileCode, 	F.[Name] [FileName],	F.[LatinName] [FileLatinName],
	F.CostGuid, 
	F.AccGuid,
	F.CustomerGuid,
	T.MatGUID,	mt.Code MatCode, mt.[Name] MatName, mt.LatinName matLatinName,
	T.StoreGUID,	st.Code StoreCode, st.[Name] StoreName, mt.LatinName StoreLatinName,
	T.Dose,	
	T.Unity,	
	T.Every,	
	T.Qty,	
	T.StartTime,	
	T.Priority,	
	T.Status,	
	T.Notes,	

	TD.GUID	DetailsGUID,
	TD.ParentGUID	 ParentGUID,
	TD.StoreGUID DetailsStoreGUID, std.Code DetailsStoreCode, std.Name DetailsStoreName , std.LatinName DetailsStoreLatinName,
	TD.MatGUID	 DetailsMatGUID, mtd.Code DetailsMatCode, mtd.Name DetailsMatName, mtd.LatinName DetailsMatLatinName,
	TD.Qty	DetailsQty,
	TD.Unity DetailsUnity,
	case TD.Unity when 0 then mt.Unity when 1  then mt.Unit2 when 2 then  mt.Unit3 END AS DetailsUnityName,	
	TD.WorkerGUID, emp.Code WorkerCode, emp.Name WorkerName, emp.LatinName WorkerLatinName, 
	TD.DoseTime,	
	TD.Dose DetailsDose,	
	TD.Notes DetailsNotes,
	TD.Status DetailsStatus
FROM HosTreatmentPlan000 As T	INNER JOIN HosTreatmentPlanDetails000 TD ON T.GUID = TD.ParentGUID
								INNER JOIN vwHosFile F ON F.GUID = T.FileGUID
								INNER JOIN mt000 mt ON mt.GUID = t.MatGUID
								INNER JOIN mt000 mtd ON mtd.GUID = td.MatGUID
								LEFT JOIN vwHosEmployee emp On emp.GUID = TD.WorkerGUID
								LEFT JOIN st000 st On st.GUID = T.StoreGUID
								LEFT JOIN st000 std On std.GUID = TD.StoreGUID
								LEFT JOIN cu000 cu On cu.GUID = F.AccGuid
#########################################################################
#END