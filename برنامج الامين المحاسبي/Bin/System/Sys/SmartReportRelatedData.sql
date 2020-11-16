##################################################################################
CREATE PROCEDURE prcGetCustomerData
	@fields		NVARCHAR(MAX),
	@keyType	INT,
	@keys		KeysTable READONLY
AS
	DECLARE @sql		NVARCHAR(MAX),
			@cfTable	NVARCHAR(255);
		
	SET @sql = N'SELECT ' + @fields + N' FROM @keys K LEFT JOIN vexCu C ON K.ID = C.GUID' + 
		N' LEFT JOIN ac000 A ON A.GUID = C.AccountGUID' +
		N' LEFT JOIN GCCCustLocations000 gccL ON gccL.GUID = C.GCCLocationGUID' +
		N' LEFT JOIN vwcu cu ON cu.CuGUID = C.GUID' +
		N' LEFT JOIN co000 Co ON Co.GUID = C.CostGUID' +
		N' LEFT JOIN GCCCustomerTax000 cuTax ON cuTax.CustGUID = C.GUID AND cuTax.TaxType = 1' +
		N' LEFT JOIN (SELECT TaxCode, Code + ''-'' + Name AS TaxCodeName, Code + ''-'' + LatinName AS TaxCodeLName FROM GCCTaxCoding000) gccTC ON gccTC.TaxCode = cuTax.TaxCode' +
		N' LEFT JOIN GCCCustomerTax000 cuETax ON cuETax.CustGUID = C.GUID AND cuETax.TaxType = 2' +
		N' LEFT JOIN (SELECT TaxCode, Code + ''-'' + Name AS TaxCodeName, Code + ''-'' + LatinName AS TaxCodeLName FROM GCCTaxCoding000) gccETC ON gccETC.TaxCode = cuETax.TaxCode';

	IF CHARINDEX(N'__CF__', @fields) > 0
	BEGIN
		SET @cfTable = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'cu000');
		SET @sql = @sql + N' LEFT JOIN ' + @cfTable + N' CF ON C.GUID = CF.Orginal_Guid';
	END

	SET @sql = @sql + N' ORDER BY K.Ordinal';

	EXECUTE sp_executesql @sql, N'@keys KeysTable READONLY', @keys;
##################################################################################
CREATE PROCEDURE prcGetMaterialData
	@fields		NVARCHAR(MAX),
	@keyType	INT,
	@keys		KeysTable READONLY
AS	
	DECLARE @sql		NVARCHAR(MAX),
			@cfTable	NVARCHAR(255),
			@segmentNumber INT ,
			@Counter INT,
			@SegTable VARCHAR(max) ;
	SET @Counter = 1;
	SET @SegTable = '';
	SET @sql = N'SELECT ' + @fields + N' FROM @keys K LEFT JOIN mt000 M ON K.ID = M.GUID LEFT JOIN gr000 Mg ON Mg.GUID = M.GroupGUID';
	IF CHARINDEX('__SEG__', @fields) > 0
		BEGIN 
			SELECT  @segmentNumber = max(number) FROM MaterialsSegmentsManagement000
			WHILE (@counter <= @segmentNumber)
			BEGIN 
				SET @SegTable = @SegTable +'
					LEFT JOIN (SELECT MATEL.MaterialId, SEGEL.Code AS ElementCode , SEGEL.Name AS ElementName, SEGEL.LatinName AS ElementLName, MATSEGMAN.Number
								FROM
									MaterialElements000 MATEL 
									INNER JOIN SegmentElements000 SEGEL ON SEGEL.Id = MATEL.ElementId
									INNER JOIN Segments000 SEG on SEG.Id = SEGEL.SegmentId 
									INNER JOIN MaterialsSegmentsManagement000 MATSEGMAN ON MATSEGMAN.SegmentId = SEG.Id
									WHERE MATSEGMAN.Number = ' + CAST(@Counter  AS varchar) + ' ) __SEG__' + CAST(@Counter AS varchar) + ' ON __SEG__' + CAST(@Counter  AS varchar) + '.MaterialId = M.GUID' ;   
				SET @counter = @counter + 1
			END 
			SET @sql = @sql +  @SegTable ;
		 END
	 IF CHARINDEX(N'__CF__', @fields) > 0
		BEGIN
			SET @cfTable = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'mt000');
			SET @sql = @sql + N' LEFT JOIN ' + @cfTable + N' CF ON M.GUID = CF.Orginal_Guid';
		END
	SET @sql = @sql + N' ORDER BY K.Ordinal';
	EXECUTE sp_executesql @sql, N'@keys KeysTable READONLY', @keys;
