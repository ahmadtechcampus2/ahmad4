##############################################
CREATE FUNCTION fnTrnGet_InStatementDetailes
	(
		@FromDate			DATETIME
		,@ToDate			DATETIME
		,@SenderContains	NVARCHAR(512)
		,@ReceiverContains	NVARCHAR(512)
		,@Destination		UNIQUEIDENTIFIER
		,@SourceOffice		UNIQUEIDENTIFIER
		,@Branch			UNIQUEIDENTIFIER 
	)
RETURNS TABLE	
AS
RETURN
(
	SELECT 
		vr.* 
	FROM TrnTransferVoucher000 vr 
		INNER JOIN TrnSenderReceiver000 sender ON vr.SenderGUId = sender.GUID 
		INNER JOIN TrnSenderReceiver000 receiver1 ON vr.Receiver1_GUID = receiver1.GUID
		LEFT JOIN TrnSenderReceiver000 receiver2 ON vr.Receiver2_GUID = receiver2.GUID 
		INNER JOIN TrnStatement000 Stm ON Stm.GUID = vr.StatementGUID  
		INNER JOIN TrnStatementTypes000 StmType ON StmType.GUID = Stm.TypeGUID  
	WHERE  
		vr.StatementGuid <> 0x0 AND vr.IsFromStatement = 1 AND vr.InStatementPayedGuid = 0x0 
		AND (IsReturned = 1 OR paid = 1)
		
		AND (ISNULL(@SourceOffice, 0x0) = 0x0 OR stmType.OfficeGUID = @SourceOffice)
		AND (@SenderContains = '' OR sender.Name = @SenderContains)
		AND (@ReceiverContains = '' OR receiver1.Name = @ReceiverContains OR receiver2.Name = @ReceiverContains)
		AND vr.[Date] BETWEEN @FromDate AND @ToDate
		AND (ISNULL(@Destination, 0x0) = 0x0 OR vr.DestinationGuid = @Destination)
)		

##############################################
CREATE FUNCTION fnTrnGet_OutStatementDetailes
	(
		@FromDate			DATETIME
		,@ToDate			DATETIME
		,@SenderContains	NVARCHAR(512)
		,@ReceiverContains	NVARCHAR(512)
		,@Destination		UNIQUEIDENTIFIER
		,@DestinationOffice		UNIQUEIDENTIFIER
		,@Branch			UNIQUEIDENTIFIER 
		
	)
RETURNS TABLE
AS
RETURN
(
	
	SELECT 
		vr.* 
	FROM TrnTransferVoucher000 vr 
		inner join TrnSenderReceiver000 sender ON vr.SenderGUId = sender.GUID 
		inner join TrnSenderReceiver000 receiver1 ON vr.Receiver1_GUID = receiver1.GUID
		Left join TrnSenderReceiver000 receiver2 ON vr.Receiver2_GUID = receiver2.GUID 
	WHERE  
		vr.Approved > 0  AND ISNULL(vr.OutStatementGuid, 0x0) = 0x0 
		
		AND vr.DestinationBranch = @DestinationOffice
		AND vr.DestinationType = 2

		AND (@SenderContains = '' OR sender.Name = @SenderContains)
		AND (@ReceiverContains = '' OR receiver1.Name = @ReceiverContains OR receiver2.Name = @ReceiverContains)
		AND vr.[Date] BETWEEN @FromDate AND @ToDate
		AND (ISNULL(@Destination, 0x0) = 0x0 OR vr.DestinationGuid = @Destination)		
)		
##############################################
#END