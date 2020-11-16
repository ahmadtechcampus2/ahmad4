############################################################################################
CREATE PROCEDURE prcCheckDBCol_bu_Sums
AS
	SET ANSI_WARNINGS  OFF
	EXEC prcDisableTriggers  'bu000'
	UPDATE [bu000] SET [TotalDisc] = ISNULL((SELECT SUM([Discount]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0) + ISNULL((SELECT SUM([Discount]) FROM [di000] WHERE [di000].[ParentGUID] = [bu].[GUID]), 0) 
		FROM [bu000] AS [bu] INNER JOIN [#Bu] [B] ON [b].[Guid] = [bu].[Guid]
		WHERE ABS(ISNULL([bu].[TotalDisc], 0) - (ISNULL((SELECT SUM([Discount]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0) + ISNULL((SELECT SUM([Discount]) FROM [di000] WHERE [di000].[ParentGUID] = [bu].[GUID]), 0))) > 0.1 
	UPDATE [bu000] SET [TotalExtra] = ISNULL((SELECT SUM([Extra]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0) + ISNULL((SELECT SUM([Extra]) FROM [di000] WHERE [di000].[ParentGUID] = [bu].[GUID]), 0) 
		FROM [bu000] AS [bu] INNER JOIN [#Bu] [B] ON [b].[Guid] = [bu].[Guid]
		WHERE ABS(ISNULL([bu].[TotalExtra], 0) - (ISNULL((SELECT SUM([Extra]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0) + ISNULL((SELECT SUM([Extra]) FROM [di000] WHERE [di000].[ParentGUID] = [bu].[GUID]), 0))) > 0.1 
	
	UPDATE [bu000] SET [ItemsDisc] = ISNULL((SELECT SUM([Discount]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0) 
		FROM [bu000] AS [bu]  INNER JOIN [#Bu] [B] ON [b].[Guid] = [bu].[Guid]
		WHERE ABS(ISNULL([bu].[ItemsDisc], 0) - ISNULL((SELECT SUM([Discount]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0)) > 0.1 
	

	UPDATE [bu] SET [BonusDisc] = ISNULL((SELECT SUM([biBonusDisc] * [biBillQty]) FROM [vwBiMt] WHERE [vwBiMt].[biParent] = [bu].[GUID]), 0) 
		FROM [bu000] AS [bu]  INNER JOIN [#Bu] [B] ON [b].[Guid] = [bu].[Guid]
		WHERE ABS(ISNULL([bu].[BonusDisc], 0) - ISNULL((SELECT SUM([biBonusDisc] * [biBillQty]) FROM [vwBiMt] WHERE [vwBiMt].[biParent] = [bu].[GUID]), 0)) > 0.1 

	UPDATE [bu] SET [VAT] = ISNULL((SELECT SUM([VAT]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]), 0)  
		FROM [bu000]  [bu] INNER JOIN [#Bu] [B] ON [b].[Guid] = [bu].[Guid]
		WHERE [VAT] <> (SELECT SUM([VAT]) FROM [bi000] WHERE [bi000].[ParentGUID] = [bu].[GUID]) 
	UPDATE [bu] SET [Total] = CASE [bt].[VatSystem] WHEN 1 THEN 0 WHEN 2 THEN [bu].[VAT] ELSE 0 END + ISNULL((SELECT SUM([biPrice] * [biBillQty]) FROM [vwBiMt] WHERE [vwBiMt].[biParent] = [bu].[GUID]), 0) 
		FROM [bu000] AS [bu]  INNER JOIN [#Bu] [B] ON [b].[Guid] = [bu].[Guid]
		INNER JOIN [bt000] [bt] ON [bu].[TypeGuid] = [bt].[Guid]
		WHERE ABS(ISNULL([bu].[Total], 0) - CASE [bt].[VatSystem] WHEN 1 THEN 0 WHEN 2 THEN [bu].[VAT] ELSE 0 END - ISNULL((SELECT SUM([biPrice] * [biBillQty]) FROM [vwBiMt] WHERE [vwBiMt].[biParent] = [bu].[GUID]), 0)) > 0.1 
	ALTER TABLE [bu000] ENABLE TRIGGER ALL
##################################
CREATE PROCEDURE prcCollectBillsinOneBill
      @SourceTypGuid  UNIQUEIDENTIFIER, 
      @DistTypGuid  UNIQUEIDENTIFIER, 
      @FromND                 BIT, 
      @StartDate        DATETIME, 
      @EndDate          DATETIME, 
      @From             INT, 
      @To                     INT, 
      @Acc              UNIQUEIDENTIFIER, 
      @Customer         UNIQUEIDENTIFIER, 
      @CustCondGuid     UNIQUEIDENTIFIER, 
      @MatCondGuid            UNIQUEIDENTIFIER = 0x00, 
      @Cost             UNIQUEIDENTIFIER = 0X00, 
      @GrpGuid          UNIQUEIDENTIFIER = 0X00, 
      @Pay              [INT] = -1,--0 CASH 1 LATER -1 LATER cASH 
      @NotesContain           [NVARCHAR](256) = '',-- NULL or Contain Text  
      @NotesNotContain  [NVARCHAR](256) = '', -- NULL or Not Contain  
      @BillCondGuid     UNIQUEIDENTIFIER = 0X00, 
      @CostFlag         INT = 0, 
      @Post             INT = 1, -- 0 UNPOSTED, 1 POSTED
      @Continue         [INT] = 0, 
      @DeleteOldBill    [BIT] = 0, 
      @SrcBillGuid      UNIQUEIDENTIFIER = 0X00,
      @ShowBillsWithoutCust BIT = 0,
      @TotatalDialy				BIT = 0
AS 
      ------------------------------------------------------------------------- (in this version) last 4 versions has been marged ---- (mo aktr)
      SET NOCOUNT ON 
	  DECLARE @SNIntegrateErrorFlag BIT
	  DECLARE @DeleteOldBillAsInt INT
	  SET @DeleteOldBillAsInt = (SELECT CONVERT(INT, @DeleteOldBill))
      DECLARE @Guid UNIQUEIDENTIFIER,@BtName NVARCHAR(256),@UserGuid UNIQUEIDENTIFIER,@Sql NVARCHAR(max),@Criteria NVARCHAR(max) 
      DECLARE @c CURSOR,@CurrencyPtr UNIQUEIDENTIFIER 
      SET @UserGuid = [dbo].[fnGetCurrentUserGUID]() 
      CREATE TABLE [#Mat] ( [mtGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
      CREATE TABLE #BillCond  
      ( 
            buGuid UNIQUEIDENTIFIER, 
            biGuid UNIQUEIDENTIFIER 
      ) 

      IF @MatCondGuid <> 0X00 OR @GrpGuid <> 0X00 
            INSERT INTO [#Mat] EXEC [prcGetMatsList]  NULL, @GrpGuid,-1,@MatCondGuid  
      CREATE TABLE [#Cost] ( [Number] [UNIQUEIDENTIFIER]) 
      INSERT INTO  [#Cost] select [GUID] from [fnGetCostsList]( @Cost) 
      IF @Cost = 0x00 
            INSERT INTO [#Cost] VALUES(0X00) 

      CREATE TABLE [#Cust] ( [Number] [UNIQUEIDENTIFIER], [Sec] [INT])  
      INSERT INTO [#Cust] EXEC [prcGetCustsList]  @Customer, @Acc, @CustCondGuid  

      SELECT [c].[Number] , [Sec],ACCOUNTGUID ,[customername], [LatinName] INTO [#Cust2] FROM  [#Cust] [c] INNER JOIN [cu000] [cu] ON [cu].[Guid] = [c].[Number] 

      SELECT @BtName = Name FROM [bt000] WHERE GUID = @SourceTypGuid 

      CREATE TABLE #Bill 
      ( 
		    [TypeGuid]		  UNIQUEIDENTIFIER,
		    [Security]		  INT, 
            [Guid]			  UNIQUEIDENTIFIER, 
            [Number]		  FLOAT, 
            [CustGuid]		  UNIQUEIDENTIFIER, 
            [ContraBill]      UNIQUEIDENTIFIER, 
            [CurrencyGUID]    UNIQUEIDENTIFIER, 
            [StoreGUID]       UNIQUEIDENTIFIER, 
            [CustAcc]		  UNIQUEIDENTIFIER, 
            [Branch]		  UNIQUEIDENTIFIER, 
            [CurrencyVal]     FLOAT, 
            [customername]    NVARCHAR(250) COLLATE ARABIC_CI_AI,
			[customerLname]	  [NVARCHAR](250) COLLATE ARABIC_CI_AI, 	 
            [Date]            DATETIME, 
            [CostGUID]		  UNIQUEIDENTIFIER, 
            [State]			  BIT DEFAULT 0, 
            [PayType]		  INT,
            FIRSTPAY		  FLOAT DEFAULT 0,
            IsPosted		  INT,
			[CustAccGuid]	  UNIQUEIDENTIFIER
      ) 
      CREATE TABLE [#NewBi]( 
            [Number] [INT] IDENTITY(1,1), 
            [Qty] [float]  , 
            [Unity] [float], 
            [Price] [float], 
            [BonusQnt] [float], 
            [Discount] [float], 
            [BonusDisc] [float] , 
            [Extra] [float] , 
            [CurrencyVal] [float] , 
            [Notes] [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
            [Qty2] [float], 
            [Qty3] [float], 
            [ClassPtr] [NVARCHAR](250), 
            [ExpireDate] [datetime], 
            [ProductionDate] [datetime], 
            [Length] [float] NULL DEFAULT (0), 
            [Width] [float] NULL DEFAULT (0), 
            [Height] [float] NULL DEFAULT (0), 
            [GUID] [uniqueidentifier] /*ROWGUIDCOL*/  NOT NULL DEFAULT (newid()), -- ROWGUIDCOL not supported in Azure
            [VAT] [float] NULL DEFAULT (0), 
            [ParentGUID] [uniqueidentifier] , 
            [MatGUID] [uniqueidentifier]  , 
            [CurrencyGUID] [uniqueidentifier], 
            [StoreGUID] [uniqueidentifier], 
            [CostGUID] [uniqueidentifier], 
            [Count] [float],
            [VatRatio]	[float] DEFAULT 0
      ) 
      CREATE TABLE [#NewDi]( 
            [Number] [INT] IDENTITY(1,1), 
            [Discount] [FLOAT] , 
            [Extra] [float], 
            [CurrencyVal] [float], 
            [Notes] [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
            [Flag] [int]  DEFAULT (0), 
            [GUID] [uniqueidentifier] DEFAULT newid() , 
            [ClassPtr] [NVARCHAR](250), 
            [ParentGUID] [uniqueidentifier] , 
            [AccountGUID] [uniqueidentifier], 
            [CurrencyGUID] [uniqueidentifier], 
            [CostGUID] [uniqueidentifier], 
            [ContraAccGUID] [uniqueidentifier] 
      ) 
      CREATE TABLE [#BillColected]( 
            [Id] [int] IDENTITY(1,1), 
            [CollectedGUID] [uniqueidentifier], 
            [NewCollectedGUID] [uniqueidentifier] 
      ) 
      CREATE TABLE [#Part]( [GUID] [uniqueidentifier] )  
       

      SET @Sql = 'INSERT INTO #Bill ([TypeGuid], [Security], [Guid], [CustGuid], [CurrencyGUID], [StoreGUID], [CustAcc], [Branch], [Number], [customername], [customerLname], [Date], [CurrencyVal], [CostGuid], [PayType], FIRSTPAY, IsPosted, CustAccGuid) 
                  SELECT ' 

      IF ((@CostFlag & 0X00002) > 0) 
            SET @Sql = @Sql +' DISTINCT ' 

      Declare @LeftOrInner NVARCHAR(10)
      IF (@ShowBillsWithoutCust > 0)
		  SET @LeftOrInner = ' LEFT '
	  ELSE
		  SET @LeftOrInner = ' INNER '

      SET @Sql = @Sql + '[bu].[TypeGuid], [bu].[Security], [bu].[Guid], [bu].[CustGuid], [bu].[CurrencyGUID], [bu].[StoreGUID], [CustAccGuid], [Branch], [bu].[Number], [customername], [cu].[LatinName], '
      IF @TotatalDialy  > 0
		 SET @Sql = @Sql + 'dbo.fnGetDateFromTime([Date]),'
	  ELSE 
		 SET @Sql = @Sql + 'dbo.fnGetDateFromTime(GETDATE()),'
       SET @Sql = @Sql + '[bu].[CurrencyVal], [bu].[CostGuid], [PayType], [bu].FIRSTPAY, [bu].IsPosted, BU.CustAccGuid
                         FROM [vbbu] [bu] ' + @LeftOrInner + ' JOIN [#Cust2] [cu] ON [bu].[CustGuid] = [cu].[Number] '
      
      IF ((@CostFlag & 0X00001) > 0) 
            SET @Sql = @Sql + 'INNER JOIN [#Cost] co ON co.[Number] = bu.CostGuid ' 

      IF ((@CostFlag & 0X00002) > 0) 
            SET @Sql = @Sql + ' INNER JOIN bi000 bi ON bu.Guid = bi.ParentGuid INNER JOIN  [#Cost] co2 ON [bi].[CostGUID] = co2.[Number]' 

      SET @Sql = @Sql + 'WHERE [TypeGuid] = ''' + CAST(@SourceTypGuid AS NVARCHAR(36)) + '''' 


	  IF (@ShowBillsWithoutCust > 0)
	  BEGIN
		  IF (@Customer <> 0x00)
			  SET @Sql = @Sql + ' AND [CustGuid] = ''' + CAST(@Customer AS NVARCHAR(36)) + ''' '
		  IF (@Acc <> 0x00)
			  SET @Sql = @Sql + ' AND [CustAccGuid] = ''' + CAST(@Acc AS NVARCHAR(36)) + ''' '
      END
	
      IF @Pay <> -1  
            SET @Sql = @Sql + ' AND ([PayType] = ' + CAST(@Pay AS NVARCHAR(25)) + ') '  

      IF @FromND = 0 
            SET @Sql = @Sql + ' AND ([Date] BETWEEN ' + [dbo].[fnDateString](@StartDate) + ' AND ' + [dbo].[fnDateString](@EndDate) + ') '
      IF @FromND = 1 
            SET @Sql = @Sql + ' AND ([bu].[number] BETWEEN ' + cast (@From AS NVARCHAR(20)) + ' AND ' + CAST (@To AS NVARCHAR (20)) + ') '
            
	  IF @NotesContain <>  '' 
            SET @Sql = @Sql + ' AND ([bu].[Notes] LIKE ''%'+  @NotesContain + '%'') '
      IF @NotesNotContain <> '' 
            SET @Sql = @Sql + ' AND ([bu].[Notes] NOT LIKE ''%' +  @NotesNotContain + '%'') ' 

      EXEC(@Sql) 

	  
	DECLARE @Cnt INT 
	IF @MatCondGuid <> 0X00 OR @GrpGuid <> 0X00 
		DELETE b FROM #Bill b LEFT JOIN (SELECT DISTINCT A.GUID FROM #Bill A LEFT JOIN [bi000] b ON b.ParentGuid = A.Guid INNER JOIN [#Mat] C ON [mtGUID] = b.[MatGuid]) C ON c.[Guid] = b.Guid WHERE c.[Guid] IS NULL 

	IF @BillCondGuid <> 0X00 
	BEGIN 
		SET @Sql = 'INSERT INTO #BillCond SELECT [buGuid],[biGuid] FROM vwBuBi_Address a INNER JOIN #Bill b ON b.Guid = [buGuid]' 
		select @CurrencyPtr = Guid FROM my000 WHERE Number = 1 
		SET @Criteria = [dbo].[fnGetBillConditionStr]( NULL,@BillCondGuid,@CurrencyPtr) 

		IF @Criteria <> ''   -- For Bill Custom Filed
		BEGIN
			IF RIGHT ( RTRIM (@Criteria) , 4 ) ='<<>>'
			BEGIN	
			SET @Criteria = REPLACE(@Criteria ,'<<>>','')		
				DECLARE @CFTableName NVARCHAR(255)
				Set @CFTableName = (SELECT CFGroup_Table From CFMapping000 Where Orginal_Table = 'bu000' )
				SET @SQL = @SQL + ' INNER JOIN ['+ @CFTableName +'] ON [b].[Guid] = ['+ @CFTableName +'].[Orginal_Guid] '			
			END
			SET @Criteria = ' WHERE (' + @Criteria + ')' 
			SET @Sql = @Sql + @Criteria 
		END
		EXEC(@Sql) 
		DELETE B FROM #Bill b LEFT JOIN #BillCond ON b.Guid = buGuid  WHERE buGuid IS NULL 
	END 	
	
      IF @Continue = 0 
      BEGIN 
		  IF ((dbo.fnConnections_GetLanguage() = 1) or (dbo.fnConnections_GetLanguage() = 2))
		  BEGIN
				SELECT [f].[Guid],[f].[Number],[f].[CustGuid],[CustomerLname] as customername,[bu].[Date],[bu].[Number] AS  [ContraNumber],[bt].[LatinName] AS [btName] 
				FROM  [#Bill] [f] INNER JOIN  [BU000] [bu] ON [bu].[Guid] = [f].[Guid] 
				INNER JOIN [bt000] [bt] ON [bt].[Guid] = [bu].[TypeGuid] 
				WHERE [dbo].[fnGetUserBillSec_Browse]([dbo].[fnGetCurrentUserGUID](), [bu].[TypeGuid]) >= [bu].[Security]
				ORDER BY [customername],[bu].[Date] 
	             
				SELECT [f].[Guid],[f].[Number],[f].[CustGuid],[CustomerLname] as customername,[bu].[Date],[NewCollectedGuid] [ContraBill],[bu].[Number] AS  [ContraNumber],[bt].[LatinName] AS [btName] 
				FROM  #Bill f INNER JOIN BillColected000 B ON f.Guid = [CollectedGUID] INNER JOIN  [BU000] [bu] ON [bu].[Guid] = [NewCollectedGuid] 
				INNER JOIN [bt000] [bt] ON [bt].[Guid] = [bu].[TypeGuid] 
				WHERE [dbo].[fnGetUserBillSec_Browse]([dbo].[fnGetCurrentUserGUID](), [bu].[TypeGuid]) >= [bu].[Security]
				ORDER BY [customername],[bu].[Date],[bu].[Number] 
		  END
		  ELSE
		  BEGIN
				SELECT [f].[Guid],[f].[Number],[f].[CustGuid],[customername],[bu].[Date],[bu].[Number] AS  [ContraNumber],[bt].[Name] AS [btName]
				FROM  [#Bill] [f] INNER JOIN  [BU000] [bu] ON [bu].[Guid] = [f].[Guid] 
				INNER JOIN [bt000] [bt] ON [bt].[Guid] = [bu].[TypeGuid] 
				WHERE [dbo].[fnGetUserBillSec_Browse]([dbo].[fnGetCurrentUserGUID](), [bu].[TypeGuid]) >= [bu].[Security]
				ORDER BY [customername],[bu].[Date] 
	             
				SELECT [f].[Guid],[f].[Number],[f].[CustGuid],[customername],[bu].[Date],[NewCollectedGuid] [ContraBill],[bu].[Number] AS  [ContraNumber],[bt].[Name] AS [btName]
				FROM  #Bill f INNER JOIN BillColected000 B ON f.Guid = [CollectedGUID] INNER JOIN  [BU000] [bu] ON [bu].[Guid] = [NewCollectedGuid] 
				INNER JOIN [bt000] [bt] ON [bt].[Guid] = [bu].[TypeGuid] 
				WHERE [dbo].[fnGetUserBillSec_Browse]([dbo].[fnGetCurrentUserGUID](), [bu].[TypeGuid]) >= [bu].[Security]
				ORDER BY [customername],[bu].[Date],[bu].[Number] 
	            
	            
		  END

			EXECUTE @SNIntegrateErrorFlag = prcCheckSNIntegrate @DeleteOldBillAsInt
			IF(@SNIntegrateErrorFlag = 1)
			BEGIN
				ROLLBACK
				SELECT 1 As SNErrorFlag
				RETURN   
			END
		RETURN                                    
      END 

      BEGIN TRAN 


      IF @Continue = 1 
            DELETE A FROM #Bill A INNER JOIN BillColected000 B ON a.Guid = [CollectedGUID] 
                  INNER JOIN [bu000] c ON c.Guid = [NewCollectedGUID]


    
      DELETE #Bill WHERE [Guid] NOT IN (SELECT IdType FROM dbo.RepSrcs WHERE IdTbl =  @SrcBillGuid) 


      SELECT [CustGuid], [CurrencyGUID], [StoreGUID], [Branch], [CurrencyVal], [CostGuid], [PayType], FIRSTPAY, IsPosted, NEWID() AS ContraBill, CustAccGuid,[Date]
      INTO #WWW 
      FROM #Bill 
      GROUP BY [CustGuid], [CurrencyGUID], [StoreGUID], [Branch], [CurrencyVal], [CostGuid], [PayType], FIRSTPAY, IsPosted, CustAccGuid,[Date]
            
      UPDATE b SET [ContraBill] = [cb].[ContraBill] 
      FROM  [#Bill] b 
      INNER JOIN #WWW [cb] ON [cb].[CustGuid] = b.[CustGuid] 
                  AND [cb].[CurrencyGUID] = [b].[CurrencyGUID] 
                  AND [cb].[StoreGUID] = [b].[StoreGUID] 
                  AND [cb].[Branch] = [b].[Branch] 
                  AND [cb].[CurrencyVal] = [b].[CurrencyVal] 
                  AND [cb].[CostGuid] = [b].[CostGuid] 
                  AND [cb].[PayType] = [b].[PayType] 
                  AND [cb].[FIRSTPAY] = [b].[FIRSTPAY]
                  AND [cb].[IsPosted] = [b].[IsPosted]
				  AND [cb].[CustAccGuid] = [b].[CustAccGuid]
				  AND [cb].[Date] = [b].[Date]

      INSERT INTO [#BillColected]([CollectedGUID] ,[NewCollectedGUID]) SELECT   [Guid],[ContraBill] FROM #Bill 

      SELECT @Cnt = MAX([ID]) FROM  [BillColected000] 

      IF @Cnt     IS NULL 
                  SET @Cnt = 0 
       
      CREATE TABLE [#BU] 
      ( 
            [Number]    [INT] IDENTITY(1,1), 
            [Date]            [DATETIME], 
            [CurrencyVal]     [FLOAT], 
            [Notes]     [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
            [Branch]    [uniqueidentifier], 
            [GUID]            [uniqueidentifier], 
            [TypeGUID] [uniqueidentifier], 
            [CustGUID] [uniqueidentifier], 
            [CurrencyGUID]    [uniqueidentifier], 
            [StoreGUID]       [uniqueidentifier], 
            [CustAccGUID]     [uniqueidentifier], 
            [customername]    [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
            [CostGUID] [uniqueidentifier], 
            [PayType]   [INT] ,
            FIRSTPAY    FLOAT,
            [IsPosted] [INT]
      )

     SET @Sql = 'INSERT INTO [#NewBi] ([Qty],[Unity],[Price],[Discount],[BonusDisc],[BonusQnt],[Extra],[Notes],[CurrencyVal], 
                  [Qty2],[Qty3],[ClassPtr],[ExpireDate],[ProductionDate],Length,Width,Height,VAT,ParentGUID,MatGUID,[CurrencyGUID],[StoreGUID],CostGUID,[Count]) 
                SELECT SUM(Qty),Unity,Price,SUM([Discount]),SUM([BonusDisc]),SUM(BonusQnt),SUM(Extra),[Notes],[bi].[CurrencyVal], 
                  SUM(Qty2),SUM(Qty3),ClassPtr,[ExpireDate],[ProductionDate],Length,Width,Height,SUM([bi].VAT),[ContraBill],[bi].MatGUID,[bi].[CurrencyGUID],[bi].[StoreGUID],[bi].[CostGUID],[Count] 
                  FROM [bi000] [bi] INNER JOIN #Bill [bu] ON [bu].[Guid] = [bi].[ParentGUID] '

      IF @BillCondGuid <> 0X00 
            SET @Sql = @Sql + ' INNER JOIN #BillCond ON [bi].Guid = biGuid ' 
      IF ((@CostFlag & 0X00002) > 0) 
            SET @Sql = @Sql + ' INNER JOIN  [#Cost] co ON [bi].[CostGUID] = co.[Number]' 
      SET @Sql = @Sql + 'GROUP BY [Unity],[Price],[bi].[CurrencyVal], 
                        [ClassPtr],[ExpireDate],[ProductionDate],[Length],[Width],[Height],[ContraBill],[MatGUID],[Notes],[bi].[CurrencyGUID],[bi].[StoreGUID],[bi].[CostGUID],[Count]' 
	 EXEC(@Sql) 
	UPDATE n SET [VatRatio] =( CASE WHEN ((n.[Qty]* n.[Price]) ) = 0 THEN 0 ELSE   n.Vat / ((n.[Qty]* n.[Price])/CASE N.UNITY WHEN 2 THEN Unit2Fact WHEN 3 THEN Unit3Fact ELSE 1 END - [Discount] + [Extra]) END )* 100 from [#NewBi] n inner join mt000 m on m.guid = n.matguid where n.Vat > 0
      IF @MatCondGuid <> 0X00 OR @GrpGuid <> 0X00 
            DELETE b FROM  [#NewBi] b LEFT JOIN [#Mat] ON  [MatGuid] = [MtGuid] WHERE [MtGuid] IS NULL 
      
      INSERT INTO BillColected000 ( [ID],[CollectedGUID] ,[NewCollectedGUID], [GUID])
            SELECT @Cnt+ [ID],[CollectedGUID] ,[NewCollectedGUID], NEWID() FROM [#BillColected] 

      IF @MatCondGuid = 0X00 AND @GrpGuid = 0X00 
            INSERT INTO [#NewDi]([Discount] ,[Extra],[CurrencyVal],[Notes],[Flag],[ClassPtr],[ParentGUID],[AccountGUID],[CurrencyGUID],[CostGUID],[ContraAccGUID]) 
            SELECT SUM([Discount]) ,SUM([Extra]),[bi].[CurrencyVal],[bi].[Notes],[Flag],[ClassPtr],[ContraBill],[AccountGUID],[bi].[CurrencyGUID],[bi].[CostGUID],[ContraAccGUID] 
            FROM [di000] [bi] INNER JOIN #Bill [bu] ON [bu].[Guid] = [bi].[ParentGUID] 
            GROUP BY [bi].[CurrencyVal],[Notes],[Flag],[ClassPtr],[ContraBill],[AccountGUID],[bi].[CurrencyGUID],bi.[CostGUID],[ContraAccGUID] 
            
		IF (dbo.fnConnections_GetLanguage() = 1) 
        BEGIN 
			INSERT INTO[#BU]( [Date], CurrencyVal, Notes,Branch,GUID,TypeGUID,CustGUID,CurrencyGUID,StoreGUID,[CustAccGUID],[customername],[CostGUID],[PayType], FIRSTPAY, [IsPosted]) 
            SELECT [dbo].[fnGetDateFromDT]([Date]),CurrencyVal,@BtName + ' ' + 'from' + CAST (MIN([Number]) AS NVARCHAR (20)) + ' to ' + CAST (MAX([Number]) AS NVARCHAR (24)) + ' Count of Collected Bills: ' + CAST (COUNT(*) AS NVARCHAR (24)),[Branch],[ContraBill],@DistTypGuid,CustGUID,CurrencyGUID,StoreGUID,[CustAcc],[customername],[CostGUID],[PayType], FIRSTPAY, [IsPosted] 
            FROM #Bill   
            GROUP BY [Branch],[ContraBill],CurrencyVal,CustGUID,CurrencyGUID,StoreGUID,[CustAcc],[customername],[CostGUID],[PayType], FIRSTPAY, IsPosted , [Date]
            ORDER BY [Branch] 
        END 
        ELSE IF (dbo.fnConnections_GetLanguage() = 2) 
        BEGIN 
			INSERT INTO[#BU]([Date],CurrencyVal,Notes,Branch,GUID,TypeGUID,CustGUID,CurrencyGUID,StoreGUID,[CustAccGUID],[customername],[CostGUID],[PayType], FIRSTPAY, [IsPosted]) 
            SELECT [dbo].[fnGetDateFromDT]([Date]),CurrencyVal,@BtName + ' ' + 'De' + CAST (MIN([Number]) AS NVARCHAR (20)) + ' le ' + CAST (MAX([Number]) AS NVARCHAR (24)) + ' numÈro des Factures rassemblÈes: ' + CAST (COUNT(*) AS NVARCHAR (24)),[Branch],[ContraBill],@DistTypGuid,CustGUID,CurrencyGUID,StoreGUID,[CustAcc],[customername],[CostGUID],[PayType], FIRSTPAY, [IsPosted] 
            FROM #Bill   
            GROUP BY [Branch],[ContraBill],CurrencyVal,CustGUID,CurrencyGUID,StoreGUID,[CustAcc],[customername],[CostGUID],[PayType], FIRSTPAY, IsPosted, [Date]
            ORDER BY [Branch] 
        END 
        ELSE  
        BEGIN 
			INSERT INTO[#BU]([Date],CurrencyVal,Notes,Branch,GUID,TypeGUID,CustGUID,CurrencyGUID,StoreGUID,[CustAccGUID],[customername],[CostGUID],[PayType], FIRSTPAY, [IsPosted]) 
            SELECT [dbo].[fnGetDateFromDT]([Date]),CurrencyVal,@BtName + ' ' + '„‰' + CAST (MIN([Number]) AS NVARCHAR (20)) + ' ≈·Ï ' + CAST (MAX([Number]) AS NVARCHAR (24)) + ' ⁄œœ «·›Ê« Ì— «·„Ã„⁄…: ' + CAST (COUNT(*) AS NVARCHAR (24)),[Branch],[ContraBill],@DistTypGuid,CustGUID,CurrencyGUID,StoreGUID,[CustAcc],[customername],[CostGUID],[PayType], FIRSTPAY, [IsPosted] 
            FROM #Bill   
            GROUP BY [Branch],[ContraBill],CurrencyVal,CustGUID,CurrencyGUID,StoreGUID,[CustAcc],[customername],[CostGUID],[PayType], FIRSTPAY, IsPosted , [Date]
            ORDER BY [Branch] 
		END  
      SELECT ISNULL([maxNum],0) - MIN(b.Number)  AS [MAXUMBER], b.[Branch] 
            INTO [#BN] 
            FROM [#bu] B INNER JOIN  
            (SELECT MAX(b2.[NUMBER]) + 1 AS [maxNum], [Branch] FROM [bu000] b2 WHERE b2.TypeGUID = @DistTypGuid group by  b2.[Branch]) b4 ON b.[Branch] = b4.[Branch] 
      GROUP BY [maxNum], b.[Branch] 

      INSERT INTO bu000 (FIRSTPAY, [PayTYpe], [Number],[Date],CurrencyVal,Notes,b.Branch,GUID,TypeGUID,CustGUID,CurrencyGUID,StoreGUID,CustAccGUID,[Cust_Name],[UserGuid],[Security],[CostGUID]) 
            SELECT b.FIRSTPAY, [PayType], ISNULL([MAXUMBER],0) + [B].[Number], [Date], CurrencyVal,Notes,[b].[Branch],[GUID],TypeGUID,CustGUID,CurrencyGUID,StoreGUID,CustAccGUID,customername,@UserGuid,1,[CostGUID] 
            FROM [#bu] b LEFT JOIN [#BN] bn ON b.Branch =  bn.Branch 

      INSERT INTO [bi000] ( 
            [Number],[Qty],[Unity],[Price],[BonusQnt],[Discount],[BonusDisc] ,[Extra] ,[CurrencyVal], 
            [Notes],[Qty2],[Qty3], 
            [ClassPtr],[ExpireDate], 
            [ProductionDate],[Length],[Width],[Height], 
            [GUID],[VAT],[ParentGUID],[MatGUID],[CurrencyGUID],[StoreGUID],[CostGUID],[Count] ,[VatRatio]
                      ) 
      SELECT * FROM [#NewBi] 
       
      INSERT INTO di000([Number],[Discount],[Extra],[CurrencyVal],[Notes],[Flag],[GUID],[ClassPtr] ,[ParentGUID],[AccountGUID],[CurrencyGUID],[CostGUID] ,[ContraAccGUID]) 
      SELECT * FROM [#NewDi] 

      IF EXISTS(SELECT * FROM [#NewBi] N INNER JOIN [mt000] [mt] ON [mt].[Guid] = [N].[MatGuid] WHERE snflag > 0) 
      BEGIN 
            SELECT N.[ParentGuid] [ContraBill],n.[Guid],b.[Guid] AS biGuid,[buGuid]  
            INTO #snCol 
            FROM  
            [#NewBi] N INNER JOIN  [mt000] [mt] ON [mt].[Guid] = [N].[MatGuid] 
             INNER JOIN (select bi.*,[bu].[ContraBill],[bu].[GUID] AS [buGuid]FROM [bi000] [bi] INNER JOIN #Bill [bu] ON [bu].[Guid] = [bi].[ParentGUID] INNER JOIN [mt000] [m] ON [m].[Guid] = [bi].[MatGuid] WHERE m.snflag > 0) b  
            ON N.[ParentGuid] = b.[ContraBill] 
            AND N.[Unity] = b.[Unity] AND  N.[Price] = b.[Price]  AND b.[CurrencyVal] = N.[CurrencyVal] 
            AND (N.[ClassPtr] COLLATE ARABIC_CI_AI) = (B.[ClassPtr] COLLATE ARABIC_CI_AI)  
            AND N.[ExpireDate]= b.[ExpireDate]  
            AND N.[Length]=  b.[Length]  
            AND N.[Width]=  b.[Width]  
            AND N.[Height]=  b.[Height]  
            AND N.[MatGUID]   = b.[MatGUID]     
            AND (N.[Notes] COLLATE ARABIC_CI_AI)=  (b.[Notes] COLLATE ARABIC_CI_AI) 
            AND N.[CurrencyGUID]= b.[CurrencyGUID]    
            AND N.[StoreGUID] = b.[StoreGUID] 
            AND N.[CostGUID]= b.[CostGUID] 
            AND N.[Count]=  b.[Count] 
            WHERE snflag > 0 
            INSERT INTO SNT000 (Item,biGUID,stGUID,ParentGUID,Notes,buGuid) 
                  SELECT DISTINCT Item,n.[Guid],stGUID,ParentGUID,Notes,[ContraBill] FROM [SNT000] [t] INNER JOIN [#snCol] N ON N.biGuid = [t].biGuid 
			
		EXECUTE @SNIntegrateErrorFlag = prcCheckSNIntegrate @DeleteOldBillAsInt
			IF(@SNIntegrateErrorFlag = 1)
			BEGIN
				ROLLBACK
				SELECT 1 As SNErrorFlag
				RETURN   
			END
      END 
	  EXEC prcCheckDBCol_bu_Sums 

	  -- Check if there duplicate in Serial Numbers Before Collectting Bills
	  IF EXISTS(SELECT sn.snGuid
	  			FROM vwMt mt 
	  				INNER JOIN vwbubi			AS b  ON b.biMatPtr = mt.mtGUID AND b.buGUID = b.biParent
	  				INNER JOIN #Bill			AS selectedBills on B.buGUID = selectedBills.[Guid]
	  				INNER JOIN vwbt				AS bt ON bt.btGUID = b.buType
	  				INNER JOIN vwExtended_SN	AS sn ON sn.buGUID = b.buGUID AND sn.biGUID = b.biGUID AND sn.biMatPtr = b.biMatPtr
	  			WHERE 
	  				(b.buIsPosted = 1 OR bt.btAutoPost = 1)
	  			GROUP BY 
	  				sn.snGuid
	  			HAVING 
	  				COUNT(SN.snGuid) > 1)
	  BEGIN 
	  	ROLLBACK
	  	SELECT 2 As SNErrorFlag -- 2 is Duplicate Flag
	  	RETURN     
	  END
		
     
	  INSERT INTO mc000(tYPE,NUMBER,ITEM,aSC2) VALUES(24,1000,3000,'COLBILL1000D79016AC-3495-449C-8EA7-41895239F0CB')
      IF EXISTS(SELECT * FROM  [bt000] WHERE [Guid] = @DistTypGuid AND  [BAutoEntry] = 1) 
      BEGIN 
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
      END

      ----------- by ahmad a h
      ---------------------------------
      ---------------------------------
      IF (@Post = 1)
      BEGIN
            IF EXISTS(SELECT * FROM  [bt000] WHERE [Guid] = @DistTypGuid AND  [bAutoPost] = 1)
            BEGIN
				  EXEC prcDisableTriggers 'ms000'
                  SET @c = CURSOR FAST_FORWARD FOR 
                        SELECT  [Guid] FROM [#BU]
                  OPEN @c     
                  
                  FETCH  FROM @c  INTO @Guid
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                        EXEC [dbo].[prcBill_Post1] @Guid, @Post
                        FETCH  FROM @c  INTO @Guid
                  END 
				  CLOSE @c
				  DEALLOCATE @c
                  ALTER TABLE ms000 ENABLE TRIGGER ALL
            END
      END
      ---------------------------------
      ---------------------------------
 
      IF (@DeleteOldBill > 0) 
      BEGIN 
            UPDATE bu SET IsPosted = 0 FROM [bu000] bu INNER JOIN [#Bill] B on bu.Guid = b.Guid 
            IF @MatCondGuid <> 0X00 OR @GrpGuid <> 0X00 
            BEGIN 
				  EXEC prcDisableTriggers 'ms000'
                  DELETE bi FROM bi000 bi 
				  INNER JOIN [#Bill] bu on bi.ParentGuid = bu.Guid 
				  INNER JOIN [#Mat] C ON [mtGUID] = bi.[MatGuid] 
				  WHERE [dbo].[fnGetUserBillSec_Delete] ([dbo].[fnGetCurrentUserGUID](), [bu].[TypeGuid]) >= [bu].[Security]
                  
                  DELETE bu from BU000 bu
				  WHERE Guid NOT IN (SELECT DISTINCT ParentGuid FROM bi000) 
				  AND [dbo].[fnGetUserBillSec_Delete] ([dbo].[fnGetCurrentUserGUID](), [bu].[TypeGuid]) >= [bu].[Security]
                  
                  UPDATE #Bill SET STATE = 1 WHERE Guid NOT IN (Select DISTINCT Guid FROM bu000) 
                  
                  ALTER TABLE ms000 ENABLE TRIGGER ALL
            END 
            ELSE 
                  DELETE bu FROM [bu000] bu INNER JOIN [#Bill] B on bu.Guid = b.Guid 
				  WHERE [dbo].[fnGetUserBillSec_Delete] ([dbo].[fnGetCurrentUserGUID](), [bu].[TypeGuid]) >= [bu].[Security]
			
			EXECUTE @SNIntegrateErrorFlag = prcCheckSNIntegrate @DeleteOldBillAsInt
			IF(@SNIntegrateErrorFlag = 1)
			BEGIN
				ROLLBACK
				SELECT 1 As SNErrorFlag
				RETURN   
			END
      END 
      DELETE mc000 where asc2 = 'COLBILL1000D79016AC-3495-449C-8EA7-41895239F0CB'
      COMMIT 
      
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

###########################
CREATE PROCEDURE prcCheckSNIntegrate @DeleteOldBill  INT = 0
AS
BEGIN
	SET NOCOUNT ON
	SELECT sn.snGuid, SUM(CASE WHEN bt.btIsInput = 1 THEN 1 ELSE -1 END) AS qty
	INTO #result
	FROM vwMt mt 
		INNER JOIN vwbubi			AS b  ON b.biMatPtr = mt.mtGUID AND b.buGUID = b.biParent
		INNER JOIN vwbt				AS bt ON bt.btGUID = b.buType
		INNER JOIN vwExtended_SN	AS sn ON sn.buGUID = b.buGUID AND sn.biGUID = b.biGUID AND sn.biMatPtr = b.biMatPtr
	WHERE 
		mt.mtForceInSN = 1 AND mt.mtForceOutSN = 1 AND (b.buIsPosted = 1 OR bt.btAutoPost = 1)
	GROUP BY 
		sn.snGuid
	HAVING 
		SUM(CASE WHEN bt.btIsInput = 1 THEN 1 ELSE -1 END) NOT IN (-@DeleteOldBill, 0, 1, 1 + @DeleteOldBill) -- (0,1) if @DeleteOldBill =0 else (-1,0,1,2)
	
	
	INSERT INTO #result
	SELECT sn.snGuid, SUM(CASE WHEN bt.btIsInput = 1 THEN 1 ELSE -1 END) AS qty
	FROM vwMt mt 
		INNER JOIN vwbubi			AS b  ON b.biMatPtr = mt.mtGUID AND b.buGUID = b.biParent
		INNER JOIN vwbt				AS bt ON bt.btGUID = b.buType
		INNER JOIN vwExtended_SN	AS sn ON sn.buGUID = b.buGUID AND sn.biGUID = b.biGUID AND sn.biMatPtr = b.biMatPtr
	WHERE 
		(mt.mtForceOutSN = 1 OR mt.mtForceInSN = 1 OR (mt.mtForceOutSN = 0 AND mt.mtForceInSN = 0)) AND (b.buIsPosted = 1 OR bt.btAutoPost = 1)
	GROUP BY
		sn.snGuid
	HAVING 
		SUM(CASE WHEN bt.btIsInput = 1 THEN 1 ELSE -1 END) NOT IN (-1 - @DeleteOldBill, -1, 0, 1, 1 + @DeleteOldBill) -- (-1,0,1) if @DeleteOldBill =0 else (-2,-1,0,1,2)
	
	
	IF((SELECT COUNT(qty) AS SNsIssuesAfterDelSelectedBill FROM #result) > 0)
	BEGIN
		RETURN SELECT 1;
	END
	RETURN SELECT 0;
 END
###########################
#END