###############################################################################
CREATE VIEW DMSVwDocumentFieldsInfo AS 
SELECT VAL.DocumentID,
       VAL.FieldID,
	   VAL.Value AS FLDVaLue,
	   Name AS FLDName, 
	   LatinName AS FLDLatinName ,
	   [Type] AS FLDType,
	   [Order] FLDOrder,
	   DisplayText AS COMBODisplayText, 
	   LatinDisplayText AS COMBOLatinDisplayText 
FROM DMSTblDocumentFieldValue AS VAL INNER JOIN 
     DMSTblField AS FLD ON FLD.ID=VAL.FieldID LEFT JOIN 
	 DMSTblComboValue AS COMBO 
	 ON CAST(COMBO.ID AS VARCHAR(max))=VAL.Value WHERE FLD.IsHidden=0
###########################################################################
CREATE VIEW DMSVwDocumentCalculatedProperties AS 
SELECT		DocumentID,
			COUNT(ID) FileCount,
			SUM(Size) Size 
FROM		DMSTblFile 
GROUP BY	DocumentId
###########################################################################
#END