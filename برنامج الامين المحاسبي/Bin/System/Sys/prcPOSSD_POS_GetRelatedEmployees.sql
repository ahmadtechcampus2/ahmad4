################################################################################
CREATE Procedure prcPOSGetRelatedEmployees
@posGuid UNIQUEIDENTIFIER
AS
BEGIN
	SELECT PE.* FROM POSEmployee000 PE INNER JOIN POSRelatedEmployees000 PR ON PE.Guid = PR.EmployeeGuid
	WHERE POSGuid = @posGuid
	AND PE.IsWorking = 1
END
#################################################################
#END 