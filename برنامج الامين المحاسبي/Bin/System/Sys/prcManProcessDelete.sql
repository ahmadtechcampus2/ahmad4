########################################################
CREATE PROC prcManProcessDelete		@processGuid [UNIQUEIDENTIFIER]
									  ,@operationDelete [INT]
AS
IF(@operationDelete = 1)
BEGIN
	DELETE FROM MANoperation000 WHERE guid = @processGuid
END
DELETE FROM MAN_FORM_RAWMAT000 WHERE parentform = @processGuid
DELETE FROM MANMANAFUCTUREDMATS000 WHERE parentform = @processGuid
DELETE FROM VARIEDCOST000 WHERE ParentGuid = @processGuid
DELETE FROM MANMACHINES000 WHERE parentGuid = @processGuid
DELETE FROM MANWORKER000 WHERE parentGuid = @processGuid
#########################################################	                      
#END