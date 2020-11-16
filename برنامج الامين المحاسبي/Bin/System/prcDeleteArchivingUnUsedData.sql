##########################################################################
CREATE PROCEDURE prcDeleteArchivingUnUsedData
AS
	BEGIN
		DELETE F 
		FROM DMSTblDocument D RIGHT JOIN DMSTblDocumentFieldValue F 
		ON D.ID = F.DocumentID
		WHERE D.ID IS NULL

		DELETE F 
		FROM DMSTblDocument D RIGHT JOIN DMSTblFile F 
		ON D.ID = F.DocumentId
		WHERE D.ID IS NULL
	END

##########################################################################
#END