#########################################################
CREATE FUNCTION CanRepriceManufacturingMaterial(@MaterialGuid UNIQUEIDENTIFIER)
RETURNS INT
AS
BEGIN
	--ãÇÏÉ ãÓÊæÏÚíÉ Ãæ ÎÏãíÉ ÈÏæä ÊÍÏíÏ ÎíÇÑ ÅÎÑÇÌ ÇáãæÇÏ ÇáÎÏãíÉ Ýí ÎíÇÑÇÊ ÇáÊÕäíÚ 
	IF((SELECT [Type] FROM mt000 WHERE GUID = @MaterialGuid) = 1) 
		if(ISNULL((SELECT dbo.fnOption_GetValue('AmnCostRep_ShowPrice', 2)), '0') = '0')
			RETURN 0;

	RETURN (SELECT Type FROM mt000 WHERE guid = @MaterialGuid)
END
#########################################################
CREATE PROCEDURE prcManufac_reGenBills
	@StartDate [DATETIME], 
    @EndDate [DATETIME], 
    @PriceType [INT]  ,
	@ShowPriceforMatService [BIT] = 0
AS
      SET NOCOUNT ON  

	IF EXISTS( SELECT TOP 1 cu.AccountGUID
					FROM cu000 cu
					INNER JOIN vwAcCu ac on ac.GUID = cu.AccountGUID
					INNER JOIN mx000 mn on mn.AccountGUID = cu.AccountGUID
					WHERE ac.CustomersCount > 1)
	BEGIN
		DECLARE @DiscAccoutnGUID UNIQUEIDENTIFIER;
		SELECT TOP 1  @DiscAccoutnGUID = cu.AccountGUID
		FROM cu000 cu
			INNER JOIN vwAcCu ac on ac.GUID = cu.AccountGUID
			INNER JOIN mx000 mn on mn.AccountGUID = cu.AccountGUID
		WHERE ac.CustomersCount > 1

		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT 1, 0, 'AmnE0052: [' + CAST(@DiscAccoutnGUID AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
		
		RETURN 
	END 

      EXEC prcBill_rePost   
      EXEC prcDisableTriggers 'bi000'    
      EXEC prcDisableTriggers 'di000'  
  
      SELECT  
            Bu.Date 
            ,Mi.MatGuid 
            ,CASE @PriceType 
				WHEN 1 THEN [dbo].[fnMaterial_GetPrice](Mi.MatGuid, @PriceType, Bu.Date) 
			ELSE 0 END Price  
      INTO #DatesAvgs  
      FROM Bi000 Bi  
      INNER JOIN Bu000 Bu ON Bi.ParentGuid = Bu.Guid 
      INNER JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid 
      INNER JOIN Mb000 Mb ON Bu.Guid = Mb.BillGuid 
      INNER JOIN Mn000 Mn ON Mn.Guid = Mb.ManGuid 
      INNER JOIN Mi000 Mi ON Mi.ParentGuid = Mn.Guid AND Mi.MatGuid = Bi.MatGuid 
      INNER JOIN Mt000 Mt ON Mt.Guid = Mi.MatGuid 
      WHERE Mb.Type IN (0, 2) 
            AND Mn.Date BETWEEN @StartDate AND @EndDate 
      GROUP BY Bu.Date, Mi.MatGuid 
     
      UPDATE Bi000  
	  SET Price =  
	  --CASE @ShowPriceforMatService
	  --WHEN 0 THEN 
	    CASE (SELECT dbo.CanRepriceManufacturingMaterial(mt.GUID))
		   WHEN 0 THEN  
		    (CASE @PriceType   
			-- ÓÚÑ ÇáßáÝÉ  
			WHEN 1 THEN  
					DatesAvgs.Price --[dbo].[fnMaterial_GetPrice](Mi.MatGuid, @PriceType, Bu.Date)  
					* (CASE [mi].[unity]  
									WHEN 2 THEN [mt].[unit2Fact]    
									WHEN 3 THEN [mt].[unit3Fact]    
									ELSE 1    
							END) 
			-- ÓÚÑ ÈØÇÞÉ ÇáäãæÐÌ 
			WHEN 3 THEN 
				(select [Price] * [MI000].[CurrencyVal] FROM 
					MI000 inner join MN000  on MI000.ParentGUID = MN000.guid 
					where MN000.TYPE=0 AND MI000.MatGuid = Bi.MatGuid AND MN000.FormGUID = mn.FormGUID
					AND MN000.Date BETWEEN @StartDate AND @EndDate ) 
			-- ÇáÓÚÑ ÇáÇÝÊÑÇÖí 
			WHEN 4 THEN   
					CASE Bt.DefPrice  
							WHEN 2            THEN CASE bi.Qty + bi.BonusQnt    WHEN 0 THEN 0 ELSE ((bi.Price * bi.Qty) - bi.Profits - (bi.Qty * bi.Discount* bt.bDiscAffectProfit) + (bi.Qty * bi.Extra * bt.bExtraAffectProfit)) / (bi.Qty + bi.BonusQnt) END   
							WHEN 4            THEN CASE bi.Unity WHEN 1 THEN mt.Whole WHEN 2 THEN mt.Whole2   ELSE mt.Whole3          END   
							WHEN 8            THEN CASE bi.Unity WHEN 1 THEN mt.Half  WHEN 2 THEN mt.Half2          ELSE mt.Half3           END   
							WHEN 16           THEN CASE bi.Unity WHEN 1 THEN mt.Export      WHEN 2 THEN mt.Export2  ELSE mt.Export3   END   
							WHEN 32           THEN CASE bi.Unity WHEN 1 THEN mt.Vendor      WHEN 2 THEN mt.Vendor2  ELSE mt.Vendor3   END   
							WHEN 64           THEN CASE bi.Unity WHEN 1 THEN mt.Retail      WHEN 2 THEN mt.Retail2  ELSE mt.Retail3   END   
							WHEN 128    THEN CASE bi.Unity WHEN 1 THEN mt.EndUser  WHEN 2 THEN mt.EndUser2 ELSE mt.EndUser3 END     
							WHEN 256    THEN bi.Price   
							WHEN 512    THEN CASE bi.Unity WHEN 1 THEN mt.LastPrice      WHEN 2 THEN mt.LastPrice2     ELSE mt.LastPrice3      END   
							ELSE 0   
					END 
			-- ÇáÓÚÑ ÇáæÓØí ÇáãÑÌÍ ÇáËÇÈÊ  
			WHEN 5 THEN 
				[dbo].fnGetOutbalanceAveragePrice(Mt.[GUID], Bu.[Date]) 
			ELSE   
						[dbo].[fnMaterial_GetPrice](Mi.MatGuid, @PriceType, @EndDate) * (CASE [mi].[unity]  WHEN 2 THEN [mt].[unit2Fact]     
									WHEN 3 THEN [mt].[unit3Fact]    
									ELSE 1    
							END)  
				END)
			WHEN 1 THEN bi.Price 
			END
      FROM Bi000 Bi  
      INNER JOIN Bu000 Bu ON Bi.ParentGuid = Bu.Guid  
      INNER JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid  
      INNER JOIN Mb000 Mb ON Bu.Guid = Mb.BillGuid  
      INNER JOIN Mn000 Mn ON Mn.Guid = Mb.ManGuid  
      INNER JOIN Mi000 Mi ON Mi.ParentGuid = Mn.Guid AND Mi.MatGuid = Bi.MatGuid  
      INNER JOIN Mt000 Mt ON Mt.Guid = Mi.MatGuid  
      INNER JOIN #DatesAvgs DatesAvgs ON DatesAvgs.Date = Bu.Date AND DatesAvgs.MatGuid = Mi.MatGuid 
      WHERE Mb.Type IN (0, 2)  
            AND Mn.Date BETWEEN @StartDate AND @EndDate  
  
      EXEC [prcCheckDB_bu_Sums] 1  

        UPDATE Di000 SET  
			CustomerGUID =  ISNULL(cu.GUID, 0x0)
        FROM Di000 Di  
        INNER JOIN Bu000 Bu ON Di.ParentGuid = Bu.Guid  
        INNER JOIN Mb000 Mb ON Bu.Guid = Mb.BillGuid  
        INNER JOIN Mn000 Mn ON Mn.Guid = Mb.ManGuid  
        INNER JOIN Mx000 Mx ON Mx.ParentGuid = Mn.Guid AND Mx.AccountGuid = Di.AccountGuid  
		LEFT JOIN cu000 AS Cu ON cu.AccountGUID = Mx.AccountGuid

        UPDATE Di000 SET  
                  Extra = CASE WHEN Mx.Discount > 0 THEN mx.Extra ELSE 0 END  
                  ,Discount = CASE WHEN Mx.Discount < 0 THEN Bu.Total * -Mx.Discount / 100 ELSE 0 END  
        FROM Di000 Di  
        INNER JOIN Bu000 Bu ON Di.ParentGuid = Bu.Guid  
        INNER JOIN Mb000 Mb ON Bu.Guid = Mb.BillGuid  
        INNER JOIN Mn000 Mn ON Mn.Guid = Mb.ManGuid  
        INNER JOIN Mx000 Mx ON Mx.ParentGuid = Mn.Guid AND Mx.AccountGuid = Di.AccountGuid  
        WHERE Mn.Flags & 1 = 1  
                  AND Mb.Type = 0  
                  AND Mx.Discount <> 0  
                  AND Mn.Date BETWEEN @StartDate AND @EndDate  
          
        DELETE FROM Di000 WHERE Guid IN  
        (  
                  SELECT Di.Guid  
                  FROM Di000 Di  
                  INNER JOIN Bu000 Bu ON Di.ParentGuid = Bu.Guid  
                  INNER JOIN Mb000 Mb ON Bu.Guid = Mb.BillGuid  
                  INNER JOIN Mn000 Mn ON Mn.Guid = Mb.ManGuid  
                  WHERE Mn.Flags & 1 = 1  
                          AND Mb.Type = 0  
                          AND Di.Extra = 0  
                          AND Di.Discount = 0  
                          AND Mn.Date BETWEEN @StartDate AND @EndDate  
        )  
          
        EXEC [prcCheckDB_bu_Sums] 1  
        
      UPDATE Bi000  
            SET Price = CASE @PriceType   
                                    WHEN 3 THEN ((select [Price] * [MI000].[CurrencyVal] * [MI000].[Percentage] FROM 
													MI000 inner join MN000  on MI000.ParentGUID = MN000.guid 
													where MN000.TYPE=0 AND MI000.MatGuid = Bi.MatGuid AND MN000.FormGUID = mn.FormGUID
													AND MN000.Date BETWEEN @StartDate AND @EndDate ) )/100   
                                    ELSE   
                                      ( ( (OutBills.Total + OutBills.TotalExtra - OutBills.TotalDisc)* [mi].[Percentage])/100)/ Bi.Qty  
                                    END
      FROM Bi000 Bi  
      INNER JOIN Bu000 Bu ON Bi.ParentGuid = Bu.Guid  
      INNER JOIN Mb000 Mb ON Bu.Guid = Mb.BillGuid  
      INNER JOIN Mn000 Mn ON Mn.Guid = Mb.ManGuid  
      INNER JOIN Mi000 Mi ON Mi.ParentGuid = Mn.Guid AND Mi.MatGuid = Bi.MatGuid  
      INNER JOIN Mt000 Mt ON Mt.Guid = Mi.MatGuid  
      INNER JOIN   
      (  
            SELECT Mn.Guid ManGuid  
                        ,SUM(Bu.Total) Total  
                        ,SUM(TotalExtra) TotalExtra  
                        ,SUM(TotalDisc) TotalDisc  
            FROM Mn000 Mn  
            INNER JOIN Mb000 Mb ON Mb.ManGuid = Mn.Guid  
            INNER JOIN Bu000 Bu ON Mb.BillGuid = Bu.Guid  
            WHERE Mb.Type IN (0, 2)  
            GROUP BY Mn.Guid  
      )OutBills ON OutBills.ManGuid = Mn.Guid  
      WHERE Mb.Type = 1  
            AND Mn.Date BETWEEN @StartDate AND @EndDate  
        
      EXEC [prcCheckDB_bu_Sums] 1  
        
      EXEC prcDisableTriggers 'di000'  
      EXEC prcEnableTriggers 'bi000' 
      
 --- regeneration of Entry 
EXEC prcManufac_ReGenBillEntry @StartDate ,@EndDate
---
/*      
	DECLARE 
		@c CURSOR, 
		@g [UNIQUEIDENTIFIER] 
	SET @c = CURSOR FAST_FORWARD FOR	 
		SELECT 
			[mnGUID] 
		FROM 
			[vwMn] 
		WHERE 
			[mnDate] BETWEEN @StartDate AND @EndDate AND  
			[mnType] = 1 
		ORDER BY 
			[mnDate] 
		 
	OPEN @c FETCH FROM @c INTO @g 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
	 
		DECLARE @OutBillGuid		UNIQUEIDENTIFIER 
		DECLARE @InBillGuid			UNIQUEIDENTIFIER 
		DECLARE @OutSemiBillGuid	UNIQUEIDENTIFIER 
		SELECT @OutBillGuid			= BillGuid FROM mb000 WHERE ManGuid = @g AND Type = 0 
		SELECT @InBillGuid			=  BillGuid FROM mb000 WHERE ManGuid = @g AND Type = 1 
		SELECT @OutSemiBillGuid		=  BillGuid FROM mb000 WHERE ManGuid = @g AND Type = 2 
		 
		DECLARE @OutBillNumber		INT 
		DECLARE @InBillNumber		INT 
		DECLARE @OutSemiBillNumber	INT 
		SELECT @OutBillNumber		=	Number FROM Bu000 WHERE Guid = @OutBillGuid 
		SELECT @InBillNumber		=	Number FROM Bu000 WHERE Guid = @InBillGuid 
		SELECT @OutSemiBillNumber	=	Number FROM Bu000 WHERE Guid = @OutSemiBillGuid 
		 
		EXEC [prcManufac_GenBills] @g, 1, @PriceType, 0, 0, 0, 0, @InBillNumber, @OutBillNumber, @OutSemiBillNumber, @InBillGuid, @OutBillGuid, @OutSemiBillGuid  
		FETCH FROM @c INTO @g 
	END 
	 
	CLOSE @c DEALLOCATE @c 
	*/ 
#########################################################
#END