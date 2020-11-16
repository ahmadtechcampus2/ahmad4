################################################################################
CREATE PROCEDURE prcPOSSD_Shift_GenerateExternalOperationsEntry
-- Params -------------------------------
	@ShiftGUID				UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	DECLARE @EN TABLE ( [Number]		[INT] , 
						[Date]			[DATETIME],
						[Debit]			[FLOAT], 
						[Credit]		[FLOAT],
						[CustomerGUID]	[UNIQUEIDENTIFIER],
						[Notes]			[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
						[CurrencyVal]	[FLOAT],
						[GUID]			[UNIQUEIDENTIFIER], 
						[ParentGUID]	[UNIQUEIDENTIFIER], 
						[accountGUID]	[UNIQUEIDENTIFIER], 
						[CurrencyGUID]	[UNIQUEIDENTIFIER], 
						[ContraAccGUID]	[UNIQUEIDENTIFIER] )
				   
	DECLARE @CE TABLE ( [Type]			[INT] ,
						[Number]		[INT],
						[Date]			[DATETIME] ,
						[Debit]			[FLOAT],
						[Credit]		[FLOAT],
						[Notes]			[NVARCHAR](1000),
						[CurrencyVal]	[FLOAT],
						[IsPosted]		[INT],
						[State]			[INT],
						[Security]		[INT],
						[Num1]			[FLOAT],
						[Num2]			[FLOAT],
						[Branch]		[UNIQUEIDENTIFIER],
						[GUID]			[UNIQUEIDENTIFIER],
						[CurrencyGUID]	[UNIQUEIDENTIFIER],
						[TypeGUID]		[UNIQUEIDENTIFIER],
						[IsPrinted]		[BIT],
						[PostDate]		[DATETIME] )
	
	DECLARE  @ER TABLE( [GUID]		   [UNIQUEIDENTIFIER],
						[EntryGUID]    [UNIQUEIDENTIFIER],
						[ParentGUID]   [UNIQUEIDENTIFIER],
						[ParentType]   [INT],
						[ParentNumber] [INT] )


	DECLARE @Result								INT  
	DECLARE @Number								INT = 0
	DECLARE @EntryGUID							UNIQUEIDENTIFIER 
	DECLARE @MaxCENumber						INT
	DECLARE @Amount								FLOAT
	DECLARE @Note								NVARCHAR(250)
	DECLARE @DebitAccount						UNIQUEIDENTIFIER
	DECLARE @CreditAccount						UNIQUEIDENTIFIER
	DECLARE @CustomerGUID						UNIQUEIDENTIFIER
	DECLARE @CurrencyGUID						UNIQUEIDENTIFIER
	DECLARE @CurrencyValue						FLOAT
	DECLARE @DefCurrencyGUID					UNIQUEIDENTIFIER
	DECLARE @EntryNote							NVARCHAR(1000)
	DECLARE @language							INT
	DECLARE @txt_EntryInShiftExternalOperation	NVARCHAR(250)
	DECLARE @txt_ToPOS							NVARCHAR(250)
	DECLARE @txt_ShiftEmployee					NVARCHAR(250)
	DECLARE @txt_Shift							NVARCHAR(250)
	DECLARE @txt_ReceiveDownPayment				NVARCHAR(250)
	DECLARE @txt_ReturnDownPayment				NVARCHAR(250)
	DECLARE @txt_ReceiveDriverPayment			NVARCHAR(250)
	DECLARE @txt_ReturnDriverPayment			NVARCHAR(250)
	DECLARE @txt_SettlementDriverPayment        NVARCHAR(250)
	DECLARE @ShiftControlAccount				UNIQUEIDENTIFIER
	DECLARE @BranchGuid							UNIQUEIDENTIFIER

	SET @EntryGUID						   = NEWID()
	SET @BranchGuid						   = (SELECT TOP 1 [GUID] FROM br000 ORDER BY Number)
	SET @MaxCENumber					   = (SELECT ISNULL(MAX(Number), 0) + 1 FROM ce000  WHERE Branch = ISNULL(@BranchGuid, 0x0))
	SET @DefCurrencyGUID				   = (SELECT TOP 1 [GUID] FROM my000 WHERE CurrencyVal = 1 ORDER BY [Number])
	SET @language						   = [dbo].[fnConnections_getLanguage]() 
	SET @txt_EntryInShiftExternalOperation = [dbo].[fnStrings_get]('POS\ENTRYINSHIFTEXTERNALOPERATIONS', @language)
	SET @txt_ToPOS						   = [dbo].[fnStrings_get]('POS\TOPOSCARD', @language)
	SET @txt_ShiftEmployee				   = [dbo].[fnStrings_get]('POS\SHIFTEMPLOYEE', @language) 
	SET @txt_Shift						   = [dbo].[fnStrings_get]('POS\SHIFT', @language) 
	SET @txt_ReceiveDownPayment            = [dbo].[fnStrings_get]('POSSD\ReceiveDownPayment', @language) 
	SET @txt_ReturnDownPayment             = [dbo].[fnStrings_get]('POSSD\ReturnDownPayment', @language) 
	SET @txt_ReceiveDriverPayment          = [dbo].[fnStrings_get]('POSSD\ReceiveDriverPayment', @language) 
	SET @txt_ReturnDriverPayment		   = [dbo].[fnStrings_get]('POSSD\ReturnDriverPayment', @language) 
	SET @txt_SettlementDriverPayment       = [dbo].[fnStrings_get]('POSSD\SettlementDriverPayment', @language) 

	SET @EntryNote	= ( SELECT @txt_EntryInShiftExternalOperation +  CAST(S.Code AS NVARCHAR(250)) + @txt_ToPOS 
							  + CAST(C.Code AS NVARCHAR(250)) + '-' + CASE @language WHEN 0 THEN C.Name ELSE CASE C.LatinName WHEN '' THEN C.Name ELSE C.LatinName END END 
							  +'. '+ @txt_ShiftEmployee +': '+ E.Name
						FROM POSSDShift000 S
						LEFT JOIN POSSDStation000 C	   ON S.StationGUID	 = C.[GUID]
						LEFT JOIN POSSDEmployee000 E ON S.EmployeeGUID = E.[Guid]
						WHERE S.[GUID] =  @ShiftGUID )  

	SELECT @ShiftControlAccount = ShiftControlGUID 
	FROM POSSDStation000 POSCard
	INNER JOIN POSSDShift000 POSShift ON POSCard.[GUID] = POSShift.[StationGUID]
	WHERE POSShift.[GUID] = @ShiftGUID
	------------------------------------------------------------------------------------------------------------------

	-- ce with default currecny
	INSERT INTO @CE
	SELECT 1																								   AS [Type],
		   @MaxCENumber					    																   AS Number,
		   GETDATE()																						   AS [Date],
		   (SELECT SUM(Amount) FROM POSSDExternalOperation000 WHERE [ShiftGUID] = @ShiftGUID AND [State] != 1)  AS Debit,
		   (SELECT SUM(Amount) FROM POSSDExternalOperation000 WHERE [ShiftGUID] = @ShiftGUID AND [State] != 1)  AS Credit,
		   @EntryNote																				           AS Notes,
		   1																						           AS  CurrencyVal,
		   0																						           AS IsPosted,
		   0																						           AS [State],
		   1																						           AS [Security],
		   0																						           AS Num1,
		   0																						           AS Num2,
		   0x0																						           AS Branch,
		   @EntryGUID																				           AS [GUID],
		   @DefCurrencyGUID																			           AS CurrencyGUID,
		   '00000000-0000-0000-0000-000000000000'													           AS TypeGUID,
		   0																						           AS IsPrinted,
		   GETDATE()																				           AS PostDate


	DECLARE AllShiftExternalOperations  CURSOR FOR	
	SELECT  
			EO.Amount,
			(CASE EO.[Type] WHEN 7  THEN (CASE EO.IsPayment WHEN 0 THEN @txt_ReceiveDownPayment ELSE @txt_ReturnDownPayment END + ' - ' ) ELSE ''END) +
			(CASE EO.[Type] WHEN 9  THEN (CASE EO.IsPayment WHEN 0 THEN @txt_ReceiveDriverPayment ELSE @txt_ReturnDriverPayment END + ' - ') ELSE ''END) +
			(CASE EO.[Type] WHEN 10 THEN @txt_SettlementDriverPayment + ' - ' ELSE ''END) +
			ISNULL(EO.Note, '') +  ' - ' + @txt_Shift + CAST(S.Code AS NVARCHAR(250)) + @txt_ToPOS + C.Name +'. '+ @txt_ShiftEmployee +': '+ E.Name,
			EO.DebitAccountGUID AS DebitAccountGUID,
			EO.CreditAccountGUID AS CreditAccountGUID,
			EO.CurrencyGUID,
			EO.CurrencyValue,
			EO.CustomerGUID
	FROM POSSDExternalOperation000 EO
	LEFT JOIN POSSDShift000 S  ON EO.ShiftGUID = S.[GUID]
	LEFT JOIN POSSDStation000 C ON S.StationGUID	 = C.[Guid]
	LEFT JOIN POSSDEmployee000 E ON S.EmployeeGUID = E.[Guid]
	WHERE EO.ShiftGUID = @ShiftGUID
	AND	  EO.[State]  != 1
	OPEN AllShiftExternalOperations;
	
		FETCH NEXT FROM AllShiftExternalOperations INTO @Amount, @Note, @DebitAccount, @CreditAccount, @CurrencyGUID, @CurrencyValue, @CustomerGUID;
		WHILE (@@FETCH_STATUS = 0)
		BEGIN  
			SET @Number = @Number + 1;

			DECLARE @DebitAmount FLOAT = @Amount * @CurrencyValue,
					@CreditAmount FLOAT = @Amount * @CurrencyValue,
					@DebitCurrencyGuid UNIQUEIDENTIFIER = @CurrencyGUID, 
					@DeditCurrencyValue FLOAT = @CurrencyValue,
					@CreditCurrencyGuid UNIQUEIDENTIFIER = @CurrencyGUID, 
					@CreditCurrencyValue FLOAT = @CurrencyValue,
					@DebitCustomer UNIQUEIDENTIFIER = @CustomerGUID,
					@CreditCustomer UNIQUEIDENTIFIER = @CustomerGUID

			IF(@DebitAccount = @ShiftControlAccount)
			BEGIN
				SET @DebitCurrencyGuid = @DefCurrencyGUID
				SET @DeditCurrencyValue = 1
				SET @DebitCustomer = 0x0
			END

			IF(@CreditAccount = @ShiftControlAccount)
			BEGIN
				SET @CreditCurrencyGuid = @DefCurrencyGUID
				SET @CreditCurrencyValue = 1
				SET @CreditCustomer = 0x0
			END


		   -- Debit line ---
		   INSERT INTO @EN
		   SELECT @Number AS Number,
				  GETDATE() AS [Date],
				  @DebitAmount AS Debit,
				  0 AS Credit,
				  @DebitCustomer AS CustomerGUID,
				  @Note AS Note,
				  @DeditCurrencyValue AS CurrencyVal,
				  NEWID() AS [GUID],
				  @EntryGUID AS ParentGUID,
				  @DebitAccount AS accountGUID,
				  @DebitCurrencyGuid AS CurrencyGUID,
				  @CreditAccount AS ContraAccGUID

			  
			 SET @Number = @Number + 1;
	  
		  -- Credit line --
		   INSERT INTO @EN
		   SELECT @Number AS Number,
				  GETDATE() AS [Date],
				  0 AS Debit,
				  @CreditAmount AS Credit,
				  @CreditCustomer AS CustomerGUID,
				  @Note AS Note,
				  @CreditCurrencyValue AS CurrencyVal,
				  NEWID() AS [GUID],
				  @EntryGUID AS ParentGUID,
				  @CreditAccount AS accountGUID,
				  @CreditCurrencyGuid AS CurrencyGUID,
				  @DebitAccount AS ContraAccGUID
			  
		   FETCH NEXT FROM AllShiftExternalOperations INTO @Amount, @Note, @DebitAccount, @CreditAccount, @CurrencyGUID, @CurrencyValue, @CustomerGUID;
		END
	
		CLOSE      AllShiftExternalOperations;
		DEALLOCATE AllShiftExternalOperations;

	INSERT INTO @ER
	SELECT NEWID()	  AS [GUID],
		   @EntryGUID AS EntryGUID,
		   @ShiftGUID AS ParentGUID,
		   702		  AS ParentType,
		   S.Code	  AS ParentNumber
	FROM POSSDShift000 S
	WHERE S.[GUID]  = @ShiftGUID



	IF((SELECT COUNT(*) FROM @EN) > 0)
	BEGIN

				INSERT INTO ce000 (   [Type],
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
		
				INSERT INTO [en000] ( [Number],			
									  [Date],			
									  [Debit],			
									  [Credit],
									  [CustomerGUID],	
									  [Notes],		
									  [CurrencyVal],
									  [GUID],		
									  [ParentGUID],	
									  [accountGUID],
									  [CurrencyGUID],
									  [ContraAccGUID] ) SELECT * FROM @EN
		
				INSERT INTO er000 (   [GUID],
							          [EntryGUID],
							          [ParentGUID],
							          [ParentType],
							          [ParentNumber] ) SELECT * FROM @ER


			EXEC prcConnections_SetIgnoreWarnings 1
			UPDATE ce000 SET [IsPosted] = 1 WHERE [GUID] = @EntryGUID
			EXEC prcConnections_SetIgnoreWarnings 0

	END


							  DECLARE @CheckGenerateEntry INT = ( SELECT COUNT(*) 
																  FROM er000 ER
																  INNER JOIN ce000 CE ON ER.EntryGUID = CE.[GUID]
																  INNER JOIN en000 EN ON CE.[GUID] = EN.ParentGUID
																  WHERE ER.ParentGUID = @ShiftGUID
																  AND ER.ParentType = 702 )

	DECLARE @CheckIfShiftHasNotCanceledExternalOperations INT = ( SELECT COUNT(*)
																  FROM POSSDExternalOperation000
																  WHERE ShiftGUID  = @ShiftGUID
																  AND	  [State]  != 1 )


	IF(@CheckGenerateEntry > 0 OR @CheckIfShiftHasNotCanceledExternalOperations = 0)
	BEGIN
		 SET @Result =1
	END
	ELSE
	BEGIN
		 SET @Result =0
	END
	SELECT @Result	 AS Result

#################################################################
#END
