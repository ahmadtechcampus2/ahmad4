###########################################################################
CREATE PROCEDURE prcCustomizePrintByConfigID
	@ConfgId  [UNIQUEIDENTIFIER],
	@TypeGuid  [UNIQUEIDENTIFIER]
As 
 SET NOCOUNT ON

    SELECT DISTINCT(TempletPrintGuid) AS Id, TypeGuid, ConFigerationID, r.Name 
	FROM 
		RichDocument000 r 
		INNER JOIN CustomizePrint000 c ON r.Id=c.TempletPrintGuid
		WHERE 
			c.ConFigerationID = @ConfgId 
		   AND c.TypeGuid = @TypeGuid 
		   AND c.UserGuid=0x0
###########################################################################
CREATE PROCEDURE prcAllCustomizePrintByConfigID
	@ConfgId  [UNIQUEIDENTIFIER],
	@UserGuid  [UNIQUEIDENTIFIER] = 0x0
As 
 SET NOCOUNT ON

    SELECT DISTINCT(TempletPrintGuid) AS Id, TypeGuid, ConFigerationID, r.Name 
	FROM 
		RichDocument000 r 
		INNER JOIN CustomizePrint000 c ON r.Id=c.TempletPrintGuid
		WHERE 
			c.ConFigerationID = @ConfgId 
			AND c.UserGuid=@UserGuid
###########################################################################
#END
