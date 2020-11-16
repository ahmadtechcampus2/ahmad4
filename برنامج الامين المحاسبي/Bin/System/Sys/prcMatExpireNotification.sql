##########################################################
CREATE PROCEDURE prcMatExpireNotification
AS    
	SET NOCOUNT ON  
	BEGIN
		DECLARE @NotificationPeriod [INT]= 15
		SET @NotificationPeriod = (SELECT CAST(value AS INT) FROM op000 WHERE Name = 'AmnCfg_NotificationPeriod' and [dbo].[fnGetCurrentUserGuid]() = userguid)
		IF (ISNULL(@NotificationPeriod,0X00)=0X00) 
			SET  @NotificationPeriod= 15

		IF EXISTS(SELECT DATEDIFF(day, GETDATE(), biExpireDate) AS expireperiod 
				  FROM [fnExtended_Bi_Fixed](0X0) BI 
				  INNER JOIN MS000 MS ON MS.MatGUID = BI.biMatPtr
				  WHERE biExpireDate <> '1/1/1980' AND MS.Qty > 0 AND (DATEDIFF(day, GETDATE(), biExpireDate) <= @NotificationPeriod))
			SELECT 1
	END
/*
prcConnections_add2 'ãÏíÑ' 
*/
##################################################### 