############################################################
CREATE PROCEDURE prcUpdateAccCostNewRatio
	@ParentAccGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON 
	
	IF EXISTS(SELECT * FROM AccCostNewRatio000 WHERE PrimaryGUID = @ParentAccGUID)
	BEGIN
		CREATE TABLE #Result 
		(
			ParentGUID		UNIQUEIDENTIFIER,
			PrimaryGUID		UNIQUEIDENTIFIER,
			ControlDbColumn NVARCHAR(250),
			EntryRel		INT
		)

		INSERT INTO #Result 
		SELECT DISTINCT 
			ParentGUID,
			PrimaryGUID,
			ControlDbColumn,
			Entry_Rel
		FROM AccCostNewRatio000
		WHERE PrimaryGUID = @ParentAccGUID

		DELETE FROM AccCostNewRatio000 WHERE PrimaryGUID = @ParentAccGUID 

		SELECT 
			NEWID()				AS GUID,
			r.ParentGuid		AS ParentGUID, 
			r.PrimaryGuid		AS PrimaryGUID,
			ci.SonGUID			AS SonGUID,
			ci.Num2				AS Ratio,
			r.controlDbColumn	AS ControlDbColumn,
			r.EntryRel			AS EntryRel,
			ac.Debit			AS Debit,
			ci.CustomerGUID		AS CustomerGUID,
			IDENTITY(INT, 0, 1) AS Number
	    INTO #Temp
		FROM ci000 as ci 
		INNER JOIN #Result  AS r ON r.PrimaryGuid = ci.ParentGUID 
		LEFT JOIN ac000		AS ac ON ac.GUID = ci.SonGUID

		INSERT INTO AccCostNewRatio000	
		SELECT 
			GUID,
			ParentGUID,
			PrimaryGUID,
			SonGUID,
			Ratio,
			ControlDbColumn,
			EntryRel,
			Debit,
			Number, 
			ISNULL(CustomerGUID, 0x0)
		FROM #Temp
	END				
################################################################################
#END