################################################################################
CREATE PROCEDURE POSprcTicketGenerateEntry
-- Params -------------------------------
	@ShiftGuid				UNIQUEIDENTIFIER,
	@TicketsType INT = 0 -- 0: Sales, 1: Purchases, 2: ReturnedSales, 3: Returned Purchases  
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	DECLARE @EN TABLE (	[Number]			[INT], 
						[Date]				[DATETIME], 
						[Debit]				[FLOAT], 
						[Credit]			[FLOAT], 
						[Notes]				[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
						[CurrencyVal]		[FLOAT],
						[GUID]				[UNIQUEIDENTIFIER], 
						[ParentGUID]		[UNIQUEIDENTIFIER], 
						[accountGUID]		[UNIQUEIDENTIFIER], 
						[CurrencyGUID]		[UNIQUEIDENTIFIER], 
						[ContraAccGUID]		[UNIQUEIDENTIFIER])
			   
	DECLARE @CE TABLE ( [Type] [INT] ,
						[Number] [INT],
						[Date] [datetime] ,
						[Debit] [float],
						[Credit] [FLOAT],
						[Notes] [NVARCHAR](1000) ,
						[CurrencyVal] [FLOAT],
						[IsPosted] [INT],
						[State] [INT],
						[Security] [INT],
						[Num1] [FLOAT],
						[Num2] [FLOAT],
						[Branch] [UNIQUEIDENTIFIER],
						[GUID] [UNIQUEIDENTIFIER],
						[CurrencyGUID] [UNIQUEIDENTIFIER],
						[TypeGUID] [UNIQUEIDENTIFIER],
						[IsPrinted] [BIT],
						[PostDate] [DATETIME])


	DECLARE  @ER TABLE( [GUID] [UNIQUEIDENTIFIER],
						[EntryGUID] [UNIQUEIDENTIFIER],
						[ParentGUID] [UNIQUEIDENTIFIER],
						[ParentType] [INT],
						[ParentNumber] [INT])


	DECLARE @Number			            INT = 0
	DECLARE @ParentType					INT
	DECLARE @LaterValue		            FLOAT
	DECLARE @Note			            NVARCHAR(250)
	DECLARE @AccGuid		            UNIQUEIDENTIFIER
	DECLARE @ShiftControlAccGUID        UNIQUEIDENTIFIER
	DECLARE @DefCurrencyGUID			UNIQUEIDENTIFIER 
	DECLARE @EntryGUID					UNIQUEIDENTIFIER 
	DECLARE @MaxCENumber				INT
	DECLARE @EntryNote					NVARCHAR(1000)
	DECLARE @language					INT
	DECLARE @txt_EntryInShiftTickets	NVARCHAR(250)
	DECLARE @txt_ToPOS					NVARCHAR(250)
	DECLARE @txt_ShiftEmployee			NVARCHAR(250)
	DECLARE @txt_CustomerEntry			NVARCHAR(250)
	DECLARE @txt_InShift				NVARCHAR(250)


	 SET @ParentType = CASE @TicketsType WHEN 2 THEN 704 ELSE 701 END

	 SET @language = [dbo].[fnConnections_getLanguage]() 
	 SET @txt_EntryInShiftTickets = 
			CASE @TicketsType WHEN 2 THEN [dbo].[fnStrings_get]('POS\ENTRYINSHIFTRETSALESTICKETS', @language) 
			ELSE [dbo].[fnStrings_get]('POS\ENTRYINSHIFTTICKETS', @language) END

	 SET @txt_ToPOS				  = [dbo].[fnStrings_get]('POS\TOPOSCARD',			 @language)
	 SET @txt_ShiftEmployee		  = [dbo].[fnStrings_get]('POS\SHIFTEMPLOYEE',		 @language) 
	 SET @txt_CustomerEntry		  = [dbo].[fnStrings_get]('POS\CUSTOMERENTRY',		 @language) 
	 SET @txt_InShift			  = [dbo].[fnStrings_get]('POS\INSHIFT',			 @language) 


	 SET @EntryNote = ( SELECT @txt_EntryInShiftTickets +' '+ CAST(S.Code AS NVARCHAR(250)) +' '+ @txt_ToPOS + C.Name +'. '+@txt_ShiftEmployee  +': '+  E.Name
						FROM POSShift000 S
						LEFT JOIN POSCard000 C ON S.POSGuid = C.[Guid]
						LEFT JOIN POSEmployee000 E ON S.EmployeeId = E.[Guid]
						WHERE S.[Guid] =  @ShiftGuid )

	 SET @MaxCENumber     = ISNULL((SELECT MAX(Number) FROM ce000), 0) + 1
	 SET @DefCurrencyGUID = (SELECT TOP 1 [GUID] FROM my000 WHERE CurrencyVal = 1 ORDER BY [Number])
	 SET @EntryGUID       = NEWID()

	INSERT INTO @CE
	SELECT 1																						   AS [Type],
		   @MaxCENumber					    														   AS Number,
		   GETDATE()																				   AS [Date],
		   (SELECT SUM(LaterValue) FROM POSTicket000 WHERE [ShiftGuid] = @ShiftGuid AND [State]  = 0) AS Debit,
		   (SELECT SUM(LaterValue) FROM POSTicket000 WHERE [ShiftGuid] = @ShiftGuid AND [State]  = 0) AS Credit,
		   @EntryNote																				   AS Notes,
		   1																						   AS  CurrencyVal,
		   1																						   AS IsPosted,
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
			@txt_CustomerEntry +' '+ AC.cuCustomerName +  @txt_InShift + CAST(S.Code AS NVARCHAR(250)) +' '+ @txt_ToPOS + C.Name +'. '+ @txt_ShiftEmployee +': '+ E.Name,
			AC.acGUID AS accountGUID,
			C.ShiftControl AS ShiftControlAccGUID
	FROM POSTicket000 T
	LEFT JOIN POSShift000 S    ON T.ShiftGuid    = S.[Guid]
	LEFT JOIN POSCard000  C    ON S.POSGuid      = C.[Guid]
	LEFT JOIN vwCuAc	  AC   ON T.CustomerGuid = AC.cuGUID
	LEFT JOIN POSEmployee000 E ON S.EmployeeId   = E.[Guid]
	WHERE T.ShiftGuid = @ShiftGuid
		AND	T.Type = @TicketsType
		AND	T.[State]  = 0
		AND	T.LaterValue != 0

	DECLARE @DebitAcountGUID UNIQUEIDENTIFIER, @CreditAccountGUID UNIQUEIDENTIFIER

	OPEN AllShiftTickets;	

	FETCH NEXT FROM AllShiftTickets INTO @LaterValue, @Note, @AccGuid, @ShiftControlAccGUID;
	WHILE (@@FETCH_STATUS = 0)
	BEGIN  
		SET @Number = @Number + 1;

		SET @DebitAcountGUID = CASE @TicketsType WHEN 2 THEN @ShiftControlAccGUID ELSE @AccGuid END
		SET @CreditAccountGUID = CASE @TicketsType WHEN 2 THEN @AccGuid ELSE @ShiftControlAccGUID END

		INSERT INTO @EN
		SELECT @Number AS Number,
				GETDATE() AS [Date],
				@LaterValue AS Debit,
				0 AS Credit,
				@Note AS Note,
				1 AS CurrencyVal,
				NEWID() AS [GUID],
				@EntryGUID AS ParentGUID,
				@DebitAcountGUID AS accountGUID,
				@DefCurrencyGUID AS CurrencyGUID,
				@CreditAccountGUID AS ContraAccGUID
		
		SET @Number = @Number + 1;
			
		INSERT INTO @EN
		SELECT	@Number AS Number,
				GETDATE() AS [Date],
				0 AS Debit,
				@LaterValue AS Credit,
				@Note AS Note,
				1 AS CurrencyVal,
				NEWID() AS [GUID],
				@EntryGUID AS ParentGUID,
				@CreditAccountGUID AS accountGUID,
				@DefCurrencyGUID AS CurrencyGUID,
				@DebitAcountGUID AS ContraAccGUID


	   FETCH NEXT FROM AllShiftTickets INTO @LaterValue, @Note, @AccGuid, @ShiftControlAccGUID;
	END

	CLOSE      AllShiftTickets;
	DEALLOCATE AllShiftTickets;

	INSERT INTO @ER
	SELECT NEWID()	  AS [GUID],
		   @EntryGUID AS EntryGUID,
		   @ShiftGuid AS ParentGUID,
		   @ParentType	AS ParentType,
		   S.Code	  AS ParentNumber
	FROM POSShift000 S
	WHERE S.[Guid]  = @ShiftGuid
	


	IF((SELECT COUNT(*) FROM @EN) > 0)
	BEGIN
	
		EXEC prcDisableTriggers 'ce000', 0
	    EXEC prcDisableTriggers 'en000', 0
	    EXEC prcDisableTriggers 'er000', 0
	
	
			INSERT INTO ce000 
			SELECT * FROM @CE
	
			INSERT INTO [en000] (
			[Number],			
			[Date],			
			[Debit],			
			[Credit],			
			[Notes],		
			[CurrencyVal],
			[GUID],		
			[ParentGUID],	
			[accountGUID],
			[CurrencyGUID],
			[ContraAccGUID]) 
			SELECT * FROM @EN
	
			INSERT INTO er000
			SELECT * FROM @ER
	
	
		EXEC prcEnableTriggers 'ce000'	
		EXEC prcEnableTriggers 'en000'
		EXEC prcEnableTriggers 'er000'
	
	END
	
	DECLARE @CheckGenerateEntry			   INT = (	SELECT COUNT(*) 
													FROM er000 ER
													INNER JOIN ce000 CE ON ER.EntryGUID = CE.[GUID]
													INNER JOIN en000 EN ON CE.[GUID] = EN.ParentGUID
													WHERE ER.ParentGUID = @ShiftGuid
													AND ER.ParentType = @ParentType	)
	
	DECLARE @CheckIfShiftHasFilteredTicket INT = ( SELECT COUNT(*)
												   FROM POSTicket000
												   WHERE [ShiftGuid] = @ShiftGuid
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