##################################################################################
CREATE PROCEDURE prcGetBillItemData
	@fields		NVARCHAR(MAX),
	@keyType	INT,
	@keys		KeysTable READONLY
AS
	DECLARE @sql NVARCHAR(MAX),
	@cfTable	NVARCHAR(255);
	DECLARE @IsGCCSystemEnabled INT = dbo.fnOption_GetInt('AmnCfg_EnableGCCTaxSystem', '0');
	DECLARE @IsExciseUsed BIT = (SELECT ISNULL(IsUsed,0) FROM GCCTaxTypes000 WHERE [Type] = 2)
		
	IF @keyType = 0
	BEGIN
		SET @sql = N'SELECT ' + @fields + N' FROM @keys K LEFT JOIN bi000 Bi ON K.ID = Bi.GUID' + 
			N' LEFT JOIN st000 St2 ON Bi.StoreGUID = St2.Guid LEFT JOIN co000 Co2 ON Bi.CostGUID = Co2.Guid';
		IF @IsGCCSystemEnabled = 1
		BEGIN 
			SET @sql += N' LEFT JOIN (SELECT TaxCode, Code + ''-'' + Name AS TaxCodeName, Code + ''-'' + LatinName AS TaxCodeLName FROM GCCTaxCoding000) gccTC ON gccTC.TaxCode = bi.TaxCode';
			IF @IsExciseUsed = 1  
			BEGIN 
				SET @sql += N' LEFT JOIN (SELECT TaxCode, Code + ''-'' + Name AS TaxCodeName, Code + ''-'' + LatinName AS TaxCodeLName FROM GCCTaxCoding000) gccETC ON gccETC.TaxCode = bi.ExciseTaxCode';
			END
		END
	END
	ELSE IF @keyType = 1
	BEGIN
	SET @sql = N'SELECT ' + @fields + N' FROM @keys K LEFT JOIN bi000 Bi ON K.ID = Bi.GUID' + 
		N' LEFT JOIN st000 St2 ON Bi.StoreGUID = St2.Guid LEFT JOIN co000 Co2 ON Bi.CostGUID = Co2.Guid' + 
		N' LEFT JOIN vwBillRelatedField Bu ON Bu.GUID = Bi.ParentGUID LEFT JOIN my000 My ON Bu.CurrencyGuid = My.Guid' + 
		N' LEFT JOIN st000 St ON Bu.StoreGUID = St.Guid LEFT JOIN co000 Co ON Bu.CostGUID = Co.Guid' + 
		N' LEFT JOIN cu000 Cu ON Bu.CustGUID = Cu.Guid' + 
		N' LEFT JOIN br000 Br ON Bu.Branch = Br.Guid' + 
		N' LEFT JOIN bt000 Bt ON Bu.TypeGUID = Bt.Guid' + 
		N' LEFT JOIN pt000 Pt ON Bu.Guid = Pt.RefGUID' +
		N' LEFT JOIN us000 Cus ON Bu.CreateUserGUID = Cus.GUID' +
		N' LEFT JOIN us000 Uus ON Bu.LastUpdateUserGUID = Uus.GUID'+
		N' LEFT JOIN ac000 Acc ON Bu.CustAccGUID = Acc.GUID' + 
		N' LEFT JOIN vwCustAddress CA ON Bu.CustomerAddressGUID = CA.GUID' +
		N' LEFT JOIN LC000 Lc ON Bu.LCGUID = Lc.GUID';

		IF @IsGCCSystemEnabled = 1
		BEGIN 
			SET @sql += N' LEFT JOIN (SELECT TaxCode, Code + ''-'' + Name AS TaxCodeName, Code + ''-'' + LatinName AS TaxCodeLName FROM GCCTaxCoding000) gccTC ON gccTC.TaxCode = bi.TaxCode';
			IF @IsExciseUsed = 1  
			BEGIN 
				SET @sql += N' LEFT JOIN (SELECT TaxCode, Code + ''-'' + Name AS TaxCodeName, Code + ''-'' + LatinName AS TaxCodeLName FROM GCCTaxCoding000) gccETC ON gccETC.TaxCode = bi.ExciseTaxCode';
			END
		END

		IF CHARINDEX(N'__CF__', @fields) > 0
		BEGIN
			SET @cfTable = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'bu000');
			SET @sql = @sql + N' LEFT JOIN ' + @cfTable + N' CF ON Bu.GUID = CF.Orginal_Guid';
		END
	END

	SET @sql = @sql + N' ORDER BY K.Ordinal';

	EXECUTE sp_executesql @sql, N'@keys KeysTable READONLY', @keys;
