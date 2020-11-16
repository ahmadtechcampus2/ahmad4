################################################################################
CREATE PROCEDURE prcPOSSD_Station_ControlAccountOutsideMoves
-- Params -------------------------------   
	@POSGuid				UNIQUEIDENTIFIER,
	@POSAccount				UNIQUEIDENTIFIER,
	@StartDate				DATETIME,
	@EndDate				DATETIME
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	DECLARE @EntryGeneratedFromPOSTicket				INT = 701
	DECLARE @EntryGeneratedFromPOSExternalOperations	INT = 702
	DECLARE @EntryGeneratedFromPOSBankCardTicket		INT = 703
	DECLARE @EntryGeneratedFromPOSSalesReturnTicket		INT = 704
	DECLARE @EntryGeneratedFromRecieveCouponToCustomer	INT = 705
	DECLARE @EntryGeneratedFromRecieveCardToCustomer	INT = 706
	DECLARE @EntryGeneratedFromPayCouponFromCustomer	INT = 707
	DECLARE @EntryGeneratedFromPayCardFromCustomer		INT = 708
	DECLARE @EntryGeneratedFromExpiredReturnCoupon		INT = 709
	DECLARE @EntryGeneratedFromGCCTaxSaleTicket			INT = 710
	DECLARE @EntryGeneratedFromGCCTaxReSaleTicket		INT = 711
	DECLARE @EntryGeneratedFromDeliveryFeeOrder		    INT = 712
	DECLARE @EntryGeneratedFromDownPaymentOrder		    INT = 713

	SELECT BRel.BillGUID AS BillGUID
	INTO #BillGeneratedFromPOS
	FROM POSSDShift000 S
	INNER JOIN BillRel000 BRel ON S.[GUID] = BRel.ParentGUID
	WHERE StationGUID = @POSGuid

	 DECLARE @Lang	INT
	 EXEC @Lang = [dbo].fnConnections_GetLanguage;

	 SELECT 
 		EN.[Date]									AS EnDate,
 		Ce.Number									AS CeNumber,
 		Ce.[GUID]									AS CeGuid,
		EN.[GUID]									AS EnGuid,
		BU.[GUID]									AS BuGuid,
		CH.[GUID]									AS ChGuid,
 		EN.Notes									AS EnNotes,
 		EN.AccountGUID								AS AccountGuid,
 		EN.Debit									AS Debit,
 		EN.Credit									AS Credit,
 		((EN.Debit - EN.Credit) / EN.CurrencyVal)	AS MoveBalance ,
 		(CASE ER.ParentType WHEN 2 THEN CASE @Lang WHEN 0 THEN BT.Abbrev ELSE CASE BT.LatinAbbrev WHEN '' THEN BT.Abbrev ELSE BT.LatinAbbrev END END 
 							WHEN 5 THEN CASE @Lang WHEN 0 THEN NT.Abbrev ELSE CASE NT.LatinAbbrev WHEN '' THEN NT.Abbrev ELSE NT.LatinAbbrev END END + ': ' + CH.Num 
 							WHEN 4 THEN CASE @Lang WHEN 0 THEN ET.Abbrev ELSE CASE ET.LatinAbbrev WHEN '' THEN ET.Abbrev ELSE ET.LatinAbbrev END END
 							ELSE '' END ) + ': ' + CAST(ER.ParentNumber AS nvarchar(100)) AS Name,
 
 		EN.CurrencyVal								AS EnCurrencyVal,
 		MY.Code										AS EnCurrencyCode,
 		ISNULL(ER.ParentType, 1)					AS CeParentType,
 		BT.BillType									AS BillType,
 		ER.ParentGUID								AS ParentGuid,
 		ER.ParentNumber								AS ParentNumber,
 		CE.TypeGUID									AS CeTypeGuid

	 FROM 
 		ce000  CE 			 
 		INNER JOIN en000 EN	 ON CE.[GUID]	 = EN.ParentGuid
 		LEFT  JOIN ac000 AC  ON AC.[GUID]	 = EN.AccountGUID
 		LEFT  JOIN et000 ET	 ON CE.TypeGUID	 = ET.[GUID]
 		LEFT  JOIN er000 ER	 ON ER.EntryGUID = CE.[GUID]
 		LEFT  JOIN bu000 BU	 ON BU.[GUID]	 = ER.ParentGUID
 		LEFT  JOIN bt000 BT  ON BT.[GUID]	 = BU.TypeGUID
 		LEFT  JOIN my000 MY  ON MY.[GUID]	 = EN.CurrencyGUID
 		LEFT  JOIN ch000 CH  ON CH.[GUID]	 = ER.ParentGUID
 		LEFT  JOIN nt000 NT  ON NT.[GUID]	 = CH.TypeGUID
 
	 WHERE 
		EN.AccountGuid = @POSAccount
		AND ER.ParentType NOT IN (@EntryGeneratedFromPOSExternalOperations, @EntryGeneratedFromPOSTicket, 
								  @EntryGeneratedFromPOSBankCardTicket, @EntryGeneratedFromGCCTaxReSaleTicket,
								  @EntryGeneratedFromPOSSalesReturnTicket, @EntryGeneratedFromRecieveCouponToCustomer, 
								  @EntryGeneratedFromRecieveCardToCustomer, @EntryGeneratedFromPayCouponFromCustomer, 
								  @EntryGeneratedFromPayCardFromCustomer, @EntryGeneratedFromGCCTaxSaleTicket,
								  @EntryGeneratedFromDeliveryFeeOrder, @EntryGeneratedFromDownPaymentOrder,
								  @EntryGeneratedFromExpiredReturnCoupon)
		AND ISNULL(BU.[GUID], 0x0) NOT IN (SELECT BillGUID FROM #BillGeneratedFromPOS)
		AND EN.[Date] BETWEEN @StartDate AND @EndDate
 
	 ORDER BY 
		EN.[Date] ,Ce.[Number]
#################################################################
#END
