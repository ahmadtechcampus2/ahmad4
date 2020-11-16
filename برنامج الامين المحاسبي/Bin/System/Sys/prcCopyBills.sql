##################################
CREATE PROCEDURE prcCopyBills
	@SourceTypGuid      	UNIQUEIDENTIFIER, 
    @DistTypGuid        	UNIQUEIDENTIFIER, 
    @FromND             	BIT, 
    @StartDate          	DATETIME, 
    @EndDate            	DATETIME, 
    @From               	INT, 
    @To                 	INT, 
    @Acc                	UNIQUEIDENTIFIER, 
    @Customer           	UNIQUEIDENTIFIER, 
    @Store              	UNIQUEIDENTIFIER, 
    @CustCondGuid       	UNIQUEIDENTIFIER, 
    @MatCondGuid        	UNIQUEIDENTIFIER = 0x00, 
    @Cost               	UNIQUEIDENTIFIER = 0X00, 
    @GrpGuid            	UNIQUEIDENTIFIER = 0X00, 
    @Pay                	[INT] = -1,--0 CASH 1 LATER -1 LATER cASH 
    @NotesContain       	[NVARCHAR](256) = '',-- NULL or Contain Text  
    @NotesNotContain    	[NVARCHAR](256) = '', -- NULL or Not Contain  
    @BillCondGuid       	UNIQUEIDENTIFIER = 0X00, 
    @CostFlag           	INT = 0, 
    @Post               	INT = 1, -- 0 UNPOSTED, 1 POSTED 
    @Continue           	[INT] = 0, 
    @DeleteOldBill      	[BIT] = 0, 
    @SrcBillGuid        	UNIQUEIDENTIFIER = 0X00 ,
	@ShowBillsWithoutCust	BIT = 0
