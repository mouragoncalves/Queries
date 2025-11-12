-- exec sp_GetINSSMainEntityClosing
--     @entityCode = '9111',
--     @year = 2025,
--     @month = 10

DROP TABLE IF EXISTS #TmpXml		

SELECT
    convert(xml,c.Content) as ContentXML, ev.EntityCode
INTO #TmpXml
FROM Event ev		
INNER JOIN xmlContent c	WITH (NOLOCK) ON ev.Id = c.ReferenceId
WHERE c.ContentReferenceEnum = 0 
    -- AND ev.entitycode = @entityCode
    AND ev.EventStatusEnum = 6
    AND ev.relatedyear = 2025
    AND (9 is null or ev.relatedmonth = 9)
    AND ev.eventtypeenum = 43;

DROP TABLE IF EXISTS #TmpXmlFamMat		

SELECT
    convert(xml,c.Content) as ContentXML, ev.EntityCode
INTO #TmpXmlFamMat
FROM Event ev		
INNER JOIN xmlContent c WITH (NOLOCK) ON ev.Id = c.ReferenceId
WHERE c.ContentReferenceEnum = 0
    -- AND ev.entitycode = @entityCode
    AND ev.EventStatusEnum = 6
    AND ev.relatedyear = 2025
    AND (9 is null or ev.relatedmonth = 9)
    AND ev.eventtypeenum = 43

-- SELECT
--     basesCp.B.value('(*:vrSalFam)[1]', 'VARCHAR(14)') as vrSalFam,
--     basesCp.B.value('(*:vrSalMat)[1]', 'VARCHAR(14)') as vrSalMat,
--     basesCp.B.value('(../../../../../*:ideEvento/*:indApuracao)[1]', 'VARCHAR(2)') as indApuracao,
--     EntityCode
-- FROM #TmpXmlFamMat sq
-- OUTER APPLY sq.ContentXML.nodes('/*:eSocial/*:evtCS/*:infoCS/*:ideEstab/*:ideLotacao/*:basesRemun/*:basesCp') as basesCp(B)

-- SELECT
--     distinct infoCR.C.value('(*:vrCR)[1]', 'VARCHAR(14)') as vrCR,
--     infoCR.C.value('(*:vrCRSusp)[1]', 'VARCHAR(14)') as vrCRSusp,
--     infoCR.C.value('(*:tpCR)[1]', 'VARCHAR(6)') as tpCR,
--     infoCR.C.value('(../../*:ideEvento/*:indApuracao)[1]', 'VARCHAR(2)') as indApuracao,
--     EntityCode
-- FROM #TmpXML sq
-- OUTER APPLY sq.ContentXML.nodes('/*:eSocial/*:evtCS/*:infoCS/*:infoCRContrib') as infoCR(C) 

DROP TABLE IF EXISTS #Resultado1
DROP TABLE IF EXISTS #Resultado2

SELECT
    NULL AS vrCR,
    NULL AS vrCRSusp,
    NULL AS tpCR,
    basesCp.B.value('(../../../../../*:ideEvento/*:indApuracao)[1]', 'VARCHAR(2)') AS indApuracao,
    sq.EntityCode,
    basesCp.B.value('(*:vrSalFam)[1]', 'VARCHAR(14)') AS vrSalFam,
    basesCp.B.value('(*:vrSalMat)[1]', 'VARCHAR(14)') AS vrSalMat
INTO #Resultado1
FROM #TmpXmlFamMat sq
OUTER APPLY sq.ContentXML.nodes('/*:eSocial/*:evtCS/*:infoCS/*:ideEstab/*:ideLotacao/*:basesRemun/*:basesCp') AS basesCp(B);

SELECT
    distinct infoCR.C.value('(*:vrCR)[1]', 'VARCHAR(14)') AS vrCR,
    infoCR.C.value('(*:vrCRSusp)[1]', 'VARCHAR(14)') AS vrCRSusp,
    infoCR.C.value('(*:tpCR)[1]', 'VARCHAR(6)') AS tpCR,
    infoCR.C.value('(../../*:ideEvento/*:indApuracao)[1]', 'VARCHAR(2)') AS indApuracao,
    sq.EntityCode,
    NULL AS vrSalFam,
    NULL AS vrSalMat
INTO #Resultado2
FROM #TmpXML sq
OUTER APPLY sq.ContentXML.nodes('/*:eSocial/*:evtCS/*:infoCS/*:infoCRContrib') AS infoCR(C);

WITH Base AS (
    SELECT
        CAST(NULLIF(vrCR, '') AS DECIMAL(18,2)) AS vrCR,
        CAST(NULLIF(vrCRSusp, '') AS DECIMAL(18,2)) AS vrCRSusp,
        tpCR,
        CAST(NULLIF(vrSalFam, '') AS DECIMAL(18,2)) AS vrSalFam,
        CAST(NULLIF(vrSalMat, '') AS DECIMAL(18,2)) AS vrSalMat,
        indApuracao,
        EntityCode
    FROM #Resultado1

    UNION ALL

    SELECT
        CAST(NULLIF(vrCR, '') AS DECIMAL(18,2)),
        CAST(NULLIF(vrCRSusp, '') AS DECIMAL(18,2)),
        tpCR,
        CAST(NULLIF(vrSalFam, '') AS DECIMAL(18,2)),
        CAST(NULLIF(vrSalMat, '') AS DECIMAL(18,2)),
        indApuracao,
        EntityCode
    FROM #Resultado2
)
SELECT 
    EntityCode,
    SUM(ISNULL(vrCR, 0)) + SUM(ISNULL(vrCRSusp, 0)) AS Valor,
    SUM(ISNULL(vrSalFam, 0)) + SUM(ISNULL(vrSalMat, 0)) AS FamiliaMaternidade
FROM Base
GROUP BY EntityCode;