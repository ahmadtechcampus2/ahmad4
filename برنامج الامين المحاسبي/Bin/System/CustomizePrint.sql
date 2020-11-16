###########################################################################
CREATE PROCEDURE prcCustomizePrint
	@DocumentGuid [UNIQUEIDENTIFIER],
	@TypeGuid [UNIQUEIDENTIFIER],
	@UserGuid [UNIQUEIDENTIFIER],
	@ConfgId  [UNIQUEIDENTIFIER]
As 
 SET NOCOUNT ON
 
   INSERT INTO CustomizePrint000(TempletPrintGuid, TypeGuid, UserGuid, ConFigerationID) 
   VALUES(@DocumentGuid, @TypeGuid, @UserGuid, @ConfgId)
###########################################################################
#END
