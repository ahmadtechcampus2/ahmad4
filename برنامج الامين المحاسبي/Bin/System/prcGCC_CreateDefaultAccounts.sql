######################################################### 
CREATE PROC prcGCC_CreateDefaultAccounts
	@AccGUID UNIQUEIDENTIFIER, 
	@country [INT] = 0 -- 0: Emirates, 1: SAUDI
AS 
	SET NOCOUNT ON 

	IF (ISNULL(@AccGUID, 0x0) = 0x0) OR NOT EXISTS(SELECT * FROM ac000 WHERE GUID = @AccGUID) 
		RETURN 
	
	IF EXISTS(SELECT * FROM ac000 WHERE ParentGUID = @AccGUID)
		RETURN 

	IF EXISTS(SELECT * FROM GCCTaxAccounts000)
		RETURN 

	IF EXISTS(SELECT * FROM GCCCustLocations000 where VATAccGUID != 0x0 OR ReturnAccGUID != 0x0)
		RETURN 
	
	SELECT * INTO #ac FROM ac000 WHERE GUID = @AccGUID
	SELECT TOP 0 * INTO #accounts FROM ac000 WHERE GUID = @AccGUID

	DECLARE @AccCode NVARCHAR(500)
	SELECT @AccCode = Code FROM ac000 WHERE GUID = @AccGUID

	DECLARE @Number INT 
	SET @Number = ISNULL((SELECT MAX(Number) FROM ac000), 0) + 1

	DECLARE 
		@G1 UNIQUEIDENTIFIER,
		@G11 UNIQUEIDENTIFIER,
		@G12 UNIQUEIDENTIFIER,
		@G13 UNIQUEIDENTIFIER,
		@G2 UNIQUEIDENTIFIER,
		@G3 UNIQUEIDENTIFIER

	SET @G1 = NEWID()
	SET @G11 = NEWID()
	SET @G12 = NEWID()
	SET @G13 = NEWID()
	SET @G2 = NEWID()
	SET @G3 = NEWID()

	-----------------------------------------
	UPDATE #ac 
	SET Number = @Number, GUID = @G1, ParentGUID = @AccGUID, Code = @AccCode + N'1', Name = N'ضريبة القيمة المضافة', LatinName = N'VAT Tax Accounts'
	INSERT INTO #accounts SELECT * FROM #ac
	SET @Number = @Number + 1

	UPDATE #ac 
	SET Number = @Number, GUID = @G2, ParentGUID = @AccGUID, Code = @AccCode + N'2', Name = N'الضريبة الانتقائية', LatinName = N'Excise Tax Accounts'
	INSERT INTO #accounts SELECT * FROM #ac
	SET @Number = @Number + 1

	UPDATE #ac 
	SET Number = @Number, GUID = @G3, ParentGUID = @AccGUID, Code = @AccCode + N'3', Name = N'صافي الضرائب المستحقة', LatinName = N'Net Tax Accounts'
	INSERT INTO #accounts SELECT * FROM #ac
	SET @Number = @Number + 1
	-----------------------------------------

	-----------------------------------------
	UPDATE #ac 
	SET Number = @Number, GUID = @G11, ParentGUID = @G1, Code = @AccCode + N'11', Name = N'حسابات ضريبة القيمة المضافة', LatinName = N'VAT Location Accounts'
	INSERT INTO #accounts SELECT * FROM #ac
	SET @Number = @Number + 1

	UPDATE #ac 
	SET Number = @Number, GUID = @G12, ParentGUID = @G1, Code = @AccCode + N'12', Name = N'حسابات استرداد ضريبة القيمة المضافة', LatinName = N'Refund VAT Location Accounts'
	INSERT INTO #accounts SELECT * FROM #ac
	SET @Number = @Number + 1

	UPDATE #ac 
	SET Number = @Number, GUID = @G13, ParentGUID = @G1, Code = @AccCode + N'13', Name = N'الضريبة العكسية', LatinName = N'Reverse Charges Accounts'
	INSERT INTO #accounts SELECT * FROM #ac
	SET @Number = @Number + 1
	-----------------------------------------

	DECLARE @class INT 
	SET @class = 0
	-----------------------------------------
	IF @country = 0
	BEGIN
		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G11, Code = @AccCode + N'1101', Name = N'ضريبة القيمة المضافة أبو ظبي', LatinName = N'Abu Dhabi VAT', Num1 = 1
		INSERT INTO #accounts SELECT * FROM #ac
		SET @Number = @Number + 1
		UPDATE GCCCustLocations000 SET VATAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name = N'أبو ظبي'

		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G11, Code = @AccCode + N'1102', Name = N'ضريبة القيمة المضافة دبي', LatinName = N'Dubai VAT', Num1 = 2
		INSERT INTO #accounts SELECT * FROM #ac
		SET @Number = @Number + 1
		UPDATE GCCCustLocations000 SET VATAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name = N'دبي'

		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G11, Code = @AccCode + N'1103', Name = N'ضريبة القيمة المضافة الشارقة', LatinName = N'Sharjah VAT', Num1 = 3
		INSERT INTO #accounts SELECT * FROM #ac
		SET @Number = @Number + 1
		UPDATE GCCCustLocations000 SET VATAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name = N'الشارقة'

		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G11, Code = @AccCode + N'1104', Name = N'ضريبة القيمة المضافة عجمان', LatinName = N'Ajman VAT', Num1 = 4
		INSERT INTO #accounts SELECT * FROM #ac
		SET @Number = @Number + 1
		UPDATE GCCCustLocations000 SET VATAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name = N'عجمان'

		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G11, Code = @AccCode + N'1105', Name = N'ضريبة القيمة المضافة أم القيوين', LatinName = N'Um elkiwin VAT', Num1 = 5
		INSERT INTO #accounts SELECT * FROM #ac
		SET @Number = @Number + 1
		UPDATE GCCCustLocations000 SET VATAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name = N'أم القيوين'

		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G11, Code = @AccCode + N'1106', Name = N'ضريبة القيمة المضافة رأس الخيمة', LatinName = N'Ras Alkhaimeh VAT', Num1 = 6
		INSERT INTO #accounts SELECT * FROM #ac
		SET @Number = @Number + 1
		UPDATE GCCCustLocations000 SET VATAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name = N'رأس الخيمة'

		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G11, Code = @AccCode + N'1107', Name = N'ضريبة القيمة المضافة الفجيرة', LatinName = N'Alfujairah VAT', Num1 = 7
		INSERT INTO #accounts SELECT * FROM #ac
		SET @Number = @Number + 1
		UPDATE GCCCustLocations000 SET VATAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name = N'الفجيرة'

		SET @class = 8
	END ELSE BEGIN 
		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G11, Code = @AccCode + N'1101', Name = N'ضريبة القيمة المضافة السعودية', LatinName = N'Saudia VAT', Num1 = 1
		INSERT INTO #accounts SELECT * FROM #ac
		SET @Number = @Number + 1
		UPDATE GCCCustLocations000 SET VATAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name = N'المملكة العربية السعودية'
		SET @class = 2
	END 

	UPDATE #ac 
	SET Number = @Number, GUID = NEWID(), ParentGUID = @G11, Code = @AccCode + N'1111', Name = N'ضريبة القيمة المضافة البحرين', LatinName = N'Bahrain VAT', Num1 = @class
	INSERT INTO #accounts SELECT * FROM #ac
	SET @Number = @Number + 1
	UPDATE GCCCustLocations000 SET VATAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name like '%البحرين%'
	SET @class = @class + 1

	UPDATE #ac 
	SET Number = @Number, GUID = NEWID(), ParentGUID = @G11, Code = @AccCode + N'1112', Name = N'ضريبة القيمة المضافة الكويت', LatinName = N'Kuwait VAT', Num1 = @class
	INSERT INTO #accounts SELECT * FROM #ac
	SET @Number = @Number + 1
	UPDATE GCCCustLocations000 SET VATAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name like '%الكويت%'
	SET @class = @class + 1

	UPDATE #ac 
	SET Number = @Number, GUID = NEWID(), ParentGUID = @G11, Code = @AccCode + N'1113', Name = N'ضريبة القيمة المضافة قطر', LatinName = N'Qatar VAT', Num1 = @class
	INSERT INTO #accounts SELECT * FROM #ac
	SET @Number = @Number + 1
	UPDATE GCCCustLocations000 SET VATAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name like '%قطر%'
	SET @class = @class + 1

	UPDATE #ac 
	SET Number = @Number, GUID = NEWID(), ParentGUID = @G11, Code = @AccCode + N'1114', Name = N'ضريبة القيمة المضافة عمان', LatinName = N'Oman VAT', Num1 = @class
	INSERT INTO #accounts SELECT * FROM #ac
	SET @Number = @Number + 1
	UPDATE GCCCustLocations000 SET VATAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name like '%عمان%'
	SET @class = @class + 1

	IF @country = 0
	BEGIN 
		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G11, Code = @AccCode + N'1115', Name = N'ضريبة القيمة المضافة السعودية', LatinName = N'Saudia VAT', Num1 = @class
		UPDATE GCCCustLocations000 SET VATAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name like '%السعودية%'
	END ELSE BEGIN 
		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G11, Code = @AccCode + N'1115', Name = N'ضريبة القيمة المضافة الإمارات العربية المتحدة', LatinName = N'UAE VAT', Num1 = @class
		UPDATE GCCCustLocations000 SET VATAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name like '%الإمارات%'
	END		
	INSERT INTO #accounts SELECT * FROM #ac
	SET @Number = @Number + 1
	SET @class = @class + 1

	UPDATE #ac 
	SET Number = @Number, GUID = NEWID(), ParentGUID = @G11, Code = @AccCode + N'1121', Name = N'ضريبة القيمة المضافة محلي غير مشترك', LatinName = N'LNR VAT', Num1 = @class
	INSERT INTO #accounts SELECT * FROM #ac
	UPDATE GCCCustLocations000 SET VATAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name = N'محلي غير مشترك'
	SET @Number = @Number + 1
	SET @class = @class + 1

	UPDATE #ac 
	SET Number = @Number, GUID = NEWID(), ParentGUID = @G11, Code = @AccCode + N'1122', Name = N'ضريبة القيمة المضافة خارجي', LatinName = N'Outside GCC VAT', Num1 = @class
	INSERT INTO #accounts SELECT * FROM #ac
	UPDATE GCCCustLocations000 SET VATAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name like '%خارج منطقة اتفاقية%'
	SET @Number = @Number + 1
	SET @class = @class + 1
	-----------------------------------------

	IF @country = 0
	BEGIN 
		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G12, Code = @AccCode + N'1201', Name = N'استرداد ضريبة القيمة المضافة أبو ظبي', LatinName = N'Abu Dhabi Refund VAT', Num1 = 1
		INSERT INTO #accounts SELECT * FROM #ac
		UPDATE GCCCustLocations000 SET ReturnAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name = N'أبو ظبي'
		SET @Number = @Number + 1

		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G12, Code = @AccCode + N'1202', Name = N'استرداد ضريبة القيمة المضافة دبي', LatinName = N'Dubai Refund VAT', Num1 = 2
		INSERT INTO #accounts SELECT * FROM #ac
		UPDATE GCCCustLocations000 SET ReturnAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name = N'دبي'
		SET @Number = @Number + 1

		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G12, Code = @AccCode + N'1203', Name = N'استرداد ضريبة القيمة المضافة الشارقة', LatinName = N'Sharjah Refund VAT', Num1 = 3
		INSERT INTO #accounts SELECT * FROM #ac
		UPDATE GCCCustLocations000 SET ReturnAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name = N'الشارقة'
		SET @Number = @Number + 1

		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G12, Code = @AccCode + N'1204', Name = N'استرداد ضريبة القيمة المضافة عجمان', LatinName = N'Ajman Refund VAT', Num1 = 4
		INSERT INTO #accounts SELECT * FROM #ac
		UPDATE GCCCustLocations000 SET ReturnAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name = N'عجمان'
		SET @Number = @Number + 1

		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G12, Code = @AccCode + N'1205', Name = N'استرداد ضريبة القيمة المضافة أم القيوين', LatinName = N'Um elkiwin Refund VAT', Num1 = 5
		INSERT INTO #accounts SELECT * FROM #ac
		UPDATE GCCCustLocations000 SET ReturnAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name = N'أم القيوين'
		SET @Number = @Number + 1

		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G12, Code = @AccCode + N'1206', Name = N'استرداد ضريبة القيمة المضافة رأس الخيمة', LatinName = N'Ras Alkhaimeh Refund VAT', Num1 = 6
		INSERT INTO #accounts SELECT * FROM #ac
		UPDATE GCCCustLocations000 SET ReturnAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name = N'رأس الخيمة'
		SET @Number = @Number + 1

		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G12, Code = @AccCode + N'1207', Name = N'استرداد ضريبة القيمة المضافة الفجيرة', LatinName = N'Alfujairah Refund VAT', Num1 = 7
		INSERT INTO #accounts SELECT * FROM #ac
		UPDATE GCCCustLocations000 SET ReturnAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name = N'الفجيرة'
		SET @Number = @Number + 1
		SET @class = 8
	END ELSE BEGIN 
		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G12, Code = @AccCode + N'1201', Name = N'استرداد ضريبة القيمة المضافة السعودية', LatinName = N'Saudia Refund VAT', Num1 = 1
		INSERT INTO #accounts SELECT * FROM #ac
		UPDATE GCCCustLocations000 SET ReturnAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name like '%السعودية%'
		SET @Number = @Number + 1
		SET @class = 2
	END 

	UPDATE #ac 
	SET Number = @Number, GUID = NEWID(), ParentGUID = @G12, Code = @AccCode + N'1211', Name = N'استرداد ضريبة القيمة المضافة البحرين', LatinName = N'Bahrain Refund VAT', Num1 = @class  
	INSERT INTO #accounts SELECT * FROM #ac
	UPDATE GCCCustLocations000 SET ReturnAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name like '%البحرين%'
	SET @Number = @Number + 1
	SET @class = @class + 1

	UPDATE #ac 
	SET Number = @Number, GUID = NEWID(), ParentGUID = @G12, Code = @AccCode + N'1212', Name = N'استرداد ضريبة القيمة المضافة الكويت', LatinName = N'Kuwait Refund VAT', Num1 = @class  
	INSERT INTO #accounts SELECT * FROM #ac
	UPDATE GCCCustLocations000 SET ReturnAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name like '%الكويت%'
	SET @Number = @Number + 1
	SET @class = @class + 1

	UPDATE #ac 
	SET Number = @Number, GUID = NEWID(), ParentGUID = @G12, Code = @AccCode + N'1213', Name = N'استرداد ضريبة القيمة المضافة قطر', LatinName = N'Qatar Refund VAT', Num1 = @class  
	INSERT INTO #accounts SELECT * FROM #ac
	UPDATE GCCCustLocations000 SET ReturnAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name like '%قطر%'
	SET @Number = @Number + 1
	SET @class = @class + 1

	UPDATE #ac 
	SET Number = @Number, GUID = NEWID(), ParentGUID = @G12, Code = @AccCode + N'1214', Name = N'استرداد ضريبة القيمة المضافة عمان', LatinName = N'Oman Refund VAT', Num1 = @class  
	INSERT INTO #accounts SELECT * FROM #ac
	UPDATE GCCCustLocations000 SET ReturnAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name like '%عمان%'
	SET @Number = @Number + 1
	SET @class = @class + 1

	IF @country = 0
	BEGIN 
		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G12, Code = @AccCode + N'1215', Name = N'استرداد ضريبة القيمة المضافة السعودية', LatinName = N'Saudia Refund VAT', Num1 = @class  
		UPDATE GCCCustLocations000 SET ReturnAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name like '%السعودية%'
	END ELSE BEGIN 
		UPDATE #ac 
		SET Number = @Number, GUID = NEWID(), ParentGUID = @G12, Code = @AccCode + N'1215', Name = N'استرداد ضريبة القيمة المضافة الإمارات العربية المتحدة', LatinName = N'UAE Refund VAT', Num1 = @class  
		UPDATE GCCCustLocations000 SET ReturnAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name like '%الإمارات%'
	END		
	INSERT INTO #accounts SELECT * FROM #ac
	SET @Number = @Number + 1
	SET @class = @class + 1

	UPDATE #ac 
	SET Number = @Number, GUID = NEWID(), ParentGUID = @G12, Code = @AccCode + N'1221', Name = N'استرداد ضريبة القيمة المضافة محلي غير مشترك', LatinName = N'LNR Refund VAT', Num1 = @class  
	INSERT INTO #accounts SELECT * FROM #ac
	UPDATE GCCCustLocations000 SET ReturnAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name like '%محلي غير مشترك%'
	SET @Number = @Number + 1
	SET @class = @class + 1

	UPDATE #ac 
	SET Number = @Number, GUID = NEWID(), ParentGUID = @G12, Code = @AccCode + N'1222', Name = N'استرداد ضريبة القيمة المضافة خارجي', LatinName = N'Outside GCC Refund VAT', Num1 = @class  
	INSERT INTO #accounts SELECT * FROM #ac
	UPDATE GCCCustLocations000 SET ReturnAccGUID = (SELECT TOP 1 GUID FROM #ac) WHERE Name like '%خارج منطقة اتفاقية%'
	SET @Number = @Number + 1
	SET @class = @class + 1
	-----------------------------------------

	-----------------------------------------
	SET @class = 1
	UPDATE #ac 
	SET Number = @Number, GUID = NEWID(), ParentGUID = @G13, Code = @AccCode + N'131', Name = N'حساب الضريبة العكسية', LatinName = N'Reverse Charges Tax', Num1 = 101
	INSERT INTO #accounts SELECT * FROM #ac
	SET @Number = @Number + 1
	
	UPDATE #ac 
	SET Number = @Number, GUID = NEWID(), ParentGUID = @G13, Code = @AccCode + N'132', Name = N'استرداد الضريبة العكسية', LatinName = N'Reverse Charges Refund Tax', Num1 = 102
	INSERT INTO #accounts SELECT * FROM #ac
	SET @Number = @Number + 1

	UPDATE #ac 
	SET Number = @Number, GUID = NEWID(), ParentGUID = @G13, Code = @AccCode + N'133', Name = N'مقابل الضريبة العكسية', LatinName = N'Reverse Charges Contra Tax'
	INSERT INTO #accounts SELECT * FROM #ac
	SET @Number = @Number + 1
	-----------------------------------------

	-----------------------------------------
	UPDATE #ac 
	SET Number = @Number, GUID = NEWID(), ParentGUID = @G2, Code = @AccCode + N'21', Name = N'حساب الضريبة الانتقائية', LatinName = N'Excise Tax', Num1 = 201
	INSERT INTO #accounts SELECT * FROM #ac
	SET @Number = @Number + 1
	
	UPDATE #ac 
	SET Number = @Number, GUID = NEWID(), ParentGUID = @G2, Code = @AccCode + N'22', Name = N'استرداد الضريبة الانتقائية', LatinName = N'Refund Excise Tax', Num1 = 202
	INSERT INTO #accounts SELECT * FROM #ac
	SET @Number = @Number + 1
	-----------------------------------------

	-----------------------------------------
	UPDATE #ac 
	SET Number = @Number, GUID = NEWID(), ParentGUID = @G3, Code = @AccCode + N'31', Name = N'صافي ضريبة القيمة المضافة المستحق', LatinName = N'Net VAT Tax', Num1 = 301
	INSERT INTO #accounts SELECT * FROM #ac
	SET @Number = @Number + 1
	
	UPDATE #ac 
	SET Number = @Number, GUID = NEWID(), ParentGUID = @G3, Code = @AccCode + N'32', Name = N'صافي الضريبة الانتقائية المستحق', LatinName = N'Net Excise Tax', Num1 = 302
	INSERT INTO #accounts SELECT * FROM #ac
	SET @Number = @Number + 1
	-----------------------------------------

	INSERT INTO ac000 SELECT * FROM #accounts

	DELETE GCCTaxAccounts000

	INSERT INTO GCCTaxAccounts000 (Number, GUID, VATAccGUID, ReturnAccGUID, ReverseChargesAccGUID, ReturnReverseChargesAccGUID, ExciseTaxAccGUID, ReturnExciseTaxAccGUID)
	SELECT Num1, NEWID(), GUID, 0x0, 0x0, 0x0, 0x0, 0x0 FROM #accounts WHERE ParentGUID = @G11 ORDER BY Number

	UPDATE ta
	SET ReturnAccGUID = a.GUID 
	FROM 
		#accounts a 
		INNER JOIN GCCTaxAccounts000 ta ON ta.Number = a.Num1 AND a.ParentGUID = @G12

	UPDATE GCCTaxAccounts000
	SET 
		ReverseChargesAccGUID = (SELECT TOP 1 GUID FROM #accounts WHERE Num1 = 101),
		ReturnReverseChargesAccGUID = (SELECT TOP 1 GUID FROM #accounts WHERE Num1 = 102),
		ExciseTaxAccGUID = (SELECT TOP 1 GUID FROM #accounts WHERE Num1 = 201),
		ReturnExciseTaxAccGUID = (SELECT TOP 1 GUID FROM #accounts WHERE Num1 = 202)
	WHERE Number = 1

	UPDATE GCCTaxSettings000 
	SET 
		NetVATAccGUID = (SELECT TOP 1 GUID FROM #accounts WHERE Num1 = 301),
		NetExciseAccGUID = (SELECT TOP 1 GUID FROM #accounts WHERE Num1 = 302)
#########################################################
#END
