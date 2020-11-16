################################################################################
CREATE PROCEDURE prcPOSGetPosAccounts
@posGuid uniqueidentifier
AS
BEGIN
       SELECT 
                     AC.Name  AS AccountName,
                     AC.LatinName  AS  AccountLatinName,
                     AC.GUID AS AccountGuid
       FROM 
                     ac000 AC INNER JOIN POSCard000 PC ON AC.GUID = PC.ContinuesCash
       WHERE PC.Guid = @posGuid

       UNION ALL

       SELECT 
                     AC.Name  AS AccountName,
                     AC.LatinName  AS  AccountLatinName,
                     AC.GUID AS AccountGuid
       FROM 
                     ac000 AC INNER JOIN POSEmployee000 PE ON AC.GUID = PE.MinusAccount OR AC.GUID = PE.ExtraAccount
                     INNER JOIN POSRelatedEmployees000 PR ON PR.EmployeeGuid = PE.Guid AND PR.POSGuid = @posGuid
       
END
#################################################################
#END 