##############################
CREATE VIEW vwHosInsuranceCard
AS
SELECT
			Number,
			GUID,
			Code,
			Name,
			LatinName,
			Address,
			Phone,
			AccGuid,
			Security
	FROm HosInsuranceCard000

##############################
#END