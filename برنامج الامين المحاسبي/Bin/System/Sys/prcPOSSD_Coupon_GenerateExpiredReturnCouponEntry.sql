################################################################################
CREATE PROCEDURE prcPOSSD_Coupon_GenerateExpiredReturnCouponEntry
-- Params -------------------------------
	@FromDate			DATETIME,
	@ToDate				DATETIME
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	DECLARE @EN TABLE( [Number]			INT,
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
					   [Notes]		    NVARCHAR(1000),
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

	DECLARE @ExpiredCoupon TABLE( ReturnCouponGUID  UNIQUEIDENTIFIER,
								  TicketGUID        UNIQUEIDENTIFIER,
								  TicketType        INT,
								  [Type]		    INT,
								  Code			    NVARCHAR(500),
								  StationGUID	    UNIQUEIDENTIFIER,
								  Station		    NVARCHAR(250),
								  CustomerGUID	    UNIQUEIDENTIFIER,
								  CustomerName	    NVARCHAR(250),
								  Amount		    FLOAT,
								  TransactionDate   DATETIME,
								  ExpiryDate	    DATETIME,
								  ExpiryDays	    INT,
								  AccountGUID	    UNIQUEIDENTIFIER,
								  Account		    NVARCHAR(250),
								  ExpireAccountGUID UNIQUEIDENTIFIER,
								  ExpireAccount     NVARCHAR(250) )

	DECLARE @ENNumber			   INT = 0
	DECLARE @NewCENumber		   INT
	DECLARE @ENValue		       FLOAT
	DECLARE @TotalCouponAmount	   FLOAT
	DECLARE @ENNote			       NVARCHAR(250)
	DECLARE @CENote				   NVARCHAR(1000)
	DECLARE @txt_CancelRECoupon    NVARCHAR(250)
	DECLARE @txt_CancelRECard      NVARCHAR(250)
	DECLARE @txt_DeliveredToCust   NVARCHAR(250)
	DECLARE @txt_ExpiryDate        NVARCHAR(250)
	DECLARE @AccGuid		       UNIQUEIDENTIFIER
	DECLARE @ExpireAccountGUID     UNIQUEIDENTIFIER
	DECLARE @DefCurrencyGUID	   UNIQUEIDENTIFIER 
	DECLARE @EntryGUID			   UNIQUEIDENTIFIER 
	DECLARE @BranchGuid			   UNIQUEIDENTIFIER
	DECLARE @ExpiredCouponGUID     UNIQUEIDENTIFIER
	DECLARE @language			   INT = [dbo].[fnConnections_getLanguage]()

	DECLARE @User UNIQUEIDENTIFIER = (SELECT TOP 1 [GUID] FROM us000 WHERE [bAdmin] = 1 AND [Type] = 0 ORDER BY [Number])	
	EXEC prcConnections_Add @User
	INSERT INTO @ExpiredCoupon EXEC prcPOSSD_Coupon_GetExpiredReturnCoupon 0x0, @FromDate, @ToDate
	SET @txt_CancelRECoupon  = [dbo].[fnStrings_get]('POSSD\CANCEL_RETURN_COUPON',  @language)
	SET @txt_CancelRECard    = [dbo].[fnStrings_get]('POSSD\CANCEL_RETURN_CARD',    @language)
	SET @txt_DeliveredToCust = [dbo].[fnStrings_get]('POSSD\DELIVERED_TO_CUST',     @language)
	SET @txt_ExpiryDate      = [dbo].[fnStrings_get]('POSSD\EXPIRY_DATE',           @language)
	SET @CENote			     = [dbo].[fnStrings_get]('POSSD\EXPIRED_RETURN_COUPON', @language) + CAST(CONVERT(DATE, @ToDate) AS NVARCHAR(250))

	SET @BranchGuid         = ( SELECT TOP 1 [GUID] FROM br000 ORDER BY Number )
	SET @NewCENumber        = ( SELECT ISNULL(MAX(Number), 0) + 1 FROM ce000  WHERE Branch = ISNULL(@BranchGuid, 0x0) )
	SET @DefCurrencyGUID    = ( SELECT TOP 1 [GUID] FROM my000 WHERE CurrencyVal = 1 ORDER BY [Number] )
	SET @TotalCouponAmount  = ( SELECT SUM(Amount) FROM  @ExpiredCoupon )
	SET @EntryGUID          = NEWID()
	SET @ExpiredCouponGUID  = NEWID()
	 

	INSERT INTO @CE
	SELECT 1								AS [Type],
		   @NewCENumber					    AS Number,
		   GETDATE()						AS [Date],
		   @TotalCouponAmount				AS Debit,
		   @TotalCouponAmount				AS Credit,
		   @CENote							AS Notes,
		   1								AS  CurrencyVal,
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



	DECLARE @AllExpiredCoupon CURSOR 
	SET @AllExpiredCoupon = CURSOR FAST_FORWARD FOR
	SELECT  
		Amount,
		( CASE [Type] WHEN 0 THEN @txt_CancelRECoupon 
					  ELSE @txt_CancelRECard END ) + Code +' '
		+ @txt_DeliveredToCust + CustomerName +' '
		+ @txt_ExpiryDate + CAST(CONVERT(DATE, ExpiryDate) AS NVARCHAR(250)),
		AccountGUID,
		ExpireAccountGUID
		[Type]
	FROM 
		@ExpiredCoupon
	OPEN @AllExpiredCoupon;	

		FETCH NEXT FROM @AllExpiredCoupon INTO @ENValue, @ENNote, @AccGuid, @ExpireAccountGUID;
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
				  @ExpireAccountGUID	AS ContraAccGUID
		

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
				  @ExpireAccountGUID	AS accountGUID,
				  @DefCurrencyGUID		AS CurrencyGUID,
				  0x0					AS CostGUID,
				  @AccGuid				AS ContraAccGUID

		FETCH NEXT FROM @AllExpiredCoupon INTO @ENValue, @ENNote, @AccGuid, @ExpireAccountGUID;
		END

		CLOSE      @AllExpiredCoupon;
		DEALLOCATE @AllExpiredCoupon;

	INSERT INTO @ER
	SELECT NEWID()	          AS [GUID],
		   @EntryGUID         AS EntryGUID,
		   @ExpiredCouponGUID AS ParentGUID,
		   709		          AS ParentType,
		   0

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

			INSERT INTO POSSDExpiredReturnCoupon000 ( [GUID],
													  [Date],
													  [FromDate],
													  [ToDate],
													  [Amount],
													  [EntryGUID] ) SELECT @ExpiredCouponGUID, 
																		   GETDATE(), 
																		   @FromDate, 
																		   @ToDate, 
																		   @TotalCouponAmount, 
																		   @EntryGUID

		   UPDATE 
			POSSDReturnCoupon000 SET ProcessedExpiryCoupon = @ExpiredCouponGUID
		   FROM  
			POSSDReturnCoupon000 RC 
			INNER JOIN @ExpiredCoupon EC ON RC.[GUID] = EC.ReturnCouponGUID
	END

	IF((SELECT COUNT(*) FROM er000 WHERE parentGUID = @ExpiredCouponGUID) = 0)
	BEGIN
		SELECT 0 AS IsGenerate
		RETURN;
	END

	IF((SELECT COUNT(*) FROM POSSDExpiredReturnCoupon000 WHERE [GUID] = @ExpiredCouponGUID) = 0)
	BEGIN
		SELECT 0 AS IsGenerate
		RETURN;
	END

	SELECT 1 AS IsGenerate
#################################################################
#END
