###################################################
CREATE PROC repPatientsStatistics
	@Gender 		INT, 
	@Nationality 	NVARCHAR(32), 
	@FileStartDate 	DATETIME,
	@FileEndDate 	DATETIME,
	@BirthStartDate DATETIME,
	@BirthEndDate 	DATETIME,
	@UseBirthDate 	INT,
	@SortBy 		INT
AS
SET NOCOUNT ON 

	DECLARE @MaleStr NVARCHAR(100)
	SELECT @MaleStr = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'male' ELSE 'ÐßÑ' END

	DECLARE @FemaleStr NVARCHAR(100)
	SELECT @FemaleStr = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'female' ELSE 'ÃäËì' END

	IF @SortBy = -1 SET @SortBy = 0
	
	IF @SortBy = 0 
		SELECT 
			CASE T.Gender WHEN 0 THEN @FemaleStr ELSE @MaleStr END AS Gender, 
			P.Nation, 
			COUNT(*) AS PatientsCount
		FROM 
			hosPerson000 P INNER JOIN hosPatient000 T ON P.GUID = T.PersonGUID
			INNER JOIN hosPFile000 PF ON T.GUID = PF.PatientGUID
		WHERE 
			PF.DateIn >= @FileStartDate AND PF.DateOut <= @FileEndDate AND
			(@Gender = -1 OR T.Gender = @Gender) AND
			(@Nationality = '' OR P.Nation = @Nationality) AND
			(@UseBirthDate != 1 OR P.BirthDay BETWEEN @BirthStartDate AND @BirthEndDate)

		GROUP BY
			T.Gender, P.Nation
		ORDER BY
			T.Gender, P.Nation
	ELSE
		SELECT 
			P.Nation, 
			CASE T.Gender WHEN 0 THEN @FemaleStr ELSE @MaleStr END AS Gender, 
			COUNT(*) AS PatientsCount
		FROM 
			hosPerson000 P INNER JOIN hosPatient000 T ON P.GUID = T.PersonGUID
			INNER JOIN hosPFile000 PF ON T.GUID = PF.PatientGUID
		WHERE 
			PF.DateIn >= @FileStartDate AND PF.DateOut <= @FileEndDate AND
			(@Gender = -1 OR T.Gender = @Gender) AND
			(@Nationality = '' OR P.Nation = @Nationality) AND
			(@UseBirthDate != 1 OR P.BirthDay BETWEEN @BirthStartDate AND @BirthEndDate)

		GROUP BY
			P.Nation, T.Gender
		ORDER BY
			P.Nation, T.Gender
/*

EXEC repPatientsStatistics -1, '', '1/1/2005', '12/31/2005', '1/1/1970', '1/10/2005', 0, 1
*/
################################################
#END