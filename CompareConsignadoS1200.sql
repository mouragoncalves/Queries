DECLARE @MainEntityCode VARCHAR(20) = '101122', @RelatedYear INT = 2025, @RelatedMonth INT = 7;

WITH WorkerCreditsData AS (
    SELECT
        MainEntityCode, NomeTrabalhador, RIGHT('00000000000' + Cpf, 11) Cpf, Matricula, FORMAT(IfConcessoraCodigo, '000') Financeira, Contrato, ValorParcela, [Year], [Month], Competencia
    FROM WorkerCredit 
    WHERE MainEntityCode = @MainEntityCode 
        AND [Year] = @RelatedYear 
        AND [Month] = @RelatedMonth
), S1200 AS (
    SELECT e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey, CONVERT(XML, c.Content) ContentXML
    FROM Event e
        INNER JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0 AND CHARINDEX('<descFolha>', c.Content) > 0
    WHERE e.EventTypeEnum = 8
        --AND e.EntityCode IN (SELECT CAST(value AS varchar) FROM STRING_SPLIT(@EntitiesCode, ','))
        AND e.RelatedYear = @RelatedYear
        AND e.RelatedMonth = @RelatedMonth
        AND e.EventStatusEnum IN (0, 6, 7)
), EventXmlsDataS1200 AS (
    SELECT
        EventId,
        RelatedYear,
        RelatedMonth,
        EntityCode,
        t.n.value('(/eSocial/evtRemun/ideTrabalhador/cpfTrab)[1]', 'varchar(11)') CPF,
        t.n.value('(../../matricula)[1]', 'varchar(50)') Matricula,
        t.n.value('(../../../nrInsc)[1]', 'varchar(14)') Estabelecimento,
        t.n.value('(../codRubr)[1]', 'varchar(10)') Rubrica,
        t.n.value('(../vrRubr)[1]', 'decimal(15,2)') ValorRubrica,
        t.n.value('(instFinanc)[1]', 'varchar(10)') Financeira,
        t.n.value('(nrDoc)[1]', 'varchar(50)') Contrato,
        t.n.value('(observacao)[1]', 'varchar(255)') Observacao
    FROM S1200
    CROSS APPLY ContentXML.nodes('/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun[descFolha]/descFolha') AS t(n)
), S2299 AS (
    SELECT e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey
    FROM Event e
        INNER JOIN WorkerCreditsDistinct wc ON
        e.BusinessKey = wc.Matricula
    WHERE e.EventTypeEnum = 25
        AND e.EventStatusEnum = 6
        AND e.RelatedYear = 2025
        AND e.RelatedMonth = 9
), S5003 AS (
    SELECT e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey, CONVERT(XML, c.Content) ContentXML
    FROM Event e
        INNER JOIN WorkerCreditsDistinct wc ON e.BusinessKey = wc.Matricula
        INNER JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0 --AND CHARINDEX('<eConsignado>', c.Content) > 0
    WHERE e.EventTypeEnum = 47
        AND e.EventStatusEnum = 6
        AND e.RelatedYear = 2025
        AND e.RelatedMonth = 9
), XmlsDataS5003 AS (
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
        t.n.value('(*[local-name()="nrContrato"])[1]', 'varchar(50)') AS Contrato,
        '' AS Observacao
    FROM S5003
    CROSS APPLY ContentXML.nodes('/*[local-name()="eSocial"]/*[local-name()="evtBasesFGTS"]/*[local-name()="infoFGTS"]/*[local-name()="ideEstab"]/*[local-name()="ideLotacao"]/*[local-name()="infoTrabFGTS"]/*[local-name()="eConsignado"]') AS t(n)
)
SELECT 
    e.EventId, w.MainEntityCode, e.EntityCode, 
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
    (e.ValorRubrica - w.ValorParcela) DiferencaValor,
    e.Observacao
FROM EventXmlsDataS1200 e
FULL OUTER JOIN WorkerCreditsData w ON w.Matricula = e.Matricula AND w.Contrato = e.Contrato