##########################
CREATE VIEW vwHosFSurgery
AS 
	SELECT 
	[Number],
	[GUID],
	[FileGUID],
	CAST( CAST (DatePart( yyyy, [BeginDate]) AS NVARCHAR) + '/' + CAST ( DatePart( mm, [BeginDate] ) AS NVARCHAR ) + '/'+CAST( DatePart( dd, [BeginDate] )AS NVARCHAR) AS datetime) AS [BeginDate],
	CAST( CAST (DatePart( yyyy, [EndDate]) AS NVARCHAR) + '/' + CAST ( DatePart( mm, [EndDate] ) AS NVARCHAR ) + '/'+CAST( DatePart( dd, [EndDate] )AS NVARCHAR) AS datetime) AS [EndDate],
	[Desc],
	[Tempreture],
	[Pressure],
	[NarStartWay],
	[NarTanbeeb],
	[NarFollowing],
	[NarBreathing],
	[NarLiquids],
	[NarBlood],
	[NarStartDate],
	[NarEndDate],
	[Security],
	[Name],
	[SiteGUID],
	[RoomCost],
	[PatientBillGuid],
	[SurgeryBillGuid],
	[RoomCostEntryGUID],
	[WorkersEntryGUID],
	[OperationGUID],
	[AnesthetistEntryGuid],
	[CurrencyGuid],
	[CurrencyVal]
FROM
	HosFSurgery000
##########################
CREATE VIEW  vwHosSurgery
AS
SELECT 
	S.Guid SurgeryGuid,
	S.FileGuid FileGuid,
	S.SurgeryBillGuid,
	S.patientBillGuid,		
---------------
	op.Guid  opGuid,
	ISNULL(op.Name, '') 			opName, 
	ISNULL(op.LatinName,'')  	opLatinName, 
	ISNULL(op.Code, '') 			opCode  ,
---------------
	Doc.Guid DocGuid,
	ISNULL(Doc.Name, '') 			DocName, 
	ISNULL(Doc.LatinName, '') DocLatinName, 
	ISNULL(Doc.Code, '')  		DocCode,
	ISNULL(Sw.Income, '')  		DocIncome,
---------------
	S.BeginDate SurgeryBeginDate ,
	S.EndDate SurgeryEndDate,
	DateDiff(MINUTE,S.BeginDate,S.EndDate) AS PeriodMinute,
	S.[DESC] NOTES,
	S.SiteGuid SurgerySiteGuid,
	SITE.[NAME] SiteName,
	S.Security
FROM hosFSurgery000 S INNER JOIN hosOperation000 Op On S.OperationGuid = Op.Guid
					  LEFT JOIN HosSurgeryWorker000 Sw On Sw.ParentGuid = S.Guid
					  LEFT JOIN vwHosDoctor Doc On Doc.Guid = Sw.WorkerGuid
					  LEFT JOIN  hossite000 AS SITE ON SITE.GUID = S.SiteGuid
####################################################
CREATE function  vwHosSurgeryCost()
RETURNS
	@result Table (Guid  uniqueidentifier, TOTALCost float)
as 
BEGIN
	Declare @Surgery_Cost int		  
	set @Surgery_Cost =  (select Value from op000 where name = 'HosCfg_SurgeryCost')  

	DECLARE @WorkersIncom TABLE (SurgeryGUID UNIQUEIDENTIFIER, TOTAL FLOAT)
	INSERT INTO @WorkersIncom
	SELECT 
		S.guid,
		SUM( w.Income)
	FROM 
		hosFSurgery000 AS S 
		INNER JOIN  HosSurgeryWorker000 w On w.ParentGuid = S.Guid
	GROUP BY S.guid

	INSERT INTO 	@RESULT
	SELECT 
		S.Guid SurgeryGuid,
		case @Surgery_Cost  
			WHEN  1 THEN 
				S.RoomCost +
				IsNull(bu1.Total,0)  + 
				IsNUll(bu2.Total,0)  +
				IsNUll(worker.Total,0)  
			ELSE 
				IsNUll(S.RoomCost,0) +
				IsNUll(bu2.Total,0)  +  
				IsNUll(worker.Total,0)  
			END  
		TotalCost 	

	FROM hosFSurgery000 AS S 
		LEFT JOIN @WorkersIncom AS worker On worker.SurgeryGUID = S.Guid
		LEFT JOIN bu000 AS bu1 On S.SurgeryBillGuid = bu1.Guid  
		LEFT JOIN bu000 AS bu2 On S.PatientBillGuid = bu2.Guid 	 
RETURN
END
##########################
#END