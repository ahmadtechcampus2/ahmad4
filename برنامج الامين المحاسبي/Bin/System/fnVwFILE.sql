###############################
CREATE FUNCTION fnVwFILE ( @PatientGUID [UNIQUEIDENTIFIER])
RETURNS TABLE
AS 
	RETURN  
		SELECT		
			[F].[Number],
			[F].[GUID],
			[F].[Code] ,
			[P].[Name],
			[P].[LatinName],
			[F].[Security],
			[F].[DateIn],
			[F].[DateOut],
			[F].[PatientGuid]
		FROM 
			[HosPFile000] [F] INNER JOIN [vwHosPatient] AS [P] ON [F].[PatientGUID] = [P].[GUID]
		WHERE 
			[F].[PatientGuid] = @PatientGUID
	

########################################
#END
