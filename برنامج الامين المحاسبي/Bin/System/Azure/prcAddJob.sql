####################################################################
CREATE Procedure prcAddJob 
	@JobName		[NVARCHAR]( 256), --name of job
	@JobType		[INT], -- type of job 4: d, 8: w, 16: m
	@JobTime		[INT], 
	@Jobday			[INT], 
	@JobStartDate	[INT], 
	@DBName			[NVARCHAR]( 256), 
	@Command		[NVARCHAR]( max),
	@Occurance		[INT] = 2, --1 Once Only, 2 Every 
	@HoursNumber [INT]  = 250--Number of hours 
AS
/*
	this procedure Add Job To database
	this job Execute the Command
*/
	--
	-- This functionality is not available in Azure
	EXECUTE prcNotSupportedInAzure

#######################################################################
#END