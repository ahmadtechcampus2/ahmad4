#########################################################
CREATE PROC prc_man_form_delete	@guid UNIQUEIDENTIFIER
AS
DELETE FROM MAN_FORM000 WHERE guid = @guid
DELETE FROM MAN_FORM_RAWMAT000 WHERE parentform = @guid
DELETE FROM MANMANAFUCTUREDMATS000 WHERE parentform = @guid
DELETE FROM VARIEDCOST000 WHERE ParentGuid = @guid
DELETE FROM MANMACHINES000 WHERE parentGuid = @guid
DELETE FROM MANWORKER000 WHERE parentGuid = @guid
#########################################################	                      
#END