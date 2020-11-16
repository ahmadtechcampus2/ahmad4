###############################################################################
CREATE FUNCTION  fnGetDocumentDefaultNameNextSerialNumber
(@sourceDocumentTypeID		UNIQUEIDENTIFIER)

	RETURNS NVARCHAR(50)
AS
BEGIN
	DECLARE @NextSerialNumber NVARCHAR(100) = ''
	DECLARE @NumberPart NVARCHAR (100) = ''
	DECLARE @TextPart NVARCHAR (100) = ''
	DECLARE @ReadingNumPart BIT = 1
	DECLARE @LastSerialNumber NVARCHAR(100)
	DECLARE @StartNumber NVARCHAR(100)

	SELECT @LastSerialNumber = LastSerialNumber, @StartNumber = StartNumber FROM ArchivingAutoNamingSettings WHERE SourceID = @sourceDocumentTypeID
	DECLARE @DigitsCnt INT = (SELECT DigitsCnt FROM ArchivingAutoNamingSettings WHERE SourceID = @sourceDocumentTypeID);
	
	IF (@LastSerialNumber IS NULL OR (@LastSerialNumber = ''))
		RETURN @StartNumber;
	
	SET @DigitsCnt = (LEN(@LastSerialNumber))

	DECLARE @Cnt INT = 0
	WHILE (@Cnt <=  @DigitsCnt AND @ReadingNumPart = 1)
	BEGIN
		DECLARE @char NCHAR =  SUBSTRING(@LastSerialNumber,(@DigitsCnt - @Cnt),1)
		IF(@char LIKE '[0-9]')
		BEGIN
			SET @NumberPart = @char + @NumberPart
		END
		ELSE
		BEGIN
			SET @TextPart = SUBSTRING(@LastSerialNumber, 1 ,(@DigitsCnt - @Cnt))
			SET @ReadingNumPart = 0
		END
	   SET @Cnt = @Cnt + 1;
	END;
	
	
	DECLARE @CurrentNumber NVARCHAR(100) = CONVERT(NVARCHAR(100), (@NumberPart + 1))
	DECLARE @CurrentNumberLen INT = LEN(@CurrentNumber)
	WHILE (@CurrentNumberLen < (SELECT LEN(@NumberPart)))
	BEGIN
		SET @CurrentNumber = '0' + @CurrentNumber
		SET @CurrentNumberLen  = @CurrentNumberLen + 1
	END;
	
	SET @NextSerialNumber = @TextPart + @CurrentNumber
	RETURN @NextSerialNumber

END
###########################################################################
CREATE FUNCTION  fnGetDateAsFormat
(@date DATE, @format NVARCHAR(250))

	RETURNS NVARCHAR(50)
AS
BEGIN
	DECLARE @FormatedDate NVARCHAR(250) = ''

	IF(@format = 'YYYY-MMM-DD')
	BEGIN 
		DECLARE @d VARCHAR(11)
		SELECT @d = CONVERT(VARCHAR(11), @date, 109)
		SELECT @FormatedDate = RIGHT(@d,4) + '-' + LEFT(@d,3) + '-' + right('00'+LTRIM(SUBSTRING(@d,5,2)),2)
	END

	ELSE IF(@format = 'YYYY-MM-DD')
	BEGIN 
		SELECT @FormatedDate = CONVERT(char(10), @date, 126)
	END

	ELSE IF(@format = 'YY-MM-DD')
	BEGIN 
		DECLARE @dd VARCHAR(10)
		SELECT @d = CONVERT(VARCHAR(10), @date, 126)
		SELECT @FormatedDate = RIGHT(@d,8) 
	END

	ELSE IF(@format = 'DD')
	BEGIN 
		SELECT @FormatedDate = FORMAT(@date, 'dd')

	END

	ELSE IF(@format = 'DDD')
	BEGIN 
		SELECT @FormatedDate = FORMAT(@date, 'ddd')
	END

	ELSE IF(@format = 'MM')
	BEGIN 
		SELECT @FormatedDate = FORMAT(@date, 'MM')
	END

	ELSE IF(@format = 'MMM')
	BEGIN 
		SELECT @FormatedDate = FORMAT(@date, 'MMM')
	END
	
	ELSE IF(@format = 'YY')
	BEGIN 
		SELECT @FormatedDate = FORMAT(@date, 'yy')
	END
	
	ELSE IF(@format = 'YYYY')
	BEGIN 
		SELECT @FormatedDate = FORMAT(@date, 'yyyy')
	END
	RETURN @FormatedDate	