##################################################################################
CREATE PROCEDURE prcGetBillData
	@fields		NVARCHAR(MAX),
	@keyType	INT,
	@keys		KeysTable READONLY
AS
	DECLARE @sql		NVARCHAR(MAX),
			@cfTable	NVARCHAR(255);

	IF @keyType = 0
	BEGIN
		SET @sql = N'SELECT ' + @fields + N' FROM @keys K LEFT JOIN vwBillRelatedField Bu ON K.ID = Bu.GUID LEFT JOIN my000 My ON Bu.CurrencyGuid = My.Guid' + 
			N' LEFT JOIN st000 St ON Bu.StoreGUID = St.Guid LEFT JOIN co000 Co ON Bu.CostGUID = Co.Guid' + 
			N' LEFT JOIN cu000 Cu ON Bu.CustGUID = Cu.Guid' + 
			N' LEFT JOIN br000 Br ON Bu.Branch = Br.Guid' + 
			N' LEFT JOIN bt000 Bt ON Bu.TypeGUID = Bt.Guid' + 
			N' LEFT JOIN pt000 Pt ON Bu.Guid = Pt.RefGUID' +
			N' LEFT JOIN us000 Cus ON Bu.CreateUserGUID = Cus.GUID' +
			N' LEFT JOIN us000 Uus ON Bu.LastUpdateUserGUID = Uus.GUID' +
			N' LEFT JOIN vwCustAddress CA ON Bu.CustomerAddressGUID = CA.GUID' +
			N' LEFT JOIN vwNt NT ON Bu.CheckTypeGUID = NT.ntGUID' +
			N' LEFT JOIN ac000 Acc ON Bu.CustAccGUID = Acc.GUID' + 
			N' LEFT JOIN LC000 Lc ON Bu.LCGUID = Lc.GUID' +
			N' LEFT JOIN vwObjectRelatedDocument Doc ON Doc.[Guid] = Bu.Guid';

	END

	IF CHARINDEX(N'__CF__', @fields) > 0
	BEGIN
		SET @cfTable = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'bu000');
		SET @sql = @sql + N' LEFT JOIN ' + @cfTable + N' CF ON Bu.GUID = CF.Orginal_Guid';
	END

	SET @sql = @sql + N' ORDER BY K.Ordinal';

	EXECUTE sp_executesql @sql, N'@keys KeysTable READONLY', @keys;
##################################################################################
CREATE PROCEDURE prcGetCostCenterData
	@fields		NVARCHAR(MAX),
	@keyType	INT,
	@keys		KeysTable READONLY
AS
	DECLARE @sql		NVARCHAR(MAX),
			@cfTable	NVARCHAR(255);

	IF @keyType = 0
	BEGIN
		SET @sql = N'SELECT ' + @fields + N' FROM @keys K LEFT JOIN co000 Co ON K.ID = Co.GUID'+
				   N' LEFT JOIN co000 PCo ON PCo.GUID = Co.ParentGUID';
	END

	IF CHARINDEX(N'__CF__', @fields) > 0
	BEGIN
		SET @cfTable = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'co000');
		SET @sql = @sql + N' LEFT JOIN ' + @cfTable + N' CF ON Co.GUID = CF.Orginal_Guid';
	END

	SET @sql = @sql + N' ORDER BY K.Ordinal';

	EXECUTE sp_executesql @sql, N'@keys KeysTable READONLY', @keys;
##################################################################################
CREATE PROCEDURE prcGetAccountData
       @fields       NVARCHAR(MAX),
       @keyType      INT,
       @keys         KeysTable READONLY
