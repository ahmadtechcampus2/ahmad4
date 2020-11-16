#######################################################################################
CREATE PROCEDURE repCalcBillsTotalVAT
	@StartDate			[DATETIME],			-- Start Date      
	@EndDate			[DATETIME],			-- End Date      
	@SrcTypesGuid		[UNIQUEIDENTIFIER],	-- Entry Sources      
	@CustGuid 			[UNIQUEIDENTIFIER],	--      
	@AccGuid 			[UNIQUEIDENTIFIER],     
	@CurrencyGuid 		[UNIQUEIDENTIFIER],     
	@CurrencyVal 		[FLOAT],     
	@SortType 			[INT],				-- 0 sort by Date , 1 Sort By Cust      
	@ViewZeroVats		[INT],				-- 0 View All 1 = dont view	zero vat  
	@viewNoneZeroVats	[BIT],   
	@ViewGroupByType	[INT],				-- 0 = dont aggr 1 = aggr     
	@ShowUnposted		[BIT],
	@Vendor				[INT],     
	@SalesMan			[INT],   
	@Lang				[BIT] = 0,   
	@Abrev				[BIT] = 0,   
	@CustCondGuid		[UNIQUEIDENTIFIER] = 0x00 ,
	@MatCondGuid		[UNIQUEIDENTIFIER] = 0x00,   
	@VeiwCFlds 			NVARCHAR(max) = '', 	-- New Parameter to check veiwing of Custom Fields	 
	@Co_Guid			[UNIQUEIDENTIFIER] = 0x0,	--New Paramerter To show cost center			    
	@Group				[INT] = 0     
