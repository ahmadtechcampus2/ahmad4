##############################
CREATE VIEW vwHosInsuranceCategoryCard
AS
SELECT
			Number,
			GUID,
			Code,
			Name,
			LatinName,
			InsuranceGUID,
			MaxAmount,
			Note
	FROm HosInsuranceCategoryCard000
	
##############################
#END