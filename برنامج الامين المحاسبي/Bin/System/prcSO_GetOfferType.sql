########################################################
CREATE PROCEDURE prcSO_GetOfferType
	@billItemSOGuid [UNIQUEIDENTIFIER]
AS
	SELECT TOP 1 
		so.Type 
	FROM 
		vwSOAccounts	AS soac
		INNER JOIN vwSpecialOffers AS so ON so.Guid = soac.SOGuid
	WHERE 	
		soac.soDetailGuid = @BillItemSoGuid
#########################################################
CREATE PROC prcSO_UsedBillTypes
	@SpecialOfferGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	
	SELECT DISTINCT 
		bt.btGUID AS BillTypeGuid, 1 AS Sort
	FROM 
		vwBt AS bt
		INNER JOIN bu000 AS bu ON bu.TypeGuid = bt.btGUID
		INNER JOIN bi000 AS bi ON bi.ParentGuid = bu.GUID
		INNER JOIN SOItems000 AS soi ON soi.GUID = bi.soGUID
		INNER JOIN vwSpecialOffers AS so ON so.GUID = soi.SpecialOfferGUID
	WHERE 
		so.GUID = @SpecialOfferGuid

	UNION ALL
	SELECT DISTINCT 
		bt.btGUID AS BillTypeGuid, 2 AS Sort 
	FROM 
		vwBt AS bt
		INNER JOIN bu000 AS bu ON bu.TypeGuid = bt.btGUID
		INNER JOIN bi000 AS bi ON bi.ParentGuid = bu.GUID
		INNER JOIN SOOfferedItems000 AS sooi ON sooi.GUID = bi.soGUID
		INNER JOIN vwSpecialOffers AS so On so.GUID = sooi.SpecialOfferGUID
	WHERE 
		so.GUID = @SpecialOfferGuid

	UNION ALL
	SELECT DISTINCT 
		bt.btGUID AS BillTypeGuid, 3 AS Sort 
	FROM 
		vwBt as bt
		INNER JOIN bu000 AS bu ON bu.TypeGuid = bt.btGUID
		INNER JOIN bi000 AS bi ON bi.ParentGuid = bu.GUID
		INNER JOIN ContractBillItems000 as ContBi ON ContBi.BillItemGuid = bi.Guid
		INNER JOIN SOItems000 AS soi ON soi.GUID = ContBi.ContractItemGuid
		INNER JOIN vwSpecialOffers AS so ON so.GUID = soi.SpecialOfferGUID
	WHERE 
		so.GUID = @SpecialOfferGuid
	ORDER BY  
		Sort
-- SORT:  1:SOItems BILL TYPE  
--		  2:SOOfferedItems BILL TYPE
--		  3:ContractBillItems BILL TYPE
#########################################################
CREATE PROC prcSO_CanEditBillDate
      @SpecialOfferGUID UNIQUEIDENTIFIER,
      @NewEndDate DATETIME
AS
      DECLARE
            @SOType INT,
            @Used BIT
            
      SELECT @SOType = [Type] FROM SpecialOffers000 WHERE [GUID] = @SpecialOfferGUID
            
      IF @SOType <> 3
      BEGIN
            IF EXISTS(
                  SELECT 
                        1
                  FROM 
                        vwBu bu
                        INNER JOIN bi000 bi ON bi.ParentGUID = bu.buGUID
                        INNER JOIN (SELECT [GUID] FROM SOItems000 
                                          WHERE SpecialOfferGUID = @SpecialOfferGUID
                                          UNION ALL
                                          SELECT [GUID] FROM SOOfferedItems000
                                          WHERE SpecialOfferGUID = @SpecialOfferGUID) soi ON bi.SOGuid = soi.[GUID]
                  WHERE 
                        bu.buDate > @NewEndDate)
            BEGIN
                  SELECT @Used = 1
            END
            ELSE
            BEGIN
                  SELECT @Used = 0
            END
      END
      
      IF @SOType = 3
      BEGIN
            IF EXISTS(SELECT 
                  1
            FROM 
                  vwBu bu
                  INNER JOIN bi000 bi ON bi.ParentGUID = bu.buGUID
                  INNER JOIN ContractBillItems000 cbi ON cbi.BillItemGuid = bi.[GUID]
                  INNER JOIN SOItems000 soi ON soi.[GUID] = cbi.ContractItemGuid
            WHERE 
                  bu.buDate > @NewEndDate)
            BEGIN
                  SELECT @Used = 1
            END
            ELSE
            BEGIN
                  SELECT @Used = 0
            END
      END
      
      SELECT @Used AS Used
########################################################
#END    
