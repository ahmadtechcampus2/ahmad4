######################################
CREATE PROC prcDistModifyDeviceOptions
	@DistGuid		UNIQUEIDENTIFIER = 0x0, 
	@HiGuid			UNIQUEIDENTIFIER = 0x0, 
	@TypeGuid		UNIQUEIDENTIFIER = 0x0, 
	@FromDistGuid	UNIQUEIDENTIFIER = 0x0, 
	@ModifyFlds		NVARCHAR(100)	 = '', 
	@OutRouteVisits	INT	 = -1, 
	@PrntPrice		INT	 = -1	 
AS 
	SET NOCOUNT ON 
	CREATE TABLE [#Dists]( [DistGuid] 	[UNIQUEIDENTIFIER], [Security] 	 [INT])    
	INSERT INTO [#Dists] ( [DistGuid], [Security]) EXEC [GetDistributionsList] @DistGuid, @HiGuid     
	IF(@ModifyFlds = '' AND @PrntPrice = -1 AND @OutRouteVisits = -1)  
	BEGIN 
		Update DTo  
		set 
			-----------------«⁄œ«œ«  «·ÃÂ«“ 
			DTo.[SuperVisorPassword] = DFrm.[SuperVisorPassword], 
			--------------------- ŒÌ«—«    ’œÌ— «·ÃÂ«“>> ŒÌ«—«  
			DTo.[ExportEmptyMaterialFlag]= DFrm.[ExportEmptyMaterialFlag], 
			DTo.[ExportSerialNumFlag]	 = DFrm.[ExportSerialNumFlag], 
			DTo.[ExportOffers]			 = DFrm.[ExportOffers], 
			DTo.[ExportAfterZeroAcc]	 = DFrm.[ExportAfterZeroAcc], 
			DTo.[ExportStoreFlag]		 = DFrm.[ExportStoreFlag], 
			DTo.[ExportStoreGuid]		 = DFrm.[ExportStoreGuid],
			--added 
			DTo.[HideEmptyMatInEntryBills] = DFrm.[HideEmptyMatInEntryBills],
			DTo.[MatCondGUID] = DFrm.[MatCondGUID],
			DTo.[MatSortFld] = DFrm.[MatSortFld],
			DTo.[MatGroupGUID] = DFrm.[MatGroupGUID],
			-------------------------’›Õ… ⁄«„
			DTo.[VisitPerDay] = DFrm.[VisitPerDay],
			DTo.[CanUseGPRS] = DFrm.[CanUseGPRS],
			DTo.[VerificationStore] = DFrm.[VerificationStore],
			DTo.[GPRSTransferType] = DFrm.[GPRSTransferType],
			-------------------------ŒÌ«—«   ’œÌ— «·“»«∆‰ >> ŒÌ«—«  
			DTo.[ExportAllCustDetailFlag]= DFrm.[ExportAllCustDetailFlag], 
			DTo.[ExportCustInRouteOnly]	 = DFrm.[ExportCustInRouteOnly], 
			DTo.[ExportCustAcc]			 = DFrm.[ExportCustAcc], 
			DTo.[ExportCustAccDays]		 = DFrm.[ExportCustAccDays], 
			DTo.[GlStartDate]			 = DFrm.[GlStartDate], 
			DTo.[GlEndDate]				 = DFrm.[GlEndDate], 
			DTo.[ExportCustAccDaysNumber]= DFrm.[ExportCustAccDaysNumber], 
			DTo.[ExportDetailedCustAcc]	 = DFrm.[ExportDetailedCustAcc], 
			---added
			DTo.[CustCondGUID] = DFrm.[CustCondGUID],
			DTo.[CustSortFld] = DFrm.[CustSortFld],
			--------------------ŒÌ«—«  «·«” Ì—«œ 
			DTo.[CustAccGuid] 			= DFrm.[CustAccGuid], 
			DTo.[LastBuNumber]			= DFrm.[LastBuNumber], 
			DTo.[LastEnNumber]			= DFrm.[LastEnNumber], 
			DTo.[UploadPassWord]		= DFrm.[UploadPassWord], 
			DTo.[AutoPostBill] 			= DFrm.[AutoPostBill], 
			DTo.[AutoGenBillEntry] 		= DFrm.[AutoGenBillEntry], 
			--added
			DTo.[ResetDaily] 		= DFrm.[ResetDaily], 
		    ---------------ŒÌ«—«  «·“Ì«—…  
			DTo.[SpecifyOrder]			= DFrm.[SpecifyOrder], 
			DTo.[ShowTodayRoute]		= DFrm.[ShowTodayRoute], 
			DTo.[AccessByBarcode]		= DFrm.[AccessByBarcode], 
			DTo.[EndVisitByBarcode]		= DFrm.[EndVisitByBarcode], 
			DTo.[AccessByRFID]			= DFrm.[AccessByRFID], 
			DTo.[CustBalanceByJobCost]	= DFrm.[CustBalanceByJobCost], 
			DTo.[CustBarcodeHasValidate]= DFrm.[CustBarcodeHasValidate], 
			DTo.[CanChangeCustBarcode]	= DFrm.[CanChangeCustBarcode], 
			DTo.[CanAddCustomer]		= DFrm.[CanAddCustomer], 
			DTo.[ChangeCustCard]		= DFrm.[ChangeCustCard], 
			DTo.[IgnoreNoDetailsVisits] = DFrm.[IgnoreNoDetailsVisits], 
			DTo.[OutRouteVisitsNumber]	= DFrm.[OutRouteVisitsNumber],	 
			--------------------ŒÌ«—«  «·›« Ê—… 
			DTo.[CanChangePrice]	= DFrm.[CanChangePrice], 
			DTo.[UseCustLastPrice]	= DFrm.[UseCustLastPrice], 
			DTo.[CheckBillOffers]	= DFrm.[CheckBillOffers], 
			DTo.[CanUpdateOffer]	= DFrm.[CanUpdateOffer], 
			DTo.[CanAddBonus]		= DFrm.[CanAddBonus], 
			DTo.[CanUpdateBill]		= DFrm.[CanUpdateBill], 
			DTo.[CanDeleteBill]		= DFrm.[CanDeleteBill],	 
			DTo.[AddMatByBarcode]	= DFrm.[AddMatByBarcode],	 
			DTo.[OutNegative]		= DFrm.[OutNegative], 
			DTo.[NoOvertakeMaxDebit]= DFrm.[NoOvertakeMaxDebit], 
			DTo.[PrintPrice]		= DFrm.[PrintPrice], 
			DTo.[DefaultPayType]	= DFrm.[DefaultPayType], 
			DTo.[ItemDiscType]		= DFrm.[ItemDiscType], 
			----------------------‰Ê«›– «·»—‰«„Ã 
			DTo.[UseStockOfCust]	= DFrm.[UseStockOfCust], 
			DTo.[ShowCustInfo]		= DFrm.[ShowCustInfo], 
			DTo.[ShowBills]			= DFrm.[ShowBills], 
			DTo.[ShowEntries]		= DFrm.[ShowEntries], 
			DTo.[UseShelfShare]		= DFrm.[UseShelfShare], 
			DTo.[UseActivity]		= DFrm.[UseActivity], 
			DTo.[UseCustTarget]		= DFrm.[UseCustTarget], 
			DTo.[ShowQuestionnaire] = DFrm.[ShowQuestionnaire] 
		FROM  
			Distributor000 AS DTo  
			INNER JOIN Distributor000 AS DFrm ON DFrm.Guid = @FromDistGuid   
			INNER JOIN #Dists AS s ON s.DistGuid = dTo.Guid		 
		WHERE 
			DTo.TypeGuid = @TypeGuid OR @TypeGuid = 0x0 
  
		Delete  
			Distdd000  
		FROM  
			Distdd000 AS dd 
			INNER JOIN Distributor000 AS dr  ON dr.Guid = dd.DistributorGuid 
			INNER JOIN #Dists AS s ON s.DistGuid = dr.Guid		 
		Where  
			dr.TypeGuid = @TypeGuid OR @TypeGuid = 0x0 
			AND dd.DistributorGuid <> @FromDistGuid 
  
		DECLARE @C			CURSOR, 
				@DisGuid	UNIQUEIDENTIFIER 
		SET @C = CURSOR FAST_FORWARD FOR  
				SELECT DistGuid From #Dists AS ds INNER JOIN Distributor000 AS dr ON dr.Guid = ds.DistGuid WHERE TypeGuid = @TypeGuid OR @TypeGuid = 0x0 
		OPEN @C FETCH FROM @C INTO @DisGuid 
		WHILE @@FETCH_STATUS = 0   
		BEGIN  			 
			INSERT INTO Distdd000 (Number, Guid, DistributorGuid, ObjectType, ObjectGuid, ObjectNumber) 
			Select Number, newId(), @DisGuid, ObjectType, ObjectGuid, ObjectNumber  
		    From  
				Distdd000  
			Where 
	   	    	 DistributorGUID = @FromDistGuid	   	     
	   	    FETCH FROM @c INTO @DisGuid 
		END
		CLOSE @C
		DEALLOCATE @C
	END 
	 
	IF(@ModifyFlds	<> '' OR @PrntPrice > -1 OR @OutRouteVisits > -1 )  
	BEGIN 
		---------------------ŒÌ«—«  «·“Ì«—… 
		DECLARE @SpecifyOrder			INT, -- ÕœÌœ  ”·”· ⁄„·Ì«  «·“Ì«—…  
				@ShowTodayRoute			INT, --«ŸÂ«— «·Œÿ «·ÌÊ„Ì 
				@CustBalanceByJobCost	INT, --«·«—’œ… ⁄‰œ „—ﬂ“ «·ﬂ·›… 
				@AccessByBarcode		INT, --»œ«Ì… «·“Ì«—… ⁄‰ ÿ—Ìﬁ —„“ «·»«—ﬂÊœ 
				@EndVisitByBarcode		INT, --«‰Â«¡ «·“Ì«—… ⁄‰ ÿ—Ìﬁ —„“ «·»«—ﬂÊœ 
				@AccessByRFID			INT,	--»œ«Ì… «·“Ì«—… ⁄‰ ÿ—Ìﬁ „ÊÃ«  «·—«œÌÊ 
				@CustBarcodeHasValidate INT, --»«—ﬂÊœ «·“»Ê‰ ·Â Œ«‰…  Õﬁﬁ 
				@CanChangeCustBarcode	INT, --«·”„«Õ » €ÌÌ— »«—ﬂÊœ «·“»Ê‰ 
				@CanAddCustomer			INT, --«·”„«Õ »≈÷«›… “»Ê‰  
				@ChangeCustCard			INT, --«·”„«Õ » €ÌÌ— »«—ﬂÊœ «·“»Ê‰ 
				@IgnoreNoDetailsVisits	INT, -- Ã«Â· «·“Ì«—«  «· Ì ·Ì” ·Â«  ›«’Ì· 
				@OutRouteVisitsNumber	INT --⁄œœ «·“Ì«—«  «·Œ«—ÃÌ… «·„”„ÊÕ… 
		--------------------ŒÌ«—«  «·›« Ê—… 
		DECLARE @CanChangePrice		INT, --«·”„«Õ » €ÌÌ— ”⁄— «·»Ì⁄ 
				@UseCustLastPrice	INT, --«” Œœ«„ «Œ— ”⁄— “»Ê‰  
				@CheckBillOffers	INT, --›Õ’  Õﬁﬁ «·⁄—Ê÷ 
				@CanUpdateOffer		INT, --«·”„«Õ » ⁄œÌ· Âœ«Ì« «·⁄—÷ 
				@CanAddBonus		INT, --«·”„«Õ »≈÷«›… Âœ«Ì« ··›« Ê—… 
				@CanUpdateBill		INT, --«·”„«Õ » ⁄œÌ· ›« Ê—… 
				@CanDeleteBill		INT, --«·”„«Õ »Õ–› ›« Ê—… 
				@AddMatByBarcode	INT, --«÷«›… „«œ… ⁄‰ ÿ—Ìﬁ —„“ «·»«—ﬂÊœ 
				@OutNegative		INT, --«·”„«Õ »«·«Œ—«Ã «·”«·» 
				@NoOvertakeMaxDebit INT, --«·”„«Õ » Ã«Ê“ œÌ‰ «·“»«∆‰ 
				@PrintPrice			INT, --ÿ»«⁄… «·”⁄— ›Ì «·›« Ê—… 
				@ItemDiscType		INT, --Õ”„ «·«ﬁ·«„ 
				@DefaultPayType		INT --ÿ—Ìﬁ… «·œ›⁄ 
		---------------------ŒÌ«—«  «·“Ì«—… 
		SET @SpecifyOrder  		= SubString (@ModifyFlds, 1, 1) 
		SET	@ShowTodayRoute		= SubString(@ModifyFlds, 2, 1) 
		SET @AccessByBarcode	= SubString(@ModifyFlds, 3, 1) 
		SET @EndVisitByBarcode	= SubString(@ModifyFlds, 4, 1) 
		SET @AccessByRFID		= SubString(@ModifyFlds, 5, 1) 
		SET @CustBalanceByJobCost	= SubString(@ModifyFlds, 6, 1)  
		SET @CustBarcodeHasValidate	= SubString(@ModifyFlds, 7, 1) 
		SET @CanChangeCustBarcode	= SubString(@ModifyFlds, 8, 1) 
		SET @CanAddCustomer		= SubString(@ModifyFlds, 9, 1) 
		SET @ChangeCustCard		= SubString(@ModifyFlds, 10,1) 
		SET @IgnoreNoDetailsVisits	= SubString(@ModifyFlds, 11,1) 
		SET @OutRouteVisitsNumber	= @OutRouteVisits 
		--------------------ŒÌ«—«  «·›« Ê—… 
		SET @CanChangePrice		= SubString(@ModifyFlds, 12, 1) 
		SET @UseCustLastPrice	= SubString(@ModifyFlds, 13, 1) 
		SET @CheckBillOffers 	= SubString(@ModifyFlds, 14, 1) 
		SET @CanUpdateOffer		= SubString(@ModifyFlds, 15, 1) 
		SET @CanAddBonus		= SubString(@ModifyFlds, 16, 1) 
		SET @CanUpdateBill		= SubString(@ModifyFlds, 17, 1) 
		SET @CanDeleteBill		= SubString(@ModifyFlds, 18, 1) 
		SET @AddMatByBarcode   	= SubString(@ModifyFlds, 19, 1) 
		SET @OutNegative		= SubString(@ModifyFlds, 20, 1) 
		SET @NoOvertakeMaxDebit = SubString(@ModifyFlds, 21, 1) 
		SET @PrintPrice			= @PrntPrice 
		SET @ItemDiscType		= SubString(@ModifyFlds, 22, 1) 
		SET @DefaultPayType		= SubString(@ModifyFlds, 23, 1) 
		 
		UPDATE Distributor000  
		SET  
			---------------------ŒÌ«—«  «·“Ì«—… 
	 		[SpecifyOrder]			= CASE @SpecifyOrder		WHEN 5  THEN [SpecifyOrder]		ELSE @SpecifyOrder		END, 
			[ShowTodayRoute]		= CASE @ShowTodayRoute		WHEN 5  THEN [ShowTodayRoute]		ELSE @ShowTodayRoute		END, 		  
			[AccessByBarcode]		= CASE @AccessByBarcode		WHEN 5  THEN [AccessByBarcode]		ELSE @AccessByBarcode		END,  
			[EndVisitByBarcode]		= CASE @EndVisitByBarcode	WHEN 5  THEN [EndVisitByBarcode]	ELSE @EndVisitByBarcode		END,  
			[AccessByRFID]			= CASE @AccessByRFID		WHEN 5  THEN [AccessByRFID]		ELSE @AccessByRFID		END,  
			[CustBalanceByJobCost]	= CASE @CustBalanceByJobCost	WHEN 5  THEN [CustBalanceByJobCost]	ELSE @CustBalanceByJobCost	END,  
			[CustBarcodeHasValidate]= CASE @CustBarcodeHasValidate	WHEN 5  THEN [CustBarcodeHasValidate]	ELSE @CustBarcodeHasValidate 	END,  
			[CanChangeCustBarcode]	= CASE @CanChangeCustBarcode	WHEN 5  THEN [CanChangeCustBarcode]	ELSE @CanChangeCustBarcode	END,  
			[CanAddCustomer]		= CASE @CanAddCustomer		WHEN 5  THEN [CanAddCustomer]		ELSE @CanAddCustomer		END, 		  
			[ChangeCustCard]		= CASE @ChangeCustCard		WHEN 5  THEN [ChangeCustCard]		ELSE @ChangeCustCard		END, 		  
			[IgnoreNoDetailsVisits]	= CASE @IgnoreNoDetailsVisits	WHEN 5  THEN [IgnoreNoDetailsVisits]	ELSE @IgnoreNoDetailsVisits 	END,   
			[OutRouteVisitsNumber]	= CASE @OutRouteVisitsNumber	WHEN -1 THEN [OutRouteVisitsNumber]	ELSE @OutRouteVisitsNumber	END, 	  
			--------------------ŒÌ«—«  «·›« Ê—… 
			[CanChangePrice]	= CASE @CanChangePrice		WHEN 5  THEN [CanChangePrice]		ELSE @CanChangePrice	END, 		  
			[UseCustLastPrice]	= CASE @UseCustLastPrice	WHEN 5  THEN [UseCustLastPrice]		ELSE @UseCustLastPrice	END, 		  
			[CheckBillOffers]	= CASE @CheckBillOffers		WHEN 5  THEN [CheckBillOffers]		ELSE @CheckBillOffers	END, 		  
			[CanUpdateOffer]	= CASE @CanUpdateOffer		WHEN 5  THEN [CanUpdateOffer]		ELSE @CanUpdateOffer	END,  
			[CanAddBonus]		= CASE @CanAddBonus			WHEN 5  THEN [CanAddBonus]			ELSE @CanAddBonus		END, 	 
			[CanUpdateBill]		= CASE @CanUpdateBill		WHEN 5  THEN [CanUpdateBill]		ELSE @CanUpdateBill		END, 			  
			[CanDeleteBill]		= CASE @CanDeleteBill		WHEN 5  THEN [CanDeleteBill]		ELSE @CanDeleteBill		END,  
			[AddMatByBarcode]	= CASE @AddMatByBarcode		WHEN 5  THEN [AddMatByBarcode]		ELSE @AddMatByBarcode	END,  
			[OutNegative]		= CASE @OutNegative			WHEN 5  THEN [OutNegative]			ELSE @OutNegative		END,  
			[NoOvertakeMaxDebit]= CASE @NoOvertakeMaxDebit	WHEN 5  THEN [NoOvertakeMaxDebit]	ELSE @NoOvertakeMaxDebit END,  
			[PrintPrice]		= CASE @PrintPrice			WHEN -1  THEN [PrintPrice]			ELSE @PrintPrice		END,  
			[ItemDiscType]		= CASE @ItemDiscType		WHEN 5  THEN [ItemDiscType]			ELSE @ItemDiscType		END,  
			[DefaultPayType]	= CASE @DefaultPayType		WHEN 5 THEN [DefaultPayType]		ELSE @DefaultPayType	END 
			------------------------		 
		FROM 	 
			Distributor000 AS dr   
			INNER JOIN #Dists AS s ON s.DistGuid = dr.Guid		 
		WHERE  
				dr.TypeGuid = @TypeGuid OR @TypeGuid = 0x0 
	END 
##############################
#END