################################################################################
CREATE PROCEDURE prcPOSSD_Shift_GenerateDeliveryFeeEntry
-- Params -------------------------------
	@ShiftGuid    UNIQUEIDENTIFIER
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
	DECLARE @CEValue		             FLOAT
	DECLARE @ENNote			             NVARCHAR(250)
	DECLARE @AccGuid		             UNIQUEIDENTIFIER
	DECLARE @ShiftControlAccGUID         UNIQUEIDENTIFIER
	DECLARE @DefCurrencyGUID			 UNIQUEIDENTIFIER 
	DECLARE @EntryGUID					 UNIQUEIDENTIFIER 
	DECLARE @BranchGuid				     UNIQUEIDENTIFIER
	DECLARE @CostGUID				     UNIQUEIDENTIFIER
	DECLARE @NewCENumber				 INT
	DECLARE @EntryNote					 NVARCHAR(1000)
	DECLARE @ENCreditAccGUID			 UNIQUEIDENTIFIER
	DECLARE @ENDebitAccGUID				 UNIQUEIDENTIFIER


	DECLARE @User UNIQUEIDENTIFIER = (SELECT TOP 1 [GUID] FROM us000 WHERE [bAdmin] = 1 AND [Type] = 0 ORDER BY [Number])	
	EXEC prcConnections_Add @User, 0
	EXEC prcConnections_SetIgnoreWarnings 1


	DECLARE @language			   INT
	
	DECLARE @txt_DeliveryFee	   NVARCHAR(250)
	DECLARE @txt_Customer          NVARCHAR(250)
	DECLARE @txt_SaleTransaction   NVARCHAR(250)
	DECLARE @txt_Driver			   NVARCHAR(250)
	DECLARE @txt_ShiftNumber	   NVARCHAR(250)
	DECLARE @txt_Station	       NVARCHAR(250)
	DECLARE @txt_Employee	       NVARCHAR(250)
	DECLARE @txt_DeliveryFeeEntry  NVARCHAR(250)
	

	SET @language				= [dbo].[fnConnections_getLanguage]()
	SET @txt_DeliveryFee		= [dbo].[fnStrings_get]('POSSD\OrderDeliveryFee',	   @language) 
	SET @txt_Customer			= [dbo].[fnStrings_get]('POSSD\ForCustomer',		   @language)
	SET @txt_SaleTransaction    = [dbo].[fnStrings_get]('POSSD\InSalesTicket',		   @language) 
	SET @txt_Driver				= [dbo].[fnStrings_get]('POSSD\AndDriver',			   @language) 
	SET @txt_ShiftNumber		= [dbo].[fnStrings_get]('POSSD\ShiftNumber',           @language)
	SET @txt_Station			= [dbo].[fnStrings_get]('POSSD\Station',               @language)
	SET @txt_Employee			= [dbo].[fnStrings_get]('POSSD\Employee',              @language)
	SET @txt_DeliveryFeeEntry	= [dbo].[fnStrings_get]('POSSD\OrderDeliveryFeeEntry', @language)
	
	

	SET @BranchGuid		 = (SELECT TOP 1 [GUID] FROM br000 ORDER BY Number)
	SET @NewCENumber	 = (SELECT ISNULL(MAX(Number), 0) + 1 FROM ce000  WHERE Branch = ISNULL(@BranchGuid, 0x0))
	SET @DefCurrencyGUID = (SELECT TOP 1 [GUID] FROM my000 WHERE CurrencyVal = 1 ORDER BY [Number])
	SET @EntryGUID		 = NEWID()
	SET @EntryNote		 = (SELECT 
								@txt_DeliveryFeeEntry + SH.Code
							  + @txt_Station + CASE @language WHEN 0 THEN S.Name ELSE CASE S.LatinName WHEN '' THEN S.Name ELSE S.LatinName END END + '.'
							  + @txt_Employee + CASE @language WHEN 0 THEN E.Name ELSE CASE E.LatinName WHEN '' THEN E.Name ELSE E.LatinName END END
							FROM 
								POSSDShift000 SH
								INNER JOIN POSSDStation000 S ON SH.StationGUID = S.[GUID]
								INNER JOIN POSSDEmployee000 E ON SH.EmployeeGUID = E.[GUID]
							WHERE 
								SH.[GUID] = @ShiftGuid)


	SELECT @CEValue = SUM(OI.DeliveryFee)
	FROM 
		POSSDOrderEvent000 OE 
		INNER JOIN POSSDTicketOrderInfo000 OI ON OE.OrderGUID = OI.[GUID]
	WHERE 
		OE.ShiftGUID = @ShiftGuid
		AND OE.[Event] = 10
		AND OI.DeliveryFee > 0
	 

	INSERT INTO @CE
	SELECT 1								AS [Type],
		   @NewCENumber					    AS Number,
		   GETDATE()						AS [Date],
		   @CEValue							AS Debit,
		   @CEValue							AS Credit,
		   @EntryNote						AS Notes,
		   1								AS CurrencyVal,
		   0								AS IsPosted,
		   0								AS [State],
		   1								AS [Security],
		   0								AS Num1,
		   0								AS Num2,
		   ISNULL(@BranchGuid, 0x0)			AS Branch,
		   @EntryGUID						AS [GUID],
		   @DefCurrencyGUID					AS CurrencyGUID,
		   0x0								AS TypeGUID,
		   0								AS IsPrinted,
		   GETDATE()						AS PostDate



	DECLARE @AllOrderWithDeliveryFee CURSOR 
	SET @AllOrderWithDeliveryFee = CURSOR FAST_FORWARD FOR
	SELECT 
		OI.DeliveryFee, 
		@txt_DeliveryFee + CAST(OI.Number AS NVARCHAR(50))
	  + @txt_Customer + CASE @language WHEN 0 THEN CU.CustomerName ELSE CASE CU.LatinName WHEN '' THEN CU.CustomerName ELSE CU.LatinName END END
	  + @txt_SaleTransaction + CAST(T.Number AS NVARCHAR(50))
	  + @txt_Driver + CASE @language WHEN 0 THEN D.Name ELSE CASE D.LatinName WHEN '' THEN D.Name ELSE D.LatinName END END + '.'
	  + @txt_ShiftNumber + SH.Code
	  + @txt_Station + CASE @language WHEN 0 THEN ST.Name ELSE CASE ST.LatinName WHEN '' THEN ST.Name ELSE ST.LatinName END END
	  + @txt_Employee + CASE @language WHEN 0 THEN E.Name ELSE CASE E.LatinName WHEN '' THEN E.Name ELSE E.LatinName END END,
		SO.DeliveryFeeAccountGUID, 
		ST.ShiftControlGUID, 
		S.CostCenterGUID
	FROM 
		POSSDOrderEvent000 OE 
		INNER JOIN POSSDTicketOrderInfo000 OI ON OE.OrderGUID = OI.[GUID]
		INNER JOIN POSSDTicket000 T ON OI.TicketGUID = T.[GUID]
		INNER JOIN POSSDShift000 SH ON OE.ShiftGUID = SH.[GUID]
		INNER JOIN POSSDStation000 ST ON SH.StationGUID = ST.[GUID]
		INNER JOIN POSSDStationOrder000 SO ON SO.StationGUID = ST.[GUID]
		INNER JOIN cu000 CU ON T.CustomerGUID = CU.[GUID]
		INNER JOIN POSSDDriver000 D ON OI.DriverGUID = D.[GUID]
		INNER JOIN POSSDEmployee000 E ON SH.EmployeeGUID = E.[GUID]
		LEFT  JOIN POSSDSalesman000 S ON T.SalesmanGUID = S.[GUID]
	WHERE 
		OE.ShiftGUID = @ShiftGuid
		AND OE.[Event] = 10
		AND OI.DeliveryFee > 0
	OPEN @AllOrderWithDeliveryFee;

		FETCH NEXT FROM @AllOrderWithDeliveryFee INTO @ENValue, @ENNote, @AccGuid, @ShiftControlAccGUID, @CostGUID;
		WHILE (@@FETCH_STATUS = 0)
		BEGIN  
			SET @ENNumber = @ENNumber + 1;

		   INSERT INTO @EN
		   SELECT @ENNumber					AS Number,
				  GETDATE()					AS [Date],
				  @ENValue					AS Debit,
				  0							AS Credit,
				  @ENNote					AS Note,
				  1							AS CurrencyVal,
				  NEWID()					AS [GUID],
				  @EntryGUID				AS ParentGUID,
				  @ShiftControlAccGUID		AS AccountGUID,
				  @DefCurrencyGUID			AS CurrencyGUID,
				  0x0						AS CostGUID,
				  @AccGuid					AS ContraAccGUID
		

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
				  @AccGuid					AS AccountGUID,
				  @DefCurrencyGUID			AS CurrencyGUID,
				  0x0						AS CostGUID,
				  @ShiftControlAccGUID		AS ContraAccGUID

		FETCH NEXT FROM @AllOrderWithDeliveryFee INTO @ENValue, @ENNote, @AccGuid, @ShiftControlAccGUID, @CostGUID;
		END

		CLOSE      @AllOrderWithDeliveryFee;
		DEALLOCATE @AllOrderWithDeliveryFee;

	INSERT INTO @ER
	SELECT NEWID()		AS [GUID],
		   @EntryGUID	AS EntryGUID,
		   @ShiftGuid	AS ParentGUID,
		   712			AS ParentType,
		   S.Code		AS ParentNumber
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
										AND ER.ParentType = 712 )

	DECLARE @HasOrderWithDeliveryFee FLOAT = ( SELECT ISNULL(SUM(OI.DeliveryFee), 0)
												FROM 
													POSSDOrderEvent000 OE 
													INNER JOIN POSSDTicketOrderInfo000 OI ON OE.OrderGUID = OI.[GUID]
												WHERE 
													OE.ShiftGUID = @ShiftGuid
													AND OE.[Event] = 10
													AND OI.DeliveryFee > 0 )

	IF( @CheckGenerateEntry > 0 OR @HasOrderWithDeliveryFee = 0 )
	BEGIN
		SELECT 1 AS IsGenerated
	END
	ELSE
	BEGIN
		SELECT 0 AS IsGenerated
	END
#################################################################
#END
