########################################
CREATE PROCEDURE prcDistSaveDistributionLines
	@DistributorCode NVARCHAR(250), -- The distributor code.
	@DistributorName NVARCHAR(250), -- The distributor name.
	@AccountCode NVARCHAR(250), -- The account code.
	@CustomerName NVARCHAR(250), -- The customer name.
	@Rout1 INT, -- Route 1, the allowed value is from 0 to the day's count of the coverage, if else then 0.
	@Rout1Time DATETIME, -- Route 1 time
	@Rout2 INT, -- Route 2, the allowed value is from 0 to the day's count of the coverage, if else then 0.
	@Rout2Time DATETIME, -- Route 2 time.
	@Rout3 INT, -- Route 3, the allowed value is from 0 to the day's count of the coverage, if else then 0.
	@Rout3Time DATETIME, -- Route 3 time.
	@Rout4 INT, -- Route 4, the allowed value is from 0 to the day's count of the coverage, if else then 0.
	@Rout4Time DATETIME, -- Route 4 time.
	@UpdateData BIT -- If update data if it exists or no.
AS
	SET NOCOUNT ON

	IF @CustomerName = '' AND @AccountCode = ''
	BEGIN
		SELECT 0 AS ImportResult
		RETURN 
	END
	
	IF @DistributorCode = '' AND @DistributorName = ''
	BEGIN
		SELECT 0 AS ImportResult
		RETURN
	END
	
	DECLARE 
		@CustomerGUID UNIQUEIDENTIFIER,
		@DistributorGUID UNIQUEIDENTIFIER,
		@CoverageCount INT
		
	SELECT @CustomerGUID = [GUID] FROM cu000 WHERE CustomerName = @CustomerName OR AccountGUID = (SELECT [GUID] FROM ac000 WHERE Code = @AccountCode)
	
	IF ISNULL(@CustomerGUID, 0x0) = 0x0
	BEGIN
		SELECT 0 AS ImportResult
		RETURN
	END
	
	SELECT @DistributorGUID = [GUID] FROM Distributor000 WHERE Code = @DistributorCode OR Name = @DistributorName
	
	IF ISNULL(@DistributorGUID, 0x0) = 0x0
	BEGIN
		SELECT 0 AS ImportResult
		RETURN
	END
	
	
	IF @UpdateData = 0 AND EXISTS(SELECT * FROM DistDistributionLines000 WHERE DistGUID = @DistributorGUID AND CustGUID = @CustomerGUID)
	BEGIN
		SELECT 0 AS ImportResult
		RETURN
	END
	
	SELECT @CoverageCount = dbo.fnOption_GetInt('DistCfg_Coverage_RouteCount', '0')

	IF @Rout1 > @CoverageCount OR @Rout1 < 1
	BEGIN
		SET @Rout1 = 0
	END
	IF @Rout2 > @CoverageCount OR @Rout2 < 1
	BEGIN
		SET @Rout2 = 0
	END
	IF @Rout3 > @CoverageCount OR @Rout3 < 1
	BEGIN
		SET @Rout3 = 0
	END
	IF @Rout4 > @CoverageCount OR @Rout4 < 1
	BEGIN
		SET @Rout4 = 0
	END

	IF @UpdateData = 1 AND EXISTS(SELECT * FROM DistDistributionLines000 WHERE DistGUID = @DistributorGUID AND CustGUID = @CustomerGUID)
	BEGIN
		UPDATE DistDistributionLines000 
		SET
			Route1 = @Rout1,
			Route1Time = @Rout1Time,
			Route2 = @Rout2,
			Route2Time = @Rout2Time,
			Route3 = @Rout3,
			Route3Time = @Rout3Time,
			Route4 = @Rout4,
			Route4Time = @Rout4Time
		WHERE
			DistGUID = @DistributorGUID AND CustGUID = @CustomerGUID
		
		SELECT 1 AS ImportResult
		RETURN
	END

	IF NOT EXISTS(SELECT * FROM DistDistributionLines000 WHERE DistGUID = @DistributorGUID AND CustGUID = @CustomerGUID)
	BEGIN
		INSERT INTO DistDistributionLines000 VALUES(NEWID(), @DistributorGUID, @CustomerGUID, @Rout1, @Rout2, @Rout3, @Rout4, @Rout1Time, @Rout2Time, @Rout3Time, @Rout4Time)
		DECLARE
			@custAccGUID UNIQUEIDENTIFIER,
			@distCustsAccGUID UNIQUEIDENTIFIER

		SET @custAccGUID = ISNULL((SELECT AccountGUID FROM cu000 WHERE [GUID] = @CustomerGUID), 0x0)
		SET @distCustsAccGUID = ISNULL((SELECT CustomersAccGUID FROM Distributor000 WHERE [GUID] = @DistributorGUID), 0x0)

		IF NOT EXISTS(SELECT * FROM ci000 WHERE SonGUID = @custAccGUID AND ParentGUID = @distCustsAccGUID)
		BEGIN
			DECLARE @item INT

			SET @item = (SELECT ISNULL(MAX(Item), 0) + 1 FROM ci000 WHERE ParentGUID = @distCustsAccGUID)
			INSERT INTO ci000(Item, Num1, Num2, GUID, ParentGUID, SonGUID, CustomerGUID) 
			VALUES(@item, 0, 0, NEWID(), @distCustsAccGUID, @custAccGUID, @CustomerGUID)
		END
		SELECT 1 AS ImportResult
		RETURN
	END
#############################
#END
