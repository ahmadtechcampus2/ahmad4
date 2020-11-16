#########################################################
CREATE VIEW vwShipToBill
as
	SELECT * from    pfcshipmentbill000
	WHERE TYPE = 1
#########################################################
CREATE VIEW vwReturnFromBill
as
	SELECT * from     pfcshipmentbill000
	WHERE TYPE = 2
#########################################################
CREATE VIEW vwShipToBillWithPurchasingBillView
as
	SELECT * from     pfcshipmentbill000
	WHERE TYPE = 3
#########################################################
CREATE VIEW vwShipFromBillWithReturnPurchasingBillView
as
	SELECT * from     pfcshipmentbill000
	WHERE TYPE = 4
#########################################################
CREATE VIEW vtsubprofitcenter
as
	SELECT * FROM   subprofitcenter000
#########################################################
CREATE VIEW vtmainprofitcenter
as
	SELECT * FROM   mainprofitcenter000
#########################################################
CREATE VIEW ViewGeneralOrCompositeAcc
as
	SELECT * FROM vbAc 
	WHERE (NSons > 0 AND type != 2) OR Type = 4
#########################################################
CREATE VIEW ViewBelongsToCompositeAccount
AS 
SELECT ac.* FROM ci000 ci 
INNER JOIN vbAc ac on ac.guid = ci.SonGUID
WHERE ci.ParentGUID = CAST( (SELECT TOP 1 Value FROM op000 WHERE NAME = 'PFC_Providers_Account') AS UNIQUEIDENTIFIER)
#########################################################
CREATE VIEW ViewBelongsToGeneralAccount
AS
SELECT ac.* 
FROM dbo.fnGetAccountsList(CAST( (SELECT TOP 1 Value FROM op000 WHERE NAME = 'PFC_Providers_Account') AS UNIQUEIDENTIFIER),0) AccList
INNER JOIN vbAc ac 
ON ac.GUID = AccList.GUID
#########################################################		
#END
