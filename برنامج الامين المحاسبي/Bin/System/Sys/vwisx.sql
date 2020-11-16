#############################################
CREATE VIEW vtisx
AS
	SELECT isx.*
	FROM
		isx000 isx --cross join Connections co
	WHERE
		--co.[HostName] = HOST_NAME() AND co.[HostId] = HOST_ID()
		-- co.SPID = @@spid
		 dbo.fnGetUserOrder_Mask( dbo.fnGetCurrentUserNumber(), Mask1, Mask2, Mask3, Mask4 ) != 0 
#############################################
CREATE VIEW vwisx
AS 
	SELECT * FROM vtisx
##############################################
CREATE VIEW vw_us_Normal
AS
	SELECT 
		[GUID], [Number], [LoginName], [bAdmin], [FirstName], [LastName], [Department], [Responsibility], '' AS [Code], '' AS [Name]
	FROM 
		us000
	WHERE
		[Type] = 0 AND [bAdmin] != 1
##############################################
#END
