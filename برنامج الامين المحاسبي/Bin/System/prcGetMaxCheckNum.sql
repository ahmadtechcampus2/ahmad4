#########################################################################
CREATE PROCEDURE prcGetMaxCheckNum
	@Type	[UNIQUEIDENTIFIER] = 0X0
AS 
	SET NOCOUNT ON
	SELECT ISNULL(MAX([Number]), 0) AS Max FROM [ch000] WHERE @Type = 0X0 OR [TypeGuiD] = @Type
########################################################################
#END