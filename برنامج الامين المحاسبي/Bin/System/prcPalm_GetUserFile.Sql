#########################################################
CREATE PROCEDURE prcPalm_GetUserFile   
	@PalmUserName [NVARCHAR](255)              
AS              
-------------------------------------              
SET NOCOUNT ON              

EXEC [prcPalm_GetUserTemplates] @PalmUserName
EXEC [prcPalm_GetUserStores] @PalmUserName
EXEC [prcPalm_GetUserCosts] @PalmUserName
EXEC [prcPalm_GetUserCustomers] @PalmUserName
EXEC [prcPalm_GetUserMaterial] @PalmUserName
EXEC [prcPalm_GetUserStatement] @PalmUserName

#########################################################
#END