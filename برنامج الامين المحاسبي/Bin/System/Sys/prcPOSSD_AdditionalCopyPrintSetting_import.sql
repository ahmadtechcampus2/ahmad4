################################################################################
CREATE PROCEDURE prcPOSSDAdditionalCopyPrintSetting_import
	@DestinationStationGUID UNIQUEIDENTIFIER,	
	@SourceStationGuidList NVARCHAR(MAX)
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSDAdditionalCopyPrintSetting_IsGroupExist
	Purpose: check if specified groups exist in POS additional copy print settings that belong to a specific print design and operation type
	How to Call: EXEC prcPOSSDAdditionalCopyPrintSetting_import 'CC008441-C78E-47DC-86B7-F8DDBD4D3330',1,'''B1B2001E-650D-4BA0-A4C6-47035D89467C'',''5843420E-ED82-4CAA-AD3E-AAEBFF0672AF'''

	Create By: Hanadi Salka													Created On: 15 March 2018
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	DECLARE @maxNumber INT
	DECLARE @ProcessGuid UNIQUEIDENTIFIER
	DECLARE @sqlCommand NVARCHAR(MAX);
	SET @ProcessGuid = NEWID();
	SET @maxNumber = (select MAX(Number) from POSSDAdditionalCopyPrintSettingHeader000 AS H INNER JOIN POSSDRelatedAdditionalCopyPrintSetting000 AS SR ON (SR.AdditionalCopyPSGUID = H.GUID) WHERE SR.StationGUID = @DestinationStationGUID );

	SET @sqlCommand = CONCAT('INSERT INTO POSSDAdditionalCopyPrintSettingHeader000 ',
		'(',
		   'OriginalGUID,',
		  'PrintDesignGUID,',
		  'Number,',
		  'Name,',
		  'LatinName,',
		  'OperationType,',
		  'LanguageType,   ', 
		  'ProcessThreadGuid ',
		') ',
		'SELECT ',
		   'H.[GUID]',
		  ',[PrintDesignGUID]',		  
		  ',',@maxNumber,' + ROW_NUMBER() OVER(ORDER BY H.[Number] ASC) AS Number ',
		  ',max([Name])',
		  ',max([LatinName])',
		  ',max([OperationType])',
		  ',max([LanguageType])',	
		  ',''',@ProcessGuid,''' ',  
		'FROM POSSDAdditionalCopyPrintSettingHeader000 AS H ',
		'INNER JOIN POSSDRelatedAdditionalCopyPrintSetting000 AS SR ON (SR.AdditionalCopyPSGUID = H.GUID) ',
		'INNER JOIN POSSDAdditionalCopyPrintSettingDetail000 AS D ON (D.AdditionalCopyPSGUID = H.GUID) ',
		'INNER JOIN POSSDStationGroup000 AS G ON (G.GroupGUID = D.GroupGUID AND G.StationGUID = ''',@DestinationStationGUID,''') ',
		'WHERE   SR.StationGUID IN ( ',@SourceStationGuidList,') ', 		
		'GROUP BY H.[GUID], H.PrintDesignGUID, H.Number; ');
	EXEC (@sqlCommand);

	SET @sqlCommand = CONCAT('INSERT INTO POSSDAdditionalCopyPrintSettingDetail000 ',
			'( ',				
				'[AdditionalCopyPSGUID], ',
				'[GroupGUID], ',
				'[Number] ',
		    ')   ',
			'SELECT  ',				
				 'H.[GUID],',
				 'D.[GroupGUID],',
				 'D.[Number] ',
			  'FROM POSSDAdditionalCopyPrintSettingDetail000 AS D INNER JOIN POSSDAdditionalCopyPrintSettingHeader000 AS H  ON (D.AdditionalCopyPSGUID = H.OriginalGUID) ',
			  'INNER JOIN POSSDRelatedAdditionalCopyPrintSetting000 AS SR ON (SR.AdditionalCopyPSGUID = H.OriginalGUID) ',
			  'INNER JOIN POSSDStationGroup000 AS G ON (G.GroupGUID = D.GroupGUID AND G.StationGUID = ''',@DestinationStationGUID,''') ',
			  'WHERE  SR.StationGUID IN ( ',@SourceStationGuidList,') ');
   -- SELECT @sqlCommand;
	EXEC (@sqlCommand);


	INSERT INTO POSSDRelatedAdditionalCopyPrintSetting000
           ([GUID]
           ,[StationGUID]
           ,[AdditionalCopyPSGUID]
           ,[UsedByPOSPrinter])
	SELECT
           NEWID()
           ,@DestinationStationGUID
           ,H.[GUID]
           ,0
	FROM POSSDAdditionalCopyPrintSettingHeader000 AS H 
	WHERE H.ProcessThreadGuid = @ProcessGuid;
 END
#################################################################
#END