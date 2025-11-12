-- SELECT wc.MainEntityCode, wc.[Year], wc.[Month], wc.Competencia, wc.NumeroInscricaoEstabelecimento CNPJ, wc.matricula, RIGHT('00000000000' + wc.Cpf, 11) CPF, wc.Contrato, FORMAT(wc.IfConcessoraCodigo, '000') Financeira, wc.ValorParcela 
-- FROM WorkerCredit wc
-- WHERE WC.Contrato = '248831';
-- DECLARE @MainEntityCode VARCHAR(20) = '101122', @EntitiesCode VARCHAR(MAX) = '101122,101223,101225,101226,102122,103122,104122,105122,106122,107122,112122,113122', @RelatedYear INT = 2025, @RelatedMonth INT = 7;

WITH WorkerCreditsData AS (
    SELECT 
        wc.MainEntityCode, wc.[Year], wc.[Month], wc.Competencia, wc.NumeroInscricaoEstabelecimento CNPJ, wc.matricula, wc.NomeTrabalhador, 
        RIGHT('00000000000' + wc.Cpf, 11) CPF, wc.Contrato, FORMAT(wc.IfConcessoraCodigo, '000') Financeira, wc.ValorParcela, wc.Rubrica
    FROM WorkerCredit wc
    WHERE wc.Month = 9 --AND wc.matricula = 'APS-EDUC06022024R115120'
), WorkerCreditsDistinct AS (
    SELECT DISTINCT matricula FROM WorkerCreditsData
), EventXmlsDataS2299 AS (
    SELECT e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey
    FROM Event e
        INNER JOIN WorkerCreditsDistinct wc ON
        e.BusinessKey = wc.Matricula
    WHERE e.EventTypeEnum = 25
        AND e.EventStatusEnum = 6
        AND e.RelatedYear = 2025
        AND e.RelatedMonth = 9
), EventsData AS (
    SELECT e.Id EventId, e.RelatedYear, e.RelatedMonth, e.EntityCode, e.BusinessKey, CONVERT(XML, c.Content) ContentXML
    FROM Event e
        INNER JOIN WorkerCreditsDistinct wc ON e.BusinessKey = wc.Matricula
        INNER JOIN XMLContent c ON c.ReferenceId = e.Id AND c.ContentReferenceEnum = 0 --AND CHARINDEX('<eConsignado>', c.Content) > 0
    WHERE e.EventTypeEnum = 47
        AND e.EventStatusEnum = 6
        AND e.RelatedYear = 2025
        AND e.RelatedMonth = 9
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
        t.n.value('(*[local-name()="nrContrato"])[1]', 'varchar(50)') AS Contrato,
        '' AS Observacao
    FROM EventsData
    CROSS APPLY ContentXML.nodes('/*[local-name()="eSocial"]/*[local-name()="evtBasesFGTS"]/*[local-name()="infoFGTS"]/*[local-name()="ideEstab"]/*[local-name()="ideLotacao"]/*[local-name()="infoTrabFGTS"]/*[local-name()="eConsignado"]') AS t(n)
) --SELECT * FROM EventsData
select * FROM (SELECT 
    e.EventId, w.MainEntityCode, IIF(e.EntityCode IS Null, d.EntityCode, e.EntityCode) EntityCode, 
    IIF(e.RelatedYear IS NULL, w.Year, e.RelatedYear) RelatedYear, 
    IIF(e.RelatedMonth IS NULL, w.Month, e.RelatedMonth) RelatedMonth, 
    w.NomeTrabalhador,
    IIF(e.CPF IS NULL, w.Cpf, E.CPF) EmployeeDocument, 
    IIF(e.Matricula IS NULL, w.Matricula, E.Matricula) BusinessKey, 
    w.Rubrica,
    w.Financeira A_Financeira, w.Contrato A_Contrato, w.ValorParcela A_Parcela,
    e.Financeira E_Financeira, e.Contrato E_Contrato, e.ValorRubrica E_Parcela,
    -- CASE 
    --     WHEN w.Financeira = e.Financeira THEN 'OK'
    --     -- WHEN w.Financeira IS NULL THEN 'Consignado sem financeira'
    --     -- WHEN e.Financeira IS NULL THEN 'eSocial sem financeira'
    --     ELSE 'DIVERGENTE'
    -- END ValidaFinanceira_Status,
    -- CASE 
    --     WHEN w.Contrato = e.Contrato THEN 'OK'
    --     -- WHEN w.Contrato IS NULL THEN 'Consignado sem contrato'
    --     -- WHEN e.Contrato IS NULL THEN 'eSocial sem contrato'
    --     ELSE 'DIVERGENTE'
    -- END ValidaContrato_Status,
    CASE 
        WHEN w.Financeira = e.Financeira AND w.Contrato = e.Contrato THEN 'OK' 
        ELSE IIF(e.EventId IS NULL, 'Sem informação do APS', 'Divergente ABM')
    END Validacao,
    CASE 
        WHEN ABS(w.ValorParcela - e.ValorRubrica) <= 0.01 THEN 'OK'
        WHEN w.ValorParcela IS NULL THEN 'Consignado sem valor'
        WHEN e.ValorRubrica IS NULL THEN 'eSocial sem valor'
        WHEN w.ValorParcela > e.ValorRubrica THEN 'Valor maior no consignado'
        WHEN w.ValorParcela < e.ValorRubrica THEN 'Valor maior no eSocial'
        ELSE 'DIVERGENTE'
    END ValidaParcela_Status
    -- (e.ValorRubrica - w.ValorParcela) DiferencaValor,
    -- e.Observacao
FROM EventXmlsDataS5003 e
FULL OUTER JOIN WorkerCreditsData w ON e.RelatedYear = w.Year AND e.RelatedMonth = w.Month AND w.Matricula = e.Matricula AND w.Contrato = e.Contrato
LEFT JOIN EventXmlsDataS2299 d ON w.matricula = d.BusinessKey) t

-- WHERE EmployeeDocument IN ('00776817540','02045722155','02633080308','02675270121','02791500162','02806175267','03626320570','04108028244','04564664603','04740456419','05109687404','05301776509','05413268130','05613313598','06082347960','06443848594','06813621629','07431132840','07980017390','08291174822','08456522570','08598802492','09058576663','09800977627','10685216861','11022677837','12787591400','13255433819','13329204621','14239151864','14279767750','14342163810','14367080870','15246644804','15291385820','15656948803','17702329823','21363046829','21388406896','21874178836','22207624838','22360723847','23483964835','25195178836','25783937886','26279637832','26487007811','26841216806','27227582884','27845120880','29070718820','29087021852','29223339812','29223339812','29316768888','29413167877','30338297839','30644507861','30667583890','30725698861','31071324896','31658862880','32187486826','32280973820','32332855823','32857751818','33433381844','33830931824','34201995895','34474125851','34526895814','34758227845','35942717818','35997543811','36175982851','36281084896','36783288811','37172538838','37686048888','38126853883','38297321800','38892884808','39750552865','40287856852','40863688896','41177926873','42000910890','42011105838','42557139874','42760851877','43147722805','43266216806','43923609892','43955554899','43955554899','43993887816','44159475817','45447878829','45570516859','47152598851','48033470852','48450037832','49455892839','49844739837','49999965881','50506043894','51015748805','51025271858','51171081839','52274720843','54447882841','61297247302','62350655318','70464684277','81515111334','82121249168','83416900049','98295802372')



-- select * FROM XMLContent WHERE ReferenceId = 18152229 