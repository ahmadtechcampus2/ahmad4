################################################################################
CREATE PROCEDURE prcDeleteDiffrencesBills
	@CloseDay			    [DATETIME]
AS
	SET NOCOUNT ON 
	Declare @IncreaseBillTypeGuid uniqueidentifier =  dbo.fnOption_GetGUID('PFC_IncreaseBillType')
	Declare @DecreaseBillTypeGuid uniqueidentifier =  dbo.fnOption_GetGUID('PFC_DecreaseBillType')
	 
	UPDATE bu000 SET Isposted = 0
	WHERE Date = @CloseDay AND  TypeGuid IN(@IncreaseBillTypeGuid, @DecreaseBillTypeGuid)

	Delete FROM bu000 WHERE Date = @CloseDay AND Isposted = 0 AND TypeGuid IN(@IncreaseBillTypeGuid, @DecreaseBillTypeGuid)
################################################################################
#END