AS
	DECLARE @sql		NVARCHAR(MAX),
			@cfTable	NVARCHAR(255);
		
    SET @sql = N'SELECT ' + @fields + N' FROM @keys K LEFT JOIN ac000 A ON K.ID = A.GUID' +
            N' LEFT JOIN ac000 P ON A.ParentGUID = P.GUID' +
            N' LEFT JOIN ac000 F ON A.FinalGUID = F.GUID' +
            N' LEFT JOIN my000 C ON A.CurrencyGUID = C.GUID';

	IF CHARINDEX(N'__CF__', @fields) > 0
	BEGIN
		SET @cfTable = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'ac000');
		SET @sql = @sql + N' LEFT JOIN ' + @cfTable + N' CF ON A.GUID = CF.Orginal_Guid';
	END

	SET @sql = @sql + N' ORDER BY K.Ordinal';

	EXECUTE sp_executesql @sql, N'@keys KeysTable READONLY', @keys;
##################################################################################
CREATE PROCEDURE prcGetOrderData
       @fields       NVARCHAR(MAX),
       @keyType      INT,
       @keys         KeysTable READONLY
AS
	DECLARE @sql		NVARCHAR(MAX),
			@cfTable	NVARCHAR(255);
      
	SET @sql = N'SELECT ' + @fields + N' FROM @keys K LEFT JOIN ORAddInfo000 O ON K.ID = O.ParentGuid' + 
		N' LEFT JOIN bu000 bu on O.ParentGuid = bu.GUID' +
		N' LEFT JOIN bt000 bt on bt.GUID = bu.TypeGUID' +
		N' LEFT JOIN vwCustAddress CA ON Bu.CustomerAddressGUID = CA.GUID' + 
		N' LEFT JOIN vwObjectRelatedDocument Doc ON Doc.[Guid] = O.ParentGuid';
 
	IF CHARINDEX(N'__CF__', @fields) > 0
	BEGIN
		SET @cfTable = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'bu000');
		SET @sql = @sql + N' LEFT JOIN ' + @cfTable + N' CF ON O.ParentGuid = CF.Orginal_Guid';
	END
 
	SET @sql = @sql + N' ORDER BY K.Ordinal';

	EXECUTE sp_executesql @sql, N'@keys KeysTable READONLY', @keys;
##################################################################################
CREATE PROCEDURE prcGetEntryData
	@fields		NVARCHAR(MAX),
	@keyType	INT,
	@keys		KeysTable READONLY
AS
	DECLARE @sql		NVARCHAR(MAX),
			@cfTable	NVARCHAR(255);
 
	SET @sql = N'SELECT ' + @fields + N' FROM @keys K LEFT JOIN vwCEntryRelatedField ce ON K.ID = ce.GUID' +
										 N' LEFT JOIN er000 er ON er.EntryGUID = ce.[GUID]'
										+N' LEFT JOIN vwPyEntryRelatedField py ON py.[GUID] = er.ParentGUID'
										+N' LEFT JOIN et000 et ON et.[Guid] = ce.TypeGUID'
										+N' LEFT JOIN my000 m ON ce.CurrencyGUID=m.GUID '
										+N' LEFT JOIN us000 PCus ON py.CreateUserGUID = PCus.GUID' 
										+N' LEFT JOIN us000 PUus ON py.LastUpdateUserGuid = PUus.GUID'
										+N' LEFT JOIN us000 CCus ON ce.CreateUserGuid = CCus.GUID' 
										+N' LEFT JOIN us000 CUus ON ce.LastUpdateUserGuid = CUus.GUID'
										+N' LEFT JOIN vwObjectRelatedDocument Doc ON Doc.[Guid] = ce.Guid'
										+N' LEFT JOIN vwObjectRelatedDocument pyDoc ON pyDoc.[Guid] = py.Guid';

	IF CHARINDEX(N'__CF__', @fields) > 0
	BEGIN
		SET @cfTable = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'py000');
		SET @sql= @sql + N' LEFT JOIN ' + @cfTable + N' CF ON py.guid = CF.Orginal_Guid';
	END

	SET @sql = @sql + N' ORDER BY K.Ordinal';

	EXECUTE sp_executesql @sql, N'@keys KeysTable READONLY', @keys;
##################################################################################
CREATE PROCEDURE prcGetEntryItemData
	@fields		NVARCHAR(MAX),
	@keyType	INT,
	@keys		KeysTable READONLY
