#########################################################
CREATE FUNCTION fnEntry_getNewNum(@BranchGUID [UNIQUEIDENTIFIER] = NULL)
	RETURNS [INT]
AS BEGIN
	DECLARE @result [INT]
	
	IF ISNULL(@BranchGUID, 0x0) = 0x0
		SET @result = ISNULL((SELECT MAX([Number]) FROM [ce000]), 0) + 1
	ELSE
		SET @result = ISNULL((SELECT MAX([Number]) FROM [ce000] WHERE [Branch] = @BranchGUID), 0) + 1  

	RETURN @result
 END

#########################################################
CREATE FUNCTION fnEntry_getNewNum1( @entryNum [INT], @BranchGUID [UNIQUEIDENTIFIER] = NULL)
	RETURNS [INT]
AS BEGIN
	DECLARE @result [INT]
	SET @BranchGUID = ISNULL( @BranchGUID, 0X0)

	IF @entryNum = 0 OR EXISTS(SELECT * FROM [ce000] WHERE [Number] = @entryNum AND [Branch] = @BranchGUID )  
	BEGIN 

		IF ISNULL(@BranchGUID, 0x0) = 0x0
			SET @result = ISNULL((SELECT MAX([Number]) FROM [ce000]), 0) + 1
		ELSE
			SET @result = ISNULL((SELECT MAX([Number]) FROM [ce000] WHERE [Branch] = @BranchGUID), 0) + 1  
	END ELSE BEGIN 
		SET @result = @entryNum
	END
	RETURN @result
 END
#########################################################
#END
