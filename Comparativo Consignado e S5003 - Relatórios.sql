DECLARE --@MainEntityCode VARCHAR(40) = '103122', 
@Year INT = 2025, @Month INT = 9;
--, @LegalEntityDocument VARCHAR(40);

-- SELECT top 1 @LegalEntityDocument = LegalEntityDocument
-- FROM Event
-- WHERE EntityCode = @MainEntityCode
--     AND EventTypeEnum = 1
--     AND EventStatusEnum = 6
-- ORDER BY ClientReceivedDate DESC;

WITH 
-- S1005 AS (
--     SELECT 
--         Id, ClientReceivedDate, EntityCode, BusinessKey, LegalEntityDocument, OriginLegalDocument,
--         ROW_NUMBER() OVER (PARTITION BY BusinessKey ORDER BY ClientReceivedDate DESC) [Number]
--     FROM Event 
--     WHERE LegalEntityDocument = @LegalEntityDocument 
--     AND EventTypeEnum = 1 AND EventStatusEnum = 6

WorkerCreditData AS (
    SELECT
        w.Id, w.MainEntityCode, w.Competencia, w.Matricula, RIGHT('00000000000' + w.Cpf, 11) Cpf, FORMAT(w.IfConcessoraCodigo, '000') Financeira, w.Contrato, w.ValorParcela, w.NumeroInscricaoEstabelecimento CnpjCno, w.NomeTrabalhador, w.[Year], w.[Month] 
    FROM WorkerCredit w
    WHERE w.[Year] = @Year 
        AND w.[Month] = @Month
), EntityCodeList AS (
    SELECT EntityCode, CnpjCno FROM (
        SELECT DISTINCT
            EntityCode, BusinessKey CnpjCno, ROW_NUMBER() OVER (PARTITION BY BusinessKey ORDER BY ClientReceivedDate DESC) [Number]
        FROM Event
        WHERE EventTypeEnum = 1 
            AND EventStatusEnum = 6 
            AND BusinessKey IN (SELECT CnpjCno FROM WorkerCreditData)) V
    WHERE Number = 1
) SELECT * FROM EntityCodeList

, BusinessKeyCpf AS (
    SELECT 
        w.Id, w.MainEntityCode, b.EntityCode, w.Competencia, w.Matricula, RIGHT('00000000000' + w.Cpf, 11) Cpf, FORMAT(w.IfConcessoraCodigo, '000') Financeira, w.Contrato, w.ValorParcela, w.NumeroInscricaoEstabelecimento CnpjCno, w.NomeTrabalhador, w.[Year], w.[Month] 
    FROM WorkerCredit w
    JOIN BusinessKeyCnpjCno b ON w.NumeroInscricaoEstabelecimento = RIGHT(b.CnpjCno, LEN(w.NumeroInscricaoEstabelecimento))
    WHERE w.[Year] = @Year 
        AND w.[Month] = @Month
        AND w.Cpf IN (SELECT DISTINCT Cpf FROM WorkerCreditData)
), BusinessKeyList AS (
    SELECT 
        distinct Matricula BusinessKey 
    FROM BusinessKeyCpf 
    WHERE [Year] = @Year 
        AND [Month] = @Month
-- ), S1200 AS (
--     SELECT e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey, CONVERT(XML, c.Content) ContentXML
--     FROM Event e
--         INNER JOIN WorkerCreditData w ON e.BusinessKey = w.Matricula
--         INNER JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0 AND CHARINDEX('<descFolha>', c.Content) > 0
--     WHERE e.EventTypeEnum = 8
--         AND e.RelatedYear = @Year
--         AND e.RelatedMonth = @Month
--         AND e.EventStatusEnum <= 7
-- ), EventXmlsDataS1200 AS (
    -- SELECT
    --     EventId,
    --     RelatedYear,
    --     RelatedMonth,
    --     EntityCode,
    --     t.n.value('(/eSocial/evtRemun/ideTrabalhador/cpfTrab)[1]', 'varchar(11)') CPF,
    --     t.n.value('(../../matricula)[1]', 'varchar(50)') Matricula,
    --     t.n.value('(../../../nrInsc)[1]', 'varchar(14)') Estabelecimento,
    --     t.n.value('(../codRubr)[1]', 'varchar(10)') Rubrica,
    --     t.n.value('(../vrRubr)[1]', 'decimal(15,2)') ValorRubrica,
    --     t.n.value('(instFinanc)[1]', 'varchar(10)') Financeira,
    --     t.n.value('(nrDoc)[1]', 'varchar(50)') Contrato,
    --     t.n.value('(observacao)[1]', 'varchar(255)') Observacao
    -- FROM S1200
    -- CROSS APPLY ContentXML.nodes('/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun[descFolha]/descFolha') AS t(n)
), S2299 AS (
    SELECT e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey
    FROM Event e
    -- INNER JOIN WorkerCreditData w ON e.BusinessKey = w.Matricula
    WHERE e.EventTypeEnum = 25
        AND e.EventStatusEnum = 6
        AND e.BusinessKey IN (SELECT BusinessKey FROM BusinessKeyList)
        -- AND e.RelatedYear <= @Year
        -- AND e.RelatedMonth < @Month
), S5003 AS (
    SELECT 
        e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey, CONVERT(XML, c.Content) ContentXML, 
        ROW_NUMBER() OVER (PARTITION BY BusinessKey ORDER BY ClientReceivedDate DESC) [Number]
    FROM Event e
    INNER JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0 --AND CHARINDEX('<eConsignado>', c.Content) > 0
    WHERE e.EventTypeEnum = 47
        AND e.EventStatusEnum = 6 
        AND e.RelatedYear = 2025 
        AND e.RelatedMonth = 9 
        -- AND e.BusinessKey = 'MMN_EDUC.25062024R860503'
    -- SELECT e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey, CONVERT(XML, c.Content) ContentXML
    -- --, ROW_NUMBER() OVER (PARTITION BY BusinessKey ORDER BY ClientReceivedDate DESC) [Number]
    -- FROM Event e
    --     --INNER JOIN WorkerCreditData w ON e.BusinessKey = w.Matricula
    -- INNER JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0 --AND CHARINDEX('<eConsignado>', c.Content) > 0
    -- WHERE e.EventTypeEnum = 47
    --     AND e.EventStatusEnum = 6
    --     AND e.RelatedYear = @Year
    --     AND e.RelatedMonth = @Month
), EventXmlsDataS5003 AS (
    SELECT
        EventId,
        RelatedYear,
        RelatedMonth,
        EntityCode,
        t.n.value('(../../../../../*[local-name()="ideTrabalhador"]/*[local-name()="cpfTrab"])[1]', 'varchar(11)') AS CPF,
        t.n.value('(../*[local-name()="matricula"])[1]', 'varchar(50)') AS Matricula,
        t.n.value('(../../../*[local-name()="nrInsc"])[1]', 'varchar(14)') AS Estabelecimento,
        '' AS Rubrica,
        t.n.value('(*[local-name()="vreConsignado"])[1]', 'decimal(15,2)') AS ValorRubrica,
        t.n.value('(*[local-name()="instFinanc"])[1]', 'varchar(10)') AS Financeira,
        t.n.value('(*[local-name()="nrContrato"])[1]', 'varchar(50)') AS Contrato
        -- '' AS Observacao
    FROM S5003
    CROSS APPLY ContentXML.nodes('/*[local-name()="eSocial"]/*[local-name()="evtBasesFGTS"]/*[local-name()="infoFGTS"]/*[local-name()="ideEstab"]/*[local-name()="ideLotacao"]/*[local-name()="infoTrabFGTS"]/*[local-name()="eConsignado"]') AS t(n)
    WHERE [Number] = 1
), Result AS (
    SELECT 
        e.EventId, w.MainEntityCode, w.EntityCode, 
        IIF(e.RelatedYear IS NULL, w.Year, e.RelatedYear) RelatedYear, 
        IIF(e.RelatedMonth IS NULL, w.Month, e.RelatedMonth) RelatedMonth, 
        w.NomeTrabalhador,
        IIF(e.CPF IS NULL, w.Cpf, E.CPF) EmployeeDocument, 
        IIF(e.Matricula IS NULL, w.Matricula, E.Matricula) BusinessKey, 
        e.Rubrica,
        w.Financeira C_Financeira, w.Contrato C_Contrato, w.ValorParcela C_Parcela,
        e.Financeira E_Financeira, e.Contrato E_Contrato, e.ValorRubrica E_Parcela,
        CASE 
            WHEN w.Financeira = e.Financeira THEN 'OK'
            WHEN w.Financeira IS NULL THEN 'Consignado sem financeira'
            WHEN e.Financeira IS NULL THEN 'eSocial sem financeira'
            ELSE 'DIVERGENTE'
        END ValidaFinanceira_Status,
        CASE 
            WHEN w.Contrato = e.Contrato THEN 'OK'
            WHEN w.Contrato IS NULL THEN 'Consignado sem contrato'
            WHEN e.Contrato IS NULL THEN 'eSocial sem contrato'
            ELSE 'DIVERGENTE'
        END ValidaContrato_Status,
        CASE 
            WHEN ABS(w.ValorParcela - e.ValorRubrica) <= 0.01 THEN 'OK'
            WHEN w.ValorParcela IS NULL THEN 'Consignado sem valor'
            WHEN e.ValorRubrica IS NULL THEN 'eSocial sem valor'
            WHEN w.ValorParcela > e.ValorRubrica THEN 'Valor maior no consignado'
            WHEN w.ValorParcela < e.ValorRubrica THEN 'Valor maior no eSocial'
            ELSE 'DIVERGENTE'
        END ValidaParcela_Status,
        (e.ValorRubrica - w.ValorParcela) DiferencaValor
    FROM EventXmlsDataS5003 e
    FULL OUTER JOIN BusinessKeyCpf w ON w.Matricula = e.Matricula AND w.Contrato = e.Contrato
) --SELECT * FROM S1005
SELECT 
    r.*,
    CASE 
        WHEN r.C_Financeira = r.E_Financeira AND r.C_Contrato = r.E_Contrato AND r.C_Parcela = r.E_Parcela THEN 'OK'
        WHEN r.C_Financeira = r.E_Financeira AND r.C_Contrato = r.E_Contrato AND r.C_Parcela > r.E_Parcela THEN 'OK com diferença de valor'
        WHEN r.C_Financeira = r.E_Financeira AND r.C_Contrato = r.E_Contrato AND r.C_Parcela < r.E_Parcela THEN 'Erro no valor parcela'
        WHEN r.EventId IS NULL THEN
            CASE 
                WHEN s.EventId IS NULL THEN 'Sem informação do APS'
                WHEN CONCAT(r.RelatedYear, RIGHT('00' + CAST(r.RelatedMonth AS VARCHAR(2)), 2)) > 
                     CONCAT(s.RelatedYear, RIGHT('00' + CAST(s.RelatedMonth AS VARCHAR(2)), 2))
                    THEN CONCAT('Inativo desde: ', RIGHT('00' + CAST(s.RelatedMonth AS VARCHAR(2)), 2), '/', s.RelatedYear)
                ELSE 'Evento inexistente'
            END
        ELSE 'Divergente ABM'
    END AS Validacao
FROM Result r
LEFT JOIN S2299 s 
    ON s.BusinessKey = r.BusinessKey
ORDER BY r.MainEntityCode, r.EntityCode, r.BusinessKey;

-- SELECT *
-- FROM Event e
-- JOIN XMLContent c ON c.ReferenceId = e.Id
-- WHERE e.EventTypeEnum = 8 AND e.BusinessKey = 'MMN_EDUC.25062024R860503' AND e.RelatedYear = 2025 AND e.RelatedMonth = 9

-- SELECT * FROM Event e
-- JOIN XMLContent c ON c.ReferenceId = e.Id
-- WHERE e.EventTypeEnum = 47 AND e.BusinessKey = 'MMN_EDUC.25062024R860503' AND e.RelatedYear = 2025 AND e.RelatedMonth = 9

-- SELECT e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey, CONVERT(XML, c.Content) ContentXML
-- , ROW_NUMBER() OVER (PARTITION BY BusinessKey ORDER BY ClientReceivedDate DESC) [Number]
-- FROM Event e
-- INNER JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0 --AND CHARINDEX('<eConsignado>', c.Content) > 0
-- WHERE e.EventTypeEnum = 47
--     AND e.EventStatusEnum = 6 AND e.RelatedYear = 2025 AND e.RelatedMonth = 9 AND e.BusinessKey = 'MMN_EDUC.25062024R860503'

-- SELECT * FROM WorkerCredit WHERE Matricula = 'AP-Educ01092009R0836' OR Cpf = '32332855823'
