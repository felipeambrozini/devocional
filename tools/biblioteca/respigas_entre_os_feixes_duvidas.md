# Respigas entre os Feixes: dúvidas e decisões

## Pendências

- Cap. 38 (arquivo `39.json`), título "Nosso Senhor Jesus.": não foi identificado um versículo específico que sirva de base ao título. A frase foi mantida entre aspas como no original, mas não há citação registrada. Confirmar se o título deve ficar sem aspas ou se corresponde a algum texto que não foi localizado.

## Decisões de tradução

- Cap. 131 (arquivo `132.json`): o título inglês "Grace Doth Much More Abound." foi traduzido por "Superabundou a Graça.", forma da BKJ em Romanos 5:20, para que a citação entre aspas seja literal.
- Títulos que são versículos usam o texto da BKJ entre aspas retas.
- Falas retóricas longas do pregador foram convertidas em discurso indireto quando não eram citações bíblicas.
- Em cinco capítulos (15, 28, 42, 124 e 129) a pontuação foi ajustada para preservar a contagem de frases em relação ao original, sem alterar o sentido.

## Avisos do auditor justificados

O `auditar_livro.py` acusa `fora_da_biblia` nos casos abaixo.

1. Citações bíblicas literais que ocupam o versículo inteiro ou atravessam a fronteira entre versículos. O índice do auditor usa `|` entre versículos, de modo que uma citação terminada exatamente no fim do versículo não é encontrada pelo teste `" trecho "`. Todas estão registradas em `citacoes` e passam no `checar_capitulo.py`. Exemplos: cap. 108 (Habacuque 3:17-18) e cap. 143 (Hebreus 11:24-25).

2. Citações de hinos e poesia, mantidas entre aspas como no original e não registradas como Escritura:
   - cap. 102 (arquivo `102.json`), p1
   - cap. 107 (arquivo `107.json`), p1
   - cap. 121 (arquivo `121.json`), p1
   - cap. 123 (arquivo `123.json`), p1
   - cap. 131 (arquivo `131.json`), p1
   - cap. 137 (arquivo `137.json`), p1
   - cap. 139 (arquivo `139.json`), p3 e p5
   - cap. 141 (arquivo `141.json`), p0

3. Falas retóricas do pregador, não citações bíblicas:
   - cap. 11 (arquivo `11.json`), p0
   - cap. 15 (arquivo `15.json`), p1
   - cap. 17 (arquivo `17.json`), p0
   - cap. 20 (arquivo `20.json`), p1
   - cap. 34 (arquivo `34.json`), p0

O `revisar_livro.py` marca nove ocorrências de "faze" como português de Portugal. A forma é o imperativo correto de segunda pessoa (tu) e foi mantida para uniformidade com o tratamento por "tu" adotado no livro.
