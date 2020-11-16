################################################################################
CREATE PROCEDURE prcPOSSD_Shift_GenerateBankCardsEntry
-- Params -------------------------------
	@ShiftGuid				UNIQUEIDENTIFIER
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

	DECLARE @ENNumber			        INT = 0
	DECLARE @ENValue		            FLOAT
	DECLARE @ENNote			            NVARCHAR(250)
	DECLARE @AccGuid		            UNIQUEIDENTIFIER
	DECLARE @ShiftControlAccGUID        UNIQUEIDENTIFIER
	DECLARE @DefCurrencyGUID			UNIQUEIDENTIFIER 
	DECLARE @EntryGUID					UNIQUEIDENTIFIER 
	DECLARE @BranchGuid				    UNIQUEIDENTIFIER
	DECLARE @CostGUID				    UNIQUEIDENTIFIER
	DECLARE @NewCENumber				INT
	DECLARE @EntryNote					NVARCHAR(1000)


	DECLARE @language			INT
	DECLARE @txt_BankSaleEntry	NVARCHAR(250)
	DECLARE @txt_POSShift		NVARCHAR(250)
	DECLARE @txt_POSEmployee	NVARCHAR(250)
	DECLARE @txt_BankCard		NVARCHAR(250)
	DECLARE @txt_SalesType		NVARCHAR(250)
	SET @language = [dbo].[fnConnections_getLanguage]() 
	SET @txt_BankSaleEntry = [dbo].[fnStrings_get]('POSSD\BANK_SALE_ENTRY',     @language) 
	SET @txt_POSShift	   = [dbo].[fnStrings_get]('POSSD\BANK_ENTRY_SHIFT',    @language)
	SET @txt_POSEmployee   = [dbo].[fnStrings_get]('POSSD\BANK_ENTRY_EMPLOYEE', @language) 
	SET @txt_BankCard	   = [dbo].[fnStrings_get]('POSSD\BANK_CARD',           @language) 
	SET @txt_SalesType	   = [dbo].[fnStrings_get]('POSSD\SALES_TYPE',          @language) 


	 SET @EntryNote = ( SELECT  @txt_BankSaleEntry 
							  + CAST(C.Code AS NVARCHAR(250)) + '-' + CASE @language WHEN 0 THEN C.Name ELSE CASE C.LatinName WHEN '' THEN C.Name ELSE C.LatinName END END
							  + @txt_POSShift + CAST(S.Code AS NVARCHAR(250)) + @txt_POSEmployee 
							  + CASE @language WHEN 0 THEN E.Name ELSE CASE E.LatinName WHEN '' THEN E.Name ELSE E.LatinName END END  
						FROM POSSDShift000 S
						LEFT JOIN POSSDStation000 C ON S.StationGUID = C.[Guid]
						LEFT JOIN POSSDEmployee000 E ON S.EmployeeGUID = E.[Guid]
						WHERE S.[GUID] =  @ShiftGuid )
	
	 SET @BranchGuid      = (SELECT TOP 1 [GUID] FROM br000 ORDER BY Number)
	 SET @NewCENumber     = (SELECT ISNULL(MAX(Number), 0) + 1 FROM ce000  WHERE Branch = ISNULL(@BranchGuid, 0x0))
	 SET @DefCurrencyGUID = (SELECT TOP 1 [GUID] FROM my000 WHERE CurrencyVal = 1 ORDER BY [Number])
	 SET @EntryGUID       = NEWID()
	 

	INSERT INTO @CE
	SELECT 1																					 AS [Type],
		   @NewCENumber					    													 AS Number,
		   GETDATE()																			 AS [Date],

		   (SELECT SUM(TB.Value) 
			FROM POSSDTicket000 T INNER JOIN POSSDTicketBankCard000 TB ON T.[GUID] = TB.TicketGUID 
			WHERE T.ShiftGUID = @ShiftGuid AND T.[State]  = 0 )						             AS Debit,

		   (SELECT SUM(TB.Value) 
			FROM POSSDTicket000 T INNER JOIN POSSDTicketBankCard000 TB ON T.[GUID] = TB.TicketGUID 
			WHERE T.ShiftGUID = @ShiftGuid AND T.[State]  = 0 )									 AS Credit,

		   @EntryNote																			 AS Notes,
		   1																					 AS  CurrencyVal,
		   0																					 AS IsPosted,
		   0																					 AS [State],
		   1																					 AS [Security],
		   0																					 AS Num1,
		   0																					 AS Num2,
		   ISNULL(@BranchGuid, 0x0)																 AS Branch,
		   @EntryGUID																			 AS [GUID],
		   @DefCurrencyGUID																		 AS CurrencyGUID,
		   0x0																					 AS TypeGUID,
		   0																					 AS IsPrinted,
		   GETDATE()																			 AS PostDate



	DECLARE @AllShiftTicketsPayByBankCards CURSOR 
	SET @AllShiftTicketsPayByBankCards = CURSOR FAST_FORWARD FOR
	SELECT  TB.Value,
			@txt_BankCard + 
			CASE @language WHEN 0 THEN B.Name ELSE CASE B.LatinName WHEN '' THEN B.Name ELSE B.LatinName END END + 
			@txt_POSShift + CAST(S.Code AS NVARCHAR(250)) + @txt_SalesType + CAST(T.Number AS NVARCHAR(250)) +
			@txt_POSEmployee + CASE @language WHEN 0 THEN E.Name ELSE CASE E.LatinName WHEN '' THEN E.Name ELSE E.LatinName END END,
			B.ReceiveAccGUID     AS accountGUID,
			C.ShiftControlGUID   AS ShiftControlAccGUID,
			SM.CostCenterGUID    AS CostGUID
	FROM POSSDTicket000 T
	INNER JOIN POSSDTicketBankCard000 TB ON T.[GUID]	    = TB.TicketGUID
	LEFT JOIN  POSSDShift000 S			 ON T.ShiftGuid     = S.[GUID]
	LEFT JOIN  POSSDStation000 C		 ON S.StationGUID   = C.[Guid]
	LEFT JOIN  vwCuAc AC				 ON T.CustomerGuid  = AC.cuGUID
	LEFT JOIN  POSSDEmployee000 E		 ON S.EmployeeGUID  = E.[Guid]
	LEFT JOIN  BankCard000 B			 ON TB.BankCardGUID	= B.[GUID]
	LEFT JOIN  POSSDSalesman000 SM		 ON T.SalesmanGUID  = SM.[GUID]
	WHERE T.ShiftGUID = @ShiftGuid
	AND	  T.[State]  = 0
	OPEN @AllShiftTicketsPayByBankCards;	

		FETCH NEXT FROM @AllShiftTicketsPayByBankCards INTO @ENValue, @ENNote, @AccGuid, @ShiftControlAccGUID, @CostGUID;
		WHILE (@@FETCH_STATUS = 0)
		BEGIN  
			SET @ENNumber = @ENNumber + 1;

		   INSERT INTO @EN
		   SELECT @ENNumber				AS Number,
				  GETDATE()				AS [Date],
				  @ENValue				AS Debit,
				  0						AS Credit,
				  @ENNote				AS Note,
				  1						AS CurrencyVal,
				  NEWID()				AS [GUID],
				  @EntryGUID			AS ParentGUID,
				  @AccGuid				AS accountGUID,
				  @DefCurrencyGUID		AS CurrencyGUID,
				  0x0					AS CostGUID,
				  @ShiftControlAccGUID	AS ContraAccGUID
		

			 SET @ENNumber = @ENNumber + 1;

		   INSERT INTO @EN
		   SELECT @ENNumber				AS Number,
				  GETDATE()				AS [Date],
				  0						AS Debit,
				  @ENValue				AS Credit,
				  @ENNote				AS Note,
				  1						AS CurrencyVal,
				  NEWID()				AS [GUID],
				  @EntryGUID			AS ParentGUID,
				  @ShiftControlAccGUID	AS accountGUID,
				  @DefCurrencyGUID		AS CurrencyGUID,
				  0x0					AS CostGUID,
				  @AccGuid				AS ContraAccGUID

		FETCH NEXT FROM @AllShiftTicketsPayByBankCards INTO @ENValue, @ENNote, @AccGuid, @ShiftControlAccGUID, @CostGUID;
		END

		CLOSE      @AllShiftTicketsPayByBankCards;
		DEALLOCATE @AllShiftTicketsPayByBankCards;

	INSERT INTO @ER
	SELECT NEWID()	  AS [GUID],
		   @EntryGUID AS EntryGUID,
		   @ShiftGuid AS ParentGUID,
		   703		  AS ParentType,
		   S.Code	  AS ParentNumber
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
										AND ER.ParentType = 703	)

	DECLARE @HasBankCardTickets INT = ( SELECT COUNT(*)
										FROM POSSDTicket000 T
										INNER JOIN POSSDTicketBankCard000 TB ON T.[GUID] = TB.TicketGUID
										WHERE T.ShiftGUID = @ShiftGuid AND T.[State] = 0)
	IF( @CheckGenerateEntry > 0 OR @HasBankCardTickets = 0 )
	BEGIN
		SELECT 1 AS IsGenerated
	END
	ELSE
	BEGIN
		SELECT 0 AS IsGenerated
	END
#################################################################
#END
