DECLARE @RelatedYear INT = 2025, @RelatedMonth INT = 6;

WITH Events_S1200 AS (
    SELECT e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, CONVERT(XML, c.Content) ContentXML
    FROM Event e 
    JOIN XMLContent c ON c.ReferenceId = e.Id
    WHERE e.EventTypeEnum = 8
        AND e.RelatedYear = @RelatedYear
        AND e.RelatedMonth = @RelatedMonth
        AND e.EventStatusEnum <= 7
        AND c.ContentReferenceEnum = 0
), Events_XML AS (
    SELECT * 
    FROM Events_S1200
    WHERE ContentXML.exist('/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun/descFolha') = 1
        -- OR ContentXML.value('count(/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun/descFolha)', 'int') > 0
)
SELECT 
    EventId,
    RelatedYear,
    RelatedMonth,
    EntityCode,
    t.n.value('(/eSocial/evtRemun/ideTrabalhador/cpfTrab)[1]', 'varchar(11)') CPF,
    t.n.value('(../../matricula)[1]', 'varchar(50)') AS Matricula,
    t.n.value('(../../../nrInsc)[1]', 'varchar(14)') AS Estabelecimento,
    t.n.value('(../codRubr)[1]', 'varchar(10)') AS CodigoRubrica,
    t.n.value('(../vrRubr)[1]', 'decimal(15,2)') AS ValorRubrica,
    t.n.value('(instFinanc)[1]', 'varchar(10)') AS InstituicaoFinanceira,
    t.n.value('(nrDoc)[1]', 'varchar(50)') AS NumeroDocumento,
    t.n.value('(cnpjDescFolha)[1]', 'varchar(14)') AS CNPJDescFolha,
    t.n.value('(tpDesc)[1]', 'varchar(5)') AS TipoDesconto,
    t.n.value('(observacao)[1]', 'varchar(255)') AS Observacao,
    ROW_NUMBER() OVER (PARTITION BY EventId ORDER BY (SELECT NULL)) AS OrdemDescFolha
FROM Events_XML
CROSS APPLY ContentXML.nodes('/eSocial/evtRemun/dmDev/infoPerApur/ideEstabLot/remunPerApur/itensRemun[descFolha]/descFolha') AS t(n)

