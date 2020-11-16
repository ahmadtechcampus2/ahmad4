################################################################################
CREATE FUNCTION fnCheckIfAccUsedInPOSSmartDeviceOptions()
RETURNS @SmartDevicesOptionsAccountsList TABLE 
(
		[GUID]	UNIQUEIDENTIFIER
)
AS 
BEGIN
       
	DECLARE @CentralAccGUID UNIQUEIDENTIFIER
	DECLARE @DebitAccGUID   UNIQUEIDENTIFIER
	DECLARE @CreditAccGUID  UNIQUEIDENTIFIER
	DECLARE @ExpenseAccGUID UNIQUEIDENTIFIER
	DECLARE @IncomeAccGUID  UNIQUEIDENTIFIER

	DECLARE AllPOSOperationsAccounts  CURSOR FOR	
	SELECT  CentralAccGUID,
			DebitAccGUID,
			CreditAccGUID,
			ExpenseAccGUID,
			IncomeAccGUID
	FROM POSCard000 
	OPEN AllPOSOperationsAccounts;	

	FETCH NEXT FROM AllPOSOperationsAccounts INTO @CentralAccGUID, @DebitAccGUID, @CreditAccGUID, @ExpenseAccGUID, @IncomeAccGUID;
	WHILE (@@FETCH_STATUS = 0)
	BEGIN  
	
	IF(@CentralAccGUID != 0x0)
		INSERT INTO  @SmartDevicesOptionsAccountsList ([GUID]) (SELECT [GUID] 
															    FROM dbo.fnGetAccountsList(@CentralAccGUID, 0) 
																WHERE [GUID] NOT IN (SELECT [Guid] FROM @SmartDevicesOptionsAccountsList))

	IF(@DebitAccGUID   != 0x0)
		INSERT INTO  @SmartDevicesOptionsAccountsList ([GUID]) (SELECT [GUID] 
																FROM dbo.fnGetAccountsList(@DebitAccGUID  , 0) 
																WHERE [GUID] NOT IN (SELECT [Guid] FROM @SmartDevicesOptionsAccountsList))

	IF(@CreditAccGUID  != 0x0)
		INSERT INTO  @SmartDevicesOptionsAccountsList ([GUID]) (SELECT [GUID] 
																FROM dbo.fnGetAccountsList(@CreditAccGUID , 0) 
																WHERE [GUID] NOT IN (SELECT [Guid] FROM @SmartDevicesOptionsAccountsList))

	IF(@ExpenseAccGUID != 0x0)
		INSERT INTO  @SmartDevicesOptionsAccountsList ([GUID]) (SELECT [GUID] 
																FROM dbo.fnGetAccountsList(@ExpenseAccGUID, 0) 
																WHERE [GUID] NOT IN (SELECT [Guid] FROM @SmartDevicesOptionsAccountsList))

	IF(@IncomeAccGUID  != 0x0)
		INSERT INTO  @SmartDevicesOptionsAccountsList ([GUID]) (SELECT [GUID] 
																FROM dbo.fnGetAccountsList(@IncomeAccGUID , 0) 
																WHERE [GUID] NOT IN (SELECT [Guid] FROM @SmartDevicesOptionsAccountsList))

	FETCH NEXT FROM AllPOSOperationsAccounts INTO  @CentralAccGUID, @DebitAccGUID, @CreditAccGUID, @ExpenseAccGUID, @IncomeAccGUID;
	END

	CLOSE      AllPOSOperationsAccounts;
	DEALLOCATE AllPOSOperationsAccounts;

	RETURN

END
#################################################################
#END
