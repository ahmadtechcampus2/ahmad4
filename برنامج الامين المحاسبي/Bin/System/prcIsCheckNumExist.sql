#################################################
CREATE PROCEDURE prcIsCheckNumExist
	@Num [INT],
	@Type [UNIQUEIDENTIFIER]
AS
	SELECT COUNT(*) AS [cnt] FROM [ch000] WHERE [Number] = @Num AND [TypeGuid] = @Type

/*
EXEC prcIsCheckNumExist 77
select * from nt000
*/
#################################################
#END
