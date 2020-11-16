#########################################################################
CREATE VIEW vwMatTargets AS
SELECT
MatTargets.[GUID]		[GUID],
MatTargets.mtGuid		mtGuid,
mt.Code					MatCode,
mt.Name					MatName,
mt.LatinName			MatLatinName,
mt.Security				MatSec, 
MatTargets.stGuid		stGuid,
st.Code					StoreCode,
st.Name					StoreName,
st.LatinName			StoreLatinName,
st.Security				StoreSec,
MatTargets.bdpGuid		bdpGuid,
bdp.Code				PeriodCode,
bdp.Name				PeriodName,
bdp.LatinName			PeriodLatinName,
bdp.StartDate			PeriodStartDate,
bdp.EndDate				PeriodEndDate,
bdp.Security			PeriodSec,
MatTargets.TargetQuantity    TargetQty,
MatTargets.SalesPrice   SalesPrice,
MatTargets.TargetPrice  TargetPrice

FROM MatTargets000 AS MatTargets 
INNER JOIN vbst    AS st   ON st.Guid = MatTargets.stGuid 
INNER JOIN bdp000  AS bdp  ON bdp.Guid= MatTargets.bdpGuid
INNER JOIN vbmt    AS mt   ON mt.Guid = MatTargets.mtGuid 
#########################################################################
#END