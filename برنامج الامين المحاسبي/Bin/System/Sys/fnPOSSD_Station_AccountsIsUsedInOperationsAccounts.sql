################################################################################
CREATE FUNCTION fnPOSSD_Station_AccountsIsUsedInOperationsAccounts
(
	   @CurrentPOS		          UNIQUEIDENTIFIER,
       @AccountToBeVerified		  UNIQUEIDENTIFIER,

	   @CentralAccOfTheCurrentPOS UNIQUEIDENTIFIER,
	   @DebitAccOfTheCurrentPOS   UNIQUEIDENTIFIER,
	   @CreditAccOfTheCurrentPOS  UNIQUEIDENTIFIER,
	   @ExpenseAccOfTheCurrentPOS UNIQUEIDENTIFIER,
	   @IncomeAccOfTheCurrentPOS  UNIQUEIDENTIFIER
)
RETURNS BIT
AS
BEGIN
       
	DECLARE @CentralAcc UNIQUEIDENTIFIER
	DECLARE @DebitAcc   UNIQUEIDENTIFIER
	DECLARE @CreditAcc  UNIQUEIDENTIFIER
	DECLARE @ExpenseAcc UNIQUEIDENTIFIER
	DECLARE @IncomeAcc  UNIQUEIDENTIFIER

	DECLARE AllPOSOperationsAccounts  CURSOR FOR	
	SELECT  CentralAccGUID,
			DebitAccGUID,
			CreditAccGUID,
			ExpenseAccGUID,
			IncomeAccGUID
	FROM POSSDStation000
	WHERE [GUID] != @CurrentPOS
	UNION ALL
	SELECT @CentralAccOfTheCurrentPOS,
		   @DebitAccOfTheCurrentPOS,
		   @CreditAccOfTheCurrentPOS,
		   @ExpenseAccOfTheCurrentPOS,
		   @IncomeAccOfTheCurrentPOS 

	OPEN AllPOSOperationsAccounts;	

	FETCH NEXT FROM AllPOSOperationsAccounts INTO @CentralAcc, @DebitAcc, @CreditAcc, @ExpenseAcc, @IncomeAcc;
	WHILE (@@FETCH_STATUS = 0)
	BEGIN  
	
	IF((@CentralAcc != 0x0) AND (@AccountToBeVerified IN (SELECT [GUID] FROM [dbo].[fnGetAccountsList](@CentralAcc, 1))))
		RETURN 1

	IF((@DebitAcc   != 0x0) AND (@AccountToBeVerified IN (SELECT [GUID] FROM [dbo].[fnGetAccountsList](@DebitAcc, 1))))
		RETURN 1

	IF((@CreditAcc  != 0x0) AND (@AccountToBeVerified IN (SELECT [GUID] FROM [dbo].[fnGetAccountsList](@CreditAcc, 1))))
		RETURN 1

	IF((@ExpenseAcc != 0x0) AND (@AccountToBeVerified IN (SELECT [GUID] FROM [dbo].[fnGetAccountsList](@ExpenseAcc, 1))))
		RETURN 1 

	IF((@IncomeAcc  != 0x0) AND (@AccountToBeVerified IN (SELECT [GUID] FROM [dbo].[fnGetAccountsList](@IncomeAcc, 1))))
		RETURN 1

	FETCH NEXT FROM AllPOSOperationsAccounts INTO @CentralAcc, @DebitAcc, @CreditAcc, @ExpenseAcc, @IncomeAcc;
	END

	CLOSE      AllPOSOperationsAccounts;
	DEALLOCATE AllPOSOperationsAccounts;

	RETURN 0

END
#################################################################
#END
