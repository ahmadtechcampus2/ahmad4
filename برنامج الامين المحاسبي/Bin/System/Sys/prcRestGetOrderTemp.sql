######################################################
CREATE Procedure prcRestGetOrderTemp
	@Guid				[uniqueidentifier],
	@User				[uniqueidentifier] = 0x0,
	@DepartmentID		[uniqueidentifier] = 0x0
AS
SET NOCOUNT ON	

SELECT * FROM vwRestOrderTemp
WHERE (@Guid=0x0 or @Guid=Guid) 
		AND (@User=0x0 or @User=[CashierID])
		AND (@DepartmentID=0x0 or @DepartmentID=[DepartmentID])
Order By CASE
			WHEN Receipting = '1980-01-01 00:00:00.000'THEN 1 
			WHEN CONVERT (date, Receipting)  = CONVERT (date, GETDATE()) then 2
			ELSE 0
		END , Receipting, Number
######################################################
CREATE Procedure prcRestGetOrder
	@Guid				[uniqueidentifier],
	@User				[uniqueidentifier] = 0x0,
	@DepartmentID		[uniqueidentifier] = 0x0
AS
SET NOCOUNT ON	

SELECT * FROM vwRestOrder
WHERE (@Guid=0x0 or @Guid=Guid) 
		AND (@User=0x0 or @User=[CashierID])
		AND (@DepartmentID=0x0 or @DepartmentID=[DepartmentID])
Order By CASE
			WHEN Receipting = '1980-01-01 00:00:00.000'THEN 1 
			WHEN CONVERT (date, Receipting)  = CONVERT (date, GETDATE()) then 2
			ELSE 0
		END, Receipting , Number
######################################################
CREATE PROCEDURE prcGetConCurrencyOrder
	@Guid	UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON	
	DECLARE @OS_Corrected INT = 7

	SELECT
		Guid
	FROM
		vwRestOrderTemp
	WHERE
		@Guid=Guid 
		AND (HostName<>HOST_NAME())
		AND (State=@OS_Corrected)
######################################################
#END