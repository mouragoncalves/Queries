DECLARE @MainEntityCode VARCHAR(20), @EntityCode VARCHAR(20), @Year INT = 2025, @Month INT = 10;

-- SET @MainEntityCode = '1222';
SET @EntityCode = '5125';

WITH WorkerCreditData AS (
    SELECT
        w.Id WorkerCreditId, w.MainEntityCode, RIGHT('00000000000000' + w.NumeroInscricaoEstabelecimento, 14) CnpjCno, w.[Year] RelatedYear, w.[Month] RelatedMonth, w.Competencia, 
        w.Matricula BusinessKey, RIGHT('00000000000' + w.Cpf, 11) Cpf, w.NomeTrabalhador, w.Rubrica,
        FORMAT(w.IfConcessoraCodigo, '000') Financeira, w.Contrato, w.ValorParcela
    FROM WorkerCredit w
    WHERE w.[Year] = @Year
        AND w.[Month] = @Month
        AND CASE WHEN LEN(@MainEntityCode) > 0 THEN w.MainEntityCode ELSE 1 END = CASE WHEN LEN(@MainEntityCode) > 0 THEN @MainEntityCode ELSE 1 END
), EntityCodeByOriginLegalDocument AS (
    SELECT EntityCode, CnpjCno FROM (
        SELECT DISTINCT
            e.EntityCode, RIGHT('00000000000000' + e.BusinessKey, 14) CnpjCno, ROW_NUMBER() OVER (PARTITION BY e.BusinessKey ORDER BY ClientReceivedDate DESC) [Number]
        FROM Event e
        WHERE e.EventTypeEnum = 1 
            AND e.EventStatusEnum = 6 
        ) V
    WHERE Number = 1
), WorkerCreditByEntityCode AS (
    SELECT * FROM (
        SELECT 
            w.WorkerCreditId, w.MainEntityCode, e.EntityCode, w.CnpjCno, w.RelatedYear, w.RelatedMonth, w.Competencia, w.BusinessKey, w.Cpf, w.NomeTrabalhador, w.Rubrica,
            w.Financeira, w.Contrato, w.ValorParcela
        FROM WorkerCreditData w
        JOIN EntityCodeByOriginLegalDocument e ON e.CnpjCno = w.CnpjCno
    ) V
    WHERE CASE 
        WHEN LEN(@EntityCode) > 0 THEN 
            CASE WHEN EntityCode = @EntityCode OR EntityCode IS NULL THEN 1 ELSE 0 END
        ELSE 1 
    END = 1
), S2299 AS (
    SELECT 
        e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey
    FROM Event e
    WHERE e.EventTypeEnum = 25
        AND e.EventStatusEnum = 6
        AND e.EntityCode IN (SELECT DISTINCT EntityCode FROM WorkerCreditByEntityCode)
        -- AND e.BusinessKey IN (SELECT DISTINCT BusinessKey FROM WorkerCreditByEntityCode)
), S2299X AS (
    SELECT 
        e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey, CONVERT(XML, c.Content) ContentXML
    FROM Event e
    INNER JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0 AND CHARINDEX('<descFolha>', c.Content) > 0
    WHERE e.EventTypeEnum = 25
        AND e.RelatedYear = @Year
        AND e.RelatedMonth = @Month
        AND e.EventStatusEnum = 6
        AND e.EntityCode IN (SELECT DISTINCT EntityCode FROM WorkerCreditByEntityCode)
        -- AND e.BusinessKey IN (SELECT DISTINCT BusinessKey FROM WorkerCreditByEntityCode)
), S1200 AS (
    SELECT 
        e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey, CONVERT(XML, c.Content) ContentXML
    FROM Event e
    INNER JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0 AND CHARINDEX('<descFolha>', c.Content) > 0
    WHERE e.EventTypeEnum = 8
        AND e.RelatedYear = @Year
        AND e.RelatedMonth = @Month
        AND e.EventStatusEnum <= 7
        AND e.EntityCode IN (SELECT DISTINCT EntityCode FROM WorkerCreditByEntityCode)
        -- AND e.BusinessKey IN (SELECT DISTINCT BusinessKey FROM WorkerCreditByEntityCode)
), EventXmlsDataS1200 AS (
    SELECT
        EventId,
        RelatedYear,
        RelatedMonth,
        EntityCode,
        t.n.value('(/eSocial/evtRemun/ideTrabalhador/cpfTrab)[1]', 'varchar(11)') Cpf,
        t.n.value('(../../matricula)[1]', 'varchar(50)') BusinessKey,
        t.n.value('(../../../nrInsc)[1]', 'varchar(14)') CnpjCno,
        t.n.value('(../codRubr)[1]', 'varchar(10)') Rubrica,
        t.n.value('(../vrRubr)[1]', 'decimal(15,2)') ValorParcela,
        t.n.value('(instFinanc)[1]', 'varchar(10)') Financeira,
        t.n.value('(nrDoc)[1]', 'varchar(50)') Contrato,
        t.n.value('(observacao)[1]', 'varchar(255)') Observacao
    FROM S1200
    CROSS APPLY ContentXML.nodes('/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun[descFolha]/descFolha') AS t(n)
), EventXmlsDataS2299 AS (
    SELECT
        EventId,
        RelatedYear,
        RelatedMonth,
        EntityCode,
        t.n.value('(../../../../../../ideVinculo/cpfTrab)[1]', 'varchar(11)') AS Cpf,
        t.n.value('(../../../../../../ideVinculo/matricula)[1]', 'varchar(50)') AS BusinessKey,
        t.n.value('(../nrInsc)[1]', 'varchar(14)') AS CnpjCno,
        t.n.value('(codRubr)[1]', 'varchar(10)') AS Rubrica,
        t.n.value('(vrRubr)[1]', 'decimal(15,2)') AS ValorParcela,
        t.n.value('(descFolha/instFinanc)[1]', 'varchar(10)') AS Financeira,
        t.n.value('(descFolha/nrDoc)[1]', 'varchar(50)') AS Contrato,
        '' Observacao
    FROM S2299X
    CROSS APPLY ContentXML.nodes('/eSocial/evtDeslig/infoDeslig/verbasResc/dmDev/infoPerApur/ideEstabLot/detVerbas') AS t(n)
    WHERE t.n.value('(codRubr)[1]', 'varchar(10)') IN ('16965', '16966', '16967', '16968', '16969', '16975', '16976', '16977', '16978')
), WorkerCreditByEntityCodeS2299 AS (
    SELECT 
        w.WorkerCreditId, w.MainEntityCode, W.EntityCode, w.CnpjCno, w.RelatedYear, w.RelatedMonth, w.Competencia, w.BusinessKey, w.Cpf, w.NomeTrabalhador, w.Rubrica, w.Financeira, w.Contrato, w.ValorParcela, 
        CASE 
            WHEN s.EventId IS NULL THEN NULL
            WHEN CAST(CONCAT(CAST(s.RelatedMonth AS INT), CAST(s.RelatedYear AS INT)) AS INT) >= CAST(CONCAT(CAST(w.RelatedMonth AS INT), CAST(w.RelatedYear AS INT)) AS INT) THEN NULL
            ELSE CONCAT('Inativo desde: ', RIGHT('00' + CAST(s.RelatedMonth AS VARCHAR(2)), 2), '/', s.RelatedYear) 
        END Desligamento 
    FROM WorkerCreditByEntityCode w
    LEFT JOIN S2299 s ON s.BusinessKey = w.BusinessKey
), EventsData AS (
    SELECT * FROM EventXmlsDataS1200
    UNION ALL 
    SELECT * FROM EventXmlsDataS2299
)

