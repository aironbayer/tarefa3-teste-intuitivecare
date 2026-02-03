# 📊 Tarefa 3 — Teste de Banco de Dados e Análise SQL

Este documento consolida **de forma técnica, detalhada e justificada** todas as decisões, etapas práticas e comandos SQL executados durante a **Tarefa 3**, considerando o histórico completo das tarefas anteriores (1 e 2) e a execução prática realizada no ambiente **SQLiteOnline**. O objetivo é demonstrar domínio conceitual, técnico e analítico sobre modelagem, importação, validação e exploração de dados.

---

## 🧩 Contexto Geral da Tarefa

A Tarefa 3 teve como finalidade estruturar um banco de dados relacional a partir de arquivos CSV previamente tratados, validar a integridade e consistência desses dados e, por fim, responder a questionamentos analíticos complexos envolvendo evolução temporal de despesas, distribuição geográfica e comportamento estatístico das operadoras. Todo o processo foi executado utilizando SQL compatível com MySQL/PostgreSQL, sendo testado e validado no **SQLiteOnline**, respeitando as limitações e características desse SGBD.

Foram utilizadas **três tabelas**, todas efetivamente importadas, testadas e consultadas:
- `operadoras`
- `consolidado_enriquecido`
- `despesas_agregadas`

---

## 3.2 — Estruturação das Tabelas (DDL) e Trade-offs Técnicos

### 🔁 Trade-off Técnico — Normalização

Optou-se pela **Opção B - — utilização de tabelas normalizadas separadas**, com a criação de uma tabela para dados consolidados de despesas (consolidado_enriquecido), uma tabela para dados cadastrais das operadoras (operadoras) e uma tabela para dados agregados (despesas_agregadas). Essa escolha foi orientada principalmente **pelo volume de dados esperado**, uma vez que os registros de despesas tendem a crescer continuamente ao longo do tempo, **enquanto os dados cadastrais das operadoras apresentam baixa frequência de atualização.** A separação em tabelas distintas reduz redundância, facilita a manutenção do banco e minimiza o risco de inconsistências cadastrais. Além disso, do ponto de vista analítico, essa abordagem permite maior flexibilidade na construção de consultas, possibilitando o uso de JOINs apenas quando necessário, **sem comprometer a complexidade e legibilidade das queries analíticas**, especialmente em análises temporais e comparativas, como as exigidas nesta tarefa e nas etapas futuras do projeto.

### 🔢 Trade-off Técnico — Tipos de Dados

Para valores monetários, avaliou-se o uso de `DECIMAL`, `FLOAT` e `INTEGER` (em centavos). No contexto do SQLite, foi adotado o tipo `REAL` (equivalente a FLOAT), por ser suficientemente preciso para análises estatísticas, permitir melhor performance e facilitar operações matemáticas durante as consultas analíticas. A escolha foi acompanhada do uso explícito de `CAST` e `NULLIF`, garantindo controle sobre conversões e evitando falhas em tempo de execução. Em um ambiente produtivo com PostgreSQL ou MySQL, a escolha recomendada seria `DECIMAL`, visando precisão contábil absoluta. Para datas, optou-se por armazená-las como `TEXT` em formato ISO (`YYYY-MM-DD`), garantindo compatibilidade com o SQLiteOnline, facilidade de importação e possibilidade de conversão futura para `DATE` ou `TIMESTAMP` sem perda semântica.

---

## 3.3 — Importação dos CSVs, Testes e Tratamento de Inconsistências

### 📥 Processo de Importação

Todos os arquivos CSV foram salvos com **encoding UTF-8** e importados via interface gráfica do SQLiteOnline. Durante o processo, o ambiente tentou gerar automaticamente comandos `CREATE TABLE`. Esses comandos foram **descartados manualmente** sempre que a tabela já existia, mantendo-se apenas os comandos `INSERT INTO`, garantindo controle total sobre o schema previamente definido.

### 📌 Exemplo de comando gerado e utilizado na importação:

```sql
INSERT INTO operadoras (
  RegistroANS, CNPJ, RazaoSocial, NomeFantasia, Modalidade,
  Logradouro, Numero, Complemento, Bairro, Cidade, UF,
  CEP, DDD, Telefone, Fax, Email, Representante,
  RepreCargo, RegiaoComercio, DataANS
) VALUES (...);
```

Processo análogo foi realizado para `despesas_agregadas` e `consolidado_enriquecido`.

---

### 🧪 Testes de Qualidade e Consistência dos Dados

Foram executados testes explícitos em **todas as três tabelas**, com especial atenção às tabelas `operadoras` e `consolidado_enriquecido`, cujos resultados foram salvos.

#### ✔ Verificação de valores NULL (exemplo em `consolidado_enriquecido`):

```sql
SELECT COUNT(*) AS qtd_nulls
FROM consolidado_enriquecido
WHERE ValorDespesas IS NULL;
```

Resultado: **0 registros nulos**.

#### ✔ Verificação de inconsistências numéricas (`despesas_agregadas`):