AS
	DECLARE @sql		NVARCHAR(MAX),
			@cfTable	NVARCHAR(255);
	
	IF @keyType = 0
		SET @sql = N'SELECT  ' + @fields + N' FROM @keys K LEFT JOIN en000 en ON K.ID = en.GUID' +
			N' LEFT JOIN my000 enc ON en.CurrencyGUID = enc.GUID' + 
			N' LEFT JOIN co000 co on co.guid = en.costguid' + 
			N' LEFT JOIN ac000 acc on acc.guid = en.ContraAccGUID'+
			N' LEFT JOIN vwCu cu ON cu.cuGUID = en.CustomerGUID ';
	ELSE
	BEGIN
		SET @sql = N'SELECT  ' + @fields + N' FROM @keys K LEFT JOIN en000 en ON K.ID = en.GUID' 
				+N' LEFT JOIN vwCEntryRelatedField ce ON en.ParentGUID = ce.[GUID]'
				+N' LEFT JOIN er000 er ON er.EntryGUID = ce.[GUID]'
				+N' LEFT JOIN vwPyEntryRelatedField py ON py.[GUID] = er.ParentGUID'
				+N' LEFT JOIN et000 et ON et.[Guid] = ce.TypeGUID'
				+N' LEFT JOIN my000 enC ON en.CurrencyGUID = enC.GUID' 
				+N' LEFT JOIN co000 co on co.guid = en.costguid'
				+N' LEFT JOIN ac000 acc on acc.guid = en.ContraAccGUID' 
				+N' LEFT JOIN my000 m ON ce.CurrencyGUID = m.GUID'
				+N' LEFT JOIN vwCu cu ON cu.cuGUID = en.CustomerGUID'
				+N' LEFT JOIN us000 PCus ON py.CreateUserGUID = PCus.GUID' 
				+N' LEFT JOIN us000 PUus ON py.LastUpdateUserGuid = PUus.GUID'
				+N' LEFT JOIN us000 CCus ON ce.CreateUserGuid = CCus.GUID' 
				+N' LEFT JOIN us000 CUus ON ce.LastUpdateUserGuid = CUus.GUID'
				+N' LEFT JOIN vwObjectRelatedDocument Doc ON Doc.[Guid] = ce.Guid'
				+N' LEFT JOIN vwObjectRelatedDocument pyDoc ON pyDoc.[Guid] = py.Guid';


		IF CHARINDEX(N'__CF__', @fields) > 0
		BEGIN
			SET @cfTable = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'py000');
			SET @sql = @sql + N' LEFT JOIN ' + @cfTable + N' CF ON py.guid = CF.Orginal_Guid';
		END
	END
	
	SET @sql = @sql + N' ORDER BY K.Ordinal';
	EXECUTE sp_executesql @sql, N'@keys KeysTable READONLY', @keys;
##################################################################################
CREATE PROCEDURE prcGetPackinglistDataData
       @fields       NVARCHAR(MAX),
       @keyType      INT,
       @keys         KeysTable READONLY
AS
	DECLARE @sql		NVARCHAR(MAX),
			@cfTable	NVARCHAR(255);
      
	SET @sql = N'SELECT ' + @fields + N' FROM @keys K LEFT JOIN packingLists000 pk ON K.ID = pk.guid';
 
	IF CHARINDEX(N'__CF__', @fields) > 0
	BEGIN
		SET @cfTable = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'packingLists000');
		SET @sql = @sql + N' LEFT JOIN ' + @cfTable + N' CF ON pk.guid = CF.Orginal_Guid';
	END
 
	SET @sql = @sql + N' ORDER BY K.Ordinal';

	EXECUTE sp_executesql @sql, N'@keys KeysTable READONLY', @keys;
##################################################################################
CREATE PROCEDURE prcGetNotePaperData
       @fields       NVARCHAR(MAX),
       @keyType      INT,
       @keys         KeysTable READONLY