END
###########################################################################
CREATE PROCEDURE prcArchivingGetDocumentDefaultName
	@sourceDocumentTypeID		UNIQUEIDENTIFIER ,
	@sourceDocumentID			UNIQUEIDENTIFIER ,
	@sourceAmnType				INT ,
	@defaultName				NVARCHAR(MAX) OUTPUT

AS
	SET NOCOUNT ON
	DECLARE @Name NVARCHAR(MAX) = ''
	DECLARE @documentTypeID UNIQUEIDENTIFIER = (
										SELECT TOP 1  DocumentTypeID 
										FROM DMSTblRelatedType RT
										LEFT JOIN DMSTblDocumentType DT ON RT.DocumentTypeID = DT.ID
										WHERE TypeID = @sourceDocumentTypeID
										ORDER BY DT.Number
										)
	DECLARE @SettingID UNIQUEIDENTIFIER
	DECLARE @Separator NVARCHAR(10)
	DECLARE @DigitsCnt INT
	DECLARE @StartNum NVARCHAR(10)
	DECLARE @ISActive INT 

	SELECT 
		@SettingID = ID
		,@Separator = Separator
		,@DigitsCnt = DigitsCnt
		,@StartNum = StartNumber
		,@ISActive= IsActive 
	FROM 
		ArchivingAutoNamingSettings 
	WHERE 
		SourceID = @sourceDocumentTypeID

	IF (@ISActive = 0)
	BEGIN
		SET @defaultName = ''
		RETURN
	END

	DECLARE @FldID INT
	DECLARE @FldOrder INT 
	DECLARE @CustomValue NVARCHAR(MAX)
	DECLARE @fldValue NVARCHAR(MAX)

	DECLARE settingCursor CURSOR
	    FOR SELECT FldID, FldOrder, CustomValue FROM ArchivingAutoNamingSettingsItem WHERE ParentID = @SettingID ORDER BY FldOrder
	OPEN settingCursor
	FETCH NEXT FROM settingCursor
	INTO  @FldID ,@FldOrder ,@CustomValue ;
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @fldValue  = (SELECT CASE 
								WHEN @FldID = 1 THEN (SELECT dbo.fnGetCurrentUserName()) --USERNAME
								WHEN @FldID = 2 THEN CAST((SELECT HOST_NAME())AS NVARCHAR(250)) --COMPUTERNAME
						
								WHEN @FldID = 3 THEN (SELECT DB_NAME())--DATABASENAME
								WHEN @FldID = 4 THEN (SELECT dbo.fnGetDocumentDefaultNameNextSerialNumber(@sourceDocumentTypeID)) --SERIALNUMBER
								WHEN @FldID = 5 THEN (@CustomValue) --TEXTFLD
										
								WHEN @FldID = 6 THEN  CONVERT(NVARCHAR(250), --SOURCEDOCUMENTNUMBER
									(CASE WHEN (@sourceAmnType = 1 OR  @sourceAmnType = 4) THEN (SELECT [Number] FROM bu000 WHERE [GUID] = @sourceDocumentID) --BillType, OrderType 
										WHEN @sourceAmnType = 2 THEN (SELECT [Number] FROM py000 WHERE [GUID] = @sourceDocumentID) --EntryType 
										WHEN @sourceAmnType = 3 THEN (SELECT [Number] FROM ch000 WHERE [GUID] = @sourceDocumentID) --CheckType 
										WHEN @sourceAmnType = 7 THEN (SELECT [Number] FROM cu000 WHERE [GUID] = @sourceDocumentID) --CustomerCard 
										WHEN @sourceAmnType = 8 THEN (SELECT [Number] FROM mt000 WHERE [GUID] = @sourceDocumentID) --MaterialCard 
										WHEN @sourceAmnType = 9 THEN (SELECT [Number] FROM ac000 WHERE [GUID] = @sourceDocumentID) --AccountCard 
										WHEN @sourceAmnType = 10 THEN (SELECT [Number] FROM co000 WHERE [GUID] = @sourceDocumentID)	--CostCard 									
										WHEN @sourceAmnType = 11 THEN (SELECT [Number] FROM FM000 WHERE [GUID] = @sourceDocumentID) --FormCard 
										WHEN @sourceAmnType = 12 THEN (SELECT [Number] FROM MN000 WHERE [GUID] = @sourceDocumentID) --ManufacturingProcessCard 
										WHEN @sourceAmnType = 13 THEN (SELECT [Number] FROM MNPS000 WHERE [GUID] = @sourceDocumentID) --ProductionPlanCard 
										WHEN @sourceAmnType = 14 THEN (SELECT [Number] FROM SpecialOffer000 WHERE [GUID] = @sourceDocumentID) --SpecialOfferCard 
										WHEN @sourceAmnType = 15 THEN (SELECT '') --AccountCheckDateCard 
										WHEN (@sourceAmnType = 16 OR @sourceAmnType = 17 OR @sourceAmnType = 18 OR @sourceAmnType = 19) --ShipmentToProfitCenter, ShipmentFromProfitCenter, ShipmentToWithPurchasing, ShipmentFromWithReturnPurchasing
															 THEN (SELECT [Number] FROM PFCShipmentBill000 WHERE [GUID] = @sourceDocumentID)

										ELSE '' END
									))
								
								WHEN @FldID = 7 THEN  CONVERT(NVARCHAR(250), --SOURCEDOCUMENTNAME
									(CASE WHEN (@sourceAmnType = 1 OR  @sourceAmnType = 4) THEN (SELECT [Name] FROM bt000 WHERE [GUID] = @sourceDocumentTypeID)
										WHEN @sourceAmnType = 2 THEN (SELECT [Name] FROM et000 WHERE [GUID] = @sourceDocumentTypeID) 
										WHEN @sourceAmnType = 3 THEN (SELECT [Name] FROM nt000 WHERE [GUID] = @sourceDocumentTypeID) 
										WHEN @sourceAmnType = 7 THEN (SELECT [CustomerName] FROM cu000 WHERE [GUID] = @sourceDocumentID) --CustomerCard 
										WHEN @sourceAmnType = 8 THEN (SELECT [Name] FROM mt000 WHERE [GUID] = @sourceDocumentID) --MaterialCard 
										WHEN @sourceAmnType = 9 THEN (SELECT [Name] FROM ac000 WHERE [GUID] = @sourceDocumentID) --AccountCard 
										WHEN @sourceAmnType = 10 THEN (SELECT [Name] FROM co000 WHERE [GUID] = @sourceDocumentID)	--CostCard 									
										WHEN @sourceAmnType = 11 THEN (SELECT [Name] FROM FM000 WHERE [GUID] = @sourceDocumentID) --FormCard 
										WHEN @sourceAmnType = 12 THEN (SELECT dbo.fnStrings_get('MN\MANUFACTURE', DEFAULT)) --ManufacturingProcessCard 
										WHEN @sourceAmnType = 13 THEN (SELECT dbo.fnStrings_get('MN\PRODUCTIONPLANCARD', DEFAULT)) --ProductionPlanCard 
										WHEN @sourceAmnType = 14 THEN (SELECT [Name] FROM SpecialOffer000 WHERE [GUID] = @sourceDocumentID) --SpecialOfferCard 
										WHEN @sourceAmnType = 15 THEN (SELECT dbo.fnStrings_get('ACC\ACCCHECKDATE', DEFAULT)) --AccountCheckDateCard 
										WHEN @sourceAmnType = 16 THEN (SELECT dbo.fnStrings_get('PFC\SHIPEMENT_TO_PROFIT_CENTER', DEFAULT)) --ShipmentToProfitCenter
										WHEN @sourceAmnType = 17 THEN (SELECT dbo.fnStrings_get('PFC\SHIPEMENT_RETURN_FROM_PROFIT_CENTER', DEFAULT)) --ShipmentFromProfitCenter
										WHEN @sourceAmnType = 18 THEN (SELECT dbo.fnStrings_get('PFC\SHIPEMENT_PURCHASE_TO_PROFIT_CENTER', DEFAULT)) --ShipmentToWithPurchasing
										WHEN @sourceAmnType = 19 THEN (SELECT dbo.fnStrings_get('PFC\SHIPEMENT__PURCHASE_FROM_PROFIT_CENTER_WITH_RETURN', DEFAULT)) -- ShipmentFromWithReturnPurchasing
															 
										ELSE '' END
									))
								
								WHEN @FldID = 8 THEN --SOURCEDOCUMENTDATE
									(CASE WHEN (@sourceAmnType = 1 OR  @sourceAmnType = 4) THEN (SELECT dbo.fnGetDateAsFormat([Date],@CustomValue) FROM bu000 WHERE [GUID] = @sourceDocumentID)
										WHEN @sourceAmnType = 2 THEN (SELECT dbo.fnGetDateAsFormat([Date],@CustomValue) FROM py000 WHERE [GUID] = @sourceDocumentID) 
										WHEN @sourceAmnType = 3 THEN (SELECT dbo.fnGetDateAsFormat([Date],@CustomValue) FROM ch000 WHERE [GUID] = @sourceDocumentID) 
										WHEN @sourceAmnType = 11 THEN (SELECT dbo.fnGetDateAsFormat([fmDate],@CustomValue) FROM vwfm WHERE [fmGUID] = @sourceDocumentID) --FormCard 
										WHEN @sourceAmnType = 12 THEN (SELECT dbo.fnGetDateAsFormat([Date],@CustomValue) FROM MN000 WHERE [GUID] = @sourceDocumentID) --ManufacturingProcessCard 
										WHEN @sourceAmnType = 15 THEN (SELECT dbo.fnGetDateAsFormat([CheckedToDate],@CustomValue) FROM CheckAcc000  WHERE [GUID] = @sourceDocumentID) --AccountCheckDateCard
										WHEN (@sourceAmnType = 16 OR @sourceAmnType = 17 OR @sourceAmnType = 18 OR @sourceAmnType = 19) --ShipmentToProfitCenter, ShipmentFromProfitCenter, ShipmentToWithPurchasing, ShipmentFromWithReturnPurchasing
															THEN (SELECT dbo.fnGetDateAsFormat([Date],@CustomValue) FROM PFCShipmentBill000 WHERE [GUID] = @sourceDocumentID)

										
										ELSE '' END


									)
								WHEN @FldID = 9 THEN --BRANCHNAME
									(CASE WHEN (@sourceAmnType = 1 OR  @sourceAmnType = 4) THEN (SELECT BR.Name FROM bu000 BU LEFT JOIN br000 BR ON BU.Branch = BR.GUID WHERE BU.[GUID] = @sourceDocumentID)
										WHEN @sourceAmnType = 2 THEN (SELECT BR.Name FROM py000 PY LEFT JOIN br000 BR ON PY.BranchGUID = BR.GUID WHERE PY.[GUID] = @sourceDocumentID) 
										WHEN @sourceAmnType = 3 THEN (SELECT BR.Name FROM ch000 CH LEFT JOIN br000 BR ON CH.BranchGUID = BR.GUID WHERE CH.[GUID] = @sourceDocumentID) 
										ELSE '' END
									)		
								ELSE '' END)

			SET @Name = @Name + CASE WHEN @FldOrder = 0 THEN CAST(@fldValue AS NVARCHAR(250)) ELSE (@Separator + CAST(@fldValue AS NVARCHAR(250))) END

		FETCH NEXT FROM settingCursor INTO  @FldID ,@FldOrder ,@CustomValue ;
	END 
	CLOSE settingCursor;
	DEALLOCATE settingCursor;
	SET @defaultName = @Name
###########################################################################
CREATE FUNCTION fnHasAutoArchiveSerialName(@sourceType UNIQUEIDENTIFIER)
RETURNS BIT
AS
BEGIN

	IF EXISTS(
		SELECT * FROM 
			ArchivingAutoNamingSettings S 
			INNER JOIN dbo.ArchivingAutoNamingSettingsItem SISerial ON S.ID = SISerial.ParentID
			INNER JOIN dbo.ArchivingAutoNamingSettingsItem SIType ON S.ID = SIType.ParentID
		WHERE 
			S.SourceID = @sourceType AND S.IsActive = 1 
			AND SISerial.FldID = 4 AND SIType.FldID = 7)
	BEGIN
		RETURN 1
	END

	RETURN 0
END
###########################################################################
#END
