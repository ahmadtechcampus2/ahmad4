################################################################################
CREATE PROCEDURE prcGCC_TaxDuration_VerifyBillsNumbersByBranch
	@TaxDurationGUID UNIQUEIDENTIFIER,
	@BranchGUID UNIQUEIDENTIFIER = 0x0
AS
	SET NOCOUNT ON

	DECLARE @Lang INT = (SELECT [dbo].[fnConnections_GetLanguage]())
	DECLARE @TaxDurationStartDate DATE
	DECLARE @TaxDurationEndDate   DATE	
	SELECT 
		@TaxDurationStartDate = [StartDate],
		@TaxDurationEndDate = [EndDate]		
	FROM GCCTaxDurations000 WHERE [GUID] = @TaxDurationGUID

	DECLARE @AllBillTypes CURSOR 
	DECLARE @BillTypeGUID  UNIQUEIDENTIFIER
	DECLARE @BillTypeName NVARCHAR(250)
	DECLARE @BillType INT;
	DECLARE @count INT = 1;
	DECLARE @ForceNumbering BIT = ISNULL((SELECT TOP 1 ForceNumberingByBillType FROM GCCTaxSettings000), 0);

	SET @AllBillTypes = CURSOR FAST_FORWARD FOR
	SELECT 
		CASE @ForceNumbering
			WHEN 1 THEN 0x0
			ELSE [GUID]
		END,
		CASE @ForceNumbering
			WHEN 1 THEN ''
			ELSE Name
		END,
		BillType
	FROM   
		bt000
	WHERE
		bNoEntry = 0
		AND BillType IN (0, 1, 2, 3) 
		AND [Type] = 1
	GROUP BY 
		CASE @ForceNumbering
			WHEN 1 THEN 0x0
			ELSE [GUID]
		END,
		CASE @ForceNumbering
			WHEN 1 THEN ''
			ELSE Name
		END,
		BillType

	OPEN @AllBillTypes;	
	FETCH NEXT FROM @AllBillTypes INTO @BillTypeGUID, @BillTypeName, @BillType; ---------- BILL TYPES
	WHILE (@@FETCH_STATUS = 0)
	BEGIN 
		DECLARE 
			@MinNumber INT,
			@MaxNumber INT

		SELECT 
			@MinNumber = ISNULL(MIN(Number), 0),
			@MaxNumber = ISNULL(MAX(Number), 0)
		FROM 
			bu000 AS BU
			INNER JOIN bt000 AS BT ON bu.TypeGUID = bt.GUID
		WHERE 
			Branch = @BranchGUID
			AND
			((@ForceNumbering = 1 AND BT.BillType = @BillType)  OR (@ForceNumbering <> 1 AND TypeGUID = @BillTypeGUID))
			AND 
			CAST([Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate

		IF EXISTS(SELECT * FROM GCCTaxDurations000 WHERE IsTransfered = 0 AND EndDate < @TaxDurationStartDate)
		BEGIN 
			SELECT 
				@MinNumber = ISNULL(MAX(Number), @MinNumber) + 1
			FROM 
				bu000 AS BU
				INNER JOIN bt000 AS BT ON bu.TypeGUID = bt.GUID
			WHERE 
				Branch = @BranchGUID
				AND
				((@ForceNumbering = 1 AND BT.BillType = @BillType)  OR (@ForceNumbering <> 1 AND TypeGUID = @BillTypeGUID))
				AND 
				CAST([Date] AS DATE) < @TaxDurationStartDate
		END 
				
		SET @count = @MinNumber;
		WHILE (@count < @MaxNumber)
		BEGIN 
			IF NOT EXISTS (
				SELECT *
				FROM 
					bu000 BU 
					INNER JOIN bt000 BT ON BU.TypeGUID = BT.[GUID]
				WHERE 
					BU.Number = @count
					AND
					BU.Branch = @BranchGUID
					AND
					((@ForceNumbering = 1 AND BT.BillType = @BillType)  OR (@ForceNumbering <> 1 AND TypeGUID = @BillTypeGUID))
					AND 
					CAST(BU.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate)
			BEGIN 
				INSERT INTO #Result VALUES(-1, @count, @BillTypeName + ': ' + CAST(@count AS NVARCHAR(250)), 0x0, @BillType)
			END

			SET @count = @count + 1
		END
		FETCH NEXT FROM @AllBillTypes INTO @BillTypeGUID, @BillTypeName, @BillType;
	END CLOSE @AllBillTypes	DEALLOCATE @AllBillTypes;
################################################################################
CREATE PROCEDURE prcGCC_TaxDuration_VerifyBillsNumbers
	@TaxDurationGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	CREATE TABLE #Result (BillNumber INT, VerifyNumber INT, BillTypeName NVARCHAR(250), BillGUID UNIQUEIDENTIFIER, BillType INT)
	IF EXISTS(SELECT * FROM br000)
	BEGIN 
		DECLARE @Branches CURSOR 
		DECLARE @BrGUID UNIQUEIDENTIFIER
		DECLARE @BrNumber BIGINT
		SET @Branches = CURSOR FAST_FORWARD FOR 
				SELECT 0 AS Number, 0x0 AS GUID UNION ALL SELECT Number, GUID FROM br000 ORDER BY Number 

		OPEN @Branches FETCH NEXT FROM @Branches INTO @BrNumber, @BrGUID
		WHILE @@FETCH_STATUS = 0
		BEGIN 
			EXEC prcGCC_TaxDuration_VerifyBillsNumbersByBranch @TaxDurationGUID, @BrGUID
			FETCH NEXT FROM @Branches INTO @BrNumber, @BrGUID
		END CLOSE @Branches DEALLOCATE @Branches
	END ELSE BEGIN 
		EXEC prcGCC_TaxDuration_VerifyBillsNumbersByBranch @TaxDurationGUID, 0x0
	END 

	SELECT DISTINCT * FROM #Result
##################################################################################
#END
