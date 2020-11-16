###############################################################################
CREATE FUNCTION fn_bubi_FixedCps(@CustPtr [UNIQUEIDENTIFIER],@CustAcc  [UNIQUEIDENTIFIER])
	RETURNS TABLE 
AS 
RETURN 	(
	
		SELECT      
			[bu].[TypeGuid] AS [buType],     
			[bu].[Security] AS [buSecurity],     
			[bu].[Guid] AS [buGUID],     
			[bu].[Number] [buNumber],   
			[bu].[Date] as [buDate],     
			[bi].[biNumber] AS [biNumber],      
			[bu].[Notes] AS [buNotes],     
			bu.[CustAccGUID] AS [buCustAcc], 
			[Bu].[Total] AS [BuTotal],
			[Bu].[VAT] AS   [BuVAT],
			[ItemsDisc] [buItemsDisc],
			[Bu].[BonusDisc] AS [BuBonusDisc], 
			[ItemsExtra] AS [buItemsExtra],
			[Bu].[FirstPay]  AS [BuFirstPay],     
			[biMatPtr] AS [biMatPtr],     
			[biQty] AS [biQty],     
			[bi].[biBonusQnt] AS [biBonusQnt],     
			[bi].[biUnity] AS [biUnity],     
			[bi].[biQty2] AS [biQty2],     
			[bi].[biQty3] AS [biQty3],     
			[bi].[biExpireDate] AS [bExpireDate],     
			[bi].[biProductionDate] AS [biProductionDate],     
			[bu].[CostGuid] [biCostPtr], 
			CASE [bi].[bicostptr] WHEN 0X00 THEN [bu].[CostGuid] ELSE [bi].[bicostptr] END  [biCost_Ptr],    
			[bi].[biClassPtr]  ,     
			[bi].[biLength] AS [biLength],     
			[bi].[biWidth] AS [biWidth],     
			[bi].[biHeight] [biHeight], 
			[bi].[biCount] [biCount],     
			[Bi].[biPrice] ,     
			[Bi].[biDiscount] AS [BiDiscount], 
			[Bi].[biBonusDisc] AS [biBonusDisc],    
			[bi].[biExtra] AS [biExtra],     
			[bi].[biNotes] AS [biNotes],     
			[bu].[SalesManPtr] AS [buSalesManPtr], 
			[bu].[Vendor] AS [buVendor],  
			[bu].[TextFld1] AS [buTextFld1],
			[bu].[TextFld2] AS [buTextFld2],
			[bu].[TextFld3] AS [buTextFld3],
			[bu].[TextFld4] AS [buTextFld4],
			[bu].[CustGUID] AS [buCustPtr],
			[bu].[IsPosted] AS [buIsPosted],
			[bu].[MatAccGuid] AS [buMatAcc],
			[bi].[biStorePtr] AS [biStorePtr],
			[bi].[biExpireDate] AS [biExpireDate],
			[Bu].[PayType] AS [buPayType],
			[Bu].[branch] AS [buBranch],
			[bi].biVat as biVat,
			[bi].biVatRatio as biVatRatio,
			biCurrencyPtr,biCurrencyVal,
			bu.TotalSalesTax as buTotalSalesTax
		 
		FROM  
			[vbbu] AS [bu] 
			INNER JOIN [vwbi] AS [bi] ON [bu].[Guid] = [bi].[biParent]
			WHERE 
				(@CustPtr = 0X00) 
				OR ([CustGUID] = @CustPtr OR 
					(@CustAcc <> 0X00 AND [bu].[MatAccGuid] = @CustAcc AND 
					 EXISTS(SELECT 1 FROM bt000 WHERE GUID = bu.TypeGUID AND (Type = 3 OR Type = 4)))))
###############################################################################
### ·⁄œ… “»«∆‰ „⁄ «· ›«’Ì·
###############################################################################
CREATE PROCEDURE repCPS_WithDetails    
	@serialNumber [bit] = 0,   
	@UserId			AS [UNIQUEIDENTIFIER],    
	@EndDate		AS [DATETIME],     
	@CurPtr			AS [UNIQUEIDENTIFIER],      
	@CurVal			AS [FLOAT],      
	@Post			AS [INT],	-- 1: xxx, 2: yyy, 3: zzz      
	@Cash			AS [INT],	-- 0: a, 1: b, 2: c, c: d      
	@Contain		AS [NVARCHAR](1000),      
	@NotContain		AS [NVARCHAR](1000),      
	@UseChkDueDate	AS [INT],     
	@ShowChk		AS [INT],  
	@CostGuid		AS [UNIQUEIDENTIFIER],  
	@ShowAccMoved   AS [INT] = 0,  
	@StartBal		AS [INT] = 0,  
	@bUnmatched		AS [INT] = 1, 
	@ShwChWithEn	AS [INT] = 0, 
	@ShowDiscExtDet AS [INT] = 0, 
	-- @ShowOppAcc		AS [INT] = 0, 
	-- @Flag			BIGINT = 0,
	@IsEndorsedRecieved AS BIT = 0, 
	@IsDiscountedRecieved AS BIT = 0,
	@IsNotShowUnDelivered AS BIT = 0,
	@IsShowChequeDetailsPartly BIT = 0,
	@ShowValVat AS [BIT] = 0,
	@DetailingByCurrencyAccount  AS [BIT] = 0
AS  
		SET NOCOUNT ON  
	DECLARE
		        
		@ContainStr		[NVARCHAR](1000),        
		@NotContainStr	[NVARCHAR](1000)    
		   
	DECLARE @StDate [DATETIME]    
	-- prepare Parameters:	       
	SET @ContainStr = '%' + @Contain + '%'       
	SET @NotContainStr = '%' + @NotContain + '%'  
	      
	DECLARE @Curr TABLE( DATE SMALLDATETIME,VAL FLOAT, CurrGuid UNIQUEIDENTIFIER)
	INSERT INTO @Curr  
		SELECT DATE,CurrencyVal, CURRENCYGuid FROM mh000 WHERE DATE <= @EndDate 
	UNION ALL  
		SELECT  '1/1/1980',CurrencyVal, Guid FROM MY000      
	-- 	INSERT BILLS MOVE
	
