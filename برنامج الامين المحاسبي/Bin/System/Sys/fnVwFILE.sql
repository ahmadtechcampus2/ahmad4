###############################
CREATE FUNCTION fnVwFILE ( @PatientGUID UNIQUEIDENTIFIER)
RETURNS TABLE
AS 
	RETURN  
		SELECT		
			F.Number,
			F.GUID,
			F.Code ,
			P.[Name],
			P.[LatinName],
			F.Security,
			F.DateIn,
			F.DateOut,
			F.PatientGuid
		FROM 
			HosPFile000 F INNER JOIN vwHosPatient AS P ON F.PatientGUID = P.GUID
		WHERE 
			F.PatientGuid = @PatientGUID
########################################
CREATE  FUNCTION FnVwHosBillMats
	(
		@BillGuid UNIQUEIDENTIFIER 	
	)
RETURNS  @result TABLE
(
	notes	NVARCHAR(200) COLLATE ARABIC_CI_AI,
	[Date]	DATETIME,
	total	FLOAT,
	matName NVARCHAR(200) COLLATE ARABIC_CI_AI, 
	unit	NVARCHAR(200) COLLATE ARABIC_CI_AI,
	Qty		FLOAT,
	price	FLOAT
)
AS
BEGIN
INSERT @result
SELECT  bu.notes,bu.[date], bu.total,
	mt.[name] AS matname, 
		CASE bi.unity 
			WHEN 1 THEN mt.unity 
			WHEN 2 THEN mt.unit2 
			WHEN 3 THEN mt.unit3 
		END
		AS unit,
		CASE bi.unity 
			WHEN 1 THEN bi.qty   
			WHEN 2 THEN bi.qty /  unit2fact
			WHEN 3 THEN bi.qty / unit3fact
		END
		AS qty,
	bi.price
	
--FROM hosConsumedMaster000 AS c 
	FROM bu000 AS bu 
	--INNER JOIN bu000 AS bu ON bu.guid = c.billguid 
	INNER JOIN bi000 AS bi ON bu.guid = bi.parentguid
	INNER JOIN mt000 AS mt ON mt.guid = bi.matguid
	WHERE bu.guid = @BillGuid 
	--ORDER BY c.[date]
RETURN 
END
################################################################
CREATE function fnRepSurgeryDetailes	
(
	@FileGuid UNIQUEIDENTIFIER
)

/*RETURNS  @result TABLE
(
	notes NVARCHAR(200),
	[Date] DATETIME,
	total FLOAT,
	matName NVARCHAR(200), 
	unit NVARCHAR (200),
	Qty FLOAT,
	price FLOAT

)*/
RETURNS  @TEMP  TABLE
(
	Guid		UNIQUEIDENTIFIER,
	type		INT,-- 0 main, 1 doctors,2 patient bill , 3 surgery bill
	[NAME]		NVARCHAR(200) COLLATE ARABIC_CI_AI, --  ÇáØÈíÈ  -- ÇÓã ÇáÚãáíÉ 
	[Date]		DATETIME, -- æÞÊ ÇáÚãáíÉ 
	[DateOut]	DATETIME, -- æÞÊ ÇáÚãáíÉ 
	COST		FLOAT, --- ÇáÃÊÚÇÈ 
	unit		NVARCHAR(200) COLLATE ARABIC_CI_AI, -- æÍÏÉ ÇáãÇÏÉ
	Qty			FLOAT, -- ÇáßãíÉ 
	price		FLOAT, -- ÇáÓÚÑ  
	NOTES		NVARCHAR(200) COLLATE ARABIC_CI_AI -- ÇáÈíÇä
)
AS
BEGIN
DECLARE @RESULT TABLE 
(
	Guid		UNIQUEIDENTIFIER,
	type		INT,-- 0 main, 1 doctors,2 patient bill , 3 surgery bill
	[NAME]		NVARCHAR(200) COLLATE ARABIC_CI_AI, --  ÇáØÈíÈ  -- ÇÓã ÇáÚãáíÉ 
	[Date]		DATETIME, -- æÞÊ ÇáÚãáíÉ 
	[DateOut]	DATETIME, -- æÞÊ  
	COST		FLOAT, --- ÇáÃÊÚÇÈ
	unit		NVARCHAR(200) COLLATE ARABIC_CI_AI, -- æÍÏÉ ÇáãÇÏÉ -- ÇÓã ÇáãæÞÚ
	Qty			FLOAT, -- ÇáßãíÉ 
	price		FLOAT, -- ÇáÓÚÑ  
	NOTES		NVARCHAR(200) COLLATE ARABIC_CI_AI  -- ÇáÈíÇä
)
	DECLARE @Guid UNIQUEIDENTIFIER, @SurgeryBillGuid UNIQUEIDENTIFIER,
	@patientBillGuid UNIQUEIDENTIFIER, @SurgeryGuid	UNIQUEIDENTIFIER,
	@OpName  NVARCHAR(200), @Date DATETIME, @DateOut DATETIME,
	@DocName NVARCHAR(200), @Tot FLOAT, @SiteName NVARCHAR(200), @Period INT
		
	DECLARE c CURSOR FOR  
	SELECT  
		DISTINCT(sur.SurgeryGuid),
		SurgeryBillGuid,
		patientBillGuid,
		OpName,
		SurgeryBeginDate,
		SurgeryEndDate,
		SiteName,
		PeriodMinute,
		fn.totalcost
	FROM 
	vwHosSurgery AS sur 
	INNER JOIN fnHosGetSurgeryCost(@FileGuid) AS Fn ON Fn.SurgeryGuid = sur.SurgeryGuid
	WHERE FileGuid = @FileGuid
	ORDER BY [SurgeryBeginDate]
	OPEN C
	FETCH NEXT FROM C
	INTO  
		@Guid,
		@SurgeryBillGuid,
		@patientBillGuid,
		@opName,
		@Date,
		@DateOut,
		@SiteName,
		@Period,
		@Tot


	WHILE (@@FETCH_STATUS = 0 ) 
	BEGIN 
		-- ÇáÃÓÇÓí 
		INSERT INTO @result 
		SELECT 
			@Guid,
			0,
			@OpName,
			@Date,
			@DateOut,
			@Tot,
			@SiteName,
			0,
			0,
			''

		-- ÇáÚÇãáíä 
		INSERT INTO @result  (Guid, type, [name], [Date] ,COST, Notes)
		SELECT
			@Guid,--Sw.Guid,
			1,
			Doc.Name,
			@Date,
			sw.InCome,
			sw.[Desc]	

			FROM HosSurgeryWorker000 AS SW 
			INNER JOIN vwHosDoctor AS DOC ON Doc.Guid = Sw.WorkerGuid
			WHERE SW.parentGuid = @Guid
		-- ÇáãæÇÏ 
		INSERT INTO @Result (Guid, type, [Name],[Date], COST, unit, Qty,price) 
		SELECT 
			@Guid,
			2,
			matName,
			@Date,
			total,
			unit,	
			Qty,
			price
			FROM FnVwHosBillMats(@patientBillGuid) AS fn 

		INSERT INTO @Result (Guid, type, [Name],[Date], COST, unit, Qty,price) 
		SELECT
			@Guid,
			3,
			matName,
			@Date,
			total,
			unit,	
			Qty,
			price
			FROM FnVwHosBillMats(@SurgeryBillGuid) AS fn 

		FETCH NEXT FROM C	 
		INTO  
		@Guid,
		@SurgeryBillGuid,
		@patientBillGuid,
		@opName,
		@Date,
		@DateOut,
		@SiteName,
		@Period,
		@Tot
	END 
	CLOSE C
	DEALLOCATE C 
		
