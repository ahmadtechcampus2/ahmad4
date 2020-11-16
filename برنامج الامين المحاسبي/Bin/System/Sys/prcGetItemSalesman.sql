################################################################################
CREATE PROC prcGetItemSalesman
	@MatID			Uniqueidentifier,
	@TimeStr		NVARCHAR(25),
	@BillsID		Uniqueidentifier
AS 
SET NOCOUNT ON
	
	DECLARE 
		@DepartmentID	Uniqueidentifier,
		@GroupID		Uniqueidentifier,
		@BranchID		Uniqueidentifier,
		@Time			DATETIME

	SET @Time = CAST(@TimeStr AS DATETIME)
	SET @BranchID = (SELECT BranchID FROM posuserbills000 WHERE Guid = @BillsID)

	SET @GroupID = (SELECT IsNull(GroupGuid, 0x0) FROM Mt000 
					WHERE Guid = @MatID)

	SET @DepartmentID =(SELECT Top 1
							DeptGroup.ParentID 
						FROM vwDepartmentGroups DeptGroup
						LEFT JOIN Department000 Dept ON DeptGroup.ParentID = Dept.Guid
						WHERE 	(GroupID = @GroupID)
						AND		(Dept.BranchID = @BranchID)
						)

	SELECT * FROM vwSalesman
	WHERE 	(DepartmentID = @DepartmentID)
	AND 	(InWork = 1)
	AND 	( (DATEPART(Hour, @Time) * 60) + DATEPART(Minute, @Time) BETWEEN StartTime AND EndTime)
################################################################################
#END

