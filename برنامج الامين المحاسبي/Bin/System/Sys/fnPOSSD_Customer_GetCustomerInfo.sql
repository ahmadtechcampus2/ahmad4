#################################################################
CREATE FUNCTION fnPOSSD_Customer_GetCustomerInfo
-- Param ----------------------------------------------------------
	  ( @CustomerGuid UNIQUEIDENTIFIER )
-- Return ----------------------------------------------------------
RETURNS @Result TABLE( [GUID]		 UNIQUEIDENTIFIER, 
					   Number		 INT, 
					   CustomerName  NVARCHAR(250), 
					   LatinName	 NVARCHAR(250),  
					   Nationality	 NVARCHAR(250),
					   [Address]	 NVARCHAR(250),
					   Phone1		 NVARCHAR(100),
					   Phone2		 NVARCHAR(100),
					   FAX			 NVARCHAR(100),
					   TELEX		 NVARCHAR(100),
					   Notes		 NVARCHAR(250),
					   EMail		 NVARCHAR(250),
					   HomePage		 NVARCHAR(250),
					   Prefix		 NVARCHAR(100),
					   Suffix		 NVARCHAR(100),
					   GPSX			 FLOAT,
					   GPSY			 FLOAT,
					   GPSZ			 FLOAT,
					   Area			 NVARCHAR(100),
					   City			 NVARCHAR(100),
					   Street		 NVARCHAR(100),
					   POBox		 NVARCHAR(100),
					   ZipCode		 NVARCHAR(100),
					   Mobile		 NVARCHAR(100),
					   Pager		 NVARCHAR(100),
					   Country		 NVARCHAR(100),
					   Hoppies		 NVARCHAR(100),
					   Gender		 NVARCHAR(100),
					   [Certificate] NVARCHAR(100),
					   DateOfBirth	 DATETIME,
					   Job		     NVARCHAR(100),
					   JobCategory	 NVARCHAR(100),
					   AccountGUID	 UNIQUEIDENTIFIER,
					   NSEMail1	     NVARCHAR(250), 
					   NSEMail2	     NVARCHAR(250), 
					   NSMobile1	 NVARCHAR(100), 
					   NSMobile2	 NVARCHAR(100),
					   Head			 NVARCHAR(250),
					   GCCLocationGUID UNIQUEIDENTIFIER,
					   TaxCode		INT,
					   TaxNumber	NVARCHAR(100),
					   DefaultAddressGUID UNIQUEIDENTIFIER)
--------------------------------------------------------------------
AS 
BEGIN
	INSERT INTO @Result
	SELECT 
		CU.[GUID], 
		CAST(Number AS INT) Number, 	
		CustomerName,  	
		LatinName,	 
		Nationality,	
		[Address], 
		Phone1, 
		Phone2, 
		FAX,
		TELEX,
		Notes,
		EMail,
		HomePage,	 
		Prefix,
		Suffix,
		GPSX,	 
		GPSY,	 
		GPSZ,	 
		Area,	 
		City,	 
		Street,
		POBox,
		ZipCode,
		Mobile,
		Pager,
		Country,
		Hoppies,
		Gender,
		[Certificate], 
		DateOfBirth,
		Job,
		JobCategory,
		AccountGUID,
		NSEMail1,    
		NSEMail2,    
		NSMobile1,
		NSMobile2,
		Head,
		GCCLocationGUID,	 
		GCCCU.TaxCode,
		GCCCU.TaxNumber,
		CU.DefaultAddressGUID
		FROM vexCu AS CU LEFT JOIN GCCCustomerTax000  AS GCCCU  ON (GCCCU.CustGUID = CU.GUID)		
		WHERE CU.[GUID] = @CustomerGuid
RETURN 
END

#################################################################
CREATE FUNCTION fnPOSSD_AccCust_getBalance(@CustomerGuid uniqueidentifier	) RETURNS float
AS 
BEGIN
/*******************************************************************************************************
	Company : Syriansoft
	Function : fnPOSSD_AccCust_getBalance
	Purpose: get the balance of a specific customer
	How to Call: SELECT DBO.fnPOSSD_AccCust_getBalance ('3C2561FE-406C-446D-AFE3-6212319487F8')
	Create By: Hanadi Salka													Created On: 28 Dec 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	DECLARE @AccountGuid UNIQUEIDENTIFIER;
	DECLARE @CurrencyGuid UNIQUEIDENTIFIER = 0x0;
	DECLARE @StartDate DATETIME;
	DECLARE @EndDate DATETIME;
	DECLARE @CostGuid [UNIQUEIDENTIFIER] =0x00;	
	DECLARE @CurrentBalance FLOAT;
	DECLARE @Balance FLOAT;
	DECLARE @OpenShiftTicketBalance FLOAT;
	DECLARE @OpenShiftExternalOperationBalance FLOAT;
	IF @CustomerGuid IS NULL OR @CustomerGuid = 0X00 
		RETURN @Balance;

	SELECT @AccountGuid = AccountGUID 
	FROM vcCu WHERE GUID = @CustomerGuid;

	SET @StartDate = DBO.fnPOSSD_GetFileDates(1);
	SET @EndDate = DBO.fnPOSSD_GetFileDates(0);

	SET @CurrentBalance = ISNULL(dbo.fnAccCust_getBalance(@AccountGuid,  @CurrencyGuid,  @StartDate, @EndDate, @CostGuid, @CustomerGuid),0);

	SET @OpenShiftTicketBalance = ISNULL((SELECT	
									SUM (
										CASE WHEN (t.type = 1 OR T.Type = 2) THEN t.LaterValue * -1
										WHEN (t.type = 0 OR T.Type = 3) THEN t.LaterValue 
										ELSE 0 END
									) AS LaterValue
								FROM POSSDTicket000 AS t inner join POSSDShift000 AS s ON (s.GUID = t.ShiftGUID)								
								WHERE t.customerguid = @CustomerGuid and CloseDate is null and t.State = 0
								GROUP BY t.CustomerGUID),0);

	SET @OpenShiftExternalOperationBalance = ISNULL((SELECT SUM (
											CASE WHEN (EO.IsPayment = 1) THEN (EO.Amount * EO.CurrencyValue)
											WHEN  (EO.IsPayment = 0) THEN ((EO.Amount * EO.CurrencyValue) * -1)
											ELSE 0 END
											) AS BALANCE
										FROM POSSDExternalOperation000 as eo inner join POSSDShift000 as s on (s.GUID = eo.ShiftGUID)
										WHERE customerguid = @CustomerGuid and CloseDate is null and EO.State = 0),0);

	SET @Balance = @CurrentBalance +  @OpenShiftTicketBalance + @OpenShiftExternalOperationBalance;
	RETURN @Balance;
END
#################################################################
#END 