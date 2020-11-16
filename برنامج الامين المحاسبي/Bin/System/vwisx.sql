#############################################
CREATE VIEW vtisx
AS
	select isx.*
	from
		isx000 isx cross join Connections co
	where
		co.SPID = @@spid
		AND dbo.fnGetUserMask( co.UserNumber) & dbo.fnGetUserOrderMask( co.UserNumber, Mask1, Mask2, Mask3, Mask4 ) != 0
#############################################
CREATE VIEW vwisx
AS 
	select * from vtisx
##############################################
#END