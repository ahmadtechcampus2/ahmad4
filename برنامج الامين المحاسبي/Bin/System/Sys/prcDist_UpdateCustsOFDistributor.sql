################################################################################
CREATE FUNCTION fnGetCodeParts(
	@code NVARCHAR(max),
	@parentCode NVARCHAR(max) = '',
	@GetNumeric BIT = 1,
	@NumericCode NVARCHAR(MAX) = ''
	)
RETURNS NVARCHAR(MAX)
AS
BEGIN
	IF(@GetNumeric = 1)
	BEGIN
		DECLARE @curCode NVARCHAR(MAX) = '',
				@NumCode NVARCHAR(MAX) = '',
				@charIndex INT

		IF(SUBSTRING(@code, 1, len(@parentCode)) like @parentCode)
		BEGIN
			SET @code = SUBSTRING(@code, LEN(@parentCode) + 1, LEN(@code))
		END
		SET @charIndex = LEN(@code)
		WHILE (1 <= @charIndex)
		BEGIN
			SET @curCode = SUBSTRING(@Code, @charIndex, 1)
			IF(ISNUMERIC(@curCode) = 1)
			BEGIN
				SET @NumCode = @NumCode + @curCode
			END
			ELSE
				BREAK
			SET @charIndex -= 1
		END
		RETURN REVERSE(@NumCode)
	END

	DECLARE @nonNumriCode NVARCHAR(MAX) = ''

	SET @nonNumriCode = CASE WHEN @parentCode = SUBSTRING(@code, 1, LEN(@parentCode)) 
						     THEN SUBSTRING(@code, LEN(@parentCode) + 1, LEN(@code))
							 ELSE '' END

	SET @nonNumriCode = CASE WHEN LEN(@nonNumriCode) > LEN(@NumericCode)
							 THEN SUBSTRING(@nonNumriCode, 1, LEN(@nonNumriCode) - LEN(@NumericCode)) 
							 ELSE '' END
	RETURN @nonNumriCode
END
################################################################################
CREATE PROCEDURE GetNextMaximumCode(
									@TableName NVARCHAR(MAX),
									@ColName NVARCHAR(MAX),
									@ParentGUID UNIQUEIDENTIFIER,
									@NewMaxCode NVARCHAR(MAX) OUTPUT)
