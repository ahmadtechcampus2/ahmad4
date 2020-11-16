################################################################################
CREATE PROC prcPOSCheckReturnItems 
	@ReturnInBranch	INT,
	@Branch			UNIQUEIDENTIFIER,
	@Number			FLOAT,
	@Date			DATETIME,
	@ReturnInDays	INT,
	@ReturnDays		INT
AS
SET NOCOUNT ON

	DECLARE 
		@OrderBranch	UNIQUEIDENTIFIER,
		@OrderDate		DATETIME,
		@OrderNumber	INT,
		@OrderID		UNIQUEIDENTIFIER,
		@ReturnResult	INT

	SELECT 
		@OrderBranch = 	[Order].[BranchID],
		@OrderDate = 	[Order].[Date],
		@OrderNumber = 	[Order].[Number],
		@OrderID	=	[Order].[Guid]
	FROM POSOrder000 [Order]
	WHERE [Order].[Number] = @Number

	IF (IsNull(@OrderNumber, 0) = 0) 
		SET @ReturnResult = 0 		-- The order has not found
	ELSE
	IF ( @OrderBranch != @Branch) AND (@ReturnInBranch = 1)
		SET @ReturnResult = 1 		-- The order is not in the branch	
	ELSE
	IF (@ReturnInDays = 1) AND (@Date NOT BETWEEN @OrderDate AND @OrderDate + @ReturnDays)
		SET @ReturnResult = 2 		-- The Order is not in the return days
	ELSE
	IF ( (SELECT Count(*) FROM POSOrderItems000
		WHERE 	ParentID = @OrderID
		AND 	Type = 0) = 0)
		SET @ReturnResult = 3 		-- The order has no sales items
	ELSE
		SET @ReturnResult = 4 		-- The order is accepted to return items


	SELECT @ReturnResult AS ReturnResult

################################################################################
#END
