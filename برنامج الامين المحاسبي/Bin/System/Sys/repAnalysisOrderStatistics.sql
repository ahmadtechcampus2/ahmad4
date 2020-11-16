###########################
CREATE PROCEDURE repAnalysisOrderStatistics
	@PatientGUID 	UNIQUEIDENTIFIER,
	@DoctorGuid		UNIQUEIDENTIFIER,
	@StartDate		DATETIME,
	@EndDate		DATETIME,
	@PatientType		INT = -1 ---- 0 internal , 1 Extermal , -1 ALL
AS
SET NOCOUNT ON 
CREATE TABLE #Result
(
	[OrderNumber]		FLOAT,
	[OrderGuid]			UNIQUEIDENTIFIER,
	[OrderCode]			NVARCHAR(256) COLLATE ARABIC_CI_AI,
	[OrderDate]			DATETIME,
	[OrderStatus]		INT,
	[OrderPatientGUID]	UNIQUEIDENTIFIER,
	[OrderFileGUID]		UNIQUEIDENTIFIER,
	[OrderPayGUID]		UNIQUEIDENTIFIER,
	--[OrderDoctorGUID]	UNIQUEIDENTIFIER,
	
	[AnalysisGUID]		UNIQUEIDENTIFIER,
	[Result]			NVARCHAR(256) COLLATE ARABIC_CI_AI,
	[State]				NVARCHAR(256) COLLATE ARABIC_CI_AI,
	[Price]				FLOAT--,
	--[Discount]			FLOAT
)

INSERT INTO #Result
SELECT 
	O.[Number],
	O.[Guid],
	O.[Code],
	O.[Date],
	O.[Status],
	ISNULL( O.[PatientGUID], H.[PatientGUID]), 
	O.[FileGUID],
	O.[PayGUID],
	--O.[DoctorGUID],
	T.[AnalysisGUID],--R.[GUID],
	D.[Result],
	D.[State],
	R.[Price] --,
	--D.[Discount]
-- select * from [HosToDoAnalysis000]
FROM
	[hosAnalysisOrder000] AS O 
	INNER JOIN [HosToDoAnalysis000] AS T ON T.[AnalysisOrderGuid] = O.[Guid] 
	INNER JOIN [hosAnalysis000] AS R ON R.[GUID] = T.[AnalysisGUID]
	LEFT JOIN [hosAnalysisOrderDetail000] AS D ON O.[Guid] = D.[ParentGUID]

	LEFT JOIN [vwHosFile] AS H ON O.[FileGUID] = H.[GUID]
WHERE
	( (O.[PatientGUID] = @PatientGUID) OR ( H.[PatientGUID] = @PatientGUID) OR ( @PatientGUID = 0x0))
	--AND(( O.[DoctorGUID] = @DoctorGuid) OR ( @DoctorGuid = 0x0))
	AND ( O.[Date] BETWEEN @StartDate AND @EndDate)
	AND ( 
			(@PatientType = -1 ) 
			OR ( @PatientType = 0 AND O.[FileGUID] <> 0x0 AND O.[FileGUID] IS NOT NULL ) 
			OR ( @PatientType = 1 AND O.[PatientGUID] <> 0x0 AND O.[PatientGUID] IS NOT NULL )
		)

--- return result set 
SELECT
	R.[OrderGuid],
	R.[OrderCode],
	R.[OrderDate],
	R.[OrderStatus],
	R.[OrderPayGUID],
	R.[OrderPatientGUID],
	--R.[OrderDoctorGUID],
	R.[AnalysisGUID],
	R.[Result],
	R.[State],
	R.[Price],
	--R.[Discount],
	ISNULL( P.[Name], F.[Name]) AS PatientName,
	G.[Name] AS [Name] --,
	--E.[Name] AS DoctorName
FROM
	[#Result] AS R
	-- LEFT JOIN [vwhosEmployee] AS E ON R.[OrderDoctorGUID] = E.[GUID]
	LEFT JOIN [hosAnalysis000] AS G ON G.[GUID] = R.[AnalysisGUID]
	LEFT JOIN [vwHosPatient] AS P ON R.[OrderPatientGUID] = P.[Guid]
	LEFT JOIN [vwHosFile] AS F ON R.[ORDERFileGuid] = F.[GUID]
ORDER BY
	R.[OrderNumber]

/*



EXEC repAnalysisOrderStatistics
0x0,		--@PatientGUID 		UNIQUEIDENTIFIER,
0x0,		--@DoctorGuid		UNIQUEIDENTIFIER,
'1/1/2005',	--@StartDate		DATETIME,
'1/1/2006',	--@EndDate			DATETIME
1			-- @PatientType		INT = -1 ---- 0 internal , 1 Extermal , -1 ALL

exec repAnalysisOrderStatistics '913e0088-832a-487b-b36f-e3c9a32a2afc', '00000000-0000-0000-0000-000000000000', '1/1/2005', '6/22/2005' 

--select * from HosAnalysisLookUpValues000
select * from dbo.HosAnalysisResults000

select * from dbo.HosAnaDet000

select * from dbo.hosAnalysisItems000

dbo.HosAnalysisResults000
select * from [HosAnalysisOrderDetail000] 
select * from 
	[hosAnalysisOrder000] AS O 
	INNER JOIN [hosAnalysis000] AS R ON R.GUID = D.AnalysisGUID
	LEFT JOIN [HosAnalysisOrderDetail000] AS D ON D.ParentGuid = O.Guid 
	LEFT JOIN vwHosFile AS H ON O.[FileGUID] = H.[GUID]
select * from dbo.hosAnalysisOrder000 where code = '4081'
'39AC3899-25B4-4616-9025-55884F41157F'
dbo.hosAnalysisOrderDetail000

select * from dbo.HosToDoAnalysis000 where AnalysisOrderGUID = '39AC3899-25B4-4616-9025-55884F41157F'
select * from dbo.hosAnalysisOrderDetail000

*/

###########################
#END