AS  
	SET NOCOUNT ON
	DECLARE	@sql NVARCHAR(Max) = ''
	IF (@ParentGUID = 0x0)
	BEGIN
		Set @sql = 'SELECT @NewMaxCode = Max(CASE ISNUMERIC(code)
												WHEN 1 THEN CODE
												ELSE 0 END) + 1
					 FROM ' + @TableName + ' WHERE '+@ColName+' = '''+CAST(@ParentGUID AS NVARCHAR(max))+''''
		
		exec sp_executesql @sql, N'@NewMaxCode NVARCHAR(MAX) OUT', @NewMaxCode OUT
		RETURN
	END
	Declare @ParentCode NVARCHAR(Max)
	CREATE TABLE #TempCodesTbl
	(
		childGUID UNIQUEIDENTIFIER,
		childCODE NVARCHAR(MAX),
		parentCODE NVARCHAR(MAX),
		NumericCode NVARCHAR(MAX),
		NonNumericCode NVARCHAR(MAX)
	)
	Set @sql = 'INSERT INTO #TempCodesTbl'
	Set @sql += ' Select child.Guid ,child.CODE, parent.CODE, 
				 dbo.fnGetCodeParts(child.CODE, parent.CODE, 1 , Null), Null FROM ' + @TableName + ' AS child ' +
				' INNER JOIN '+@TableName+' parent on parent.GUID = child.'+ @ColName+
				' WHERE child.'+@ColName+' = '''+CAST(@ParentGUID AS NVARCHAR(max))+''''
	EXEC (@sql)

	UPDATE #TempCodesTbl SET NonNumericCode = dbo.fnGetCodeParts(childCODE, parentCODE, 0 , NumericCode)

	SELECT TOP 1  @NewMaxCode = CASE WHEN NumericCode = ''
								THEN parentCODE + NonNumericCode + '001'
								ELSE parentCODE + NonNumericCode + 
									 CASE WHEN PATINDEX('%[0-9]%', NumericCode) > 0 
									 THEN 
										RIGHT( REPLICATE('0', LEN(NumericCode) - PATINDEX('%[0-9]%', NumericCode) + 1) + CONVERT( NVARCHAR, CONVERT(BIGINT, RIGHT(NumericCode, LEN(NumericCode) - PATINDEX('%[0-9]%', NumericCode) + 1)) + 1), 
											CASE WHEN LEN(NumericCode) - PATINDEX('%[0-9]%', NumericCode) + 1 >= LEN (CONVERT( NVARCHAR, CONVERT(BIGINT, RIGHT(NumericCode, LEN(NumericCode) - PATINDEX('%[0-9]%', NumericCode) + 1)) + 1)) 
											THEN  
												LEN(NumericCode) - PATINDEX('%[0-9]%', NumericCode) + 1 
											ELSE 
												LEN (CONVERT( NVARCHAR, CONVERT(BIGINT, RIGHT(NumericCode, LEN(NumericCode) - PATINDEX('%[0-9]%', NumericCode) + 1)) + 1)) 
											END)
									  ELSE 
									   	 NumericCode 
									   END
									END
				 FROM
				 #TempCodesTbl ORDER BY CONVERT(BIGINT, NumericCode) DESC
################################################################################
CREATE PROC prcDist_UpdateCustsOFDistributor
		@DistGuid UNIQUEIDENTIFIER				 
AS 
BEGIN 
	SET NOCOUNT ON 	  
	DECLARE	@C          				CURSOR,  
        	@CustGuid					UNIQUEIDENTIFIER,  
			@NewBarcode					NVARCHAR(100),  
			@NewNotes					NVARCHAR(250), 
			@Name						NVARCHAR(250), 
			@LatinName					NVARCHAR(250),
			@Code						NVARCHAR(250), 
			@Area						NVARCHAR(100), 
			@Street						NVARCHAR(100), 
			@Phone						NVARCHAR(50), 
			@pager						NVARCHAR(250),
			@Mobile						NVARCHAR(50), 
			@Phone2						NVARCHAR(250),
			@Address					NVARCHAR(250),
			@ZipCode					NVARCHAR(250),
			@PersonalName				NVARCHAR(250), 
        	@CustTypeGuid				UNIQUEIDENTIFIER,  
        	@TradeChannelGuid			UNIQUEIDENTIFIER,  
        	@Contracted					BIT, 
			@New						BIT,
			@GPSX						FLOAT,  
			@GPSY						FLOAT,
			@NewCustomerDefaultPrice	FLOAT,
			@DistributorCostGuid		UNIQUEIDENTIFIER,
			@Rout1						INT,
			@AutoNewCustToRoute			BIT,
			@DefaultAddressGuid			UNIQUEIDENTIFIER
			
	SELECT 
		@NewCustomerDefaultPrice = ISNULL(NewCustomerDefaultPrice, 128),
		@AutoNewCustToRoute = AutoNewCustToRoute
	FROM
		Distributor000
	WHERE
		Guid = @DistGuid
	
	SET @DistributorCostGuid = 0x0
	
	SELECT
		@DistributorCostGuid =  ISNULL(CostGUID , 0x0)
	FROM 
		DistSalesman000 s
		INNER JOIN Distributor000 d ON d.PrimSalesmanGUID = s.GUID
	WHERE 
		d.GUID = @DistGuid
			
	SET @C = CURSOR FAST_FORWARD FOR  
    	SELECT	
			[cu].[CustomerGuid],  
			ISNULL([cu].[NewBarcode], ''),  
			ISNULL([cu].[NewNotes], ''),  
			ISNULL([cu].[Name], ''),  
			ISNULL([a].[Name], ''),  
			ISNULL([ca].[Street], ''),  
			ISNULL([cu].[Phone], ''),  
			ISNULL([cu].[Mobile], ''),  
			ISNULL([cu].[PersonalName], ''),  
			ISNULL([cu].[CustomerTypeGuid], 0x00),  
			ISNULL([cu].[TradeChannelGuid], 0x00),  
			ISNULL([cu].[Contracted], 0),
			ISNULL([ca].[GPSX], 0),
			ISNULL([ca].[GPSY], 0),
			ISNULL([cu].[latinName], ''),
			ISNULL([ca].[MoreDetails], ''),
			ISNULL([cu].[pager], ''),
			ISNULL([cu].[Phone2], ''),
			ISNULL([ca].[ZipCode], ''),
			ISNULL([cu].[Route1], 0),
			ISNULL([cu].[DefaultAddressGUID], 0x0)  
		FROM 
			[DistDeviceNewCu000] cu
			INNER JOIN [DistDeviceCustAddress000] ca ON [ca].[AddressGuid] = [cu].[DefaultAddressGuid] 
			LEFT JOIN [DistDeviceAddressArea000] a ON [a].[Guid] = [ca].[AreaGuid] 
		WHERE 
			[cu].[DistributorGuid] = @DistGuid  

	OPEN @C	
	FETCH FROM @C 
	INTO 
		@CustGuid, 
		@NewBarcode, 
		@NewNotes, 
		@Name, 
		@Area, 
		@Street, 
		@Phone, 
		@Mobile,
		@PersonalName,
		@CustTypeGuid, 
		@TradeChannelGuid, 
		@Contracted, 
		@GPSX, 
		@GPSY, 
		@LatinName,
		@Address,
		@pager,
		@Phone2,
		@ZipCode,
		@Rout1,
		@DefaultAddressGuid
	WHILE @@fetch_status = 0  
	BEGIN  
		------------------------------------------------------------------------------------- 
		--------------------- UPDATE CUST INFORMATION 
		IF Exists (Select GUID FROM [Cu000] Where [Guid] = @CustGuid)  
        BEGIN  
			-- Add Cust Befor Updates 
			IF NOT EXISTS(SELECT CustGuid FROM DistCustUpdates000 WHERE CustGuid = @CustGuid) 
			BEGIN 
				DECLARE @OldCtGuid		UNIQUEIDENTIFIER, 
						@OldTchGuid		UNIQUEIDENTIFIER, 
						@OldContracted	INT 

				SELECT 
					@OldCtGuid = CustomerTypeGuid, 
					@OldTchGuid = TradeChannelGuid, 
					@OldContracted = Contracted 
				FROM 
					DistCe000 
				WHERE 
					CustomerGuid = @CustGuid 
				
				INSERT INTO DistCustUpdates000 (Guid, DistGuid, CustGuid, Barcode, Name, Area, Street, Phone, Mobile, PersonalName,
				 Notes, CustTypeGuid, TradeChannelGuid, Contracted, New, Date, GPSX, GPSY , Address , pager , Phone2 , ZipCode ) 
				SELECT 
					newId(), 
					@DistGuid, 
					Guid, 
					Barcode, 
					CustomerName,
					Area, 
					Street, 
					Phone1, 
					Mobile, 
					Head, 
					Notes, 
					ISNULL(@OldCtGuid, 0x00), 
					ISNULL(@OldTchGuid, 0x00), 
					ISNULL(@OldContracted, 0), 
					0, 
					getDate(), 
					GPSX, 
					GPSY,
					Address,
					pager,
					Phone2,
					ZipCode
				FROM 
					vexCu 
				WHERE 
					Guid = @CustGuid 	 
			END 
			-- Update Cust Information 
			IF(@NewBarcode <> '')
			BEGIN
			UPDATE [cu000] 
			SET 
				[Barcode] = '' 
			Where 
				[barcode] = @NewBarcode  
			END
			---------------------------
			UPDATE [cu000] 
			SET 
				[Barcode] = @NewBarcode, 
				[Notes] = @NewNotes, 
				[CustomerName] = @Name,
				[Phone1] = @Phone, 
				[Mobile] = @Mobile, 
				[Head] = @PersonalName,
				[LatinName] = @LatinName,
				[pager] = @pager,
				[Phone2] = @Phone2,
				[DefaultAddressGUID] = @DefaultAddressGuid
			WHERE 
				[Guid] = @CustGuid

			IF EXISTS (SELECT Guid FROM DistCe000 WHERE CustomerGuid = @CustGuid) 
			BEGIN 
				UPDATE DistCe000 SET TradeChannelGuid = @TradeChannelGuid, CustomerTypeGuid = @CustTypeGuid, Contracted = @Contracted 
				WHERE CustomerGuid = @CustGuid 
			END 
			ELSE 
			BEGIN 
				INSERT INTO DistCe000(CustomerGuid, TradeChannelGuid, CustomerTypeGuid, Contracted) 
							VALUES	 (@CustGuid, @TradeChannelGuid, @CustTypeGuid, @Contracted) 
			END 
			SET @New = 0 
	    END  
        ELSE  
	    BEGIN	 
		------------------------------------------------------------------------------------- 
		--------------------- NEW CUST  
			Declare @AccParentGuid		UNIQUEIDENTIFIER, 
					@AccFinalGuid		UNIQUEIDENTIFIER, 
					@AccGuid			UNIQUEIDENTIFIER, 
					@DistCustsAccGuid	UNIQUEIDENTIFIER, 
					@CiNumber			INT	 

			SELECT 
				@AccParentGuid = CustAccGuid, 
				@DistCustsAccGuid = CustomersAccGuid 
			FROM 
				Distributor000 
			WHERE 
				Guid = @DistGuid 

			IF ISNULL(@AccParentGuid, 0x00) = 0x00 
			BEGIN 
				SELECT 
					@AccParentGuid = ParentGuid, 
					@AccFinalGuid = FinalGuid 
				FROM 
					Ac000  
				WHERE 
					Guid = (SELECT TOP 1 AccountGuid FROM DistDistributionLines000 AS dl INNER JOIN cu000 AS cu ON cu.Guid = dl.CustGuid AND dl.DistGuid = @DistGuid) 
			END 
			ELSE 
			BEGIN 
				Select @AccFinalGuid = FinalGuid FROM ac000 WHERE Guid = @AccParentGuid 
			END 
			Set @AccGuid = newID() 
 
			-- Tarek -------------------------------------------------------------------------------------------
			EXEC GetNextMaximumCode 'ac000' ,'ParentGUID' , @AccParentGuid, @Code OUT
			
			EXEC [prcAccount_add] @Guid = @AccGuid, @Code = @Code, @Name = @Name, @Notes = 'New Account From PPC', @ParentGuid = @AccParentGuid, @FinalGuid = @AccFinalGuid 
			-- Tarek -------------------------------------------------------------------------------------------
			
			SELECT @CiNumber = MAX(Item) FROM ci000 WHERE ParentGuid = @DistCustsAccGuid 
			SET @ciNumber = ISNULL(@ciNumber, 0) + 1 
			INSERT INTO ci000 (Item, ParentGuid, SonGuid) VALUES (@ciNumber, @DistCustsAccGuid, @AccGuid) 

	        INSERT INTO [Cu000] ([Guid], [Number], [CustomerName], [BarCode], [Notes], [Phone1], [Mobile], 
								 [Head], [AccountGuid], [DefPrice], [CostGuid],[LatinName],[pager],[Phone2],[DefaultAddressGUID],[Security],[NSNotSendEmail],[NSNotSendSMS] )  
				SELECT 
				   @CustGuid, 
				   dbo.fnDistGetNewCuNum(),
				   @Name, 
				   @NewBarCode, 
				   @NewNotes, 
				   @Phone, 
				   @Mobile,
				   @PersonalName, 
				   @AccGuid, 
				   @NewCustomerDefaultPrice, 
				   @DistributorCostGuid,
				   @LatinName,
				   @pager, 
				   @Phone2,
				   @DefaultAddressGuid,
				   1,1,1

			IF EXISTS (SELECT Guid FROM DistCe000 WHERE CustomerGuid = @CustGuid) 
			BEGIN 
				UPDATE DistCe000 SET TradeChannelGuid = @TradeChannelGuid, CustomerTypeGuid = @CustTypeGuid, Contracted = @Contracted 
				WHERE CustomerGuid = @CustGuid 
			END 
			ELSE 
			BEGIN 
				INSERT INTO DistCe000( CustomerGuid, TradeChannelGuid, CustomerTypeGuid, Contracted) 
							VALUES	 ( @CustGuid, @TradeChannelGuid, @CustTypeGuid, @Contracted) 
			END 
			IF(@AutoNewCustToRoute = 1 AND @Rout1 > 0)
			begin
			    INSERT INTO DistDistributionLines000 VALUES(NEWID(), @DistGuid, @CustGuid, @Rout1, 0, 0, 0, '', '', '', '')
			END
			SET @New = 1 
	    END  
		 
		-- Add Cust Updates 
		INSERT INTO DistCustUpdates000(Guid, DistGuid, CustGuid, Barcode, Name, Area, Street, Phone, Mobile,
									   PersonalName, Notes, CustTypeGuid, TradeChannelGuid, Contracted, 
									   New, Date, GPSX, GPSY, Address, pager, Phone2, ZipCode)

		VALUES(newId(), @DistGuid, @CustGuid, @NewBarcode, @Name, @Area, @Street, @Phone, @Mobile, 
			   @PersonalName, @NewNotes, @CustTypeGuid, @TradeChannelGuid, @Contracted,
			   @New, getDate(), @GPSX, @GPSY , @Address , @pager , @Phone2 , @ZipCode) 
		------------------------------------------------------------------------------ 
	    Fetch 
		From @C 
		INTO 
			@CustGuid, 
			@NewBarcode, 
			@NewNotes, 
			@Name, 
			@Area, 
			@Street, 
			@Phone, 
			@Mobile, 
			@PersonalName,
			@CustTypeGuid, 
			@TradeChannelGuid, 
			@Contracted, 
			@GPSX, 
			@GPSY, 
			@LatinName, 
			@Address, 
			@pager, 
			@Phone2, 
			@ZipCode, 
			@Rout1,
			@DefaultAddressGuid
	END  
	CLOSE @C
	DEALLOCATE @C

	DELETE [DistDeviceNewCu000] WHERE [DistributorGuid] = @DistGuid 
END 
/*
Exec prcDist_UpdateCustsOFDistributor '06826D4F-E81B-4DF0-AC22-438A09F68C93'
*/
################################################################################
CREATE PROCEDURE prcDistPostCustomerAddresses
    @DistributorGUID UNIQUEIDENTIFIER 
AS      
	SET NOCOUNT ON      
	
	----------------------------------------------------------------
	--------------------- Insert New Countries ---------------------
	INSERT INTO AddressCountry000 ([Number], [GUID], [Code], [Name], [LatinName])
	SELECT
		ISNULL((SELECT MAX([Number]) FROM AddressCountry000), 0) + ROW_NUMBER() OVER( ORDER BY newc.Number),
		[newc].[GUID],
		[newc].[Code],
		[newc].[Name],
		[newc].[LatinName]
	FROM 
		DistDeviceAddressCountry000 newc 
	WHERE 
		[State] = 1
		AND GUID NOT IN (SELECT GUID FROM AddressCountry000)
	--------------------- Update Existing Countries ---------------------
	UPDATE c 
	SET
		[c].[GUID]			  = [newc].[GUID],
		[c].[Code]			  = [newc].[Code],
		[c].[Name]			  = [newc].[Name],
		[c].[LatinName]		  = [newc].[LatinName]
	FROM 
		DistDeviceAddressCountry000 newc
		INNER JOIN AddressCountry000 c ON [c].GUID = [newc].GUID
	WHERE 
		[newc].[State] = 1

	-------------------------------------------------------------
	--------------------- Insert New Cities ---------------------
	INSERT INTO AddressCity000 ([Number], [GUID], [Code], [Name], [LatinName], [ParentGUID])
	SELECT
		ISNULL((SELECT MAX([Number]) FROM AddressCity000), 0) + ROW_NUMBER() OVER( ORDER BY newc.Number),
		[newc].[GUID],
		[newc].[Code],
		[newc].[Name],
		[newc].[LatinName],
		[newc].[ParentGUID]
	FROM 
		DistDeviceAddressCity000 newc 
	WHERE 
		[State] = 1
		AND GUID NOT IN (SELECT GUID FROM AddressCity000)
	--------------------- Update Existing Cities ---------------------
	UPDATE c 
	SET
		[c].[GUID]			  = [newc].[GUID],
		[c].[Code]			  = [newc].[Code],
		[c].[Name]			  = [newc].[Name],
		[c].[LatinName]		  = [newc].[LatinName],
		[c].[ParentGUID]      = [newc].[ParentGUID]
	FROM 
		DistDeviceAddressCity000 newc
		INNER JOIN AddressCity000 c ON [c].GUID = [newc].GUID
	WHERE 
		[newc].[State] = 1
	------------------------------------------------------------
	--------------------- Insert New Areas ---------------------
	INSERT INTO AddressArea000 ([Number], [GUID], [Code], [Name], [LatinName], [ParentGUID])
	SELECT
		ISNULL((SELECT MAX([Number]) FROM AddressArea000), 0) + ROW_NUMBER() OVER( ORDER BY newa.Number),
		[newa].[GUID],
		[newa].[Code],
		[newa].[Name],
		[newa].[LatinName],
		[newa].[ParentGUID]
	FROM 
		DistDeviceAddressArea000 newa 
	WHERE 
		[State] = 1
		AND GUID NOT IN (SELECT GUID FROM AddressArea000)
	--------------------- Update Existing Areas ---------------------
	UPDATE a 
	SET
		[a].[GUID]			  = [newa].[GUID],
		[a].[Code]			  = [newa].[Code],
		[a].[Name]			  = [newa].[Name],
		[a].[LatinName]		  = [newa].[LatinName],
		[a].[ParentGUID]      = [newa].[ParentGUID]
	FROM 
		DistDeviceAddressArea000 newa
		INNER JOIN AddressArea000 a ON [a].GUID = [newa].GUID
	WHERE 
		[newa].[State] = 1
		----------------------------------------------------------------
		--------------------- Insert New Addresses ---------------------
	INSERT INTO CustAddress000 ([Number], [GUID], [Name], [LatinName], [CustomerGUID], [AreaGUID], [Street], [BulidingNumber], 
								[FloorNumber], [MoreDetails], [POBox], [ZipCode], [GPSX], [GPSY])
	SELECT
		ISNULL((SELECT MAX([Number]) FROM CustAddress000), 0) + ROW_NUMBER() OVER( ORDER BY newca.Number),
		[newca].[AddressGUID],
		[newca].[Name],
		[newca].[LatinName],
		[newca].[CustomerGUID],
		[newca].[AreaGUID],
		[newca].[Street],
		[newca].[BulidingNumber],
		[newca].[FloorNumber],
		[newca].[MoreDetails],
		[newca].[POBox],
		[newca].[ZipCode],
		[newca].[GPSX],
		[newca].[GPSY]
	FROM 
		distdeviceCustAddress000 newca 
	WHERE 
		[DistributorGUID] = @DistributorGUID
		AND [State] = 1
		AND [AddressGUID] NOT IN (SELECT GUID FROM CustAddress000)
	--------------------- Update Existing Addresses ---------------------
	UPDATE ca 
	SET
		[ca].[GUID]			  = [newca].[AddressGUID],
		[ca].[Name]			  = [newca].[Name],
		[ca].[LatinName]	  = [newca].[LatinName],
		[ca].[CustomerGUID]   = [newca].[CustomerGUID],
		[ca].[AreaGUID]		  = [newca].[AreaGUID],
		[ca].[Street]		  = [newca].[Street],
		[ca].[BulidingNumber] = [newca].[BulidingNumber],
		[ca].[FloorNumber]	  = [newca].[FloorNumber],
		[ca].[MoreDetails]	  = [newca].[MoreDetails],
		[ca].[POBox]		  = [newca].[POBox],
		[ca].[ZipCode]		  = [newca].[ZipCode],
		[ca].[GPSX]			  = [newca].[GPSX],
		[ca].[GPSY]			  = [newca].[GPSY]
	FROM 
	distdeviceCustAddress000 newca 
	INNER JOIN CustAddress000 ca ON [ca].GUID = [newca].[AddressGUID]
	WHERE 
		newca.DistributorGUID = @DistributorGUID
		AND newca.state = 1
	----------------------------------------------------------------------------
	--------------------- Insert New Addresses Working Days---------------------
	INSERT INTO CustAddressWorkingDays000 ([Number], [GUID], [AddressGUID], [WorkDays], [MorningStart], [MorningEnd], [NightStart], [NightEnd])
	SELECT
		ISNULL((SELECT MAX([Number]) FROM CustAddressWorkingDays000), 0) + ROW_NUMBER() OVER( ORDER BY newd.Number),
		[newd].[AmenWorkingAddressGUID],
		[newd].[AddressGUID],
		[newd].[WorkDays],
		[newd].[MorningStart],
		[newd].[MorningEnd],
		[newd].[NightStart],
		[newd].[NightEnd]
	FROM 
		DistDeviceCustAddressWorkingDays000 newd 
	WHERE 
		[State] = 1
		AND AmenWorkingAddressGUID NOT IN (SELECT GUID FROM CustAddressWorkingDays000)
	--------------------- Update Existing Addresses Working Days ---------------------
	UPDATE d
	SET
		[d].[GUID]			  = [newd].[AmenWorkingAddressGUID],
		[d].[AddressGUID]	  = [newd].[AddressGUID],
		[d].[WorkDays]		  = [newd].[WorkDays],
		[d].[MorningStart]	  = [newd].[MorningStart],
		[d].[MorningEnd]      = [newd].[MorningEnd],
		[d].[NightStart]	  = [newd].[NightStart],
		[d].[NightEnd]        = [newd].[NightEnd]
	FROM 
		DistDeviceCustAddressWorkingDays000 newd
		INNER JOIN CustAddressWorkingDays000 d ON [d].GUID = [newd].[AmenWorkingAddressGUID]
	WHERE 
		[newd].[State] = 1
			---------------------Delete ----------------
	DELETE d
	FROM 
		DistDeviceCustAddressWorkingDays000 newd
		INNER JOIN CustAddressWorkingDays000 d ON [d].GUID = [newd].[AmenWorkingAddressGUID]
	WHERE 
		[newd].[State] = 3
################################################################################
#END
