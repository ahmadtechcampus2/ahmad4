##################################
create proc HosEntriesFile
	@FileGuid uniqueidentifier
AS
SET NOCOUNT ON 
declare @CostGuid uniqueidentifier, @AccGuid uniqueidentifier

select 
	@CostGuid = CostGuid,
	@AccGuid = AccGuid

	From HospFile000 
	Where Guid = @FileGuid
				
Select  
	distinct(py.pyGuid) as Guid ,
	et.[etName] AS TypeName,
	--ac.name, 
	py.pyTypeGuid as TypeGuid,
	--py.number, 
	py.pynotes as Notes, 
	py.[pydate] as [Date],
	py.pySecurity as Security
	--ce.Guid,
	--ce.notes, en.number, en.date  

From vwPy as Py
	INNER JOIN vwet As et on py.pyTypeGuid = et.etGuid 
	INNER JOIN er000 as er on er.ParentGuid = Py.pyGuid
	INNER JOIN ce000 as ce on er.EntryGuid = ce.Guid
	INNER JOIN en000 as en on en.ParentGuid = ce.Guid
	inner join vwac as ac on ac.acGuid = en.AccountGuid 
where 	
	@CostGuid = en.CostGuid
	--And	@AccGuid = en.AccountGuid
	--order by en.date, py.guid, en.number 
	order by py.pydate
##################################
CREATE proc HosUpdate_FirstStayGuid
	@FileGuid uniqueidentifier
as
SET NOCOUNT ON 
DECLARE @FirstStayGuid uniqueidentifier, @FileSite uniqueidentifier
DECLARE @FileDateIn DateTime
 
SELECT @FileSite = SiteGuid, @FileDateIn = DateIn  
FROM HosPfile000 where Guid =@FileGuid

SELECT @FirstStayGuid = Guid 
from HosStay000 
where FileGuid = @FileGuid 
	and StartDate = (select Min(StartDate) From hosStay000 where fileGuid = @FileGuid)

update HosStay000 
set SiteGuid = @FileSite,  StartDate = @FileDateIn 
where Guid = @FirstStayGuid
####################################################################
CREATE PROC prcHosCurrentResident
	@SiteGuid UNIQUEIDENTIFIER
AS
SET NOCOUNT ON

DECLARE @BillTypeGuid UNIQUEIDENTIFIER
SELECT 
	@BillTypeGuid = CAST(VALUE AS UNIQUEIDENTIFIER)
FROM OP000
WHERE NAME = 'HosCfg_Consumed_BillType'

SELECT	TOP 1
	Site.Code AS SiteCode,	
	PFile.AccGuid,
	PFile.CostGuid,
	Co.[Name] AS CostName,
	@BillTypeGuid AS BillTypeGuid
From HosStay000 as Stay
	INNER JOIN hospfile000 as PFile ON Stay.FileGuid = PFile.Guid
	INNER JOIN hospatient000 as patient ON patient.guid = PFile.patientGuid
	INNER JOIN hosperson000 as person ON person.Guid = patient.PersonGuid
	INNER JOIN Hossite000 as Site ON Site.Guid = Stay.SiteGuid 
	INNER JOIN Co000 as Co ON Co.Guid = PFile.CostGuid 		
WHERE Site.Guid = @SiteGuid AND 
	(GetDate() between Stay.StartDate and Stay.EndDate)
####################################################################
#END