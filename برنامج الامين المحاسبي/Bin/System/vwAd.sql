#########################################################
CREATE VIEW vtAd
AS
	SELECT * FROM [Ad000]

#########################################################
CREATE VIEW vbAd
AS
	SELECT * FROM [vtAd]
#########################################################

CREATE VIEW vwAd
AS   
	SELECT  
		[GUID] AS [adGuid],  
		[ParentGUID] AS [adAssGuid],  
		[SN] AS [adSN],  
		[InDate] AS [adInDate], 
		[InVal] AS [adInVal],  
		[InCurrencyGUID] AS [adInCurrencyGUID],  
		[InCurrencyVal] AS [adInCurrencyVal],  
		[OutDate] AS [adOutDate], 
		[OutVal] AS [adOutVal],  
		[OutCurrencyGUID] AS [adOutCurrencyGUID],  
		[OutCurrencyVal] AS [adOutCurrencyVal],  
		[AddedVal] AS [adAddedVal],  
		[DeductVal] AS [adDeductVal],  
		[MaintenVal] AS [adMaintenVal],  
		[DeprecationVal] AS [adDeprecationVal],  
		[PurchaseOrder] AS [adPurchaseOrder],  
		[PurchaseOrderDate] AS [adPurchaseOrderDate],  
		[Model] AS [adModel],  
		[Origin] AS [adOrigin],  
		[Company] AS [adCompany],  
		[ManufDate] AS [adManufDate],  
		[Supplier] AS [adSupplier],  
		[LKind] AS [adLKind],  
		[LCNum] AS [adLCNum],  
		[LCDate] AS [adLCDate],  
		[ImportPermit] AS [adImportPermit],  
		[ArrvDate] AS [adArrvDate],  
		[ArrvPlace] AS [adArrvPlace],  
		[CustomsStatement] AS [adCustomStatement],  
		[CustomsCost] AS [adCustomCost],  
		[CustomsDate] AS [adCustomDate],  
		[GUARANTEE_BEGINDATE] AS [adGuarantyBeginDate],
		[GUARANTEE_ENDDATE] AS [adGuarantyEndDate],
		[ContractGuaranty] AS [adContractGuaranty],  
		[ContractGuarantyDate] AS [adContractGuarantyDate],  
		[ContractGuarantyEndDate] AS [adContractGuarantyEndDate],  
		[JobPolicy] AS [adJobPolicy],  
		[Notes] AS [adNotes],  
		[Number] AS [Number], 
		[ScrapValue] AS [adScrapValue], 
		[Status] AS [adStatus],  
		[DailyRental] AS [adDailyRental], 
		[BARCODE] AS [adBarCode],
		[coGuid] AS [adCoGuid],
		[brGuid] AS [adBrGuid],
		[SnGuid] AS [adSnGuid],
		[Security] AS [adSecurity],
		[Age] AS [adAge],
		[BillGUID] AS [adBillGUID]
	FROM  
		vbAd AS [AD]  
		
#########################################################
#END

