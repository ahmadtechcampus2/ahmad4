########################################################
CREATE PROCEDURE prcDeleteWorker @WorkerGuid [UNIQUEIDENTIFIER]
AS
DELETE FROM WORKERS000 WHERE guid = @WorkerGuid
########################################################
CREATE PROCEDURE prcDeleteManWorkers @ParentGuid [UNIQUEIDENTIFIER]
AS
DELETE FROM MANWORKER000 WHERE parentGuid = @ParentGuid
#########################################################	                      
#END
