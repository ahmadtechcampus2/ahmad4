################################################################################
CREATE FUNCTION fnGetWagesDefault(@Amount FLOAT, @WagesTypeID UNIQUEIDENTIFIER)
RETURNS FLOAT
BEGIN

	DECLARE @Wages FLOAT = 0;

	SET @Wages = (
	SELECT TOP 1
		CASE 
			WHEN wUseRange = 1 THEN
				ISNULL((SELECT MAX(wiWage) FROM vwTrnWages WHERE wGUID = @WagesTypeID AND @Amount BETWEEN wiMinAmount AND wiMaxAmount),(SELECT MAX(wiWage) FROM vwTrnWages WHERE wGUID = @WagesTypeID))
			ELSE CASE 
				WHEN wRatioType = 1 THEN
					@Amount * wRatio / 100
				ELSE
					ISNULL(@Amount * (SELECT MAX(wiRatio) FROM vwTrnWages WHERE wGUID = @WagesTypeID AND @Amount BETWEEN wiMinAmount AND wiMaxAmount) / 100,
					@Amount * (SELECT MAX(wiRatio) FROM vwTrnWages WHERE wGUID = @WagesTypeID) / 100)
				END
		END AS Wages
	FROM 
		vwTrnWages
	WHERE 
		wGUID = @WagesTypeID)
	RETURN @Wages;
END
################################################################################
CREATE PROC repTrnWagesDifferences
	@SenderBranch		UNIQUEIDENTIFIER = 0x0,
	@ReciverBranch		UNIQUEIDENTIFIER = 0x0,
	@FromDate			DATETIME = '',
	@ToDate				DATETIME = '',
	@DiffereceOptions	INT		 = 1
AS
	SET NOCOUNT ON

	;WITH TRN AS
	(
		SELECT 
		tv.GUID					GUID,
		tv.InternalNum			InternalNumber, 
		tv.Code,
		tv.Date					TrnDate,
		sb.Name					SenderBranch,
		rb.Name					RecieverBranch,
		tv.state				TransferState,
		tv.Amount				Ammount,
		My.Name					ReciveCurrency,
		tv.WagesType			WagesType,
		tv.DestBranchWages		DestBranchDefaultWages,
		tv.NetWages / tv.CurrencyVal				ActualWages,
		tv.Wages / tv.CurrencyVal	DefaultWages,
		sender.Name + ' ' + sender.FatherName + ' ' + sender.LastName				SenderName,
		reciever.Name + ' ' + reciever.FatherName + ' ' + reciever.LastName			RecieverName
	FROM 
		TrnTransferVoucher000 tv
		INNER JOIN TrnBranch000 sb ON sb.GUID = tv.SourceBranch 
		INNER JOIN TrnBranch000 rb ON rb.Guid = tv.DestinationBranch
		LEFT JOIN TrnSenderReceiver000 sender ON sender.GUID = tv.SenderGUID
		LEFT JOIN TrnSenderReceiver000 reciever ON reciever.GUID = tv.Receiver1_GUID
		INNER JOIN MY000 my ON my.GUID = tv.CurrencyGUID
	WHERE 
		SourceType = 1 AND DestinationType = 1
		AND (SourceBranch = @SenderBranch OR @SenderBranch = 0x0)
		AND (DestinationBranch = @ReciverBranch OR @ReciverBranch = 0x0)
		AND tv.Date BETWEEN @FromDate AND @ToDate
	
	)
	SELECT 
		T.*,
		T.ActualWages - T.DefaultWages AS [Difference]
	FROM 
		TRN AS T
	WHERE 
		(
			(ActualWages > DefaultWages AND @DiffereceOptions & 2 > 0)
			 OR (ActualWages < DefaultWages AND @DiffereceOptions & 4 > 0)
			 OR (ActualWages = DefaultWages AND @DiffereceOptions & 8 > 0)
		)
	ORDER BY 
		Code, InternalNumber, TrnDate
###################################################################################
#END

