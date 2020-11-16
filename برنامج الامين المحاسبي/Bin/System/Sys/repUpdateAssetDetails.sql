############################################################################################
CREATE PROC repUpdateAssetDetails @AdGUID UNIQUEIDENTIFIER, @AdCurrentGUID UNIQUEIDENTIFIER 
AS 
	--INSERT INTO @Tbl   
	-----------------------------------------------------------------  
	UPDATE ad000 SET   
		[PurchaseOrder] = ad.[PurchaseOrder],   
		[PurchaseOrderDate] = ad.[PurchaseOrderDate],   
		[Model] = ad.[Model],   
		[Origin] = ad.[Origin],   
		[Company] = ad.[Company],   
		[ManufDate] = ad.[ManufDate],   
		[Supplier] = ad.[Supplier],   
		[LKind] = ad.[LKind],   
		[LCNum] = ad.[LCNum],   
		[LCDate] = ad.[LCDate],   
		[ImportPermit] = ad.[ImportPermit],   
		[ArrvDate] = ad.[ArrvDate],   
		[ArrvPlace] = ad.[ArrvPlace],   
		[CustomsStatement] = ad.[CustomsStatement],   
		[CustomsCost] = ad.[CustomsCost],   
		[CustomsDate] = ad.[CustomsDate],   
		[ContractGuaranty] = ad.[ContractGuaranty],   
		[ContractGuarantyDate] = ad.[ContractGuarantyDate],   
		[ContractGuarantyEndDate] = ad.[ContractGuarantyEndDate],   
		[JobPolicy] = ad.[JobPolicy],   
		[Notes] = ad.[Notes],   
		[ScrapValue] = ad.[ScrapValue],  
		[dailyrental] = ad.[dailyrental],  
		[SITE] = ad.[SITE],  
		[DEPARTMENT] = ad.[DEPARTMENT], 
		[GUARANTEE] = ad.[GUARANTEE],
		[Security] = ad.[Security], 
		[indate] = ad.[indate],
		[age] = ad.[age], 
		[AddedVal] = ad.[AddedVal],
		[DeductVal] = ad.[DeductVal],
		[MaintenVal] = ad.[MaintenVal],
		[DeprecationVal] = ad.[DeprecationVal]
	FROM  
		(SELECT   
			[PurchaseOrder],   
			[PurchaseOrderDate],   
			[Model],   
			[Origin],   
			[Company],   
			[ManufDate],   
			[Supplier],   
			[LKind],   
			[LCNum],   
			[LCDate],   
			[ImportPermit],   
			[ArrvDate],   
			[ArrvPlace],   
			[CustomsStatement],   
			[CustomsCost],   
			[CustomsDate],   
			[ContractGuaranty],   
			[ContractGuarantyDate],   
			[ContractGuarantyEndDate],   
			[JobPolicy],   
			[Notes],   
			[ScrapValue],  
			[dailyrental], 
			[SITE], 
			[DEPARTMENT], 
			[GUARANTEE],
			[Security],
			[indate],
			[age],
			[AddedVal],
			[DeductVal],
			[MaintenVal],
			[DeprecationVal]
		FROM   
			ad000  
		WHERE   
			  
			ad000.GUID = @AdCurrentGUID) AS ad  
	WHERE   
		ad000.GUID = @adGUID  
#########################################################################################
#END