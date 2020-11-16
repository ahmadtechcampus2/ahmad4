##############################
CREATE VIEW vtHosAnalysisOrder
AS
	SELECT * FROM hosAnalysisOrder000
##############################
CREATE VIEW vbHosAnalysisOrder
AS
	SELECT * FROM vtHosAnalysisOrder
##############################
CREATE VIEW vcHosAnalysisOrder
AS
	SELECT * FROM vbHosAnalysisOrder
##############################
CREATE VIEW vdHosAnalysisOrder
AS
	SELECT * FROM vbHosAnalysisOrder

##############################
CREATE VIEW vwHosAnalysisOrder
AS
SELECT
		A.Number,
		A.GUID,
		A.Code,
		A.FileGUID,
		CASE WHEN A.PatientGUID = 0x0 THEN F.PatientGUID ELSE A.PatientGUID END AS PatientGUID,
		A.AccGUID,
		-- A.Date,
		CAST( CAST (DatePart( yyyy, A.[Date]) AS NVARCHAR) + '/' + CAST ( DatePart( mm, A.[Date] ) AS NVARCHAR ) + '/'+CAST( DatePart( dd, A.[Date] )AS NVARCHAR) AS datetime) AS [Date], 
		A.Status, 
		A.Notes, 
		A.Security, 
		A.PayGuid,
		A.Branch,
		F.[Code] [FileCode],
		F.[Name] [FileName],
		F.[LatinName] [FileLatinName],
		P.[Code] PatientCode,
		P.[Name] PatientName,
		P.[LatinName] PatientLatinName,
		P.Kind,
		P.PatientBirthDay
	FROM vbHosAnalysisOrder A LEFT JOIN   vwHosFile F ON A.FileGUID =  F.GUID
							   LEFT JOIN   vwHosPatient P ON A.PatientGUID =  P.GUID

##############################
CREATE  FUNCTION  fnHosGetMaxAnalysisDate( 
			@PatientGUID UNIQUEIDENTIFIER,	
			@ItemGUID UNIQUEIDENTIFIER,
			@Date DATETIME
)
RETURNS DATETIME
BEGIN
	DECLARE @RES DATETIME
	SELECT @RES = Max( [Date]) 
	FROM HosAnalysisResults000  R
					INNER JOIN vwHosAnalysisOrder O ON R.AnalysisOrderGuid = O.GUID
					INNER JOIN vwHosAnalysisAll A ON A.GUID = R.ItemGUID 
	WHERE ItemGUID = @ItemGUID 		
				AND 
				PatientGUID = @PatientGUID
				AND 
				[DATE] < @Date
	RETURN @Res
END
##############################
#END