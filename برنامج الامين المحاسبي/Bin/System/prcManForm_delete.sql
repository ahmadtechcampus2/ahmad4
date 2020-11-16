########################################################
CREATE PROCEDURE prcManForm_delete
	@guid [UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON
	
	delete [fm000] where [guid] = @guid

########################################################
CREATE PROCEDURE prcDeleteManMachines @parentGuid [UNIQUEIDENTIFIER]
AS
	DELETE FROM ManMachines000  where parentGuid = @parentGuid
########################################################
CREATE PROCEDURE prcDeleteManWorkers @ParentGuid [UNIQUEIDENTIFIER]
AS
	DELETE FROM MANWORKER000 WHERE parentGuid = @ParentGuid
#########################################################
#END    