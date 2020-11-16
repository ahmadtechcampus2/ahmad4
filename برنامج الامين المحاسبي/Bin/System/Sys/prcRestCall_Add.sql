################################################################
CREATE PROCEDURE prcRestCall_Add  
	@Mode	[INT] = -1,
	@Guid [uniqueidentifier],
	@CallerID [NVARCHAR](50) = '',
	@CustomerID [uniqueidentifier],
	@OrderID [uniqueidentifier] = 0x0,
	@UserID [uniqueidentifier] = 0x0,
	@Date [datetime] = '1/1/1980',
	@Status [int] = 0
AS
SET NOCOUNT ON

IF @Mode=0
BEGIN
	INSERT INTO [RestCallsLog000]
           ([Guid]
		   ,[CallerID]
           ,[CustomerID]
		   ,[OrderID]
		   ,[UserID]
           ,[Date]
           ,[Status])
SELECT 
			@Guid
			,@CallerID
			,@CustomerID
			,@OrderID
			,@UserID
			,@Date
			,@Status
END 
ELSE IF @Mode=1
BEGIN
	UPDATE [RestCallsLog000] SET 
		[CallerID] = @CallerID
		,[CustomerID] = @CustomerID
		,[OrderID] = @OrderID
		,[UserID] = @UserID
		,[Date] = @Date
		,[Status] = @Status
	WHERE [Guid] = @Guid
END	
           
####################################################################
CREATE PROCEDURE prcCallsLogReport 
@StartDate [datetime],
	@EndDate [datetime],
	@UserID [uniqueidentifier] = 0x0,
	@CustomerID [uniqueidentifier] = 0x0,
	@CallStatus [int] = -1
AS
SET NOCOUNT ON

SELECT c.CallerID, c.Date, cu.cuCustomerName CustomerName, o.OrderNumber OrderNumber, c.Status
FROM RestCallsLog000 c 
LEFT JOIN vwCu cu ON c.CustomerID = cu.cuGUID
LEFT JOIN RestOrder000 o ON o.Guid = c.OrderID
WHERE (c.Date BETWEEN @StartDate AND @EndDate)
AND	  ((cu.cuGUID = @CustomerID) OR @CustomerID = 0x0)
AND   ((c.UserID = @UserID) OR @UserID = 0x0)
AND   ((c.Status = @CallStatus) OR @CallStatus = -1)
ORDER BY c.Date DESC

####################################################################
#END


