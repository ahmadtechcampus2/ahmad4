#########################################################
CREATE FUNCTION fnGCCGetBillItemTaxCode(@MatTaxCode INT, @CustTaxCode INT, @BtGUID UNIQUEIDENTIFIER, 
	@CustLocation INT, @IsCustSubscribed BIT, @IsOA BIT, @IsCalcTaxForPUTaxCode BIT = 0)
RETURNS INT
BEGIN
	DECLARE 
		@NONE TINYINT = 0,
		@SR TINYINT = 1,
		@ZR TINYINT = 3,
		@EX TINYINT = 4,
		@IG TINYINT = 5,
		@OA TINYINT = 6,
		@PU TINYINT = 12,
		@XP TINYINT = 13,
		@NA TINYINT = 14;
		
	IF @NONE IN(@MatTaxCode, @CustTaxCode)
		RETURN @NONE;
	IF @CustTaxCode = @PU AND @IsCalcTaxForPUTaxCode = 0
		RETURN @PU;
	IF @CustTaxCode = @PU AND @IsCalcTaxForPUTaxCode = 1
		RETURN @MatTaxCode;
	IF @CustTaxCode = @XP
		RETURN @XP;
	IF @CustTaxCode = @NA
	BEGIN
		IF EXISTS(SELECT * FROM bt000 WHERE GUID = @BtGUID AND [BillType] IN (0, 2))
			RETURN @NA;
	END
	IF @EX IN(@MatTaxCode, @CustTaxCode)
		RETURN @EX;
	IF @ZR IN(@MatTaxCode, @CustTaxCode) OR (@CustLocation != 0 /*Local*/ AND @IsCustSubscribed = 0)
		RETURN @ZR;
	IF @IsOA = 1
		RETURN @OA;
	IF @CustTaxCode = @IG
		RETURN @IG;

	RETURN @MatTaxCode;
END
#########################################################
CREATE FUNCTION fnGCCGetVatRatio(@TaxCode INT, @MatVatRatio FLOAT)
RETURNS INT
BEGIN

	DECLARE 
		@NONE TINYINT = 0,
		@SR TINYINT = 1,
		@ZR TINYINT = 3,
		@EX TINYINT = 4,
		@IG TINYINT = 5,
		@OA TINYINT = 6,
		@PU TINYINT = 12,
		@XP TINYINT = 13,
		@NA TINYINT = 14;
	IF @TaxCode IN(@EX, @ZR, @NONE, @PU, @XP, @NA) -- || m_BillDlg->IsGCCRCBill())
		RETURN 0;
	IF @TaxCode IN(@SR, @OA, @IG)
		RETURN @MatVatRatio;

	RETURN 0;
END
#########################################################
CREATE PROC prcGCCResetBillsTaxes
    @PayTypeFilter TINYINT = 2, -- 0 Forward, 1 Cash,  2 All
    @ForVerification BIT = 0,
	@DurationGuid UNIQUEIDENTIFIER = 0x,
	@ShowDifferencesOnly BIT = 0,
	@HandleSr BIT = 0,
	@HandleZero BIT = 0,
	@HandleZeroType INT = 0
