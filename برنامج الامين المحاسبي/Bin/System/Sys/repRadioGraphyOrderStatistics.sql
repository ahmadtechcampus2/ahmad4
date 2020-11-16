#########################################
CREATE PROCEDURE repRadioGraphyOrderStatistics
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
	[OrderStatus]		INT, --
	[OrderPatientGUID]	UNIQUEIDENTIFIER,--
	[OrderFileGUID]		UNIQUEIDENTIFIER,--
	[OrderPayGUID]		UNIQUEIDENTIFIER,
	[OrderDoctorGUID]	UNIQUEIDENTIFIER,
	[RadioGraphyGUID]	UNIQUEIDENTIFIER,
	[Result]			NVARCHAR(4000) COLLATE ARABIC_CI_AI,
	[State]				NVARCHAR(256) COLLATE ARABIC_CI_AI,
	[Price]				FLOAT,
	[Discount]			FLOAT,
	[AccName]			NVARCHAR(200) COLLATE ARABIC_CI_AI
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
	O.[DoctorGUID],
	R.[GUID],
	D.[Result],
	D.[State],
	D.[Price],
	D.[Discount],
	IsNull(Ac.[name], '')

-- select * from hosRadioGraphyOrder000
FROM
	[HosRadioGraphyOrderDetail000] AS D
	INNER JOIN [hosRadioGraphyOrder000] AS O ON D.ParentGuid = O.Guid 
	INNER JOIN [hosRadioGraphy000] AS R ON R.GUID = D.RadioGraphyGUID
	LEFT join AC000 AS AC on AC.Guid = O.AccGuid
	LEFT JOIN vwHosFile AS H ON O.[FileGUID] = H.[GUID]
WHERE
	( (O.[PatientGUID] = @PatientGUID) OR ( H.[PatientGUID] = @PatientGUID) OR ( @PatientGUID = 0x0))
	AND(( O.[DoctorGUID] = @DoctorGuid) OR ( @DoctorGuid = 0x0))
	AND ( O.[Date] BETWEEN @StartDate AND @EndDate)
	AND ( 
			(@PatientType = -1 ) 
			OR ( @PatientType = 0 AND O.[FileGUID] <> 0x0 AND O.[FileGUID] IS NOT NULL ) 
			OR ( @PatientType = 1 AND O.[FileGUID] = 0x0)
		)

-- select * from #Result
-- select * from [HosRadioGraphyOrderDetail000] AS D
--- return result set 
SELECT
	R.[OrderGuid],
	R.[OrderCode],
	R.[OrderDate],
	R.[AccName], 
	R.[OrderStatus],
	R.[OrderPayGUID],
	R.[OrderPatientGUID],
	R.[OrderDoctorGUID],
	R.[RadioGraphyGUID],
	R.[Result],
	R.[State],
	R.[Price],
	R.[Discount],
	ISNULL( P.[Name], F.[Name]) AS PatientName,
	ISnull(F.Code, -1) AS FileCode ,
	G.[Name] AS [Name],
	E.[Name] AS DoctorName
FROM
	[#Result] AS R
	LEFT JOIN [vwhosEmployee] AS E ON R.[OrderDoctorGUID] = E.[GUID]
	LEFT JOIN [hosRadioGraphy000] AS G ON G.[GUID] = R.[RadioGraphyGUID]
	LEFT JOIN [vwHosPatient] AS P ON R.[OrderPatientGUID] = P.[Guid]
	LEFT JOIN [vwHosFile] AS F ON R.[ORDERFileGuid] = F.[GUID]
ORDER BY
	R.[OrderNumber]


/*


EXEC repRadioGraphyOrderStatistics
0x0,		--@PatientGUID 		UNIQUEIDENTIFIER,
0x0,		--@DoctorGuid		UNIQUEIDENTIFIER,
'1/1/2005',	--@StartDate		DATETIME,
'1/1/2006',	--@EndDate			DATETIME
1			--@PatientType		INT = -1 ---- 0 internal , 1 Extermal , -1 ALL
select * from hosRadioGraphy000
select * from hosRadioGraphyOrder000 order by number

select * from [hosRadioGraphyOrder000] as h inner join HosPatient000 as p on h.[PatientGUID] = p.guid

select * from vwHosFile
select * from [hosRadioGraphy000]
select * from HosRadioGraphyOrderDetail000


exec [repRadioGraphyOrderStatistics] '913e0088-832a-487b-b36f-e3c9a32a2afc', '00000000-0000-0000-0000-000000000000', '1/1/2005', '6/22/2005' 

EXEC [repRadioGraphyOrderStatistics] 0X0, 0X0, '12/26/2005', '12/26/2005', 1 

select * from [hosRadioGraphyOrder000] WHERE DATE = '12/26/2005'
*/
#########################################
#END