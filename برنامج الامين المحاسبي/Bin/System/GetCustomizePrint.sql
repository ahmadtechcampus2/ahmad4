###########################################################################
CREATE PROCEDURE prcGetCustomizePrint
	@TypeGuid [UNIQUEIDENTIFIER],
	@UserGuid [UNIQUEIDENTIFIER],
	@ConfgId  [UNIQUEIDENTIFIER]
As 
 SET NOCOUNT ON
	 SELECT r.* FROM RichDocument000 r INNER JOIN CustomizePrint000 c ON r.Id=c.TempletPrintGuid
		WHERE c.ConFigerationID = @ConfgId 
			  AND c.TypeGuid = @TypeGuid 
			  AND c.UserGuid=@UserGuid
###########################################################################
#END
