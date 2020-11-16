#########################################################
create proc prcServer_listDir
	@path [NVARCHAR](255) = null,
	@showFiles [bit] = 0
as
/*
This procedure:
	- lists drive names only if @path is null.
	- lists directories only if @showFiles was 0.
	- returns dir of given @path.
	- acts on servers' hardware only, DRIVES AND PATHES ARE RELATIVE TO THE SQL-SERVER
*/
	EXECUTE prcNotSupportedInAzure
 
#########################################################
#end