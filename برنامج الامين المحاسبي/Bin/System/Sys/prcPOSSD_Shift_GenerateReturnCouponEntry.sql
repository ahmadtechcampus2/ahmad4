#################################################################
CREATE PROCEDURE prcPOSSD_Shift_GenerateReturnCouponEntry
-- Params -------------------------------
	@ShiftGuid					UNIQUEIDENTIFIER,
	@ReturnCouponSettingType	INT, -- 0: Coupon,  1: Card
	@TicketReturnCouponType     INT  -- 0: Receive, 1: Pay
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
	DECLARE @EntryType					INT
	DECLARE @ENValue		            FLOAT
	DECLARE @ENNote			            NVARCHAR(250)
	DECLARE @AccGuid		            UNIQUEIDENTIFIER
	DECLARE @ShiftControlAccGUID        UNIQUEIDENTIFIER
	DECLARE @DefCurrencyGUID			UNIQUEIDENTIFIER 
	DECLARE @EntryGUID					UNIQUEIDENTIFIER 
	DECLARE @BranchGuid				    UNIQUEIDENTIFIER
	DECLARE @CostGUID				    UNIQUEIDENTIFIER
	DECLARE @CENumber					INT
	DECLARE @CENote				     	NVARCHAR(1000)
	DECLARE @CEValue					FLOAT
	DECLARE @language				    INT
	DECLARE @txt_ReturnCouponInShift    NVARCHAR(250)
	DECLARE @txt_POSStation		        NVARCHAR(250)
	DECLARE @txt_POSEmployee	        NVARCHAR(250)
	DECLARE @txt_CouponToCustomer       NVARCHAR(250)
	DECLARE @txt_CouponExpiryDate       NVARCHAR(250)
	DECLARE @txt_InShift			    NVARCHAR(250)
	SET @language = [dbo].[fnConnections_getLanguage]()
	IF(@ReturnCouponSettingType = 0 AND @TicketReturnCouponType = 0)-- قسائم مسلّمة
	BEGIN
		SET @txt_ReturnCouponInShift = [dbo].[fnStrings_get]('POSSD\SHIFT_RECEIVE_COUPON',       @language)
		SET @txt_CouponToCustomer    = [dbo].[fnStrings_get]('POSSD\RECEIVE_COUPON_TO_CUSTOMER', @language)
		SET @EntryType = 705
	END
	IF(@ReturnCouponSettingType = 1 AND @TicketReturnCouponType = 0)-- بطاقات مسلّمة
	BEGIN
		SET @txt_ReturnCouponInShift = [dbo].[fnStrings_get]('POSSD\SHIFT_RECEIVE_CARD',         @language)
		SET @txt_CouponToCustomer    = [dbo].[fnStrings_get]('POSSD\RECEIVE_CARD_TO_CUSTOMER',   @language)
		SET @EntryType = 706
	END
	IF(@ReturnCouponSettingType = 0 AND @TicketReturnCouponType = 1)-- قسائم مستلمة
	BEGIN
		SET @txt_ReturnCouponInShift = [dbo].[fnStrings_get]('POSSD\SHIFT_PAY_COUPON',           @language)
		SET @txt_CouponToCustomer    = [dbo].[fnStrings_get]('POSSD\PAY_COUPON_FROM_CUSTOMER',   @language)
		SET @EntryType = 707
	END
	IF(@ReturnCouponSettingType = 1 AND @TicketReturnCouponType = 1)-- بطاقات مستلمة
	BEGIN
		SET @txt_ReturnCouponInShift = [dbo].[fnStrings_get]('POSSD\SHIFT_PAY_CARD',             @language)
		SET @txt_CouponToCustomer    = [dbo].[fnStrings_get]('POSSD\PAY_CARD_FROM_CUSTOMER',     @language)
		SET @EntryType = 708
	END
	SET @txt_POSStation			     = [dbo].[fnStrings_get]('POSSD\STATION_RECEIVE_COUPON',     @language)
	SET @txt_POSEmployee		     = [dbo].[fnStrings_get]('POSSD\BANK_ENTRY_EMPLOYEE',        @language)	
	SET @txt_CouponExpiryDate        = [dbo].[fnStrings_get]('POSSD\COUPON_EXPIRY_DATE',		 @language)
	SET @txt_InShift			     = [dbo].[fnStrings_get]('POSSD\IN_SHIFT',					 @language)
	SET @CENote = ( SELECT  
						@txt_ReturnCouponInShift + CAST(S.Code AS NVARCHAR(250)) 
					  + @txt_POSStation + CAST(C.Code AS NVARCHAR(250)) + '-' + CASE @language WHEN 0 THEN C.Name ELSE CASE C.LatinName WHEN '' THEN C.Name ELSE C.LatinName END END
					  + @txt_POSEmployee 
					  + CASE @language WHEN 0 THEN E.Name ELSE CASE E.LatinName WHEN '' THEN E.Name ELSE E.LatinName END END  
					FROM 
						POSSDShift000 S
						LEFT JOIN POSSDStation000 C ON S.StationGUID = C.[Guid]
						LEFT JOIN POSSDEmployee000 E ON S.EmployeeGUID = E.[Guid]
					WHERE 
						S.[GUID] = @ShiftGuid )
	
	 SET @BranchGuid      = (SELECT TOP 1 [GUID] FROM br000 ORDER BY Number)
	 SET @CENumber		  = (SELECT ISNULL(MAX(Number), 0) + 1 FROM ce000  WHERE Branch = ISNULL(@BranchGuid, 0x0))
	 SET @DefCurrencyGUID = (SELECT TOP 1 [GUID] FROM my000 WHERE CurrencyVal = 1 ORDER BY [Number])
	 SET @EntryGUID       = NEWID()
	 SET @CEValue         = (SELECT 
								 ISNULL(SUM(TRC.Amount), 0) 
							 FROM 
								 POSSDTicket000 T 
								 INNER JOIN POSSDTicketReturnCoupon000 TRC ON T.[GUID] = TRC.TicketGUID 
								 INNER JOIN POSSDReturnCoupon000 RC ON TRC.ReturnCouponGUID = RC.[GUID]
								 INNER JOIN POSSDStationReturnCouponSettings000 SRCS ON RC.ReturnSettingsGUID = SRCS.[GUID]
							 WHERE 
								 T.ShiftGUID = @ShiftGuid 
								 AND TRC.[IsReceipt] = @TicketReturnCouponType 
								 AND TRC.[Type] = @ReturnCouponSettingType 
								AND SRCS.[Type] = @ReturnCouponSettingType
								 )
	INSERT INTO @CE
	SELECT 1							AS [Type],
		   @CENumber					AS Number,
		   GETDATE()					AS [Date],
		   @CEValue						AS Debit,
		   @CEValue						AS Credit,
		   @CENote						AS Notes,
		   1							AS  CurrencyVal,
		   0							AS IsPosted,
		   0							AS [State],
		   1							AS [Security],
		   0							AS Num1,
		   0							AS Num2,
		   ISNULL(@BranchGuid, 0x0)		AS Branch,
		   @EntryGUID					AS [GUID],
		   @DefCurrencyGUID				AS CurrencyGUID,
		   0x0							AS TypeGUID,
		   0							AS IsPrinted,
		   GETDATE()					AS PostDate

	DECLARE @AllShiftTicketsReceiveByCoupon CURSOR 
	SET @AllShiftTicketsReceiveByCoupon = CURSOR FAST_FORWARD FOR
	SELECT  
		TRC.Amount,
		@txt_CouponToCustomer + ISNULL(AC.cuCustomerName,'')
	  + @txt_CouponExpiryDate + CAST(CONVERT(DATE, DATEADD(DAY, RC.ExpiryDays, RC.TransactionDate)) AS NVARCHAR(250)) 
	  + @txt_InShift + CAST(S.Code AS NVARCHAR(250)) 
	  + @txt_POSStation + CAST(C.Code AS NVARCHAR(250)) + '-' + CASE @language WHEN 0 THEN C.Name ELSE CASE C.LatinName WHEN '' THEN C.Name ELSE C.LatinName END END
	  + @txt_POSEmployee 
	  + CASE @language WHEN 0 THEN E.Name ELSE CASE E.LatinName WHEN '' THEN E.Name ELSE E.LatinName END END,
		SRCS.AccountGUID AS accountGUID,
		C.ShiftControlGUID   AS ShiftControlAccGUID,
		SM.CostCenterGUID    AS CostGUID
	FROM 
		POSSDTicket000 T
		INNER JOIN POSSDTicketReturnCoupon000 TRC ON T.[GUID]	   = TRC.TicketGUID
		LEFT JOIN  POSSDReturnCoupon000 RC ON TRC.ReturnCouponGUID = RC.[GUID]
		LEFT JOIN  POSSDStationReturnCouponSettings000 SRCS ON RC.ReturnSettingsGUID = SRCS.[GUID]
		LEFT JOIN  POSSDShift000 S  ON T.ShiftGuid    = S.[GUID]
		LEFT JOIN  POSSDStation000 C  ON S.StationGUID  = C.[Guid]
		LEFT JOIN  vwCuAc AC ON RC.CustomerGuid = AC.cuGUID
		LEFT JOIN  POSSDEmployee000 E  ON S.EmployeeGUID = E.[Guid]
		LEFT JOIN  POSSDSalesman000 SM		 ON T.SalesmanGUID  = SM.[GUID]
	WHERE 
		T.ShiftGUID = @ShiftGuid
	AND	TRC.[IsReceipt]  = @TicketReturnCouponType AND TRC.Type = @ReturnCouponSettingType 
	AND SRCS.[Type] = @ReturnCouponSettingType

	OPEN @AllShiftTicketsReceiveByCoupon;	
		FETCH NEXT FROM @AllShiftTicketsReceiveByCoupon INTO @ENValue, @ENNote, @AccGuid, @ShiftControlAccGUID, @CostGUID;
		WHILE (@@FETCH_STATUS = 0)
		BEGIN  
			SET @ENNumber = @ENNumber + 1;
		  
		   INSERT INTO @EN
		   SELECT @ENNumber				AS Number,
				  GETDATE()				AS [Date],
				  CASE @TicketReturnCouponType WHEN 0 THEN 0 ELSE @ENValue	END 	AS Debit,
				  CASE @TicketReturnCouponType WHEN 0 THEN @ENValue ELSE 0	END 	AS Credit,
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
				  CASE @TicketReturnCouponType WHEN 0 THEN @ENValue ELSE 0	END 	AS Debit,
				  CASE @TicketReturnCouponType WHEN 0 THEN 0 ELSE @ENValue	END 	AS Credit,
				  @ENNote				AS Note,
				  1						AS CurrencyVal,
				  NEWID()				AS [GUID],
				  @EntryGUID			AS ParentGUID,
				  @ShiftControlAccGUID	AS accountGUID,
				  @DefCurrencyGUID		AS CurrencyGUID,
				  0x0					AS CostGUID,
				  @AccGuid				AS ContraAccGUID
	
		FETCH NEXT FROM @AllShiftTicketsReceiveByCoupon INTO @ENValue, @ENNote, @AccGuid, @ShiftControlAccGUID, @CostGUID;
		END
		CLOSE      @AllShiftTicketsReceiveByCoupon;
		DEALLOCATE @AllShiftTicketsReceiveByCoupon;
	
	INSERT INTO @ER
	SELECT NEWID()	  AS [GUID],
		   @EntryGUID AS EntryGUID,
		   @ShiftGuid AS ParentGUID,
		   @EntryType AS ParentType,
		   S.Code	  AS ParentNumber
	 FROM POSSDShift000 S
	 WHERE S.[GUID]  = @ShiftGuid
	
	------------- FINAL INSERT -------------
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
										AND ER.ParentType = @EntryType	)

	DECLARE @HasReturnCouponTickets INT = ( SELECT COUNT(*)
										    FROM POSSDTicket000 T
										    INNER JOIN POSSDTicketReturnCoupon000 TRC ON T.[GUID] = TRC.TicketGUID
										    WHERE T.ShiftGUID = @ShiftGuid AND T.[State] = 0
											AND	TRC.[IsReceipt] = @TicketReturnCouponType 
											AND TRC.Type = @ReturnCouponSettingType 
											)

   

	IF( @CheckGenerateEntry > 0 OR @HasReturnCouponTickets = 0 )
	BEGIN
		SELECT 1 AS IsGenerated
	END
	ELSE
	BEGIN
		SELECT 0 AS IsGenerated
	END
#################################################################
#END 