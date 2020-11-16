##############################
CREATE VIEW vtHosPFile
AS
	SELECT * FROM HosPFile000
##############################
CREATE VIEW vbHosPFile
AS
	SELECT * FROM vtHosPFile
##############################
CREATE VIEW vcHosPFile
AS
	SELECT * FROM vbHosPFile
##############################
CREATE VIEW vdHosFile
AS
	SELECT * FROM vbHosPFile
##############################
CREATE VIEW vwHosFile
AS 
SELECT 
			F.Number, 
			F.GUID, 
			F.Code , 
			P.[Name], 
			P.[LatinName], 
			F.Security, 
			F.DateIn, 
			F.DateOut, 
			F.PatientGuid, 
			F.AccGuid, 
			F.CostGuid, 
			P.Gender,
			IsNull(cu.Guid, 0x0) As CustomerGuid, 
			F.EntranceType,
			ISNULL(P.PatientNation, '') PatientNation,
			ISNULL(PatientBirthDay, GetDate()) PatientBirthDay,
			F.Accompanying,
			F.Branch
FROM vbHosPFile F INNER JOIN vwHosPatient AS P ON F.PatientGUID = P.GUID 
				   left JOIN Cu000 cu ON cu.AccountGuid = F.AccGuid
##############################
CREATE VIEW vwHosConsumed
AS
SELECT 
	C.Number, 
	C.GUID, 
	C.FileGUID, 
	C.MatGUID, 
	C.Notes, 
	C.Security, 
	C.Price, 
	C.Qty, 
	C.Discount,
	C.Unity,
	ISNULL( MAS.CurrencyGuid, 0x0) AS CurrencyGuid,
	ISNULL( MAS.CurrencyVal, 1) AS CurrencyVal,
	C.ParentGuid,
	M.mtCode MatCode,
	M.[mtName] MatName,
	M.mtLatinName LatinName,
	ISNULL( [St].[Guid], [C].[StoreGuid]) AS StoreGUID,
	ISNULL( St.Name, '') AS StoreName,

	( case C.Unity WHEN 1 THEN 1
				WHEN 2 THEN M.mtUnit2Fact
				WHEN 3	THEN M.mtUnit3Fact
				ELSE M.mtDefUnitFact END) AS mtUnitFact,
	[dbo].[fnItemSecViol](0x0, [C].[MatGUID], ISNULL( [St].[Guid], [C].[StoreGuid]), [F].[costGuid]) as [SecViol]

FROM HosConsumed000 C INNER JOIN vwMt  M ON C.MatGUID = M.MtGUID
					INNER JOIN HosPFile000 as F ON C.FileGuid = F.Guid
					LEFT JOIN st000 AS st ON st.Guid = C.StoreGuid
					LEFT JOIN HosConsumedMaster000 AS MAS ON MAS.Guid = C.ParentGuid

/*
select * from mt000
select * from bi000 where matguid = 'E450D34F-3653-4B87-B3E1-B59B22F2BEE0' and parentguid = '3E3D99C1-8F5C-47FA-BEFF-83CC69708B51'
select * from HosConsumed000
select * from vwHosConsumed
select * from hosStay000
select * from vwHosEMPLOYEE
select * from HosEMPLOYEE000

select * from ce000 where guid = '8F7C8DA2-8E10-4E66-A55A-24CB109E20CC'
select * from en000 where parentguid = '8F7C8DA2-8E10-4E66-A55A-24CB109E20CC'


select guid from mt000 where code = '4160101' 

select guid from bu000 where number = 631
*/
##############################
#END