-- SELECT distinct EntityCode FROM WorkerCreditByEntityCode

-- DELETE FROM WorkerCredit WHERE Competencia = '10/2025' AND Matricula = 'HAB10062021R151441'

SELECT 
    e.EventId, w.MainEntityCode, ISNULL(w.EntityCode, e.EntityCode) EntityCode, 
    IIF(e.RelatedYear IS NULL, w.RelatedYear, e.RelatedYear) RelatedYear, 
    IIF(e.RelatedMonth IS NULL, w.RelatedMonth, e.RelatedMonth) RelatedMonth, 
    w.NomeTrabalhador,
    IIF(e.CPF IS NULL, w.Cpf, E.CPF) EmployeeDocument, 
    IIF(e.BusinessKey IS NULL, w.BusinessKey, E.BusinessKey) BusinessKey, 
    e.Rubrica,
    w.Financeira A_Financeira, w.Contrato A_Contrato, w.ValorParcela A_Parcela,
    e.Financeira E_Financeira, e.Contrato E_Contrato, e.ValorParcela E_Parcela,
    (e.ValorParcela - w.ValorParcela) DiferencaValor,
    CASE 
        WHEN e.EventId IS NULL THEN
            CASE 
                WHEN LEN(w.[Desligamento]) > 0 THEN w.Desligamento
                ELSE 'Sem informação do APS'
            END
        WHEN w.Financeira = e.Financeira 
            AND w.Contrato = e.Contrato 
            AND ABS(w.ValorParcela - e.ValorParcela) <= 0.01 THEN 'OK'
        WHEN w.Financeira = e.Financeira 
            AND w.Contrato = e.Contrato 
            AND w.ValorParcela > e.ValorParcela THEN 'OK com diferença de valor'
        WHEN w.Financeira = e.Financeira 
            AND w.Contrato = e.Contrato 
            AND w.ValorParcela < e.ValorParcela THEN 'Erro no valor parcela'
        ELSE 
            -- CASE
            --     WHEN (w.Financeira IS NULL OR w.Contrato IS NULL OR w.ValorParcela IS NULL) THEN
            --         'Consignado sem (' + 
            --         STUFF((
            --             SELECT ', ' + campo
            --             FROM (
            --                 SELECT 'financeira' AS campo WHERE w.Financeira IS NULL
            --                 UNION ALL
            --                 SELECT 'contrato' WHERE w.Contrato IS NULL
            --                 UNION ALL
            --                 SELECT 'valor' WHERE w.ValorParcela IS NULL
            --             ) t
            --             FOR XML PATH('')
            --         ), 1, 2, '') + ')'
                
            --     WHEN (e.Financeira IS NULL OR e.Contrato IS NULL OR e.ValorParcela IS NULL) THEN
            --         'eSocial sem (' + 
            --         STUFF((
            --             SELECT ', ' + campo
            --             FROM (
            --                 SELECT 'financeira' AS campo WHERE e.Financeira IS NULL
            --                 UNION ALL
            --                 SELECT 'contrato' WHERE e.Contrato IS NULL
            --                 UNION ALL
            --                 SELECT 'valor' WHERE e.ValorParcela IS NULL
            --             ) t
            --             FOR XML PATH('')
            --         ), 1, 2, '') + ')'
                
            --     ELSE
            'Dados Divergente'
            -- 'Divergente (' + 
            -- STUFF((
            --     SELECT ', ' + campo
            --     FROM (
            --         SELECT 'financeira' AS campo WHERE w.Financeira != e.Financeira
            --         UNION ALL
            --         SELECT 'contrato' WHERE w.Contrato != e.Contrato
            --         UNION ALL
            --         SELECT 'valor' WHERE ABS(w.ValorParcela - e.ValorParcela) > 0.01
            --     ) t
            --     FOR XML PATH('')
            -- ), 1, 2, '') + ')'
            -- END
    END AS [Status]
