################################################################################
CREATE PROCEDURE POSprcExternalOperationGenerateEntry
-- Params -------------------------------
	@ShiftGuid				UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
DECLARE @EN  TABLE ([Number]			[INT] , 
					[Date]				[DATETIME], 
					[Debit]				[FLOAT], 
					[Credit]			[FLOAT], 
					[Notes]				[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
					[CurrencyVal]		[FLOAT],
					[GUID]				[UNIQUEIDENTIFIER], 
					[ParentGUID]		[UNIQUEIDENTIFIER], 
					[accountGUID]		[UNIQUEIDENTIFIER], 
					[CurrencyGUID]		[UNIQUEIDENTIFIER], 
					[ContraAccGUID]		[UNIQUEIDENTIFIER]	 )
				   
DECLARE @CE TABLE (
	[Type] [INT] ,
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
	[PostDate] [DATETIME]
	)
	
DECLARE  @ER TABLE(
	[GUID] [UNIQUEIDENTIFIER],
	[EntryGUID] [UNIQUEIDENTIFIER],
	[ParentGUID] [UNIQUEIDENTIFIER],
	[ParentType] [INT],
	[ParentNumber] [INT])
	
DECLARE @Number								INT = 0
DECLARE @EntryGUID							UNIQUEIDENTIFIER 
DECLARE @MaxCENumber						INT
DECLARE @Amount								FLOAT
DECLARE @Note								NVARCHAR(250)
DECLARE @DebitAccount						UNIQUEIDENTIFIER
DECLARE @CreditAccount						UNIQUEIDENTIFIER
DECLARE @CurrencyGUID						UNIQUEIDENTIFIER
DECLARE @CurrencyValue						FLOAT
DECLARE @DefCurrencyGUID					UNIQUEIDENTIFIER
DECLARE @EntryNote							NVARCHAR(1000)
DECLARE @language							INT
DECLARE @txt_EntryInShiftExternalOperation	NVARCHAR(250)
DECLARE @txt_ToPOS							NVARCHAR(250)
DECLARE @txt_ShiftEmployee					NVARCHAR(250)
DECLARE @txt_Shift							NVARCHAR(250)
DECLARE @ShiftControlAccount				UNIQUEIDENTIFIER

SET @EntryGUID						   = NEWID()
SET @MaxCENumber					   = ISNULL((SELECT MAX(Number) FROM ce000), 0) + 1
SET @DefCurrencyGUID				   = (SELECT TOP 1 [GUID] FROM my000 WHERE CurrencyVal = 1 ORDER BY [Number])
SET @language						   = [dbo].[fnConnections_getLanguage]() 
SET @txt_EntryInShiftExternalOperation = [dbo].[fnStrings_get]('POS\ENTRYINSHIFTEXTERNALOPERATIONS', @language)
SET @txt_ToPOS						   = [dbo].[fnStrings_get]('POS\TOPOSCARD', @language)
SET @txt_ShiftEmployee				   = [dbo].[fnStrings_get]('POS\SHIFTEMPLOYEE', @language) 
SET @txt_Shift						   = [dbo].[fnStrings_get]('POS\SHIFT', @language) 

SET @EntryNote	= ( SELECT @txt_EntryInShiftExternalOperation +  CAST(S.Code AS NVARCHAR(250)) + @txt_ToPOS + C.Name +'. '+ @txt_ShiftEmployee +': '+ E.Name
					FROM POSShift000 S
					LEFT JOIN POSCard000 C	   ON S.POSGuid	   = C.[Guid]
					LEFT JOIN POSEmployee000 E ON S.EmployeeId = E.[Guid]
					WHERE S.[Guid] =  @ShiftGuid )  

SELECT @ShiftControlAccount = ShiftControl 
FROM POSCard000 POSCard
INNER JOIN POSShift000 POSShift ON POSCard.[GUID] = POSShift.[POSGuid]
WHERE POSShift.[GUID] = @ShiftGuid
------------------------------------------------------------------------------------------------------------------

-- ce with default currecny
INSERT INTO @CE
SELECT 1																								   AS [Type],
	   @MaxCENumber					    																   AS Number,
	   GETDATE()																						   AS [Date],
	   (SELECT SUM(Amount) FROM POSExternalOperations000 WHERE [ShiftGuid] = @ShiftGuid AND [State] != 1)  AS Debit,
	   (SELECT SUM(Amount) FROM POSExternalOperations000 WHERE [ShiftGuid] = @ShiftGuid AND [State] != 1)  AS Credit,
	   @EntryNote																				           AS Notes,
	   1																						           AS  CurrencyVal,
	   1																						           AS IsPosted,
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
		ISNULL(EO.Note, '') +  ' - ' + @txt_Shift + CAST(S.Code AS NVARCHAR(250)) + @txt_ToPOS + C.Name +'. '+ @txt_ShiftEmployee +': '+ E.Name,
		EO.DebitAccount AS DebitAccount,
		EO.CreditAccount AS  CreditAccount,
		EO.CurrencyGUID,
		EO.CurrencyValue
FROM POSExternalOperations000 EO
LEFT JOIN POSShift000 S    ON EO.ShiftGuid = S.[Guid]
LEFT JOIN POSCard000 C	   ON S.POSGuid	   = C.[Guid]
LEFT JOIN POSEmployee000 E ON S.EmployeeId = E.[Guid]
WHERE EO.ShiftGuid = @ShiftGuid
AND	  EO.[State]  != 1
OPEN AllShiftExternalOperations;
	
	FETCH NEXT FROM AllShiftExternalOperations INTO @Amount, @Note, @DebitAccount, @CreditAccount, @CurrencyGUID, @CurrencyValue;
	WHILE (@@FETCH_STATUS = 0)
	BEGIN  
		SET @Number = @Number + 1;

		DECLARE @DebitAmount FLOAT = @Amount * @CurrencyValue,
				@CreditAmount FLOAT = @Amount * @CurrencyValue,
				@DebitCurrencyGuid UNIQUEIDENTIFIER = @CurrencyGUID, 
				@DeditCurrencyValue FLOAT = @CurrencyValue,
				@CreditCurrencyGuid UNIQUEIDENTIFIER = @CurrencyGUID, 
				@CreditCurrencyValue FLOAT = @CurrencyValue

		IF(@DebitAccount = @ShiftControlAccount)
		BEGIN
			SET @DebitCurrencyGuid = @DefCurrencyGUID
			SET @DeditCurrencyValue = 1
		END

		IF(@CreditAccount = @ShiftControlAccount)
		BEGIN
			SET @CreditCurrencyGuid = @DefCurrencyGUID
			SET @CreditCurrencyValue = 1
		END


	   -- Debit line ---
	   INSERT INTO @EN
	   SELECT @Number AS Number,
			  GETDATE() AS [Date],
			  @DebitAmount AS Debit,
			  0 AS Credit,
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
			  @Note AS Note,
			  @CreditCurrencyValue AS CurrencyVal,
			  NEWID() AS [GUID],
			  @EntryGUID AS ParentGUID,
			  @CreditAccount AS accountGUID,
			  @CreditCurrencyGuid AS CurrencyGUID,
			  @DebitAccount AS ContraAccGUID
			  
	   FETCH NEXT FROM AllShiftExternalOperations INTO @Amount, @Note, @DebitAccount, @CreditAccount, @CurrencyGUID, @CurrencyValue;
	END
	
	CLOSE      AllShiftExternalOperations;
	DEALLOCATE AllShiftExternalOperations;

INSERT INTO @ER
SELECT NEWID()	  AS [GUID],
	   @EntryGUID AS EntryGUID,
	   @ShiftGuid AS ParentGUID,
	   702		  AS ParentType,
	   S.Code	  AS ParentNumber
FROM POSShift000 S
	   WHERE S.[Guid]  = @ShiftGuid

DECLARE @ResultEntry INT
DECLARE @sqlCommand NVARCHAR(256), @sqlCommand2 NVARCHAR(256)
DECLARE @tableCe NVARCHAR(256)
DECLARE @tableEn NVARCHAR(256)
DECLARE @tableEr NVARCHAR(256)
DECLARE @Result INT  

SET @tableCe ='ce000'
SET @tableEn ='en000'
SET @tableEr ='er000'

SET @ResultEntry = 0 

IF((SELECT COUNT(*) FROM @EN) > 0)
BEGIN
   BEGIN TRANSACTION

		SET @sqlCommand =
		    'EXEC prcDisableTriggers '+@tableCe+', 0  
			 EXEC prcDisableTriggers '+@tableEn+', 0  
			 EXEC prcDisableTriggers '+@tableEr+', 0'
		 EXECUTE sp_executesql @sqlCommand 
				
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

		SET @sqlCommand2 = 
		    'EXEC prcEnableTriggers '+@tableCe+'   
			 EXEC prcEnableTriggers '+@tableEn+'    
			 EXEC prcEnableTriggers '+@tableEr+''
		 EXECUTE sp_executesql @sqlCommand2 
   COMMIT
END


DECLARE @CheckGenerateEntry							 INT = (  SELECT COUNT(*) 
															  FROM er000 ER
															  INNER JOIN ce000 CE ON ER.EntryGUID = CE.[GUID]
															  INNER JOIN en000 EN ON CE.[GUID] = EN.ParentGUID
															  WHERE ER.ParentGUID = @ShiftGuid
															  AND ER.ParentType = 702 )

DECLARE @CheckIfShiftHasNotCanceledExternalOperations INT = ( SELECT COUNT(*)
															  FROM POSExternalOperations000
															  WHERE ShiftGuid  = @ShiftGuid
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