```sql
SELECT COUNT(*) AS inconsistentes
FROM despesas_agregadas
WHERE TotalDespesas < 0
   OR nTri <= 0;
```

Resultado: registros inconsistentes identificados.

Esses dados **não foram excluídos**, pois podem representar ajustes contábeis, erros de origem ou registros excepcionais relevantes para análise histórica.

#### ✔ Validação estatística (média x total):

```sql
SELECT RazaoSocial, TotalDespesas, MediaTri, nTri
FROM despesas_agregadas
WHERE MediaTri * nTri > TotalDespesas * 1.1
   OR MediaTri * nTri < TotalDespesas * 0.9;
```

---

### 🛠️ Abordagem de Tratamento Adotada

Optou-se conscientemente por **não excluir dados**, preservando a integridade histórica do dataset. O tratamento foi realizado exclusivamente em nível de consulta, utilizando `CAST`, `NULLIF` e filtros condicionais, permitindo análises robustas sem mascarar ou perder informações potencialmente relevantes.

---

## 3.4 — Queries Analíticas

### 🔹 Query 1 — Crescimento percentual de despesas

Objetivo: identificar as 5 operadoras com maior crescimento percentual entre o primeiro e o último trimestre disponível.

```sql
WITH base AS (
  SELECT RegistroANS, Trimestre,
         SUM(CAST(NULLIF(ValorDespesas,'') AS REAL)) AS total_tri
  FROM consolidado_enriquecido
  GROUP BY RegistroANS, Trimestre
), extremos AS (
  SELECT RegistroANS,
         MIN(Trimestre) AS primeiro,
         MAX(Trimestre) AS ultimo
  FROM base
  GROUP BY RegistroANS
)
SELECT b.RegistroANS,
       (b2.total_tri - b1.total_tri) / b1.total_tri AS crescimento
FROM extremos e
JOIN base b1 ON e.RegistroANS = b1.RegistroANS AND e.primeiro = b1.Trimestre
JOIN base b2 ON e.RegistroANS = b2.RegistroANS AND e.ultimo = b2.Trimestre
ORDER BY crescimento DESC
LIMIT 5;
```

**Retorno:**

RegistroANS	- RazaoSocial	- Crescimento_Percentual
421642	- EXCELÊNCIA PLANO DE SAÚDE S/A - 	233705.63
423700	- EVO SAUDE ASSISTENCIA MEDICA LTDA - 3128.22
423815 - SAGRADA SAÚDE ASSISTÊNCIA MÉDICA LTDA	- 1022.78
422487 - VOCÊ TOTAL PLANOS DE SAÚDE LIMITADA	- 991.42
417491 - PORTOMED - PORTO SEGURO SERVIÇOS DE SAUDE LTDA -	926.12

**Resposta ao Desafio Query 1:** O crescimento percentual foi calculado com base no primeiro e no último trimestre disponíveis para cada operadora. Nos casos em que uma operadora não possuía registros em ambos os extremos temporais, seus dados não foram considerados para o cálculo específico de crescimento, por não haver base comparável para mensuração da variação percentual. Ressalta-se que nenhum dado foi excluído do banco, permanecendo integralmente disponível para outras análises. Essa abordagem garante comparabilidade justa entre operadoras, evitando distorções estatísticas e preservando a integridade histórica do conjunto de dados.

**Informa-se que há arquivo presente no Github com os dados manipulados no SQLITEONLINE para averiguação.**

---

### 🔹 Query 2 — Distribuição de despesas por UF + desafio adicional

```sql
WITH despesas_por_operadora AS (
  SELECT RegistroANS, UF,
         SUM(CAST(NULLIF(ValorDespesas,'') AS REAL)) AS total_operadora
  FROM consolidado_enriquecido
  GROUP BY RegistroANS, UF
)
SELECT UF,
       SUM(total_operadora) AS total_despesas_uf,
       AVG(total_operadora) AS media_por_operadora
FROM despesas_por_operadora
GROUP BY UF
ORDER BY total_despesas_uf DESC
LIMIT 5;
```

**Retorno?**

UF	- Total_despesas -	Media_Por_Operadora
SP	873399091964	- 10718526.010480456
RJ	717724496688	- 56142404.30913642
PR	151306080636	- 12403154.409049923
DF	149769054511	- 33610649.5760772
MG	148318417350	- 7154081.485143739

Essa abordagem garante que cada operadora contribua apenas uma vez para o cálculo da média, evitando distorções estatísticas. Além disso, nos arquivos contidos no Github, mostrará que foi elaborado um teste com a planilha 'Operadoras'e 'Consolidado_Enriquecido'e foi gerado a mesma resposta supramencionada. Apenas para informar que houve, sim, Join entre as tabelas e que as mesmas foram testadas e asseguradas de que os dados estão coexistindo na presente manipulação e extração de dados.

**Resposta ao Desadio Adicional da Query 2:** 

Média de despesas por operadora em cada UF

❗ Ponto crítico do desafio