INSERT INTO @TEMP				
 SELECT * FROM @result ORDER BY [date], type
RETURN 
END
########################################
CREATE FUNCTION FnVwHosConsumedDetaild
	( 
		@FileGuid UNIQUEIDENTIFIER =  0x0 
	) 
RETURNS  @result TABLE 
( 
	Guid	UNIQUEIDENTIFIER, 
	notes	NVARCHAR(200) COLLATE ARABIC_CI_AI, 
	[Date]	DATETIME, 
	total	FLOAT, 
	matName NVARCHAR(200) COLLATE ARABIC_CI_AI,  
	unit	NVARCHAR(200) COLLATE ARABIC_CI_AI, 
	Qty		FLOAT, 
	price	FLOAT 
) 
AS 
BEGIN 
DECLARE @UserPerm INT, @UserGUID UNIQUEIDENTIFIER
SET @UserGUID = dbo.fnGetCurrentUserGUID() 
SELECT @UserPerm = [dbo].[fnGetUserSec](@UserGUID, 2147549664, 0x0, 1, 1 ) -- @PermType
INSERT @result 
SELECT c.guid, c.notes,c.[date], 
	CASE bi.unity  
			WHEN 1 THEN bi.qty    
			WHEN 2 THEN bi.qty /  unit2fact 
			WHEN 3 THEN bi.qty / unit3fact 
		END 
		* 
		bi.price , 
	mt.[name] AS matname,  
		CASE bi.unity  
			WHEN 1 THEN mt.unity  
			WHEN 2 THEN mt.unit2  
			WHEN 3 THEN mt.unit3  
		END 
		AS unit, 
		CASE bi.unity  
			WHEN 1 THEN bi.qty    
			WHEN 2 THEN bi.qty /  unit2fact 
			WHEN 3 THEN bi.qty / unit3fact 
		END 
		AS qty, 
	bi.price 
	 
FROM hosConsumedMaster000 AS c  
	INNER JOIN bu000 AS bu ON bu.guid = c.billguid  
	INNER JOIN bi000 AS bi ON bu.guid = bi.parentguid 
	INNER JOIN mt000 AS mt ON mt.guid = bi.matguid 
	WHERE @FileGuid = 0x0 OR c.fileGuid = @FileGuid  AND  @UserPerm >= c.security  
	ORDER BY c.[date], c.notes 

RETURN  
END 
########################################
#END