AS     
	SET NOCOUNT ON    
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INTEGER])      
	CREATE TABLE [#BillsTypesTbl] ([TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INT], [UserReadPriceSecurity] [INT],[UnPostedSecurity] [INT])     
	CREATE TABLE [#CustTbl] ([CustGuid] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#MatTbl]( MatGuid [UNIQUEIDENTIFIER] , [mtSecurity] [INT])      
	CREATE TABLE [#CustTbl2] ([CustGuid] [UNIQUEIDENTIFIER], [Security] INT, [CustomerName] NVARCHAR(256)) 
	--Filling temporary tables      
	INSERT INTO [#BillsTypesTbl]EXEC [prcGetBillsTypesList2] @SrcTypesGuid--, @UserGuid     
	INSERT INTO [#CustTbl]	EXEC [prcGetCustsList] @CustGuid, @AccGuid, @CustCondGuid
	INSERT INTO [#MatTbl]	EXEC [prcGetMatsList] 	0x0, 0x0, -1, @MatCondGuid    
	INSERT INTO [#CustTbl2] 
	SELECT 
		[CustGuid],
		[c].[Security],
		CASE @Lang 
			WHEN 0 THEN [CustomerName] 
			ELSE CASE [LatinName] 
					WHEN '' THEN [CustomerName] 
					ELSE [LatinName] 
				END 
		END AS [CustomerName]
	FROM 
		[#CustTbl] AS [c] 
		INNER JOIN [cu000] AS [cu] ON [cu].[Guid] = [CustGuid]
	
	IF @AccGuid = 0x0 AND @CustGuid = 0x0 AND @CustCondGuid = 0x00   
		INSERT INTO [#CustTbl2] SELECT 0x0, 1, ''
		
	CREATE TABLE [#Result](      
		[buDate] 				[DATETIME],     
		[buType]				[UNIQUEIDENTIFIER],     
		[buNumber] 				[FLOAT],     
		[buGUID] 				[UNIQUEIDENTIFIER],     
		[buCustPtr] 			[UNIQUEIDENTIFIER],     
		[buCustName] 			[NVARCHAR](250) COLLATE ARABIC_CI_AI,     
		[buTotal]				[FLOAT],     
		[buVAT]					[FLOAT],     
		[buBillDesc]			[NVARCHAR](250) COLLATE ARABIC_CI_AI,     
		[buTotalDiscount]		[FLOAT],     
		[buTotalExtras]			[FLOAT],     
		[buBillNet]				[FLOAT],     
		[buVatAffectedTotal]	[FLOAT],   
		[buVendor]				[FLOAT],     
		[buSalesMan]			[FLOAT],     
		[buDirection]			[FLOAT],     
		[buSortFlag]			[INT],   
		[Security]				[INT],     
		[UserSecurity] 			[INT],     
		[UserReadPriceSecurity] [INT], 
		[buCostPtr]				[UNIQUEIDENTIFIER],
		[buCostCenterName]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[btBillType]			[INT],
		[btName]				[NVARCHAR](250) COLLATE ARABIC_CI_AI)
	    
	IF (@SortType < 1) OR (@SortType > 5)
		SET @SortType = 1;     
        
	--	CASE WHEN ReadPriceSec >= buSecurity THEN r.buTotal ELSE 0 END AS buTotal,       
	INSERT INTO [#Result]       
	SELECT      
		[r].[buDate],      
		[r].[buType],      
		[r].[buNumber],      
		[r].[buGUID],      
		[r].[buCustPtr],     
		[cu].[CustomerName],      
		CASE WHEN [bt].[UserReadPriceSecurity] >= buSecurity THEN 1 ELSE 0 END * [r].[FixedbuTotal],       
		CASE WHEN [bt].[UserReadPriceSecurity] >= buSecurity THEN 1 ELSE 0 END * SUM([r].[FixedbiVAT]),
		[r].[buNotes],     
		CASE WHEN [bt].[UserReadPriceSecurity] >= buSecurity THEN 1 ELSE 0 END * [r].[FixedbuTotalDisc],     
		CASE WHEN [bt].[UserReadPriceSecurity] >= buSecurity THEN 1 ELSE 0 END * [r].[FixedbuTotalExtra],     
		CASE WHEN [bt].[UserReadPriceSecurity] >= buSecurity THEN 1 ELSE 0 END * [r].[FixedbuTotal],			   
		CASE WHEN [bt].[UserReadPriceSecurity] >= buSecurity THEN 1 ELSE 0 END * 
			SUM(CASE WHEN [r].[biVat] > 0 THEN (
				[r].[FixedbiUnitPrice]  + 
				CASE r.btTaxBeforeExtra WHEN 1 THEN 0 ELSE [r].[FixedbiUnitExtra] END - 
				CASE r.btTaxBeforeDiscount WHEN 1 THEN 0 ELSE r.FixedbiUnitDiscount END) 
					* [r].[biQty]
				END) AS [VatAffectedTotal], 
		[r].[buVendor],     
		[r].[buSalesManPtr],     
		[r].[buDirection],     
		[r].[buSortFlag],   
		[r].[buSecurity],      
		CASE [r].[buIsPosted] WHEN 1 THEN [bt].[UserSecurity] ELSE [UnPostedSecurity] END,
		[bt].[UserReadPriceSecurity], 
		[r].[buCostPtr],
		CASE [r].[buCostPtr] WHEN 0x0 THEN '' ELSE [co].[Name] END AS [buCostCenterName],
		[r].[btBillType],
		[r].[btName]
	FROM       
		[fnExtended_bi_fixed]( @CurrencyGuid) AS [r]
		INNER JOIN [#CustTbl2] AS [cu] ON [r].[buCustPtr] = [cu].[CustGuid]     
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]
		INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGuid]  
		LEFT JOIN [co000] AS [co] ON [r].[buCostPtr] = [co].[GUID]
	WHERE
		[buDate] BETWEEN @StartDate AND @EndDate
		AND ((@ViewZeroVats = 1) OR ((@ViewZeroVats = 0) AND ([biVAT] > 0)))
		AND ((@viewNoneZeroVats = 1) OR ((@viewNoneZeroVats = 0) AND ([biVAT] = 0)))  
		AND ((@Vendor = 0) OR (@Vendor = [r].[buVendor]) )
		AND ((@SalesMan = 0) OR (@Salesman = [r].[buSalesManPtr]))
		AND ((buisposted = 1) OR ((@ShowUnposted = 1) AND (buisposted = 0)))
		AND ( ISNULL(@Co_Guid,0X0) = 0X0 OR ([buCostPtr] = @Co_Guid))
	GROUP BY
		[r].[buDate],      
		[r].[buType],      
		[r].[buNumber],      
		[r].[buGUID],      
		[r].[buCustPtr],     
		[cu].[CustomerName],      
		[r].[FixedbuTotal],   
		[r].[btVatSystem],   
		[r].[FixedbuVAT],       
		[r].[buNotes],     
		[r].[FixedbuTotalDisc],     
		[r].[FixedbuTotalExtra],     
		[r].[FixedbuTotal],			   
		[r].[buVendor],     
		[r].[buSalesManPtr],     
		[r].[buDirection],     
		[r].[buSortFlag],   
		[r].[buSecurity],      
		[bt].[UserSecurity],      
		[bt].[UserReadPriceSecurity],   
		[bt].[UnPostedSecurity],   
		[r].[buIsPosted], 
		[r].[buCostPtr],
		[co].[name],
		[r].[btBillType],
		[r].[btName]
		   
	EXEC [prcCheckSecurity]     
	   
	UPDATE [#Result] 
	SET [buBillNet] = [buTotal] - [buTotalDiscount] + [buTotalExtras] + [buVat]   
	
	DECLARE 
		@Sql NVARCHAR(4000),  
		@CF_Table NVARCHAR(255) --Mapped Table for Custom Fields   
	-------------------------------------------------------------------------------------------------------   
	-- Checked if there are Custom Fields to View  	   
	-------------------------------------------------------------------------------------------------------   
	IF @VeiwCFlds <> ''	    
		SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'bu000')  -- Mapping Table	   
	------------------------------------------------------------------------------------------------------	  
	IF (@Abrev = 0)   
	BEGIN
		IF ( @Group = 0)
		BEGIN    
			SET @Sql = 
				'SELECT 
					[buDate] AS [Date],
					[buType],
					[buNumber],
					[bt].[Abbrev] + '' : '' + convert(nvarchar(255), [buNumber]) AS BillName, 
					[buGUID],
					[buCustPtr],
					[buCustName],
					[buTotal],
					[buVAT],
					[buBillDesc],
					[buTotalDiscount],
					[buTotalExtras],
					[buBillNet],
					ISNULL([buVatAffectedTotal], 0 ) AS [buVatAffectedTotal],
					[buVendor] AS vendor,
					[buSalesMan] AS Sales,
					[buDirection],
					[buCostCenterName],
					[btBillType],
					[btName],
					ISNULL([cu].[Number], 0) As [CustNum],
					ISNULL([cu].[Nationality], '''') As [Nationality],
					ISNULL([cu].[Address], '''') As [Address],
					ISNULL([cu].[Phone1], '''') As [Phone1],
					ISNULL([cu].[Phone2], '''') As [Phone2],
					ISNULL([cu].[Fax], '''') As [Fax],
					ISNULL([cu].[Telex], '''') As [Telex],
					ISNULL([cu].[Notes], '''') As [Notes],
					ISNULL([cu].[DiscRatio], '''') As [DiscRatio],
					ISNULL([cu].[Prefix], '''') As [Prefix],
					ISNULL([cu].[Suffix], '''') As [Suffix],
					ISNULL([cu].[Mobile], '''') As [Mobile],
					ISNULL([cu].[Pager], '''') As [Pager],
					ISNULL([cu].[Email], '''') As [Email],
					ISNULL([cu].[HomePage], '''') As [HomePage],
					ISNULL([cu].[Country], '''') As [Country],
					ISNULL([cu].[City], '''') As [City],
					ISNULL([cu].[Area], '''') As [Area],
					ISNULL([cu].[Street], '''') As [Street],
					ISNULL([cu].[ZipCode], '''') As [ZipCode],
					ISNULL([cu].[POBox], '''') As [POBox],
					ISNULL([cu].[Certificate], '''') As [Certificate],
					ISNULL([cu].[Job], '''') As [Job],
					ISNULL([cu].[JobCategory], '''') As [JobCategory],
					ISNULL([cu].[UserFld1], '''') As [UserFld1],
					ISNULL([cu].[UserFld2], '''') As [UserFld2],
					ISNULL([cu].[UserFld3], '''') As [UserFld3],
					ISNULL([cu].[UserFld4], '''') As [UserFld4],
					ISNULL([cu].[DateOfBirth], '''') As [DateOfBirth],
					ISNULL([cu].[Gender], '''') As [Gender],
					ISNULL([cu].[Hoppies], '''') As [Hobbies],
					ISNULL([cu].[DefPrice], '''') As [DefPrice] '
							IF @VeiwCFlds <> ''  
				SET @Sql = @Sql + @VeiwCFlds  
				
			SET @Sql = @Sql + 
				' FROM [#Result] [r]
				 LEFT JOIN [vexcu] [cu] ON [cu].[GUID] = [r].[buCustPtr]
				 LEFT JOIN [bt000] [bt] ON [r].[buType] = [bt].[GUID] '					 
			IF @VeiwCFlds <> ''  
			BEGIN  
				SET @Sql = @Sql + ' LEFT JOIN ' + @CF_Table + ' ON [r].[buGUID] = ' + @CF_Table + '.Orginal_Guid '		  
			END  
			
			SET @Sql = @Sql + ' ORDER BY '
			SET @Sql = @Sql + 
				CASE @SortType 
					WHEN 1 THEN '[buCustName], [buDate], [buSortFlag], [buNumber], [buCostCenterName] '  
					WHEN 2 THEN '[buDate], [buSortFlag], [buNumber], [buCostCenterName] '
					WHEN 3 THEN '[buVAT], [buDate], [buSortFlag], [buNumber], [buCostCenterName] '
					WHEN 4 THEN '[buCostCenterName], [buCustName], [buDate], [buSortFlag], [buNumber]'
					WHEN 5 THEN '[btBillType], [btName], [buNumber]'
					ELSE '[buDate], [buNumber], [buSortFlag], [buCostPtr] '
				END
			  
			EXECUTE sp_executesql @Sql  
		END
		ELSE
		BEGIN
			SET @Sql = ' SELECT '
			IF  @Group = 1
				SET @Sql = @Sql + '[buCostCenterName], [buCostPtr] '
			ELSE IF  @Group = 2
				SET @Sql = @Sql + 
				'	[buCustPtr],
					[buCustName],
					ISNULL([cu].[Number], 0) As [CustNum],
					ISNULL([cu].[Nationality], '''') As [Nationality],
					ISNULL([cu].[Address], '''') As [Address],
					ISNULL([cu].[Phone1], '''') As [Phone1],
					ISNULL([cu].[Phone2], '''') As [Phone2],
					ISNULL([cu].[Fax], '''') As [Fax],
					ISNULL([cu].[Telex], '''') As [Telex],
					ISNULL([cu].[Notes], '''') As [Notes],
					ISNULL([cu].[DiscRatio], '''') As [DiscRatio],
					ISNULL([cu].[Prefix], '''') As [Prefix],
					ISNULL([cu].[Suffix], '''') As [Suffix],
					ISNULL([cu].[Mobile], '''') As [Mobile],
					ISNULL([cu].[Pager], '''') As [Pager],
					ISNULL([cu].[Email], '''') As [Email],
					ISNULL([cu].[HomePage], '''') As [HomePage],
					ISNULL([cu].[Country], '''') As [Country],
					ISNULL([cu].[City], '''') As [City],
					ISNULL([cu].[Area], '''') As [Area],
					ISNULL([cu].[Street], '''') As [Street],
					ISNULL([cu].[ZipCode], '''') As [ZipCode],
					ISNULL([cu].[POBox], '''') As [POBox],
					ISNULL([cu].[Certificate], '''') As [Certificate],
					ISNULL([cu].[Job], '''') As [Job],
					ISNULL([cu].[JobCategory], '''') As [JobCategory],
					ISNULL([cu].[UserFld1], '''') As [UserFld1],
					ISNULL([cu].[UserFld2], '''') As [UserFld2],
					ISNULL([cu].[UserFld3], '''') As [UserFld3],
					ISNULL([cu].[UserFld4], '''') As [UserFld4],
					ISNULL([cu].[DateOfBirth], '''') As [DateOfBirth],
					ISNULL([cu].[Gender], '''') As [Gender],
					ISNULL([cu].[Hoppies], '''') As [Hobbies],
					ISNULL([cu].[DefPrice], '''') As [DefPrice] '
			ELSE
				SET @Sql = @Sql + '[buDate]'				
			SET @Sql = @Sql + 
				'	,SUM([buTotal]) [buTotal],
					SUM([buVAT]) [buVAT],
					SUM([buTotalDiscount]) [buTotalDiscount],
					SUM([buTotalExtras]) [buTotalExtras],
					SUM([buBillNet]) [buBillNet],
					SUM([buVatAffectedTotal]) [buVatAffectedTotal],
					[buDirection]'
			SET @Sql = @Sql + 
			'	FROM 
					[#Result] [r] 
					LEFT JOIN [vexcu] [cu] ON [cu].[GUID] = [r].[buCustPtr]
				GROUP BY 
					[buDirection],'
			IF  @Group = 1
				SET @Sql = @Sql + '[buCostCenterName], [buCostPtr] '
			ELSE IF  @Group = 2
				SET @Sql = @Sql + 
				'	[buCustPtr],
					[buCustName],
					[cu].[Number],
					[cu].[Nationality],
					[cu].[Address],
					[cu].[Phone1],
					[cu].[Phone2],
					[cu].[Fax],
					[cu].[Telex],
					[cu].[Notes],
					[cu].[DiscRatio],
					[cu].[Prefix],
					[cu].[Suffix],
					[cu].[Mobile],
					[cu].[Pager],
					[cu].[Email],
					[cu].[HomePage],
					[cu].[Country],
					[cu].[City],
					[cu].[Area],
					[cu].[Street],
					[cu].[ZipCode],
					[cu].[POBox],
					[cu].[Certificate],
					[cu].[Job],
					[cu].[JobCategory],
					[cu].[UserFld1],
					[cu].[UserFld2],
					[cu].[UserFld3],
					[cu].[UserFld4],
					[cu].[DateOfBirth],
					[cu].[Gender],
					[cu].[Hoppies],
					[cu].[DefPrice]'
			ELSE
				SET @Sql = @Sql + '[buDate]'
			SET @Sql = @Sql + ' ORDER BY '
			IF  @Group = 1
				SET @Sql = @Sql + '[buCostCenterName], [buCostPtr] '
			ELSE IF  @Group = 2
				SET @Sql = @Sql + 
				'	[buCustPtr],
					[buCustName],
					[cu].[Number],
					[cu].[Nationality],
					[cu].[Address],
					[cu].[Phone1],
					[cu].[Phone2],
					[cu].[Fax],
					[cu].[Telex],
					[cu].[Notes],
					[cu].[DiscRatio],
					[cu].[Prefix],
					[cu].[Suffix],
					[cu].[Mobile],
					[cu].[Pager],
					[cu].[Email],
					[cu].[HomePage],
					[cu].[Country],
					[cu].[City],
					[cu].[Area],
					[cu].[Street],
					[cu].[ZipCode],
					[cu].[POBox],
					[cu].[Certificate],
					[cu].[Job],
					[cu].[JobCategory],
					[cu].[UserFld1],
					[cu].[UserFld2],
					[cu].[UserFld3],
					[cu].[UserFld4],
					[cu].[DateOfBirth],
					[cu].[Gender],
					[cu].[Hoppies],
					[cu].[DefPrice]'
			ELSE
				SET @Sql = @Sql + '[buDate]'
			EXECUTE sp_executesql @Sql  		     
		END
	END   
	ELSE  
	BEGIN    
		SET @Sql = 
		'	SELECT 
				SUM([buTotal]) AS [buTotal],
				SUM([buVAT]) AS [buVAT],
				SUM([buTotalDiscount]) AS [buTotalDiscount],
				SUM([buTotalExtras]) AS [buTotalExtras],
				SUM([buBillNet]) AS [buBillNet],
				SUM([buVatAffectedTotal]) AS [buVatAffectedTotal],
				[buDirection] '   
		IF @VeiwCFlds <> ''  
			SET @Sql = @Sql + @VeiwCFlds  
		SET @Sql = @Sql + ' FROM [#Result] [r] '  
		IF @VeiwCFlds <> ''  
			SET @Sql = @Sql + ' LEFT JOIN ' + @CF_Table + ' ON [r].[buGUID] = ' + @CF_Table + '.Orginal_Guid '
		SET @Sql = @Sql + ' GROUP BY [buDirection] '  
		IF @VeiwCFlds <> ''  
			SET @Sql = @Sql + @VeiwCFlds  
		EXECUTE sp_executesql @Sql  
	END  
	IF (@ViewGroupByType = 1)     
	BEGIN     
		SELECT       
			[buType],     
			SUM([buTotal]) as [buBillsTotal],       
			SUM([buVAT]) as [buBillsVAT],     
			SUM([buTotalDiscount]) as [buBillsDisc],     
			SUM([buTotalExtras]) as [buBillsExtra],     
			SUM([buBillNet]) as [buBillNet],   
			SUM([buVatAffectedTotal]) as [BuBillsVatAffectedTotal]     
		 	     
		FROM 
			[#Result]       
		GROUP BY      
			[buType]      
	END 
	    
	SELECT * FROM [#SecViol]    
/*
	prcConnections_add2 '„œÌ—'
	exec [repCalcBillsTotalVAT] '11/1/2004 0:0:0.0', '12/31/2004 23:59:59.998', 'da2ac588-996d-469b-824e-0b88f562e421', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '04b7552d-3d32-47db-b041-50119e80dd52', 1.000000, 1, 1, 0, 0, 0, 0, 0, '00000000-0000-0000-0000-000000000000', '', '00000000-0000-0000-0000-000000000000', 1
*/
################################################################################
#END