#################################################################
CREATE PROC prcPDABilling_InitTemplate
		@PDAGUID uniqueidentifier 
AS      
	SET NOCOUNT ON      
	-----------------------------------------------
	DECLARE @IsGCCEnabled BIT = (SELECT [dbo].[fnOption_GetBit]('AmnCfg_EnableGCCTaxSystem', DEFAULT))
	----------------------------------------------- 
	DELETE DistDeviceBt000 WHERE DistributorGUID = @PDAGUID 
	DELETE DistDeviceEt000 WHERE DistributorGUID = @PDAGUID 
	----------------------------------------------- 
	INSERT INTO  DistDeviceBt000 
	( 
			[btGUID], 
			[DistributorGUID], 
			[SortNum], 
			[Name], 
			[Abbrev], 
			[BillType], 
			[DefPrice], 
			[bIsInput], 
			[bIsOutput], 
			[bNoEntry], 
			[bNoPost], 
			[bPrintReceipt], 
			[Type], 
			[StoreGUID],
			[VATSystem] 
	) 
	SELECT   
			[bt].[btGUID], 
			@PDAGUID, 
			[bt].[btSortNum], 
			[bt].[btName], 
			[bt].[btAbbrev], 
			[bt].[btBillType], 
			CASE [bt].[btDefPrice]	WHEN 4		THEN 1		-- Whole Price		«·Ã„·…
									WHEN 8		THEN 2		-- Half Price		‰’› «·Ã„·…
									WHEN 16		THEN 4		-- Export Price		«· ’œÌ—
									WHEN 32		THEN 3		-- Vendor Price		«·„Ê“⁄
									WHEN 64		THEN 5		-- Retail Price		«·„›—ﬁ
									WHEN 128	THEN 6		-- EndUser Price	«·„” Â·ﬂ
									WHEN 2048	THEN 2048	-- CustPrice		”⁄— »ÿ«ﬁ… «·“»Ê‰
									ELSE 1	-- Whole Price
			END,
			[bt].[btIsInput], 
			[bt].[btIsOutput], 
			[bt].[btNoEntry], 
			[bt].[btNoPost], 
			[bt].[btPrintReceipt], 
			[bt].[btType], 
			[bt].[btDefStore],	 
			CASE @IsGCCEnabled WHEN 1 THEN 1 ELSE [bt].[btVatSystem] END
	FROM          
		vwBt AS bt  
		INNER JOIN vwPd AS pd ON bt.btGUID = pd.RefGUID 
	WHERE                  
		bt.btType =  1 	    AND   
		pd.RefType = 1		AND 
		pd.ProfileGUID = @PDAGUID 
	----------------------------------------------- 
	INSERT INTO  DistDeviceEt000 
	( 
			[etGUID], 
			[DistributorGUID], 
			[SortNum], 
			[Name], 
			[Abbrev], 
			[EntryType], 
			[FldDebit], 
			[FldCredit] 
	) 
	SELECT   
			[et].[etGUID], 
			@PDAGUID, 
			0, 
			[et].[etName], 
			[et].[etAbbrev], 
			[et].[etEntryType], 
			[et].[etFldDebit], 
			[et].[etFldCredit] 
	FROM          
		vwEt AS et 
		INNER JOIN vwPd AS pd ON et.etGUID = pd.RefGUID 
	WHERE                  
		et.etEntryType =  0 AND   
		pd.RefType = 2		AND 
		pd.ProfileGUID = @PDAGUID 

/* 
EXEC prcPDABilling_InitTemplate '2C8484AA-EF78-4629-92BF-44731488B3BD' 
*/ 
#################################################################
#END
