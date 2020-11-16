##################################################################################
CREATE FUNCTION fbPPo
	( @TypeGUID AS [UNIQUEIDENTIFIER]) 
	RETURNS TABLE 
	AS 
		RETURN (SELECT * FROM [ppo000] AS [PPo] WHERE [PPo].[TypeGUID] = @TypeGUID) 

##################################################################################
#END
