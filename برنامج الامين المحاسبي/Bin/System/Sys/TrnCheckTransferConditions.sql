################################################################################
CREATE TRIGGER trgTrnTransferVoucher_CheckConditions
	ON TrnTransferVoucher000 FOR INSERT, UPDATE
	NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN 
	
IF NOT EXISTS(SELECT * FROM deleted) OR (EXISTS(SELECT * FROM deleted) AND(UPDATE(State) OR UPDATE(Amount)))
BEGIN

	DECLARE
		@CurrentCenter UNIQUEIDENTIFIER, 
		@CurrentCurancy UNIQUEIDENTIFIER,
		@Amount FLOAT,
		@Cnt INT,
		@SumAmount FLOAT,
		@TransferTypes INT,
		@PaidSum FLOAT,
		@NewSum FLOAT,
		@PaidCount INT,
		@NewCount INT,
		@NoDate DATETIME;

	SET @CurrentCenter = CAST(dbo.fnOption_GetValue('TrnCfg_CurrentCenter', 2)  AS UNIQUEIDENTIFIER)
	SET @CurrentCurancy = (SELECT GUID FROM my000 WHERE Number = (Select MIN(Number) FROM my000))
	SET @NoDate = '1/1/1980';

	;WITH I AS
	(
		SELECT 
			I.*,
			ISNULL(CET.Date, I.Date) AS FilterDate
		FROM 
			inserted AS I 
			LEFT JOIN deleted AS D ON I.GUID = D.GUID AND I.State <> D.State AND I.State = 8
			LEFT JOIN er000 AS ERT ON I.GUID = ERT.ParentGUID AND ERT.ParentType = 501
			LEFT JOIN ce000 AS CET ON ERT.EntryGuid = CET.GUID
	)
	SELECT TOP 1
		@Amount = T.Amount,
		@Cnt = T.TotalCnt,
		@SumAmount = T.SumAmount,
		@TransferTypes = T.TransferType
	FROM 
		TransferConditions000 AS T
		JOIN I ON (T.ToDate <> @NoDate AND I.FilterDate BETWEEN T.FromDate AND T.ToDate) OR (T.ToDate = @NoDate AND I.FilterDate >= T.FromDate) 
	WHERE 
		SourceType = 1 AND DestinationType = 1
		AND (
				((I.State = 0 OR I.State = 2) AND (T.TransferType = 0 OR T.TransferType = 2) AND (T.BranchGuid = I.SourceBranch OR T.BranchGuid = 0x)) 
				OR 
				(I.State = 8 AND (T.TransferType = 1 OR T.TransferType = 2) AND (T.BranchGuid = I.DestinationBranch OR T.BranchGuid = 0x))
			)
		AND (T.CenterGuid = @CurrentCenter OR T.CenterGuid = 0x);

	IF @Amount IS NULL
		RETURN;

	SELECT 
		@PaidSum = SUM(CASE WHEN i.State <> ISNULL(d.State, 0) AND i.State = 8 THEN i.MustPaidAmount ELSE 0 END),
		@NewSum = SUM(CASE WHEN (i.State = 0 OR I.State = 2) THEN (i.Amount
		* (CASE WHEN i.CurrencyGUID  <> @CurrentCurancy 
				THEN i.CurrencyVal ELSE 1 END)
		) ELSE 0 END),
		@PaidCount = SUM(CASE WHEN i.State <> ISNULL(d.State, 0) AND i.State = 8 THEN 1 ELSE 0 END),
		@NewCount = SUM(CASE WHEN (i.State = 0 OR I.State = 2) THEN 1 ELSE 0 END)
	FROM 
		inserted AS i 
		LEFT JOIN deleted AS d ON i.Guid = d.Guid;
	
	-- «–« ﬂ«‰ œ›⁄ ÕÊ«·… Ê«—œ…
	IF (UPDATE(State) 
			AND EXISTS(
				SELECT * 
				FROM 
					inserted AS I 
					JOIN deleted AS D ON I.GUID = D.GUID AND I.State <> D.State AND I.State = 8 AND I.MustPaidAmount > @Amount
					JOIN er000 AS ERT ON I.GUID = ERT.ParentGUID AND ERT.ParentType = 501
					JOIN ce000 AS CET ON ERT.EntryGuid = CET.GUID
				WHERE 
					CET.[Date] = CONVERT(VARCHAR(10), GETDATE(), 120)
				)
				AND @Amount <> 0 AND (@TransferTypes = 2 OR @TransferTypes = 1))
	BEGIN
		INSERT INTO [ErrorLog] ([level], [type], [c1]) SELECT 1, 0, 'AmnE0175: Transfer Exceeded Amount limit Pay blahhh'
	END
	--INSERT INTO [ErrorLog] ([level], [type], [c1]) SELECT 1, 0, 'AmnE0175: Transfer Exceeded Amount limit Pay '+CAST(ISNULL(@PaidSum,0) AS VARCHAR(250)) + ' ' +CAST(ISNULL(@Amount,0) AS VARCHAR(250));
	IF EXISTS(SELECT *
		FROM 
			inserted AS i 
		WHERE
			(i.State = 0 OR i.State = 2)
			--AND i.Date = CONVERT(VARCHAR(10), GETDATE(), 120)
			 AND i.Amount > @Amount AND @Amount <> 0)
	BEGIN
		INSERT INTO [ErrorLog] ([level], [type], [c1]) SELECT 1, 0, 'AmnE0175: Transfer Exceeded Amount limit';
	END
	
	SELECT 
		@NewSum = @NewSum + ISNULL(SUM(T.Amount), 0),
		@NewCount = @NewCount + COUNT(T.GUID)
	FROM 
		TrnTransferVoucher000 AS T
		JOIN inserted I ON T.Date = I.Date
	WHERE 
		T.SourceType = 1 AND T.DestinationType = 1
		AND (T.[State] = 0 OR T.[State] = 2)
		AND T.SourceBranch = i.SourceBranch
		--AND T.[Date] = CONVERT(VARCHAR(10), GETDATE(), 120)
		AND NOT EXISTS(SELECT * FROM inserted WHERE GUID = T.GUID);
	
	SELECT
		@PaidSum = @PaidSum + ISNULL(SUM(T.MustPaidAmount), 0),
		@PaidCount = @PaidCount + COUNT(T.GUID)
	FROM 
		TrnTransferVoucher000 AS T
		JOIN inserted I ON T.Date = I.Date
		JOIN er000 AS ER ON I.GUID = ER.ParentGUID AND ER.ParentType = 501
		JOIN ce000 AS CE ON ER.EntryGuid = CE.GUID
		JOIN er000 AS ERT ON T.GUID = ERT.ParentGUID AND ERT.ParentType = 501
		JOIN ce000 AS CET ON ERT.EntryGuid = CET.GUID
	WHERE 
		T.SourceType = 1 AND T.DestinationType = 1
		AND T.DestinationBranch = I.DestinationBranch
		AND T.[State] = 8
		AND CE.[Date] = CET.[Date]
		AND NOT EXISTS(SELECT * FROM inserted WHERE GUID = T.GUID);

	IF ((@NewSum > @SumAmount AND (@TransferTypes = 0 OR @TransferTypes = 2)) OR (@PaidSum > @SumAmount AND (@TransferTypes = 0 OR @TransferTypes = 1))) AND @SumAmount <> 0
	BEGIN
		INSERT INTO [ErrorLog] ([level], [type], [c1]) SELECT 1, 0, 'AmnE0176: Transfer Exceeded Sum Amount limit '+CAST(@NewSum AS VARCHAR(250)) + ' ' +CAST(@SumAmount AS VARCHAR(250));
	END

	IF ((@NewCount > @Cnt AND (@TransferTypes = 0 OR @TransferTypes = 2)) OR (@PaidCount > @Cnt AND (@TransferTypes = 0 OR @TransferTypes = 1))) AND @Cnt <> 0
	BEGIN
		INSERT INTO [ErrorLog] ([level], [type], [c1]) SELECT 1, 0, 'AmnE0177: Transfer Exceeded Count Amount limit';
	END
END
###################################################################################
#END