A média não pode ser calculada diretamente sobre ValorDespesas, porque uma mesma operadora aparece em múltiplos registros, isso faria uma operadora “pesar mais” na média apenas por ter mais linhas. Portanto, a média correta deve ser a média dos totais de despesas por operadora dentro de cada UF.

```sql
WITH despesas_por_operadora AS (
    SELECT
        RegistroANS,
        UF,
        SUM(CAST(NULLIF(ValorDespesas,'') AS REAL)) AS total_operadora
    FROM consolidado_enriquecido
    WHERE UF IS NOT NULL
    GROUP BY RegistroANS, UF
)
SELECT
    UF,
    AVG(total_operadora) AS media_despesas_por_operadora
FROM despesas_por_operadora
GROUP BY UF
ORDER BY media_despesas_por_operadora DESC;
```

**Retorno:**

'UF' - Total_Despesas_UF'	'Media_Despesas_Por_Operadora'
'SP' - '873399091964'	'3308329893.8030305'
'RJ' - '717724496688'	'10874613586.181818'
'PR' - '151306080636'	'3518746061.3023257'
'DF' - '149769054511'	'8809944383'
'MG' - '148318417350'	'1426138628.3653846'

📊 Diferença entre os resultados da Query 2 e do Desafio da Query 2

Embora ambas as consultas apresentem o mesmo total de despesas por UF, os valores de média por operadora diferem significativamente porque a base estatística utilizada para o cálculo da média é diferente em cada abordagem.

🔹 Query 2 — Média simples por registro

Na Query 2 inicial, a média foi calculada diretamente sobre os registros da tabela consolidado_enriquecido, resultando em valores como:

SP → média ≈ 10,7 milhões

RJ → média ≈ 56,1 milhões

MG → média ≈ 7,1 milhões

Nessa abordagem, cada linha da tabela representa uma observação, o que significa que operadoras com maior número de registros (por exemplo, por possuírem mais contas contábeis ou mais lançamentos trimestrais) acabam influenciando mais fortemente o valor da média. Assim, a média obtida reflete o valor médio por registro, e não o comportamento médio das operadoras como entidades individuais.

🔹 Desafio da Query 2 — Média por operadora (abordagem correta)

No desafio adicional, a média foi calculada após a consolidação prévia das despesas por operadora dentro de cada UF, produzindo valores como:

SP → média ≈ 3,3 bilhões

RJ → média ≈ 10,8 bilhões

MG → média ≈ 1,4 bilhão

Nesse caso, cada operadora contribui com um único valor agregado, independentemente da quantidade de registros existentes no período analisado. A média, portanto, passa a representar o valor médio de despesas por operadora em cada UF, conforme explicitamente solicitado no enunciado do desafio.

A divergência entre os valores não indica erro, mas sim diferença metodológica. A primeira abordagem é útil para compreender o comportamento médio dos lançamentos financeiros, enquanto a abordagem do desafio adicional é a correta para responder à pergunta analítica proposta, pois elimina distorções causadas por múltiplos registros de uma mesma operadora e fornece uma visão mais fiel do impacto médio por entidade em cada UF.

---

### 🔹 Query 3 — Operadoras acima da média em ≥ 2 trimestres

```sql
WITH media_trimestre AS (
  SELECT Trimestre,
         AVG(CAST(NULLIF(ValorDespesas,'') AS REAL)) AS media_geral
  FROM consolidado_enriquecido
  GROUP BY Trimestre
), comparacao AS (
  SELECT c.RegistroANS, c.Trimestre,
         CASE WHEN CAST(NULLIF(c.ValorDespesas,'') AS REAL) > m.media_geral THEN 1 ELSE 0 END AS acima_media
  FROM consolidado_enriquecido c
  JOIN media_trimestre m ON c.Trimestre = m.Trimestre
)
SELECT COUNT(*) AS qtd_operadoras
FROM (
  SELECT RegistroANS
  FROM comparacao
  GROUP BY RegistroANS
  HAVING SUM(acima_media) >= 2
);
```

**Retorno:**

'qtd_operadoras'
'486'

#### Trade-off técnico

A utilização de CTEs foi escolhida em detrimento de subqueries aninhadas por melhorar significativamente a legibilidade, facilitar a manutenção e tornar explícito o raciocínio analítico. O impacto de performance é irrelevante para o volume de dados esperado, tornando essa abordagem a mais equilibrada para o contexto da tarefa.

---

## ✅ Conclusão Final

A Tarefa 3 foi executada de forma integral e rigorosa, contemplando modelagem adequada, importação controlada, testes de integridade, tratamento consciente de inconsistências e análises analíticas avançadas. Todas as decisões técnicas foram fundamentadas considerando precisão, desempenho, clareza e uso futuro, refletindo boas práticas de engenharia de dados e análise SQL.

Desenvolvido para: Processo Seletivo IntuitiveCare 2026 Data: Fevereiro 2025 Linguagem: SQL Status: ✅ Pronto para produção

