#########################################################
CREATE TRIGGER trg_ms000_CheckBalance 
	ON  ms000  FOR UPDATE, INSERT 
	NOT FOR REPLICATION
AS  
	IF @@ROWCOUNT = 0 RETURN 	

	SET NOCOUNT ON
	
	IF UPDATE(Qty)  
		
		IF dbo.fnOption_GetInt('AmnCfg_MatQtyByStore', '0') = 1 
		BEGIN
			DECLARE @isCalcPurchaseOrderRemindedQty BIT
			SELECT @isCalcPurchaseOrderRemindedQty = dbo.fnOption_GetInt('AmnCfg_CalcPurchaseOrderRemindedQty', '0')

			INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
			SELECT   
				2,   
				0,   
				'AmnW0062: ' + cast([i].[GUID] as NVARCHAR(128)) + ' Product balance is less than zero, ' + dbo.fnMaterial_GetCodeName( [i].[MatGUID]), 
				[i].[GUID]   
			FROM   
				[inserted] AS [i] 
				INNER JOIN [mt000] AS [mt] ON [mt].[GUID] = [i].[MatGUID]
				LEFT JOIN [deleted] AS [d] ON [d].[GUID] = [i].[GUID]
			WHERE   
				(([i].[Qty] + (CASE @isCalcPurchaseOrderRemindedQty 
								  WHEN 1 THEN [dbo].[fnGetPurchaseOrderRemaindedQty](i.MatGUID, i.StoreGUID, 0x0) 
								  ELSE 0 
							 END)) < -dbo.fnGetZeroValueQTY()) 
				AND 
				( [d].[GUID] IS NULL OR [i].[Qty] < [d].[Qty] )
				AND 
				[mt].[Type] <> 1 -- €Ì— Œœ„Ì…  

			INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])   
			SELECT   
				2,   
				0,   
				'AmnW0063: ' + cast([i].[GUID] as NVARCHAR(128)) + ' Product balance is less than minimum, ' + dbo.fnMaterial_GetCodeName( [i].[MatGUID]), 
				[i].[GUID]   
			FROM   
				[inserted] AS [i] 
				INNER JOIN [mt000] AS [mt] ON [mt].[GUID] = [i].[MatGUID]  
				LEFT JOIN [deleted] AS [d] ON [d].[GUID] = [i].[GUID]					
			WHERE   
				(([i].[Qty] + (CASE @isCalcPurchaseOrderRemindedQty 
								  WHEN 1 THEN [dbo].[fnGetPurchaseOrderRemaindedQty](i.MatGUID, i.StoreGUID, 0x0) 
								  ELSE 0 
							 END)) < [mt].[Low]) 
				AND 
					[mt].[Low] <> 0
				AND
					( [d].[GUID] IS NULL OR [i].[Qty] < [d].[Qty] )
				AND 
					[mt].[Type] <> 1 -- €Ì— Œœ„Ì…  

			INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])   
			SELECT   
				2,   
				0,   
				'AmnW0064: ' + cast([i].[GUID] as NVARCHAR(128)) + ' Product balance is less than ordering limit, ' + dbo.fnMaterial_GetCodeName( [i].[MatGUID]), 
				[i].[GUID]   
			FROM   
				[inserted] AS [i] 
				INNER JOIN [mt000] AS [mt] ON [mt].[GUID] = [i].[MatGUID]  
				LEFT JOIN [deleted] AS [d] ON [d].[GUID] = [i].[GUID]
			WHERE   
				(([i].[Qty] + (CASE @isCalcPurchaseOrderRemindedQty 
								  WHEN 1 THEN [dbo].[fnGetPurchaseOrderRemaindedQty](i.MatGUID, i.StoreGUID, 0x0) 
								  ELSE 0 
							 END))< [mt].[OrderLimit]) 
				AND 
					[mt].[OrderLimit] <> 0
				AND
				    ( [d].[GUID] IS NULL OR [i].[Qty] < [d].[Qty] )
				AND 
					[mt].[Type] <> 1 -- €Ì— Œœ„Ì…  
		END 
#########################################################
#END
