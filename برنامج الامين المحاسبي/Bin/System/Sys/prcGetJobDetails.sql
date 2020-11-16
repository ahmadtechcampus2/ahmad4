#####################################################################################
CREATE PROCEDURE prcGetJobDetails
	@JobID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	SELECT 
		js.step_id,
		js.step_uid,
		js.step_name,
		CASE 
			WHEN (SELECT 1 WHERE jOp.Name LIKE N'%BillType%') = 1 THEN 1
			WHEN (SELECT 1 WHERE jOp.Name LIKE N'%EntryType%' OR jOp.Name LIKE N'%ChequeType%') = 1 THEN 2
			ELSE 0 -- other option
		END AS OptionType,
		jOp.Name AS OptionName,
		jOp.Value AS OptionValue,
		dbo.fnGetJobOptionFormatedValue(jOp.Name, jOp.Value) AS FormatedValue
	INTO 
		#Result
	FROM
		msdb.dbo.sysjobsteps AS js
		LEFT JOIN ScheduledJobOptions000 jOp ON js.step_uid = jOp.TaskGUID
	WHERE job_id = @JobID
	ORDER BY
		js.step_id,
		OptionType;

	IF EXISTS(SELECT * FROM #Result WHERE OptionName LIKE N'%BillType%' OR OptionName LIKE N'%EntryType%' OR OptionName LIKE N'%ChequeType%')
	BEGIN
		UPDATE R
			SET FormatedValue = ISNULL(ISNULL(BT.btName, ISNULL(ET.etName, nt.ntName)), N'')
		FROM
			#Result AS R
			LEFT JOIN vwbt AS BT ON CAST(R.OptionValue AS UNIQUEIDENTIFIER) = BT.btGuid
			LEFT JOIN vwet AS ET ON CAST(R.OptionValue AS UNIQUEIDENTIFIER) = ET.etGuid
			LEFT JOIN vwnt AS NT ON CAST(R.OptionValue AS UNIQUEIDENTIFIER) = nt.ntGuid
		WHERE 
			OptionName LIKE N'%BillType%' 
			OR OptionName LIKE N'%EntryType%' 
			OR OptionName LIKE N'%ChequeType%';
	END

	SELECT res.* FROM #Result AS res LEFT JOIN checkDBProc AS checkDb ON checkDb.procName = OptionName ORDER BY step_id, OptionType, checkDb.code ,OptionName 
#####################################################################################
CREATE FUNCTION fnGetJobOptionFormatedValue(@opName NVARCHAR(500), @opValue NVARCHAR(500))
RETURNS NVARCHAR(MAX)
BEGIN
	IF (SELECT 1 WHERE @opName LIKE N'%MatGUID%') = 1
		RETURN (SELECT mtCode+'-'+mtName FROM vwmt WHERE mtGuid = CAST(@opValue AS UNIQUEIDENTIFIER));

	IF (SELECT 1 WHERE @opName LIKE N'%GroupGUID%') = 1
		RETURN (SELECT grCode+'-'+grName FROM vwgr WHERE grGuid = CAST(@opValue AS UNIQUEIDENTIFIER));

	IF (SELECT 1 WHERE @opName LIKE N'%StoreGUID%') = 1
		RETURN (SELECT stCode+'-'+stName FROM vwst WHERE stGuid = CAST(@opValue AS UNIQUEIDENTIFIER));

	IF (SELECT 1 WHERE @opName LIKE N'%CostGUID%') = 1
		RETURN (SELECT coCode+'-'+coName FROM vwco WHERE coGuid = CAST(@opValue AS UNIQUEIDENTIFIER));

	RETURN N'';
END
#####################################################################################
#END