FROM EventsData e
FULL OUTER JOIN WorkerCreditByEntityCodeS2299 w ON w.BusinessKey = e.BusinessKey AND w.Contrato = e.Contrato
ORDER BY EmployeeDocument



-- SELECT * 
-- FROM Event e 
-- JOIN XMLContent c ON c.ReferenceId = e.Id
-- WHERE e.RelatedYear = 2025 AND e.RelatedMonth = 10 AND e.EventTypeEnum = 8 AND e.BusinessKey = 'AMT_Educ06032024R373845' AND e.EventStatusEnum = 6

------------------------



-- WITH WorkerCreditsData AS (
--     SELECT
--         w.Id WorkerCreditId, w.MainEntityCode, RIGHT('00000000000000' + w.NumeroInscricaoEstabelecimento, 14) CnpjCno, w.[Year] RelatedYear, w.[Month] RelatedMonth, w.Competencia, 
--         w.Matricula BusinessKey, RIGHT('00000000000' + w.Cpf, 11) Cpf, w.NomeTrabalhador, w.Rubrica,
--         FORMAT(w.IfConcessoraCodigo, '000') Financeira, w.Contrato, w.ValorParcela
--     FROM WorkerCredit w
--     WHERE w.[Year] = @Year
--         AND w.[Month] = @Month
--         AND CASE WHEN LEN(@MainEntityCode) > 0 THEN w.MainEntityCode ELSE 1 END = CASE WHEN LEN(@MainEntityCode) > 0 THEN @MainEntityCode ELSE 1 END
-- ), EntityCodeByOriginLegalDocument AS (
--     SELECT EntityCode, CnpjCno FROM (
--         SELECT DISTINCT
--             e.EntityCode, RIGHT('00000000000000' + e.BusinessKey, 14) CnpjCno, ROW_NUMBER() OVER (PARTITION BY e.BusinessKey ORDER BY ClientReceivedDate DESC) [Number]
--         FROM Event e
--         WHERE e.EventTypeEnum = 1 
--             AND e.EventStatusEnum = 6 
--         ) V
--     WHERE Number = 1
-- ), WorkerCreditByEntityCode AS (
--     SELECT * FROM (
--         SELECT 
--             w.WorkerCreditId, w.MainEntityCode, e.EntityCode, w.CnpjCno, w.RelatedYear, w.RelatedMonth, w.Competencia, w.BusinessKey, w.Cpf, w.NomeTrabalhador, w.Rubrica,
--             w.Financeira, w.Contrato, w.ValorParcela
--         FROM WorkerCreditData w
--         JOIN EntityCodeByOriginLegalDocument e ON e.CnpjCno = w.CnpjCno
--     ) V
--     WHERE CASE 
--         WHEN LEN(@EntityCode) > 0 THEN 
--             CASE WHEN EntityCode = @EntityCode OR EntityCode IS NULL THEN 1 ELSE 0 END
--         ELSE 1 
--     END = 1
-- ), EventsDataS2299 AS (
--         SELECT e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey, CONVERT(XML, c.Content) ContentXML
--         FROM Event e
--             INNER JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0 AND CHARINDEX('<consigFGTS>', c.Content) > 0
--         WHERE e.EventTypeEnum = 25
--             AND e.EntityCode IN (SELECT CAST(value AS varchar) FROM STRING_SPLIT(@entityCodeList, ','))
--             AND e.RelatedYear > = 2025
--             AND e.RelatedMonth >= 6
--             AND e.EventStatusEnum IN (0, 6, 7)
--     ), EventXmlsDataS2299 AS (
--         SELECT
--             EventId,
--             RelatedYear,
--             RelatedMonth,
--             EntityCode,
--             t.n.value('(../../../../../../ideVinculo/cpfTrab)[1]', 'varchar(11)') AS CPF,
--             t.n.value('(../../../../../../ideVinculo/matricula)[1]', 'varchar(50)') AS Matricula,
--             t.n.value('(../nrInsc)[1]', 'varchar(14)') AS Estabelecimento,
--             t.n.value('(codRubr)[1]', 'varchar(10)') AS Rubrica,
--             t.n.value('(vrRubr)[1]', 'decimal(15,2)') AS ValorRubrica,
--             t.n.value('(descFolha/instFinanc)[1]', 'varchar(10)') AS Financeira,
--             t.n.value('(descFolha/nrDoc)[1]', 'varchar(50)') AS Contrato
--         FROM EventsDataS2299
--         CROSS APPLY ContentXML.nodes('/eSocial/evtDeslig/infoDeslig/verbasResc/dmDev/infoPerApur/ideEstabLot/detVerbas') AS t(n)
--         WHERE t.n.value('(codRubr)[1]', 'varchar(10)') IN ('16965', '16966', '16967', '16968', '16969', '16975', '16976', '16977', '16978')
--     ), EventsDataS5003 AS (
--     SELECT e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey, CONVERT(XML, c.Content) ContentXML
--     FROM Event e
--         INNER JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0 AND CHARINDEX('<eConsignado>', c.Content) > 0
--     WHERE e.EventTypeEnum = 47
--         AND e.EntityCode IN (SELECT CAST(value AS varchar) FROM STRING_SPLIT(@entityCodeList, ','))
--         AND e.BusinessKey IN (SELECT DISTINCT Matricula FROM WorkerCreditsData)
--         AND e.RelatedYear = @RelatedYear
--         AND e.RelatedMonth = @RelatedMonth
--         AND e.EventStatusEnum = 6
-- ), EventXmlsDataS5003 AS (
--     SELECT
--         EventId,
--         RelatedYear,
--         RelatedMonth,
--         EntityCode,
--         t.n.value('(/*:eSocial/*:evtBasesFGTS/*:ideTrabalhador/*:cpfTrab)[1]', 'varchar(11)') AS CPF,
--         t.n.value('(../*:matricula)[1]', 'varchar(50)') AS Matricula,
--         t.n.value('(../../../*:nrInsc)[1]', 'varchar(14)') AS Estabelecimento,
--         '' AS Rubrica,
--         t.n.value('(*:vreConsignado)[1]', 'decimal(15,2)') AS ValorRubrica,
--         t.n.value('(*:instFinanc)[1]', 'varchar(10)') AS Financeira,
--         t.n.value('(*:nrContrato)[1]', 'varchar(50)') AS Contrato,
--         '' AS Observacao
--     FROM EventsDataS5003
--     CROSS APPLY ContentXML.nodes('/*:eSocial/*:evtBasesFGTS/*:infoFGTS/*:ideEstab/*:ideLotacao/*:infoTrabFGTS/*:eConsignado') AS t(n)
-- ),  EventXmlsData AS (
--     SELECT EventId, RelatedYear, RelatedMonth, EntityCode, CPF, Matricula, Estabelecimento, Rubrica, ValorRubrica, Financeira, Contrato, Observacao
--     FROM EventXmlsDataS5003
--     UNION ALL 
--     SELECT EventId, RelatedYear, RelatedMonth, EntityCode, CPF, Matricula, Estabelecimento, Rubrica, ValorRubrica, Financeira, Contrato, NULL AS Observacao
--     FROM EventXmlsDataS2299
-- )