AS
	DECLARE 
		@sql		NVARCHAR(MAX),
	    @cfTable	NVARCHAR(255);
     
    SET @sql = N'SELECT ' + @fields + N' FROM @keys K LEFT JOIN ch000 Ch ON K.ID = Ch.GUID ' +
		N' LEFT JOIN ac000 A ON Ch.AccountGUID = A.GUID' +
		N' LEFT JOIN ac000 A2 ON Ch.Account2GUID = A2.GUID' +
		N' LEFT JOIN cu000 CU ON Ch.CustomerGUID = CU.GUID' +
		N' LEFT JOIN ac000 EA ON Ch.EndorseAccGUID = EA.GUID' +
		N' LEFT JOIN cu000 EC ON Ch.EndorseCustGUID = EC.GUID' +
		N' LEFT JOIN co000 Co ON Ch.Cost1GUID = Co.GUID' +
		N' LEFT JOIN co000 Co2 ON Ch.Cost2GUID = Co2.GUID' +
		N' LEFT JOIN Bank000 B ON Ch.BankGUID = B.GUID' + 
		N' LEFT JOIN nt000 N ON Ch.TypeGUID = N.GUID' +
		N' LEFT JOIN vwObjectRelatedDocument Doc ON Doc.[Guid] = Ch.Guid';
		
	IF CHARINDEX(N'__CF__', @fields) > 0
	BEGIN
		SET @cfTable = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'ch000');
		SET @sql = @sql + N' LEFT JOIN ' + @cfTable + N' CF ON Ch.GUID = CF.Orginal_Guid';
	END
	SET @sql = @sql + N' ORDER BY K.Ordinal';
	EXECUTE sp_executesql @sql, N'@keys KeysTable READONLY', @keys;
##################################################################################
CREATE PROCEDURE prcGetOrderItemData
       @fields       NVARCHAR(MAX),
       @keyType      INT,
       @keys         KeysTable READONLY
AS
	DECLARE @sql		NVARCHAR(MAX),
			@cfTable	NVARCHAR(255);
      
	IF @keyType = 0
	BEGIN
	SET @sql = N'SELECT ' + @fields + N' FROM @keys K LEFT JOIN bi000 bi ON K.ID = bi.GUID ' +
		N'LEFT JOIN st000 st ON bi.StoreGUID = st.Guid ' + 
		N'LEFT JOIN co000 co on bi.CostGUID = co.GUID ';
	END
	ELSE IF @keyType = 1
	BEGIN
	 SET @sql = N'SELECT ' + @fields + N' FROM @keys K LEFT JOIN bi000 bi ON K.ID = bi.GUID ' +
	     N' LEFT JOIN bu000 bu on bi.ParentGuid = bu.GUID' +
		 N' LEFT JOIN ORAddInfo000 O ON bu.GUID = O.ParentGuid' + 
		 N' LEFT JOIN bt000 bt on bt.GUID = bu.TypeGUID';

		 IF CHARINDEX(N'__CF__', @fields) > 0
		BEGIN
			SET @cfTable = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'bu000');
			SET @sql = @sql + N' LEFT JOIN ' + @cfTable + N' CF ON O.ParentGuid = CF.Orginal_Guid';
		END
	END
	SET @sql = @sql + N' ORDER BY K.Ordinal';

	EXECUTE sp_executesql @sql, N'@keys KeysTable READONLY', @keys;
##################################################################################
CREATE PROCEDURE prcGetEmployeeData
       @fields       NVARCHAR(MAX),
       @keyType      INT,
       @keys         KeysTable READONLY
AS
	DECLARE @sql   NVARCHAR(MAX);
      
    SET @sql = N'SELECT ' + @fields + N' FROM @keys K LEFT JOIN AssetEmployee000 EM ON K.ID = EM.GUID ';
 
	SET @sql = @sql + N' ORDER BY K.Ordinal';

	EXECUTE sp_executesql @sql, N'@keys KeysTable READONLY', @keys;
