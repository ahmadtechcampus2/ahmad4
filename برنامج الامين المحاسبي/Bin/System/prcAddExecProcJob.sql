####################################################################
## this procedure Add Job To database
## this job Execute Procedure
CREATE Procedure prcAddExecProcJob 
	@JobName [NVARCHAR](256), 
	@JobType [int], 
	@JobTime [int], 
	@Jobday [int], 
	@JobStartDate [int], 
	@DBName [NVARCHAR](256), 
	@PrcName [NVARCHAR](MAX) ,
	@parameters NVARCHAR(MAX),
	@Occurance		[INT]= 1   , --1 Once Only, 2 Every 
	@HoursNumber [INT] = 1,--Number of hours   
	@FreqRelativeInterval [INT] = 0
As 
SET NOCOUNT ON

DECLARE @Command [NVARCHAR]( MAX)
SELECT @Command = 'DECLARE @UsGuid [UNIQUEIDENTIFIER] 
		   SELECT top 1 @UsGuid = [GUID] FROM [us000] WHERE [bAdmin] = 1
		   Execute [prcConnections_add] @UsGuid' + char(13)
SELECT @Command = @Command + ' Execute ' + @PrcName + ' ' + @parameters

EXEC dbo.prcAddJob 	
			@JobName, 
			@JobType, 
			@JobTime, 
			@Jobday, 
			@JobStartDate, 
			@DBName, 
			@Command,
			@Occurance,
			@HoursNumber,
			@FreqRelativeInterval
#######################################################################
#END