-- SELECT 
--     e.EventId, w.MainEntityCode, e.EntityCode, 
--     IIF(e.RelatedYear IS NULL, w.Year, e.RelatedYear) RelatedYear, 
--     IIF(e.RelatedMonth IS NULL, w.Month, e.RelatedMonth) RelatedMonth, 
--     w.NomeTrabalhador,
--     IIF(e.CPF IS NULL, w.Cpf, E.CPF) EmployeeDocument, 
--     IIF(e.Matricula IS NULL, w.Matricula, E.Matricula) BusinessKey, 
--     e.Rubrica,
--     w.Financeira C_Financeira, w.Contrato C_Contrato, w.ValorParcela C_Parcela,
--     e.Financeira E_Financeira, e.Contrato E_Contrato, e.ValorRubrica E_Parcela,
--     CASE 
--         WHEN e.RelatedMonth < @RelatedMonth OR e.RelatedYear < @RelatedYear  THEN CONCAT('Inativo desde: ', e.RelatedMonth, '/', e.RelatedYear)
--         WHEN w.Financeira = e.Financeira THEN 'OK'
--         WHEN w.Financeira IS NULL THEN 'Consignado sem financeira'
--         WHEN e.Financeira IS NULL THEN 'eSocial sem financeira'
--         ELSE 'DIVERGENTE'
--     END ValidaFinanceira_Status,
--     CASE 
--         WHEN e.RelatedMonth < @RelatedMonth OR e.RelatedYear < @RelatedYear  THEN CONCAT('Inativo desde: ', e.RelatedMonth, '/', e.RelatedYear)
--         WHEN w.Contrato = e.Contrato THEN 'OK'
--         WHEN w.Contrato IS NULL THEN 'Consignado sem contrato'
--         WHEN e.Contrato IS NULL THEN 'eSocial sem contrato'
--         ELSE 'DIVERGENTE'
--     END ValidaContrato_Status,
--     CASE 
--         WHEN e.RelatedMonth < @RelatedMonth OR e.RelatedYear < @RelatedYear  THEN CONCAT('Inativo desde: ', e.RelatedMonth, '/', e.RelatedYear)
--         WHEN ABS(w.ValorParcela - e.ValorRubrica) <= 0.01 THEN 'OK'
--         WHEN w.ValorParcela IS NULL THEN 'Consignado sem valor'
--         WHEN e.ValorRubrica IS NULL THEN 'eSocial sem valor'
--         WHEN w.ValorParcela > e.ValorRubrica THEN 'Valor maior no consignado'
--         WHEN w.ValorParcela < e.ValorRubrica THEN 'Valor maior no eSocial'
--         ELSE 'DIVERGENTE'
--     END ValidaParcela_Status,
--     (e.ValorRubrica - w.ValorParcela) DiferencaValor,
--     e.Observacao
-- FROM EventXmlsData e
-- FULL OUTER JOIN WorkerCreditsData w ON w.Matricula = e.Matricula AND w.Contrato = e.Contrato