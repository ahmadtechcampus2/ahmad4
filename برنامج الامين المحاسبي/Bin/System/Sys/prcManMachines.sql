########################################################
CREATE PROCEDURE prcGetMachineInfo @AdGuid [UNIQUEIDENTIFIER] 
AS
DECLARE
	@SN NVARCHAR(100) ,
	@MachineName NVARCHAR(50),
	@MACHINELATINNAME NVARCHAR(50)
SELECT @SN = snc.SN FROM snc000 AS snc 
					WHERE snc.Guid =( SELECT ad.SNGuid FROM ad000 AS ad 
					WHERE ad.guid = @AdGuid )
SELECT @MachineName  = mt.[name] ,@MACHINELATINNAME =mt.[latinName] FROM mt000 AS mt 
					WHERE  mt.guid =(SELECT matguid FROM snc000 AS snc 
					WHERE snc.guid =(SELECT ad.snguid FROM ad000 AS ad WHERE ad.guid = @AdGuid))
SELECT @SN As [sn] , @MachineName AS [machineName] ,@MACHINELATINNAME AS [machineLatinName]
########################################################
CREATE PROCEDURE prcDeleteManMachines @parentGuid [UNIQUEIDENTIFIER]
AS
	DELETE FROM ManMachines000  where parentGuid = @parentGuid
#########################################################	                      
#END