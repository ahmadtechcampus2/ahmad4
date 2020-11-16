##################################################################
CREATE PROCEDURE prc_Used_Mat
@MATGUID		UNIQUEIDENTIFIER 
AS 
/*
	Result = 1: mat used in mi000
	Result = 2: mat used in bi000
	Result = 3: mat used in mi000 and bi000
	Result = 4: mat used in POSTicketItem000
*/
	SET NOCOUNT ON
	DECLARE
		@Result INT = 0, 
		@Unit2 INT = 0,
		@Unit3 INT = 0
	IF EXISTS(SELECT * FROM mi000 WHERE MatGUID = @MATGUID)
	BEGIN
		select @Result = 1
		IF EXISTS(SELECT * FROM mi000 WHERE MatGUID = @MATGUID AND Unity = 2)
			SET @Unit2 = 1
		IF EXISTS(SELECT * FROM mi000 WHERE MatGUID = @MATGUID AND Unity = 3)
			SET @Unit3 = 1
	END
	
	IF EXISTS(SELECT * FROM bi000 WHERE MatGUID = @MATGUID)
	BEGIN
		select @Result = @Result + 2
		IF EXISTS(SELECT * FROM bi000 WHERE MatGUID = @MATGUID AND Unity = 2)
			SET @Unit2 = 1
		IF EXISTS(SELECT * FROM bi000 WHERE MatGUID = @MATGUID AND Unity = 3)
			SET @Unit3 = 1
	END

	IF EXISTS(SELECT * FROM POSSDTicketItem000 TI LEFT JOIN POSSDTicket000 T ON TI.TicketGuid = T.[GUID] WHERE MatGUID = @MATGUID AND T.[State] != 2)
	BEGIN
		select @Result = @Result + 4
		IF EXISTS(SELECT * FROM POSSDTicketItem000 TI LEFT JOIN POSSDTicket000 T ON TI.TicketGuid = T.[GUID] WHERE MatGUID = @MATGUID AND T.[State] != 2 AND TI.UnitType = 1)
			SET @Unit2 = 1
		IF EXISTS(SELECT * FROM POSSDTicketItem000 TI LEFT JOIN POSSDTicket000 T ON TI.TicketGuid = T.[GUID] WHERE MatGUID = @MATGUID AND T.[State] != 2 AND TI.UnitType = 2)
			SET @Unit3 = 1
	END

	IF @Result > 0
		SELECT @Result AS Result, @Unit2 as Unit2Used, @Unit3 As Unit3Used
#################################################################
#END