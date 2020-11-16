######################################################### 
CREATE PROC prcGCCTaxSystem_Enable
	@enableSystem [BIT] = 1,
	@country [INT] = 0, -- 0: Emirates, 1: SAUDI
	@SubscriptionDate [DATE] = '1-1-2018'
AS
/*
This procedure:
	- inserts/updates the op000 EnableGCCTaxSystem record.
	- is usually called from options dialog in al-ameen.
*/
	SET NOCOUNT ON

	----------------
	DELETE GCCTaxTypes000
	----------------
	INSERT INTO GCCTaxTypes000 (Number, GUID, Type, Name, LatinName, Abbrev, TaxNumber, TaxNumberCode, Description, IsUsed)
	SELECT 1, NEWID(), 1, N'ضريبة القيمة المضافة', N'Value added tax', N'VAT', N'', N'', N'', 1
	----------------
	INSERT INTO GCCTaxTypes000 (Number, GUID, Type, Name, LatinName, Abbrev, TaxNumber, TaxNumberCode, Description, IsUsed)
	SELECT 2, NEWID(), 2, N'الضريبة الانتقائية', N'Excise tax', N'Excise tax', N'', N'', N'', 0
	----------------
	----------------
	DELETE GCCTaxCoding000
	----------------
	INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
	SELECT 1, NEWID(), N'SR', N'التصنيف الأساسي', N'Standard rated', 1, 1, 5
	----------------
	INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
	SELECT 2, NEWID(), N'RC', N'البيع الخاضع للرسوم العكسية', N'Supplies subject to reverse charge', 1, 2, 5
	----------------
	INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
	SELECT 3, NEWID(), N'ZR', CASE @country WHEN 1 THEN N'الشراء ذو الضريبة صفر' ELSE N'البيع ذو الضريبة صفر' END, N'Zero rated', 1, 3, 0
	----------------
	INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
	SELECT 4, NEWID(), N'EX', N'معفى', N'Exempt', 1, 4, 0
	----------------
	INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
	SELECT 5, NEWID(), N'IG', N'البيع بين دول مجلس التعاون الخليجي', N'Intra GCC', 1, 5, 0
	----------------
	INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
	SELECT 6, NEWID(), N'OA', N'التعديلات على ضريبة المخرجات', N'Amendments to output tax', 1, 6, 0
	----------------
	INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
	SELECT 7, NEWID(), N'PU', N'مبيعات المواطنين (الصحة/التعليم/المسكن الأول)', N'Private Healthcare/Private Education/First house sales to citizens', 1, 12, 0
	----------------
	INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
	SELECT 8, NEWID(), N'XP', N'الصادرات', N'Exports', 1, 13, 0
	----------------
	INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
	SELECT 9, NEWID(), N'NA', N'غير مكلف', N'Not Assignment', 1, 14, 0
	----------------
	INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
	SELECT 10, NEWID(), N'GV', N' أعضاء المجموعة الضريبية', N'Members of the tax group', 1, 15, 0
	----------------
	INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
	SELECT 11, NEWID(), N'TR', N' السياحة', N'Tourism', 1, 16, 0
	----------------
	INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
	SELECT 101, NEWID(), N'T', N'خاضع للضريبة', N'Taxable', 2, 7, 0
	----------------
	INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
	SELECT 102, NEWID(), N'ET', N'قابل للخصم', N'Deductible', 2, 8, 0
	----------------
	INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
	SELECT 103, NEWID(), N'A', N'التبغ ومنتجات التبغ', N'Tobacco and tobacco products', 2, 9, 100
	----------------
	INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
	SELECT 104, NEWID(), N'B', N'المنتجات الغازية', N'Carbonated drinks', 2, 10, 50
	----------------
	INSERT INTO GCCTaxCoding000 (Number, GUID, Code, Name, LatinName, TaxType, TaxCode, TaxRatio)
	SELECT 105, NEWID(), N'C', N'مشروبات الطاقة', N'Energy drinks', 2, 11, 100

	----------------
	----------------
	DECLARE @G1 UNIQUEIDENTIFIER = NEWID()
	DECLARE @G2 UNIQUEIDENTIFIER = NEWID()
	DECLARE @G3 UNIQUEIDENTIFIER = NEWID()

	DELETE GCCCustLocations000
	
	DECLARE @DefSubscriptionDate DATE 
	SET @DefSubscriptionDate = [dbo].[fnDate_Amn2Sql]([dbo].[fnOption_get]('AmnCfg_FPDate', DEFAULT))
	DECLARE @Number INT 
	SET @Number = 1
	----------------
	IF @country = 0
	BEGIN
		INSERT INTO GCCCustLocations000 (Number, GUID, Name, LatinName, ParentLocationGUID, Classification, IsSubscribed, SubscriptionDate, IsSystem)
		SELECT @Number, @G1, N'الإمارات العربية المتحدة', N'United Arab Emarets', 0x0, 0, 1, @DefSubscriptionDate, 1
		SET @Number = @Number + 1
		----------------
		INSERT INTO GCCCustLocations000 (Number, GUID, Name, LatinName, ParentLocationGUID, Classification, IsSubscribed, SubscriptionDate, IsSystem)
		SELECT @Number, NEWID(), N'أبو ظبي', N'Abu Dhabi',@G1, 0, 1, @DefSubscriptionDate, 1
		SET @Number = @Number + 1
		----------------
		INSERT INTO GCCCustLocations000 (Number, GUID, Name, LatinName, ParentLocationGUID, Classification, IsSubscribed, SubscriptionDate, IsSystem)
		SELECT @Number, NEWID(), N'دبي', N'Dubai',@G1, 0, 1, @DefSubscriptionDate, 1
		SET @Number = @Number + 1
		----------------
		INSERT INTO GCCCustLocations000 (Number, GUID, Name, LatinName, ParentLocationGUID, Classification, IsSubscribed, SubscriptionDate, IsSystem)
		SELECT @Number, NEWID(), N'الشارقة', N'Sharjah',@G1, 0, 1, @DefSubscriptionDate, 1
		SET @Number = @Number + 1
		----------------
		INSERT INTO GCCCustLocations000 (Number, GUID, Name, LatinName, ParentLocationGUID, Classification, IsSubscribed, SubscriptionDate, IsSystem)
		SELECT @Number, NEWID(), N'عجمان', N'Ajman',@G1, 0, 1, @DefSubscriptionDate, 1
		SET @Number = @Number + 1
		----------------
		INSERT INTO GCCCustLocations000 (Number, GUID, Name, LatinName, ParentLocationGUID, Classification, IsSubscribed, SubscriptionDate, IsSystem)
		SELECT @Number, NEWID(), N'أم القيوين', N'Um elkiwin',@G1, 0, 1, @DefSubscriptionDate, 1
		SET @Number = @Number + 1
		----------------
		INSERT INTO GCCCustLocations000 (Number, GUID, Name, LatinName, ParentLocationGUID, Classification, IsSubscribed, SubscriptionDate, IsSystem)
		SELECT @Number, NEWID(), N'رأس الخيمة', N'Ras Alkhaimeh',@G1, 0, 1, @DefSubscriptionDate, 1
		SET @Number = @Number + 1
		----------------
		INSERT INTO GCCCustLocations000 (Number, GUID, Name, LatinName, ParentLocationGUID, Classification, IsSubscribed, SubscriptionDate, IsSystem)
		SELECT @Number, NEWID(), N'الفجيرة', N'Alfujairah',@G1, 0, 1, @DefSubscriptionDate, 1
		SET @Number = @Number + 1
	END ELSE BEGIN 
		INSERT INTO GCCCustLocations000 (Number, GUID, Name, LatinName, ParentLocationGUID, Classification, IsSubscribed, SubscriptionDate, IsSystem)
		SELECT @Number, @G1, N'المملكة العربية السعودية', N'Kingdom of Saudia Arabia', 0x0, 0, 1, @DefSubscriptionDate, 1
		SET @Number = @Number + 1
	END

	----------------
	INSERT INTO GCCCustLocations000 (Number, GUID, Name, LatinName, ParentLocationGUID, Classification, IsSubscribed, SubscriptionDate, IsSystem)
	SELECT @Number, @G2, N'اتفاقية دول مجلس التعاون الخليجي', N'GCC',0x0, 1, 0, @DefSubscriptionDate, 1
	SET @Number = @Number + 1
	----------------
	INSERT INTO GCCCustLocations000 (Number, GUID, Name, LatinName, ParentLocationGUID, Classification, IsSubscribed, SubscriptionDate, IsSystem)
	SELECT @Number, NEWID(), N'مملكة البحرين', N'Bahrain',@G2, 1, 0, @DefSubscriptionDate, 1
	SET @Number = @Number + 1
	----------------
	INSERT INTO GCCCustLocations000 (Number, GUID, Name, LatinName, ParentLocationGUID, Classification, IsSubscribed, SubscriptionDate, IsSystem)
	SELECT @Number, NEWID(), N'دولة الكويت', N'Kuwait',@G2, 1, 0, @DefSubscriptionDate, 1
	SET @Number = @Number + 1
	----------------
	INSERT INTO GCCCustLocations000 (Number, GUID, Name, LatinName, ParentLocationGUID, Classification, IsSubscribed, SubscriptionDate, IsSystem)
	SELECT @Number, NEWID(), N'سلطنة عمان', N'Oman',@G2, 1, 0, @DefSubscriptionDate, 1
	SET @Number = @Number + 1
	----------------
	INSERT INTO GCCCustLocations000 (Number, GUID, Name, LatinName, ParentLocationGUID, Classification, IsSubscribed, SubscriptionDate, IsSystem)
	SELECT @Number, NEWID(), N'دولة قطر', N'Qatar',@G2, 1, 0, @DefSubscriptionDate, 1
	SET @Number = @Number + 1
	----------------
	IF @country = 0
	BEGIN
		INSERT INTO GCCCustLocations000 (Number, GUID, Name, LatinName, ParentLocationGUID, Classification, IsSubscribed, SubscriptionDate, IsSystem)
		SELECT @Number, NEWID(), N'المملكة العربية السعودية', N'Kingdom of Saudia Arabia', @G2, 1, 0, @DefSubscriptionDate, 1
		SET @Number = @Number + 1
	END ELSE BEGIN 
		INSERT INTO GCCCustLocations000 (Number, GUID, Name, LatinName, ParentLocationGUID, Classification, IsSubscribed, SubscriptionDate, IsSystem)
		SELECT @Number, NEWID(), N'الإمارات العربية المتحدة', N'United Arab Emarets', @G2, 1, 0, @DefSubscriptionDate, 1
		SET @Number = @Number + 1
	END
	----------------
	INSERT INTO GCCCustLocations000 (Number, GUID, Name, LatinName, ParentLocationGUID, Classification, IsSubscribed, SubscriptionDate, IsSystem)
	SELECT @Number, @G3, N'خارجي', N'Outside', 0x0, 2, 0, @DefSubscriptionDate, 1
	SET @Number = @Number + 1
	----------------
	INSERT INTO GCCCustLocations000 (Number, GUID, Name, LatinName, ParentLocationGUID, Classification, IsSubscribed, SubscriptionDate, IsSystem)
	SELECT @Number, NEWID(), N'محلي غير مشترك', N'Local non registered', @G3, 3, 0, @DefSubscriptionDate, 1
	SET @Number = @Number + 1
	----------------
	INSERT INTO GCCCustLocations000 (Number, GUID, Name, LatinName, ParentLocationGUID, Classification, IsSubscribed, SubscriptionDate, IsSystem)
	SELECT @Number, NEWID(), N'خارج منطقة اتفاقية دول مجلس التعاون الخليجي', N'Outside GCC', @G3, 4, 0, @DefSubscriptionDate, 1
	SET @Number = @Number + 1
	----------------
	----------------
	DELETE GCCTaxSettings000
	---------------
	INSERT INTO GCCTaxSettings000([GUID], SubscriptionDate, ForceNumberingByBillType) VALUES(NEWID(), @SubscriptionDate, 0)

	UPDATE bt000 
	SET taxBeforeDiscount = 0, taxBeforeExtra = 0, VATSystem = 0, DefVATAccGUID = 0x0
	WHERE
		(((Type = 1) AND (BillType = 0 OR BillType = 1 OR BillType = 2 OR BillType = 3) AND (bNoEntry = 0)) OR Type = 5 OR Type = 6)

	EXEC prcDisableTriggers 'bu000'
	UPDATE bu
	SET ReturendBillDate = bu.[Date] 
	FROM 
		bu000 bu 
		INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID 
	WHERE 
		bt.[Type] = 1 
		AND 
		(bt.BillType = 2 OR bt.BillType = 3)
		AND 
		bu.ReturendBillDate <= '1-1-1990'

	EXEC prcEnableTriggers 'bu000'
