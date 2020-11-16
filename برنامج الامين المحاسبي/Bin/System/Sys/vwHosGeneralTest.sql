##################################################################################
CREATE  VIEW vwHosGeneralTest
AS
SELECT 
	G.Number, 
	G.GUID, 
	G.FileGUID, 
	G.Date, 
	G.OperationGUID, 
	G.AccGUID,
	G.Result, 
	G.Cost, 
	G.Notes, 
	G.Security, 
	G.Discount, 
	G.Type,
	G.EntryGUID,
	Op.[Code] OpCode,
	OP.[Name] OpName,
	OP.[LatinName] OpLatinName,
	AC.[Code]  AccCode,
	AC.[Name]  AccName,
	AC.[LatinName]  AccLatinName,
	G.CurrencyGuid,
	G.CurrencyVal
FROM hosGeneralTest000  G 
		INNER JOIN hosGeneralOperation000 OP ON G.OperationGUID =  OP.GUID
		LEFT JOIN AC000 AC 						ON G.ACCGUID =  AC.GUID
##################################################################################
#END
