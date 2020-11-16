##########################################
CREATE VIEW vwHosRadioGraphyOrderDetails
AS 
SELECT  
		O.[Number],
		O.[GUID],
		O.[Code],
		O.[FileGUID],
		O.[PatientGUID],
		O.GENDER,
		O.[AccGUID],
		O.[Date],
		O.[StatusGUID],
		O.[Status],
		O.[Notes],
		D.[Notes] AS DetailNotes,
		O.[Security],
		O.[PayGuid],
		O.[Branch],
		O.[FileCode],
		O.[FileName],
		R.TypeGuid,
		O.[PatientCode],
		O.[PatientName],
		O.DoctorGUID,
		D.[RadioGraphyGuid],
		D.price,
		R.[Name] AS RGName,
  	R.[Code] AS RGCode
	FROM
		[vwHosRadioGraphyOrder] AS O INNER JOIN [hosRadioGraphyOrderDetail000] AS D ON O.[Guid] = D.[ParentGuid]
		INNER JOIN vwHosRadioGraphy AS R ON D.[RadioGraphyGuid] = R.[Guid]
		LEFT JOIN HosRadioGraphyType000 AS RT ON  RT.[Guid] = R.TypeGuid
###################################################
#END