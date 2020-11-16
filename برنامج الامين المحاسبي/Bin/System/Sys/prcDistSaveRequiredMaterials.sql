########################################
CREATE PROCEDURE prcDistSaveRequiredMaterials
	@CustomerClass NVARCHAR(250), -- The customer state name.
	@FromDate DATETIME, -- From date.
	@ToDate DATETIME, -- To date.
	@MaterialCode NVARCHAR(250), -- The material code.
	@MaterialName NVARCHAR(250), -- The material name.
	@Quantity FLOAT, -- The quantity of the material.
	@Unit NVARCHAR(250), -- The material's unit, may the name of the unit or the number of the unit which is: 0 or 1: unit 1, 2: unit 2, 3: unit 3.
	@IsOptional BIT, -- If the material obligatory or optional, 0: Obligatory, 1: Optional.
	@MaterialTemplate NVARCHAR(250), -- Material template code or name.
	@TradeChannel NVARCHAR(250), -- Trade channel code or name.
	@CustomerType NVARCHAR(250), -- Customer type code or name.
	@UpdateData BIT -- If update data if it exists or no.
AS
	SET NOCOUNT ON

	IF @CustomerClass = '' AND @MaterialTemplate = '' AND @TradeChannel = '' AND @CustomerType = '' 
	BEGIN
		SELECT 0 AS ImportResult
		RETURN
	END
	
	IF @MaterialCode = '' AND @MaterialName = ''
	BEGIN
		SELECT 0 AS ImportResult
		RETURN
	END
	
	IF @Quantity = 0
	BEGIN
		SELECT 0 AS ImportResult
		RETURN
	END
	
	DECLARE
		@CustomerClassGuid UNIQUEIDENTIFIER,
		@MaterialTemplateGuid UNIQUEIDENTIFIER,
		@TradeChannelGuid UNIQUEIDENTIFIER,
		@CustomerTypeGuid UNIQUEIDENTIFIER,
		@MaterialGuid UNIQUEIDENTIFIER,
		@mtFact INT,
		@Num INT
		
	SELECT @CustomerClassGuid = [GUID] FROM DistCustClasses000 WHERE Name = @CustomerClass
	SELECT @MaterialTemplateGuid = [GUID] FROM DistMatTemplates000 WHERE Name = @MaterialTemplate
	SELECT @TradeChannelGuid = [GUID] FROM DistTCh000 WHERE Code = @TradeChannel OR Name = @TradeChannel
	SELECT @CustomerTypeGuid = [GUID] FROM DistCT000 WHERE Code = @CustomerType OR Name = @CustomerType
	
	IF ISNULL(@CustomerClassGuid, 0x0) = 0x0 AND ISNULL(@MaterialTemplateGuid, 0x0) = 0x0 AND ISNULL(@TradeChannelGuid, 0x0) = 0x0 AND ISNULL(@CustomerTypeGuid, 0x0) = 0x0
	BEGIN
		SELECT 0 AS ImportResult
		RETURN
	END
	
	SELECT @MaterialGuid = [GUID] FROM mt000 WHERE @MaterialCode = Code OR @MaterialName = Name
	
	IF @Unit <> '0' OR @Unit <> '1' OR @Unit <> '2' OR @Unit <> '3'
	BEGIN
		SELECT 
			@Unit = CASE 
						WHEN @Unit = Unity THEN 1
						WHEN @Unit = Unit2 THEN 2
						WHEN @Unit = Unit3 THEN 3
						ELSE 1
					END
		FROM
			mt000 
		WHERE 
			[GUID] = @MaterialGuid
	END

	SELECT @mtFact = CASE @Unit WHEN 2 THEN Unit2Fact When 3 THEN Unit3Fact Else 1 END from mt000 where Guid = @MaterialGuid

	IF ISNULL(@MaterialGuid, 0x0) = 0x0
	BEGIN
		SELECT 0 AS ImportResult
		RETURN
	END
	
	Declare @parentGuid UNIQUEIDENTIFIER 
	SELECT @parentGuid = Guid FROM DistRequiredMaterials000 
						 WHERE 
							CustClassGuid = ISNULL(@CustomerClassGuid, 0x0)
							AND CustomerTypeGuid = ISNULL(@CustomerTypeGuid, 0x0)
							AND MaterialTemplateGuid = ISNULL(@MaterialTemplateGuid, 0x0)
							AND TradeChannelGuid = ISNULL(@TradeChannelGuid, 0x0)
							AND StartDate = @FromDate
							AND EndDate = @ToDate

	IF @UpdateData = 0 
		AND 
		ISNULL(@parentGuid, 0x0) <> 0x0
		AND
		EXISTS(SELECT * FROM DistReqMatsDetails000 WHERE MaterialGuid = @MaterialGuid AND ParentGuid = @parentGuid)
	BEGIN
		SELECT 0 AS ImportResult
		RETURN
	END
	
	IF @UpdateData = 1
		AND 
		ISNULL(@parentGuid, 0x0) <> 0x0
		AND
		EXISTS(SELECT * FROM DistReqMatsDetails000 WHERE MaterialGuid = @MaterialGuid AND ParentGuid = @parentGuid)
	BEGIN
		UPDATE DistReqMatsDetails000 
		SET
			Quantity = @Quantity * @mtFact,
			Unity = CAST(@Unit AS INT),
			[Type] = @IsOptional
		WHERE 
			ParentGuid = @parentGuid 
			AND 
			MaterialGuid = @MaterialGuid 

		SELECT 1 AS ImportResult
		RETURN
	END
	
	IF ISNULL(@parentGuid, 0x0) <> 0x0
		AND
		NOT EXISTS(SELECT * FROM DistReqMatsDetails000 WHERE MaterialGuid = @MaterialGuid And unity = @Unit AND ParentGuid = @parentGuid)
	BEGIN
		SELECT @Num = (ISNULL(MAX(Number), 0) + 1) FROM DistReqMatsDetails000 WHERE ParentGuid = @ParentGuid
		
		INSERT INTO DistReqMatsDetails000 VALUES(@Num, NEWID(), @parentGuid, ISNULL(@MaterialGuid, 0x0), @Quantity * @mtFact, @Unit, @IsOptional)
		SELECT 1 AS ImportResult
		RETURN
	END
	
	IF ISNULL(@parentGuid, 0x0) = 0x0
	BEGIN
		SET @parentGuid = NEWID()
		SELECT @Num = (ISNULL(MAX(Number), 0) + 1) FROM DistRequiredMaterials000
		INSERT INTO DistRequiredMaterials000 VALUES(@Num, @parentGuid, ISNULL(@CustomerClassGuid, 0x0), @FromDate, @ToDate, ISNULL(@CustomerTypeGuid, 0x0), ISNULL(@MaterialTemplateGuid, 0x0), ISNULL(@TradeChannelGuid, 0x0))
		
		SELECT @Num = (ISNULL(MAX(Number), 0) + 1) FROM DistReqMatsDetails000
		INSERT INTO DistReqMatsDetails000 VALUES(@Num, NEWID(), @parentGuid, ISNULL(@MaterialGuid, 0x0), @Quantity * @mtFact, @Unit, @IsOptional)
		
		SELECT 1 AS ImportResult
		RETURN
	END
#############################
#END