#########################################################
CREATE FUNCTION fnGCCTaxSystem_CheckEnable()
	RETURNS INT
BEGIN
	IF EXISTS(SELECT * FROM bt000 AS BT WHERE (((Type = 1) AND BillType IN(0, 1, 2, 3)  AND (bNoEntry = 0)) OR Type = 5 OR Type = 6) AND VATSystem = 2)
		RETURN 1;

	--IF EXISTS(SELECT * FROM et000 WHERE TaxType = 2)
	--	RETURN 2;
	
	RETURN 0;
END
#########################################################
CREATE FUNCTION fnGetNextBillNumber(@btGuid UNIQUEIDENTIFIER, @brachGuid UNIQUEIDENTIFIER = 0x)
RETURNS BIGINT
BEGIN

	DECLARE @IsGCCSystemEnabled	BIT = dbo.fnOption_GetInt('AmnCfg_EnableGCCTaxSystem', '0');
	DECLARE @Number BIGINT = 1;
	DECLARE @btBillType INT,
			@btType INT;
	DECLARE @ForceNumbering BIT = (SELECT TOP 1 ForceNumberingByBillType FROM GCCTaxSettings000);

	 SELECT 
		@btBillType = BillType,
		@btType = [Type] 
	FROM bt000 WHERE GUID = @btGuid;

	IF @IsGCCSystemEnabled <> 0 AND @ForceNumbering = 1 AND @btBillType IN(0, 1, 2, 3) AND @btType = 1
	BEGIN
		SELECT @Number = ISNULL(MAX([Number]), 0) + 1
		FROM 
			BU000 AS BU 
			JOIN BT000 AS BT ON BU.TypeGUID = BT.Guid 
		WHERE 
			BT.BillType = @btBillType
			AND ((ISNULL(@brachGuid, 0x) <> 0x AND BU.Branch = @brachGuid) OR ISNULL(@brachGuid, 0x) = 0x)
	END
	ELSE BEGIN
		SELECT @Number = ISNULL(MAX([Number]), 0) + 1
		FROM [BU000]
		WHERE [TypeGuid] = @btGuid
	END

	RETURN @Number
END
#########################################################
#END