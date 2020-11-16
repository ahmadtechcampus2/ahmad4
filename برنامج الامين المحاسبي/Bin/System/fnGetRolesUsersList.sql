######################################################### 
CREATE FUNCTION fnGetRolesUsersList(@RoleGUID [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER])
AS BEGIN
/*
This function:
	- returns a list of users and rows descending from given @roleGuid
	- caller should join with us000 of type 0 or 1 to identify or filter as needed.
*/

	-- insert roles:
	INSERT INTO @Result  SELECT [GUID] FROM [fnGetRolesList](@RoleGuid)

	-- insert users:
	INSERT INTO @Result
		SELECT [rt].[rtChildGuid] FROM
			@result AS [rs] INNER JOIN [vwRT] AS [rt] ON [rs].[guid] = [rt].[rtParentGuid]
			INNER JOIN [vwUs] AS [us] ON [rt].[rtChildGuid] = [us].[usGuid]
		WHERE
			[us].[usType] = 0
	RETURN
END

#########################################################
#END