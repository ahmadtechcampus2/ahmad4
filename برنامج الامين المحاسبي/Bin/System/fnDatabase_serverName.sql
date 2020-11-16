#########################################################
create function fnDatabase_serverName()
	returns [nvarchar](128)
as begin
/*
this function:
	- returns the database servers' name.
	- used mainly in replication.
*/

	return cast(isnull(serverproperty('ServerName'), serverproperty('InstanceName')) as [nvarchar](128))

end

#########################################################