AS 
	SET NOCOUNT ON 
	DECLARE  
		@Guid               UNIQUEIDENTIFIER, 
		@BtName             NVARCHAR(256), 
		@UserGuid           UNIQUEIDENTIFIER, 
		@Sql                NVARCHAR(max), 
		@Criteria           NVARCHAR(max), 
		@CurrencyPtr        UNIQUEIDENTIFIER
		
        SET @UserGuid = [dbo].[fnGetCurrentUserGUID]() 
        
        DECLARE @VATTYPSRC   INT
        DECLARE @VATTYPDIST INT
		
        SET @VATTYPSRC = (SELECT bt.VATSystem FROM bt000 bt WHERE bt.[GUID] = @SourceTypGuid) 
        SET @VATTYPDIST = (SELECT bt.VATSystem FROM bt000 bt WHERE bt.[GUID] = @DistTypGuid)
 

        CREATE TABLE [#Mat](  
			[mtGUID] [UNIQUEIDENTIFIER],  
			[mtSecurity] [INT]) 
			
        CREATE TABLE #BillCond( 
            buGuid UNIQUEIDENTIFIER, 
            biGuid UNIQUEIDENTIFIER) 

        CREATE TABLE [#Cost]( [Number] [UNIQUEIDENTIFIER]) 

        CREATE TABLE [#Store](  
            [Number] [UNIQUEIDENTIFIER], 
            [Security] INT) 
            
        CREATE TABLE [#Cust](  
            [Number] [UNIQUEIDENTIFIER],  
            [Sec] [INT])  
             
        IF (@MatCondGuid <> 0X00 OR @GrpGuid <> 0X00) 
			INSERT INTO [#Mat] EXEC [prcGetMatsList]  NULL, @GrpGuid,-1, @MatCondGuid  
             
		INSERT INTO  [#Cost]  
		SELECT [GUID] FROM [fnGetCostsList]( @Cost) 
		
		IF @Cost = 0x00 
			INSERT INTO [#Cost] VALUES( 0X00) 
             
        CREATE TABLE #Bill( 
			[TypeGuid]		  UNIQUEIDENTIFIER,
			[Security]		  INT, 
            [Guid]			  UNIQUEIDENTIFIER, 
            [Number]		  FLOAT, 
            [CustGuid]		  UNIQUEIDENTIFIER, 
            [ContraBill]	  UNIQUEIDENTIFIER, 
            [CurrencyGUID]	  UNIQUEIDENTIFIER, 
            [StoreGUID]		  UNIQUEIDENTIFIER, 
            [CustAcc]		  UNIQUEIDENTIFIER, 
            [Branch]		  UNIQUEIDENTIFIER, 
            [CurrencyVal]	  FLOAT, 
            [customername]	  [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
			[customerLname]	  [NVARCHAR](250) COLLATE ARABIC_CI_AI, 	
            [Date]            [DATETIME], 
            [CostGUID]		  UNIQUEIDENTIFIER, 
            [State]			  [BIT] DEFAULT 0, 
            [PayType]		  [INT], 
            [IsPosted]		  [INT],
			[Vendor]		  [FLOAT],
			[SalesManPtr]	  [FLOAT],
			[TextFld1]		  [NVARCHAR](100) COLLATE ARABIC_CI_AI,
			[TextFld2]		  [NVARCHAR](100) COLLATE ARABIC_CI_AI,
			[TextFld3]		  [NVARCHAR](100) COLLATE ARABIC_CI_AI,
			[TextFld4]		  [NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[bIsInput]		  [BIT],
			[Notes]			  [NVARCHAR](250) COLLATE ARABIC_CI_AI
			)
			
        CREATE TABLE [#NewBi]( 
            [Number]	  [INT], 
            [Qty]		  [float], 
            [Unity]		  [float], 
            [Price]		  [float], 
            [BonusQnt]	  [float], 
            [Discount]	  [float], 
            [BonusDisc]   [float] , 
            [Extra]		  [float] , 
            [CurrencyVal] [float] , 
            [Notes]       [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
            [Qty2]        [float], 
            [Qty3]        [float], 
            [ClassPtr]    [NVARCHAR](250), 
            [ExpireDate]  [datetime], 
            [ProductionDate]  [datetime], 
            [Length]      [float] NULL DEFAULT (0), 
            [Width]       [float] NULL DEFAULT (0), 
            [Height]      [float] NULL DEFAULT (0), 
            [GUID]        [uniqueidentifier] /*ROWGUIDCOL */ NOT NULL DEFAULT (newid()), -- ROWGUIDCOL not supported in Azure
            [VAT]         [float] NULL DEFAULT (0), 
            [ParentGUID]  [uniqueidentifier] , 
            [MatGUID]     [uniqueidentifier]  , 
            [CurrencyGUID]  [uniqueidentifier], 
            [StoreGUID]     [uniqueidentifier], 
            [CostGUID]      [uniqueidentifier], 
            [Count]         [float],
			[VatRatio]	    [float] DEFAULT 0) 
			
            CREATE TABLE [#NewDi] 
            ( 
				[Number]    [INT] IDENTITY(1,1), 
				[Discount]  [FLOAT] , 
				[Extra]     [float], 
				[CurrencyVal]  [float], 
				[Notes]  [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
				[Flag]   [int]  DEFAULT (0), 
				[GUID]   [uniqueidentifier] DEFAULT newid() , 
				[ClassPtr]     [NVARCHAR](250), 
				[ParentGUID]   [uniqueidentifier] , 
				[AccountGUID]  [uniqueidentifier], 
				[CurrencyGUID] [uniqueidentifier], 
				[CostGUID]     [uniqueidentifier], 
				[ContraAccGUID] [uniqueidentifier] 
            ) 
            
            CREATE TABLE [#BillCopied] 
            ( 
                        [Id] [int]       IDENTITY(1,1), 
                        [CopiedGUID]     [uniqueidentifier], 
                        [NewCopiedGUID]  [uniqueidentifier] 
            ) 
            
            CREATE TABLE [#Part] 
            ( 
                        [GUID]  [uniqueidentifier] 
            )  
             
            INSERT INTO [#Cust]  
            EXEC [prcGetCustsList]  @Customer, @Acc, @CustCondGuid 
             
            INSERT INTO [#Store] 
            EXEC [prcGetStoresList] @Store 
             
            IF @Store = 0x00 
            INSERT INTO [#Store]        VALUES(0X00, 0) 
            
		    SELECT  [c].[Number], 
				    [Sec],ACCOUNTGUID,
				    [customername],
				    [LatinName]  
            INTO  [#Cust2]  
            FROM  [#Cust] [c] INNER JOIN [cu000] [cu]ON [cu].[Guid] = [c].[Number] 
            
            SELECT @BtName = Name  
            FROM   [bt000]  
            WHERE  GUID = @SourceTypGuid 
                         
            SET @Sql = 'INSERT INTO #Bill ([TypeGuid], [Security], [Guid], [CustGuid], [CurrencyGUID], [StoreGUID], [CustAcc], [Branch], [Number], [customername], [customerLname], [Date], [CurrencyVal], [CostGuid], [PayType], [IsPosted], [Vendor], [SalesManPtr], [TextFld1], [TextFld2], [TextFld3], [TextFld4], [bIsInput], [Notes]) 
            SELECT ' 
            IF ((@CostFlag & 0X00002) > 0) 
                        SET @Sql = @Sql +' DISTINCT ' 
                        
		    Declare @LeftOrInner NVARCHAR(10)
		    IF (@ShowBillsWithoutCust > 0)
		 	    SET @LeftOrInner = ' LEFT '
		    ELSE
			    SET @LeftOrInner = ' INNER '

            SET @Sql = @Sql + '[bu].[TypeGuid], [bu].[Security], [bu].[Guid], [bu].[CustGuid], [bu].[CurrencyGUID], [bu].[StoreGUID], [bu].CustAccGuid, [Branch], [bu].[Number], [cust_name], [cu].[LatinName], [Date], [bu].[CurrencyVal], [bu].[CostGuid], [PayType], [bu].[IsPosted],
							   [bu].[Vendor], [bu].[SalesManPtr], bu.[TextFld1], [bu].[TextFld2], [bu].[TextFld3], [bu].[TextFld4], [bt].[bIsInput], [bu].[Notes]
							   FROM [vbbu] [bu] ' + @LeftOrInner + ' JOIN [#Cust2] [cu] ON [bu].[CustGuid] = [cu].[Number]' + CHAR(13) 
							   
            IF ((@CostFlag & 0X00001) > 0) 
                        SET @Sql = @Sql + 'INNER JOIN [#Cost] co ON co.[Number] = bu.CostGuid ' 
            IF ((@CostFlag & 0X00002) > 0) 
                        SET @Sql = @Sql + ' INNER JOIN bi000 bi ON bu.Guid = bi.ParentGuid INNER JOIN  [#Cost] co2 ON [bi].[CostGUID] = co2.[Number]' 
            IF (@Store <> 0X00) 
                        SET @Sql = @Sql + ' INNER JOIN [#Store] st ON st.[Guid] = bu.StoreGuid' + CHAR(13) 
			SET @Sql = @Sql + ' INNER JOIN bt000 bt ON bt.Guid = bu.TypeGuid' + CHAR(13)			
            SET @Sql = @Sql + 'WHERE [TypeGuid] = ''' + CAST(@SourceTypGuid AS NVARCHAR(36)) + '''' 
            
		    IF (@ShowBillsWithoutCust > 0)
		    BEGIN
			    IF (@Customer <> 0x00)
				    SET @Sql = @Sql + ' AND [CustGuid] = ''' + CAST(@Customer AS NVARCHAR(36)) + ''' '
			    IF (@Acc <> 0x00)
				    SET @Sql = @Sql + ' AND [AccountGuid] = ''' + CAST(@Acc AS NVARCHAR(36)) + ''' '
		    END
	
            IF @Pay <> -1  
                        SET @Sql = @Sql + ' AND ([PayType] = ' + CAST(@Pay AS NVARCHAR(25)) + ') '  
            IF @FromND = 0 
                        SET @Sql = @Sql + ' AND ([Date] BETWEEN ' + [dbo].[fnDateString](@StartDate) + ' AND ' + [dbo].[fnDateString](@EndDate) + ')' + CHAR(13) 
            IF @FromND = 1 
                        SET @Sql = @Sql + ' AND ([bu].[number] BETWEEN ' + cast (@From AS NVARCHAR(20)) + ' AND ' + CAST (@To AS NVARCHAR (20)) + ')' + CHAR(13) 
            IF @NotesContain <>  '' 
			    SET @Sql = @Sql + ' AND ([bu].[Notes] LIKE ''%'+  @NotesContain + '%'')' + CHAR(13) 
		    IF @NotesNotContain <> '' 
			    SET @Sql = @Sql + ' AND ([bu].[Notes] NOT LIKE ''%' +  @NotesNotContain + '%'')' 
			    
            EXEC(@Sql) 
		    UPDATE n SET [VatRatio] =( CASE WHEN ((n.[Qty]* n.[Price]) ) = 0 THEN 0 ELSE   n.Vat/((n.[Qty]* n.[Price])/CASE N.UNITY WHEN 2 THEN Unit2Fact WHEN 3 THEN Unit3Fact ELSE 1 END - [Discount] + [Extra]) END )* 100 from [#NewBi] n inner join mt000 m on m.guid = n.matguid where n.Vat > 0
			
            
            IF @MatCondGuid <> 0X00 OR @GrpGuid <> 0X00 
                        DELETE b FROM #Bill b LEFT JOIN (SELECT DISTINCT A.GUID FROM #Bill A LEFT JOIN [bi000] b ON b.ParentGuid = A.Guid INNER JOIN [#Mat] C ON [mtGUID] = b.[MatGuid]) d ON d.[Guid] = b.Guid WHERE d.[Guid] IS NULL 
            IF @BillCondGuid <> 0X00 
            BEGIN 
                        SET @Sql = 'INSERT INTO #BillCond SELECT [buGuid],[biGuid] FROM vwBuBi_Address a INNER JOIN #Bill b ON b.Guid = [buGuid]' 
                        select @CurrencyPtr = Guid FROM my000 WHERE Number = 1 
                        SET @Criteria = [dbo].[fnGetBillConditionStr]( NULL,@BillCondGuid,@CurrencyPtr) 
                        IF @Criteria <> '' 
                                    SET @Criteria = ' WHERE (' + @Criteria + ')' 
                        SET @Sql = @Sql + @Criteria 
                        EXEC(@Sql) 
                                    DELETE B FROM #Bill b LEFT JOIN #BillCond ON b.Guid = buGuid  WHERE buGuid IS NULL 
            END 
            IF @Continue = 0 
            BEGIN 
					IF ((dbo.fnConnections_GetLanguage() = 1) or (dbo.fnConnections_GetLanguage() = 2))
					Begin
                        SELECT [b].[Guid],[b].[Number],[b].[CustGuid],[CustomerLname] as customername, [bu].[Date],[bu].[Number] AS  [ContraNumber], [bt].[LatinName] AS [btName]  
                        FROM  [#Bill] [b] INNER JOIN  [BU000] [bu] ON [bu].[Guid] = [b].[Guid] 
                        INNER JOIN [bt000] [bt] ON [bt].[Guid] = [bu].[TypeGuid] 
					    WHERE [dbo].[fnGetUserBillSec_Browse]([dbo].[fnGetCurrentUserGUID](), [bu].[TypeGuid]) >= [bu].[Security]
                        ORDER BY [customername],[bu].[Date] 
                         
                        SELECT [f].[Guid], [f].[Number], [f].[CustGuid],[CustomerLname] as customername, [bu].[Date],[NewCopiedGuid] [ContraBill],[bu].[Number] AS  [ContraNumber], [bt].[LatinName] AS [btName]  
                        FROM  #Bill f INNER JOIN BillCopied000 B ON f.Guid = [CopiedGUID] INNER JOIN  [BU000] [bu] ON [bu].[Guid] = [NewCopiedGuid] 
                        INNER JOIN [bt000] [bt] ON [bt].[Guid] = [bu].[TypeGuid] 
					    WHERE [dbo].[fnGetUserBillSec_Browse]([dbo].[fnGetCurrentUserGUID](), [bu].[TypeGuid]) >= [bu].[Security]
                        ORDER BY [customername],[bu].[Date],[bu].[Number] 
					END
					ELSE
					Begin
						SELECT [b].[Guid],[b].[Number],[b].[CustGuid],[Customername], [bu].[Date],[bu].[Number] AS  [ContraNumber],[bt].[Name] AS [btName]
                        FROM  [#Bill] [b] INNER JOIN  [BU000] [bu] ON [bu].[Guid] = [b].[Guid] 
                        INNER JOIN [bt000] [bt] ON [bt].[Guid] = [bu].[TypeGuid] 
					    WHERE [dbo].[fnGetUserBillSec_Browse]([dbo].[fnGetCurrentUserGUID](), [bu].[TypeGuid]) >= [bu].[Security]
                        ORDER BY [customername],[bu].[Date] 
                         
                        SELECT [f].[Guid], [f].[Number], [f].[CustGuid],[customername], [bu].[Date],[NewCopiedGuid] [ContraBill],[bu].[Number] AS  [ContraNumber],[bt].[Name] AS [btName]
                        FROM  #Bill f INNER JOIN BillCopied000 B ON f.Guid = [CopiedGUID] INNER JOIN  [BU000] [bu] ON [bu].[Guid] = [NewCopiedGuid] 
                        INNER JOIN [bt000] [bt] ON [bt].[Guid] = [bu].[TypeGuid] 
					    WHERE [dbo].[fnGetUserBillSec_Browse]([dbo].[fnGetCurrentUserGUID](), [bu].[TypeGuid]) >= [bu].[Security]
                        ORDER BY [customername],[bu].[Date],[bu].[Number] 
					END       
                    RETURN                                                                     
				
            END 
            
            BEGIN TRAN 
            
            IF @Continue = 1 
                        DELETE A FROM #Bill A INNER JOIN BillCopied000 B ON a.Guid = [CopiedGUID] 
                                                                                                INNER JOIN [bu000] c ON c.Guid = [NewCopiedGUID] 
            DELETE #Bill WHERE [Guid] NOT IN (SELECT IdType FROM dbo.RepSrcs WHERE IdTbl =  @SrcBillGuid) 
            
		    UPDATE #Bill SET [ContraBill] = NEWID()
            INSERT INTO [#BillCopied]([CopiedGUID] ,[NewCopiedGUID]) SELECT   [Guid],[ContraBill] FROM #Bill 

		    DECLARE @Cnt INT 
            SELECT @Cnt = MAX([ID]) FROM  [BillCopied000] 
            IF @Cnt IS NULL 
                    SET @Cnt = 0 
             
            CREATE TABLE [#BU] 
            ( 
                        [Number] [INT] IDENTITY(1,1), 
                        [Date]            [DATETIME], 
                        [CurrencyVal] [FLOAT], 
                        [Notes] [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
                        [Branch] [uniqueidentifier], 
                        [GUID] [uniqueidentifier], 
                        [TypeGUID] [uniqueidentifier], 
                        [CustGUID] [uniqueidentifier], 
                        [CurrencyGUID] [uniqueidentifier], 
                        [StoreGUID] [uniqueidentifier], 
                        [CustAccGUID] [uniqueidentifier], 
                        [customername] [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
						[CostGUID] [uniqueidentifier], 
                        [PayType][INT], 
                        [IsPosted] [INT],
						[Vendor] [FLOAT],
						[SalesManPtr] [FLOAT],
						[TextFld1] [NVARCHAR](100) COLLATE ARABIC_CI_AI,
						[TextFld2] [NVARCHAR](100) COLLATE ARABIC_CI_AI,
						[TextFld3] [NVARCHAR](100) COLLATE ARABIC_CI_AI,
						[TextFld4] [NVARCHAR](250) COLLATE ARABIC_CI_AI
            )  
            
            SET @Sql = 'INSERT INTO [#NewBi] ([Number], [Qty],[Unity],[Price],[Discount],[BonusDisc],[BonusQnt],[Extra],[Notes],[CurrencyVal], 
            [Qty2],[Qty3],[ClassPtr],[ExpireDate],[ProductionDate],Length,Width,Height,VAT,ParentGUID,MatGUID,[CurrencyGUID],[StoreGUID],CostGUID,[Count], [VatRatio]) 
            SELECT bi.Number, Qty,Unity, Price, Discount, BonusDisc, BonusQnt, Extra, [bi].Notes, bi.CurrencyVal, 
            Qty2, Qty3, ClassPtr, ExpireDate, ProductionDate, Length, Width, Height, VAT, ContraBill, bi.MatGUID, bi.CurrencyGUID, bi.StoreGUID, bi.CostGUID, Count, bi.VatRatio 
            FROM [bi000] [bi] INNER JOIN #Bill [bu] ON [bu].[Guid] = [bi].[ParentGUID]' + CHAR(13) 
            IF @BillCondGuid <> 0X00 
                        SET @Sql = @Sql + ' INNER JOIN #BillCond ON [bi].Guid = biGuid ' 
            IF ((@CostFlag & 0X00002) > 0) 
                        SET @Sql = @Sql + ' INNER JOIN  [#Cost] co ON [bi].[CostGUID] = co.[Number]' 
            EXEC(@Sql) 
			
		    INSERT INTO BillCopied000 ( [ID],[CopiedGUID] ,[NewCopiedGUID] )
		    SELECT @Cnt+ [ID],[CopiedGUID] ,[NewCopiedGUID] FROM [#BillCopied] 

            IF @MatCondGuid <> 0X00 OR @GrpGuid <> 0X00 
                        DELETE b FROM  [#NewBi] b LEFT JOIN [#Mat] ON  [MatGuid] = [MtGuid] WHERE [MtGuid] IS NULL 
			
            IF @MatCondGuid = 0X00 AND @GrpGuid = 0X00 
                        INSERT INTO [#NewDi]([Discount], [Extra], [CurrencyVal], [Notes], [Flag], [ClassPtr], [ParentGUID], [AccountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID]) 
                        SELECT [Discount], [Extra], [bi].[CurrencyVal], [bi].[Notes], [Flag], [ClassPtr], [ContraBill], [AccountGUID], [bi].[CurrencyGUID], [bi].[CostGUID], [ContraAccGUID] 
                        FROM [di000] [bi] INNER JOIN #Bill [bu] ON [bu].[Guid] = [bi].[ParentGUID] 
	
			IF (dbo.fnConnections_GetLanguage() = 1)
			BEGIN
				INSERT INTO[#BU]( [Date], CurrencyVal, Notes, Branch, GUID, TypeGUID, CustGUID, CurrencyGUID, StoreGUID, [CustAccGUID], [customername], [CostGUID], [PayType], [IsPosted], [Vendor], [SalesManPtr], [TextFld1], [TextFld2], [TextFld3], [TextFld4])
                SELECT [dbo].[fnGetDateFromDT]( [Date]), CurrencyVal, ISNULL (Notes, '') + '(Bill Copied from ' + @BtName + '' + cast ([Number] AS NVARCHAR (24))+ ')', [Branch], [ContraBill], @DistTypGuid, CustGUID, CurrencyGUID, StoreGUID, [CustAcc], [customerLname], [CostGUID], [PayType], [IsPosted] , [Vendor], [SalesManPtr], [TextFld1], [TextFld2], [TextFld3], [TextFld4]
                FROM #Bill  
			END
			ELSE IF (dbo.fnConnections_GetLanguage() = 2)
			BEGIN
				INSERT INTO[#BU]( [Date], CurrencyVal, Notes, Branch, GUID, TypeGUID, CustGUID, CurrencyGUID, StoreGUID, [CustAccGUID], [customername], [CostGUID], [PayType], [IsPosted], [Vendor], [SalesManPtr], [TextFld1], [TextFld2], [TextFld3], [TextFld4]) 
				SELECT [dbo].[fnGetDateFromDT]( [Date]), CurrencyVal, ISNULL (Notes, '') + '(Facture copiÈe de ' + @BtName + '' + cast ([Number] AS NVARCHAR (24))+ ')', [Branch], [ContraBill], @DistTypGuid, CustGUID, CurrencyGUID, StoreGUID, [CustAcc], [customerLname], [CostGUID], [PayType], [IsPosted] , [Vendor], [SalesManPtr], [TextFld1], [TextFld2], [TextFld3], [TextFld4]
                FROM #Bill  
			END
			ELSE 
			BEGIN	 
				INSERT INTO[#BU]( [Date], CurrencyVal, Notes, Branch, GUID, TypeGUID, CustGUID, CurrencyGUID, StoreGUID, [CustAccGUID], [customername], [CostGUID], [PayType], [IsPosted], [Vendor], [SalesManPtr], [TextFld1], [TextFld2], [TextFld3], [TextFld4]) 
                SELECT [dbo].[fnGetDateFromDT]( [Date]), CurrencyVal, ISNULL (Notes, '') + '(›« Ê—… „‰”ÊŒ… „‰ ' + @BtName + '' + cast ([Number] AS NVARCHAR (24)) + ')', [Branch], [ContraBill], @DistTypGuid, CustGUID, CurrencyGUID, StoreGUID, [CustAcc], [customername], [CostGUID], [PayType], [IsPosted] , [Vendor], [SalesManPtr], [TextFld1], [TextFld2], [TextFld3], [TextFld4]
                FROM #Bill  
			END		 
                                     
            SELECT ISNULL([maxNum],0)- MIN(b.Number)  AS [MAXUMBER], b.[Branch] 
            INTO [#BN] 
            FROM [#bu] B INNER JOIN  
                        (SELECT MAX(b2.[NUMBER]) + 1 AS [maxNum], [Branch] FROM [bu000] b2 WHERE b2.TypeGUID = @DistTypGuid group by  b2.[Branch]) b4 ON b.[Branch] = b4.[Branch] 
            GROUP BY [maxNum], b.[Branch] 
            INSERT INTO bu000 ([PayTYpe],[Number],[Date],CurrencyVal,Notes,Branch,GUID,TypeGUID,CustGUID,CurrencyGUID,StoreGUID,CustAccGUID,[Cust_Name],[UserGuid],[Security],[CostGUID], [Vendor], [SalesManPtr], [TextFld1], [TextFld2], [TextFld3], [TextFld4]) 
            SELECT [PayType],ISNULL([MAXUMBER],0) + [B].[Number],[Date],CurrencyVal,[b].Notes,[b].[Branch],[GUID],TypeGUID,CustGUID,CurrencyGUID,StoreGUID,CustAccGUID,customername,@UserGuid,1,[CostGUID], [Vendor], [SalesManPtr], [TextFld1], [TextFld2], [TextFld3], [TextFld4]
            FROM [#bu] b LEFT JOIN [#BN] bn ON b.Branch =  bn.Branch 
    
    
             IF (@VATTYPDIST = 0)AND  (@VATTYPSRC <> 0)
             BEGIN
				UPDATE [#NewBi] SET Price = Price + (VAT/ Qty) WHERE [VatRatio] > 0 AND Qty > 0
				UPDATE [#NewBi] SET VAT =0, [VatRatio] = 0 WHERE [VatRatio] > 0 AND Qty > 0
             END
   
           
				
            INSERT INTO [bi000] 
            ( 
                        [Number],[Qty],[Unity],[Price],[BonusQnt],[Discount],[BonusDisc] ,[Extra] ,[CurrencyVal], 
                        [Notes],[Qty2],[Qty3], 
                        [ClassPtr],[ExpireDate], 
                        [ProductionDate],[Length],[Width],[Height], 
                        [GUID],[VAT],[ParentGUID],[MatGUID],[CurrencyGUID],[StoreGUID],[CostGUID],[Count], [VatRatio] 
            ) 
            SELECT * FROM [#NewBi] 
    
            INSERT INTO di000([Number],[Discount],[Extra],[CurrencyVal],[Notes],[Flag],[GUID],[ClassPtr] ,[ParentGUID],[AccountGUID],[CurrencyGUID],[CostGUID] ,[ContraAccGUID]) 
            SELECT * FROM [#NewDi] 
            IF EXISTS(SELECT * FROM [#NewBi] N INNER JOIN [mt000] [mt] ON [mt].[Guid] = [N].[MatGuid] WHERE snflag > 0) 
            BEGIN 
                        SELECT N.[ParentGuid] [ContraBill],N.[Guid] Guid ,b.[Guid] AS biGuid, [b].[buGuid],
							   [snc].[Guid] AS snGuid, [b].[bIsInput], [b].[IsPosted] 
                        INTO #SN 
                        FROM  
                        [#NewBi] N INNER JOIN (select bi.*,[bu].[ContraBill],[bu].[GUID] AS [buGuid], 
													[bu].[bIsInput], [bu].[IsPosted] FROM [bi000] [bi] 
													INNER JOIN #Bill [bu] ON [bu].[Guid] = [bi].[ParentGUID] 
													INNER JOIN [mt000] [m] ON [m].[Guid] = [bi].[MatGuid] 
													INNER JOIN [bt000] bt on [bt].[guid] = [bu].[TypeGuid] 
													WHERE m.snflag > 0
													and [bu].[typeGuid] = @SourceTypGuid) b  
	                    ON N.[ParentGuid] = b.[ContraBill] 
						AND N.[Unity] = b.[Unity] AND  N.[Price] = b.[Price]  AND b.[CurrencyVal] = N.[CurrencyVal] 
                        AND (N.[ClassPtr] COLLATE ARABIC_CI_AI) = (B.[ClassPtr] COLLATE ARABIC_CI_AI)  
                        AND N.[ExpireDate]= b.[ExpireDate]  
                        AND N.[Length]=  b.[Length]  
                        AND N.[Width]=  b.[Width]  
                        AND N.[Height]=  b.[Height]  
                        AND N.[MatGUID] = b.[MatGUID]        
                        AND (N.[Notes] COLLATE ARABIC_CI_AI)=  (b.[Notes] COLLATE ARABIC_CI_AI)        
                        AND N.[CurrencyGUID]= b.[CurrencyGUID] 
                        AND N.[StoreGUID] = b.[StoreGUID] 
                        AND N.[CostGUID]= b.[CostGUID] 
                        AND N.[Count]=  b.[Count] 
						INNER JOIN [SNT000] [snt] ON [snt].[biGuid] = [b].[Guid]
						INNER JOIN [SNC000] [snc] ON [snc].[Guid] = [snt].[ParentGuid]
						INNER JOIN [MT000] [mt] ON [mt].[guid] = [N].[MatGuid]
                        WHERE snflag > 0 


                        INSERT INTO SNT000 (Item,biGUID,stGUID,ParentGUID,Notes,buGuid) 
                                    SELECT DISTINCT Item,n.[Guid],stGUID,ParentGUID,Notes,[ContraBill] FROM [#SN] N INNER JOIN [SNT000] [t] ON N.biGuid = [t].biGuid 
            END 
            
            EXEC prcCheckDBCol_bu_Sums 
            
            IF EXISTS(SELECT * FROM  [bt000] WHERE [Guid] = @DistTypGuid AND  [BAutoEntry] = 1) 
            BEGIN 
						EXEC prcDisableTriggers 'CE000'
						Declare	@c  AS CURSOR
                        SET @c = CURSOR FAST_FORWARD FOR  
                                    SELECT  [Guid] FROM [#BU] 
                        OPEN @c       
                         
                        FETCH  FROM @c  INTO @Guid 
                        WHILE @@FETCH_STATUS = 0 
                        BEGIN 
                                     
                                    EXEC [dbo].[prcBill_genEntry] @Guid 
                                    FETCH  FROM @c  INTO @Guid 
                        END  
						CLOSE @c
						DEALLOCATE @c
                        ALTER TABLE CE000 ENABLE TRIGGER ALL
            END  
            IF (@Post = 1) 
            BEGIN 
                        IF EXISTS(SELECT * FROM  [bt000] WHERE [Guid] = @DistTypGuid AND  [bAutoPost] = 1) 
                        BEGIN 
                                    
									EXEC prcDisableTriggers 'Ms000'
									Declare	@c2  AS CURSOR
                                    SET @c2 = CURSOR FAST_FORWARD FOR  
                                                SELECT  [Guid] FROM [#BU] 
                                    OPEN @c2       
                                     
                                    FETCH  FROM @c2  INTO @Guid 
                                    WHILE @@FETCH_STATUS = 0 
                                    BEGIN 
                                                EXEC [dbo].[prcBill_Post1] @Guid, @Post 
                                                FETCH  FROM @c2 INTO @Guid 
                                    END    
									CLOSE @c2
									DEALLOCATE @c2
                                    ALTER TABLE ms000 ENABLE TRIGGER ALL 
                        END 
            END 

            IF EXISTS(SELECT * FROM  [bt000] WHERE [Guid] = @DistTypGuid AND  [Type] IN (5,6)) 
            BEGIN 
				DECLARE @TypeGuid UNIQUEIDENTIFIER
				SELECT TOP 1 @TypeGuid = ParentGuid FROM OITVS000 WHERE OTGUID = @DistTypGuid AND Selected = 1 ORDER BY StateOrder

				INSERT INTO ori000 (Number, GUID, POIGUID, Qty, Type, Date, Notes, POGUID, BuGuid, TypeGuid, BonusPostedQty, bIsRecycled)
				SELECT
					0, NEWID(), bi.Guid, bi.Qty , 0, bu.Date, '', bi.ParentGUID, 0x0, @TypeGuid, 0, 0
				FROM 
					[#NewBi] [bi] 
					INNER JOIN [#BU] [bu] ON bu.GUID = bi.ParentGUID

				INSERT INTO ORADDINFO000 (GUID, ParentGuid, SADATE, SDDATE, SPDATE, SSDATE, AADATE, ADDATE, APDATE, ASDATE, Finished,
											Add1,Add2, PTType, PTOrderDate, PTDate, PTDaysCount, ExpectedDate, FDATE) 
				SELECT NEWID(), bu.Guid, bu.date, bu.date, bu.date, bu.date, bu.date, bu.date, '1980-01-01', bu.Date, 0, 0, 0, 0, 5, '1980-01-01', 0, bu.Date, '1980-01-01'
				FROM 
					 [#BU] [bu]
				
				IF EXISTS(SELECT * FROM  [UsrApp000]  WHERE ParentGuid = @DistTypGuid)
				BEGIN
					INSERT INTO OrderApprovals000 (GUID, Number, OrderGuid, UserGuid)
					SELECT NEWID(), us.[Order], bu.[GUID], UserGUID
					FROM
						[UsrApp000] [us]
						CROSS APPLY  [#BU] [bu]
					WHERE 
						us.ParentGuid = @DistTypGuid
				END
			END

            IF (@DeleteOldBill > 0) 
            BEGIN 
                        
                        EXEC prcDisableTriggers 'MS000'
                        UPDATE bu SET IsPosted = 0 FROM [bu000] bu INNER JOIN [#Bill] B on bu.Guid = b.Guid 
                        
                        IF @MatCondGuid <> 0X00 OR @GrpGuid <> 0X00 
                        BEGIN 
                                    DELETE bi FROM bi000 bi 
                                    INNER JOIN [#Bill] bu ON bi.ParentGuid = bu.Guid 
                                    INNER JOIN [#Mat] C ON [mtGUID] = bi.[MatGuid] 
								    WHERE [dbo].[fnGetUserBillSec_Delete] ([dbo].[fnGetCurrentUserGUID](), [bu].[TypeGuid]) >= [bu].[Security]
									
                                    DELETE bu FROM BU000 bu
                                    WHERE Guid NOT IN (Select DISTINCT ParentGuid FROM bi000)
								    AND [dbo].[fnGetUserBillSec_Delete] ([dbo].[fnGetCurrentUserGUID](), [bu].[TypeGuid]) >= [bu].[Security]
				  
                                    UPDATE #Bill SET STATE = 1 WHERE Guid NOT IN (Select DISTINCT Guid FROM bu000) 
									
									/* Regenerate Entry for partially copied and deleted bills according to filtration condetions */
                                    DECLARE @RemaingBuCnt INT
                                    SELECT @RemaingBuCnt = Count(*) FROM bu000
                                    WHERE Guid IN (Select DISTINCT Guid FROM #Bill)
                                    
                                    if (@RemaingBuCnt > 0)
                                    BEGIN
										
										EXEC prcDisableTriggers 'CE000'
										Declare	@c3  AS CURSOR
									    SET @c3 = CURSOR FAST_FORWARD FOR   
										SELECT  [Guid] FROM [BU000] 
										WHERE Guid IN (Select DISTINCT Guid FROM #Bill) 
										OPEN @c3        
                          
										FETCH  FROM @c3  INTO @Guid  
										WHILE @@FETCH_STATUS = 0  
										BEGIN  
											EXEC [prcBill_DeleteEntry] @Guid 
											EXEC [dbo].[prcBill_genEntry] @Guid  
											FETCH  FROM @c3  INTO @Guid  
										END  
										CLOSE @c3
										DEALLOCATE @c3
										ALTER TABLE CE000 ENABLE TRIGGER ALL 
                                    END  
                        END 
                        ELSE 
                                    DELETE bu FROM [bu000] bu INNER JOIN [#Bill] B on bu.Guid = b.Guid 
								    WHERE [dbo].[fnGetUserBillSec_Delete] ([dbo].[fnGetCurrentUserGUID](), [bu].[TypeGuid]) >= [bu].[Security]
                        
                        ALTER TABLE ms000 ENABLE TRIGGER ALL 
            END 
			DEAllOCATE @c
            IF EXISTS(SELECT * FROM OP000 WHERE [NAME] ='AmnCfg_UseLogging' AND [Value] = 1) 
            BEGIN 
                        INSERT INTO  LoG000 (Computer,GUID,LogTime,RecGUID,Operation,OperationType,UserGUID) 
                        SELECT host_Name(),NEWID(),GETDATE(),Guid,1,1,@UserGUID FROM #bu 
                        IF (@DeleteOldBill > 0) 
                        BEGIN 
                                    IF @MatCondGuid <> 0X00  OR @GrpGuid <> 0X00 
                                    BEGIN 
                                                INSERT INTO  LoG000 (Computer,GUID,LogTime,RecGUID,Operation,OperationType,UserGUID) 
                                                SELECT host_Name(),NEWID(),GETDATE(),Guid,1,2,@UserGUID FROM [#Bill] WHERE STATE = 1 
                                                INSERT INTO  LoG000 (Computer,GUID,LogTime,RecGUID,Operation,OperationType,UserGUID) 
                                                SELECT host_Name(),NEWID(),GETDATE(),Guid,1,3,@UserGUID FROM [#Bill] WHERE STATE <> 1 
                                    END 
                                    ELSE 
                                                INSERT INTO  LoG000 (Computer,GUID,LogTime,RecGUID,Operation,OperationType,UserGUID) 
                                                SELECT host_Name(),NEWID(),GETDATE(),Guid,1,2,@UserGUID FROM [#Bill] 
                        END 
            END 
            
            COMMIT 
            
		    ----------------
			IF ((dbo.fnConnections_GetLanguage() = 1) or (dbo.fnConnections_GetLanguage() = 2))
			Begin
				SELECT [f].[Guid],[f].[Number],[f].[CustGuid], [customerLname] AS customername, [bu].[Date],[ContraBill],[bu].[Number] AS  [ContraNumber]  
				FROM  #Bill f INNER JOIN  [BU000] [bu] ON [bu].[Guid] = [ContraBill] 
				ORDER BY [customername],[bu].[Date]
			END
			ELSE
			Begin
				SELECT [f].[Guid],[f].[Number],[f].[CustGuid],[customername], [bu].[Date],[ContraBill],[bu].[Number] AS  [ContraNumber]  
				FROM  #Bill f INNER JOIN  [BU000] [bu] ON [bu].[Guid] = [ContraBill] 
				ORDER BY [customername],[bu].[Date]
            END
		    ---------------- «·›Ê« Ì— «· Ì ·„ Ì „ Õ–›Â« ·⁄œ„ ÊÃÊœ ”„«ÕÌ…
		    SELECT COUNT(*) BillsCount FROM bu000 bu
		    WHERE [dbo].[fnGetUserBillSec_Delete] ([dbo].[fnGetCurrentUserGUID](), [bu].[TypeGuid]) < [bu].[Security]
 /*
EXECUTE [prcCopyBills] '942f6229-21de-46f0-985c-1472358379fd', 'c140e3bb-d367-4e66-bee2-7bf56ee82cbb', 0, '1/1/2010 0:0:0.0', '10/13/2010 23:59:18.253', 0, 0, '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', -1, '', '', '00000000-0000-0000-0000-000000000000', 1, 1, 0, 0, '00000000-0000-0000-0000-000000000000', 1
EXECUTE  [prcCopyBills] '942f6229-21de-46f0-985c-1472358379fd', '99fa9513-7e47-4094-bb0a-9ddaa0ce1a67', 0, '1/1/2010 0:0:0.0', '10/13/2010 23:59:22.315', 0, 0, '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', -1, '', '', '00000000-0000-0000-0000-000000000000', 1, 1, 0, 0, '00000000-0000-0000-0000-000000000000', 1		   
 */
###########################
#END