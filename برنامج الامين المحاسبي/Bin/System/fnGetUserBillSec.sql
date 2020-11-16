###########################################################################
CREATE FUNCTION fnGetUserBillSec(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER], @PermType [INT])
	RETURNS [INT]
AS BEGIN
	DECLARE  
		@RID_BILL AS [INT], 
		@RID_MANUFACTURE AS [INT],
		@RID_ASSEMBILL AS [INT],
		@RID_MATERIALS_COST_CARD AS INT
	SET @RID_BILL = 0x10010000 
	SET @RID_MANUFACTURE = 0x20002040 
	SET @RID_ASSEMBILL = 0x1002E000
	SET @RID_MATERIALS_COST_CARD = 536894576
	 
	IF EXISTS (SELECT * FROM BT000 WHERE TYPE = 2 AND Guid =@Type and SORTNum IN ( 5, 6) ) 
		RETURN [dbo].[fnGetUserSec](@UserGUID, @RID_MANUFACTURE, 0x00, 1, @PermType)  
	IF EXISTS (SELECT * FROM BT000 WHERE TYPE IN (9, 10) AND Guid =@Type) 
		RETURN [dbo].[fnGetUserSec](@UserGUID, @RID_ASSEMBILL, @Type, 1, @PermType)  

	--Õ«·… »ÿ«ﬁ…  ﬂ·Ì› «·„Ê«œ —»ÿ ’·«ÕÌ… ”⁄— «·‰„ÿ »’·«ÕÌ… «” ⁄—«÷ «·»ÿ«ﬁ… 
	IF EXISTS (SELECT * FROM BT000 WHERE BillType IN (4, 5) AND Guid =@Type AND SortNum = 0) 	
		RETURN [dbo].[fnGetUserSec](@UserGUID, @RID_MATERIALS_COST_CARD, 0x0, 1, 1)

   RETURN [dbo].[fnGetUserSec](@UserGUID, @RID_BILL, @Type, 1, @PermType) 
END
###########################################################################
#END