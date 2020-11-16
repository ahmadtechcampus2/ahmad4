######################################################################################
CREATE CREATE PROCEDURE prcDBCConnections_Clean
	@CleanMe BIT = 0 
AS
/* 
This procedure: 
	- checks for the existance of Connections table, and when necessary, creates it. 
	- makes sure that records in connections table belongs to currently active connections. 
	- is called usually from prcConnections_Add and prcConnections_List. 
*/ 
--	SET NOCOUNT ON 

	BEGIN TRAN 
	CREATE TABLE #t( 
		spid INT, 
		ecid INT, 
		status NVARCHAR(255) COLLATE ARABIC_CI_AI, 
		loginname NVARCHAR(255) COLLATE ARABIC_CI_AI, 
		hostname NVARCHAR(255) COLLATE ARABIC_CI_AI, 
		blk INT, 
		dbname NVARCHAR(255) COLLATE ARABIC_CI_AI, 
		cmd NVARCHAR(255) COLLATE ARABIC_CI_AI) 

	INSERT INTO #t EXEC sp_who

	DELETE Connections FROM Connections AS c LEFT JOIN #t AS t ON c.SPID = t.SPID WHERE t.SPID IS NULL  
	--DELETE repSrcs FROM repSrcs AS r LEFT JOIN #t AS t ON r.SPID = t.SPID WHERE t.SPID IS NULL

	IF @CleanMe = 1
	BEGIN
		DELETE Connections WHERE spid = @@SPID 
		--DELETE RepSrcs WHERE SPID = @@SPID 
	END

	DROP TABLE #t 
	 
	COMMIT TRAN 
######################################################################################
#END