##################################################################################
CREATE VIEW vwBillRelatedField
AS 
	SELECT 
		Number As BillNumber, 
		Cust_Name, 
		Date, 
		CurrencyVal, 
		Notes, 
		Total, 
		PayType,
		TotalDisc,
		TotalExtra,
		ItemsDisc,
		BonusDisc, 
		FirstPay, 
		Profits, 
		IsPosted, 
		Security, 
		Vendor, 
		SalesManPtr, 
		Branch, 
		VAT, 
		GUID, 
		TypeGUID, 
		CustGUID, 
		CurrencyGUID, 
		StoreGUID, 
		CustAccGUID, 
		MatAccGUID, 
		ItemsDiscAccGUID, 
		BonusDiscAccGUID, 
		FPayAccGUID, 
		CostGUID,
		UserGUID, 
		CheckTypeGUID, 
		TextFld1, 
		TextFld2, 
		TextFld3, 
		TextFld4, 
		RecState, 
		ItemsExtra, 
		ItemsExtraAccGUID, 
		CostAccGUID, 
		StockAccGUID, 
		VATAccGUID, 
		BonusAccGUID, 
		BonusContraAccGUID, 
		IsPrinted, 
		IsGeneratedByPocket, 
		CalcBillVat, 
		TotalSalesTax, 
		TotalExciseTax, 
		RefundedBillGUID, 
		IsTaxPayedByAgent, 
		LCGUID, 
		LCType, 
		ReversChargeReturn,
		ReturendBillNumber, 
		CASE  
			WHEN ReturendBillDate = '1980-01-01' THEN NULL 
			ELSE ReturendBillDate END 
		AS ReturendBillDate, 
		ImportViaCustoms, 
		TotalReversChargeTax, 
		TotalPurchaseVal, 
		CreateUserGUID, 
		CreateDate, 
		LastUpdateUserGUID, 
		CASE 
			WHEN LastUpdateDate = '1980-01-01' THEN NULL 
			ELSE LastUpdateDate END
		AS LastUpdateDate, 
		CASE (CONVERT(VARCHAR(8), CreateDate, 108)) 
			WHEN '00:00:00' THEN '' 
			ELSE CONVERT(VARCHAR(8), CreateDate, 108) END 
		AS CreateTime, 
		CASE (CONVERT(VARCHAR(8), LastUpdateDate, 108)) 
			WHEN '00:00:00' THEN '' 
			ELSE CONVERT(VARCHAR(8), LastUpdateDate, 108) END 
		AS LastUpdateTime,
		GCCLocationGUID,
		CustomerAddressGUID
	FROM dbo.bu000
##################################################################################
CREATE VIEW vwCEntryRelatedField 
AS 
	SELECT 
		Type,
		Number,
		Date,
		Debit,
		Credit,
		Notes,
		CurrencyVal,
		IsPosted,
		State,
		Security,
		Num1,
		Num2,
		Branch,
		GUID,
		CurrencyGUID,
		TypeGUID,
		IsPrinted,
		PostDate,
		CreateUserGUID,
		CASE 
			WHEN CreateDate = '1980-01-01' THEN NULL 
			ELSE CreateDate END
		AS CreateDate,
		LastUpdateUserGUID,
		CASE 
			WHEN LastUpdateDate = '1980-01-01' THEN NULL 
			ELSE LastUpdateDate END
		AS LastUpdateDate, 
	    CASE(CONVERT(VARCHAR(8), CreateDate, 108))
			WHEN '00:00:00' THEN ''
			ELSE CONVERT(VARCHAR(8), CreateDate, 108) END 
		AS CreateTime,
	    CASE(CONVERT(VARCHAR(8), LastUpdateDate, 108))
			WHEN '00:00:00' THEN ''
			ELSE CONVERT(VARCHAR(8), LastUpdateDate, 108) END
	    AS LastUpdateTime
    FROM ce000
##########################################################
CREATE VIEW vwPyEntryRelatedField
AS 
	SELECT 
		Date,
		Notes,
		CurrencyVal,
		Skip,
		Security,
		Num1,
		Num2,
		GUID,
		TypeGUID,
		AccountGUID,
		CurrencyGUID,
		BranchGUID,
		CreateUserGUID,
		CASE 
			WHEN CreateDate = '1980-01-01' THEN NULL 
			ELSE CreateDate END
		AS CreateDate, 
		LastUpdateUserGUID,
		CASE 
			WHEN LastUpdateDate = '1980-01-01' THEN NULL 
			ELSE LastUpdateDate END
		AS LastUpdateDate, 
	    CASE(CONVERT(VARCHAR(8), CreateDate, 108))
			WHEN '00:00:00' THEN ''
			ELSE CONVERT(VARCHAR(8), CreateDate, 108) END 
		AS CreateTime,
	    CASE(CONVERT(VARCHAR(8), LastUpdateDate, 108))
			WHEN '00:00:00' THEN ''
			ELSE CONVERT(VARCHAR(8), LastUpdateDate, 108) END
	    AS LastUpdateTime
    FROM py000
