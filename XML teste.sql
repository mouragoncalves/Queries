SELECT 
    e.Id,
    e.EntityCode,
    e.BusinessKey,
    c.Content
FROM Event e
JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0
WHERE 
    TRY_CAST(c.Content AS XML).exist('/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/*[count(descFolha) > 1]') = 1
    AND e.EventTypeEnum = 8
    AND e.RelatedYear = 2025
    AND e.RelatedMonth = 11
    AND e.EventStatusEnum = 7;

SELECT 
    e.Id,
    e.BusinessKey,
    c.Content
FROM Event e
JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0
CROSS APPLY (
    SELECT TRY_CAST(c.Content AS XML) AS XmlData
) AS X
WHERE 
    X.XmlData.exist('/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun[count(descFolha) > 1]') = 1
    AND e.EventTypeEnum = 8
    AND e.RelatedYear = 2025
    AND e.RelatedMonth = 11
    AND e.EventStatusEnum = 7;