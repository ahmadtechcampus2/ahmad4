################################################################################
CREATE FUNCTION fnCheckUsersLinkWithMoreOneGroup() 
RETURNS BIT  
AS
BEGIN 
DECLARE @Exist BIT = 0
IF EXISTS 
(
SELECT us.Guid
FROM 
	us000 us 
WHERE 
	us.[Type] = 0
	AND 
	(SELECT COUNT(childGuid) FROM rt000 rt WHERE rt.ChildGUID = us.Guid) > 1	
)
SET @Exist = 1

RETURN @Exist
END	
--SELECT dbo.fnCheckUsersLinkWithMoreOneGroup()
################################################################################
CREATE PROCEDURE prcGetAllUsers
AS 
SET NOCOUNT ON
SELECT us.Number,us.GUID, us.LoginName ,(SELECT COUNT(childGuid) FROM rt000 rt WHERE rt.ChildGUID = us.Guid) GroupsCount
FROM us000 us WHERE us.[Type] = 0
ORDER BY us.Number
################################################################################
#END