##########################################################
CREATE PROCEDURE prcGetPOSSDSpecialOfferData
       @fields       NVARCHAR(MAX),
       @keyType      INT,
       @keys         KeysTable READONLY
AS
	DECLARE @sql   NVARCHAR(MAX);
      
   
    SET @sql = N'SELECT ' + @fields + N' FROM @keys K LEFT JOIN POSSDSpecialOffer000 specialOffer ON K.ID = specialOffer.GUID'+
	N' INNER JOIN vwPOSSDSpecialOfferFields vwSO ON specialOffer.GUID  = vwSO.GUID';
 
	SET @sql = @sql + N' ORDER BY K.Ordinal';

	EXECUTE sp_executesql @sql, N'@keys KeysTable READONLY', @keys;
##################################################################################
CREATE PROCEDURE prcGetPOSSDStationData
       @fields       NVARCHAR(MAX),
       @keyType      INT,
       @keys         KeysTable READONLY
AS
	DECLARE @sql   NVARCHAR(MAX);
      
    SET @sql = N'SELECT ' + @fields + N' FROM @keys K LEFT JOIN  POSSDStation000  station  ON K.ID = station.GUID '+
	N'  INNER JOIN vwPOSSDStationInfoFields InfoFields ON InfoFields.StationGUID = station.GUID
		INNER JOIN POSSDShift000 sh ON sh.StationGUID = station.GUID
		INNER JOIN POSSDShiftDetail000 shiftDetails ON shiftDetails.ShiftGUID = sh.GUID
		INNER JOIN POSSDTicket000 ticket ON Ticket.ShiftGUID = shiftDetails.ShiftGUID
		INNER JOIN POSSDEmployee000 employee ON employee.GUID =  sh.EmployeeGUID
	    LEFT JOIN POSSDSalesman000 salesman ON salesman.GUID = Ticket.SalesmanGUID
		LEFT JOIN CO000 costCenter ON costCenter.GUID = salesman.CostCenterGUID ';
 
	SET @sql = @sql + N' ORDER BY K.Ordinal';

	EXECUTE sp_executesql @sql, N'@keys KeysTable READONLY', @keys;
##################################################################################
CREATE PROCEDURE prcGetPOSSDOrderData
       @fields       NVARCHAR(MAX),
       @keyType      INT,
       @keys         KeysTable READONLY
AS

	DECLARE @sql   NVARCHAR(MAX);
    SET @sql = N' SELECT ' + @fields + 
			   N' FROM  @keys K LEFT JOIN dbo.fnPOSSD_Order_GetRelatedFields() fnOrder ON K.ID = fnOrder.OrderGuid ' +
			   N' LEFT JOIN ac000 DownPaymentAcc ON DownPaymentAcc.[GUID] = fnOrder.DownPaymentAccGuid ' +
			   N' LEFT JOIN ac000 DriverPaymentAcc ON DriverPaymentAcc.[GUID] = fnOrder.DriverReceiveAccGuid ' +
			   N' LEFT JOIN vwCustAddress vwCA ON vwCA.[GUID] = fnOrder.CustomerAddressGuid ' +
			   N' ORDER BY K.Ordinal'
	
	EXECUTE sp_executesql @sql, N'@keys KeysTable READONLY', @keys;
##################################################################################
CREATE VIEW vwObjectRelatedDocument
AS
	SELECT DISTINCT 
		dbo.TryConvertUniqueidentifier([Value]) [Guid]
	FROM 
		DMSTblDocumentFieldValue
	WHERE
		dbo.TryConvertUniqueidentifier([Value]) IS NOT NULL
##################################################################################
CREATE PROCEDURE prcGetPOSLoyaltyCardData
       @fields       NVARCHAR(MAX),
       @keyType      INT,
       @keys         KeysTable READONLY
AS
	DECLARE @sql   NVARCHAR(MAX);
      
    SET @sql =	N'SELECT ' + @fields + N' FROM @keys K LEFT JOIN POSLoyaltyCard000 lc ON K.ID = lc.GUID ' +
				N'INNER JOIN POSLoyaltyCardClassification000 lcc ON LCC.GUID = LC.ClassificationGUID ';
 
	SET @sql = @sql + N' ORDER BY K.Ordinal';

	EXECUTE sp_executesql @sql, N'@keys KeysTable READONLY', @keys;
##################################################################################
#END