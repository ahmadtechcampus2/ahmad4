#################################################################
CREATE PROCEDURE prcPOSSD_Shift_GenerateGCCTaxEntry
-- Params -------------------------------
	@ShiftGuid    UNIQUEIDENTIFIER,
	@TicketType   INT
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	DECLARE @EN TABLE( [Number]			INT , 
					   [Date]			DATETIME,
					   [Debit]			FLOAT, 
					   [Credit]			FLOAT, 
					   [Notes]			NVARCHAR(255), 
					   [CurrencyVal]	FLOAT,
					   [GUID]			UNIQUEIDENTIFIER, 
					   [ParentGUID]		UNIQUEIDENTIFIER, 
					   [accountGUID]	UNIQUEIDENTIFIER, 
					   [CurrencyGUID]	UNIQUEIDENTIFIER,
					   [CostGUID]		UNIQUEIDENTIFIER,
					   [ContraAccGUID]  UNIQUEIDENTIFIER )
			   
	DECLARE @CE TABLE( [Type]		    INT,
					   [Number]		    INT,
					   [Date]		    DATETIME,
					   [Debit]		    FLOAT,
					   [Credit]		    FLOAT,
					   [Notes]		    NVARCHAR(1000) ,
					   [CurrencyVal]    FLOAT,
					   [IsPosted]	    INT,
					   [State]		    INT,
					   [Security]	    INT,
					   [Num1]		    FLOAT,
					   [Num2]	        FLOAT,
					   [Branch]		    UNIQUEIDENTIFIER,
					   [GUID]		    UNIQUEIDENTIFIER,
					   [CurrencyGUID]   UNIQUEIDENTIFIER,
					   [TypeGUID]		UNIQUEIDENTIFIER,
					   [IsPrinted]	    BIT,
					   [PostDate]		DATETIME )

	DECLARE @ER TABLE( [GUID]		    UNIQUEIDENTIFIER,
					   [EntryGUID]	    UNIQUEIDENTIFIER,
					   [ParentGUID]	    UNIQUEIDENTIFIER,
					   [ParentType]	    INT,
					   [ParentNumber]   INT )

	DECLARE @ENNumber			         INT = 0
	DECLARE @ENValue		             FLOAT
	DECLARE @ENNote			             NVARCHAR(250)
	DECLARE @AccGuid		             UNIQUEIDENTIFIER
	DECLARE @ShiftControlAccGUID         UNIQUEIDENTIFIER
	DECLARE @DefCurrencyGUID			 UNIQUEIDENTIFIER 
	DECLARE @EntryGUID					 UNIQUEIDENTIFIER 
	DECLARE @BranchGuid				     UNIQUEIDENTIFIER
	DECLARE @CostGUID				     UNIQUEIDENTIFIER
	DECLARE @NewCENumber				 INT
	DECLARE @EntryNote					 NVARCHAR(1000)
	DECLARE @DefaultCustGCCLocationGUID  UNIQUEIDENTIFIER
	DECLARE @DefaultCustGCCLocation	     NVARCHAR(250)
	DECLARE @DefaultCustName		     NVARCHAR(250)
	DECLARE @ENCreditAccGUID			 UNIQUEIDENTIFIER
	DECLARE @ENDebitAccGUID				 UNIQUEIDENTIFIER


	DECLARE @User UNIQUEIDENTIFIER = (SELECT TOP 1 [GUID] FROM us000 WHERE [bAdmin] = 1 AND [Type] = 0 ORDER BY [Number])	
	EXEC prcConnections_Add @User, 0
	EXEC prcConnections_SetIgnoreWarnings 1


	DECLARE @language			   INT
	DECLARE @txt_GCCTaxValue       NVARCHAR(50)
	DECLARE @txt_SaleTransaction   NVARCHAR(50)
	DECLARE @txt_Customer          NVARCHAR(50)
	DECLARE @txt_CustomerTransient NVARCHAR(50)
	DECLARE @txt_GCCLocation	   NVARCHAR(50)
	DECLARE @txt_Employee	       NVARCHAR(50)
	DECLARE @txt_Station	       NVARCHAR(50)
	DECLARE @txt_ShiftNumber	   NVARCHAR(50)
	DECLARE @txt_GCCTaxEntry       NVARCHAR(100)
	SET @language			   = [dbo].[fnConnections_getLanguage]()
	SET @txt_GCCTaxValue       = [dbo].[fnStrings_get]('POSSD\GCCTaxValueForMat',     @language) 
	SET @txt_SaleTransaction = CASE @TicketType WHEN 2 THEN [dbo].[fnStrings_get]('POSSD\SALESRETURN_TYPE', @language)		 
													   ELSE [dbo].[fnStrings_get]('POSSD\SALES_TYPE', @language) END
	SET @txt_Customer          = [dbo].[fnStrings_get]('POSSD\Customer',			  @language) 
	SET @txt_CustomerTransient = [dbo].[fnStrings_get]('POSSD\CustomerTransient',     @language) 
	SET @txt_GCCLocation	   = [dbo].[fnStrings_get]('POSSD\GCCLocation',           @language)
	SET @txt_Employee	       = [dbo].[fnStrings_get]('POSSD\Employee',              @language)
	SET @txt_Station	       = [dbo].[fnStrings_get]('POSSD\Station',				  @language)
	SET @txt_ShiftNumber	   = [dbo].[fnStrings_get]('POSSD\ShiftNumber',           @language)
	SET @txt_GCCTaxEntry       = CASE @TicketType WHEN 2 THEN [dbo].[fnStrings_get]('POSSD\GCCTaxSalesReturnEntry', @language)		 
										                 ELSE [dbo].[fnStrings_get]('POSSD\GCCTaxSalesEntry', @language) END
	

	SET @BranchGuid		 = (SELECT TOP 1 [GUID] FROM br000 ORDER BY Number)
	SET @NewCENumber	 = (SELECT ISNULL(MAX(Number), 0) + 1 FROM ce000  WHERE Branch = ISNULL(@BranchGuid, 0x0))
	SET @DefCurrencyGUID = (SELECT TOP 1 [GUID] FROM my000 WHERE CurrencyVal = 1 ORDER BY [Number])
	SET @EntryGUID		 = NEWID()
	SET @EntryNote		 = (SELECT 
								@txt_GCCTaxEntry + SH.Code 
							  + @txt_Station + CASE @language WHEN 0 THEN S.Name ELSE CASE S.LatinName WHEN '' THEN S.Name ELSE S.LatinName END END
							  + @txt_Employee + CASE @language WHEN 0 THEN E.Name ELSE CASE E.LatinName WHEN '' THEN E.Name ELSE E.LatinName END END
							FROM 
								POSSDShift000 SH
								INNER JOIN POSSDStation000  S ON SH.StationGUID  = S.[GUID]
								LEFT JOIN  POSSDEmployee000 E ON SH.EmployeeGUID = E.[GUID]
							WHERE
								SH.[GUID] = @ShiftGuid)
	SELECT 
		@DefaultCustGCCLocationGUID = GCCLocation.VATAccGUID,
		@DefaultCustGCCLocation = CASE @language WHEN 0 THEN GCCLocation.Name ELSE CASE GCCLocation.LatinName WHEN '' THEN GCCLocation.Name ELSE GCCLocation.LatinName END END,
		@DefaultCustName = CASE @language WHEN 0 THEN CU.CustomerName ELSE CASE CU.LatinName WHEN '' THEN CU.CustomerName ELSE CU.LatinName END END
	FROM 
		POSSDStation000 S 
		INNER JOIN POSSDShift000 SH ON SH.StationGUID = S.[GUID]
		INNER JOIN bt000 BT ON CASE @TicketType WHEN 0 THEN S.SaleBillTypeGUID ELSE S.SaleReturnBillTypeGUID END = BT.[GUID]
		INNER JOIN cu000 CU ON BT.CustAccGuid = CU.[GUID]
		INNER JOIN GCCCustLocations000 GCCLocation ON CU.GCCLocationGUID = GCCLocation.[GUID]
	WHERE
		SH.[GUID] = @ShiftGuid 
	 

	INSERT INTO @CE
	SELECT 1														AS [Type],
		   @NewCENumber					    						AS Number,
		   GETDATE()												AS [Date],
		   (SELECT SUM(T.TaxTotal) 
			FROM POSSDTicket000 T 
			WHERE T.ShiftGUID = @ShiftGuid AND T.[State]  = 0 AND T.[Type] = @TicketType AND T.TaxTotal <> 0)		AS Debit,
		   (SELECT SUM(T.TaxTotal) 
			FROM POSSDTicket000 T
			WHERE T.ShiftGUID = @ShiftGuid AND T.[State]  = 0 AND  T.[Type] = @TicketType AND T.TaxTotal <> 0)		AS Credit,
		   @EntryNote												AS Notes,
		   1														AS CurrencyVal,
		   0														AS IsPosted,
		   0														AS [State],
		   1														AS [Security],
		   0														AS Num1,
		   0														AS Num2,
		   ISNULL(@BranchGuid, 0x0)									AS Branch,
		   @EntryGUID												AS [GUID],
		   @DefCurrencyGUID											AS CurrencyGUID,
		   0x0														AS TypeGUID,
		   0														AS IsPrinted,
		   GETDATE()												AS PostDate



	DECLARE @AllTicketItemsWithGCCTax CURSOR 
	SET @AllTicketItemsWithGCCTax = CURSOR FAST_FORWARD FOR
	SELECT  
		TI.Tax,
		@txt_GCCTaxValue + CASE @language WHEN 0 THEN MT.Name ELSE CASE MT.LatinName WHEN '' THEN MT.Name ELSE MT.LatinName END END 
	  + @txt_SaleTransaction + CAST(T.Number AS NVARCHAR(50)) 
	  + @txt_Customer + CASE @language WHEN 0 THEN ISNULL(CU.CustomerName, @DefaultCustName) ELSE CASE ISNULL(CU.LatinName, @DefaultCustName) WHEN '' THEN ISNULL(CU.CustomerName, @DefaultCustName) ELSE ISNULL(CU.LatinName, @DefaultCustName) END END
	  + @txt_GCCLocation +  CASE @language WHEN 0 THEN ISNULL(GCCLocation.Name, @DefaultCustGCCLocation) ELSE CASE ISNULL(GCCLocation.LatinName, @DefaultCustGCCLocation) WHEN '' THEN ISNULL(GCCLocation.Name, @DefaultCustGCCLocation) ELSE ISNULL(GCCLocation.LatinName, @DefaultCustGCCLocation) END END
	  + @txt_Employee + CASE @language WHEN 0 THEN E.Name ELSE CASE E.LatinName WHEN '' THEN E.Name ELSE E.LatinName END END
	  + @txt_Station + CASE @language WHEN 0 THEN C.Name ELSE CASE C.LatinName WHEN '' THEN C.Name ELSE C.LatinName END END
	  + @txt_ShiftNumber + S.Code,
		GCCLocation.VATAccGUID AS accountGUID,
		C.ShiftControlGUID     AS ShiftControlAccGUID,
		SM.CostCenterGUID      AS CostGUID
	FROM 
		POSSDTicket000 T
		INNER JOIN POSSDTicketItem000 TI           ON TI.TicketGUID		 = T.[GUID]
		LEFT JOIN cu000 CU				           ON T.CustomerGUID	 = CU.[GUID]
		LEFT JOIN GCCCustLocations000 GCCLocation  ON CU.GCCLocationGUID = GCCLocation.[GUID]
		LEFT JOIN  POSSDShift000 S				   ON T.ShiftGuid        = S.[GUID]
		LEFT JOIN  POSSDStation000 C			   ON S.StationGUID      = C.[GUID]
		LEFT JOIN  POSSDEmployee000 E			   ON S.EmployeeGUID     = E.[GUID]
		LEFT JOIN  POSSDSalesman000 SM			   ON T.SalesmanGUID     = SM.[GUID]
		LEFT JOIN  mt000 MT						   ON TI.MatGUID		 = MT.[GUID]
	WHERE
		T.ShiftGUID    = @ShiftGuid
		AND	T.[State]  = 0
		AND T.[Type] = @TicketType
		AND T.TaxTotal <> 0
	OPEN @AllTicketItemsWithGCCTax;

		FETCH NEXT FROM @AllTicketItemsWithGCCTax INTO @ENValue, @ENNote, @AccGuid, @ShiftControlAccGUID, @CostGUID;
		WHILE (@@FETCH_STATUS = 0)
		BEGIN  
			SET @ENNumber = @ENNumber + 1;

			SET @ENCreditAccGUID = (CASE @TicketType WHEN 0 THEN @ShiftControlAccGUID ELSE ISNULL(@AccGuid, @DefaultCustGCCLocationGUID) END)
			SET @ENDebitAccGUID  = (CASE @TicketType WHEN 0 THEN ISNULL(@AccGuid, @DefaultCustGCCLocationGUID) ELSE @ShiftControlAccGUID END)

		   INSERT INTO @EN
		   SELECT @ENNumber					AS Number,
				  GETDATE()					AS [Date],
				  @ENValue					AS Debit,
				  0							AS Credit,
				  @ENNote					AS Note,
				  1							AS CurrencyVal,
				  NEWID()					AS [GUID],
				  @EntryGUID				AS ParentGUID,
				  @ENCreditAccGUID			AS accountGUID,
				  @DefCurrencyGUID			AS CurrencyGUID,
				  0x0						AS CostGUID,
				  @ENDebitAccGUID			AS ContraAccGUID
		

			 SET @ENNumber = @ENNumber + 1;

		   INSERT INTO @EN
		   SELECT @ENNumber					AS Number,
				  GETDATE()					AS [Date],
				  0							AS Debit,
				  @ENValue					AS Credit,
				  @ENNote					AS Note,
				  1							AS CurrencyVal,
				  NEWID()					AS [GUID],
				  @EntryGUID				AS ParentGUID,
				  @ENDebitAccGUID			AS accountGUID,
				  @DefCurrencyGUID			AS CurrencyGUID,
				  0x0						AS CostGUID,
				  @ENCreditAccGUID			AS ContraAccGUID

		FETCH NEXT FROM @AllTicketItemsWithGCCTax INTO @ENValue, @ENNote, @AccGuid, @ShiftControlAccGUID, @CostGUID;
		END

		CLOSE      @AllTicketItemsWithGCCTax;
		DEALLOCATE @AllTicketItemsWithGCCTax;

	INSERT INTO @ER
	SELECT NEWID()										 AS [GUID],
		   @EntryGUID									 AS EntryGUID,
		   @ShiftGuid									 AS ParentGUID,
		   CASE @TicketType WHEN 0 THEN 710 ELSE 711 END AS ParentType,
		   S.Code										 AS ParentNumber
	 FROM POSSDShift000 S
	 WHERE S.[GUID]  = @ShiftGuid

	------------- FINAL ENSERT -------------

	IF((SELECT COUNT(*) FROM @EN) > 0)
	BEGIN

			INSERT INTO ce000 ( [Type],
							    [Number],
							    [Date],
							    [Debit],
							    [Credit],
							    [Notes],
							    [CurrencyVal],
							    [IsPosted],
							    [State],
							    [Security],
							    [Num1],
							    [Num2],
							    [Branch],
							    [GUID],
							    [CurrencyGUID],
							    [TypeGUID],
							    [IsPrinted],
							    [PostDate] ) SELECT * FROM @CE

			INSERT INTO en000 ( [Number],			
								[Date],
								[Debit],
								[Credit],			
								[Notes],		
								[CurrencyVal],
								[GUID],		
								[ParentGUID],	
								[accountGUID],
								[CurrencyGUID],
								[CostGUID],
								[ContraAccGUID] ) SELECT * FROM @EN

			INSERT INTO er000 ( [GUID],
							    [EntryGUID],
							    [ParentGUID],
							    [ParentType],
							    [ParentNumber] ) SELECT * FROM @ER


			EXEC prcConnections_SetIgnoreWarnings 1
			UPDATE ce000 SET [IsPosted] = 1 WHERE [GUID] = @EntryGUID
			EXEC prcConnections_SetIgnoreWarnings 0
	END

	DECLARE @CheckGenerateEntry INT = (	SELECT COUNT(*) 
										FROM er000 ER
										INNER JOIN ce000 CE ON ER.EntryGUID = CE.[GUID]
										INNER JOIN en000 EN ON CE.[GUID]    = EN.ParentGUID
										WHERE ER.ParentGUID = @ShiftGuid
										AND ER.ParentType = CASE @TicketType WHEN 0 THEN 710 ELSE 711 END )

	DECLARE @HasTicketItemsWithGCCTax FLOAT = ( SELECT ISNULL(SUM(T.TaxTotal), 0)
											    FROM POSSDTicket000 T
											    WHERE T.ShiftGUID = @ShiftGuid AND T.[State] = 0 AND T.[Type] = @TicketType )

	IF( @CheckGenerateEntry > 0 OR @HasTicketItemsWithGCCTax = 0 )
	BEGIN
		SELECT 1 AS IsGenerated
	END
	ELSE
	BEGIN
		SELECT 0 AS IsGenerated
	END
#################################################################
#END 