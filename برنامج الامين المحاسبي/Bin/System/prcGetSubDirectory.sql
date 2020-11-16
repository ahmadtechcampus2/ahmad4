#######################################################################
CREATE PROC prcGetSubDirectory @Dir NVARCHAR(1000), @Lev INT = 1
AS 
	exec master.dbo.xp_dirtree @dir, @lev	
#######################################################################
#END