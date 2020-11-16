################################################################################
CREATE PROCEDURE prcPOSSD_Order_CreateNewAccount
	@POSStationGuid 		UNIQUEIDENTIFIER = 0x0,
	@CustomerName			NVARCHAR(MAX),
	@accountCode            NVARCHAR(256)
AS

/*******************************************************************************************************
Create new account for new customer under station's debit Account 
*******************************************************************************************************/

	DECLARE @debitAccountGuid UNIQUEIDENTIFIER = (SELECT DebitAccGUID FROM POSSDStation000 WHERE GUID = @POSStationGuid)
	DECLARE @finalGuid		  UNIQUEIDENTIFIER = (SELECT FinalGuid FROM ac000 WHERE Guid = @debitAccountGuid)
    DECLARE @defaultCurrency  UNIQUEIDENTIFIER = (SELECT [dbo].[fnGetDefaultCurr]())
	DECLARE @accountGuid	  UNIQUEIDENTIFIER = NEWID()
	DECLARE @startDate		  DATETIME         = (SELECT [dbo].fnPOSSD_GetFileDates(1))
    DECLARE @accountNumber	  INT              = ISNULL((SELECT MAX(Number) FROM ac000), 0) + 1
    
	
	INSERT INTO ac000 ( Number, 
						[Name], 
						Code, 
						CDate, 
						NSons, 
						Debit, 
						Credit, 
						InitDebit, 
						InitCredit, 
						UseFlag, 
						MaxDebit, 
						Notes, 
						CurrencyVal, 
						Warn, 
						CheckDate, 
						[Security], 
						DebitOrCredit, 
						[Type], 
						[State], 
						Num1, 
						Num2, 
						LatinName, 
						[GUID], 
						ParentGUID, 
						FinalGUID, 
						CurrencyGUID, 
						BranchGUID, 
						branchMask )
	VALUES ( @accountNumber,
		     @CustomerName,
		     @accountCode,
		     GETDATE(),
		     0,
		     0,
		     0,
		     0,
		     0,
		     0, 
		     0,
		     '',
		     1,
		     0,
	         @startDate,
	         1,
	         0,
	         1,
	         0,
	         0,
	         0,
	         '',
	         @accountGuid,
	         @debitAccountGuid,
	         @finalGuid,
	         @defaultCurrency,
	         0x0,
	         0 )

	SELECT @accountGuid AS AccountGuid
#################################################################
#END
