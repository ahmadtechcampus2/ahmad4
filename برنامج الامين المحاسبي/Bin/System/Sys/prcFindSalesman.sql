################################################################################
CREATE PROC prcFindSalesman
	@SearchValue	NVARCHAR(256),
	@BillsID		UNIQUEIDENTIFIER
AS
SET NOCOUNT ON

	DECLARE 
		@CurrentBranch UNIQUEIDENTIFIER

	SET @CurrentBranch = (SELECT BranchID FROM posuserbills000 WHERE Guid = @BillsID)
	SELECT 
		Co.Code AS SalesmanCode,
		Co.Name AS SalesmanName,
		Co.Guid AS SalesmanID
	FROM Salesman000 Salesman
	LEFT JOIN Co000 Co ON Salesman.Guid = Co.Guid
	LEFT JOIN Department000 Dept ON Salesman.DepartmentID = Dept.Guid
	WHERE 	((Dept.BranchID = @CurrentBranch) OR (IsNull(@CurrentBranch, 0x0) = 0x0))
	AND		((Co.Code = @SearchValue) OR (Co.Name = @SearchValue))
################################################################################
#END
