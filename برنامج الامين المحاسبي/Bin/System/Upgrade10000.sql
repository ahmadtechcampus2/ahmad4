#include upgrade_core.sql
###################################################
CREATE PROCEDURE prcUpgradeDatabase_From100010001
AS 
	IF([dbo].[fnObjectExists]('prcPOSCheckOptions') = 1)
		DROP PROC prcPOSCheckOptions

	EXEC prcAddBitFld 'Distributor000', 'AutoNewCustToRoute'
	EXEC prcAddIntFld 'DistDeviceNewCu000', 'Route1'

	EXECUTE [prcAlterFld] 'bu000', 'ReturendBillNumber', 'NVARCHAR(500)'
	EXECUTE [prcAlterFld] 'POSOrder000', 'ReturendBillNumber', 'NVARCHAR(500)'
	EXECUTE [prcAlterFld] 'POSOrderTemp000', 'ReturendBillNumber', 'NVARCHAR(500)'

	EXEC prcAddCharFld 'DistDeviceCU000', 'TaxNumber' , 250
	EXEC prcAddCharFld 'DistDeviceCU000', 'LocationName' , 250
	EXEC prcAddCharFld 'DistDeviceCU000', 'LocationLatinName' , 250

	-- BEGIN CMPT04 - 02
	-- BEGIN POS Field
	EXECUTE prcAddCharFld 'POSOrder000', 'TextFld1', 250
	EXECUTE prcAddCharFld 'POSOrder000', 'TextFld2', 250
	EXECUTE prcAddCharFld 'POSOrder000', 'TextFld3', 250
	EXECUTE prcAddCharFld 'POSOrder000', 'TextFld4', 250

	EXECUTE prcAddCharFld 'POSOrderTemp000', 'TextFld1', 250
	EXECUTE prcAddCharFld 'POSOrderTemp000', 'TextFld2', 250
	EXECUTE prcAddCharFld 'POSOrderTemp000', 'TextFld3', 250
	EXECUTE prcAddCharFld 'POSOrderTemp000', 'TextFld4', 250

	EXEC prcAddGUIDFld 'POSOrderItems000', 'RelatedBillID'
	EXEC prcAddGUIDFld 'POSOrderItemsTemp000', 'RelatedBillID'
	EXEC prcAddGUIDFld 'POSOrderItems000', 'BillItemID'
	EXEC prcAddGUIDFld 'POSOrderItemsTemp000', 'BillItemID'
	-- END POS Field
	
	IF [dbo].[fnObjectExists]('Allocations000.CustomerGUID') =  0
	BEGIN
		EXEC prcAddGUIDFld 'Allocations000', 'CustomerGUID'
		EXEC ('UPDATE   al
					SET CustomerGUID = (cu.GUID ) 
					FROM   
						Allocations000 al  
						INNER JOIN (   
							SELECT  cu.AccountGUID,count (*) as cnt  
							FROM cu000 as cu
							GROUP BY cu.AccountGUID 
							having count (*) = 1 ) cust
						ON    al.AccountGuid = cust.AccountGUID
						inner join cu000 as cu on cu.AccountGUID = cust.AccountGUID
				')
	END

	IF [dbo].[fnObjectExists]('Allocations000.ContraCustomerGUID') =  0
	BEGIN
		EXEC prcAddGUIDFld 'Allocations000', 'ContraCustomerGuid'
		EXEC ('UPDATE   al
					SET ContraCustomerGuid = (cu.GUID ) 
					FROM   
						Allocations000 al  
						INNER JOIN (   
							SELECT  cu.AccountGUID,count (*) as cnt  
							FROM cu000 as cu
							GROUP BY cu.AccountGUID 
							having count (*) = 1 ) cust
						ON    al.AccountGuid = cust.AccountGUID
						inner join cu000 as cu on cu.AccountGUID = cust.AccountGUID
				')

		EXEC ('
				DELETE FROM op000 WHERE Name = ''AccCfg_AllotmentCard.PaysGridsFields''
				DELETE FROM op000 WHERE Name = ''AccCfg_AllotmentCard.PaysChecksFields''
			')
	END

	EXECUTE	prcAddBitFld 'cu000', 'ConsiderChecksInBudget'
	EXECUTE [prcAddBitFld] 'SpecialOffers000', 'CanOfferedSelected'

	IF EXISTS (SELECT * FROM GCCTaxCoding000)
	BEGIN 
		IF NOT EXISTS (SELECT * FROM GCCTaxCoding000 WHERE TaxCode = 14)
			INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
			SELECT 9, NEWID(), N'NA', N'غير مكلف', N'Not Assignment', 1, 14, 0

			EXEC ('
			UPDATE en
			SET GCCOriginDate = py.Date
			FROM 
				en000 en 
				INNER JOIN ce000 ce ON ce.GUID = en.ParentGUID 
				INNER JOIN er000 er ON ce.GUID = er.EntryGUID 
				INNER JOIN py000 py ON py.GUID = er.ParentGUID 
			WHERE GCCOriginNumber != N'''' AND GCCOriginDate = ''1980-01-01''')

	END 
	-- END CMPT04 - 02
######################################################################################
#END