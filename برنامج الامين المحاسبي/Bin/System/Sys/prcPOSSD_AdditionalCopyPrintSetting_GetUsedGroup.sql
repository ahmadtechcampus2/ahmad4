################################################################################
CREATE PROCEDURE prcPOSSDAdditionalCopyPrintSetting_GetUsedGroup
	@StationGuid UNIQUEIDENTIFIER,
	@AdditionalCopyPSGUID UNIQUEIDENTIFIER,	
	@PDGuid UNIQUEIDENTIFIER,
	@OperationType INT ,
	@GRGuidList NVARCHAR(MAX)
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSDAdditionalCopyPrintSetting_IsGroupExist
	Purpose: check if specified groups exist in POS additional copy print settings that belong to a specific print design and operation type
	How to Call: EXEC prcPOSSDAdditionalCopyPrintSetting_GetUsedGroup '8d7b83ea-fdcf-4936-b8c5-5e245edf0f9c','cc008441-c78e-47dc-86b7-f8ddbd4d3330',1,'''02606b65-b68b-4cc5-a681-0b0f27ef744d','11e4c387-60d4-4539-ac71-2d1716bc1b08'''
	Create By: Hanadi Salka													Created On: 15 March 2018
	
	Updated On:	Hanadi Salka												Updated By: 12 April 2018
	
	Change Note:

	Remove the print design validaton from the where condition
	********************************************************************************************************/
	DECLARE @sqlCommand NVARCHAR(MAX);
	SET @sqlCommand = CONCAT('SELECT  DISTINCT Detail.GroupGUID AS GUID, GR.Number, GR.Code, GR.NAME, GR.LatinName  FROM POSSDAdditionalCopyPrintSettingHeader000 AS Header INNER JOIN POSSDAdditionalCopyPrintSettingDetail000 AS Detail   ON (Detail.AdditionalCopyPSGUID = Header.GUID) ',
								'INNER JOIN gr000 AS GR ON (GR.GUID = DETAIL.GroupGUID) ',
								'INNER JOIN POSSDRelatedAdditionalCopyPrintSetting000 AS RPS ON (RPS.AdditionalCopyPSGUID = HEADER.GUID) ',
								-- 'WHERE HEADER.PrintDesignGUID  = ''',@PDGuid,'''  AND HEADER.OperationType = ',@OperationType,' AND Header.GUID  !=  ''',@AdditionalCopyPSGUID,'''  AND RPS.StationGUID = ''',@StationGuid,'''',
								'WHERE HEADER.OperationType = ',@OperationType,' AND Header.GUID  !=  ''',@AdditionalCopyPSGUID,'''  AND RPS.StationGUID = ''',@StationGuid,'''',
								'AND DETAIL.GroupGUID IN (',@GRGuidList,');');	
	EXEC (@sqlCommand);
 END
#################################################################
#END
