##################################################################################
CREATE VIEW vwHosSurgeryUsedMats
AS
SELECT
	S.Number, 
	S.GUID, 
	ParentGuid, 
	S.MatGUID, 
	Price, 
	S.Qty, 
	S.Unity,
	Discount, 
	[Desc],
	S.Type,
	S.StoreGUID,
	M.mtCode MatCode,
	M.mtName MatName,
	M.mtLatinName MatLatinName,
	( case S.Unity WHEN 1 THEN 1
				WHEN 2 THEN M.mtUnit2Fact
				WHEN 3	THEN M.mtUnit3Fact
				ELSE M.mtDefUnitFact END) AS mtUnitFact,
	[dbo].[fnItemSecViol]( 0x0, [MatGUID], [StoreGUID], 0x0/* [costGuid]*/) as [SecViol]
FROM
	HosSurgeryMat000 S
		INNER JOIN vwHosSurgeryMats M ON  S.MatGUID = M.mtGUID

/*
select * from vwHosSurgeryUsedMats
*/

##################################################################################
#END

