#########################################################
CREATE FUNCTION fnEntryItem_GetPaidState
(
    @enGUID UNIQUEIDENTIFIER
)
RETURNS  @PaidState TABLE (FLdPaidState INT)
AS
BEGIN
    DECLARE @bpGuid UNIQUEIDENTIFIER
	DECLARE @acCurGuid UNIQUEIDENTIFIER
	DECLARE @enCurGuid UNIQUEIDENTIFIER
	DECLARE @SumPaid FLOAT
	DECLARE @enCurVal FLOAT
	DECLARE @enValue FLOAT
	DECLARE @Val FLOAT  
	SELECT @bpGuid =  bp.GUID FROM bp000 bp, en000 en WHERE @enGUID IN (bp.DebtGUID , bp.PayGUID) AND en.GUID = @enGUID 
	SELECT @acCurGuid= ac.CurrencyGUID  from ac000 ac , en000 en WHERE ac.GUID=en.AccountGUID and en.GUID = @enGUID 
	SELECT @enCurGuid=en.CurrencyGUID ,@enValue =case Debit when 0 then Credit else Debit end ,@enCurVal = en.CurrencyVal FROM en000 en WHERE  en.GUID = @enGUID
	SELECT @Val = ([dbo].[fnCurrency_fix]( @enValue, @enCurGuid, @enCurVal, @acCurGuid, DEFAULT) )
	SELECT @SumPaid= dbo.fnBP_GetFixedSumPays (@enGUID, DEFAULT) 
    IF(@bpGuid != 0x0 )
	BEGIN
	  IF (@SumPaid = @Val)
	   INSERT INTO @PaidState SELECT 3
      IF (@SumPaid < @Val)
	  INSERT INTO @PaidState SELECT 2
	END
    ELSE
	  INSERT INTO @PaidState SELECT 1
	RETURN;
END
#########################################################
CREATE VIEW vwEntryItems_PaidState
AS
SELECT
	en.*,
    f.FLdPaidState AS PaidState
FROM vwEntryItems AS [en]
	OUTER APPLY dbo.fnEntryItem_GetPaidState (en.GUID)  f
##########################################################
#END