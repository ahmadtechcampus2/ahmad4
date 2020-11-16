##############################
CREATE VIEW vtHosRadioGraphyOrder
AS
	SELECT * FROM hosRadioGraphyOrder000
##############################
CREATE VIEW vbHosRadioGraphyOrder
AS
	SELECT * FROM vtHosRadioGraphyOrder
##############################
CREATE VIEW vcHosRadioGraphyOrder
AS
	SELECT * FROM vbHosRadioGraphyOrder
##############################
CREATE VIEW vdHosRadioGraphyOrder
AS
	SELECT * FROM vbHosRadioGraphyOrder

############################################################
CREATE  VIEW vwHosRadioGraphyOrder
AS 
SELECT   
		A.Number,    
		A.GUID,    
		A.Code,    
		A.FileGUID,    
		A.PatientGUID,    
		A.AccGUID,    
		A.Date,    
		A.StatusGUID,    
		A.Status,    
		A.Notes,    
		A.Security,    
		A.PayGuid,   
		A.Branch,  
		A.DoctorGUID,  
		F.[Code] [FileCode],   
		F.[Name] [FileName],   
		ISNULL( P.[Code], F.[Code])  PatientCode,   
		ISNULL( P.[Name], F.[Code]) PatientName, 
		P.GENDER	
	FROM vbHosRadioGraphyOrder A LEFT JOIN   vwHosFile F	 ON A.FileGUID    =  F.GUID  
								 LEFT JOIN   vwHosPatient P ON A.PatientGUID =  P.GUID  
############################################################
CREATE PROCEDURE RepHosRadioGraphyOrder
	@PatientGUID 	UNIQUEIDENTIFIER = 0x0,
	@FileGUID  		UNIQUEIDENTIFIER = 0x0,
	@AccGUID  		UNIQUEIDENTIFIER = 0x0,
	@FromDate  		DATETIME,
	@ToDate  			DATETIME,
	@Status  			NVARCHAR(250) = '',
	@SortBy 			INT = 0
AS
SET NOCOUNT ON
if ( @Status = '' ) 
	SET @Status = '0'
	
CREATE TABLE #T ( Status INT )
INSERT INTO #T  SELECT CAST(DATA AS  INT )FROM dbo.fnTextToRows(@Status)
SELECT 
	* 
FROM 
	vwHosRadioGraphyOrder   O INNER JOIN #T  S  ON O.Status = S.Status
WHERE 
	(O.PatientGUID = @PatientGUID OR  @PatientGUID = 0x0)
	AND
	(O.FileGUID = @FileGUID OR @FileGUID = 0x0)
	AND
	(O.AccGUID = @AccGUID OR @FileGUID = 0x0)
	AND
	(O.[Date] BETWEEN @FromDate AND  @ToDate)
ORDER BY CASE WHEN @SortBy = 0 THEN O.[Date] ELSE O.Number END
############################################################
#END