#########################################################
CREATE VIEW vwHosDailyFollowing
AS
SELECT 
	D.Number, 
	D.GUID, 
	FileGUID, 
	[Date], 
	WorkerGUID, 
	Therapy, 
	D.Security,
	Code EmpCode, 
	[Name] EmpName
FROM
	hosFDailyFollowing000 D LEFT JOIN vwHosEmployee E On E.GUID = D.WorkerGUID
#########################################################
CREATE VIEW vwHosDailyFollowingDoc
AS
SELECT 
	D.Number, 
	D.GUID, 
	FileGUID, 
	[Date], 
	WorkerGUID, 
	Therapy, 
	D.Security,
	Code EmpCode, 
	[Name] EmpName
FROM
	hosFDailyFollowing000 D LEFT JOIN vwHosEmployee E On E.GUID = D.WorkerGUID
WHERE D.Type = 0
#########################################################
CREATE VIEW vwHosDailyFollowingNur
AS
SELECT 
	D.Number, 
	D.GUID, 
	FileGUID, 
	[Date], 
	WorkerGUID, 
	Therapy, 
	D.Security,
	Code EmpCode, 
	[Name] EmpName
FROM
	hosFDailyFollowing000 D LEFT JOIN vwHosEmployee E On E.GUID = D.WorkerGUID
WHERE D.Type = 1
#########################################################
#END