AS
       SET NOCOUNT ON

       IF OBJECT_ID('tempdb..##Bills') IS NOT NULL 
       BEGIN
			DROP TABLE ##Bills;
       END

       IF OBJECT_ID('tempdb..##BillsItems') IS NOT NULL 
       BEGIN
			DROP TABLE ##BillsItems;
       END

       DECLARE
              @VATTaxType INT,
              @ExciseTaxType INT,
              @IsExciseUsed BIT,
              @CompanySubDate DATE;

       DECLARE 
              @NONE TINYINT = 0,
              @SR TINYINT = 1,
              @ZR TINYINT = 3,
              @EX TINYINT = 4,
              @IG TINYINT = 5,
              @OA TINYINT = 6,
              @T TINYINT = 7,
              @ET TINYINT = 8;
		
		DECLARE @SR_Ratio FLOAT;

		SET @SR_Ratio = (SELECT TOP 1 TaxRatio FROM GCCTaxCoding000 WHERE TaxCode = @SR);

       -- locations Local, GCC, O, LNR, OG
       DECLARE 
              @Local TINYINT = 0,
              @GCC TINYINT = 1,
              @O TINYINT = 2,
              @LNR TINYINT = 3,
              @OG TINYINT = 4;

       DECLARE 
              @DurationStartDate DATE,
              @DurationEndDate DATE;

       SET @VATTaxType = 1;
       SET @ExciseTaxType = 2;
       SELECT @IsExciseUsed = IsUsed FROM GCCTaxTypes000 WHERE Type = @ExciseTaxType;
       SELECT TOP 1 @CompanySubDate = SubscriptionDate FROM GCCTaxSettings000;

       SELECT 
              @DurationStartDate = StartDate,
              @DurationEndDate = EndDate
       FROM 
			GCCTaxDurations000
       WHERE GUID = @DurationGuid;

       CREATE TABLE ##Bills(
              BuGUID UNIQUEIDENTIFIER,
              iBuNumber INT,
              BuNumber NVARCHAR(250),
              BuType UNIQUEIDENTIFIER,
              BuDate DATETIME,
              BuCurrencyVal FLOAT,
              BuCurrencyGuid UNIQUEIDENTIFIER,
              btCanUseExcise BIT,
              btCanUseReversCharge BIT,
              CustGUID UNIQUEIDENTIFIER,
              CustAccGUID UNIQUEIDENTIFIER,
              CustVATTaxCode INT,
              CustExciseTaxCode INT,
              CustLocClassification INT,
              CustIsSubscribed BIT,
              CustSubscriptionDate DATETIME,
              CustIsSubscribedToBill BIT,
              CustIsReversCharge BIT,
              IsSellsReSells BIT,
              IsPurchaseRePurchase BIT,
              IsRCBill BIT,
              OldTotal FLOAT,
              OldVat FLOAT,
              NewTotal FLOAT,
              NewVat FLOAT,
              IsApply BIT,
              ProccesMethod INT,
              IsPosted BIT,
              ErrNumber INT,
              SetDefCust BIT,
              PartTotal FLOAT,
              IsOA BIT,
			  IsCustomsRate BIT);

       CREATE TABLE ##BillsItems(
              BiGuid UNIQUEIDENTIFIER,
              ParentGuid UNIQUEIDENTIFIER,
              OldVAT FLOAT,
              OldVATRatio FLOAT,
              VAT FLOAT,
              VATRatio FLOAT,
              VATTaxCode INT,
              Excise FLOAT,
              ExciseRatio FLOAT,
              ExciseTaxCode INT,
              PurchaseVal FLOAT,
              ReversCharge FLOAT,
              PartTotal FLOAT,
              IsRC BIT);

       DELETE ##Bills;
       DELETE ##BillsItems;
       
       ;WITH Bills AS
       (
            SELECT
              BU.buGUID AS BuGUID,
              BU.buNumber AS iBuNumber,
              CASE [dbo].[fnConnections_GetLanguage]()
                     WHEN 0 THEN buFormatedNumber
                     ELSE buLatinFormatedNumber
              END AS BuNumber,
              BT.GUID AS BuType,
              BU.buDate,
              BU.buCurrencyVal,
              BU.buCurrencyPtr,
              BU.btBillType,
			  BU.buCustAcc,
              CASE WHEN @IsExciseUsed = 1 AND BU.btUseExciseTax = 1 THEN 1 ELSE 0 END AS btCanUseExcise,
              CASE WHEN BU.buCustPtr = 0x0 THEN BT.CustAccGUID ELSE BU.buCustPtr END AS buCustPtr,
              CASE WHEN BU.btBillType = 1 OR BU.btBillType = 3 THEN 1 ELSE 0 END AS IsSellsReSells,
              CASE WHEN BU.btBillType = 0 OR BU.btBillType = 2 THEN 1 ELSE 0 END AS IsPurchaseRePurchase,
              BU.buTotal + BU.buVAT - bu.buTotalDisc + bu.buTotalExtra AS OldTotal,
              BU.buVAT AS OldVat,
              BU.buIsPosted,
              btUseReverseCharges,
              btType,
              CASE WHEN BU.buCustPtr = 0x0 THEN 1 ELSE 0 END AS buIsDefCust,
              CASE @ForVerification
                     WHEN 0 THEN 0
                     ELSE 
                           CASE 
                                  WHEN BU.btBillType IN(2, 3) AND BU.ReturendBillDate < @DurationStartDate THEN 1 -- مرتجع مبيع, مرتجع شراء
                                  ELSE 0 
                           END
              END AS IsOABill,
			  BU.ImportViaCustoms,
			  BU.buGCCLocationGUID
       FROM
              vwBu AS BU
              INNER JOIN bt000 BT ON BT.GUID = BU.buType
       WHERE
              (((BU.btType = 1) AND BU.btBillType IN(0, 1, 2, 3)) OR BU.btType = 5 OR BU.btType = 6)
              AND BU.btNoEntry = 0
			  AND ((EXISTS(SELECT * FROM bi000 WHERE ParentGUID = BU.buGUID AND TaxCode = 0) AND @ForVerification = 0) OR @ForVerification = 1)
              AND ((@PayTypeFilter = 0 AND BU.buPayType = 1) OR (@PayTypeFilter = 1 AND BU.buPayType = 0) OR @PayTypeFilter = 2)
              AND ((BU.btBillType IN(2,3) AND CAST(BU.ReturendBillDate AS DATE) >= @CompanySubDate) OR BU.btBillType NOT IN(2,3))
              AND BU.buDate >= @CompanySubDate
              AND (@DurationGuid = 0x OR (CAST(BU.buDate AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate))
       )
       INSERT INTO ##Bills
       SELECT
              BU.buGUID,
              BU.iBuNumber,
              BU.BuNumber,
              BT.GUID,
              BU.buDate,
              BU.buCurrencyVal,
              BU.buCurrencyPtr,
              BU.btCanUseExcise,
              CASE WHEN BU.btUseReverseCharges = 1 THEN CU.ReverseCharges ELSE 0 END,
              BU.buCustPtr,
              ISNULL(BU.buCustAcc, 0x0),
              ISNULL(VCT.TaxCode, 0) AS VATTaxCode,
              ISNULL(CCT.TaxCode, 0) AS ExciseTaxCode,
              ISNULL(L.Classification, 0),
              ISNULL(L.IsSubscribed, 0),
              ISNULL(L.SubscriptionDate, '1-1-1980'),
              CASE ISNULL(L.IsSubscribed, 0)
                     WHEN 1 THEN CASE WHEN buDate >= L.SubscriptionDate THEN 1 ELSE 0 END
                     ELSE 0
              END,
              ISNULL(CU.ReverseCharges, 0),
              IsSellsReSells,
              IsPurchaseRePurchase,
              ISNULL(CASE WHEN (BU.btBillType = 0 OR BU.btBillType = 2) AND BU.btUseReverseCharges = 1 AND CU.ReverseCharges = 1 AND 
                           ((ISNULL(L.Classification, 0) = @OG OR ISNULL(L.Classification, 0) = @LNR OR ISNULL(L.Classification, 0) = @O) OR (ISNULL(L.Classification, 0) <> @Local AND ISNULL(L.IsSubscribed, 0) = 0))
                           THEN 1 ELSE 0 END, 0),
              BU.OldTotal,
              BU.OldVat,
              0, -- NewTotal
              0, -- NewVat
              0,
              1,
              BU.buIsPosted,
              CASE BU.buCustPtr
                     WHEN 0x THEN 1 -- no default customer in bill type
                     ELSE
                           CASE ISNULL(VCT.TaxType, 0) 
                                  WHEN 0 THEN 2 -- customer has no tax type
                                  ELSE 
                                         CASE ISNULL(L.GUID, 0x0)
                                                WHEN 0x0 THEN 3 -- customer has no location 
                                                ELSE 0
                 --                                      CASE WHEN ((BU.btType = 1) AND (BU.btBillType = 1 OR BU.btBillType = 3)) 
																	--AND ISNULL(BT.DefaultLocationGUID, 0x0) = 0x0
                 --                                             THEN 4 -- bill type has no default location 
                 --                                             ELSE 0
                 --                                      END
                                         END
                           END
              END,
              buIsDefCust,
              0,
              IsOABill,
			  CASE WHEN IsPurchaseRePurchase = 1 THEN ImportViaCustoms ELSE 0 END
       FROM
              Bills AS BU
              INNER JOIN bt000 BT ON BT.GUID = BU.buType
              LEFT JOIN cu000 AS CU ON BU.buCustPtr = CU.GUID
              LEFT JOIN GCCCustomerTax000 AS VCT ON BU.buCustPtr = VCT.CustGUID AND VCT.TaxType = @VATTaxType
              LEFT JOIN GCCCustomerTax000 AS CCT ON BU.buCustPtr = CCT.CustGUID AND CCT.TaxType = @ExciseTaxType
              LEFT JOIN GCCCustLocations000 AS L ON L.GUID = CU.GCCLocationGUID
			  LEFT JOIN GCCCustLocations000 AS BL ON BL.GUID = BU.buGCCLocationGUID
       
       UPDATE ##Bills
       SET ErrNumber = 5
       FROM 
              ##Bills BU
              INNER JOIN bi000 bi ON BU.BuGUID = bi.ParentGUID 
              INNER JOIN mt000 mt ON bi.MatGUID = mt.GUID 
              LEFT JOIN GCCMaterialTax000 CTM ON CTM.MatGUID = mt.GUID AND CTM.TaxType = 1
       WHERE 
              BU.ErrNumber = 0
              AND 
              ((CTM.TaxCode IS NULL) OR (CTM.TaxCode = 0))

       ;WITH TotalDiscs AS
       (
			SELECT 
				ParentGUID, 
				SUM(Discount) AS Disc, 
				SUM(Extra) AS Extra 
			FROM di000 
			GROUP BY ParentGUID
       )
       ,BITaxCodes AS
       (
			SELECT
				BI.biGUID AS GUID,
				-- Start calc tax code
				CASE
					WHEN @HandleSR = 1 AND BI.biVat > 0 THEN @SR
					WHEN @HandleZero = 1 AND BI.biVat = 0 AND VGMT.TaxCode = @SR THEN 
						CASE @HandleZeroType
							WHEN 1 THEN @ZR
							ELSE @EX
						END
					ELSE 
						ISNULL(dbo.fnGCCGetBillItemTaxCode(VGMT.TaxCode, BU.CustVATTaxCode, BU.BuType, BU.CustLocClassification, BU.CustIsSubscribedToBill, BU.IsOA, mt.IsCalcTaxForPUTaxCode), 0) 
				END AS VATTaxCode,
				-- End calc tax code
				VGMT.Ratio AS MatVATRatio,
				CASE WHEN BU.btCanUseExcise = 1 THEN 
					CASE WHEN (BU.IsSellsReSells = 1 AND BU.CustExciseTaxCode = @ET) OR (BU.IsPurchaseRePurchase = 1 AND BU.CustExciseTaxCode = @T) THEN EGMT.TaxCode ELSE 0 END
					ELSE 0
				END AS ExciseTaxCode,
				CASE WHEN BU.btCanUseExcise = 1 THEN 
					CASE WHEN (BU.IsSellsReSells = 1 AND BU.CustExciseTaxCode = @ET) OR (BU.IsPurchaseRePurchase = 1 AND BU.CustExciseTaxCode = @T) THEN EGMT.Ratio ELSE 0 END
					ELSE 0
				END AS ExciseTaxRatio,
				IsRCBill,
				CASE WHEN IsRCBill = 1 THEN VGMT.TaxCode ELSE @NONE END AS ReversChargeTaxCode,
				BI.BiPrice * BI.BiBillQty - BI.BiDiscount - (BI.BiPrice * BI.BiBillQty / (CASE BI.buTotal WHEN 0 THEN 1 ELSE BI.buTotal END) * ISNULL(TD.Disc, 0)) + BI.BiExtra + (BI.BiPrice * BI.BiBillQty / (CASE BI.buTotal WHEN 0 THEN 1 ELSE BI.buTotal END) * ISNULL(TD.Extra, 0)) AS biTotal,
				CASE BI.BiUnity
					WHEN 1 THEN mt.EndUser
					WHEN 2 THEN mt.EndUser2
					WHEN 3 THEN mt.EndUser3
				END AS EndUserPrice,
				BI.BiPrice * BI.BiBillQty AS PartTotal,
				BI.BiBillQty AS BiQty,
				BI.biCustomsRate,
				IsCustomsRate,
				CASE WHEN @HandleSR = 1 AND BI.biVat > 0 THEN 1 ELSE 0 END AS HandleSR,
				CASE WHEN @HandleZero = 1 AND BI.biVat = 0 AND VGMT.TaxCode = @SR THEN 1 ELSE 0 END AS HandleZero
			FROM
				vwExtended_bi AS BI
				JOIN ##Bills AS BU ON BU.BuGUID = BI.buGUID
				JOIN mt000 AS MT ON MT.GUID = BI.biMatPtr
				LEFT JOIN GCCMaterialTax000 AS VGMT ON VGMT.MatGUID = BI.biMatPtr AND VGMT.TaxType = @VATTaxType
				LEFT JOIN GCCMaterialTax000 AS EGMT ON EGMT.MatGUID = BI.biMatPtr AND EGMT.TaxType = @ExciseTaxType
				LEFT JOIN TotalDiscs AS TD ON TD.ParentGUID = BI.buGUID
			WHERE 
				((BU.IsSellsReSells = 1 AND VGMT.ProfitMargin <> 1) OR BU.IsSellsReSells = 0)
				AND
				(BU.ErrNumber = 0 OR @ForVerification = 1)
				--AND ((@HandleSr = 1 AND (BI.biVat <> 0)) OR (@HandleSr = 0))
       ),NewBI AS
       (
			SELECT
				GUID,
				VATTaxCode,
				ExciseTaxCode,
				ExciseTaxRatio,
				-- Start calc tax ratio
				CASE
					WHEN HandleSR = 1 THEN @SR_Ratio
					WHEN HandleZero = 1 THEN 0
					ELSE CASE WHEN IsRCBill = 0 THEN dbo.fnGCCGetVatRatio(VATTaxCode, MatVATRatio) ELSE 0 END
				END AS NewVATRatio,
				-- End calc tax ratio
				CASE WHEN IsRCBill = 1 AND ReversChargeTaxCode <> @NONE THEN MatVATRatio ELSE 0 END AS ReversChargeRatio,
				IsRCBill,
				biTotal,
				EndUserPrice,
				PartTotal,
				BiQty,
				biCustomsRate,
				IsCustomsRate
			FROM
				BITaxCodes
       )
       INSERT INTO ##BillsItems
       SELECT
			BI.[GUID],
			BI.ParentGUID,
			BI.VAT,
			BI.VATRatio,
			ISNULL(biTotal * NBI.NewVATRatio / 100, 0),
			ISNULL(NBI.NewVATRatio, 0),
			ISNULL(NBI.VATTaxCode, 0),
			ISNULL(EndUserPrice * BiQty * NBI.ExciseTaxRatio / 100, 0),
			ISNULL(NBI.ExciseTaxRatio, 0),
			ISNULL(NBI.ExciseTaxCode, 0),
			ISNULL(CASE WHEN IsRCBill = 1 THEN PartTotal ELSE 0 END, 0),
			ISNULL(CASE WHEN IsCustomsRate = 1 THEN biCustomsRate ELSE biTotal END * NBI.ReversChargeRatio / 100, 0),
			PartTotal,
			CASE WHEN IsRCBill = 1 AND ReversChargeRatio > 0 THEN 1 ELSE 0 END
		FROM
			bi000 AS BI
			JOIN NewBI AS NBI ON NBI.GUID = BI.[GUID];

       ;WITH BI AS
       (
              SELECT
              ParentGuid AS BuGuid,
              SUM(VAT) AS TotalVat,
              SUM(PartTotal) AS PartTotal
              FROM ##BillsItems
              GROUP BY ParentGuid
       )
       UPDATE B
       SET 
            NewVat = ISNULL(BI.TotalVat, 0),
            NewTotal = ISNULL(OldTotal - B.OldVat + BI.TotalVat, 0),
            SetDefCust = CASE WHEN B.ErrNumber = 0 AND B.SetDefCust = 1 THEN 1 ELSE 0 END,
            B.PartTotal = BI.PartTotal

       FROM 
			##Bills AS B
			JOIN BI ON B.BuGUID = BI.BuGuid

		IF @ShowDifferencesOnly = 1
		BEGIN
			DELETE ##Bills
			WHERE CAST((OldVat - NewVat) AS MONEY) = 0
		END
		IF @ForVerification = 0
		BEGIN
			SELECT * FROM ##Bills ORDER BY BuNumber;
			SELECT * FROM ##BillsItems 
		END
#########################################################
CREATE PROC prcGCCApplyTaxesToBills
	@DifferenceAccount UNIQUEIDENTIFIER = 0x
AS
	SET NOCOUNT ON

	IF OBJECT_ID('tempdb..##Bills') IS NULL 
	BEGIN
		INSERT INTO [ErrorLog]([level], [type], [c1]) SELECT 1, 0, '##Bills doesn''t exists'
	END

	IF OBJECT_ID('tempdb..##BillsItems') IS NULL 
	BEGIN
		INSERT INTO [ErrorLog]([level], [type], [c1]) SELECT 1, 0, '##BillsItems doesn''t exists'
	END

	EXEC prcDisableTriggers 'bu000', 0
	EXEC prcDisableTriggers 'bi000', 0

	UPDATE BU 
	SET 
		BU.IsPosted = 0,
		BU.Total = B.PartTotal,
		BU.VAT = B.NewVat,
		BU.CustGuid = CASE WHEN ISNULL(B.SetDefCust, 0) = 1 THEN BT.CustAccGuid ELSE BU.CustGuid END,
		BU.GCCLocationGUID = CASE WHEN bt.BillType IN (1, 3) AND B.CustLocClassification = 0 THEN  BT.DefaultLocationGUID ELSE 0x0 END
	FROM 
		bu000 AS BU
		JOIN bt000 AS BT ON BT.Guid = BU.TypeGuid
		JOIN ##Bills AS B ON BU.GUID = B.BuGuid
	WHERE B.IsApply = 1 AND B.ErrNumber = 0
	
	UPDATE BI
	SET
		BI.VAT = ISNULL(NBI.VAT, 0),
		BI.VATRatio = ISNULL(NBI.VATRatio, 0),
		BI.TaxCode = ISNULL(NBI.VATTaxCode, 0),
		BI.ExciseTaxVal = ISNULL(NBI.Excise, 0),
		BI.ExciseTaxPercent = ISNULL(NBI.ExciseRatio, 0),
		BI.ExciseTaxCode = ISNULL(NBI.ExciseTaxCode, 0),
		BI.PurchaseVal = ISNULL(NBI.PurchaseVal, 0),
		BI.ReversChargeVal = ISNULL(NBI.ReversCharge, 0)
	FROM
		bi000 AS BI
		JOIN ##Bills AS B ON B.BuGuid = BI.ParentGUID
		JOIN ##BillsItems AS NBI ON BI.GUID = NBI.BiGuid
	WHERE B.IsApply = 1 AND B.ErrNumber = 0

	UPDATE BU 
	SET 
		IsPosted = B.IsPosted
	FROM 
		bu000 AS BU
		JOIN ##Bills AS B ON BU.GUID = B.BuGuid
	WHERE B.IsApply = 1 AND B.ErrNumber = 0

	DECLARE @UserGuid	[UNIQUEIDENTIFIER]
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()

	INSERT INTO  LoG000 (Computer,[GUID],LogTime,RecGUID,RecNum,TypeGUID,Operation,OperationType,UserGUID,Notes)
	SELECT 
		host_Name(), 
		NEWID(), 
		GETDATE(), 
		BU.GUID, 
		BU.Number, 
		BU.TypeGuid, 
		1, 
		3, 
		@UserGUID, 
		dbo.fnStrings_get('GCC\UPDATEBILLTAX', DEFAULT) + (case [dbo].[fnConnections_GetLanguage]() when 0 then [BT].[Abbrev] else [BT].[LatinAbbrev]  end) + N':' + CONVERT(varchar(250), BU.Number)
	FROM 
		bu000 AS BU
		JOIN bt000 AS BT ON BT.Guid = BU.TypeGuid
		JOIN ##Bills AS B ON BU.GUID = B.BuGuid
	WHERE B.IsApply = 1 AND B.ErrNumber = 0
	
	DECLARE
		@c CURSOR,
		@g [UNIQUEIDENTIFIER],
		@n [INT]
		
	SET @c = CURSOR FAST_FORWARD FOR
				SELECT [bu].[buGUID],[bu].[ceNumber]
				FROM ##Bills B INNER JOIN [vwBuCe] AS [bu] ON [b].BuGuid = [bu].[buGUID]
				WHERE B.IsApply = 1 AND B.ErrNumber = 0
				ORDER BY [bu].[buSortFlag],[bu].[buDate],[bu].[buNumber]

	OPEN @c FETCH FROM @c INTO @g, @n
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--EXEC prcCheckDB_bu_Sums 1, @g
		EXEC [prcBill_GenEntry] @g, @n
		FETCH FROM @c INTO @g, @n
	END
	CLOSE @c
	DEALLOCATE @c
	
	-- قيد التسوية

	DECLARE	
		@ceNum INT,
		@ceGUID UNIQUEIDENTIFIER,
		@Total FLOAT;

	SELECT @ceNum = ISNULL(MAX(Number),0 ) + 1  FROM [ce000] 
	SET @ceGUID = NEWID();

	SELECT @Total = SUM(OldTotal - NewTotal) FROM ##Bills WHERE ProccesMethod = 1 AND IsApply = 1

	IF ABS(@Total) > 0
	BEGIN

		INSERT INTO ce000
			   ([Type]
			   ,[Number]
			   ,[Date]
			   ,[Debit]
			   ,[Credit]
			   ,[Notes]
			   ,[CurrencyVal]
			   ,[IsPosted]
			   ,[Security]
			   ,[Branch]
			   ,[GUID]
			   ,[CurrencyGUID]
			   ,[PostDate])
		SELECT
			1,
			@ceNum, 
			GETDATE(),
			ABS(@Total),
			ABS(@Total),
			dbo.fnStrings_get('GCCTAX_APPLY\ENTRY_GEN_FROM_TAX_APPLY', DEFAULT),
			1,
			0,
			1,
			ISNULL((SELECT TOP 1 GUID FROM br000 ORDER BY Number), 0x0), --branch
			@ceGUID,
			(SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1),
			GETDATE();

			INSERT INTO [dbo].[en000]
			   ([Number]
			   ,[Date]
			   ,[Debit]
			   ,[Credit]
			   ,[Notes]
			   ,[CurrencyVal]
			   ,[GUID]
			   ,[ParentGUID]
			   ,[AccountGUID]
			   ,[CustomerGUID]
			   ,[CurrencyGUID]
			   ,[ContraAccGUID]
			   ,[Type])
			SELECT
				1,
				GETDATE(),
				CASE WHEN @Total > 0 THEN @Total ELSE 0 END,
				CASE WHEN @Total < 0 THEN ABS(@Total) ELSE 0 END,
				N'',
				1,
				NEWID(),
				@ceGUID,
				@DifferenceAccount,
				ISNULL((SELECT TOP 1 GUID FROM cu000 WHERE AccountGUID = @DifferenceAccount), 0x0),
				(SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1),
				0x,
				300

			;WITH T AS
			(
				SELECT
					CustGUID,
					SUM(OldTotal - NewTotal) AS CuTotal,
					CustAccGUID
				FROM ##Bills
				WHERE ProccesMethod = 1 AND IsApply = 1
				GROUP BY CustGUID, CustAccGUID
			)
			INSERT INTO [dbo].[en000]
			   ([Number]
			   ,[Date]
			   ,[Debit]
			   ,[Credit]
			   ,[Notes]
			   ,[CurrencyVal]
			   ,[GUID]
			   ,[ParentGUID]
			   ,[AccountGUID]
			   ,[CustomerGUID]
			   ,[CurrencyGUID]
			   ,[ContraAccGUID]
			   ,[Type])
			SELECT
				ROW_NUMBER() OVER(ORDER BY CustGUID) + 1,
				GETDATE(),
				CASE WHEN CuTotal < 0 THEN ABS(CuTotal) ELSE 0 END,
				CASE WHEN CuTotal > 0 THEN CuTotal ELSE 0 END,
				N'',
				1,
				NEWID(),
				@ceGUID,
				CustAccGUID,
				CustGUID,
				(SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1),
				@DifferenceAccount,
				301
			FROM T

			UPDATE ce000 SET IsPosted = 1 WHERE GUID = @ceGUID
	END
	EXEC prcEnableTriggers 'bu000'
	EXEC prcEnableTriggers 'bi000'

	EXEC [prcBill_rePost] 1
	EXEC [prcEntry_rePost]

	DROP TABLE ##Bills
	DROP TABLE ##BillsItems
#########################################################
#END