CREATE TABLE [#bill](
			[cuNumber]				[UNIQUEIDENTIFIER] ,       
			[cuSecurity]				[int],        
			[buType]					[UNIQUEIDENTIFIER],       
			[buSecurity]				[int],        
			[btSecurity]				[int], 		       
			[buGUID]					[UNIQUEIDENTIFIER],       
			[buNumber]					[int],     
			[buDate]					[DATETIME],
			[biNumber]					[int],        
			[buNotes]					[NVARCHAR](1000) COLLATE ARABIC_CI_AI,
			[IsCash]					[bit],      
			[BillTotal]					[FLOAT],       
			[FixedBuVAT]						[FLOAT],       
			[FixedbuItemsDisc]				[FLOAT],  
			[FixedBuBonusDisc]				[FLOAT],   
			[FixedbuItemExtra]			[FLOAT],  
			[FixedbuSalesTax]			[FLOAT],
			[FixedBuFirstPay]			[FLOAT],       
			[btReadPriceSecurity]		[int],     
			[biMatPtr]					[UNIQUEIDENTIFIER],      
			[stName]					[NVARCHAR](300) COLLATE ARABIC_CI_AI,     
			[biQty]						[FLOAT],       
			[biBonusQnt]				[FLOAT],       
			[biUnity]					[INT],       
			[biQty2]					[FLOAT],       
			[biQty3]					[FLOAT],       
			[biExpireDate] 				[DATETIME],
			[biProductionDate]  		 [DATETIME],
		    [biCostPtr]					[UNIQUEIDENTIFIER],       
			[biClassPtr]				[NVARCHAR](300) COLLATE ARABIC_CI_AI,       
			[biLength]					 [FLOAT],       
			[biWidth]					[FLOAT],       
			[biHeight]					 [FLOAT],    
			[biCount]			       [FLOAT],
			[FixedBiPrice]				 [FLOAT],       
			[FixedBiDiscount]			 [FLOAT],   
			[FixedbiBonusDisc]			 [FLOAT],      
			[FixedbiExtra]				 [FLOAT],       
			[FixedbiVAT]				 [FLOAT],
			[biVatRatio]				 [FLOAT],
			[biNotes]				 [NVARCHAR](1000) COLLATE ARABIC_CI_AI DEFAULT '',       
			[buSalesManPtr]			[FLOAT],    
			[buVendor]					[FLOAT],    
			[mtSecurity]			[INT],  
			[FixedCurrencyFactor]	[FLOAT],  
			[AccountGuid]				[UNIQUEIDENTIFIER],  
			[BuTotal]				[FLOAT],  
			[btDirection]			[INT],  
		    [btBillType]			[INT],	
			[buTextFld1]		 [NVARCHAR](300) COLLATE ARABIC_CI_AI DEFAULT '',  
			[buTextFld2]		 [NVARCHAR](300) COLLATE ARABIC_CI_AI DEFAULT '',  
			[buTextFld3]		 [NVARCHAR](300) COLLATE ARABIC_CI_AI DEFAULT '',  
			[buTextFld4]		 [NVARCHAR](300) COLLATE ARABIC_CI_AI DEFAULT '',  
			[buFormatedNumber]		[INT], 
			[buBranch]					[UNIQUEIDENTIFIER] DEFAULT 0X00,  
			VS					[INT],
			SN					[NVARCHAR](300) COLLATE ARABIC_CI_AI ,
			SNGUID				[UNIQUEIDENTIFIER],
			SNItem				[INT]
			) 
		
	IF( @serialNumber = 0)     
		ALTER TABLE      
			[#bill]     
		DROP COLUMN     
			[sn],     
			SNGUID,
			SNItem
		 
	IF @serialNumber = 1 
	BEGIN
		INSERT INTO [#bill]
		SELECT 
	--sns       
			[cu].[Number] AS [cuNumber],       
			[cu].[Security] AS [cuSecurity],       
			[buType],       
			[buSecurity],       
			CASE [bi].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnpostedSecurity] END AS [btSecurity], 		       
			[buGUID],       
			[buNumber],     
			[buDate],       
			[biNumber],        
			[buNotes],       
			CASE       
					WHEN [buCustAcc] = [cu].[AccountGuid]  THEN 0      
					ELSE 1 END  AS [IsCash] ,      
			([BuTotal] + [BuVAT]) * Factor AS [BillTotal],       
			[BuVAT] * Factor [FixedBuVAT],       
			[buItemsDisc] * factor [FixedbuItemsDisc],  
			 [BuBonusDisc] * factor [FixedBuBonusDisc],   
			[buItemsExtra] * factor [FixedbuItemExtra],  
			buTotalSalesTax * Factor FixedBuSalesTax,
			CASE [btType] WHEN  2  THEN 0 WHEN  3  THEN 0 WHEN  4  THEN 0 ELSE [BuFirstPay] * Factor END AS [FixedBuFirstPay],       
			[bt].[ReadPriceSecurity] AS [btReadPriceSecurity],       
			[biMatPtr],       
			[St].[stName] AS [stName],     
			1 [biQty],      
			[biBonusQnt],       
			[biUnity],       
			[biQty2],       
			[biQty3],       
			[biExpireDate],       
			[biProductionDate],       
			[biCost_Ptr] [biCostPtr], -- /*      
			[biClassPtr],       
			[biLength],       
			[biWidth],       
			[biHeight],    
			[biCount],       
			[BiPrice] * Factor [FixedBiPrice],       
			[BiDiscount] * Factor [FixedBiDiscount],   
			[biBonusDisc] * Factor [FixedbiBonusDisc],      
			[biExtra]* Factor  [FixedbiExtra],     
			[biVat] * Factor [FixedbiVAT],
			[biVatRatio], 
			[biNotes],   --*/      
			[buSalesManPtr],    
			[buVendor],   
			[mtSecurity], 
			Factor [FixedCurrencyFactor],   
			[cu].[AccountGuid],  
			[BuTotal] * Factor [FixedBuTotal],   
			[btDirection],
			[btType] AS [btBillType],  
			[buTextFld1],  
			[buTextFld2],  
			[buTextFld3],  
			[buTextFld4],  
			CAST ([buNumber] AS [INT]) AS [buFormatedNumber],
			[buBranch],  
			CASE [btVatSystem] WHEN 2 THEN 1 else 0 END AS VS,
			SN,
			SNGUID,
			SNItem
		FROM 
			(SELECT snc.SN as SN,snc.guid as SNGUID, snt.Item as SNItem, fn.* ,
			1 / CASE WHEN  biCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN biCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
							 ELSE biCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE biCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  buDate  ORDER BY DATE DESC))
			    END Factor  
				from  [fn_bubi_FixedCps]( 0X00,0X00) fn 
                inner join cu000 cu on cu.guid = fn.buCustPtr 
                inner join ac000 ac on ac.guid = cu.AccountGUID
				inner join snc000 snc on snc.matguid = bimatptr
				inner join snt000 snt on (snt.buguid = fn.buguid and snt.parentguid = snc.guid)  ) AS [bi] 
			INNER JOIN [#BillTbl2] AS [bt] ON [bt].[Type] = [bi].[buType]   
			INNER JOIN [#CUST1] AS [cu] ON [cu].[Number] = [bi].[buCustPtr]   
			INNER JOIN [vwSt] AS st ON [st].[stGUID] = [bi].[biStorePtr]   
			INNER JOIN [#MatTbl] AS [mt] ON [mt]. [MatGuid] = [bi].[biMatPtr]  
			INNER JOIN [#CostTbl] as [co] ON [biCostPtr] = [CO].[Guid]  
		WHERE        
			[buDate] <= @EndDate       
			AND (( @Cash > 2) 
			    OR( @Cash = 0 AND [buPayType] >= 2)       
				OR((@Cash = 1) AND ( ISNULL( [buCustPtr], 0x0) = 0x0 OR [cu].[AccountGuid] <> [buCustAcc]))       
				OR( @Cash = 2 AND ([cu].[AccountGuid] = [buCustAcc] OR [cu].[AccountGuid] = [bi].[buMatAcc])))       
			AND (( @Post = 3)OR( @Post = 2 AND [buIsPosted] = 0) OR( @Post = 1 AND [buIsPosted] = 1))       
			AND (( @Contain = '') OR ( [buNotes] LIKE @ContainStr) OR ([biNotes] LIKE @ContainStr))       
			AND (( @NotContain = '') OR (( [buNotes] NOT LIKE @NotContainStr) AND ([biNotes] NOT LIKE @NotContainStr))) 
			AND NOT([btType] = 3 or [btType] = 4)  
	
		INSERT INTO [#Bill]	 
		SELECT        
			[cu].[Number] AS [cuNumber],       
			[cu].[Security] AS [cuSecurity],       
			[buType],       
			[buSecurity],       
			CASE [bi].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnpostedSecurity] END AS [btSecurity], 		       
			[buGUID],       
			[buNumber],     
			[buDate],       
			[biNumber],        
			[buNotes],       
			0 [IsCash] ,      
			([BuTotal] + [BuVAT]) * Factor AS [BillTotal],       
			[BuVAT] * Factor,       
			[buItemsDisc] * Factor,  
			[BuBonusDisc] * Factor,   
			[buItemsExtra] * Factor [FixedbuItemExtra],  
			buTotalSalesTax * Factor FixedBuSalesTax,
			CASE [btType] WHEN  2  THEN 0 WHEN  3  THEN 0 WHEN  4  THEN 0 ELSE [BuFirstPay] * Factor END AS [FixedBuFirstPay],       
			[bt].[ReadPriceSecurity] AS [btReadPriceSecurity],       
			[biMatPtr],       
			[St].[stName] AS [stName],     
			1 [biQty],       
			[biBonusQnt],       
			[biUnity],       
			[biQty2],       
			[biQty3],       
			[biExpireDate],       
			[biProductionDate],       
			[biCost_Ptr] [biCostPtr],       
			[biClassPtr],       
			[biLength],       
			[biWidth],       
			[biHeight],    
			[biCount],       
			[BiPrice] * Factor,       
			[BiDiscount] * Factor,   
			[biBonusDisc] * Factor,      
			[biExtra] * Factor,       
			[biVat] * Factor,
			[biVatRatio],   
			[biNotes],       
			[buSalesManPtr],   
			[buVendor],    
			[mtSecurity],  
			Factor [FixedCurrencyFactor],  
			[cu].[AccountGuid],  
			[BuTotal] * Factor,  
			[btDirection],  
			[btType] AS [btBillType],  
			[buTextFld1],  
			[buTextFld2],  
			[buTextFld3],  
			[buTextFld4],  
			CAST ([buNumber] AS [INT]) AS [buFormatedNumber],[buBranch],  
			CASE [btVatSystem] WHEN 2 THEN 1 else 0 END AS VS ,  
			SN,
			SNGUID,
		    SNItem
			FROM    
				(select snc.SN as SN,snc.guid as SNGUID, snt.Item as SNItem, fn.* ,
				1 / CASE WHEN  biCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN biCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
							 ELSE biCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE biCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  buDate  ORDER BY DATE DESC))
			    END Factor    
				  from [fn_bubi_FixedCps]( 0X00,0X00) fn 
				 inner join cu000 cu on cu.guid = fn.buCustPtr 
                inner join ac000 ac on ac.guid = cu.AccountGUID
				  	inner join snc000 snc on snc.matguid = bimatptr
					inner join snt000 snt on (snt.buguid = fn.buguid and snt.parentguid = snc.guid)  ) AS [bi]   
				INNER JOIN [#BillTbl2] AS [bt] ON [bt].[Type] = [bi].[buType]   
				INNER JOIN [#CUST1] AS [cu] ON [cu].[AccountGuid] = [bi].[buMatAcc]  
				INNER JOIN [vwSt] AS st ON [st].[stGUID] = [bi].[biStorePtr]   
				INNER JOIN [#MatTbl] AS [mt] ON [mt]. [MatGuid] = [bi].[biMatPtr]  
				INNER JOIN [#CostTbl] as [co] ON [biCostPtr] = [CO].[Guid]  
		WHERE        
			[buDate] <= @EndDate       
			AND (( @Cash > 2) 
			    OR( @Cash = 0 AND [buPayType] >= 2)       
				OR((@Cash = 1) AND ( ISNULL( [buCustPtr], 0x0) = 0x0 OR [cu].[AccountGuid] <> [buCustAcc]))       
				OR( @Cash = 2 AND ([cu].[AccountGuid] = [buCustAcc] OR [cu].[AccountGuid] = [bi].[buMatAcc])))       
			AND (( @Post = 3)OR( @Post = 2 AND [buIsPosted] = 0) OR( @Post = 1 AND [buIsPosted] = 1))       
			AND (( @Contain = '') OR ( [buNotes] LIKE @ContainStr) OR ([biNotes] LIKE @ContainStr))       
			AND (( @NotContain = '') OR (( [buNotes] NOT LIKE @NotContainStr) AND ([biNotes] NOT LIKE @NotContainStr))) 
			AND ([btType] = 3 or [btType] = 4) 
		--sn empty
		
		INSERT  INTO [#Bill]
		SELECT	
		[cu].[Number] AS [cuNumber],       
			[cu].[Security] AS [cuSecurity],       
			[buType],       
			[buSecurity],       
			CASE [bi].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnpostedSecurity] END AS [btSecurity], 		       
			[buGUID],       
			[buNumber],     
			[buDate],       
			[biNumber],        
			[buNotes],       
			CASE       
					WHEN [buCustAcc] = [cu].[AccountGuid]  THEN 0      
					ELSE 1 END  AS [IsCash] ,      
			([BuTotal] + [BuVAT]) * Factor AS [BillTotal],       
			[BuVAT] * Factor [FixedBuVAT],       
			[buItemsDisc] * factor [FixedbuItemsDisc],  
			 [BuBonusDisc] * factor [FixedBuBonusDisc],   
			[buItemsExtra] * factor [FixedbuItemExtra], 
			buTotalSalesTax * Factor FixedBuSalesTax, 
			CASE [btType] WHEN  2  THEN 0 WHEN  3  THEN 0 WHEN  4  THEN 0 ELSE [BuFirstPay] * Factor END AS [FixedBuFirstPay],       
			[bt].[ReadPriceSecurity] AS [btReadPriceSecurity],       
			[biMatPtr],       
			[St].[stName] AS [stName],     
			[biQty],       
			[biBonusQnt],       
			[biUnity],       
			[biQty2],       
			[biQty3],       
			[biExpireDate],       
			[biProductionDate],       
			[biCost_Ptr] [biCostPtr],       
			[biClassPtr],       
			[biLength],       
			[biWidth],       
			[biHeight],    
			[biCount],       
			[BiPrice] * Factor [FixedBiPrice],       
			[BiDiscount] * Factor [FixedBiDiscount],   
			[biBonusDisc] * Factor [FixedbiBonusDisc],      
			[biExtra]* Factor  [FixedbiExtra],       
			[biVat] * Factor [FixedbiVAT],
			[biVatRatio], 
			[biNotes],       
			[buSalesManPtr],   
			[buVendor],    
			[mtSecurity],  
			Factor [FixedCurrencyFactor],  
			[cu].[AccountGuid],  
			[BuTotal] * Factor [FixedBuTotal],  
			[btDirection],  
			[btType] AS [btBillType],  
			[buTextFld1],  
			[buTextFld2],  
			[buTextFld3],  
			[buTextFld4],  
			CAST ([buNumber] AS [INT]) AS [buFormatedNumber],[buBranch],  
			CASE [btVatSystem] WHEN 2 THEN 1 else 0 END AS VS,
			'',
			0x00,
			0
			FROM    
				(SELECT fn.* ,1 / CASE WHEN  biCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN biCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
							 ELSE biCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE biCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  buDate  ORDER BY DATE DESC))
			    END Factor  
							 
				 from [fn_bubi_FixedCps]( 0X00,0X00) fn 
				 inner join cu000 cu on cu.guid = fn.buCustPtr 
                inner join ac000 ac on ac.guid = cu.AccountGUID) AS [bi]  
				INNER JOIN [#BillTbl2] AS [bt] ON [bt].[Type] = [bi].[buType]   
				INNER JOIN [#CUST1] AS [cu] ON [cu].[Number] = [bi].[buCustPtr]   
				INNER JOIN [vwSt] AS st ON [st].[stGUID] = [bi].[biStorePtr]   
				INNER JOIN [#MatTbl] AS [mt] ON [mt]. [MatGuid] = [bi].[biMatPtr]  
				INNER JOIN [#CostTbl] as [co] ON [biCostPtr] = [CO].[Guid]  
		WHERE        
			[buDate] <= @EndDate       
			AND (( @Cash > 2) OR( @Cash = 0 AND [buPayType] >= 2)       
				OR((@Cash = 1) AND ( ISNULL( [buCustPtr], 0x0) = 0x0 OR [cu].[AccountGuid] <> [buCustAcc]))       
				OR( @Cash = 2 AND ([cu].[AccountGuid] = [buCustAcc] OR [cu].[AccountGuid] = [bi].[buMatAcc])))       
			AND (( @Post = 3)OR( @Post = 2 AND [buIsPosted] = 0) OR( @Post = 1 AND [buIsPosted] = 1))       
			AND (( @Contain = '') OR ( [buNotes] LIKE @ContainStr) OR ([biNotes] LIKE @ContainStr))       
			AND (( @NotContain = '') OR (( [buNotes] NOT LIKE @NotContainStr) AND ([biNotes] NOT LIKE @NotContainStr))) 
			AND NOT([btType] = 3 or [btType] = 4)  
	
		INSERT INTO [#Bill]	 
		SELECT        
			[cu].[Number] AS [cuNumber],       
			[cu].[Security] AS [cuSecurity],       
			[buType],       
			[buSecurity],       
			CASE [bi].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnpostedSecurity] END AS [btSecurity], 		       
			[buGUID],       
			[buNumber],     
			[buDate],       
			[biNumber],        
			[buNotes],       
			0 [IsCash] ,      
			([BuTotal] + [BuVAT]) * Factor AS [BillTotal],       
			[BuVAT] * Factor,       
			[buItemsDisc] * Factor,  
			[BuBonusDisc] * Factor,   
			[buItemsExtra] * Factor [FixedbuItemExtra],  
			buTotalSalesTax * Factor FixedBuSalesTax,
			CASE [btType] WHEN  2  THEN 0 WHEN  3  THEN 0 WHEN  4  THEN 0 ELSE [BuFirstPay] * Factor END AS [FixedBuFirstPay],       
			[bt].[ReadPriceSecurity] AS [btReadPriceSecurity],       
			[biMatPtr],       
			[St].[stName] AS [stName],     
			[biQty],       
			[biBonusQnt],       
			[biUnity],       
			[biQty2],       
			[biQty3],       
			[biExpireDate],       
			[biProductionDate],       
			[biCost_Ptr] [biCostPtr],       
			[biClassPtr],       
			[biLength],       
			[biWidth],       
			[biHeight],    
			[biCount],       
			[BiPrice] * Factor,       
			[BiDiscount] * Factor,   
			[biBonusDisc] * Factor,      
			[biExtra] * Factor,       
			[biVat] * Factor,
			[biVatRatio], 
			[biNotes],       
			[buSalesManPtr],   
			[buVendor],    
			[mtSecurity],  
			Factor [FixedCurrencyFactor],  
			[cu].[AccountGuid],  
			[BuTotal] * Factor,  
			[btDirection],  
			[btType] AS [btBillType],  
			[buTextFld1],  
			[buTextFld2],  
			[buTextFld3],  
			[buTextFld4],  
			CAST ([buNumber] AS [INT]) AS [buFormatedNumber],[buBranch],  
			CASE [btVatSystem] WHEN 2 THEN 1 else 0 END AS VS,
			'',
			0x00,
			0		   
		FROM    
			(select fn.* ,1 /CASE WHEN  biCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN biCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] =  buDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
							 ELSE biCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE biCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  buDate  ORDER BY DATE DESC))
			    END Factor  
			from [fn_bubi_FixedCps]( 0X00,0X00) fn 
			  inner join cu000 cu on cu.guid = fn.buCustPtr 
                inner join ac000 ac on ac.guid = cu.AccountGUID ) AS [bi]  
			INNER JOIN [#BillTbl2] AS [bt] ON [bt].[Type] = [bi].[buType]   
			INNER JOIN [#CUST1] AS [cu] ON [cu].[AccountGuid] = [bi].[buMatAcc]  
			INNER JOIN [vwSt] AS st ON [st].[stGUID] = [bi].[biStorePtr]   
			INNER JOIN [#MatTbl] AS [mt] ON [mt]. [MatGuid] = [bi].[biMatPtr]  
			INNER JOIN [#CostTbl] as [co] ON [biCostPtr] = [CO].[Guid]  
		WHERE        
			[buDate] <= @EndDate       
			AND (( @Cash > 2) OR( @Cash = 0 AND [buPayType] >= 2)       
				OR((@Cash = 1) AND ( ISNULL( [buCustPtr], 0x0) = 0x0 OR [cu].[AccountGuid] <> [buCustAcc]))       
				OR( @Cash = 2 AND ([cu].[AccountGuid] = [buCustAcc] OR [cu].[AccountGuid] = [bi].[buMatAcc])))       
			AND (( @Post = 3)OR( @Post = 2 AND [buIsPosted] = 0) OR( @Post = 1 AND [buIsPosted] = 1))       
			AND (( @Contain = '') OR ( [buNotes] LIKE @ContainStr) OR ([biNotes] LIKE @ContainStr))       
			AND (( @NotContain = '') OR (( [buNotes] NOT LIKE @NotContainStr) AND ([biNotes] NOT LIKE @NotContainStr))) 
			AND ([btType] = 3 or [btType] = 4) 
			delete [#Bill]  from  [#Bill] b
			 inner join snc000 snc on snc.matguid =b. bimatptr
			 inner join snt000 snt on (snt.buguid = b.buguid and snt.parentguid = snc.guid)
			 where b.biqty <> 1 OR b.SNGUID = 0x0
			
	END
	ELSE 
	BEGIN
	INSERT INTO [#Bill]
		SELECT        
			[cu].[Number] AS [cuNumber],       
			[cu].[Security] AS [cuSecurity],       
			[buType],       
			[buSecurity],       
			CASE [bi].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnpostedSecurity] END AS [btSecurity], 		       
			[buGUID],       
			[buNumber],     
			[buDate],       
			[biNumber],        
			[buNotes],       
			CASE       
					WHEN [buCustAcc] = [cu].[AccountGuid]  THEN 0      
					ELSE 1 END  AS [IsCash] ,      
			([BuTotal] + [BuVAT]) * Factor AS [BillTotal],       
			[BuVAT] * Factor [FixedBuVAT],       
			[buItemsDisc] * factor [FixedbuItemsDisc],  
			 [BuBonusDisc] * factor [FixedBuBonusDisc],   
			[buItemsExtra] * factor [FixedbuItemExtra], 
			buTotalSalesTax * Factor FixedBuSalesTax, 
			CASE [btType] WHEN  2  THEN 0 WHEN  3  THEN 0 WHEN  4  THEN 0 ELSE [BuFirstPay] * Factor END AS [FixedBuFirstPay],       
			[bt].[ReadPriceSecurity] AS [btReadPriceSecurity],       
			[biMatPtr],       
			[St].[stName] AS [stName],     
			[biQty],       
			[biBonusQnt],       
			[biUnity],       
			[biQty2],       
			[biQty3],       
			[biExpireDate],       
			[biProductionDate],       
			[biCost_Ptr] [biCostPtr],       
			[biClassPtr],       
			[biLength],       
			[biWidth],       
			[biHeight],    
			[biCount],       
			[BiPrice] * Factor [FixedBiPrice],       
			[BiDiscount] * Factor [FixedBiDiscount],   
			[biBonusDisc] * Factor [FixedbiBonusDisc],      
			[biExtra]* Factor  [FixedbiExtra],       
			[biVat] * Factor [FixedbiVAT],
			[biVatRatio], 
			[biNotes],       
			[buSalesManPtr],   
			[buVendor],    
			[mtSecurity],  
			Factor [FixedCurrencyFactor],  
			[cu].[AccountGuid],  
			[BuTotal] * Factor [FixedBuTotal],  
			[btDirection],  
			[btType] AS [btBillType],  
			[buTextFld1],  
			[buTextFld2],  
			[buTextFld3],  
			[buTextFld4],  
			CAST ([buNumber] AS [INT]) AS [buFormatedNumber],[buBranch],  
			CASE [btVatSystem] WHEN 2 THEN 1 else 0 END AS VS     
			FROM    
				(SELECT fn.* ,1 / CASE WHEN  biCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN biCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] =  buDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
							 ELSE biCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE biCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  buDate  ORDER BY DATE DESC))
			    END Factor   
				 from [fn_bubi_FixedCps]( 0X00,0X00) fn
				  inner join cu000 cu on cu.guid = fn.buCustPtr 
                inner join ac000 ac on ac.guid = cu.AccountGUID) AS [bi]  
				INNER JOIN [#BillTbl2] AS [bt] ON [bt].[Type] = [bi].[buType]   
				INNER JOIN [#CUST1] AS [cu] ON [cu].[Number] = [bi].[buCustPtr]   
				INNER JOIN [vwSt] AS st ON [st].[stGUID] = [bi].[biStorePtr]   
				INNER JOIN [#MatTbl] AS [mt] ON [mt]. [MatGuid] = [bi].[biMatPtr]  
				INNER JOIN [#CostTbl] as [co] ON [biCostPtr] = [CO].[Guid]  
		WHERE        
			[buDate] <= @EndDate       
			AND (( @Cash > 2) 
			OR( @Cash = 0 AND [buPayType] >= 2)       
				OR((@Cash = 1) AND ( ISNULL( [buCustPtr], 0x0) = 0x0 OR [cu].[AccountGuid] <> [buCustAcc]))       
				OR( @Cash = 2 AND ([cu].[AccountGuid] = [buCustAcc] OR [cu].[AccountGuid] = [bi].[buMatAcc])))       
			AND (( @Post = 3)
			     OR( @Post = 2 AND [buIsPosted] = 0) 
			     OR( @Post = 1 AND [buIsPosted] = 1))       
			AND (( @Contain = '') OR ( [buNotes] LIKE @ContainStr) OR ([biNotes] LIKE @ContainStr))       
			AND (( @NotContain = '') OR (( [buNotes] NOT LIKE @NotContainStr) AND ([biNotes] NOT LIKE @NotContainStr))) 
			AND NOT([btType] = 3 or [btType] = 4)  
	 --SELECT 6
		INSERT INTO [#Bill]	 
		SELECT        
			[cu].[Number] AS [cuNumber],       
			[cu].[Security] AS [cuSecurity],       
			[buType],       
			[buSecurity],       
			CASE [bi].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnpostedSecurity] END AS [btSecurity], 		       
			[buGUID],       
			[buNumber],     
			[buDate],       
			[biNumber],        
			[buNotes],       
			0 [IsCash] ,      
			([BuTotal] + [BuVAT]) * Factor AS [BillTotal],       
			[BuVAT] * Factor,       
			[buItemsDisc] * Factor,  
			[BuBonusDisc] * Factor,   
			[buItemsExtra] * Factor [FixedbuItemExtra], 
			buTotalSalesTax * Factor FixedBuSalesTax, 
			CASE [btType] WHEN  2  THEN 0 WHEN  3  THEN 0 WHEN  4  THEN 0 ELSE [BuFirstPay] * Factor END AS [FixedBuFirstPay],       
			[bt].[ReadPriceSecurity] AS [btReadPriceSecurity],       
			[biMatPtr],       
			[St].[stName] AS [stName],     
			[biQty],       
			[biBonusQnt],       
			[biUnity],       
			[biQty2],       
			[biQty3],       
			[biExpireDate],       
			[biProductionDate],       
			[biCost_Ptr] [biCostPtr],       
			[biClassPtr],       
			[biLength],       
			[biWidth],       
			[biHeight],    
			[biCount],       
			[BiPrice] * Factor,       
			[BiDiscount] * Factor,   
			[biBonusDisc] * Factor,      
			[biExtra] * Factor,       
			[biVat]* Factor [FixedbiVat],  
			[biVatRatio],
			[biNotes],       
			[buSalesManPtr],   
			[buVendor],    
			[mtSecurity],  
			Factor [FixedCurrencyFactor],  
			[cu].[AccountGuid],  
			[BuTotal] * Factor,  
			[btDirection],  
			[btType] AS [btBillType],  
			[buTextFld1],  
			[buTextFld2],  
			[buTextFld3],  
			[buTextFld4],  
			CAST ([buNumber] AS [INT]) AS [buFormatedNumber],[buBranch],  
			CASE [btVatSystem] WHEN 2 THEN 1 else 0 END AS VS     
		FROM    
			(select fn.* ,1 / CASE WHEN  biCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN biCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] =  buDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
							 ELSE biCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE biCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  buDate  ORDER BY DATE DESC))
			    END Factor   
			from [fn_bubi_FixedCps]( 0X00,0X00) fn
				     inner join cu000 cu on cu.guid = fn.buCustPtr 
                inner join ac000 ac on ac.guid = cu.AccountGUID ) AS [bi]  
			INNER JOIN [#BillTbl2] AS [bt] ON [bt].[Type] = [bi].[buType]   
			INNER JOIN [#CUST1] AS [cu] ON [cu].[AccountGuid] = [bi].[buMatAcc]  
			INNER JOIN [vwSt] AS st ON [st].[stGUID] = [bi].[biStorePtr]   
			INNER JOIN [#MatTbl] AS [mt] ON [mt]. [MatGuid] = [bi].[biMatPtr]  
			INNER JOIN [#CostTbl] as [co] ON [biCostPtr] = [CO].[Guid]  
		WHERE        
			[buDate] <= @EndDate       
			AND (( @Cash > 2) OR( @Cash = 0 AND [buPayType] >= 2)       
				OR((@Cash = 1) AND ( ISNULL( [buCustPtr], 0x0) = 0x0 OR [cu].[AccountGuid] <> [buCustAcc]))       
				OR( @Cash = 2 AND ([cu].[AccountGuid] = [buCustAcc] OR [cu].[AccountGuid] = [bi].[buMatAcc])))       
			AND (( @Post = 3)OR( @Post = 2 AND [buIsPosted] = 0) OR( @Post = 1 AND [buIsPosted] = 1))       
			AND (( @Contain = '') OR ( [buNotes] LIKE @ContainStr) OR ([biNotes] LIKE @ContainStr))       
			AND (( @NotContain = '') OR (( [buNotes] NOT LIKE @NotContainStr) AND ([biNotes] NOT LIKE @NotContainStr))) 
			AND ([btType] = 3 or [btType] = 4) 
	 END
	
	CREATE  CLUSTERED INDEX [BillININDEX] ON [#Bill] ([buGUID])	  
	
	CREATE TABLE  [#Disc]([Discount] FLOAT, [ParentGuid] UNIQUEIDENTIFIER, [Extra] FLOAT) 
	INSERT INTO [#Disc]
	SELECT 
		 SUM( CASE WHEN [di2].[ContraAccGuid] = [B].[AccountGuid] OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) THEN [di2].[Discount] /CASE WHEN di2.CurrencyGuid = @CurPtr  THEN di2.[CurrencyVal] ELSE [FixedCurrencyFactor] END ELSE 0 END)  
		 AS [Discount],
		 [ParentGuid],
		 SUM(CASE WHEN [di2].[ContraAccGuid] = [B].[AccountGuid] OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) THEN [di2].[Extra]/CASE WHEN di2.CurrencyGuid = @CurPtr  THEN di2.[CurrencyVal] ELSE [FixedCurrencyFactor] END ELSE 0 END)
		  AS [Extra] 
	FROM [di000] AS di2   
	INNER JOIN (SELECT DISTINCT CASE WHEN [FixedCurrencyFactor] > 0 THEN 1/ [FixedCurrencyFactor] ELSE 0 END [FixedCurrencyFactor],[AccountGuid],[buGuid] FROM  [#Bill]) AS [b] ON [b].[buGuid] = [di2].[ParentGuid]  
	WHERE [di2].[ContraAccGuid] = [B].[AccountGuid] OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0)  
	GROUP BY [ParentGuid],[FixedCurrencyFactor] 
	
	IF @serialNumber = 1
	INSERT INTO [#Result]([CustPtr],[CustSecurity],[Type],[Security],[UserSecurity],[Guid],       
		[Number],[Date],[biNumber],[BNotes],[IsCash],[BuTotal],[BuVAT],[BuDiscount],[BuExtra],[BuSalesTax],[BuFirstPay],[UserReadPriceSecurity],[MatPtr],       
		[Store],[Qty],[Bonus],[Unit],[biQty2],[biQty3],[ExpireDate],[ProductionDate],[CostPtr],[ClassPtr],[Length],[Width],[Height],[Count],[BiPrice],[BiDiscount],[BiExtra],       
		[Notes],[Balance],[SalesMan],[Vendor],[MatSecurity],[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4],[Flag],[FormatedNumber],[Branch],[biBonusDisc],[BiVAT],SN,SNGuid,SNItem)       
		SELECT        
			[cuNumber],       
			[CuSecurity],       
			[buType],       
			[buSecurity],       
			[btSecurity], 		       
			[buGUID],       
			[buNumber],     
			[buDate],       
			[biNumber],        
			[buNotes],       
			[IsCash],      
			[BillTotal],       
			[FixedBuVAT],       
			[FixedbuItemsDisc] + [FixedBuBonusDisc] + ISNULL([Discount],0),       
			[FixedbuItemExtra] + ISNULL([Extra],0),--FixedBuTotalExtra,   
			[FixedbuSalesTax],    
			[FixedBuFirstPay],       
			[btReadPriceSecurity],       
			[biMatPtr],       
			[stName],     
			[biQty],       
			[biBonusQnt],       
			[biUnity],       
			[biQty2],       
			[biQty3],       
			[biExpireDate],       
			[biProductionDate],       
			[biCostPtr],       
			[biClassPtr],       
			[biLength],       
			[biWidth],       
			[biHeight],   
			[biCount],       
			[FixedBiPrice],       
			[FixedBiDiscount],       
			[FixedbiExtra],  
			[biNotes],       
			ISNULL((([BillTotal]/* [FixedBuTotal] + [FixedBuVAT]*/ - [FixedbuFirstPay] - ([FixedbuItemsDisc]+ [FixedBuBonusDisc] +ISNULL([Discount],0))  + [FixedbuItemExtra] + ISNULL([Extra],0) + [FixedbuSalesTax]) * (-[btDirection])), 0),   
			[buSalesManPtr],   
			[buVendor],    
			[mtSecurity],   
			[buTextFld1],  
			[buTextFld2],  
			[buTextFld3],  
			[buTextFld4],  
			2, -- Flag   
			[buFormatedNumber],
			[buBranch],
			[FixedbiBonusDisc],
			[FixedBiVAT],
			sn,
			snguid,
			SNItem
		FROM    
			[#Bill] AS [b]  LEFT JOIN [#Disc] AS [d] ON [d].[ParentGuid] = [b].[buGUID] 	
	ELSE 
	INSERT INTO [#Result]([CustPtr],[CustSecurity],[Type],[Security],[UserSecurity],[Guid],       
		[Number],[Date],[biNumber],[BNotes],[IsCash],[BuTotal],[BuVAT],[BuDiscount],[BuExtra],[BuSalesTax],[BuFirstPay],[UserReadPriceSecurity],[MatPtr],       
		[Store],[Qty],[Bonus],[Unit],[biQty2],[biQty3],[ExpireDate],[ProductionDate],[CostPtr],[ClassPtr],[Length],[Width],[Height],[Count],[BiPrice],[BiDiscount],[BiExtra],       
		[Notes],[Balance],[SalesMan],[Vendor],[MatSecurity],[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4],[Flag],[FormatedNumber],[Branch],[biBonusDisc], [BiVAT])       
		SELECT        
			[cuNumber],       
			[CuSecurity],       
			[buType],       
			[buSecurity],       
			[btSecurity], 		       
			[buGUID],       
			[buNumber],     
			[buDate],       
			[biNumber],        
			[buNotes],       
			[IsCash],      
			[BillTotal],       
			[FixedBuVAT],       
			[FixedbuItemsDisc] + [FixedBuBonusDisc] + ISNULL([Discount],0),       
			[FixedbuItemExtra] + ISNULL([Extra],0),--FixedBuTotalExtra,       
			[FixedbuSalesTax],
			[FixedBuFirstPay],       
			[btReadPriceSecurity],       
			[biMatPtr],       
			[stName],     
			[biQty],       
			[biBonusQnt],       
			[biUnity],       
			[biQty2],       
			[biQty3],       
			[biExpireDate],       
			[biProductionDate],       
			[biCostPtr],       
			[biClassPtr],       
			[biLength],       
			[biWidth],       
			[biHeight],   
			[biCount],       
			[FixedBiPrice],      
			[FixedBiDiscount],       
			[FixedbiExtra],  
			[biNotes],       
			ISNULL((([BillTotal]/* [FixedBuTotal] + [FixedBuVAT]*/ - [FixedbuFirstPay] - ([FixedbuItemsDisc]+ [FixedBuBonusDisc] +ISNULL([Discount],0))  + [FixedbuItemExtra] + ISNULL([Extra],0) + [FixedbuSalesTax])* (-[btDirection])), 0),   
			[buSalesManPtr],   
			[buVendor],    
			[mtSecurity],   
			[buTextFld1],  
			[buTextFld2],  
			[buTextFld3],  
			[buTextFld4],  
			2 -- Flag   
			,[buFormatedNumber],[buBranch] ,[FixedbiBonusDisc], [FixedBiVAT]
		FROM    
			[#Bill] AS [b]  LEFT JOIN [#Disc] AS [d] ON [d].[ParentGuid] = [b].[buGUID] 
	 
	-- INSERT ENTRY  
	IF (@ShowDiscExtDet <> 0)  
	BEGIN  
		CREATE TABLE [#DetDiscExt](
			[cuNumber] UNIQUEIDENTIFIER,       
			[CuSecurity] INT,    
			[buType] UNIQUEIDENTIFIER,   
			[buSecurity] INT,  
			[btSecurity] INT, 		   
			[BillGUID] UNIQUEIDENTIFIER,   
			[buNumber] INT,     
			[buDate] DATETIME,  
			[buNotes] NVARCHAR(1000),  
			[Discount] FLOAT,  
			[Extra] FLOAT,  
			[acCodeName] NVARCHAR(256),  
			[acGuid] UNIQUEIDENTIFIER,  
			[acSecurity] INT)
			  
		INSERT INTO [#DetDiscExt] 
		SELECT  
			[cuNumber],       
			[CuSecurity],    
			[buType],   
			[buSecurity],  
			[btSecurity], 		   
			[buGUID] [BillGUID],   
			[buNumber],     
			[buDate],  
			[di2].[Notes] AS [buNotes],  
			[di2].[Discount]*[FixedCurrencyFactor] AS [Discount] ,  
			[di2].[Extra]*[FixedCurrencyFactor] AS [Extra],  
			[ac].[acCode] + '-' +[ac].[acName] AS [acCodeName],  
			[ac].[acGuid],  
			[ac].[acSecurity]  
			FROM [di000] AS [di2]   
			INNER JOIN (SELECT DISTINCT [cuNumber],[CuSecurity],[buType],[buSecurity],[btSecurity],[buNumber],[buDate],[FixedCurrencyFactor],[buGuid],[AccountGuid] FROM  [#Bill]) AS b ON [b].[buGuid] = [di2].[ParentGuid]  
			INNER JOIN [vwAc] AS [ac] ON [ac].[acGuid] = [di2].[AccountGuid]  
			WHERE [di2].[ContraAccGuid] = [B].[AccountGuid] OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0)  
		EXEC [prcCheckSecurity]  @result = '#DetDiscExt'  
		INSERT INTO #RESULT ([CustPtr],[CustSecurity],[MatPtr],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number],[Date],[BNotes],[EntryDebit],[EntryCredit],[OppAccName],[Flag])  
		SELECT  
			[cuNumber],       
			[CuSecurity],  
			[acGuid],   
			1,  
			[buType],   
			[buSecurity],  
			[btSecurity], 		   
			[BillGUID],   
			[buNumber],     
			[buDate],  
			[buNotes],  
			[Discount],  
			[Extra],  
			[acCodeName],  
			2  
		FROM #DetDiscExt  
		
	END  
	CREATE TABLE [#ENTRY](       
		[cuNumber]		UNIQUEIDENTIFIER,       
		[cuSecurity]	INT,        
		[ceTypeGuid]	UNIQUEIDENTIFIER,   
		[enGuid]		UNIQUEIDENTIFIER,    
		[ceSecurity]	INT,        
		[Security]		INT,       
		[ceGuid]		UNIQUEIDENTIFIER,     
		[ceNumber]		INT,     
		[enDate]		DATETIME,        
		[enNumber]		INT,        
		[ceNotes]		NVARCHAR(1000),        
		[FixedEnDebit]	FLOAT,        
		[FixedEnCredit] FLOAT,        
		[enNotes]		NVARCHAR(1000),        
		[Balance]		FLOAT,       
		[enContraAcc]	UNIQUEIDENTIFIER,   
		[FFLAG]			INT,    
		[erParentType]	INT,  
		[Flag]			INT,  
		[erParentGuid]  UNIQUEIDENTIFIER,  
		[enAccount]     UNIQUEIDENTIFIER,  
		[enCostPoint]   UNIQUEIDENTIFIER,  
		[ceBranch]      UNIQUEIDENTIFIER)
	INSERT INTO [#ENTRY]
	SELECT       
		[cu].[Number] AS [cuNumber],       
		[Cu].[Security] AS [cuSecurity],        
		[f].[ceTypeGuid],   
		[f].[enGuid],    
		[f].[ceSecurity],        
		[t].[Security],       
		CASE [t].[Flag] WHEN 1 THEN [er].[erParentGuid] ELSE  [f].[ceGuid] END [ceGuid],     
		[f].[ceNumber],     
		[f].[enDate],        
		[f].[enNumber],        
		[f].[enNotes],        
		[f].enDebit * Factor [FixedEnDebit] ,        
		[f].[EnCredit] * Factor  [FixedEnCredit],        
		[f].[enNotes] ,        
		ISNULL(([f].enDebit - [f].[EnCredit]), 0) * Factor AS [Balance],       
		[enContraAcc],   
		CASE [t].[Flag] WHEN 1 THEN 4 WHEN 2 THEN CASE [er].[erParentType] WHEN 5 THEN 1 ELSE [er].[erParentType] END ELSE 1 END AS [FFLAG],    
		[er].[erParentType],  
		[t].[Flag],  
		ISNULL([er].[erParentGuid],0X00) [erParentGuid],  
		[f].[enAccount],  
		[f].[enCostPoint],  
		[ceBranch]  
	FROM        
		(SELECT *,1 / CASE WHEN  enCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN enCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  enDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  enDate  ORDER BY DATE DESC) 
							 ELSE enCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE enCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  enDate  ORDER BY DATE DESC))
			    END Factor    
				   FROM vwCeEn inner join ac000 ac on ac.guid = enAccount) AS [f]  
		INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] =[f].[enAccount]      
		LEFT JOIN [vwEr] AS [er]       
		ON [f].[ceGuid] = [er].[erEntryGuid]       
		INNER JOIN [#EntrySource] AS [t]       
		ON [f].[ceTypeGuid] = [t].[Type] --AND [t].Flag <> 3  
	WHERE       
		 [f].[enDate] <= @EndDate  
		AND (( @Contain = '') OR ([f].[enNotes] LIKE @ContainStr) OR ([f].[ceNotes] LIKE @ContainStr) )       
		AND (( @NotContain = '') OR (( [f].[enNotes] NOT LIKE @NotContainStr) AND ( [f].[ceNotes] NOT LIKE @NotContainStr)))   
		AND ([cu].[Number] = [f].[enCustomerGUID])
 		  
	CREATE CLUSTERED INDEX entryParentType ON [#ENTRY]([erParentGuid])  
	INSERT INTO [#Result]  ([CustPtr],[CustSecurity],[Type],[Security],[UserSecurity],[Guid],[Number],[Date],[biNumber], [BNotes],[UserReadPriceSecurity],[CostPtr],[ClassPtr],[EntryDebit],[EntryCredit],[Notes],[Balance],[ContraAcc],[Flag],[Branch],[enGuid])       
		SELECT       
			[cuNumber],       
			[CuSecurity],  
			[ceTypeGuid],     
			[ceSecurity],        
			[#ENTRY].[Security],       
			[ceGuid],     
			[ceNumber],     
			CASE WHEN erparenttype = 13 THEN chdate ELSE [enDate] END AS enDate,
			[enNumber],        
			[ceNotes],        
			3,--	UserReadPriceSecurity       
			[enCostPoint],--	CostPtr,        
			'',--	ClassPtr,        
			[FixedEnDebit],  -- EntryDebit        
			[FixedEnCredit], -- EntryCredit,        
			[enNotes] ,        
			[Balance],       
			[enContraAcc],  
			CASE WHEN erparenttype = 6 THEN 1 ELSE [FFlag] END,
			[ceBranch],[enGuid]  
		FROM  
			[#ENTRY]  
			INNER JOIN  [#CostTbl] AS [co] ON [enCostPoint] = [co].[Guid]  
			LEFT JOIN [vwBu] AS [bu] ON [erParentGuid] = [bu].[buGuid]  
			LEFT JOIN (select chGuid,chAccount,chDir,chdate from vwch) ch ON [erParentGuid] =  ch.chGuid   
		WHERE       
			 (([Flag] = 1) OR ([Flag] = 4) OR ([Flag] = 4) OR ([Flag] = 9) OR (([Flag] = 2) AND ([erParentType] IN (6,7,8,12,13,250,251,252,253,254,255,256,257,258,259,260,261,262)) ) OR ([Flag] = 3 AND [enAccount] <> [bu].[buCustAcc] AND ([bu].[buMatAcc] <>[enAccount] or ( [bu].[buMatAcc] =[enAccount] and btType <> 3 and  btType  <>  3))) )      
			OR ([Flag] = 2 AND [erParentType] = 5 AND ((chDir = 1 and [FixedEnDebit] > 0  ) or (chDir = 2 and [FixedEnCredit] > 0  )))  
			OR ([Flag] = 3 and [erParentType] = 600) 
	  
	-- 	INSERT Normal Entry Move      
	-- IF (@ShowOppAcc = 1)  
		UPDATE [res] SET [OppAccName]  = [acName],	[OppAccCode] = [acCode]   
		 FROM [#Result] AS [res] INNER JOIN [vwAc] ON [res].[ContraAcc] = [ACgUID]   
---------------------------------------------------------------------------       
---------------------------------------------------------------------------       
	IF( @UseChkDueDate = 0)        
		INSERT INTO [#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[branch],[CostPtr],[buTextFld1],[chState],[chDir])       
			SELECT          
				[cu].[Number],       
				[Cu].[Security],        
				0,       
				[ch].[chType],       
				[ch].[chSecurity],       
				[nt].[Security],       
				[ch].[chGUID],       
				[ch].[chNumber],     
				[ch].[chDate],         
				[ch].[chNotes],       
				(Case        
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal] * Factor       
					ELSE 0        
					END), -- EntryDebit       
				(Case        
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal] * Factor 
					ELSE 0        
					END), -- EntryCredit       
				(Case        
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * Factor        
					ELSE -[ch].[chVal] * Factor       
					END), -- Balance
				CASE ch.IsTransfered
					WHEN 0 THEN 5
					ELSE 6
				END,
				[chBranchGuid],
				[chCost1GUID],
				chnum,
				[ch].[chState],
				[ch].[chDir]     
			FROM        
				(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor   
				FROM [#vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount
				  ) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]   
				INNER JOIN [#CUST1] AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  AND ch.chCustomerGuid = cu.Number
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]         
			WHERE        
				 (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))       
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))       
				AND [chDate] <= @EndDate        
				AND 
				(
					(
						(ch.IsTransfered = 0)
						AND
						(
						[chState] IN (1, 3, 5, 6, 8, 9, 12, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
					OR 
					(
						(ch.IsTransfered = 1)
						AND
						(
						[chState] IN (0, 6, 8, 9, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
				)
				       
	ELSE
	
	 IF ( @UseChkDueDate = 1)   
		INSERT INTO        
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])       
			SELECT        
				[cu].[Number],       
				[Cu].[Security],      
				0,       
				[ch].[chType],       
				[ch].[chSecurity],       
				[nt].[Security],       
				[ch].[chGUID],       
				[ch].[chNumber],     
				[ch].[chDate],      
				[ch].[chNotes],       
				(Case        
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * Factor       
					ELSE 0        
					END), -- EntryDebit       
				(Case        
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal] * Factor  
					ELSE 0        
					END), -- EntryCredit       
				(Case        
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal] * Factor     
					ELSE -[ch].[chVal]* Factor     
					END), -- Balance     
				CASE ch.IsTransfered
					WHEN 0 THEN 5
					ELSE 6
				END,
				chbranchGuid,[chCost1GUID] ,chnum,
				[ch].[chState],
				[ch].[chDir]       
			FROM        
				(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] =  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor    
				FROM [#vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount
				 ) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
				INNER JOIN [#CUST1] AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  AND ch.chCustomerGuid = cu.Number
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]            
			WHERE        
				(( @Contain = '') OR ( [chNotes] LIKE @ContainStr))       
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))       
				AND [chDueDate] <= @EndDate        
				AND 
				(
					(
						(ch.IsTransfered = 0)
						AND
						(
						[chState] IN (1, 3, 5, 6, 8, 9, 12, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
					OR 
					(
						(ch.IsTransfered = 1)
						AND
						(
						[chState] IN (0, 6, 8, 9, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
				)
			
	ELSE  
		INSERT INTO        
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])        
			SELECT        
				[cu].[Number],       
				[Cu].[Security],      
				0,       
				[ch].[chType],       
				[ch].[chSecurity],       
				[nt].[Security],       
				[ch].[chGUID],       
				[ch].[chNumber],     
				[ch].[chDate],        
				[ch].[chNotes],       
				(Case        
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * Factor      
					ELSE 0        
					END), -- EntryDebit       
				(Case        
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal] * Factor     
					ELSE 0        
					END), -- EntryCredit       
				(Case        
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal] * Factor       
					ELSE  -[ch].[chVal]  * Factor       
					END), -- Balance     
				CASE ch.IsTransfered
					WHEN 0 THEN 5
					ELSE 6
				END,
				chbranchGuid,[chCost1GUID],chnum,
				[ch].[chState],
				[ch].[chDir]      
			FROM        
				(SELECT  *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor    
				FROM [#vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount
				 ) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
				INNER JOIN [#CUST1] AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  AND ch.chCustomerGuid = cu.Number
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]            
			WHERE        
				(( @Contain = '') OR ([chNotes] LIKE @ContainStr))       
				AND (( @NotContain = '') OR ([chNotes] NOT LIKE @NotContainStr))       
				AND [chColDate] <= @EndDate        
				AND 
				(	
					(
						(ch.IsTransfered = 0)
						AND
						(
						[chState] IN (1, 3, 5, 6, 8, 9, 12, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
					OR 
					(
						(ch.IsTransfered = 1)
						AND
						(
						[chState] IN (0, 6, 8, 9, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
				)
	
	--Calc partly collected cheques.
	--select 'aman'
	INSERT INTO        
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])         
			SELECT        
				[cu].[Number],       
				[Cu].[Security],      
				0,       
				[ch].[chType],       
				[ch].[chSecurity],       
				[nt].[Security],       
				[ch].[chGUID],       
				[ch].[chNumber],     
				[ch].[chDate],           
				[ch].[chNotes],	
							
				(Case       
					WHEN [ch].[chDir] = 2 THEN 
						CASE ch.chTransferCheck 
							when 0 then case when (@ShowChk = 0 OR @IsShowChequeDetailsPartly = 1) then [chr].[SumParts]  else [chr].[SumParts] + [chr].[RemAmount] END 
							else [chr].[RemAmount]
						end * Factor    
					ELSE 0        
					END), -- EntryDebit       
				(Case        
					WHEN [ch].[chDir] = 1 THEN 
						CASE ch.chTransferCheck 
							when 0 then case when (@ShowChk = 0 OR @IsShowChequeDetailsPartly = 1) then [chr].[SumParts]  else [chr].[SumParts] + [chr].[RemAmount] END 
							else [chr].[RemAmount]
						end * Factor    
					ELSE 0        
					END), -- EntryCredit       
			
				(Case        
					WHEN [ch].[chDir] = 2 THEN 
						CASE ch.chTransferCheck 
							when 0 then case when (@ShowChk = 0 OR @IsShowChequeDetailsPartly = 1) then [chr].[SumParts]  else [chr].[SumParts] + [chr].[RemAmount] END 
							else [chr].[RemAmount]
						END * [Factor]
					ELSE 
						CASE ch.chTransferCheck 
							when 0 then -case when (@ShowChk = 0 OR @IsShowChequeDetailsPartly = 1) then [chr].[SumParts]  else [chr].[SumParts] + [chr].[RemAmount] END
							else -[chr].[RemAmount]
						END * [Factor]
					END), -- Balance     
				CASE ch.chTransferCheck
					WHEN 0 THEN 5
					ELSE 6
				END,				
				chbranchGuid,[chCost1GUID] ,[chnum],
				CASE WHEN @IsShowChequeDetailsPartly = 1 then [ch].[chState] ELSE -2 END,
				[ch].[chDir]    
			FROM        
				(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor   
				FROM [vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount
				) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
				INNER JOIN [#CUST1] AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  AND ch.chCustomerGuid = cu.Number  
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]  
				INNER JOIN [#ChequePartAmount]  AS [chr] ON [chr].[chGuid] = [ch].[chGuid]
			WHERE        
				(CASE @UseChkDueDate WHEN 1 THEN [chDueDate] ELSE [chDate] END <= @EndDate)       
				AND (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))       
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))   
			       
	IF (@ShowChk > 0)        
	BEGIN	
		INSERT INTO        
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])         
			SELECT        
				[cu].[Number],       
				[Cu].[Security],      
				0,       
				[ch].[chType],       
				[ch].[chSecurity],       
				[nt].[Security],       
				[ch].[chGUID],       
				[ch].[chNumber],     
				[ch].[chDate],       
				[ch].[chNotes],        
				(Case       
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] *  Factor    
					ELSE 0        
					END), -- EntryDebit       
				(Case        
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal] * Factor       
					ELSE 0        
					END), -- EntryCredit       
			
				(Case        
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * [Factor]      
					ELSE -[ch].[chVal] * Factor 
					END), -- Balance     
				-1,
				chbranchGuid,
				[chCost1GUID],
				[chnum],
				[ch].[chState],
				[ch].[chDir]    
			FROM        
				(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor    
				FROM [#vwCh] ch INNER JOIN  ac000 ac on ac.Guid = ch.chAccount  
				) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
				INNER JOIN [#CUST1] AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  AND ch.chCustomerGuid = cu.Number
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid] 
			WHERE        
				(CASE @UseChkDueDate WHEN 1 THEN [chDueDate] ELSE [chDate] END <= @EndDate)       
				AND (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))       
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))   
				AND 
				(
					([ch].[chState] in (0, 7, 10,  14) ) 
					OR ([chState] = (CASE @IsEndorsedRecieved WHEN   0  THEN  4   END))
					OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 0 THEN 11   END))
				)
				AND (ch.IsTransfered = 0)
			--Calc partly
			-- IF @IsShowChequeDetailsPartly = 1	
			INSERT INTO        
				[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])         
			SELECT         
					[cu].[Number],       
					[Cu].[Security],      
					0,       
					[ch].[chType],       
					[ch].[chSecurity],       
					[nt].[Security],       
					[ch].[chGUID],       
					[ch].[chNumber],     
					[ch].[chDate],              
					[ch].[chNotes],				
					(Case       
						WHEN [ch].[chDir] = 2 THEN [chr].[RemAmount]  *  Factor    
						ELSE 0        
						END), -- EntryDebit       
					(Case        
						WHEN [ch].[chDir] = 1 THEN [chr].[RemAmount]  * Factor       
						ELSE 0        
						END), -- EntryCredit       
			
					(Case        
						WHEN [ch].[chDir] = 2 THEN [chr].[RemAmount] * [Factor]      
						ELSE -[chr].[RemAmount]  * Factor 
						END), -- Balance     
					CASE @IsShowChequeDetailsPartly when 0 THEN -2 ELSE -1 END,
					chbranchGuid,
					[chCost1GUID],
					[chnum],
					[ch].[chState],
					[ch].[chDir]    
			FROM        
				(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						-- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor    
				FROM [vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount
				 ) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
				INNER JOIN [#CUST1] AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  AND ch.chCustomerGuid = cu.Number
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]   
				INNER JOIN [#ChequePartAmount] AS [chr] ON [chr].[chGuid] = [ch].[chGuid]
			WHERE        
				(CASE @UseChkDueDate WHEN 1 THEN [chDueDate] ELSE [chDate] END <= @EndDate)  
				AND (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))       
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))   
				AND chTransferCheck = 0
						  
		IF (@IsNotShowUnDelivered = 1)
			DELETE [#Result] WHERE [Guid] IN (SELECT ChGuid FROM [vwCh] WHERE [chState] =14)  
	END		
				  
----------------------------------------------------------------------  
--Delete  Check With No Edit Entry  
	IF (@ShwChWithEn = 1)  
		DELETE [#Result] WHERE ([Flag] = 5) AND [Guid] NOT IN (SELECT [ParentGuid] FROM [er000] WHERE [ParentType] = 5)  
----------------------------------------------------------------------    
	
	EXEC [prcCheckSecurity] @UserId       
	CREATE TABLE [#PREVBAL]([PriveBalance] FLOAT, [CustPtr] UNIQUEIDENTIFIER, [RBalance] FLOAT)
	INSERT INTO [#PREVBAL] SELECT SUM(ISNULL([Balance], 0)) AS [PriveBalance],[cu].[Number] as [CustPtr],  SUM(ISNULL([RBalance],0))  AS [RBalance] FROM        
		(SELECT DISTINCT [Type], [Guid], [Balance], [flag] ,'' AS [Notes],[CustPtr]  ,0.00 AS [RBalance] 
		FROM [#Result] [r] INNER JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [r].[CustPtr]  
		WHERE [Date] < [cu].[FromDate] AND [OrderFlag] = 0 AND [IsCash] = 0 AND [FLAG] =2    
			UNION ALL   
	     SELECT  [Type], [Guid], [Balance], [flag], [Notes], [CustPtr], 0 AS [RBalance] 
		 FROM [#Result] [r] INNER JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [r].[CustPtr]  WHERE [Date] < [cu].[FromDate] AND [OrderFlag] = 0 AND [IsCash] = 0 AND [FLAG] <>2 AND [FLAG] <> 6) AS [p]   
	RIGHT JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [p].[CustPtr]	  
	GROUP BY  
		[cu].[Number]      
	IF @StartBal = 1
		UPDATE [#PREVBAL] SET [PriveBalance] = 0  
		       
	DELETE [#Result] 
	FROM 
		[#Result] [r] 
		INNER JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [r].[CustPtr]  
	WHERE [Date] < [cu].[FromDate] AND [Flag] <> 6
	   
	IF @bUnmatched = 1
		UPDATE [#PREVBAL] 
		SET 
			[RBalance] = [dbo].[fnAccCust_getBalance]([cu].[AccountGuid],
			CASE @DetailingByCurrencyAccount WHEN 0 THEN @CurPtr ELSE (CASE ISNULL(ac.CurrencyGUID, 0x0) WHEN 0x0 THEN @CurPtr ELSE ac.CurrencyGUID END) END, 
			CASE @StartBal WHEN 0 THEN '1/1/1980' ELSE [cu].[FromDate] END, @EndDate, @CostGuid ,[cu].[Number] )   
		FROM 
			[#PREVBAL] AS [r] 
			INNER JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [r].[CustPtr]
			LEFT JOIN [ac000] ac ON ac.GUID = [cu].[AccountGuid]
			     
	IF (@ShowAccMoved = 1)  
		DELETE P FROM [#PREVBAL] p
		LEFT JOIN [#RESULT] R ON p.[CustPtr] = R.[CustPtr] 
		WHERE
			R.[CustPtr] IS NULL  
	  
	INSERT INTO [#Result]([CustPtr],[Date],[BuTotal],[Balance],[Flag])
	SELECT [CustPtr], [cu].[FromDate], [PriveBalance], [RBalance], 0 
	FROM [#PREVBAL] AS [r] INNER JOIN [#CUST1] AS [cu] ON [cu].[Number] = [r].[CustPtr]
###############################################################################
###·⁄œ… “»«∆‰ »œÊ‰  ›«’Ì· 
CREATE PROCEDURE repCPS_WithoutDetails  
	@UserId			AS [UNIQUEIDENTIFIER],  
	@EndDate		AS [DATETIME],  
	@CurPtr			AS [UNIQUEIDENTIFIER],  
	@CurVal			AS [FLOAT],  
	@Post			AS [INT],	-- 1: xxx, 2: yyy, 3: zzz  
	@Cash			AS [INT],	-- 0: a, 1: b, 2: c, c: d  
	@Contain		AS [NVARCHAR](1000),  
	@NotContain		AS [NVARCHAR](1000),  
	@UseChkDueDate	AS [INT],  
	@ShowChk		AS [INT], 
	@CostGuid		AS [UNIQUEIDENTIFIER], 
	@ShowAccMoved   AS [INT] = 0, 
	@StartBal		AS [INT] = 0, 
	@bUnmatched		AS [INT] =1,
	@ShwChWithEn	AS [INT] = 0,
	-- @ShowOppAcc		AS [INT] = 0,
	@haveAccOnly	[BIT] = 0, 
	-- @Flag		BIGINT = 0,
	@IsEndorsedRecieved AS BIT = 0, 
	@IsDiscountedRecieved AS BIT = 0,
	@IsNotShowUnDelivered AS BIT = 0,
	@IsShowChequeDetailsPartly BIT = 0,
	@DetailingByCurrencyAccount  AS [BIT] = 0
AS  
	SET NOCOUNT ON
	DECLARE	      
		@ContainStr		[NVARCHAR](1000),      
		@NotContainStr	[NVARCHAR](1000)     
		
	DECLARE @StDate  [DATETIME] 
	-- prepare Parameters:	     
	SET @ContainStr = '%' + @Contain + '%'     
	SET @NotContainStr = '%' + @NotContain + '%'     
	
	DECLARE @Curr TABLE( DATE SMALLDATETIME,VAL FLOAT, CurrGuid UNIQUEIDENTIFIER)
	INSERT INTO @Curr 
		SELECT DATE,CurrencyVal, CURRENCYGuid FROM mh000 WHERE DATE <= @EndDate 
	UNION ALL 
		SELECT  '1/1/1980',CurrencyVal, Guid FROM MY000  
	-- get CustAcc	     
	-- 	INSERT BILLS MOVE  
	CREATE TABLE  [#Bill](
		[cuNumber]			UNIQUEIDENTIFIER,     
		[cuSecurity]		INT,     
		[buType]			UNIQUEIDENTIFIER,     
		[buSecurity]		INT,     
		[btSecurity]		INT, 		     
		[buGUID]			UNIQUEIDENTIFIER,     
		[buNumber]			INT,   
		[buDate]			DATETIME,     
		[biNumber]			INT,      
		[buNotes]			NVARCHAR(1000),     
		[IsCash]			BIT,    
		[BillTotal]			FLOAT,     
		FixedbuVat			FLOAT,     
		[FixedbuItemsDisc]	FLOAT,
		[FixedBuBonusDisc]	FLOAT, 
		[FixedbuItemExtra]	FLOAT,
		[FixedbuSalesTax]	FLOAT,
		[FixedBuFirstPay]	FLOAT,     
		[btReadPriceSecurity] INT,     
		[buSalesManPtr]		FLOAT, 
		[buVendor]			FLOAT,  
		[FixedCurrencyFactor] FLOAT,
		[AccountGuid]		UNIQUEIDENTIFIER,
		[FixedBuTotal]		FLOAT,
		[btDirection]		INT,
		[btType]			INT,
		[buMatAcc]			UNIQUEIDENTIFIER,
		[DIR]				INT,
		[buTextFld1]		NVARCHAR(100),
		[buTextFld2]		NVARCHAR(100),
		[buTextFld3]		NVARCHAR(100),
		[buTextFld4]		NVARCHAR(100),
		[buFormatedNumber]	INT,
		[buBranch]			UNIQUEIDENTIFIER,
		[biCostPtr]			UNIQUEIDENTIFIER,
		VS					BIT)

	INSERT INTO [#Bill]
	SELECT DISTINCT
		[cu].[Number] AS [cuNumber],     
		[cu].[Security] AS [cuSecurity],     
		[buType],     
		[buSecurity],     
		CASE [bi].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnpostedSecurity] END AS [btSecurity], 		     
		[buGUID],     
		[buNumber],   
		[buDate],     
		[biNumber],      
		[buNotes],     
		CASE     
			WHEN [buCustAcc] = [cu].[AccountGuid]  THEN 0    
			ELSE 1 END   
		AS [IsCash] ,    
		([BuTotal] + [BuVAT]) * Factor AS [BillTotal],     
		[BuVAT] * Factor FixedbuVat,     
		[buItemsDisc] * Factor [FixedbuItemsDisc],
		[BuBonusDisc] * Factor [FixedBuBonusDisc], 
		[buItemsExtra] * Factor [FixedbuItemExtra],
		buTotalSalesTax * Factor FixedBuSalesTax,
		CASE [btType] WHEN  2  THEN 0 WHEN  3  THEN 0 WHEN  4  THEN 0 WHEN  2  THEN 0 ELSE [BuFirstPay] * Factor END AS [FixedBuFirstPay],     
		[bt].[ReadPriceSecurity] AS [btReadPriceSecurity],     
		[buSalesManPtr], 
		[buVendor],  
		Factor [FixedCurrencyFactor],
		[cu].[AccountGuid],
		[BuTotal] * Factor [FixedBuTotal],
		[btDirection],
		[btType],
		[bi].[buMatAcc],
		-1 AS [DIR],
		[buTextFld1],
		[buTextFld2],
		[buTextFld3],
		[buTextFld4],
		CAST ([buNumber] AS [INT]) AS [buFormatedNumber],[buBranch],[biCostPtr],
		CASE [btVatSystem] WHEN 2 THEN 1 else 0 END AS VS      
		FROM  
		(SELECT fn.* ,1 / CASE WHEN  biCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN biCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
							 ELSE biCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE biCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  buDate  ORDER BY DATE DESC))
			    END Factor 
	FROM [fn_bubi_FixedCps]( 0X00,0X00) fn inner join cu000 cu on cu.guid = fn.buCustptr
				inner join ac000 ac on ac.guid = cu.AccountGUID ) AS [bi] 
		INNER JOIN [#BillTbl2] AS [bt] ON [bt].[Type] = [bi].[buType] 
		INNER JOIN [#CUST1] AS [cu] ON [cu].[Number] = [bi].[buCustPtr]  --OR ([cu].[AccountGuid] = [bi].[buMatAcc] )
		INNER JOIN  [#CostTbl] as [co] ON [biCostPtr] = [CO].[Guid]
	WHERE      
		[buDate] <= @EndDate     
		AND (( @Cash > 2) OR( @Cash = 0 AND [buPayType] >= 2)     
			OR((@Cash = 1) AND ( ISNULL( [buCustPtr], 0x0) = 0x0 OR [cu].[AccountGuid] <> [buCustAcc]))     
			OR( @Cash = 2 AND ([cu].[AccountGuid] = [buCustAcc] OR [cu].[AccountGuid] = [bi].[buMatAcc])))     
		AND (( @Post = 3)OR( @Post = 2 AND [buIsPosted] = 0) OR( @Post = 1 AND [buIsPosted] = 1))     
		AND (( @Contain = '') OR ( [buNotes] LIKE @ContainStr) )     
		AND (( @NotContain = '') OR (( [buNotes] NOT LIKE @NotContainStr)))
		AND NOT([btType] = 3 or [btType] = 4) 
	INSERT INTO [#Bill]	 
	SELECT DISTINCT
		[cu].[Number] AS [cuNumber],     
		[cu].[Security] AS [cuSecurity],     
		[buType],     
		[buSecurity],     
		CASE [bi].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnpostedSecurity] END AS [btSecurity], 		     
		[buGUID],     
		[buNumber],   
		[buDate],     
		[biNumber],      
		[buNotes],     
		0 AS [IsCash] ,    
		([BuTotal] + [BuVAT]) * Factor AS [BillTotal],     
		[BuVAT] * Factor [BuVAT],     
		[buItemsDisc] * Factor [FixedbuItemsDisc],
		[BuBonusDisc]  * Factor [FixedBuBonusDisc], 
		[buItemsExtra]  * Factor [FixedbuItemExtra],
		buTotalSalesTax * Factor FixedBuSalesTax,
		CASE [btType] WHEN  2  THEN 0 WHEN  3  THEN 0 WHEN  4  THEN 0 WHEN  2  THEN 0 ELSE [BuFirstPay] * Factor  END AS [FixedBuFirstPay],     
		[bt].[ReadPriceSecurity] AS [btReadPriceSecurity],     
		[buSalesManPtr], 
		[buVendor],  
		Factor,
		[cu].[AccountGuid],
		[BuTotal] * Factor,
		[btDirection],
		[btType],
		[bi].[buMatAcc],
		-1 AS [DIR],
		[buTextFld1],
		[buTextFld2],
		[buTextFld3],
		[buTextFld4],
		CAST ([buNumber] AS [INT]) AS [buFormatedNumber],[buBranch],[biCostPtr],
		CASE [btVatSystem] WHEN 2 THEN 1 else 0 END AS VS      
		
		FROM  
		(SELECT fn.* ,1 / CASE WHEN  biCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN biCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
							 ELSE biCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE biCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  buDate  ORDER BY DATE DESC))
			    END Factor 
		from [fn_bubi_FixedCps]( 0X00,0X00) fn inner join cu000 cu on cu.guid = fn.buCustptr
				inner join ac000 ac on ac.guid = cu.AccountGUID  ) AS [bi] 
		INNER JOIN [#BillTbl2] AS [bt] ON [bt].[Type] = [bi].[buType] 
		INNER JOIN [#CUST1] AS [cu] ON [cu].[AccountGuid] = [bi].[buMatAcc]
		INNER JOIN  [#CostTbl] as [co] ON [biCostPtr] = [CO].[Guid]
	WHERE      
		[buDate] <= @EndDate     
		AND (( @Cash > 2) OR( @Cash = 0 AND [buPayType] >= 2)     
			OR((@Cash = 1) AND ( ISNULL( [buCustPtr], 0x0) = 0x0 OR [cu].[AccountGuid] <> [buCustAcc]))     
			OR( @Cash = 2 AND ([cu].[AccountGuid] = [buCustAcc] OR [cu].[AccountGuid] = [bi].[buMatAcc])))     
		AND (( @Post = 3)OR( @Post = 2 AND [buIsPosted] = 0) OR( @Post = 1 AND [buIsPosted] = 1))     
		AND (( @Contain = '') OR ( [buNotes] LIKE @ContainStr) )     
		AND (( @NotContain = '') OR (( [buNotes] NOT LIKE @NotContainStr)))
		AND ([btType] = 3 or [btType] = 4) 
    CREATE  CLUSTERED INDEX [BillININDEX] ON [#Bill] ([buGUID])

	CREATE TABLE  [#Disc]([Discount] FLOAT, [ParentGuid] UNIQUEIDENTIFIER, [Extra] FLOAT)
	INSERT INTO [#Disc] SELECT  SUM( CASE WHEN [di2].[ContraAccGuid] = [B].[AccountGuid] OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) THEN [di2].[Discount] /CASE WHEN di2.CurrencyGuid = @CurPtr  THEN di2.[CurrencyVal] ELSE [FixedCurrencyFactor] END ELSE 0 END) 
	 AS [Discount],[ParentGuid],SUM(CASE WHEN [di2].[ContraAccGuid] = [B].[AccountGuid] OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) THEN [di2].[Extra]/CASE WHEN di2.CurrencyGuid = @CurPtr  THEN di2.[CurrencyVal] ELSE [FixedCurrencyFactor] END ELSE 0 END) AS [Extra]
	FROM [di000] AS di2  
	INNER JOIN (SELECT DISTINCT 1/[FixedCurrencyFactor] [FixedCurrencyFactor],[AccountGuid],[buGuid] FROM  [#Bill]) AS [b] ON [b].[buGuid] = [di2].[ParentGuid] 
	WHERE [di2].[ContraAccGuid] = [B].[AccountGuid] OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) 
	GROUP BY [ParentGuid],[FixedCurrencyFactor]
	   
	INSERT INTO [#Result]([CustPtr],[CustSecurity],[Type],[Security],[UserSecurity],[Guid],     
		[Number],[Date],[BNotes],[IsCash],[BuTotal],[BuVAT],[BuDiscount],[BuExtra],[BuSalesTax],[BuFirstPay],[UserReadPriceSecurity],     
		[Notes],[Balance],[SalesMan],[Vendor],[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4],[Flag],[FormatedNumber],[Branch],[CostPtr])      
		SELECT DISTINCT      
			[cuNumber],     
			[CuSecurity],    
			[buType],     
			[buSecurity],     
			[btSecurity], 		     
			[buGUID],     
			[buNumber],     
			[buDate],     
			[buNotes],     
			[IsCash],     
			[BillTotal],     
			[FixedBuVAT],     
			[FixedbuItemsDisc] + [FixedBuBonusDisc] + ISNULL([Discount],0),     
			[FixedbuItemExtra] + ISNULL([Extra],0),--FixedBuTotalExtra, 
			[FixedbuSalesTax],
			[FixedBuFirstPay],     
			[btReadPriceSecurity],      
			'',     
			ISNULL((( [BillTotal]/*[FixedBuTotal] + [FixedBuVAT]*/ - [FixedbuFirstPay] - ([FixedbuItemsDisc]+ [FixedBuBonusDisc] +ISNULL([Discount],0))  + [FixedbuItemExtra] + ISNULL([Extra],0) + [FixedbuSalesTax])* [DIR]*[btDirection] ), 0), 
			[buSalesManPtr],  
			[buVendor],
			[buTextFld1],
			[buTextFld2],
			[buTextFld3],
			[buTextFld4],  
			2, -- Flag
			[buFormatedNumber],[buBranch],[biCostPtr]      
		FROM  
			[#Bill] AS [b]  LEFT JOIN [#Disc] AS [d] ON [d].[ParentGuid] = [b].[buGUID]

	-- 	INSERT ENTRY MOVE 
	CREATE TABLE [#ENTRY](       
		[cuNumber]		UNIQUEIDENTIFIER,       
		[cuSecurity]	INT,        
		[ceTypeGuid]	UNIQUEIDENTIFIER,   
		[enGuid]		UNIQUEIDENTIFIER,    
		[ceSecurity]	INT,        
		[Security]		INT,       
		[ceGuid]		UNIQUEIDENTIFIER,     
		[ceNumber]		INT,     
		[enDate]		DATETIME,        
		[enNumber]		INT,        
		[ceNotes]		NVARCHAR(256),        
		[FixedEnDebit]	FLOAT,        
		[FixedEnCredit] FLOAT,        
		[enNotes]		NVARCHAR(1000),        
		[Balance]		FLOAT,       
		[enContraAcc]	UNIQUEIDENTIFIER,   
		[FFLAG]			INT,    
		[erParentType]	INT,  
		[Flag]			INT,  
		[erParentGuid]  UNIQUEIDENTIFIER,  
		[enAccount]     UNIQUEIDENTIFIER,  
		[enCostPoint]   UNIQUEIDENTIFIER,  
		[ceBranch]      UNIQUEIDENTIFIER)

	INSERT INTO [#ENTRY]
	SELECT     
			[cu].[Number] AS [cuNumber],     
			[Cu].[Security] AS [cuSecurity],      
			[f].[ceTypeGuid],
			[enGuid] ,
			[f].[ceSecurity],      
			[t].[Security],     
			CASE [t].[Flag] WHEN 1 THEN [er].[erParentGuid] ELSE  [f].[ceGuid] END  [ceGuid],   
			[f].[ceNumber],   
			[f].[enDate],      
			[f].[enNumber],      
			[f].[enNotes],      
			[f].[EnDebit]* Factor [FixedEnDebit],      
			[f].[EnCredit]* Factor [FixedEnCredit],      
			[f].[enNotes] ,      
			ISNULL(([f].[EnDebit] - [f].[EnCredit]), 0) * Factor AS [Balance],     
			[enContraAcc], 
			CASE [t].[Flag] WHEN 1 THEN 4 WHEN 2 THEN CASE [er].[erParentType] WHEN 5 THEN 1 ELSE [er].[erParentType] END  ELSE 1 END AS [FFLAG],  
			[er].[erParentType],
			[t].[Flag],
			ISNULL([er].[erParentGuid],0X00) [erParentGuid],
			[f].[enAccount],
			[f].[enCostPoint],
			[ceBranch]
		FROM      
			(SELECT *,1 / CASE WHEN  enCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN enCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  enDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  enDate  ORDER BY DATE DESC) 
							 ELSE enCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE enCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  enDate  ORDER BY DATE DESC))
			    END Factor 
			FROM vwCeEn inner join ac000 ac on ac.guid = enAccount) AS [f]
			INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] =[f].[enAccount]    
			LEFT JOIN [vwEr] AS [er]     
			ON [f].[ceGuid] = [er].[erEntryGuid]     
			INNER JOIN [#EntrySource] AS [t]     
			ON [f].[ceTypeGuid] = [t].[Type] --AND [t].Flag <> 3
			LEFT JOIN [vwAc] AS [Ac]  ON [Ac].[acGuid]=[f].[enContraAcc]
		WHERE     
			 [f].[enDate] <= @EndDate
			AND (( @Contain = '') OR ([f].[enNotes] LIKE @ContainStr) OR ([f].[ceNotes] LIKE @ContainStr)  )     
			AND (( @NotContain = '') OR (( [f].[enNotes] NOT LIKE @NotContainStr)  AND ( [f].[ceNotes] NOT LIKE @NotContainStr))) 
			AND  ([cu].[Number] = [f].enCustomerGUID)
	
	CREATE CLUSTERED INDEX entryParentType ON [#ENTRY]([erParentGuid])      
	 INSERT INTO [#Result] ([CustPtr],[CustSecurity],[Type],[Security],[UserSecurity],[Guid],[Number],[Date], [BNotes],[EntryDebit],[EntryCredit],[Notes],[Balance],[ContraAcc],[Flag],[Branch],[CostPtr],[enGuid])     
		SELECT     
			[cuNumber],     
			[CuSecurity],    
			[ceTypeGuid],   
			[ceSecurity],      
			[#ENTRY].[Security],     
			[ceGuid],   
			[ceNumber],      
			CASE WHEN erparenttype = 13 THEN chdate ELSE [enDate] END AS enDate,
			[ceNotes],      
			[FixedEnDebit],  -- EntryDebit      
			[FixedEnCredit], -- EntryCredit,      
			[enNotes],      
			[Balance],     
			[enContraAcc], 
			CASE WHEN erparenttype = 6 THEN 1 ELSE [FFlag] END, 
			[CeBranch],
			[enCostPoint],
			[enGuid]
		FROM
			[#ENTRY]
			INNER JOIN  [#CostTbl] AS [co] ON [enCostPoint] = [co].[Guid]
			LEFT JOIN [vwBu] AS [bu] ON [erParentGuid] = [bu].[buGuid] 
			LEFT JOIN (select chGuid,chAccount,chDir,chdate from vwch) ch ON [erParentGuid] =  ch.chGuid  
		WHERE     
			([Flag] = 1) OR ([Flag] = 4) OR ([Flag] = 9) OR (([Flag] = 2) AND ([erParentType] IN (6, 7, 8, 12, 13,250,251,252,253,254,255,256,257,258,259,260,261,262))) OR ([Flag] = 3 AND((@haveAccOnly = 1) OR ( [enAccount] <> [bu].[buCustAcc] AND ([bu].[buMatAcc] <>[enAccount] or ( [bu].[buMatAcc] =[enAccount] and btType <> 3 and  btType  <>  3)))))    
			OR ([Flag] = 2 AND [erParentType] = 5 AND ((chDir = 1 and [FixedEnDebit] > 0  ) or (chDir = 2 and [FixedEnCredit] > 0  )))
			OR ([Flag] = 3 and [erParentType] = 600)
	 -- IF (@ShowOppAcc = 1)
	UPDATE [res] SET [OppAccName]  = [acName],	[OppAccCode] = [acCode] 
	FROM [#Result] AS [res] INNER JOIN [vwAc] ON [res].[ContraAcc] = [ACgUID] 
---------------------------------------------------------------------------     
---------------------------------------------------------------------------  
	IF( @UseChkDueDate = 0) 
	BEGIN     
		INSERT INTO      
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])     
			SELECT      
				[cu].[Number],     
				[Cu].[Security],      
				0,     
				[ch].[chType],     
				[ch].[chSecurity],     
				[nt].[Security],     
				[ch].[chGUID],     
				[ch].[chNumber],   
				[ch].[chDate],          
				[ch].[chNotes],     
				(Case      
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal] * Factor     
					ELSE 0      
					END), -- EntryDebit     
				(Case      
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal] * Factor 
					ELSE 0      
					END), -- EntryCredit     
				(Case      
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * Factor    
					ELSE -[ch].[chVal] * Factor 
					END), -- Balance  
				CASE ch.IsTransfered
					WHEN 0 THEN 5
					ELSE 6
				END,
				chbranchGuid,[chCost1GUID],chnum,
				[ch].[chState],
				[ch].[chDir]       
			FROM      
				(SELECT *,1 /CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor 
				FROM [#vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount
				)AS [ch]
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type] 
				INNER JOIN [#CUST1] AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  AND ch.chCustomerGuid = cu.Number
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]       
				    
			WHERE      
				 (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))     
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))     
				AND [chDate] <= @EndDate      
				AND 
				(
					(
						(ch.IsTransfered = 0)
						AND
						(
						[chState] IN (1, 3, 5, 6, 8, 9, 12, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
					OR 
					(
						(ch.IsTransfered = 1)
						AND
						(
						[chState] IN (0, 6, 8, 9, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
				)
				END
	ELSE IF ( @UseChkDueDate = 1)     
		INSERT INTO      
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])     
			SELECT      
				[cu].[Number],     
				[Cu].[Security],    
				0,     
				[ch].[chType],     
				[ch].[chSecurity],     
				[nt].[Security],     
				[ch].[chGUID],     
				[ch].[chNumber],   
				[ch].[chDate],          
				[ch].[chNotes],     
				(Case      
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * Factor    
					ELSE 0      
					END), -- EntryDebit     
				(Case      
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal]  * Factor    
					ELSE 0      
					END), -- EntryCredit     
				(Case      
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal] * Factor    
					ELSE  -[ch].[chVal] * Factor 
					END), -- Balance   
				CASE ch.IsTransfered
					WHEN 0 THEN 5
					ELSE 6
				END,
				chbranchGuid,[chCost1GUID],chnum,
				[ch].[chState],
				[ch].[chDir]        
			FROM      
				(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor  
				FROM [#vwCh] ch INNER JOIN  ac000 ac on ac.Guid = ch.chAccount) AS [ch]
				 INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]
				 INNER JOIN [#CUST1] AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  AND ch.chCustomerGuid = cu.Number
				 INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]          
			WHERE      
				(( @Contain = '') OR ( [chNotes] LIKE @ContainStr))     
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))     
				AND [chDueDate] <= @EndDate      
				AND 
				(
					(
						(ch.IsTransfered = 0)
						AND
						(
						[chState] IN (1, 3, 5, 6, 8, 9, 12, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
					OR 
					(
						(ch.IsTransfered = 1)
						AND
						(
						[chState] IN (0, 6, 8, 9, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
				)
				 
	ELSE      
		INSERT INTO      
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[Costptr],[buTextFld1],[chState],[chDir])      
			SELECT      
				[cu].[Number],     
				[Cu].[Security],    
				0,     
				[ch].[chType],     
				[ch].[chSecurity],     
				[nt].[Security],     
				[ch].[chGUID],     
				[ch].[chNumber],   
				[ch].[chDate],       
				[ch].[chNotes],     
				(Case      
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * Factor   
					ELSE 0      
					END), -- EntryDebit     
				(Case      
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal]* Factor 
					ELSE 0      
					END), -- EntryCredit     
				(Case      
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal] * Factor     
					ELSE  -[ch].[chVal] * Factor  
					END), -- Balance   
				CASE ch.IsTransfered
					WHEN 0 THEN 5
					ELSE 6
				END,
				chbranchGuid,[chCost1GUID],chnum,
				[ch].[chState],
				[ch].[chDir]      
			FROM      
				(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor 
				FROM [#vwCh] ch INNER JOIN  ac000 ac on ac.Guid = ch.chAccount
				) AS [ch] 
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]
				INNER JOIN [#CUST1] AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  AND ch.chCustomerGuid = cu.Number
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]          
			WHERE      
				(( @Contain = '') OR ([chNotes] LIKE @ContainStr))     
				AND (( @NotContain = '') OR ([chNotes] NOT LIKE @NotContainStr))     
				AND [chColDate] <= @EndDate      
				AND 
				(	
					(
						(ch.IsTransfered = 0)
						AND
						(
						[chState] IN (1, 3, 5, 6, 8, 9, 12, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
					OR 
					(
						(ch.IsTransfered = 1)
						AND
						(
						[chState] IN (0, 6, 8, 9, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
				)
	--Calc partly collected cheques. write here
	
	INSERT INTO        
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])         
			SELECT       
				[cu].[Number],       
				[Cu].[Security],      
				0,       
				[ch].[chType],       
				[ch].[chSecurity],       
				[nt].[Security],       
				[ch].[chGUID],       
				[ch].[chNumber],     
				[ch].[chDate],          
				[ch].[chNotes],
				
				(Case       
					WHEN [ch].[chDir] = 2 THEN 
						CASE ch.chTransferCheck 
							when 0 then case when (@ShowChk = 0 OR @IsShowChequeDetailsPartly = 1) then [chr].[SumParts]  else [chr].[SumParts] + [chr].[RemAmount] END 
							else [chr].[RemAmount]
						end * Factor    
					ELSE 0        
					END), -- EntryDebit       
				(Case        
					WHEN [ch].[chDir] = 1 THEN 
						CASE ch.chTransferCheck 
							when 0 then case when (@ShowChk = 0 OR @IsShowChequeDetailsPartly = 1) then [chr].[SumParts]  else [chr].[SumParts] + [chr].[RemAmount] END 
							else [chr].[RemAmount]
						end * Factor    
					ELSE 0        
					END), -- EntryCredit       
			
				(Case        
					WHEN [ch].[chDir] = 2 THEN 
						CASE ch.chTransferCheck 
							when 0 then case when (@ShowChk = 0 OR @IsShowChequeDetailsPartly = 1) then [chr].[SumParts]  else [chr].[SumParts] + [chr].[RemAmount] END 
							else [chr].[RemAmount]
						END * [Factor]
					ELSE 
						CASE ch.chTransferCheck 
							when 0 then -case when (@ShowChk = 0 OR @IsShowChequeDetailsPartly = 1) then [chr].[SumParts]  else [chr].[SumParts] + [chr].[RemAmount] END
							else -[chr].[RemAmount]
						END * [Factor]
					END), -- Balance     
				CASE ch.chTransferCheck
					WHEN 0 THEN 5
					ELSE 6
				END,			
				chbranchGuid,[chCost1GUID] ,[chnum],
				CASE WHEN @IsShowChequeDetailsPartly = 1 then [ch].[chState] ELSE -2 END,
				[ch].[chDir]     
			FROM        
				(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor 
				FROM [vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount
				) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
				INNER JOIN [#CUST1] AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  AND ch.chCustomerGuid = cu.Number
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]  
				INNER JOIN [#ChequePartAmount]  AS [chr] ON [chr].[chGuid] = [ch].[chGuid]
			WHERE        
				(CASE @UseChkDueDate WHEN 1 THEN [chDueDate] ELSE [chDate] END <= @EndDate)       
				AND (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))       
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))   
	   

-----------------------------------------------------------------------------------     
-----------------------------------------------------------------------------------     
	IF( @ShowChk > 0)      
BEGIN		
		INSERT INTO      
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])         
			SELECT       
				[cu].[Number],       
				[Cu].[Security],      
				0,       
				[ch].[chType],       
				[ch].[chSecurity],       
				[nt].[Security],       
				[ch].[chGUID],       
				[ch].[chNumber],     
				[ch].[chDate],       
				[ch].[chNotes],
				(Case       
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] *  Factor    
					ELSE 0        
					END), -- EntryDebit       
				(Case        
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal] * Factor       
					ELSE 0        
					END), -- EntryCredit       
			
				(Case        
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * [Factor]      
					ELSE -[ch].[chVal] * Factor 
					END), -- Balance     
				-1,chbranchGuid,[chCost1GUID] ,[chnum],
				[ch].[chState],
				[ch].[chDir]     
			FROM        
				(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor  
				FROM [#vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount
				 ) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
				INNER JOIN [#CUST1] AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  AND ch.chCustomerGuid = cu.Number
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]   
			WHERE        
				(CASE @UseChkDueDate WHEN 1 THEN [chDueDate] ELSE [chDate] END <= @EndDate)       
				AND (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))       
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))   
				AND 
				(
					([ch].[chState] in (0, 7, 10,  14) ) 
					OR ([chState] = (CASE @IsEndorsedRecieved WHEN   0  THEN  4   END))
					OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 0 THEN 11   END))
				)
				AND (ch.IsTransfered = 0)				

			--Calc partly write here
		-- IF @IsShowChequeDetailsPartly = 1	
		INSERT INTO      
				[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])         
			SELECT    
				[cu].[Number],     
				[Cu].[Security],    
				0,     
				[ch].[chType],     
				[ch].[chSecurity],     
				[nt].[Security],     
				[ch].[chGUID],     
				[ch].[chNumber],   
				[ch].[chDate],      
				[ch].[chNotes],      
				
				(Case     
						WHEN [ch].[chDir] = 2 THEN [chr].[RemAmount] *  Factor    
					ELSE 0      
					END), -- EntryDebit     
				(Case      
						WHEN [ch].[chDir] = 1 THEN [chr].[RemAmount] *  Factor       
					ELSE 0      
					END), -- EntryCredit     
			
				(Case      
						WHEN [ch].[chDir] = 2 THEN [chr].[RemAmount] *  Factor       
						ELSE -[chr].[RemAmount] *  Factor 
					END), -- Balance   
					CASE @IsShowChequeDetailsPartly when 0 THEN -2 ELSE -1 END,chbranchGuid,[chCost1GUID] ,[chnum],
					[ch].[chState],
					[ch].[chDir]     
			FROM      
				(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor 
				FROM [vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount
				) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
				INNER JOIN [#CUST1] AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  AND ch.chCustomerGuid = cu.Number
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid] 
				INNER JOIN [#ChequePartAmount] AS [chr] ON [chr].[chGuid] = [ch].[chGuid]
			WHERE      
				(CASE @UseChkDueDate WHEN 1 THEN [chDueDate] ELSE [chDate] END <= @EndDate)
				AND (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))     
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr)) 
				AND chTransferCheck = 0

		IF (@IsNotShowUnDelivered = 1)
			DELETE [#Result] WHERE [Guid] IN (SELECT ChGuid FROM [vwCh] WHERE [chState] =14)  
END		
-----------------------------------------------------------------------	     
--Delete  Check With No Edit Entry
	IF (@ShwChWithEn = 1)
		DELETE [#Result] WHERE  ([Flag] = 5) AND [Guid] NOT IN (SELECT [ParentGuid] FROM [er000] WHERE [ParentType] =5)
----------------------------------------------------------------------      
	EXEC [prcCheckSecurity] @UserId     
	     
	DECLARE @PriveBalance [FLOAT]      
	CREATE TABLE [#PREVBAL]([PriveBalance] FLOAT, [CustPtr] UNIQUEIDENTIFIER, [RBalance] FLOAT)
	INSERT INTO [#PREVBAL] SELECT SUM(ISNULL([Balance], 0)) AS [PriveBalance],[cu].[Number] as [CustPtr],  SUM(ISNULL([RBalance],0)) AS [RBalance] FROM      
		(SELECT DISTINCT [Type], [Guid], [Balance], [flag] ,'' AS [Notes],[CustPtr]  ,0.00 AS [RBalance] FROM [#Result] [r] INNER JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [r].[CustPtr]  WHERE [Date] < [cu].[FromDate] AND [OrderFlag] = 0 AND [IsCash] = 0 AND [FLAG] = 2  
			UNION ALL 
	     SELECT  [Type], [Guid], [Balance], [flag], [Notes], [CustPtr], 0 AS [RBalance] FROM [#Result] [r] INNER JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [r].[CustPtr]  WHERE [Date] < [cu].[FromDate] AND [OrderFlag] = 0 AND [IsCash] = 0 AND [FLAG] <> 2 AND [Flag] <> 6) AS [p] 
	RIGHT JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [p].[CustPtr]	
	GROUP BY
		[cu].[Number]    
	
	IF @StartBal=1 
		UPDATE [#PREVBAL] SET [PriveBalance] =0
	    
	DELETE [#Result] FROM [#Result] [r] INNER JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [r].[CustPtr]  WHERE [Date] < [cu].[FromDate] AND [Flag] <> 6
	 
	IF @bUnmatched = 1
		UPDATE [#PREVBAL] 
		SET 
			[RBalance] = [dbo].[fnAccCust_getBalance]([cu].[AccountGuid], 
			CASE @DetailingByCurrencyAccount WHEN 0 THEN @CurPtr ELSE (CASE ISNULL(ac.CurrencyGUID, 0x0) WHEN 0x0 THEN @CurPtr ELSE ac.CurrencyGUID END) END, 
			CASE @StartBal WHEN 0 THEN '1/1/1980' ELSE [cu].[FromDate] END, @EndDate, @CostGuid, [cu].[Number])   
		FROM 
			[#PREVBAL] AS [r] 
			INNER JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [r].[CustPtr]
			LEFT JOIN [ac000] ac ON ac.GUID = [cu].[AccountGuid]
 			    
	IF (@ShowAccMoved=1)
		DELETE [#PREVBAL] WHERE [CustPtr] NOT IN (SELECT DISTINCT [CustPtr] FROM [#RESULT])
	
	INSERT INTO [#Result]([CustPtr], [Date],[BuTotal],[Balance],[Flag]) SELECT [CustPtr],[cu].[FromDate],[PriveBalance],[RBalance],0   FROM [#PREVBAL] AS [r] INNER JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [r].[CustPtr] 	
###############################################################################
###“»Ê‰ ÊÕÌœ „⁄  ›«’Ì· 
CREATE PROCEDURE repCPS_WithDetails_OneCust 
	@serialNumber [bit] = 0,  
	@UserId			AS [UNIQUEIDENTIFIER],  
	@StartDate		AS [DATETIME],  
	@EndDate		AS [DATETIME],  
	@CustPtr		AS [UNIQUEIDENTIFIER],  
	@CustSec		AS [INT],  
	@CurPtr			AS [UNIQUEIDENTIFIER],  
	@CurVal			AS [FLOAT],  
	@Post			AS [INT],	-- 1: xxx, 2: yyy, 3: zzz  
	@Cash			AS [INT],	-- 0: a, 1: b, 2: c, c: d  
	@Contain		AS [NVARCHAR](1000),  
	@NotContain		AS [NVARCHAR](1000),  
	@UseChkDueDate	AS [INT],  
	@ShowChk		AS [INT], 
	@CostGuid		AS [UNIQUEIDENTIFIER], 
	@ShowAccMoved   AS [INT] = 0, 
	@StartBal		AS [INT] = 0, 
	@bUnmatched		AS [INT] =1, 
	@ShwChWithEn	AS [INT] = 0, 
	@ShowDiscExtDet AS [INT] = 0, 
	-- @ShowOppAcc		AS [INT] = 0, 
	-- @Flag	BIGINT = 0,
	@IsEndorsedRecieved AS BIT = 0, 
	@IsDiscountedRecieved AS BIT = 0,
	@IsNotShowUnDelivered AS BIT = 0,
	@IsShowChequeDetailsPartly BIT = 0,
	@ShowValVat AS [BIT] = 0,
	@DetailingByCurrencyAccount  AS [BIT] = 0,
	@AccGuid		AS [UNIQUEIDENTIFIER] = 0x0
AS   
	SET NOCOUNT ON  
	DECLARE	
		--@UserId			[INT],       
		@ContainStr		[NVARCHAR](1000),      
		@NotContainStr	[NVARCHAR](1000),      
		@StDate  [DATETIME] 
	-- prepare Parameters:	     
	SET @ContainStr = '%' + @Contain + '%'     
	SET @NotContainStr = '%' + @NotContain + '%' 
	 
	DECLARE @Curr TABLE( DATE SMALLDATETIME,VAL FLOAT, CurrGuid UNIQUEIDENTIFIER)
	INSERT INTO @Curr  
		SELECT DATE,CurrencyVal, CURRENCYGuid FROM mh000 WHERE DATE <= @EndDate 
	UNION ALL  
		SELECT  '1/1/1980',CurrencyVal, Guid FROM MY000      
	     
	-- get CustAcc	     
	--SELECT @AccGuid = [AccountGUID] FROM [cu000] WHERE [GUID] = @CustPtr     
	-- 	INSERT BILLS MOVE
	CREATE TABLE [#bill](
			[buType]					[UNIQUEIDENTIFIER],       
			[buSecurity]				[int],        
			[btSecurity]				[int], 		       
			[buGUID]					[UNIQUEIDENTIFIER],       
			[buNumber]					[int], 
			[buDate]					[DATETIME],
			[biNumber]					[int],        
			[buNotes]					[NVARCHAR](1000) COLLATE ARABIC_CI_AI,
			[IsCash]					[bit],      
			[BillTotal]					[FLOAT],       
			[FixedBuVAT]				[FLOAT],       
			[FixedbuItemsDisc]			[FLOAT],  
			[FixedBuBonusDisc]			[FLOAT],   
			[FixedbuItemExtra]			[FLOAT],  
			[FixedbuSalesTax]			[FLOAT],
			[FixedBuFirstPay]			[FLOAT],       
			[btReadPriceSecurity]		[int],     
			[biMatPtr]					[UNIQUEIDENTIFIER],  
			[stName]					[NVARCHAR](300) COLLATE ARABIC_CI_AI,     
			[biQty]						[FLOAT],       
			[biBonusQnt]				[FLOAT],       
			[biUnity]					[INT],       
			[biQty2]					[FLOAT],       
			[biQty3]					[FLOAT],       
			[biExpireDate] 				[DATETIME],
			[biProductionDate]  		 [DATETIME],
		    [biCostPtr]					 [UNIQUEIDENTIFIER],       
			[biClassPtr]				 [NVARCHAR](300) COLLATE ARABIC_CI_AI,       
			[biLength]					 [FLOAT],       
			[biWidth]					 [FLOAT],       
			[biHeight]					 [FLOAT],    
			[biCount]			         [FLOAT],
			[FixedBiPrice]				 [FLOAT],       
			[FixedBiDiscount]			 [FLOAT],   
			[FixedbiBonusDisc]			 [FLOAT],      
			[FixedbiExtra]				 [FLOAT],       
			[FixedbiVAT]				 [FLOAT],
			[biVatRatio]				 [FLOAT],
			[biNotes]					 [NVARCHAR](1000) COLLATE ARABIC_CI_AI DEFAULT '',       
			[buSalesManPtr]				 [FLOAT],    
			[buVendor]					 [FLOAT],    
			[mtSecurity]				 [INT],  
			[FixedCurrencyFactor]		 [FLOAT],  
			[BuTotal]					 [FLOAT],  
			[btDirection]				 [INT],  
		    [btBillType]				 [INT],	
			[buTextFld1]				 [NVARCHAR](300) COLLATE ARABIC_CI_AI DEFAULT '',  
			[buTextFld2]				 [NVARCHAR](300) COLLATE ARABIC_CI_AI DEFAULT '',  
			[buTextFld3]				 [NVARCHAR](300) COLLATE ARABIC_CI_AI DEFAULT '',  
			[buTextFld4]				 [NVARCHAR](300) COLLATE ARABIC_CI_AI DEFAULT '',  
			[buFormatedNumber]			 [INT], 
			[buBranch]					 [UNIQUEIDENTIFIER] DEFAULT 0X00,  
			VS							 [INT],
			SN							 [NVARCHAR](300) COLLATE ARABIC_CI_AI ,
			SNGUID						 [UNIQUEIDENTIFIER],
			SNItem							[INT]
			) 
		
	IF( @serialNumber = 0)     
		ALTER TABLE      
			[#bill]     
		DROP COLUMN     
			[sn],     
			SNGUID,
			SNItem 
		
	if @serialNumber = 1
	BEGIN 
					
	INSERT INTO [#Bill]([buType],[buSecurity],[btSecurity],[buGUID],[buNumber],[buDate],[biNumber],[buNotes],[IsCash],[BillTotal],[FixedBuVAT],
	[FixedbuItemsDisc],[FixedBuBonusDisc],[FixedbuItemExtra],[FixedbuSalesTax],[FixedBuFirstPay],[btReadPriceSecurity],[biMatPtr],[stName],
	[biQty],[biBonusQnt],[biUnity],	[biQty2],[biQty3],[biExpireDate] ,[biProductionDate],[biCostPtr],			
	[biClassPtr],[biLength],[biWidth],[biHeight],[biCount],[FixedBiPrice],[FixedBiDiscount],[FixedbiBonusDisc],[FixedbiExtra],[FixedbiVAT],[biVatRatio],[biNotes],				
	[buSalesManPtr]	,[buVendor],[mtSecurity],[FixedCurrencyFactor],[BuTotal],
	[btDirection],[btBillType],[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4],[buFormatedNumber],[buBranch],VS, SN, SNGUID, SNItem)
		SELECT       
			[buType],      
			[buSecurity],      
			CASE [bi].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnpostedSecurity] END  AS [btSecurity], 		      
			[buGUID],      
			[buNumber],    
			[buDate],      
			[biNumber],       
			[buNotes],      
			CASE [btType] WHEN  3 THEN 0 WHEN  4 THEN 0 WHEN  2 THEN 0 
			ELSE	CASE      
					WHEN [buCustAcc] = @AccGuid  THEN 0     
					ELSE 1 END    
			END AS [IsCash] ,     
			([BuTotal] + [BuVAT]) * Factor AS [BillTotal],      
			[BuVAT] * Factor [FixedBuVAT],
			      
			[buItemsDisc]* Factor [FixedbuItemsDisc], 
			[BuBonusDisc]* Factor [FixedBuBonusDisc],  
			[buItemsExtra] * Factor [FixedbuItemExtra],  
			buTotalSalesTax * Factor FixedBuSalesTax,
		    CASE [btType] WHEN  2  THEN 0 WHEN  3  THEN 0 WHEN  4  THEN 0 ELSE [BuFirstPay] * Factor END AS [FixedBuFirstPay],            
			[bt].[ReadPriceSecurity] AS [btReadPriceSecurity],      
			[biMatPtr],      
			[St].[stName] AS [stName],
			1 as biqty,      
			[biBonusQnt],      
			[biUnity],      
			[biQty2],      
			[biQty3],      
			[biExpireDate],      
			[biProductionDate],      
			[biCost_Ptr] [biCostPtr],      
			[biClassPtr],      
			[biLength],      
			[biWidth],      
			[biHeight],  
			[biCount], 
			 		   
			[BiPrice] * Factor [BiPrice] ,      
			[BiDiscount]* Factor [FixedBiDiscount],  
			[biBonusDisc]* Factor [FixedbiBonusDisc],    
			[biExtra]* Factor [FixedbiExtra],      
			[biVat] * Factor [FixedbiVAT],
			[biVatRatio],   
			[biNotes], 
			     
			[buSalesManPtr],  
			[buVendor],   
			[mtSecurity], 
			Factor [FixedCurrencyFactor], 
			[BuTotal]* Factor [FixedBuTotal], 
			[btDirection], 
			[btType] AS [btBillType], 
			[buTextFld1], 
			[buTextFld2], 
			[buTextFld3], 
			[buTextFld4], 
			CAST ([buNumber] AS [INT]) AS [buFormatedNumber],
			[buBranch], 
			CASE [btVatSystem] WHEN 2 THEN 1 else 0 END AS VS,
			SN,
			SNGUID,
			SNItem
		FROM   
			(SELECT snc.SN as SN,snc.guid as SNGUID, snt.Item as SNItem, fn.* ,
				1 /  CASE WHEN  biCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN biCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
							 ELSE biCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE biCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  buDate  ORDER BY DATE DESC))
			    END Factor   
				from [fn_bubi_FixedCps]( @CustPtr,@AccGuid) fn
				inner join snc000 snc on snc.matguid = bimatptr
				inner join snt000 snt on (snt.buguid = fn.buguid and snt.parentguid = snc.guid)
				inner join cu000 cu on cu.guid = fn.buCustPtr
				inner join ac000 ac on ac.guid = cu.AccountGUID ) AS [bi] 
			INNER JOIN [#BillTbl2] AS [bt] ON [bt].[Type] = [bi].[buType]        
			INNER JOIN [vwSt] AS [st] ON [st].[stGUID] = [bi].[biStorePtr]  
			INNER JOIN [#MatTbl] AS [mt] ON [mt].[MatGuid] = [bi].[biMatPtr] 
			INNER JOIN  [#CostTbl] as [co] ON [biCostPtr] = [CO].[Guid] 
		WHERE       
			[buDate] <= @EndDate  
			AND (( @Cash > 2) OR( @Cash = 0 AND [buPayType] >= 2)      
				OR((@Cash = 1) AND ( ISNULL( [buCustPtr], 0x0) = 0x0 OR @AccGuid <> [buCustAcc]))      
				OR( @Cash = 2 AND (@AccGuid= [buCustAcc] OR @AccGuid = [bi].[buMatAcc])))      
			AND (( @Post = 3)OR( @Post = 2 AND [buIsPosted] = 0) OR( @Post = 1 AND [buIsPosted] = 1))      
			AND (( @Contain = '') OR ( [buNotes] LIKE @ContainStr) OR ([biNotes] LIKE @ContainStr))      
			AND (( @NotContain = '') OR (( [buNotes] NOT LIKE @NotContainStr) AND ([biNotes] NOT LIKE @NotContainStr)))
			
		

		
		INSERT INTO [#Bill]([buType],[buSecurity],[btSecurity],[buGUID],[buNumber],[buDate],[biNumber],[buNotes],[IsCash],[BillTotal],[FixedBuVAT],
		[FixedbuItemsDisc],[FixedBuBonusDisc],[FixedbuItemExtra],[FixedbuSalesTax],[FixedBuFirstPay],[btReadPriceSecurity],[biMatPtr],[stName],
		[biQty],[biBonusQnt],[biUnity],	[biQty2],[biQty3],[biExpireDate] ,[biProductionDate],[biCostPtr],			
		[biClassPtr],[biLength],[biWidth],[biHeight],[biCount],[FixedBiPrice],[FixedBiDiscount],[FixedbiBonusDisc],[FixedbiExtra],[FixedbiVAT],[biVatRatio],[biNotes],				
		[buSalesManPtr]	,[buVendor],[mtSecurity],[FixedCurrencyFactor],[BuTotal],
		[btDirection],[btBillType],[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4],[buFormatedNumber],[buBranch],VS, SN, SNGUID, SNItem)
		SELECT       
				[buType],      
				[buSecurity],      
				CASE [bi].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnpostedSecurity] END  AS [btSecurity], 		      
				[buGUID],      
				[buNumber],    
				[buDate],      
				[biNumber],       
				[buNotes],      
				CASE [btType] WHEN  3 THEN 0 WHEN  4 THEN 0 WHEN  2 THEN 0 
				ELSE	CASE      
						WHEN [buCustAcc] = @AccGuid  THEN 0     
						ELSE 1 END    
				END AS [IsCash] ,     
				([BuTotal] + [BuVAT]) * Factor AS [BillTotal],      
				[BuVAT] * Factor [FixedBuVAT],      
				[buItemsDisc]* Factor [FixedbuItemsDisc], 
				[BuBonusDisc]* Factor [FixedBuBonusDisc],  
				[buItemsExtra] * Factor [FixedbuItemExtra],  
				buTotalSalesTax * Factor FixedBuSalesTax,
				CASE [btType] WHEN  2  THEN 0 WHEN  3  THEN 0 WHEN  4  THEN 0 ELSE [BuFirstPay] * Factor END AS [FixedBuFirstPay],            
				[bt].[ReadPriceSecurity] AS [btReadPriceSecurity],      
				[biMatPtr],      
				[St].[stName] AS [stName],    
				[biQty],      
				[biBonusQnt],      
				[biUnity],      
				[biQty2],      
				[biQty3],      
				[biExpireDate],      
				[biProductionDate],      
				[biCost_Ptr] [biCostPtr],      
				[biClassPtr],      
				[biLength],      
				[biWidth],      
				[biHeight],  
				[biCount],     
				[BiPrice] * Factor [BiPrice] ,      
				[BiDiscount]* Factor [FixedBiDiscount],  
				[biBonusDisc]* Factor [FixedbiBonusDisc],    
				[biExtra]* Factor [FixedbiExtra],      
				[biVat]* Factor [FixedbiVAT],
				[biVatRatio],
				[biNotes],      
				[buSalesManPtr],  
				[buVendor],   
				[mtSecurity], 
				Factor [FixedCurrencyFactor], 
				[BuTotal]* Factor [FixedBuTotal], 
				[btDirection], 
				[btType] AS [btBillType], 
				[buTextFld1], 
				[buTextFld2], 
				[buTextFld3], 
				[buTextFld4], 
				CAST ([buNumber] AS [INT]) AS [buFormatedNumber],[buBranch], 
				CASE [btVatSystem] WHEN 2 THEN 1 else 0 END AS VS,
				'',
				0x00, 			      
				0
			FROM   
				(SELECT fn.* ,1 /  CASE WHEN  biCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN biCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
							 ELSE biCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE biCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  buDate  ORDER BY DATE DESC))
			    END Factor  
					from [fn_bubi_FixedCps]( @CustPtr,@AccGuid) fn
					inner join cu000 cu on cu.guid = fn.buCustPtr
				inner join ac000 ac on ac.guid = cu.AccountGUID ) AS [bi]  
				INNER JOIN [#BillTbl2] AS [bt] ON [bt].[Type] = [bi].[buType]        
				INNER JOIN [vwSt] AS [st] ON [st].[stGUID] = [bi].[biStorePtr]  
				INNER JOIN [#MatTbl] AS [mt] ON [mt]. [MatGuid] = [bi].[biMatPtr] 
				INNER JOIN  [#CostTbl] as [co] ON [biCostPtr] = [CO].[Guid] 
			WHERE       
				[buDate] <= @EndDate  
				AND (( @Cash > 2) OR( @Cash = 0 AND [buPayType] >= 2)      
					OR((@Cash = 1) AND ( ISNULL( [buCustPtr], 0x0) = 0x0 OR @AccGuid <> [buCustAcc]))      
					OR( @Cash = 2 AND (@AccGuid= [buCustAcc] OR @AccGuid = [bi].[buMatAcc])))      
				AND (( @Post = 3)OR( @Post = 2 AND [buIsPosted] = 0) OR( @Post = 1 AND [buIsPosted] = 1))      
				AND (( @Contain = '') OR ( [buNotes] LIKE @ContainStr) OR ([biNotes] LIKE @ContainStr))      
				AND (( @NotContain = '') OR (( [buNotes] NOT LIKE @NotContainStr) AND ([biNotes] NOT LIKE @NotContainStr))) 

			DELETE [#Bill]  FROM  [#Bill] b
			 INNER JOIN snc000 snc ON snc.matguid =b. bimatptr
			 INNER JOIN snt000 snt ON (snt.buguid = b.buguid AND snt.parentguid = snc.guid)
			 WHERE b.biqty <> 1 OR b.SNGUID = 0x0
	END
	ELSE
	BEGIN 
		INSERT INTO [#Bill]([buType],[buSecurity],[btSecurity],[buGUID],[buNumber],[buDate],[biNumber],[buNotes],[IsCash],[BillTotal],[FixedBuVAT],
	[FixedbuItemsDisc],[FixedBuBonusDisc],[FixedbuItemExtra],[FixedbuSalesTax],[FixedBuFirstPay],[btReadPriceSecurity],[biMatPtr],[stName],
	[biQty],[biBonusQnt],[biUnity],	[biQty2],[biQty3],[biExpireDate] ,[biProductionDate],[biCostPtr],			
	[biClassPtr],[biLength],[biWidth],[biHeight],[biCount],[FixedBiPrice],[FixedBiDiscount],[FixedbiBonusDisc],[FixedbiExtra],[FixedbiVat],[biVatRatio],[biNotes],				
	[buSalesManPtr]	,[buVendor],[mtSecurity],[FixedCurrencyFactor],[BuTotal],
	[btDirection],[btBillType],[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4],[buFormatedNumber],[buBranch],VS)  
		SELECT       
				[buType],      
				[buSecurity],      
				CASE [bi].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnpostedSecurity] END  AS [btSecurity], 		      
				[buGUID],      
				[buNumber],    
				[buDate],      
				[biNumber],       
				[buNotes],      
				CASE [btType] WHEN  3 THEN 0 WHEN  4 THEN 0 WHEN  2 THEN 0 
				ELSE	CASE      
						WHEN [buCustAcc] = @AccGuid  THEN 0     
						ELSE 1 END    
				END AS [IsCash] ,     
				([BuTotal] + [BuVAT]) * Factor AS [BillTotal],      
				[BuVAT] * Factor [FixedBuVAT],      
				[buItemsDisc]* Factor [FixedbuItemsDisc], 
				[BuBonusDisc]* Factor [FixedBuBonusDisc],  
				[buItemsExtra] * Factor [FixedbuItemExtra],
				buTotalSalesTax * Factor FixedBuSalesTax, 
				CASE [btType] WHEN  2  THEN 0 WHEN  3  THEN 0 WHEN  4  THEN 0 ELSE [BuFirstPay] * Factor END AS [FixedBuFirstPay],            
				[bt].[ReadPriceSecurity] AS [btReadPriceSecurity],      
				[biMatPtr],      
				[St].[stName] AS [stName],    
				[biQty],      
				[biBonusQnt],      
				[biUnity],      
				[biQty2],      
				[biQty3],      
				[biExpireDate],      
				[biProductionDate],      
				[biCost_Ptr] [biCostPtr],      
				[biClassPtr],      
				[biLength],      
				[biWidth],      
				[biHeight],  
				[biCount],     
				[BiPrice] * Factor [BiPrice] ,      
				[BiDiscount]* Factor [FixedBiDiscount],  
				[biBonusDisc]* Factor [FixedbiBonusDisc],    
				[biExtra]* Factor [FixedbiExtra],      
				[biVat]* Factor [FixedbiVat],  
				[biVatRatio],
				[biNotes],      
				[buSalesManPtr],  
				[buVendor],   
				[mtSecurity], 
				Factor [FixedCurrencyFactor], 
				[BuTotal]* Factor [FixedBuTotal], 
				[btDirection], 
				[btType] AS [btBillType], 
				[buTextFld1], 
				[buTextFld2], 
				[buTextFld3], 
				[buTextFld4], 
				CAST ([buNumber] AS [INT]) AS [buFormatedNumber],[buBranch], 
				CASE [btVatSystem] WHEN 2 THEN 1 else 0 END AS VS
				     
			
			FROM   
				(SELECT fn.* ,1 /  CASE WHEN  biCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN biCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
							 ELSE biCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE biCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  buDate  ORDER BY DATE DESC))
			    END Factor  
					from [fn_bubi_FixedCps]( @CustPtr,@AccGuid) fn
					 inner join cu000 cu on cu.guid = fn.buCustPtr
				inner join ac000 ac on ac.guid = cu.AccountGUID ) AS [bi]  
				INNER JOIN [#BillTbl2] AS [bt] ON [bt].[Type] = [bi].[buType]        
				INNER JOIN [vwSt] AS [st] ON [st].[stGUID] = [bi].[biStorePtr]  
				INNER JOIN [#MatTbl] AS [mt] ON [mt]. [MatGuid] = [bi].[biMatPtr] 
				INNER JOIN  [#CostTbl] as [co] ON [biCostPtr] = [CO].[Guid] 
			WHERE       
				[buDate] <= @EndDate  
				AND (( @Cash > 2) OR( @Cash = 0 AND [buPayType] >= 2)      
					OR((@Cash = 1) AND ( ISNULL( [buCustPtr], 0x0) = 0x0 OR @AccGuid <> [buCustAcc]))      
					OR( @Cash = 2 AND (@AccGuid= [buCustAcc] OR @AccGuid = [bi].[buMatAcc])))      
				AND (( @Post = 3)OR( @Post = 2 AND [buIsPosted] = 0) OR( @Post = 1 AND [buIsPosted] = 1))      
				AND (( @Contain = '') OR ( [buNotes] LIKE @ContainStr) OR ([biNotes] LIKE @ContainStr))      
				AND (( @NotContain = '') OR (( [buNotes] NOT LIKE @NotContainStr) AND ([biNotes] NOT LIKE @NotContainStr))) 

	END
	CREATE  CLUSTERED INDEX [BillININDEX] ON [#Bill] ([buGUID])

	CREATE TABLE  [#Disc]([Discount] FLOAT, [ParentGuid] UNIQUEIDENTIFIER, [Extra] FLOAT)
	INSERT INTO [#Disc] SELECT SUM( CASE WHEN [di2].[ContraAccGuid] = @AccGuid OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) THEN [di2].[Discount]/CASE WHEN di2.CurrencyGuid = @CurPtr  THEN di2.[CurrencyVal] ELSE [FixedCurrencyFactor] END ELSE 0 END) AS [Discount],[ParentGuid],SUM(CASE WHEN [di2].[ContraAccGuid] = @AccGuid OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) THEN [di2].[Extra]/CASE WHEN di2.CurrencyGuid = @CurPtr  THEN di2.[CurrencyVal] ELSE [FixedCurrencyFactor] END ELSE 0 END) AS [Extra]  
	FROM [di000] AS [di2] INNER JOIN (SELECT DISTINCT CASE WHEN [FixedCurrencyFactor] > 0 THEN 1/ [FixedCurrencyFactor] ELSE 0 END [FixedCurrencyFactor],[buGuid] FROM  [#Bill]) AS b ON [b].[buGuid] = [di2].[ParentGuid]
	WHERE [di2].[ContraAccGuid] = @AccGuid OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) 
	GROUP BY [ParentGuid],[FixedCurrencyFactor] 

	CREATE  CLUSTERED INDEX [DiscININDEX] ON [#Disc] ([ParentGuid]) 
	IF @serialNumber = 1
		INSERT INTO [#Result]([CustPtr],[CustSecurity],[Type],[Security],[UserSecurity],[Guid],       
			[Number],[Date],[biNumber],[BNotes],[IsCash],[BuTotal],[BuVAT],[BuDiscount],[BuExtra],[BuSalesTax],[BuFirstPay],[UserReadPriceSecurity],[MatPtr],       
			[Store],[Qty],[Bonus],[Unit],[biQty2],[biQty3],[ExpireDate],[ProductionDate],[CostPtr],[ClassPtr],[Length],[Width],[Height],[Count],[BiPrice],[BiDiscount],[BiExtra],/*[biVat],*/        
			[Notes],[Balance],[SalesMan],[Vendor],[MatSecurity],[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4],[Flag],[FormatedNumber],[Branch],[biBonusDisc],[BiVAT],SN,SNGuid, SNItem)
		SELECT  
			@CustPtr,  
			@CustSec,   
			[buType],   
			[buSecurity],   
			[btSecurity], 		   
			[buGUID],   
			[buNumber],     
			[buDate],   
			[biNumber],    
			[buNotes],       
			[IsCash],      
			[BillTotal],       
			[FixedBuVAT],       
			([FixedbuItemsDisc] + [FixedBuBonusDisc] + ISNULL([Discount],0)) ,       
			([FixedbuItemExtra] + ISNULL([Extra],0)),--FixedBuTotalExtra,      
			[FixedbuSalesTax], 
			[FixedBuFirstPay],       
			[btReadPriceSecurity],       
			[biMatPtr],       
			[stName],     
			[biQty],       
			[biBonusQnt],       
			[biUnity],       
			[biQty2],       
			[biQty3],       
			[biExpireDate],       
			[biProductionDate],       
			[biCostPtr],       
			[biClassPtr],       
			[biLength],       
			[biWidth],       
			[biHeight],  
			[biCount],       
			[FixedBiPrice],
			[FixedBiDiscount],       
			[FixedbiExtra],       
			-- [FixedbiVAT],
			[biNotes],       
			ISNULL((([BillTotal]/* [FixedBuTotal] + [FixedBuVAT]*/ - [FixedbuFirstPay] - ([FixedbuItemsDisc]+ [FixedBuBonusDisc]+ISNULL([Discount],0))  + [FixedbuItemExtra] + ISNULL([Extra],0) + [FixedbuSalesTax])* (-[btDirection])), 0),   
			[buSalesManPtr],   
			[buVendor],    
			[mtSecurity],  
			[buTextFld1],  
			[buTextFld2],  
			[buTextFld3],  
			[buTextFld4],   
			2, -- Flag  
			[buFormatedNumber],[buBranch],[FixedbiBonusDisc],[FixedBiVAT],
			SN,
			SNGuid, 
			SNItem   
		FROM    
			[#Bill] AS [b]  LEFT JOIN [#Disc] AS [d] ON [d].[ParentGuid] = [b].[buGUID] 
	ELSE
		INSERT INTO [#Result]([CustPtr],[CustSecurity],[Type],[Security],[UserSecurity],[Guid],      
			[Number],[Date],[biNumber],[BNotes],[IsCash],[BuTotal],[BuVAT],[BuDiscount],[BuExtra],[BuSalesTax],[BuFirstPay],[UserReadPriceSecurity],[MatPtr],      
			[Store],[Qty],[Bonus],[Unit],[biQty2],[biQty3],[ExpireDate],[ProductionDate],[CostPtr],[ClassPtr],[Length],[Width],[Height],[Count],[BiPrice],[BiDiscount],[BiExtra],      
			[Notes],[Balance],[SalesMan],[Vendor],[MatSecurity],[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4],[Flag],[FormatedNumber],[Branch],[biBonusDisc],[BiVAT])     
		SELECT 
			@CustPtr, 
			@CustSec,  
			[buType],  
			[buSecurity],  
			[btSecurity], 		  
			[buGUID],  
			[buNumber],    
			[buDate],  
			[biNumber],   
			[buNotes],      
			[IsCash],     
			[BillTotal],      
			[FixedBuVAT],      
			([FixedbuItemsDisc] + [FixedBuBonusDisc] + ISNULL([Discount],0)) ,      
			([FixedbuItemExtra] + ISNULL([Extra],0)),--FixedBuTotalExtra,  
			[FixedbuSalesTax],    
			[FixedBuFirstPay],      
			[btReadPriceSecurity],      
			[biMatPtr],      
			[stName],    
			[biQty],      
			[biBonusQnt],      
			[biUnity],      
			[biQty2],      
			[biQty3],      
			[biExpireDate],      
			[biProductionDate],      
			[biCostPtr],      
			[biClassPtr],      
			[biLength],      
			[biWidth],      
			[biHeight], 
			[biCount],      
			[FixedBiPrice],    
			[FixedBiDiscount],      
			[FixedbiExtra],      
			 
			[biNotes],      
			ISNULL((([BillTotal]/* [FixedBuTotal] + [FixedBuVAT]*/ - [FixedbuFirstPay] - ([FixedbuItemsDisc]+ [FixedBuBonusDisc]+ISNULL([Discount],0))  + [FixedbuItemExtra] + ISNULL([Extra],0) + [FixedbuSalesTax])* (-[btDirection])), 0),  
			[buSalesManPtr],  
			[buVendor],   
			[mtSecurity], 
			[buTextFld1], 
			[buTextFld2], 
			[buTextFld3], 
			[buTextFld4],  
			2, -- Flag 
			[buFormatedNumber],[buBranch],[FixedbiBonusDisc],[FixedBiVAT] 
			  
		FROM   
			[#Bill] AS [b]  LEFT JOIN [#Disc] AS [d] ON [d].[ParentGuid] = [b].[buGUID] 

	-- Details of DisCounts and Extras 

	IF (@ShowDiscExtDet <> 0) 
	BEGIN 
		CREATE TABLE [#DetDiscExt](
			[buType]			UNIQUEIDENTIFIER,  
			[buSecurity]		INT, 
			[btSecurity]		INT, 		  
			[BillGUID]			UNIQUEIDENTIFIER,  
			[buNumber]			INT,    
			[buDate]			DATETIME, 
			[buNotes]			NVARCHAR(1000), 
			[Discount]			FLOAT, 
			[Extra]				FLOAT, 
			[acCodeName]		NVARCHAR(256), 
			[acGuid]			UNIQUEIDENTIFIER, 
			[acSecurity]		INT)

		INSERT INTO #DetDiscExt
		SELECT 
			[buType],  
			[buSecurity], 
			[btSecurity], 		  
			[buGUID] [BillGUID],  
			[buNumber],    
			[buDate], 
			[di2].[Notes] AS [buNotes], 
			[di2].[Discount]*[FixedCurrencyFactor] AS [Discount] , 
			[di2].[Extra]*[FixedCurrencyFactor] AS [Extra], 
			[ac].[acCode] + '-' +[ac].[acName] AS [acCodeName], 
			[ac].[acGuid], 
			[ac].[acSecurity] 
			FROM ([di000] AS [di2]  
			INNER JOIN (SELECT DISTINCT [buType],[buSecurity],[btSecurity],[buNumber],[buDate],[FixedCurrencyFactor],[buGuid] FROM  [#Bill]) AS b ON [b].[buGuid] = [di2].[ParentGuid]) 
			INNER JOIN [vwAc] AS [ac] ON [ac].[acGuid] = [di2].[AccountGuid] 
			WHERE [di2].[ContraAccGuid] = @AccGuid OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) 

		EXEC [prcCheckSecurity]  @result = '#DetDiscExt' 

		INSERT INTO #RESULT ([CustPtr],[CustSecurity],[MatPtr],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number],[Date],[BNotes],[EntryDebit],[EntryCredit],[OppAccName],[Flag]) 
		SELECT 
			@CustPtr, 
			@CustSec, 
			[acGuid],  
			1, 
			[buType],  
			[buSecurity], 
			[btSecurity], 		  
			[BillGUID],  
			[buNumber],    
			[buDate], 
			[buNotes], 
			[Discount], 
			[Extra], 
			[acCodeName], 
			2 
		FROM #DetDiscExt 
			 
	END 

	-- 	INSERT ENTRY MOVE 
	CREATE TABLE [#ENTRY](       
			[ceTypeGuid]	UNIQUEIDENTIFIER,    
			[ceSecurity]	INT,       
			[Security]		INT,      
			[ceGuid]		UNIQUEIDENTIFIER,    
			[ceNumber]		INT, 
			[enGuid]		UNIQUEIDENTIFIER,    
			[enDate]		DATETIME,       
			[enNumber]		INT,       
			[ceNotes]		NVARCHAR(1000),       
			[FixedEnDebit]	FLOAT,       
			[FixedEnCredit]	FLOAT,       
			[enNotes]		NVARCHAR(1000),       
			[Balance]		FLOAT,      
			[enContraacc]	UNIQUEIDENTIFIER, 
			[FFLAG]			INT,   
			[erParentType]	INT, 
			[Flag]			INT, 
			[erParentGuid]	UNIQUEIDENTIFIER, 
			[enAccount]		UNIQUEIDENTIFIER, 
			[enCostPoint]	UNIQUEIDENTIFIER,
			[ceBranch]		UNIQUEIDENTIFIER)
	
	INSERT INTO [#ENTRY]
	SELECT      
			[f].[ceTypeGuid],    
			[f].[ceSecurity],       
			[t].[Security],      
			CASE [t].[Flag] WHEN 1 THEN [er].[ParentGuid] ELSE  [f].[ceGuid] END  [ceGuid],    
			[f].[ceNumber], 
			[enGuid],    
			[f].[enDate],       
			[f].[enNumber],       
			[f].[enNotes],       
			[f].enDebit * Factor [FixedEnDebit] ,       
			[f].[EnCredit] * Factor [FixedEnCredit],       
			[f].[enNotes] ,       
			ISNULL(([f].enDebit - [f].[EnCredit]), 0) * Factor AS [Balance],      
			[enContraacc], 
			CASE [t].[Flag] WHEN 1 THEN 4 WHEN 2 THEN CASE [er].[ParentType] WHEN 5 THEN 1 ELSE [er].[ParentType] END  ELSE 1 END AS [FFLAG],   
			[er].[ParentType] AS [erParentType], 
			[t].[Flag], 
			ISNULL([er].[ParentGuid], 0X00) AS [erParentGuid], 
			[f].[enAccount], 
			[f].[enCostPoint],[ceBranch] 
		FROM       
			(SELECT *,1 /CASE WHEN  enCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN enCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  enDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  enDate  ORDER BY DATE DESC) 
							 ELSE enCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE enCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  enDate  ORDER BY DATE DESC))
			    END Factor    
				  FROM vwCeEn fn inner join ac000 ac on ac.guid = fn.enAccount)  AS [f] 
			LEFT JOIN [Er000] AS [er]      
			ON [f].[ceGuid] = [er].[EntryGuid]      
			INNER JOIN [#EntrySource] AS [t]      
			ON [f].[ceTypeGuid] = [t].[Type] --AND [t].Flag <> 3
		
		  
			    
		WHERE      
			[f].[enDate] <= @EndDate  
			
			AND ([f].[enAccount] =  @AccGuid)        
			AND (( @Contain = '') OR ([f].[enNotes] LIKE @ContainStr) OR ([f].[ceNotes] LIKE @ContainStr)  )      
			AND (( @NotContain = '') OR (( [f].[enNotes] NOT LIKE @NotContainStr) AND ( [f].[ceNotes] NOT LIKE @NotContainStr)))  
			AND ([f].[enCustomerGUID] = isnull(@CustPtr, 0x0 ))
			
	 CREATE  INDEX [enININDEX] ON [#ENTRY] ([enCostPoint],[erParentGuid]) 
	 INSERT INTO [#Result] ([CustPtr],[CustSecurity],[Type],[Security],[UserSecurity],[Guid],[Number],[Date],[biNumber], [BNotes],[UserReadPriceSecurity],[CostPtr],[ClassPtr],[EntryDebit],[EntryCredit],[Notes],[Balance],[ContraAcc],[Flag],[Branch],[enGuid])          
		SELECT      
			@CustPtr, 
			@CustSec,      
			[ceTypeGuid],    
			[ceSecurity],       
			[#ENTRY].[Security],      
			[ceGuid],    
			[ceNumber],    
			CASE WHEN erparenttype = 13 THEN chdate ELSE [enDate] END AS enDate,
			[enNumber],       
			[ceNotes],       
			3,--	UserReadPriceSecurity      
			 
			[enCostPoint],--	CostPtr,       
			'',--	ClassPtr,       
			[FixedEnDebit],  -- EntryDebit       
			[FixedEnCredit], -- EntryCredit,       
			[enNotes] ,       
			[Balance],      
			[enContraacc], 
			CASE WHEN erparenttype = 6 THEN 1 ELSE [FFlag] END,
			[ceBranch],[enGuid] 
		FROM 
			[#ENTRY] 
			INNER JOIN  [#CostTbl] AS [co] ON [enCostPoint] = [co].[Guid] 
			LEFT JOIN [vwBu] AS [bu] ON [erParentGuid] = [bu].[buGuid]  
			LEFT JOIN (select chGuid,chAccount,chDir,chdate from vwch) ch ON [erParentGuid] =  ch.chGuid   
		WHERE      
			 (([Flag] = 1) OR ([Flag] = 4) OR ([Flag] = 9) OR (([Flag] = 2) AND ([erParentType] IN (6, 7, 8, 12, 13,250,251,252,253,254,255,256,257,258,259,260,261,262))) OR ([Flag] = 3 AND [enAccount] <> [bu].[buCustAcc] AND ([bu].[buMatAcc] <>[enAccount] or ( [bu].[buMatAcc] =[enAccount] and btType <> 3 and  btType  <>  3))) )     
			OR ([Flag] = 2 AND [erParentType] = 5 AND ((chDir = 1 and [FixedEnDebit] > 0  ) or (chDir = 2 and [FixedEnCredit] > 0  ))) 
			OR ([Flag] = 3 and [erParentType] = 600) 
	-- 	INSERT Normal Entry Move    
	 
	 -- IF (@ShowOppAcc = 1) 
		UPDATE [res] SET [OppAccName]  = [acName],	[OppAccCode] = [acCode]  
		 FROM [#Result] AS [res] INNER JOIN [vwAc] ON [res].[ContraAcc] = [ACgUID]   
--------------------------------------------------------------------------- 
---------------------------------------------------------------------------     
	IF( @UseChkDueDate = 0)      
		INSERT INTO      
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date],[BNotes],[EntryDebit],[EntryCredit],[Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])     
			SELECT      
				@CustPtr,     
				@CustSec,     
				0,     
				[ch].[chType],     
				[ch].[chSecurity],     
				[nt].[Security],     
				[ch].[chGuid],     
				[ch].[chNumber],     
				[ch].[chDate],   
				[ch].[chNotes],     
				(Case      
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal]* Factor   
					ELSE 0      
					END), -- EntryDebit     
				(Case      
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal]* Factor   
					ELSE 0      
					END), -- EntryCredit     
				(Case      
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal] * Factor 
					ELSE -[ch].[chVal]* Factor 
					END), -- Balance     
				CASE ch.IsTransfered
					WHEN 0 THEN 5
					ELSE 6
				END,
				[chbranchGuid],[chCost1GUID],chnum,
				[ch].[chState],
				[ch].[chDir]        
			FROM      
			(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor   
				 FROM [#vwCh] ch INNER JOIN ac000 ac on ac.Guid = ch.chAccount) AS [ch] INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type] 
				 INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]          
			WHERE      
				[chAccount] = @AccGuid  
				AND [chCustomerGUID] = @CustPtr   
				AND (( @Contain = '') OR ([chNotes] LIKE @ContainStr))     
				AND (( @NotContain = '') OR ([chNotes] NOT LIKE @NotContainStr))     
				AND [chDate] <= @EndDate      
				AND 
				(
					(
						(ch.IsTransfered = 0)
						AND
						(
						[chState] IN (1, 3, 5, 6, 8, 9, 12, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
					OR 
					(
						(ch.IsTransfered = 1)
						AND
						(
						[chState] IN (0, 6, 8, 9, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
				)
				   
	ELSE IF( @UseChkDueDate = 1)       
		INSERT INTO      
				[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date],[BNotes],[EntryDebit],[EntryCredit],[Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])     
			SELECT      
				@CustPtr,     
				@CustSec,     
				0,     
				[ch].[chType],     
				[ch].[chSecurity],     
				[nt].[Security],     
				[ch].[chGuid],     
				[ch].[chNumber],     
				[ch].[chDate],     
				[ch].[chNotes],     
				(Case      
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal]* Factor     
					ELSE 0      
					END), -- EntryDebit     
				(Case      
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal]* Factor   
					ELSE 0      
					END), -- EntryCredit     
				(Case      
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal]* Factor     
					ELSE -[ch].[chVal]* Factor 
					END), -- Balance     
				CASE ch.IsTransfered
					WHEN 0 THEN 5
					ELSE 6
				END,
				[chbranchGuid],[chCost1GUID],chnum,
				[ch].[chState],
				[ch].[chDir]        
			FROM      
			(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor   
				FROM [#vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount) AS [ch] 
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type] 
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]          
			WHERE      
				chAccount= @AccGuid
				AND [chCustomerGUID] = @CustPtr      
				AND (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))     
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))     
				AND [chDueDate] <= @EndDate      
				AND 
				(
					(
						(ch.IsTransfered = 0)
						AND
						(
						[chState] IN (1, 3, 5, 6, 8, 9, 12, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
					OR 
					(
						(ch.IsTransfered = 1)
						AND
						(
						[chState] IN (0, 6, 8, 9, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
				)
	ELSE       
		INSERT INTO      
				[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date],[BNotes],[EntryDebit],[EntryCredit],[Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])     
			SELECT      
				@CustPtr,     
				@CustSec,     
				0,     
				[ch].[chType],     
				[ch].[chSecurity],     
				[nt].[Security],     
				[ch].[chGuid],     
				[ch].[chNumber],     
				[ch].[chDate],      
				[ch].[chNotes],     
				(Case      
					WHEN [ch].[chDir] = 2 THEN[ch].[chVal]  * Factor      
					ELSE 0      
					END), -- EntryDebit     
				(Case      
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal] * Factor       
					ELSE 0      
					END), -- EntryCredit     
				(Case      
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal]* Factor      
					ELSE -[ch].[chVal] * Factor    
					END), -- Balance     
				CASE ch.IsTransfered
					WHEN 0 THEN 5
					ELSE 6
				END,
				[chbranchGuid],[chCost1GUID],chnum,
				[ch].[chState],
				[ch].[chDir]      
			FROM      
			
				(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor   
				FROM [#vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount
				) AS [ch] 
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type] 
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]          
			WHERE      
				[chAccount] = @AccGuid 
				AND [chCustomerGUID] = @CustPtr     
				AND (( @Contain = '') OR ([chNotes] LIKE @ContainStr))     
				AND (( @NotContain = '') OR ([chNotes] NOT LIKE @NotContainStr))     
				AND [chColDate] <= @EndDate      
				AND 
				(	
					(
						(ch.IsTransfered = 0)
						AND
						(
						[chState] IN (1, 3, 5, 6, 8, 9, 12, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
					OR 
					(
						(ch.IsTransfered = 1)
						AND
						(
						[chState] IN (0, 6, 8, 9, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
				)
	--Calc partly collected cheques.
	INSERT INTO        
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])         
			SELECT        
				@CustPtr,    
				@CustSec,    
				0,       
				[ch].[chType],       
				[ch].[chSecurity],       
				[nt].[Security],       
				[ch].[chGUID],       
				[ch].[chNumber],     
				[ch].[chDate],         
				[ch].[chNotes],
				
				(Case       
					WHEN [ch].[chDir] = 2 THEN 
						CASE ch.chTransferCheck 
							when 0 then case when (@ShowChk = 0 OR @IsShowChequeDetailsPartly = 1) then [chr].[SumParts]  else [chr].[SumParts] + [chr].[RemAmount] END 
							else [chr].[RemAmount]
						end * Factor    
					ELSE 0        
					END), -- EntryDebit       
				(Case        
					WHEN [ch].[chDir] = 1 THEN 
						CASE ch.chTransferCheck 
							when 0 then case when (@ShowChk = 0 OR @IsShowChequeDetailsPartly = 1) then [chr].[SumParts]  else [chr].[SumParts] + [chr].[RemAmount] END 
							else [chr].[RemAmount]
						end * Factor    
					ELSE 0        
					END), -- EntryCredit       
			
				(Case        
					WHEN [ch].[chDir] = 2 THEN 
						CASE ch.chTransferCheck 
							when 0 then case when (@ShowChk = 0 OR @IsShowChequeDetailsPartly = 1) then [chr].[SumParts]  else [chr].[SumParts] + [chr].[RemAmount] END 
							else [chr].[RemAmount]
						END * [Factor]
					ELSE 
						CASE ch.chTransferCheck 
							when 0 then -case when (@ShowChk = 0 OR @IsShowChequeDetailsPartly = 1) then [chr].[SumParts]  else [chr].[SumParts] + [chr].[RemAmount] END
							else -[chr].[RemAmount]
						END * [Factor]
					END), -- Balance     
				CASE ch.chTransferCheck
					WHEN 0 THEN 5
					ELSE 6
				END,
				chbranchGuid,[chCost1GUID] ,[chnum],
				CASE WHEN @IsShowChequeDetailsPartly = 1 then [ch].[chState] ELSE -2 END,
				[ch].[chDir]      
			FROM        
				(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor   
				FROM [vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount
				) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
				-- INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]  
				INNER JOIN [#ChequePartAmount]  AS [chr] ON [chr].[chGuid] = [ch].[chGuid]
			WHERE
				([chAccount] = @AccGuid)
				AND 
				(CASE @UseChkDueDate WHEN 1 THEN [chDueDate] ELSE [chDate] END <= @EndDate)       
				AND (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))       
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))   
	   
----------------------------------------------------------------------------------- 
-----------------------------------------------------------------------------------     
	IF( @ShowChk > 0)      
BEGIN	
		INSERT INTO      
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])         
			SELECT      
				@CustPtr,    
				@CustSec,    
				0,     
				[ch].[chType],     
				[ch].[chSecurity],     
				[nt].[Security],     
				[ch].[chGUID],       
				[ch].[chNumber],     
				[ch].[chDate],    
				[ch].[chNotes],     
				(Case      
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] *  Factor    
					ELSE 0      
					END), -- EntryDebit     
				(Case      
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal] * Factor       
					ELSE 0      
					END), -- EntryCredit     
			
				(Case      
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * [Factor]      
					ELSE -[ch].[chVal] * Factor 
					END), -- Balance     
				-1,chbranchGuid,[chCost1GUID] ,[chnum],
				[ch].[chState],
				[ch].[chDir]      
			FROM        
				(SELECT *,1 /CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor   
				FROM [#vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount
				) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
				-- INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]   
			WHERE        
				([chAccount] = @AccGuid) 
				AND [chCustomerGUID] = @CustPtr
				AND
				(CASE @UseChkDueDate WHEN 1 THEN [chDueDate] ELSE [chDate] END <= @EndDate)       
				AND (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))       
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))   
				AND 
				(
					([ch].[chState] in (0, 7, 10,  14) ) 
					OR ([chState] = (CASE @IsEndorsedRecieved WHEN   0  THEN  4   END))
					OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 0 THEN 11   END))
				)
				AND (ch.IsTransfered = 0)								
			--Calc partly
			IF @IsShowChequeDetailsPartly = 1	
			INSERT INTO        
				[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])         
			SELECT        
				@CustPtr,    
				@CustSec,    
					0,       
					[ch].[chType],       
					[ch].[chSecurity],       
					[nt].[Security],       
					[ch].[chGUID],       
					[ch].[chNumber],     
					[ch].[chDate],         
					[ch].[chNotes],
				
					(Case       
						WHEN [ch].[chDir] = 2 THEN [chr].[RemAmount] *  Factor     
						ELSE 0        
						END), -- EntryDebit       
					(Case        
						WHEN [ch].[chDir] = 1 THEN [chr].[RemAmount] *  Factor       
						ELSE 0        
						END), -- EntryCredit       
			
					(Case        
						WHEN [ch].[chDir] = 2 THEN [chr].[RemAmount] *  Factor     
						ELSE -[chr].[RemAmount] *  Factor   
						END), -- Balance     
					CASE @IsShowChequeDetailsPartly when 0 THEN -2 ELSE -1 END,chbranchGuid,[chCost1GUID] ,[chnum],
					[ch].[chState],
					[ch].[chDir]      
			FROM      
				(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor   
				FROM [vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount
				) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
				-- INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  
				 INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]          
				INNER JOIN [#ChequePartAmount] AS [chr] ON [chr].[chGuid] = [ch].[chGuid]
			WHERE      
				([chAccount] = @AccGuid)
				AND 
				(CASE @UseChkDueDate WHEN 1 THEN [chDueDate] ELSE [chDate] END <= @EndDate)       
				AND (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))       
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))   
				AND chTransferCheck = 0

		IF (@IsNotShowUnDelivered = 1)
			DELETE [#Result] WHERE [Guid] IN (SELECT ChGuid FROM [vwCh] WHERE [chState] =14)  
END
				 
---------------------------------------------------------------------- 
--Delete  Check With No Edit Entry 
	IF (@ShwChWithEn =1) 
		DELETE [#Result] WHERE  ( [Flag] = 5) AND [Guid] NOT IN (SELECT [ParentGuid] FROM [er000] WHERE [ParentType] = 5)	     
----------------------------------------------------------------------      
	EXEC [prcCheckSecurity]      
	     
	DECLARE @PriveBalance [FLOAT]      
   
	IF @StartBal=0     
		SELECT @PriveBalance = ISNULL( SUM([Balance]), 0) FROM      
				(SELECT DISTINCT [Type], [Guid], [Balance], [flag], '' AS [Notes] FROM [#Result] WHERE [Date] < @StartDate AND [OrderFlag] = 0 AND [IsCash] = 0 AND [FLAG] =2  
			UNION ALL 
			SELECT  [Type], [Guid], [Balance], [flag], [Notes] FROM [#Result] WHERE [Date] < @StartDate AND [OrderFlag] = 0 AND [IsCash] = 0 AND [FLAG] <> 2 AND [Flag] <> 6) AS [p]     
	ELSE  
		SET @PriveBalance=0  
	    
	DELETE [#Result] WHERE [Date] < @StartDate AND [Flag] <> 6 
	 
	IF (@StartBal=0) 
		SET @StDate = '1/1/1980' 
	ELSE 
		SET @StDate = @StartDate 
	DECLARE @RBalance AS [FLOAT] 
	IF @bUnmatched = 1
	BEGIN 
		DECLARE @CurrencyGUID UNIQUEIDENTIFIER 
		SET @CurrencyGUID = @CurPtr
		IF @DetailingByCurrencyAccount <> 0
			SELECT @CurrencyGUID = ISNULL(CurrencyGUID, @CurPtr) FROM ac000 WHERE GUID = @AccGuid

		SET @RBalance = [dbo].[fnAccCust_getBalance](@AccGuid,@CurrencyGUID,@StDate,@EndDate,@CostGuid,@CustPtr) 
	END 
	ELSE 
		SET @RBalance = 0 
			    
	IF (((@ShowAccMoved=1) AND EXISTS(SELECT * FROM #RESULT)) OR (@ShowAccmoved=0))  
		INSERT INTO [#Result]([CustPtr], [Date],[BuTotal],[Balance],[Flag]) VALUES ( @CustPtr, @StartDate - 1, @PriveBalance,@RBalance, 0)   
###############################################################################
###“»Ê‰ ÊÕÌœ »œÊ‰  ›«’Ì· 
CREATE PROCEDURE repCPS_WithoutDetails_OneCust
	@UserId			AS [UNIQUEIDENTIFIER], 
	@StartDate		AS [DATETIME], 
	@EndDate		AS [DATETIME], 
	@CustPtr		AS [UNIQUEIDENTIFIER], 
	@CustSec		AS [INT], 
	@CurPtr			AS [UNIQUEIDENTIFIER], 
	@CurVal			AS [FLOAT], 
	@Post			AS [INT],	-- 1: xxx, 2: yyy, 3: zzz 
	@Cash			AS [INT],	-- 0: a, 1: b, 2: c, c: d 
	@Contain		AS [NVARCHAR](1000), 
	@NotContain		AS [NVARCHAR](1000), 
	@UseChkDueDate	AS [INT], 
	@ShowChk		AS [INT],
	@CostGuid		AS [UNIQUEIDENTIFIER],
	@ShowAccMoved   AS [INT] = 0,
	@StartBal		AS [INT] = 0,
	@bUnmatched		AS [INT] =1,
	@ShwChWithEn	AS [INT] = 0,
	@ShowDiscExtDet AS [INT] = 0,
	--@ShowOppAcc		AS [INT] = 0,
	-- @Flag		BIGINT = 0,
	@IsEndorsedRecieved AS BIT = 0, 
	@IsDiscountedRecieved AS BIT = 0,
	@IsNotShowUnDelivered AS BIT = 0,
	@IsShowChequeDetailsPartly BIT = 0
	,@DetailingByCurrencyAccount  AS [BIT] = 0,
	@AccGuid AS [UNIQUEIDENTIFIER] = 0x0
AS    
	SET NOCOUNT ON
	
	DECLARE	     
		--@UserId			[INT],      
		@ContainStr		[NVARCHAR](1000),     
		@NotContainStr	[NVARCHAR](1000),    
		@StDate  [DATETIME]
	-- prepare Parameters:	    
	SET @ContainStr = '%' + @Contain + '%'    
	SET @NotContainStr = '%' + @NotContain + '%' 
	
	DECLARE @Curr TABLE( DATE SMALLDATETIME,VAL FLOAT, CurrGuid UNIQUEIDENTIFIER)
	INSERT INTO @Curr 
		SELECT DATE,CurrencyVal, CURRENCYGuid FROM mh000 WHERE DATE <= @EndDate 
	UNION ALL 
		SELECT  '1/1/1980',CurrencyVal, Guid FROM MY000        
	    
	-- get CustAcc	    
	--SELECT @AccGuid = [AccountGUID] FROM [cu000] WHERE [GUID] = @CustPtr    
	-- 	INSERT BILLS MOVE 
	CREATE TABLE [#Bill](
		[buType]				UNIQUEIDENTIFIER,     
		[buSecurity]			INT,     
		[btSecurity]			INT, 		     
		[buGUID]				UNIQUEIDENTIFIER,     
		[buNumber]				INT,   
		[buDate]				DATETIME,     
		[biNumber]				INT,      
		[buNotes]				NVARCHAR(1000),     
		[IsCash]				BIT,    
		[BillTotal]				FLOAT,     
		[FixedBuVAT]			FLOAT,     
		[FixedbuItemsDisc]		FLOAT,
		[FixedBuBonusDisc]		FLOAT, 
		[FixedbuItemsExtra]		FLOAT,
		[FixedBuSalesTax]		FLOAT,
		[FixedBuFirstPay]		FLOAT,     
		[btReadPriceSecurity]	INT,     
		[buSalesManPtr]			FLOAT, 
		[buVendor]				FLOAT,  
		[FixedCurrencyFactor]	FLOAT,
		[FixedBuTotal]			FLOAT,
		[btDirection]			INT,
		[btType]				INT,
		[buMatAcc]				UNIQUEIDENTIFIER,
		[DIR]					INT,
		[buTextFld1]			NVARCHAR(100),
		[buTextFld2]			NVARCHAR(100),
		[buTextFld3]			NVARCHAR(100),
		[buTextFld4]			NVARCHAR(100),
		[buFormatedNumber]		INT,
		[buBranch]				UNIQUEIDENTIFIER,
		[biCostPtr]				UNIQUEIDENTIFIER,
		VS						BIT)

	INSERT INTO [#Bill]
	SELECT DISTINCT
		[buType],     
		[buSecurity],     
		CASE [bi].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnpostedSecurity] END  AS [btSecurity], 		     
		[buGUID],     
		[buNumber],   
		[buDate],     
		[biNumber],      
		[buNotes],     
		CASE [btType] WHEN  3 THEN 0 WHEN  4 THEN 0 WHEN  2 THEN 0
		ELSE	CASE     
				WHEN [buCustAcc] = @AccGuid  THEN 0     
				ELSE 1 END   
		END AS [IsCash] ,    
		([BuTotal] + [BuVAT]) * Factor AS [BillTotal],     
		[BuVAT]* Factor [FixedBuVAT],     
		[buItemsDisc]* Factor  [FixedbuItemsDisc],
		[BuBonusDisc]* Factor  [FixedBuBonusDisc], 
		[buItemsExtra]* Factor [FixedbuItemsExtra],
		buTotalSalesTax * Factor FixedBuSalesTax,
		CASE [btType] WHEN  2  THEN 0 WHEN  3  THEN 0 WHEN  4  THEN 0 WHEN  2  THEN 0 ELSE [BuFirstPay] * Factor END AS [FixedBuFirstPay],     
		[bt].[ReadPriceSecurity] AS [btReadPriceSecurity],     
		[buSalesManPtr], 
		[buVendor],  
		Factor [FixedCurrencyFactor],
		[BuTotal]* Factor [FixedBuTotal],
		[btDirection],
		[btType],
		[bi].[buMatAcc],
		-1 AS [DIR],
		[buTextFld1],
		[buTextFld2],
		[buTextFld3],
		[buTextFld4],
		CAST ([buNumber] AS [INT]) AS [buFormatedNumber],[buBranch] ,[biCostPtr],
		CASE [btVatSystem] WHEN 2 THEN 1 else 0 END AS VS 
	FROM  
		(SELECT fn.* ,1 / CASE WHEN  biCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN biCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
							 ELSE biCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE biCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  buDate  ORDER BY DATE DESC))
			    END Factor   
		 from [fn_bubi_FixedCps]( @CustPtr,@AccGuid) fn
		 inner join cu000 cu on cu.guid = fn.buCustPtr
		inner join ac000 ac on ac.guid = cu.AccountGUID) AS [bi] 
		INNER JOIN [#BillTbl2] AS [bt] ON [bt].[Type] = [bi].[buType]     
		INNER JOIN  [#CostTbl] as [co] ON [biCostPtr] = [CO].[Guid]
	WHERE      
		[buDate] <= @EndDate 
	--	AND ( @CustPtr= [bi].[buCustPtr]  OR (@AccGuid = [bi].[buMatAcc] and ([btType] = 3 or [btType] = 4) ))    
		AND (( @Cash > 2) OR( @Cash = 0 AND [buPayType] >= 2)     
			OR((@Cash = 1) AND ( ISNULL( [buCustPtr], 0x0) = 0x0 OR @CustPtr <> [buCustAcc]))     
			OR( @Cash = 2 AND (@AccGuid = [buCustAcc] OR @AccGuid = [bi].[buMatAcc])))     
		AND (( @Post = 3)OR( @Post = 2 AND [buIsPosted] = 0) OR( @Post = 1 AND [buIsPosted] = 1))     
		AND (( @Contain = '') OR ( [buNotes] LIKE @ContainStr) )     
		AND (( @NotContain = '') OR (( [buNotes] NOT LIKE @NotContainStr) )) 
	
	CREATE TABLE [#Disc]([Discount] FLOAT, [ParentGuid] UNIQUEIDENTIFIER, [Extra] FLOAT)
	INSERT INTO [#Disc] SELECT  SUM( CASE WHEN [di2].[ContraAccGuid] = @AccGuid OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) THEN [di2].[Discount]/CASE WHEN di2.CurrencyGuid = @CurPtr  THEN di2.[CurrencyVal] ELSE [FixedCurrencyFactor] END ELSE 0 END) AS [Discount],[ParentGuid],SUM(CASE WHEN [di2].[ContraAccGuid] = @AccGuid OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) THEN [di2].[Extra]/CASE WHEN di2.CurrencyGuid = @CurPtr  THEN di2.[CurrencyVal] ELSE [FixedCurrencyFactor] END ELSE 0 END) AS [Extra]
	FROM [di000] AS [di2] INNER JOIN (SELECT DISTINCT CASE WHEN [FixedCurrencyFactor] > 0 THEN 1/ [FixedCurrencyFactor] ELSE 0 END [FixedCurrencyFactor],[buGuid] FROM  [#Bill]) AS b ON [b].[buGuid] = [di2].[ParentGuid]
	WHERE [di2].[ContraAccGuid] = @AccGuid OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0)
	GROUP BY [ParentGuid],[FixedCurrencyFactor]
	
	INSERT INTO [#Result]([CustPtr],[CustSecurity],[Type],[Security],[UserSecurity],[Guid],     
		[Number],[Date],[BNotes],[IsCash],[BuTotal],[BuVAT],[BuDiscount],[BuExtra],[BuSalesTax],[BuFirstPay],[UserReadPriceSecurity],     
		[Notes],[Balance],[SalesMan],[Vendor],[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4],[Flag],[FormatedNumber],[Branch],[CostPtr])
		SELECT DISTINCT 
			@CustPtr,    
			@CustSec,      
			[buType],     
			[buSecurity],     
			[btSecurity], 		     
			[buGUID],     
			[buNumber],     
			[buDate],     
			[buNotes],     
			[IsCash],     
			[BillTotal],     
			[FixedBuVAT],     
			([FixedbuItemsDisc] + [FixedBuBonusDisc] + ISNULL([Discount],0)),     
			[FixedbuItemsExtra] + ISNULL([Extra],0),--FixedBuTotalExtra, 
			[FixedbuSalesTax],
			[FixedBuFirstPay] ,     
			[btReadPriceSecurity],      
			'',     
			ISNULL((( [BillTotal]/*[FixedBuTotal] + [FixedBuVAT]*/ - [FixedbuFirstPay] - ([FixedbuItemsDisc]+ [FixedBuBonusDisc] +ISNULL([Discount],0))  + [FixedbuItemsExtra] + ISNULL([Extra],0) + FixedBuSalesTax)* [DIR]*[btDirection] ), 0), 
			[buSalesManPtr],  
			[buVendor],
			[buTextFld1],
			[buTextFld2],
			[buTextFld3],
			[buTextFld4],  
			2, -- Flag
			[buFormatedNumber],[buBranch],[biCostPtr]      
		FROM  
			[#Bill] AS [b]  LEFT JOIN [#Disc] AS [d] ON [d].[ParentGuid] = [b].[buGUID]

	-- 	INSERT ENTRY MOVE 
	CREATE TABLE [#ENTRY](     
			[ceTypeGuid]	UNIQUEIDENTIFIER,   
			[ceSecurity]	INT,      
			[Security]		INT,     
			[ceGuid]		UNIQUEIDENTIFIER,   
			[ceNumber]		INT,
			[enGuid]		UNIQUEIDENTIFIER,  
			[enDate]		DATETIME,      
			[enNumber]		INT,      
			[ceNotes]		NVARCHAR(1000),      
			[FixedEnDebit]	FLOAT,      
			[FixedEnCredit]	FLOAT,      
			[enNotes]		NVARCHAR(1000),      
			[Balance]		FLOAT,    
			[enContraAcc]	UNIQUEIDENTIFIER, 
			[FFLAG]			INT,  
			[erParentType]	INT,
			[Flag]			INT,
			[erParentGuid]	UNIQUEIDENTIFIER,
			[enAccount]		UNIQUEIDENTIFIER,
			[enCostPoint]	UNIQUEIDENTIFIER,
			[ceBranch]		UNIQUEIDENTIFIER)
	
	INSERT INTO [#ENTRY]
	SELECT     
			[f].[ceTypeGuid],   
			[f].[ceSecurity],      
			[t].[Security],     
			CASE [t].[Flag] WHEN 1 THEN [er].[erParentGuid] ELSE  [f].[ceGuid] END [ceGuid],   
			[f].[ceNumber],
			[enGuid],  
			[f].[enDate],      
			[f].[enNumber],      
			[f].[enNotes],      
			[f].[EnDebit]* Factor  [FixedEnDebit],      
			[f].[EnCredit]* Factor [FixedEnCredit],      
			[f].[enNotes] ,      
			ISNULL(([f].[EnDebit] - [f].[EnCredit]), 0) * Factor AS [Balance],    
			[enContraAcc], 
			CASE [t].[Flag] WHEN 1 THEN 4 WHEN 2 THEN CASE [er].[erParentType] WHEN 5 THEN 1 ELSE [er].[erParentType] END  ELSE 1 END AS [FFLAG],  
			[er].[erParentType],
			[t].[Flag],
			ISNULL([er].[erParentGuid],0X00) [erParentGuid],
			[f].[enAccount],
			[f].[enCostPoint],
			[ceBranch]
		FROM      
			(SELECT *,1 / CASE WHEN  enCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN enCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  enDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  enDate  ORDER BY DATE DESC) 
							 ELSE enCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE enCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  enDate  ORDER BY DATE DESC))
			    END Factor 
			FROM vwCeEn fn inner join ac000 ac on ac.guid = fn.enAccount) AS [f]
			LEFT JOIN [vwEr] AS [er]     
			ON [f].[ceGuid] = [er].[erEntryGuid]     
			INNER JOIN [#EntrySource] AS [t]     
			ON [f].[ceTypeGuid] = [t].[Type] --AND [t].Flag <> 3
		WHERE     
			 [f].[enDate] <= @EndDate 
			 AND ([f].[enAccount] =  @AccGuid)       
			AND (( @Contain = '') OR ([f].[enNotes] LIKE @ContainStr) OR ([f].[ceNotes] LIKE @ContainStr) )     
			AND (( @NotContain = '') OR (( [f].[enNotes] NOT LIKE @NotContainStr) AND ( [f].[ceNotes] NOT LIKE @NotContainStr)))  
			AND ([f].[enCustomerGUID] = ISNULL( @CustPtr, 0x0))   
			         
	CREATE CLUSTERED INDEX entryParentType ON [#ENTRY]([erParentGuid])
	INSERT INTO [#Result] ([CustPtr],[CustSecurity],[Type],[Security],[UserSecurity],[Guid],[Number],[Date], [BNotes],[EntryDebit],[EntryCredit],[Notes],[Balance],[ContraAcc],[Flag],[Branch],[CostPtr],[enGuid])            
		SELECT     
			@CustPtr,    
			@CustSec,    
			[ceTypeGuid],   
			[ceSecurity],      
			[#ENTRY].[Security],     
			[ceGuid],   
			[ceNumber],      
			CASE WHEN erparenttype = 13 THEN chdate ELSE [enDate] END AS enDate,
			[ceNotes],      
			[FixedEnDebit],  -- EntryDebit      
			[FixedEnCredit], -- EntryCredit,      
			[enNotes],      
			[Balance],     
			[enContraacc],
			CASE WHEN erparenttype = 6 THEN 1 ELSE [FFlag] END,
			[ceBranch],
			[enCostPoint],
			[enGuid]
		FROM
			[#ENTRY]
			INNER JOIN  [#CostTbl] AS [co] ON [enCostPoint] = [co].[Guid]
			LEFT JOIN [vwBu] AS [bu] ON [erParentGuid] = [bu].[buGuid] 
			LEFT JOIN (select chGuid,chAccount,chDir,chdate from vwch) ch ON [erParentGuid] =  ch.chGuid  
		WHERE     
			(([Flag] = 1) OR ([Flag] = 4) OR ([Flag] = 9) OR (([Flag] = 2) AND ([erParentType] IN (6, 7, 8, 12, 13,250,251,252,253,254,255,256,257,258,259,260,261,262))) OR ([Flag] = 3 AND [enAccount] <> [bu].[buCustAcc] AND ([bu].[buMatAcc] <>[enAccount] or ( [bu].[buMatAcc] =[enAccount] and btType <> 3 and  btType  <>  3))) )    
			OR ([Flag] = 2 AND [erParentType] = 5 AND ((chDir = 1 and ([FixedEnDebit] > 0 ) ) or (chDir = 2 and ([FixedEnCredit] > 0 ) )))
			OR ([Flag] = 3 and [erParentType] = 600)
			
	-- IF (@ShowOppAcc = 1)
		UPDATE [res] SET [OppAccName]  = [acName],	[OppAccCode] = [acCode] 
		 FROM [#Result] AS [res] INNER JOIN [vwAc] ON [res].[ContraAcc] = [ACgUID]
---------------------------------------------------------------------------    
---------------------------------------------------------------------------    
	IF( @UseChkDueDate = 0)     
		INSERT INTO     
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date],[BNotes],[EntryDebit],[EntryCredit],[Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])    
			SELECT     
				@CustPtr,    
				@CustSec,    
				0,    
				[ch].[chType],    
				[ch].[chSecurity],    
				[nt].[Security],    
				[ch].[chGuid],    
				[ch].[chNumber],    
				[ch].[chDate],     
				[ch].[chNotes],    
				(Case     
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal]* Factor    
					ELSE 0     
					END), -- EntryDebit    
				(Case     
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal] * Factor  
					ELSE 0     
					END), -- EntryCredit    
				(Case     
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal]* Factor 
					ELSE (-[ch].[chVal]  * FACTOR) 
					END), -- Balance    
				CASE ch.IsTransfered
					WHEN 0 THEN 5
					ELSE 6
				END,
				[chbranchGuid],[chCost1GUID],chNum  ,
				[ch].[chState],
				[ch].[chDir]
			FROM     
				(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor 
				FROM [#vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount
				 ) AS [ch] 
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]          
			WHERE     
				[chAccount] = @AccGuid
				AND [chCustomerGUID] = @CustPtr     
				AND (( @Contain = '') OR ([chNotes] LIKE @ContainStr))    
				AND (( @NotContain = '') OR ([chNotes] NOT LIKE @NotContainStr))    
				AND [chDate] <= @EndDate     
				AND 
				(
					(
						(ch.IsTransfered = 0)
						AND
						(
						[chState] IN (1, 3, 5, 6, 8, 9, 12, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
					OR 
					(
						(ch.IsTransfered = 1)
						AND
						(
						[chState] IN (0, 6, 8, 9, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
				)
				     
	ELSE IF( @UseChkDueDate = 1)      
		INSERT INTO     
				[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date],[BNotes],[EntryDebit],[EntryCredit],[Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])    
			SELECT     
				@CustPtr,    
				@CustSec,    
				0,    
				[ch].[chType],    
				[ch].[chSecurity],    
				[nt].[Security],    
				[ch].[chGuid],    
				[ch].[chNumber],    
				[ch].[chDate],      
				[ch].[chNotes],    
				(Case     
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * Factor 
					ELSE 0     
					END), -- EntryDebit    
				(Case     
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal]  * Factor 
					ELSE 0     
					END), -- EntryCredit    
				(Case     
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal]  * Factor  
					ELSE -[ch].[chVal] * Factor  
					END), -- Balance    
				CASE ch.IsTransfered
					WHEN 0 THEN 5
					ELSE 6
				END,
				[chbranchGuid],[chCost1GUID],chnum ,
				[ch].[chState],
				[ch].[chDir]
			FROM     
				(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor 
				FROM [#vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount
				) AS [ch] INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]
				--INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]          
			WHERE      
				[chAccount] = @AccGuid  
				AND [chCustomerGUID] = @CustPtr   
				AND (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))    
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))    
				AND [chDueDate] <= @EndDate     
				AND 
				(
					(
						(ch.IsTransfered = 0)
						AND
						(
						[chState] IN (1, 3, 5, 6, 8, 9, 12, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
					OR 
					(
						(ch.IsTransfered = 1)
						AND
						(
						[chState] IN (0, 6, 8, 9, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
				)
	ELSE      
		INSERT INTO     
				[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date],[BNotes],[EntryDebit],[EntryCredit],[Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])    
			SELECT     
				@CustPtr,    
				@CustSec,    
				0,    
				[ch].[chType],    
				[ch].[chSecurity],    
				[nt].[Security],    
				[ch].[chGuid],    
				[ch].[chNumber],    
				[ch].[chDate],      
				[ch].[chNotes],    
				(Case     
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * Factor    
					ELSE 0     
					END), -- EntryDebit    
				(Case     
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal]* Factor      
					ELSE 0     
					END), -- EntryCredit    
				(Case     
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal]* Factor      
					ELSE -[ch].[chVal] * Factor      
					END), -- Balance    
				CASE ch.IsTransfered
					WHEN 0 THEN 5
					ELSE 6
				END,
				[chbranchGuid],[chCost1GUID]  ,chnum,
				[ch].[chState],
				[ch].[chDir]
			FROM     
				(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor 
				FROM [#vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount
				 ) AS [ch] 
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]          
			WHERE     
				[chAccount] = @AccGuid 
				AND(CASE @UseChkDueDate WHEN 1 THEN [chDueDate] ELSE [chDate] END <= @EndDate)    
				AND (( @Contain = '') OR ([chNotes] LIKE @ContainStr))    
				AND (( @NotContain = '') OR ([chNotes] NOT LIKE @NotContainStr))  
				AND 
				(
					(
						(ch.IsTransfered = 0)
						AND
						(
						[chState] IN (1, 3, 5, 6, 8, 9, 12, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
					OR 
					(
						(ch.IsTransfered = 1)
						AND
						(
						[chState] IN (0, 6, 8, 9, 13)      
						OR ([chState] = (CASE @IsEndorsedRecieved WHEN 1 THEN 4 END))
						OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 1 THEN 11 END)) 
						)
					)
				)
	--Calc partly collected cheques.
	INSERT INTO        
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])         
			SELECT        
				@CustPtr,    
				@CustSec,    
				0,       
				[ch].[chType],       
				[ch].[chSecurity],       
				[nt].[Security],       
				[ch].[chGUID],       
				[ch].[chNumber],     
				[ch].[chDate],      
				[ch].[chNotes],
				(Case       
					WHEN [ch].[chDir] = 2 THEN 
						CASE ch.chTransferCheck 
							when 0 then case when (@ShowChk = 0 OR @IsShowChequeDetailsPartly = 1) then [chr].[SumParts]  else [chr].[SumParts] + [chr].[RemAmount] END 
							else [chr].[RemAmount]
						end * Factor    
					ELSE 0        
					END), -- EntryDebit       
				(Case        
					WHEN [ch].[chDir] = 1 THEN 
						CASE ch.chTransferCheck 
							when 0 then case when (@ShowChk = 0 OR @IsShowChequeDetailsPartly = 1) then [chr].[SumParts]  else [chr].[SumParts] + [chr].[RemAmount] END 
							else [chr].[RemAmount]
						end * Factor    
					ELSE 0        
					END), -- EntryCredit       
			
				(Case        
					WHEN [ch].[chDir] = 2 THEN 
						CASE ch.chTransferCheck 
							when 0 then case when (@ShowChk = 0 OR @IsShowChequeDetailsPartly = 1) then [chr].[SumParts]  else [chr].[SumParts] + [chr].[RemAmount] END 
							else [chr].[RemAmount]
						END * [Factor]
					ELSE 
						CASE ch.chTransferCheck 
							when 0 then -case when (@ShowChk = 0 OR @IsShowChequeDetailsPartly = 1) then [chr].[SumParts]  else [chr].[SumParts] + [chr].[RemAmount] END
							else -[chr].[RemAmount]
						END * [Factor]
					END), -- Balance     
				CASE ch.chTransferCheck
					WHEN 0 THEN 5
					ELSE 6
				END,
				chbranchGuid,[chCost1GUID] ,[chnum] ,
				CASE WHEN @IsShowChequeDetailsPartly = 1 then [ch].[chState] ELSE -2 END,
				[ch].[chDir]
			FROM        
				(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor  
				FROM [vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount
				) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
				-- INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]  
				INNER JOIN [#ChequePartAmount]  AS [chr] ON [chr].[chGuid] = [ch].[chGuid]
			WHERE  
				([chAccount] = @AccGuid)
				AND 
				(CASE @UseChkDueDate WHEN 1 THEN [chDueDate] ELSE [chDate] END <= @EndDate)       
				AND (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))       
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))   
	   
-----------------------------------------------------------------------------------    
-----------------------------------------------------------------------------------    
	IF( @ShowChk > 0)     
BEGIN		
		INSERT INTO     
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1],[chState],[chDir])         
			SELECT     
				@CustPtr,    
				@CustSec,    
				0,    
				[ch].[chType],    
				[ch].[chSecurity],    
				[nt].[Security],    
				[ch].[chGUID],       
				[ch].[chNumber],    
				[ch].[chDate],        
				[ch].[chNotes],    
				(Case     
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] *  Factor    
					ELSE 0     
					END), -- EntryDebit    
				(Case     
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal] * Factor    
					ELSE 0     
					END), -- EntryCredit    
			
				(Case        
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * [Factor]      
					ELSE -[ch].[chVal] * Factor 
					END), -- Balance     
				-1,chbranchGuid,[chCost1GUID] ,[chnum] ,
				[ch].[chState],
				[ch].[chDir]
			FROM        
				(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor  
				FROM [#vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount
				 ) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
				-- INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]   
			WHERE  
				([chAccount] = @AccGuid)
				AND [chCustomerGUID] = @CustPtr
				AND 
				(CASE @UseChkDueDate WHEN 1 THEN [chDueDate] ELSE [chDate] END <= @EndDate)       
				AND (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))       
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))   
				AND 
				(
					([ch].[chState] in (0, 7, 10,  14) ) 
					OR ([chState] = (CASE @IsEndorsedRecieved WHEN   0  THEN  4   END))
					OR ([chState] = (CASE @IsDiscountedRecieved	WHEN 0 THEN 11   END))
				)
				AND (ch.IsTransfered = 0)				

			--Calc partly
			-- IF @IsShowChequeDetailsPartly = 1	
			INSERT INTO        
				[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1])         
			SELECT        
				@CustPtr,    
				@CustSec,    
					0,       
					[ch].[chType],       
					[ch].[chSecurity],       
					[nt].[Security],       
					[ch].[chGUID],       
					[ch].[chNumber],     
					[ch].[chDate],        
					[ch].[chNotes],
				
					(Case       
						WHEN [ch].[chDir] = 2 THEN [chr].[RemAmount] *  Factor     
						ELSE 0        
						END), -- EntryDebit       
					(Case        
						WHEN [ch].[chDir] = 1 THEN [chr].[RemAmount] *  Factor       
						ELSE 0        
						END), -- EntryCredit       
			
				(Case     
						WHEN [ch].[chDir] = 2 THEN [chr].[RemAmount] *  Factor       
						ELSE -[chr].[RemAmount] *  Factor   
					END), -- Balance    
					CASE @IsShowChequeDetailsPartly when 0 THEN -2 ELSE -1 END,chbranchGuid,[chCost1GUID] ,[chnum] 
			FROM     
				(SELECT *,1 / CASE WHEN  chCurrencyPtr = (case @DetailingByCurrencyAccount WHEN 1 then ac.CurrencyGuid  ELSE  @CurPtr end )
				     THEN (CASE @DetailingByCurrencyAccount 
				           WHEN 1 THEN ( (CASE  WHEN chCurrencyVal = (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) THEN 
							(SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  chDate  ORDER BY DATE DESC) 
							 ELSE chCurrencyVal END))
						  -- (SELECT TOP 1 CurrencyVal FROM mh000 WHERE CURRENCYGuid = ac.CurrencyGuid and [DATE] <=  buDate  ORDER BY DATE DESC) 
				                   ELSE chCurrencyVal
						   END) 
				    ELSE  ((SELECT TOP 1 VAL FROM @Curr WHERE CurrGuid = (case @DetailingByCurrencyAccount when 1 then ac.CurrencyGuid else @curptr end) 
					                                     and [DATE] <=  chDate  ORDER BY DATE DESC))
			    END Factor 
				FROM [vwCh] ch inner join  ac000 ac on ac.Guid = ch.chAccount
				 ) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
				-- INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]          
				INNER JOIN [#ChequePartAmount] AS [chr] ON [chr].[chGuid] = [ch].[chGuid]
			WHERE  
				([chAccount] = @AccGuid)
				AND [chCustomerGUID] = @CustPtr
				AND 
				(CASE @UseChkDueDate WHEN 1 THEN [chDueDate] ELSE [chDate] END <= @EndDate)       
				AND (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))       
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))   
				AND chTransferCheck = 0

		IF (@IsNotShowUnDelivered = 1)
			DELETE [#Result] WHERE [Guid] IN (SELECT ChGuid FROM [vwCh] WHERE [chState] =14)  
END
				
----------------------------------------------------------------------
--Delete  Check With No Edit Entry
	IF (@ShwChWithEn =1)
		DELETE [#Result] WHERE  ( [Flag] = 5) AND [Guid] NOT IN (SELECT [ParentGuid] FROM [er000] WHERE [ParentType] = 5)
----------------------------------------------------------------------     
	EXEC [prcCheckSecurity] @UserId    
  
	DECLARE @PriveBalance [FLOAT]     
	    
	IF @StartBal=0    
		SELECT @PriveBalance = ISNULL( SUM([Balance]), 0) FROM     
				(SELECT DISTINCT [Type],[Guid],[Balance], [flag],'' AS [Notes] FROM [#Result] WHERE [Date] < @StartDate AND [OrderFlag] = 0 AND [IsCash] = 0 AND [FLAG] =2 
			UNION ALL
			SELECT  [Type],[Guid],[Balance],[flag],[Notes] FROM [#Result] WHERE [Date] < @StartDate AND [OrderFlag] = 0 AND [IsCash] = 0 AND [FLAG] <> 2 AND [Flag] <> 6) AS [p]   
	ELSE 
		SET @PriveBalance=0 
	   
	DELETE [#Result] WHERE [Date] < @StartDate AND [Flag] <> 6
	
	IF (@StartBal=0)
		SET @StDate = '1/1/1980'
	ELSE
		SET @StDate = @StartDate
	DECLARE @RBalance AS [FLOAT]
	IF @bUnmatched =1
	BEGIN 
		DECLARE @CurrencyGUID UNIQUEIDENTIFIER 
		SET @CurrencyGUID = @CurPtr
		IF @DetailingByCurrencyAccount <> 0
			SELECT @CurrencyGUID = ISNULL(CurrencyGUID, @CurPtr) FROM ac000 WHERE GUID = @AccGuid

		SET @RBalance = [dbo].[fnAccCust_getBalance](@AccGuid,@CurrencyGUID,@StDate,@EndDate,@CostGuid, @CustPtr) 
	END 
	ELSE
		SET @RBalance = 0
			   
	IF (((@ShowAccMoved=1) AND EXISTS(SELECT * FROM [#RESULT])) OR (@ShowAccmoved=0)) 
		INSERT INTO [#Result]([CustPtr],[Date],[BuTotal],[Balance],[Flag]) VALUES ( @CustPtr, @StartDate - 1, @PriveBalance,@RBalance, 0)
###############################################################################
CREATE PROCEDURE repCPS
	@SrcGuid					AS [UNIQUEIDENTIFIER],    
	@StartDate					AS [DATETIME],
	@EndDate					AS [DATETIME], 
	@AccPtr						AS [UNIQUEIDENTIFIER],   
	@CustPtr					AS [UNIQUEIDENTIFIER],   
	@CurPtr						AS [UNIQUEIDENTIFIER],   
	@CurVal						AS [FLOAT],    
	@Post						AS [INT], -- 1: posted, 2: Unposted, 3: Poth     
	@Cash						AS [INT], -- 1: cash, 2: Later, else: Both     
	@Contain					AS [NVARCHAR](1000),-- Notes Contain     
	@NotContain					AS [NVARCHAR](1000),-- Notes Not Contain     
	@UseCheckDate				AS [INT], -- Use Acc Check Date As Start Date     
	@ShowDetails				AS [INT], -- Show Bill Detail     
	@UseChkDueDate				AS [INT],   
	@ShowChk					AS [INT], -- Show Uncollected Notes     
	@CostGuid					AS [UNIQUEIDENTIFIER], -- Show Uncollected Notes 
	@ShowSerialNumbers			AS [BIT],   
	@ShowAccMoved				AS [INT] = 0,  
	@StartBal					AS [INT] = 0,  
	@bUnmatched					AS [INT] =1, 
	@ShwChWithEn				AS [INT] = 0, 
	@ShowDiscExtDet				AS [INT] = 0, 
	@CondGuid					AS [UNIQUEIDENTIFIER] = 0X00, 
	@ShowChecked				AS [BIT] = 0, 
	@ItemChecked				AS [INT] = -1, 
	@CheckForUsers				AS [INT] = 0, 
	@Rid						AS FLOAT = 0   ,
	@ShowDebtAgesPreview		AS BIT = 0,
	@PeriodsNo					AS SMALLINT = 0,
	@PeriodLength				AS SMALLINT = 0,
	@IsEndorsedRecieved			BIT = 0, 
	@IsDiscountedRecieved		BIT = 0,
	@IsNotShowUnDelivered		BIT = 0,
	@IsShowChequeDetailsPartly	AS BIT = 0,
	@ShowValVat					AS BIT = 0,
	@DetailingByCurrencyAccount	AS BIT = 0,
	@IsGroupedByNoteType		AS BIT = 0,
	@ShowClosedCust				AS BIT = 1,
	@UseUnit					INT = 0,	 -- 0 : bill, 1: Unit1, 2: Unit2, 3: Unit3 
	@ShowRunningBalance			BIT = 0
AS 	    
	SET NOCOUNT ON     

	DECLARE	     
		@UserID			[UNIQUEIDENTIFIER],      
		@CustSec		[INT],     
		@NormalEntry	[INT],    
		@CustFromDate	[DATETIME], 
		@cstCnt			[INT],
		@AccWithoutCust [INT],
		@CustCount      [INT],
		@ParentAcc      [INT]

	CREATE TABLE [#Cust]([Number] [UNIQUEIDENTIFIER], [Security] [INT], [FromDate] [DATETIME])     
	CREATE TABLE [#CostTbl]([Guid] [UNIQUEIDENTIFIER], [Security] [INT])     
	CREATE TABLE [#BillTbl]([Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT], 
		[UnpostedSecurity] [INT],[PriorityNum] [INTEGER], [SamePriorityOrder] INT, [SortNumber] INT) 
	CREATE TABLE [#EntryTbl]([Type] [UNIQUEIDENTIFIER], [Security] [INT])     
	CREATE TABLE [#NotesTbl]([Type] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#EntrySource]([Type] [UNIQUEIDENTIFIER], [Security] [INT], [Flag] [INT])   
	CREATE TABLE [#BillTbl2]([Type] [UNIQUEIDENTIFIER],[Security] INT, [ReadPriceSecurity] INT, [UnpostedSecurity] INT, [btType] INT, [btVatSystem] FLOAT, [btDirection] INT)  
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])     
	CREATE TABLE [#Result] (     
		[CustPtr]					[UNIQUEIDENTIFIER],
		[CustSecurity]				[INT] DEFAULT	0,     
		[OrderFlag]					[INT] DEFAULT 0,     
		[Type]						[UNIQUEIDENTIFIER],
		[Security]					[INT] DEFAULT 0,
		[UserSecurity] 				[INT] DEFAULT 0,
	    [Guid]						[UNIQUEIDENTIFIER], 
	    [enGuid]					[UNIQUEIDENTIFIER],      
		[Number]					[INT],   
		[Date]						[DATETIME] DEFAULT '1/1/1980',      
		[biNumber]					[INT],      
		[BNotes]					[NVARCHAR](1000) COLLATE ARABIC_CI_AI DEFAULT '',      
		[ParentType]				[INT] DEFAULT 0,      
		[ParentNum]					[INT] DEFAULT 0,      
		[IsCash]					[INT] DEFAULT 0,      
		[BuTotal]					[FLOAT] DEFAULT 0,      
		[BuVAT]						[FLOAT] DEFAULT 0,     
		[BuDiscount]				[FLOAT] DEFAULT 0,     
		[BuExtra]					[FLOAT] DEFAULT 0,      
		[BuSalesTax]				[FLOAT] DEFAULT 0,      
		[BuFirstPay]				[FLOAT] DEFAULT 0,      
		[UserReadPriceSecurity]		[INT] DEFAULT 3,     
		[MatPtr]					[UNIQUEIDENTIFIER],
		[Store]						[NVARCHAR](300) COLLATE ARABIC_CI_AI,      
		[Qty]						[FLOAT],      
		[Bonus]						[FLOAT],      
		[Unit]						[INT],      
		[biQty2]					[FLOAT],      
		[biQty3]					[FLOAT],      
		[ExpireDate]				[DATETIME],      
		[ProductionDate]			[DATETIME],      
		[CostPtr]					[UNIQUEIDENTIFIER],      
		[ClassPtr]					[NVARCHAR](300) COLLATE ARABIC_CI_AI,       
		[Length]					[FLOAT],      
		[Width]						[FLOAT],      
		[Height]					[FLOAT],  
		[Count]						[FLOAT], 
		[BiPrice]					[FLOAT],      
		[BiDiscount]				[FLOAT],      
		[BiExtra]					[FLOAT],   
		[BiVAT]						[FLOAT],   
		[biBonusDisc]				[FLOAT],    
		[EntryDebit]				[FLOAT] DEFAULT 0,      
		[EntryCredit]				[FLOAT] DEFAULT 0,      
		[Notes]						[NVARCHAR](1000) COLLATE ARABIC_CI_AI DEFAULT '',     
		[Balance]					[FLOAT] DEFAULT 0,     
		[SalesMan]					[FLOAT] DEFAULT 0,  
		[Vendor]					[FLOAT] DEFAULT 0,    
		[ContraAcc]					[UNIQUEIDENTIFIER] DEFAULT 0X00, 
		[OppAccName]				[NVARCHAR](300) COLLATE ARABIC_CI_AI DEFAULT '',  
		[OppAccCode]				[NVARCHAR](300) COLLATE ARABIC_CI_AI DEFAULT '',  
		[buTextFld1]				[NVARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',  
		[buTextFld2]				[NVARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',  
		[buTextFld3]				[NVARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',  
		[buTextFld4]				[NVARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',  
		[MatSecurity]				[INT],  
		[Flag]						[INT] DEFAULT 0, 
		[FormatedNumber]			[INT], 
		[Branch]					[UNIQUEIDENTIFIER] DEFAULT 0X00, 
		[Checked]					[INT],
		[DueDate]					SMALLDATETIME DEFAULT '1/1/1980',
		CHGuid						UNIQUEIDENTIFIER DEFAULT 0X00,
		CHTypGuid					UNIQUEIDENTIFIER DEFAULT 0X00,
		chNumber					INT,
		SN  						[NVARCHAR](300) COLLATE ARABIC_CI_AI,
		SNGuid						UNIQUEIDENTIFIER,
		SNItem						INT,
		[chState]					INT DEFAULT -1,
		[chDir]						INT DEFAULT -1,
		chValue						FLOAT) 

	IF( @ShowDetails = 0)
	BEGIN     
		ALTER TABLE      
			[#Result]     
		DROP COLUMN     
			[biNumber],     
			[MatPtr],     
			[Store],   
			[Qty],     
			[Bonus],     
			[Unit],     
			[biQty2],     
			[biQty3],     
			[ExpireDate],     
			[ProductionDate],     
			[ClassPtr],     
			[Length],     
			[Width],     
			[Height],   
			[Count],   
			[BiPrice],     
			[BiDiscount],     
			[BiExtra],  
			[MatSecurity], 
			[biBonusDisc],
			SN,
			SNGuid,
			SNItem
			
	END
	ELSE
	BEGIN	
		IF @ShowSerialNumbers = 0
		BEGIN 
		ALTER TABLE      
				[#Result]     
			DROP COLUMN 
				-- SN,
				SNGuid,
				SNItem
		END 
	END
	
	SET @UserId = [dbo].[fnGetCurrentUserGUID]()      

	INSERT INTO [#NotesTbl] EXEC [prcGetNotesTypesList] @SrcGuid, @UserID     
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList3] @SrcGuid, @UserID     
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserID     
	INSERT [#EntrySource] SELECT [Type], [Security], 1 FROM [#EntryTbl] WHERE [TYPE] <> 0X00 
	INSERT [#EntrySource] SELECT [Type], [Security], 2 FROM [#NotesTbl]  
	INSERT [#EntrySource] SELECT [Type], [Security], 3 FROM [#BillTbl] 
	
	SET @NormalEntry = [dbo].[fnIsNormalEntry](@SrcGuid)    
	IF @NormalEntry > 0   
		INSERT [#EntrySource] VALUES(0X00, [dbo].[fnGetUserEntrySec_Browse](@UserId, DEFAULT), 9) 
	IF (ISNULL(@AccPtr, 0x0) = 0x0 AND ISNULL(@CustPtr, 0x0) <> 0x0)
	BEGIN 
	SELECT @AccPtr = cuAccount FROM vwcu WHERE cuGUID = ISNULL(@CustPtr, 0x0) 
	END
	SELECT @ParentAcc = NSons FROM ac000 WHERE GUID = ISNULL( @AccPtr, 0x0)	

	DECLARE @accType INT,
			@aggregateAccountFlag INT = 4

	SELECT @accType = [Type] FROM ac000 WHERE [GUID] = @AccPtr

	IF @ParentAcc = 0  AND @accType = @aggregateAccountFlag
		SELECT @ParentAcc = COUNT(*) FROM ci000 WHERE ParentGUID = @AccPtr

	SELECT @CustCount = COUNT(*) FROM vwCu WHERE cuAccount = ISNULL( @AccPtr, 0x0)
	IF (@CustCount  = 0 And @AccPtr <> 0x0)
		SET @AccWithoutCust = 1
	IF (@AccWithoutCust = 1 AND @CustPtr <> 0x0 AND @ParentAcc = 0)
	BEGIN
		INSERT INTO [#Cust]([Number], [Security]) EXEC [prcGetAcountEnCustsList] @CustPtr, @AccPtr, @CondGuid 
	END	 
	ELSE
	BEGIN
		INSERT INTO [#Cust]([Number], [Security]) EXEC [prcGetCustsList] @CustPtr, @AccPtr, @CondGuid 
	END
	
	INSERT INTO [#BillTbl2] 
	SELECT 
		[b].[Type], [Security], [ReadPriceSecurity], [UnpostedSecurity], 
		[bt].[Type], [VatSystem], CASE [bisInput] WHEN 1 THEN 1 ELSE -1 END AS [btDirection]  
	FROM 
		[#BillTbl] AS [b] 
		INNER JOIN [bt000] AS [bt] ON bt.[Guid] = [b].[Type]   

	IF (ISNULL(@CostGuid, 0x0) = 0x0)  
		INSERT INTO [#CostTbl] VALUES(0X00, 0) 
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostGuid  

	IF ( @ShowDetails <> 0)  
	BEGIN  
		CREATE TABLE [#MatTbl]([MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])   
		INSERT INTO [#MatTbl] SELECT [mtGuid], [mtSecurity] FROM [vwMt] 
		CREATE CLUSTERED INDEX MTIND ON [#MatTbl]([MatGUID]) 
	END
	 
	CREATE TABLE [#MatchNote] (     
		[CustPtr]	[UNIQUEIDENTIFIER], 
		[Notes]		[NVARCHAR](1000) COLLATE ARABIC_CI_AI DEFAULT '') 

	IF( @UseCheckDate = 0)     
		UPDATE [#Cust] SET [FromDate] = @StartDate   
	ELSE    
	BEGIN 
		CREATE TABLE [#chkAcc]([AccGUID] [UNIQUEIDENTIFIER], [chDate] DATETIME, [CustGUID] [UNIQUEIDENTIFIER])
		INSERT INTO [#chkAcc] SELECT [AccGUID], MAX([CheckedToDate]), [CustGUID]
		FROM [dbo].[CheckAcc000]   
		WHERE  
			[CheckedToDate] <= @EndDate AND [CostGuid] = @CostGuid  
		GROUP BY [AccGUID], [CustGUID] 

		UPDATE [#Cust] 
		SET [FromDate] = ISNULL([va].[chDate] + 1, @StartDate)   
		FROM 
			[#Cust] AS [c] 
			INNER JOIN [cu000] AS [vc] ON [c].[Number] = [vc].[GUID]     
			LEFT JOIN [#chkAcc] AS [va] ON [vc].[GUID] = [va].[CustGUID] 
		INSERT INTO  [#MatchNote] 
		SELECT 
			[c].[Number], ISNULL([cha].[Notes], '') 
		FROM 
			[#Cust] AS [c] 
			INNER JOIN [cu000] AS [vc] ON [c].[Number] = [vc].[GUID]     
			LEFT JOIN [#chkAcc] AS [va] ON [vc].[GUID] = [va].[CustGUID] 
			INNER JOIN [dbo].[CheckAcc000]  AS [cha] ON [cha].[CheckedToDate] = [va].[chDate] AND [cha].[AccGUID] = [va].[AccGUID] 	
	END 
	
	CREATE TABLE [#CUST1]([Number] [UNIQUEIDENTIFIER], [Security] INT, [FromDate] DATETIME, [AccountGuid] [UNIQUEIDENTIFIER])
	INSERT INTO [#CUST1] 
	SELECT [Cu].[Number], [Cu].[Security], [Cu].[FromDate], CASE WHEN (@AccWithoutCust = 1 AND @ParentAcc = 0)THEN @AccPtr ELSE  [C].[AccountGuid] END 
	FROM 
		[#Cust] AS [Cu] 
		INNER JOIN [cu000] AS [C] ON [Cu].[Number] = [C].[guid]  

	CREATE CLUSTERED INDEX COIND ON [#CostTbl]([Guid]) 
	CREATE CLUSTERED INDEX BTIND ON [#BillTbl2]([Type]) 
	
	SELECT 
		c2.ColDate EventDate, 
		ch.chTransferCheck AS IsTransfered,
		ch.* 
	INTO [#vwCh]
	FROM
		vwch ch
		INNER JOIN (SELECT ChequeGuid, MAX([Date]) ColDate FROM ChequeHistory000 cc GROUP BY ChequeGuid) AS [c2] ON ch.chGUID = c2.ChequeGuid 
		INNER JOIN [#CUST1] cu ON cu.AccountGuid = ch.chAccount and cu.Number = ch.chCustomerGUID 
		INNER JOIN [#NotesTbl] nt ON nt.Type = ch.chType
	-- WHERE ch.chTransferCheck = 0

	CREATE TABLE [#ChequePartAmount]([ChGuid] UNIQUEIDENTIFIER, [ColDate] DATETIME,	[RemAmount]	FLOAT, [SumParts] FLOAT)   
	INSERT INTO [#ChequePartAmount]
	SELECT ch.chGUID, MAX(col.Date), MAX(ch.chVal) - SUM(col.Val), SUM(col.Val)
	FROM
		vwch ch 
		INNER JOIN ColCh000 col ON ch.chGUID = col.ChGUID
		INNER JOIN [#CUST1] cu ON cu.AccountGuid = ch.chAccount 
		INNER JOIN [#NotesTbl] nt ON nt.Type = ch.chType
	-- WHERE ch.chTransferCheck = 0
	GROUP BY 
		ch.chGUID 

		
	IF @CustPtr = 0X0  
	BEGIN 
		CREATE CLUSTERED INDEX cstind ON [#CUST1]([Number], [AccountGuid])   
		IF( @ShowDetails <> 0)
		BEGIN
			EXEC [repCPS_WithDetails] @ShowSerialNumbers,@UserID,  @EndDate, @CurPtr, @CurVal, @Post, @Cash, @Contain, @NotContain, @UseChkDueDate, @ShowChk, @CostGuid ,@ShowAccMoved,@StartBal,@bUnmatched,@ShwChWithEn,@ShowDiscExtDet /*,@ShowOppAcc*//*,@Flag*/, @IsEndorsedRecieved, @IsDiscountedRecieved, @IsNotShowUnDelivered,@IsShowChequeDetailsPartly, @ShowValVat, @DetailingByCurrencyAccount 
		END
		
		ELSE 
		begin
			EXEC [repCPS_WithoutDetails] @UserID,  @EndDate,  @CurPtr, @CurVal, @Post, @Cash, @Contain, @NotContain, @UseChkDueDate, @ShowChk, @CostGuid,@ShowAccMoved,@StartBal,@bUnmatched,@ShwChWithEn/*,@ShowOppAcc*/,0/*,@Flag*/, @IsEndorsedRecieved, @IsDiscountedRecieved, @IsNotShowUnDelivered,@IsShowChequeDetailsPartly , @DetailingByCurrencyAccount   
		end    
	END ELSE BEGIN 
		SELECT @CustSec = [Security], @CustFromDate = [FromDate] FROM [#Cust] 
		
		IF( @ShowDetails <> 0) 
		BEGIN  
			EXEC [repCPS_WithDetails_OneCust] @ShowSerialNumbers,@UserID, @CustFromDate, @EndDate, @CustPtr, @CustSec, @CurPtr, @CurVal, @Post, @Cash, @Contain, @NotContain, @UseChkDueDate, @ShowChk, @CostGuid ,@ShowAccMoved,@StartBal,@bUnmatched,@ShwChWithEn,@ShowDiscExtDet/*,@ShowOppAcc*//*,@Flag*/, @IsEndorsedRecieved, @IsDiscountedRecieved, @IsNotShowUnDelivered, @IsShowChequeDetailsPartly, @ShowValVat, @DetailingByCurrencyAccount,@AccPtr
		END	 
		ELSE    
			EXEC [repCPS_WithoutDetails_OneCust] @UserId,@StartDate,@EndDate,@CustPtr,@CustSec,@CurPtr,@CurVal,@Post,@Cash,@Contain,@NotContain,@UseChkDueDate,@ShowChk,@CostGuid,@ShowAccMoved,@StartBal,@bUnmatched,@ShwChWithEn,@ShowDiscExtDet/*,@ShowOppAcc*//*,@Flag*/, @IsEndorsedRecieved, @IsDiscountedRecieved, @IsNotShowUnDelivered, @IsShowChequeDetailsPartly, @DetailingByCurrencyAccount,@AccPtr
	END
	 
	INSERT INTO [#Result]([CustPtr], [Date], [Flag])	
	SELECT [cu].[Number], [CheckedToDate], 10000 
	FROM 
		([#Cust1] AS [cu] 
		INNER JOIN (SELECT DISTINCT [CustPtr] FROM [#Result]) AS [r] ON [CustPtr] = [cu].[Number]) 
		INNER JOIN [dbo].[CheckAcc000] AS [ch] ON [ch].[AccGUID] = [AccountGuid] 
	
	IF @UseCheckDate > 0 
		UPDATE [r] SET [Notes] = [m].[Notes] 
		FROM [#Result] AS [r] INNER JOIN  [#MatchNote] AS [m] ON [r].[CustPtr] = [m].[CustPtr] WHERE [Flag] = 0 

	UPDATE [#Result] set [enGuid] = [Guid] WHERE [enGuid] IS NULL 
	IF @ShowChecked > 0 
	BEGIN 
		UPDATE	r 
		SET	[Checked] = 1  
		FROM [#Result] [r] INNER JOIN rch000 a  ON r.[enGuid] = a.[ObjGUID] 
		WHERE a.Type = @Rid 
		 	AND( (@CheckForUsers = 1) OR ([a].[UserGuid] = @UserID)) 
		IF( @ItemChecked = 0)   
			DELETE FROM [#Result] WHERE [Checked] <> 1 OR  [Checked] IS NULL 
		ELSE IF( @ItemChecked = 1)   
				DELETE FROM [#Result] WHERE [Checked] = 1  
	END 
	IF EXISTS(SELECT 1 FROM #Result WHERE chDir > 0)
		UPDATE R 
		SET R.chValue = ch.chVal * (1 / CASE WHEN [chCurrencyPtr] = @CurPtr THEN [chCurrencyVal] ELSE dbo.fnGetCurVal(@CurPtr, chDate) END)
		FROM 
			#Result AS R 
			JOIN vwch ch ON ch.chGuid = R.[Guid];
	CREATE TABLE #AccountsBal(
		CustPtr UNIQUEIDENTIFIER,
		[ParentGUID] UNIQUEIDENTIFIER,
		GUID UNIQUEIDENTIFIER,	
		[enGUID] UNIQUEIDENTIFIER,
		BuTotal FLOAT,
		Balance FLOAT,
		FirstPay FLOAT,
		Discount FLOAT,
		Extra FLOAT,
		SumBalance FLOAT,
		Checked INT,
		IsCash INT,
		Flag INT,
		LastCheckDate Date,
		LastCheckNote [NVARCHAR](MAX),
		[ContraAccName] NVARCHAR(500))

		INSERT INTO #AccountsBal
	SELECT 
		r.CustPtr,
		r.[Type],
		r.GUID,		
		r.GUID,
		MAX(BuTotal),
		MAX(Balance),
		MAX(BuFirstPay),
		MAX(BuDiscount),
		MAX(BuExtra),
		SUM(Balance),
		MAX(Checked),
		IsCash,
		Flag,
		dbo.fnAccCustLastCheckDate(DEFAULT, r.CustPtr),
		MAX(r.Notes),
		''
	FROM 
		#Result r
	WHERE 
		[OrderFlag] = 0
		AND
		([Flag] = 2 OR [Flag] = 0 OR [Flag] = 10000)
	GROUP BY 
		CustPtr,
		r.[Type],
		r.GUID,
		Flag,
		IsCash

	INSERT INTO #AccountsBal
	SELECT 
		r.CustPtr,
		r.[Type],
		r.GUID,
		enGUID,
		0,
		Balance,
		0,
		0,
		0,
		Balance,
		Checked,
		0,
		Flag,
		'1-1-1980',
		'',
		CASE [OppAccCode] WHEN '' THEN '' ELSE [OppAccCode] + '-' + [OppAccName] END
	FROM 
		#Result r
		LEFT JOIN en000 en ON en.GUID = r.enGuid 
	WHERE 
		[OrderFlag] = 0
		AND
		([Flag] != 2 AND [Flag] != 0 AND [Flag] != 10000)
		AND
		ISNULL(en.AccountGUID, 0x0) = CASE  WHEN (@AccWithoutCust = 1 AND @ParentAcc = 0) THEN @AccPtr ELSE ISNULL(en.AccountGUID, 0x0) END

	CREATE TABLE #Accounts(
		CustPtr UNIQUEIDENTIFIER,
		RealBalance FLOAT,
		PrevBalance FLOAT,
		Debit FLOAT,
		Credit FLOAT, 
		Discount FLOAT,
		Extra FLOAT,
		UnCollectedChequesBalance FLOAT,
		SumChecked FLOAT,
		SumTransferedCheques FLOAT,
		LastCheckDate Date,
		LastCheckNote [NVARCHAR](MAX))
		
	INSERT INTO #Accounts
	SELECT 
		CustPtr,
		SUM(CASE Flag WHEN 0 THEN Balance ELSE 0 END), -- «·—’Ìœ «·ÕﬁÌﬁÌ
		SUM(CASE Flag WHEN 0 THEN BuTotal ELSE 0 END), -- «·—’Ìœ «·”«»ﬁ
		SUM(CASE Flag 
				WHEN 0 THEN 0 				
				WHEN 2 THEN 
					(CASE IsCash 
						WHEN 0 THEN (CASE WHEN Balance < 0 THEN FirstPay ELSE Balance + FirstPay END)
						ELSE (CASE WHEN Balance < 0 THEN - Balance + FirstPay ELSE Balance + FirstPay END)
					END)
				WHEN -2 THEN 0
				WHEN  6 THEN 0
				ELSE (CASE WHEN SumBalance < 0 THEN 0 ELSE SumBalance END) 
			END),
		SUM(CASE Flag 
				WHEN 0 THEN 0
				WHEN 2 THEN 
					(CASE IsCash 
						WHEN 0 THEN (CASE WHEN Balance > 0 THEN FirstPay ELSE -Balance + FirstPay END)
						ELSE (CASE WHEN Balance > 0 THEN Balance + FirstPay ELSE -Balance + FirstPay END)
					END)
				WHEN -2 THEN 0
				WHEN  6 THEN 0
				ELSE (CASE WHEN SumBalance > 0 THEN 0 ELSE -SumBalance END) 
			END),
		SUM(CASE Flag 
				-- WHEN 0 THEN 0 
				WHEN 2 THEN Discount
				ELSE 0
			END),
		SUM(CASE Flag 
				-- WHEN 0 THEN 0 
				WHEN 2 THEN Extra
				ELSE 0
			END),
		SUM(CASE WHEN (Flag = -1 OR Flag = -2) THEN Balance ELSE 0 END), -- «·√Ê—«ﬁ «·„«·Ì… €Ì— «·„Õ’·…
		SUM(CASE ISNULL(Checked, 0)
			WHEN 0 THEN 0
			ELSE 
				(CASE Flag
					WHEN 0 THEN 0
					WHEN 6 THEN 0
					WHEN 2 THEN Balance
					ELSE SumBalance
				END)
			END),
		SUM(CASE Flag 
				-- WHEN 0 THEN 0 
				WHEN 6 THEN SumBalance
				ELSE 0
			END),		
		MAX(CASE Flag WHEN 10000 THEN LastCheckDate ELSE '1-1-1980' END),
		MAX(CASE Flag WHEN 0 THEN LastCheckNote ELSE '' END)
	FROM 
		#AccountsBal
	GROUP BY 
		CustPtr

	IF @ShowClosedCust = 0
	BEGIN 
		DELETE #Accounts
		WHERE ABS(Debit - Credit + PrevBalance) < 0.1

		DELETE ab
		FROM 
			#AccountsBal ab
			LEFT JOIN #Accounts acc ON acc.CustPtr = ab.CustPtr
		WHERE 
			acc.CustPtr IS NULL
	END 

	
		
	CREATE TABLE #MasterTable(
		CustomerGUID UNIQUEIDENTIFIER,
		[ParentGUID] UNIQUEIDENTIFIER,
		[GUID] UNIQUEIDENTIFIER,
		[enGUID] UNIQUEIDENTIFIER,
		[BillGUID] UNIQUEIDENTIFIER,		
		[PaymentGUID] UNIQUEIDENTIFIER,		
		[ChequeGUID] UNIQUEIDENTIFIER,		
		[EntryGUID] UNIQUEIDENTIFIER,
		[BranchGUID] UNIQUEIDENTIFIER,
		[StoreGUID] UNIQUEIDENTIFIER,
		[CostGUID] UNIQUEIDENTIFIER,
		Document NVARCHAR(500),
		[FirstPay] FLOAT,
		[Debit] FLOAT,
		[Credit] FLOAT,
		Discount FLOAT,
		Extra FLOAT,
		DiscExtraRatio FLOAT,
		[DueDate] DATE,
		[Date] DATE,
		[Type] UNIQUEIDENTIFIER,
		[Number] INT,
		[Flag] INT,
		[IsCash] INT,
		[ContraAccName] NVARCHAR(500),
		[IsEntry] BIT,
		[ChequeDesc] NVARCHAR(500)
	)

	DECLARE @DivideDiscount BIT 
	SET @DivideDiscount = 0
	IF EXISTS(SELECT * FROM [op000] WHERE [Name] = 'AmnCfg_DivideDiscount' AND [Type] = 0 AND Value = '1')
		SET @DivideDiscount = 0

	INSERT INTO #MasterTable
	SELECT 
		[CustPtr],
		[ParentGUID],
		[GUID],
		[GUID],
		0x0,
		0x0,
		0x0,
		0x0,
		0x0,
		0x0,
		0x0,
		'',
		MAX([FirstPay]),
		SUM(CASE Flag 
				WHEN 0 THEN 0 
				WHEN 2 THEN 
					(CASE IsCash 
						WHEN 0 THEN (CASE WHEN Balance < 0 THEN FirstPay ELSE Balance + FirstPay END)
						ELSE (CASE WHEN Balance < 0 THEN - Balance + FirstPay ELSE Balance + FirstPay END)
					END)
				ELSE (CASE WHEN SumBalance < 0 THEN 0 ELSE SumBalance END) 
			END),
		SUM(CASE Flag 
				WHEN 0 THEN 0 
				WHEN 2 THEN 
					(CASE IsCash 
						WHEN 0 THEN (CASE WHEN Balance > 0 THEN FirstPay ELSE - Balance + FirstPay END)
						ELSE (CASE WHEN Balance > 0 THEN Balance + FirstPay ELSE - Balance + FirstPay END)
					END)
				ELSE (CASE WHEN SumBalance > 0 THEN 0 ELSE -SumBalance END) 
			END),
		SUM(CASE Flag 
				WHEN 2 THEN Discount
				ELSE 0
			END),
		SUM(CASE Flag 
				WHEN 2 THEN Extra
				ELSE 0
			END),
		SUM(CASE Flag 
				WHEN 2 THEN 
					(CASE @DivideDiscount 
						WHEN 1 THEN CASE Balance + FirstPay WHEN 0 THEN 1 ELSE (Discount - Extra) / (Balance + FirstPay) END 
						ELSE CASE ABS(Balance) + FirstPay + (Discount - Extra) WHEN  0 THEN 1 ELSE (Discount - Extra) / (ABS(Balance) + FirstPay + (Discount - Extra)) END 
					END) 
				ELSE 0
			END),
		'1-1-1980',
		'1-1-1980',
		0x0,
		0,
		2,
		MAX(IsCash),
		'',
		0,
		''
	FROM
		#AccountsBal
	WHERE 
		ISNULL([GUID], 0x0) != 0x0
		AND 
		([Flag] = 2 OR [Flag] = 0)
	GROUP BY 
		[CustPtr],
		[ParentGUID],
		[GUID]
		
	INSERT INTO #MasterTable
	SELECT 
		[CustPtr],
		[ParentGUID],
		[GUID],
		[enGUID],
		0x0,
		0x0,
		0x0,
		0x0,
		0x0,
		0x0,
		0x0,
		'',
		0,
		(CASE WHEN SumBalance < 0 THEN 0 ELSE SumBalance END),
		(CASE WHEN SumBalance > 0 THEN 0 ELSE -SumBalance END),
		0, 
		0,
		0,
		'1-1-1980',
		'1-1-1980',
		0x0,
		0,
		[Flag],
		0,
		[ContraAccName],
		0,
		''
	FROM 	
		#AccountsBal
	WHERE 
		ISNULL([GUID], 0x0) != 0x0
		AND 
		([Flag] != 2 AND [Flag] != 0)

	DECLARE @lang INT 
	SET @lang = [dbo].[fnConnections_GetLanguage]()
	--------------------------------------------------------------
	UPDATE #MasterTable 
	SET 
		BillGUID = res.[GUID],
		[BranchGUID] = [bu].[buBranch],
		[StoreGUID] = [bu].[buStorePtr],
		[CostGUID] = [bu].[buCostPtr],
		[Date] = [bu].buDate,
		[Type] = bt.btGUID,
		[Number] = bu.buNumber,
		[Document] = (CASE @lang WHEN 0 THEN [bt].[btAbbrev] ELSE [bt].[btLatinAbbrev]  END) + ': ' + CAST(bu.buNumber AS VARCHAR(100)) 
	FROM   
		#MasterTable AS [res] 
		INNER JOIN [vwbu] AS [bu] ON [res].[GUID] = [bu].[buGuid]  
		INNER JOIN [vwBt] AS [bt] ON [res].[ParentGUID] = [bt].[btGuid]  
	--------------------------------------------------------------
	UPDATE #MasterTable 
	SET 
		[DueDate] = pt.[DueDate]
	FROM 
		#MasterTable m
		INNER JOIN pt000 pt ON pt.RefGuid = m.[GUID]  
	--------------------------------------------------------------
	UPDATE #MasterTable 
	SET 
		-- [DueDate] = b.[DueDate],
		[ChequeDesc] = (CASE @lang WHEN 0 THEN [b].[Name] ELSE (CASE [b].[LatinName] WHEN '' THEN [b].[Name] ELSE [b].[LatinName] END) END) 
			+ ': ' + CAST(b.Number AS VARCHAR(100)) 
	FROM 
		#MasterTable m
		INNER JOIN (SELECT ch.Guid, ch.TypeGuid, ch.DueDate, ch.ParentGuid, ch.Number, nt.Name, nt.LatinName FROM vbch ch INNER JOIN nt000 nt ON ch.TypeGUID = nt.GUID 
					WHERE ch.state = 0 AND ch.ParentGuid <> 0x00 AND DueDate = (SELECT MIN(DueDate) DueDate FROM vbch cc WHERE cc.[State] = 0 AND  cc.ParentGuid = ch.ParentGuid)) b ON b.ParentGuid = m.[Guid]
	--------------------------------------------------------------
	UPDATE #MasterTable 
	SET 
		PaymentGUID = res.[GUID],
		EntryGUID = er.[EntryGUID],
		[BranchGUID] = [py].[BranchGUID],
		[Date] = ISNULL(EN.Date, [py].Date),
		[Type] = et.etGUID,
		[Number] = py.Number,
		[Document] = (CASE @lang WHEN 0 THEN [et].[etAbbrev] ELSE [et].[etLatinAbbrev]  END) + ': ' + CAST(py.Number AS VARCHAR(100)) 
	FROM   
		#MasterTable AS [res] 
		INNER JOIN py000 AS [py] ON [res].[GUID] = [py].[Guid] 
		INNER JOIN er000 AS [er] ON [er].[ParentGUID] = [py].[Guid] 
		INNER JOIN [vwEt] AS [et] ON [res].[ParentGUID] = [et].[etGuid] 
		LEFT JOIN en000 AS EN ON res.enGUID = EN.GUID

	-------------------------------------------  
	UPDATE #MasterTable 
	SET  
		ChequeGUID = res.[GUID],
		[BranchGUID] = [ch].[chBranchGUID],
		[CostGUID]= [ch].[chCost1GUID],
		DueDate = ch.chDueDate,
		[Date] = [ch].chDate,
		[Type] = nt.ntGUID,
		[Number] = ch.chNumber,
		[Document] = (CASE @lang WHEN 0 THEN [nt].[ntAbbrev] ELSE [nt].[ntLatinAbbrev]  END) + ': ' + CAST(ch.chNumber AS VARCHAR(100)) + ': ' +  CAST(ch.chNum AS VARCHAR(100))
	FROM   
		#MasterTable AS [res] 
		INNER JOIN [vwCh] AS [ch] ON [res].[GUID] = [ch].[chGuid] 
		INNER JOIN [vwNt] AS [nt] ON [res].[ParentGUID] = [nt].[ntGuid]  
	-------------------------------------------  
	UPDATE #MasterTable 
	SET  
		EntryGUID = res.[GUID],
		[BranchGUID] = [ce].[ceBranch],
		[Date] = [ce].ceDate,
		[Number] = ce.ceNumber,
		[IsEntry] = 1,
		[Document] = CAST(ce.ceNumber AS VARCHAR(100)) 
	FROM   
		#MasterTable AS [res] 
		INNER JOIN [vwCe] AS [ce] ON [res].[GUID] = [ce].[ceGuid] 
	-------------------------------------------  
	UPDATE #MasterTable 
	SET  
		[IsEntry] = 0,
		[Document] = (CASE @lang WHEN 0 THEN [nt].[ntAbbrev] ELSE [nt].[ntLatinAbbrev]  END) + ': ' + CAST(ch.chNumber AS VARCHAR(100)) + ': ' +  CAST(ch.chNum AS VARCHAR(100))
	FROM   
		#MasterTable AS [res]
		INNER JOIN [vwCe] AS [ce] ON [res].[GUID] = [ce].[ceGuid] 
		INNER JOIN [er000] AS [er] ON [er].[EntryGUID] = [ce].[ceGuid] 
		INNER JOIN [vwCh] AS [ch] ON [er].[ParentGUID] = [ch].[chGuid] 
		INNER JOIN [vwNt] AS [nt] ON [res].[ParentGUID] = [nt].[ntGuid]  
	--------------------------------------------------------------
	UPDATE #MasterTable 
	SET 
		BillGUID = bu.buGUID,
		EntryGUID = bu.ceGUID,
		BranchGUID = bu.buBranch,
		StoreGUID = bu.buStorePtr,
		CostGUID = bu.buCostPtr,
		[Date] = bu.buDate,
		[Type] = bt.btGUID,
		Number = bu.buNumber,
		IsEntry = 0,
		Document = (CASE @lang WHEN 0 THEN bt.btAbbrev ELSE bt.btLatinAbbrev END) + ': ' + CAST(bu.buNumber AS VARCHAR(100))
	FROM   
		#MasterTable AS res 
		INNER JOIN vwBuCe AS bu ON res.BillGUID = bu.buGuid
		INNER JOIN vwBt AS bt ON bu.buType = bt.btGuid
	--------------------------------------------------------------
	ALTER TABLE [#MasterTable]
	ADD [PriorityNum] [INT]

	UPDATE [#MasterTable]
	SET [PriorityNum] = (SELECT [PriorityNum] FROM [#BillTbl] b WHERE [#MasterTable].Type=b.Type)
	
		-------- Customers ---------------------------
	SELECT 
		acc.CustPtr AS ParentGUID,
		ISNULL(acc.CustPtr, 0x0) AS CustomerGUID,
		ac.Guid AS AccGUID, 
		ac.Code AS AccCode, 
		ac.Name AS AccName, 
		ac.LatinName AS AccLatinName,
		CAST((CASE WHEN ABS(acc.[Debit] - acc.[Credit] + acc.[PrevBalance] - acc.RealBalance) > 0.1 THEN 1 ELSE 0 END) AS BIT) AS IsDifferentBalance,
		ISNULL(acc.PrevBalance, 0) AS PrevBalance,
		acc.Debit,
		acc.Credit,
		acc.Discount,
		acc.Extra, 
		acc.UnCollectedChequesBalance,
		acc.SumChecked,
		acc.LastCheckDate,
		acc.SumTransferedCheques,
		acc.LastCheckNote,
		ac.CurrencyGUID AS AccCurrencyGUID,
		my.Code AS AccCurrencyCode,
		CASE @DetailingByCurrencyAccount 
			WHEN 0 THEN my.CurrencyVal
			ELSE [dbo].[fnGetCurVal](ac.CurrencyGUID, @EndDate) 
		END AS AccCurrencyValue
	FROM 
		#Accounts acc 
		INNER JOIN [#CUST1] A on A.NUMBER = acc.CustPtr
		INNER JOIN ac000 ac on ac.Guid = A.AccountGuid
		INNER JOIN my000 my on my.Guid = ac.CurrencyGUID
		--INNER JOIN #MasterTable ma on ma.CustomerGUID = acc.CustPtr 
		LEFT JOIN cu000 cu ON cu.AccountGUID = A.NUMBER 
	---------------------------------------------------------------------------------

	---  Master Table --------------------------------------------------------------

	SELECT 
		m.*,
		r.BuVAT,
		r.BuSalesTax,
		CAST((CASE ISNULL(r.[Checked], 0) WHEN 1 THEN 1 ELSE 0 END) AS BIT) AS [Checked],
		ISNULL(Notes.BNotes, '') AS [BNotes],
		ISNULL(r.[chDir], 0) AS [chDir],
		ISNULL(r.[chState], 0) AS [chState],
		ISNULL(r.[chValue], 0) AS [chValue],
		CASE ISNULL([co].[coCode], '') 
			WHEN '' THEN '' 
			ELSE [co].[coCode] + '-'  + CASE @lang WHEN 0 THEN [co].[coName] ELSE CASE ISNULL([co].[coLatinName], '') WHEN '' THEN [co].[coName] ELSE [co].[coLatinName] END END
		END	AS CostName,
		CASE @lang WHEN 0 THEN ISNULL([br].[Name], '') ELSE CASE ISNULL([br].[LatinName], '') WHEN '' THEN ISNULL([br].[Name], '') ELSE [br].[LatinName] END END AS BranchName,
		'' AS ChecqueState,
		ISNULL(m.[Debit] - m.[Credit], 0) AS MoveBalance,
		CASE @ShowRunningBalance
			WHEN 0 THEN 0.0
			ELSE 
				[acc].[PrevBalance] + SUM(m.[Debit] - m.[Credit]) OVER(PARTITION BY m.CustomerGUID ORDER BY m.Date, m.Number, CASE m.Flag WHEN -1 THEN 6 ELSE m.Flag END, m.Type 
				ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
		END AS [CurrentBalance],
		CASE WHEN parentDoc.Guid IS NULL THEN 
			CASE WHEN ceDoc.Guid IS NULL THEN 0 ELSE 1 END 
		ELSE 1 END  HasDocuments
	FROM 
		#MasterTable m
		OUTER APPLY(SELECT TOP 1 BNotes FROM #Result WHERE ISNULL(enGuid, 0x0) <> 0x0 AND enGuid = m.enGUID) AS Notes
		INNER JOIN (SELECT [GUID], MAX([Checked]) AS [Checked], MAX([chDir]) AS [chDir], 
				MAX([chState]) AS chState, MAX([chValue]) AS [chValue], MAX(BuVAT) AS BuVAT, MAX(BuSalesTax) BuSalesTax
			FROM #Result WHERE [OrderFlag] = 0 GROUP BY [GUID]) r ON r.Guid = m.GUID
		INNER JOIN #Accounts acc ON acc.CustPtr = m.CustomerGUID
		LEFT JOIN vwco co ON co.coGUID = m.[CostGUID]
		LEFT JOIN br000 br ON br.GUID = m.[BranchGUID]
		LEFT JOIN vwObjectRelatedDocument ceDoc ON m.Guid = ceDoc.Guid
        LEFT JOIN vwObjectRelatedDocument parentDoc ON m.ParentGuid = parentDoc.Guid
	WHERE 
		m.Flag != -2
	ORDER BY 
		m.Date, m.PriorityNum, m.Number, CASE m.Flag WHEN -1 THEN 6 ELSE m.Flag END, m.Type
	IF (@ShowDetails <> 0)
	BEGIN 
		SELECT 
			[r].[Guid] AS [BillGUID],
			[mt].[mtGUID] AS [MaterialGUID],
			CASE ISNULL([mt].[mtCode], '') 
				WHEN '' THEN '' 
				ELSE [mt].[mtCode] + '-'  + CASE @lang WHEN 0 THEN [mt].[mtName] ELSE CASE ISNULL([mt].[mtLatinName], '') WHEN '' THEN [mt].[mtName] ELSE [mt].[mtLatinName] END END
			END	AS [MaterialName],
			[r].[Qty] / (CASE @UseUnit
				WHEN 1 THEN 1
				WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
				WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
				ELSE (CASE [r].[Unit] 
						WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
						WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
						ELSE 1
					END) END) AS [Qty],
			[r].[Bonus] / (CASE @UseUnit
				WHEN 1 THEN 1
				WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
				WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
				ELSE (CASE [r].[Unit] 
						WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
						WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
						ELSE 1
					END) END) AS [Bonus],
			(CASE @UseUnit
				WHEN 1 THEN [mt].[mtUnity]
				WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN [mt].[mtUnity] ELSE [mt].[mtUnit2] END)
				WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN [mt].[mtUnity] ELSE [mt].[mtUnit3] END)
				ELSE (CASE [r].[Unit] 
						WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN [mt].[mtUnity] ELSE [mt].[mtUnit2] END)
						WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN [mt].[mtUnity] ELSE [mt].[mtUnit3] END)
						ELSE [mt].[mtUnity]
					END) END) AS [Unit],
			[r].[BiPrice] / 
			(CASE [r].[Unit] 
						WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
						WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
						ELSE 1
					END)
			* (CASE @UseUnit
				WHEN 1 THEN 1
				WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
				WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
				ELSE (CASE [r].[Unit] 
						WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
						WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
						ELSE 1
					END) END) AS [BiPrice],
			
			([r].[Qty] / (CASE @UseUnit
				WHEN 1 THEN 1
				WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
				WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
				ELSE (CASE [r].[Unit] 
						WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
						WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
						ELSE 1
					END) END)) * 
			([r].[BiPrice] / 
			(CASE [r].[Unit] 
						WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
						WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
						ELSE 1
					END)
			* (CASE @UseUnit
				WHEN 1 THEN 1
				WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
				WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
				ELSE (CASE [r].[Unit] 
						WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
						WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
						ELSE 1
					END) END)) AS BiTotalPrice,
			[r].[ClassPtr] AS [ClassPtr],
			CASE [biQty2]
				WHEN 0 THEN (CASE mtUnit2Fact WHEN 0 THEN 0 ELSE [r].[Qty] / mtUnit2Fact END)
				ELSE [biQty2]
			END AS [biQty2],
			[mtUnit2],
			CASE [biQty3]
				WHEN 0 THEN (CASE mtUnit3Fact WHEN 0 THEN 0 ELSE [r].[Qty] / mtUnit3Fact END)
				ELSE [biQty3]
			END AS [biQty3],
			[mtUnit3],
			[Length],
			[Width],
			[Height], 
			[Count],
			[ExpireDate],
			[ProductionDate],
			[CostPtr],
			[BiDiscount] / 
			(CASE [r].[Unit] 
						WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
						WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
						ELSE 1
					END)
			* (CASE @UseUnit
				WHEN 1 THEN 1
				WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
				WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
				ELSE (CASE [r].[Unit] 
						WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
						WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
						ELSE 1
					END) END) AS [BiDiscount],
			[BiExtra] / 
			(CASE [r].[Unit] 
						WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
						WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
						ELSE 1
					END)
			* (CASE @UseUnit
				WHEN 1 THEN 1
				WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
				WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
				ELSE (CASE [r].[Unit] 
						WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
						WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
						ELSE 1
					END) END) AS [BiExtra],
			[BiBonusDisc] / 
			(CASE [r].[Unit] 
						WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
						WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
						ELSE 1
					END)
			* (CASE @UseUnit
				WHEN 1 THEN 1
				WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
				WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
				ELSE (CASE [r].[Unit] 
						WHEN 2 THEN (CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END)
						WHEN 3 THEN (CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END)
						ELSE 1
					END) END) AS [BiBonusDisc],
			CASE ([r].[Qty] * [r].[BiPrice]) WHEN 0 THEN 0 ELSE [BiDiscount] / ([r].[Qty] * [r].[BiPrice]) END AS DiscountRatio,
			CASE ([r].[Qty] * [r].[BiPrice]) WHEN 0 THEN 0 ELSE [BiExtra] / ([r].[Qty] * [r].[BiPrice]) END AS ExtraRatio,
			[r].[Notes],
			[r].[Store] AS [StoreName],
			ISNULL([co].[coGUID], 0x0) AS CostGUID,
			CASE ISNULL([co].[coCode], '') 
				WHEN '' THEN '' 
				ELSE [co].[coCode] + '-'  + CASE @lang WHEN 0 THEN [co].[coName] ELSE CASE ISNULL([co].[coLatinName], '') WHEN '' THEN [co].[coName] ELSE [co].[coLatinName] END END
			END	AS CostName,
			CASE @ShowSerialNumbers WHEN 0 THEN '' ELSE ISNULL(r.SN, '') END AS [SN],
			[BiVAT]
		FROM 
			[#Result] r
			INNER JOIN vwmt mt ON mt.mtGUID = r.MatPtr
			LEFT JOIN vwco co ON co.coGUID = r.[CostPtr]
		WHERE 
			[Flag] > 0 

		IF @ShowDiscExtDet = 1
		BEGIN 
			SELECT 
				[GUID] AS [BillGUID],
				[EntryDebit] AS Debit,
				[EntryCredit] AS Credit,
				[OppAccName] AS [AccName],
				[MatPtr] AS [AccGUID],
				[BNotes] AS [Notes]
			FROM 
				[#Result]
			WHERE 
				[Flag] = 2 AND [OrderFlag] = 1
		END 
	END 

	--  ›’Ì· «·√Ê—«ﬁ «·„«·Ì… «·„” Õﬁ… Õ”» «·√‰„«ÿ 
	IF @IsGroupedByNoteType <> 0
	BEGIN 
		SELECT
			m.CustomerGUID AS AccGUID,
			m.Type AS [TypeGUID],
			SUM([Debit] - [Credit]) AS Value,
			CASE @lang WHEN 0 THEN nt.[Name] ELSE CASE ISNULL([nt].[LatinName], '') WHEN '' THEN [nt].[Name] ELSE [nt].[LatinName] END END AS Name
		FROM 
			#MasterTable m
			INNER JOIN nt000 nt ON nt.GUID = m.[Type]
		WHERE 
			m.Flag = -1 OR m.Flag = -2
		GROUP BY 
			m.CustomerGUID,
			m.Type,
			nt.Name,
			nt.LatinName	
	END 

	IF @ShowDebtAgesPreview = 1 
	BEGIN
		DECLARE @AccountGuid UNIQUEIDENTIFIER 
		SET @AccountGuid = @AccPtr
		IF @CustPtr != 0x0 
			SET @AccountGuid = ISNULL((SELECT TOP 1 accountguid FROM cu000 WHERE [GUID] = @CustPtr), @AccountGuid)
		EXEC [repGetAges_ce] @AccountGuid, @CostGuid, @EndDate, 3, 0, @PeriodsNo, @PeriodLength, @CurPtr, @CurVal, @UserID, 0, 0, @SrcGuid, @CondGuid
	END  
	SELECT * FROM [#SecViol]
###############################################################################
#End
