#########################################################
CREATE VIEW vtTrnStatement
AS
	SELECT * FROM  TrnStatement000
#########################################################
CREATE VIEW vbTrnStatement
AS
	SELECT v.*
	FROM vtTrnStatement AS v INNER JOIN fnBranch_GetCurrentUserReadMask(DEFAULT) AS f ON v.branchMask & f.Mask <> 0
#########################################################
CREATE VIEW vcTrnStatement
AS
	SELECT * FROM vbTrnStatement

#########################################################
CREATE VIEW vdTrnStatement
AS
	SELECT DISTINCT * FROM vbTrnStatement

#########################################################
CREATE VIEW vwTrnStatement
AS   
	SELECT
		Number,
		GUID, 
		TypeGUID, 
		Code, 
		IncomingStatement, 
		FaxNo, 
		SignerName, 
		Total, 
		CurrencyGUID, 
		CurrencyVal, 
		CurrencyGUID2, 
		CurrencyVal2, 
		Date, 
		CustomerGuid, 
		DueDate, 
		Notes, 
		branchMask, 
		Security, 
		TotalInCur2,
		IsGeneratd	
	FROM  
		vbTrnStatement
#########################################################
CREATE FUNCTION fbTrnStatement
	( @TypeGUID AS UNIQUEIDENTIFIER)
	RETURNS TABLE
	AS
		RETURN (SELECT * FROM vcTrnStatement AS st WHERE st.TypeGUID = @TypeGUID)
#########################################################

#END

/*
select * from TrnTransferVoucher000
*/