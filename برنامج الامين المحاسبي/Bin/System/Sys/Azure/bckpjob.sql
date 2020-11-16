##########################################################
## ≈÷«›… „Â„… ‰”Œ «Õ Ì«ÿÌ
## -------------------------------------------------------
## Edited by: Eyad al-akhras (16:30 11/02/2002)
##########################################################
create Procedure RepAddBackupJob
	@JobName [NVARCHAR](256),
	@JobType [int],
	@JobTime [int],
	@Jobday [int],
	@JobStartDate [int],
	@DBName [NVARCHAR](256),
	@Dir [NVARCHAR](256),
	@BkNum [INT],
	@Occurance		[INT]= 1   , --1 Once Only, 2 Every 
	@HoursNumber [INT] = 1--Number of hours   
As
	EXECUTE prcNotSupportedInAzure
###########################################################
## ⁄„· ‰”Œ… «Õ Ì«ÿÌ… „‰ ﬁ»· „Â„…
create Procedure RepDoBackupJob
	@JobType [int],
	@DBName [NVARCHAR](256),
	@DirName [NVARCHAR](1000),
	@BkNum [INT]
As
	EXECUTE prcNotSupportedInAzure

################################################################
## Õ–› „Â„… ‰”Œ «Õ Ì«ÿÌ
create Procedure RepDeleteBackupJob
	@JobName [NVARCHAR](256)
As
	EXECUTE prcNotSupportedInAzure

################################################################
## Ì” Œœ„ „‰ RepGetJobSchedule
CREATE PROCEDURE RepGetResultOfJobSchedule
	@job_guid uniqueidentifier
AS 
	EXECUTE prcNotSupportedInAzure

################################################################
## ≈Õ÷«— ÃœÊ·… „Â„…
CREATE PROCEDURE RepGetJobSchedule
	@jobName [NVARCHAR](256) 
AS  
	EXECUTE prcNotSupportedInAzure

################################################################
##Ã⁄· ‰”Œ… «Õ Ì«ÿÌ… œ«∆„…
CREATE PROCEDURE repMakePremanentBackup
				@FileName [NVARCHAR](255),
				@Perm [int]
AS
	EXECUTE prcNotSupportedInAzure
################################################################
##·Õ–› «·‰”Œ «·«Õ Ì«ÿÌ… «·≈÷«›Ì…
CREATE PROCEDURE repDeleteExtraJobBackup
			@JobType [INT],
			@BkNum [INT],
			@DBName [NVARCHAR](1000) = ''
AS
	EXECUTE prcNotSupportedInAzure
################################################################
##≈Õ÷«— „·›«  «·‰”Œ «·«Õ Ì«ÿÌ 
CREATE PROCEDURE prcGetBackupFiles
				@DbName [NVARCHAR](255)
AS 
	EXECUTE prcNotSupportedInAzure
################################################################
#END
