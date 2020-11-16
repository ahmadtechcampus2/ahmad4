########################################################
CREATE PROC prcVariedCostDelete	@GUID UNIQUEIDENTIFIER ,@TYPE INT 
AS
DELETE FROM VARIEDCOST000 WHERE [PARENTGUID] = @GUID
								and [TYPE]=@TYPE
#########################################################	                      
#END			 								