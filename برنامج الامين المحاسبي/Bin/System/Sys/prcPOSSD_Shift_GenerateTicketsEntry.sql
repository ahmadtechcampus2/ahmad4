################################################################################
CREATE PROCEDURE prcPOSSD_Shift_GenerateTicketsEntry
-- Params -------------------------------
	@ShiftGuid				UNIQUEIDENTIFIER,
	@TicketsType INT = 0 -- 0: Sales, 1: Purchases, 2: ReturnedSales, 3: Returned Purchases  
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	DECLARE @EN TABLE (	[Number]			INT, 
						[Date]				DATETIME, 
						[Debit]				FLOAT, 
						[Credit]			FLOAT, 
						[Notes]				NVARCHAR(255) COLLATE ARABIC_CI_AI, 
						[CurrencyVal]		FLOAT,
						[GUID]				UNIQUEIDENTIFIER, 
						[ParentGUID]		UNIQUEIDENTIFIER, 
						[accountGUID]		UNIQUEIDENTIFIER, 
						[CurrencyGUID]		UNIQUEIDENTIFIER, 
						[CostGUID]			UNIQUEIDENTIFIER,
						[ContraAccGUID]		UNIQUEIDENTIFIER,
						[CustomerGUID]		UNIQUEIDENTIFIER)
			   
	DECLARE @CE TABLE ( [Type]			INT,
						[Number]		INT,
						[Date]			DATETIME,
						[Debit]			FLOAT,
						[Credit]		FLOAT,
						[Notes]			NVARCHAR(1000),
						[CurrencyVal]	FLOAT,
						[IsPosted]		INT,
						[State]			INT,
						[Security]		INT,
						[Num1]			FLOAT,
						[Num2]			FLOAT,
						[Branch]		UNIQUEIDENTIFIER,
						[GUID]			UNIQUEIDENTIFIER,
						[CurrencyGUID]	UNIQUEIDENTIFIER,
						[TypeGUID]		UNIQUEIDENTIFIER,
						[IsPrinted]		BIT,
						[PostDate]		DATETIME )


	DECLARE  @ER TABLE( [GUID]			UNIQUEIDENTIFIER,
						[EntryGUID]		UNIQUEIDENTIFIER,
						[ParentGUID]	UNIQUEIDENTIFIER,
						[ParentType]	INT,
						[ParentNumber]	INT )


	DECLARE @Number			            INT = 0
	DECLARE @ParentType					INT
	DECLARE @LaterValue		            FLOAT
	DECLARE @IsPayTicket				INT
	DECLARE @Note			            NVARCHAR(250)
	DECLARE @AccGuid		            UNIQUEIDENTIFIER
	DECLARE @ShiftControlAccGUID        UNIQUEIDENTIFIER
	DECLARE @DefCurrencyGUID			UNIQUEIDENTIFIER 
	DECLARE @EntryGUID					UNIQUEIDENTIFIER 
	DECLARE @CostGUID				    UNIQUEIDENTIFIER
	DECLARE @CustomerGUID				UNIQUEIDENTIFIER
	DECLARE @MaxCENumber				INT
	DECLARE @EntryNote					NVARCHAR(1000)
	DECLARE @language					INT
	DECLARE @txt_EntryInShiftTickets	NVARCHAR(250)
	DECLARE @txt_ToPOS					NVARCHAR(250)
	DECLARE @txt_ShiftEmployee			NVARCHAR(250)
	DECLARE @txt_CustomerEntry			NVARCHAR(250)
	DECLARE @txt_CustomerEntryOut		NVARCHAR(250)
	DECLARE @txt_InShift				NVARCHAR(250)
	DECLARE @txt_TicketType				NVARCHAR(250)


	 SET @ParentType = CASE @TicketsType WHEN 2 THEN 704 ELSE 701 END
	 SET @language = [dbo].[fnConnections_getLanguage]() 

	 SET @txt_EntryInShiftTickets = CASE @TicketsType WHEN 2 THEN [dbo].[fnStrings_get]('POS\ENTRYINSHIFTRETSALESTICKETS', @language) 
													  ELSE [dbo].[fnStrings_get]('POS\ENTRYINSHIFTTICKETS', @language) END

	 SET @txt_CustomerEntry = [dbo].[fnStrings_get]('POS\CUSTOMERENTRY', @language)
	 SET @txt_CustomerEntryOut = [dbo].[fnStrings_get]('POS\CUSTOMERENTRYOUT', @language) 

	 SET @txt_TicketType = CASE @TicketsType WHEN 2 THEN [dbo].[fnStrings_get]('POSSD\SALESRETURN_TYPE', @language)		 
													ELSE [dbo].[fnStrings_get]('POSSD\SALES_TYPE', @language) END

	 SET @txt_ToPOS				  = [dbo].[fnStrings_get]('POS\TOPOSCARD',			 @language)
	 SET @txt_ShiftEmployee		  = [dbo].[fnStrings_get]('POS\SHIFTEMPLOYEE',		 @language) 
	 SET @txt_InShift			  = [dbo].[fnStrings_get]('POS\INSHIFT',			 @language) 

	 SET @EntryNote = ( SELECT @txt_EntryInShiftTickets +' '+ CAST(S.Code AS NVARCHAR(250)) +' '+ @txt_ToPOS 
							 + CAST(C.Code AS NVARCHAR(250)) + '-' + CASE @language WHEN 0 THEN C.Name ELSE CASE C.LatinName WHEN '' THEN C.Name ELSE C.LatinName END END 
							 +'. '+@txt_ShiftEmployee  +': '+  E.Name
						FROM POSSDShift000 S
						LEFT JOIN POSSDStation000 C ON S.StationGUID = C.[Guid]
						LEFT JOIN POSSDEmployee000 E ON S.EmployeeGUID = E.[Guid]
						WHERE S.[GUID] =  @ShiftGuid )

	 SET @MaxCENumber     = ISNULL((SELECT MAX(Number) FROM ce000), 0) + 1
	 SET @DefCurrencyGUID = (SELECT TOP 1 [GUID] FROM my000 WHERE CurrencyVal = 1 ORDER BY [Number])
	 SET @EntryGUID       = NEWID()

	INSERT INTO @CE
	SELECT 1																						   AS [Type],
		   @MaxCENumber					    														   AS Number,
		   GETDATE()																				   AS [Date],
		   (SELECT SUM(LaterValue) FROM POSSDTicket000 WHERE [ShiftGUID] = @ShiftGuid AND [State]  = 0)  AS Debit,
		   (SELECT SUM(LaterValue) FROM POSSDTicket000 WHERE [ShiftGUID] = @ShiftGuid AND [State]  = 0)  AS Credit,
		   @EntryNote																				   AS Notes,
		   1																						   AS  CurrencyVal,
		   0																						   AS IsPosted,
		   0																						   AS [State],
		   1																						   AS [Security],
		   0																						   AS Num1,
		   0																						   AS Num2,
		   0x0																						   AS Branch,
		   @EntryGUID																				   AS [GUID],
		   @DefCurrencyGUID																			   AS CurrencyGUID,
		   '00000000-0000-0000-0000-000000000000'													   AS TypeGUID,
		   0																						   AS IsPrinted,
		   GETDATE()																				   AS PostDate



	DECLARE AllShiftTickets		  CURSOR FOR	
	SELECT  
		T.LaterValue,
		CASE  WHEN @TicketsType = 0 AND (T.Net > 0) THEN @txt_CustomerEntry ELSE @txt_CustomerEntryOut END
		+' '+ AC.cuCustomerName +  @txt_InShift + CAST(S.Code AS NVARCHAR(250)) +' '+ @txt_ToPOS + C.Name +'. ' 
		+ @txt_TicketType + CAST(T.Number AS NVARCHAR(250)) + ' '+ @txt_ShiftEmployee +': '+ E.Name,
		AC.acGUID AS accountGUID,
		C.ShiftControlGUID AS ShiftControlAccGUID,
		SM.CostCenterGUID AS CostGUID,
		T.CustomerGuid AS CustomerGUID,
		CASE WHEN (T.Net < 0) THEN 1 ELSE 0 END AS IsPayTicket
	FROM 
		POSSDTicket000 T
		LEFT JOIN POSSDShift000 S      ON T.ShiftGUID    =  S.[GUID]
		LEFT JOIN POSSDStation000 C    ON S.StationGUID  =  C.[GUID]
		LEFT JOIN vwCuAc AC            ON T.CustomerGuid = AC.cuGUID
		LEFT JOIN POSSDEmployee000 E   ON S.EmployeeGUID =  E.[Guid]
		LEFT JOIN POSSDSalesman000 SM  ON T.SalesmanGUID = SM.[GUID]
	WHERE 
		T.ShiftGUID = @ShiftGuid
		AND	T.[Type]      = @TicketsType
		AND	T.[State]     = 0
		AND	T.LaterValue != 0

	DECLARE @DebitAcountGUID UNIQUEIDENTIFIER
	DECLARE @CreditAccountGUID UNIQUEIDENTIFIER

	DECLARE @DebitCustomerGUID  UNIQUEIDENTIFIER
	DECLARE @CreditCustomerGUID UNIQUEIDENTIFIER

	OPEN AllShiftTickets;	

	FETCH NEXT FROM AllShiftTickets INTO @LaterValue, @Note, @AccGuid, @ShiftControlAccGUID, @CostGUID, @CustomerGUID, @IsPayTicket;
	WHILE (@@FETCH_STATUS = 0)
	BEGIN  
		SET @Number = @Number + 1;

		SET @DebitAcountGUID    = CASE  WHEN @TicketsType = 0 AND @IsPayTicket <> 1 THEN @AccGuid ELSE @ShiftControlAccGUID END
		SET @CreditAccountGUID  = CASE  WHEN @TicketsType = 0 AND @IsPayTicket <> 1THEN @ShiftControlAccGUID ELSE @AccGuid END
		SET @DebitCustomerGUID  = @CustomerGUID
		SET @CreditCustomerGUID = @CustomerGUID
		
		IF(@DebitAcountGUID <> @ShiftControlAccGUID)
			SET @DebitCustomerGUID = 0x0

		IF(@CreditAccountGUID <> @ShiftControlAccGUID)
			SET @CreditCustomerGUID = 0x0
		

		INSERT INTO @EN
		SELECT @Number				AS Number,
				GETDATE()			AS [Date],
				@LaterValue			AS Debit,
				0					AS Credit,
				@Note				AS Note,
				1					AS CurrencyVal,
				NEWID()				AS [GUID],
				@EntryGUID			AS ParentGUID,
				@DebitAcountGUID	AS accountGUID,
				@DefCurrencyGUID	AS CurrencyGUID,
				0x0					AS CostGUID,
				@CreditAccountGUID	AS ContraAccGUID,
				@CreditCustomerGUID AS CustomerGUID
		
		SET @Number = @Number + 1;
			
		INSERT INTO @EN
		SELECT	@Number				AS Number,
				GETDATE()			AS [Date],
				0					AS Debit,
				@LaterValue			AS Credit,
				@Note				AS Note,
				1					AS CurrencyVal,
				NEWID()				AS [GUID],
				@EntryGUID			AS ParentGUID,
				@CreditAccountGUID	AS accountGUID,
				@DefCurrencyGUID	AS CurrencyGUID,
				0x0					AS CostGUID,
				@DebitAcountGUID	AS ContraAccGUID,
				@DebitCustomerGUID	AS CustomerGUID


	FETCH NEXT FROM AllShiftTickets INTO @LaterValue, @Note, @AccGuid, @ShiftControlAccGUID, @CostGUID, @CustomerGUID, @IsPayTicket;
	END

	CLOSE      AllShiftTickets;
	DEALLOCATE AllShiftTickets;

	INSERT INTO @ER
	SELECT NEWID()	  AS [GUID],
		   @EntryGUID AS EntryGUID,
		   @ShiftGuid AS ParentGUID,
		   @ParentType	AS ParentType,
		   S.Code	  AS ParentNumber
	FROM POSSDShift000 S
	WHERE S.[GUID]  = @ShiftGuid
	


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
								[PostDate] )
			SELECT * FROM @CE
	
			INSERT INTO [en000] ( [Number],			
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
								  [ContraAccGUID],
								  [CustomerGUID] ) 
			SELECT * FROM @EN
	
			INSERT INTO er000 ( [GUID],
								[EntryGUID],
								[ParentGUID],
								[ParentType],
								[ParentNumber] )
			SELECT * FROM @ER
	
			EXEC prcConnections_SetIgnoreWarnings 1
			UPDATE ce000 SET [IsPosted] = 1 WHERE [GUID] = @EntryGUID
			EXEC prcConnections_SetIgnoreWarnings 0
	
	END
	
	DECLARE @CheckGenerateEntry			   INT = (	SELECT COUNT(*) 
													FROM er000 ER
													INNER JOIN ce000 CE ON ER.EntryGUID = CE.[GUID]
													INNER JOIN en000 EN ON CE.[GUID] = EN.ParentGUID
													WHERE ER.ParentGUID = @ShiftGuid
													AND ER.ParentType = @ParentType	)
	
	DECLARE @CheckIfShiftHasFilteredTicket INT = ( SELECT COUNT(*)
												   FROM POSSDTicket000
												   WHERE [ShiftGUID] = @ShiftGuid
												   AND	[Type] = @TicketsType
												   AND	[State] = 0
												   AND	[LaterValue] != 0 )
	
	
	IF(@CheckGenerateEntry > 0 OR @CheckIfShiftHasFilteredTicket = 0)
	BEGIN
		SELECT 1 AS IsGenerated
	END
	ELSE
	BEGIN
		SELECT 0 AS IsGenerated
	END
#################################################################
#END
