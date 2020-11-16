#####################################################################
CREATE PROCEDURE prcNotCollectedBills
      @FromND           BIT, 
      @StartDate        DATETIME, 
      @EndDate          DATETIME, 
      @From             INT, 
      @To               INT, 
      @Acc              UNIQUEIDENTIFIER, 
      @Customer         UNIQUEIDENTIFIER, 
      @CustCondGuid     UNIQUEIDENTIFIER, 
      @MatCondGuid      UNIQUEIDENTIFIER = 0x00, 
      @Cost             UNIQUEIDENTIFIER = 0X00, 
      @GrpGuid          UNIQUEIDENTIFIER = 0X00, 
      @Pay              [INT] = -1,--0 CASH 1 LATER -1 LATER cASH 
      @NotesContain     [NVARCHAR](256) = '',-- NULL or Contain Text  
      @NotesNotContain  [NVARCHAR](256) = '', -- NULL or Not Contain  
      @BillCondGuid     UNIQUEIDENTIFIER = 0X00, 
      @CostFlag         INT = 0, 
      @SrcBillGuid      UNIQUEIDENTIFIER = 0X00,
      @ShowBillsWithoutCust BIT = 0
AS 
      SET NOCOUNT ON 
      DECLARE @Sql NVARCHAR(max), @Criteria NVARCHAR(2000)
      CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT]) 
      ----------------------------------------------------
      CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])
      INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcBillGuid
      ----------------------------------------------------
      CREATE TABLE [#Mat] ( [mtGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
      INSERT INTO [#Mat] EXEC [prcGetMatsList]  NULL, @GrpGuid,-1,@MatCondGuid 
      ----------------------------------------------------
      CREATE TABLE [#Cost] ( [Number] [UNIQUEIDENTIFIER]) 
      INSERT INTO  [#Cost] select [GUID] from [fnGetCostsList]( @Cost) 
      IF @Cost = 0x00 
            INSERT INTO [#Cost] VALUES(0X00) 
      ----------------------------------------------------
      CREATE TABLE [#Cust] ( [Number] [UNIQUEIDENTIFIER], [Sec] [INT])  
      INSERT INTO [#Cust] EXEC [prcGetCustsList]  @Customer, @Acc, @CustCondGuid  
      ----------------------------------------------------
      SELECT [c].[Number] , [Sec],ACCOUNTGUID ,[customername] INTO [#Cust2] FROM  [#Cust] [c] INNER JOIN [cu000] [cu] ON [cu].[Guid] = [c].[Number] 
      ----------------------------------------------------
      CREATE TABLE #Bill 
      ( 
     [TypeGuid]    UNIQUEIDENTIFIER, 
            [Security]    INT,  
            [Guid]    UNIQUEIDENTIFIER,  
            [Number]    FLOAT,  
            [CustGuid]    UNIQUEIDENTIFIER,  
            [CurrencyGUID]        UNIQUEIDENTIFIER, 
            [StoreGUID]           UNIQUEIDENTIFIER, 
            [CustAcc]    UNIQUEIDENTIFIER,  
            [Branch]    UNIQUEIDENTIFIER,  
            [CurrencyVal]         FLOAT, 
            [CustomerName]        NVARCHAR(250) COLLATE ARABIC_CI_AI, 
            [Type]                NVARCHAR(250) COLLATE ARABIC_CI_AI, 
            [Date]                DATETIME, 
            [CostGUID]    UNIQUEIDENTIFIER,  
            [PayType]    INT 
      )
      -------------------------------------------------------------------------------------------------------  

	  CREATE TABLE #BillCond
	  ( 
            [buGuid] [UNIQUEIDENTIFIER], 
            [biGuid] [UNIQUEIDENTIFIER]
	  ) 

      ------------------------------------------------------------------------------------------------------- 
	IF @BillCondGuid <> 0X00  
	BEGIN  
	    SET @Sql = 'INSERT INTO #BillCond SELECT [buGuid],[biGuid] FROM vwBuBi_Address ' 
		DECLARE @CurrencyGUID UNIQUEIDENTIFIER
		SET @CurrencyGUID = (SELECT TOP 1 [guid] FROM [my000] WHERE [CurrencyVal] = 1)
		SET @Criteria = [dbo].[fnGetBillConditionStr] (NULL, @BillCondGuid, @CurrencyGUID) 
		IF @Criteria <> ''
			SET @Criteria = ' WHERE (' + @Criteria + ') ' 
		SET @Sql = @Sql + @Criteria 
		EXEC(@Sql)
	END 
      ------------------------------------------------------------------------------------------------------- 

      SET @Sql = 'INSERT INTO #Bill SELECT ' 
      SET @Sql = @Sql + ' DISTINCT'  
      Declare @LeftOrInner NVARCHAR(10)
      IF (@ShowBillsWithoutCust > 0)
            SET @LeftOrInner = ' LEFT '
      ELSE
            SET @LeftOrInner = ' INNER '
      SET @Sql = @Sql + ' [bu].[buType] [TypeGuid], [bu].[buSecurity] [Security], [bu].[buGuid] [Guid], [bu].[buNumber] [Number], [bu].[buCustPtr] [CustGuid], [bu].[buCurrencyPtr] [CurrencyGUID], [bu].[buStorePtr] [StoreGUID], [AccountGUID],bu.[buBranch] [Branch], [bu].[buCurrencyVal] [CurrencyVal], [CustomerName], [bt].[btName] [Name], bu.[buDate] [Date], [bu].[buCostPtr] [CostGuid], bu.[buPayType] [PayType] 
       FROM [vwbubi] [bu] ' + @LeftOrInner + ' JOIN [#Cust2] [cu] ON [bu].[buCustPtr] = [cu].[Number]  
       INNER JOIN vwbt bt ON bt.[btGuid] = bu.[buType]
        INNER JOIN #BillTbl SRC ON [SRC].[Type] = [bu].[buType]'
		IF @BillCondGuid <> 0X00  
		SET @Sql = @Sql +'INNER JOIN #BillCond bc ON [bc].[buGuid] = [bu].[buGuid] AND bc.[biGuid] = bu.[biGuid]' 

      IF ((@CostFlag & 0X00001) > 0) 
            SET @Sql = @Sql + 'INNER JOIN [#Cost] co ON co.[Number] = bu.[buCostPtr] '  
      IF ((@CostFlag & 0X00002) > 0) 
            SET @Sql = @Sql + 'INNER JOIN  [#Cost] co2 ON [bu].[biCostPtr] = co2.[Number] '  
      SET @Sql = @Sql + ' WHERE [bu].buGUID NOT IN (SELECT CollectedGUID FROM BillColected000)' 

	IF (@ShowBillsWithoutCust > 0)
	BEGIN
		IF (@Customer <> 0x00)
   SET @Sql = @Sql + ' AND [buCustPtr] = ''' + CAST(@Customer AS NVARCHAR(36)) + ''' ' 
		IF (@Acc <> 0x00)
			SET @Sql = @Sql + ' AND [AccountGuid] = ''' + CAST(@Acc AS NVARCHAR(36)) + ''' '
	END
	
      IF @Pay <> -1  
            SET @Sql = @Sql + ' AND ([buPayType] = ' + CAST(@Pay AS NVARCHAR(25)) + ') '   
      IF @FromND = 0 
            SET @Sql = @Sql + ' AND ([buDate] BETWEEN ' + [dbo].[fnDateString](@StartDate) + ' AND ' + [dbo].[fnDateString](@EndDate) + ') ' 
      IF @FromND = 1 
            SET @Sql = @Sql + ' AND ([bu].[buNumber] BETWEEN ' + cast (@From AS NVARCHAR(20)) + ' AND ' + CAST (@To AS NVARCHAR (20)) + ') ' 
      
	  IF @NotesContain <>  '' 
            SET @Sql = @Sql + ' AND ([bu].[buNotes] LIKE ''%'+  @NotesContain + '%'') ' 
      IF @NotesNotContain <> '' 
            SET @Sql = @Sql + ' AND ([bu].[buNotes] NOT LIKE ''%' +  @NotesNotContain + '%'') '  
      EXEC(@Sql) 
	
      Exec [prcCheckSecurity] @Result = '#Bill' 
	-------------------------------------
      SELECT * FROM #Bill 
      ORDER BY [customername], [Date], [Type]
      
      SELECT * FROM #SecViol
#########################################################
#END