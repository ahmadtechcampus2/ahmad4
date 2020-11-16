#########################################################################
CREATE FUNCTION fnGetBillOrderInfo(@BillGUID [UNIQUEIDENTIFIER],@TypeGUID [UNIQUEIDENTIFIER],@BillNumber INT)
	RETURNS TABLE
AS
	RETURN (
			SELECT 
				[costguid]
				,[custguid]
				,[Branch]
				,[PayType]
				,[StoreGuid]
				,[Number]
				,[TypeGuid]
				,[CurrencyVal] 
				,[CurrencyGuid]
				,[Vendor] VendorNo  
				,(SELECT DISTINCT UserNumber FROM Connections WHERE UserGUID =  dbo.fnGetCurrentUserGUID()) SalerNo
				,[bu].CustAccGuid
				,[MatAccGuid]
				,[Notes]
				,[CustomerAddressGUID] 
				,CASE WHEN ([TotalDisc] - [ItemsDisc] ) <= 0 THEN 0 ELSE 
						CASE WHEN [TotalDiscRegardlessItemDisc] = 1 
								THEN ((([TotalDisc] - [ItemsDisc] )/ ([Total])) * 100) 
							ELSE ((([TotalDisc] - [ItemsDisc] )/ ([Total] - [ItemsDisc])) * 100) 
						END
				 END	AS TotalDiscountRatio
				
				,CASE WHEN ([TotalExtra] - [ItemsExtra] ) <= 0 THEN 0 ELSE 
						CASE WHEN [TotalExtraRegardlessItemExtra] = 1 AND  ([TotalExtra] - [ItemsExtra] ) > 0
								THEN ((([TotalExtra] - [ItemsExtra] )/ ([Total])) * 100) 
							ELSE ((([TotalExtra] - [ItemsExtra] )/ ([Total] + [ItemsExtra])) * 100) 
						END 
				 END AS TotalExtraRatio

			FROM [vcbu] bu
			LEFT JOIN [vcBt] bt ON [bu].TypeGUID = [bt].GUID
			WHERE 
				bu.GUID = CASE WHEN @BillGUID = 0x0 THEN bu.GUID ELSE @BillGUID END
				AND bu.TypeGUID = CASE WHEN @TypeGUID = 0x0 THEN bu.TypeGUID ELSE @TypeGUID END
				AND bu.Number = CASE WHEN @BillNumber <= 0 THEN bu.Number ELSE @BillNumber END
		)
#########################################################################
#END