#########################################################
CREATE PROC prcCheckSecurity_userSec
	@result [NVARCHAR](128) = '#result',
	@secViol [NVARCHAR](128) = '#secViol',
	@violTypeID [INT]

AS
	SET NOCOUNT ON 
	
	DECLARE @SQL [NVARCHAR](2000)

	IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'security')
			AND EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'userSecurity')
	BEGIN
		SET @SQL = '
			DELETE FROM '+ @result +' WHERE [security] > [userSecurity]
			INSERT INTO ' + @secViol + ' SELECT ' + CAST(@violTypeID AS [NVARCHAR](7)) + ', @@ROWCOUNT'
	END			

	EXEC (@SQL)

#########################################################
CREATE PROC prcUsersSorting
@SortBy INT
AS
SET NOCOUNT ON  

SELECT DISTINCT
		us.guid AS UserGuid
		,us.Number
		,us.LoginName 
		,vc.Guid AS GroupGuid
		,vc.LoginName AS GroupName
		,us.FixedDate
FROM 
	us000 AS us
    LEFT JOIN rt000 AS rt ON us.GUID = rt.ChildGUID 
    LEFT JOIN vcus1 AS vc ON rt.ParentGUID = vc.GUID  
WHERE
    us.Type = 0	
ORDER BY 
	us.Number
 --   CASE @sortBy WHEN 0 THEN us.Number END,
 --   CASE @sortBy WHEN 1 THEN us.LoginName END,    
 --   CASE @sortBy WHEN 2 THEN vc.LoginName END, 
	--CASE @sortBy WHEN 3 THEN us.FixedDate END

#########################################################
#END