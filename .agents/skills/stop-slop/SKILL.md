---
name: stop-slop
description: Revisa os textos que o usuário lê no app (telas, widgets, avisos, personas, metadados da web) e corta os padrões de escrita de IA. Use ao criar ou alterar qualquer texto visível.
---

# Stop slop

Adaptado de [hardikpandya/stop-slop](https://github.com/hardikpandya/stop-slop)
(MIT, ver `LICENSE`; commit 8da1f03). As referências em inglês
(`references/phrases.md`, `structures.md` e `examples.md`) são as do original.
`references/portugues.md` traz os padrões em português e os exemplos deste
app. Quando as duas divergirem, vale o português e as exceções abaixo.

## Escopo

Entra todo texto que aparece para quem usa o app:

- strings de `lib/telas/` e `lib/widgets/`: títulos, parágrafos, avisos,
  diálogos, `SnackBar`, rótulos, `tooltip` e `Semantics`;
- textos de `lib/dados/` e `lib/funcoes/` que vão para a tela, como o
  `boasVindas` das personas, as `linhasDeAjuda`, os subtítulos da Biblioteca
  e `avisoDaBibliaDeEstudo`;
- metadados públicos da web: `description` e `og:description` em
  `web/index.html` e `description` em `web/manifest.json`.

Fica de fora, a não ser que o usuário peça:

- comentários e introduções da Bíblia de Estudo em `assets/` (têm os skills
  `spurgeon-comentarios` e `spurgeon-introducao`);
- instruções de sistema das personas (`lib/dados/instrucoes_*.dart`);
- comentários de código e documentação.

## Como aplicar

1. Liste os textos novos ou mudados no diff, inclusive os de `lib/dados/` que
   chegam à tela.
2. Passe cada um pelas regras abaixo e por `references/portugues.md`.
3. Reescreva só o que cair numa regra. Texto que já está direto fica.
4. Antes de trocar, procure o texto antigo em `test/`: algum teste pode
   procurar a frase exata.
5. Relate cada troca com o antes e o depois.

## Regras

1. **Corte o enchimento.** Abertura que anuncia ("Que bom ter você aqui",
   "Vale lembrar que"), ênfase vazia e advérbio de intensidade
   ("verdadeiramente", "realmente", "profundamente", "simplesmente").
2. **Quebre as fórmulas.** Contraste binário ("não é X, é Y", "não apenas X,
   mas Y"), lista do que a coisa não é, fragmento dramático, pergunta
   retórica respondida em seguida.
3. **Dê sujeito à frase.** Coisa não faz ação de gente ("o texto busca", "o
   retrato lê", "a ordem decide"). Em instrução, fale com o leitor: "Toque em
   Ouvir".
4. **Seja específico.** Troque a abstração ("experiência", "jornada",
   "rigor", "especial") pelo fato. Desconfie de "todo", "sempre", "nunca" e
   "nenhum" fazendo trabalho vago.
5. **Dois itens bastam.** Lista de três abstratos é a marca mais comum.
6. **Sem frase de efeito no fim.** Se a frase serviria de cartaz, reescreva.
7. **Confie no leitor.** Diga o fato, sem justificar nem amaciar.
8. **Pontuação do projeto.** Sem travessão e só aspas retas (PRODUCT.md,
   "Regras de texto do produto").

## Exceções deste projeto

- Advérbio que informa estado fica: "temporariamente", "localmente".
- Voz passiva em Privacidade e Termos fica: é texto jurídico, e às vezes o
  agente fica indeterminado de propósito.
- Pergunta do FAQ que começa com "Como" ou "Por que" é título e fica.
- Texto de apoio em crise (`apoio_em_crise.dart` e a orientação do CVV) não
  passa por ajuste de estilo. "Você não está sozinho" é a frase certa ali.
- A persona Spurgeon fala em voz vitoriana e trata o leitor por "tu". Não
  modernize.
- Botão, `tooltip` e `Semantics` ficam curtos e no imperativo; a regra do
  sujeito não vale para um botão "Ouvir".
- Uma instrução que manda tocar em algo precisa citar o que o leitor de tela
  anuncia (o rótulo do botão), não um elemento decorativo.
- Mudança de texto não mexe na versão (CLAUDE.md).

## Checagem rápida

- Tem advérbio de intensidade? Corte.
- Tem "não é X, é Y" ou "não apenas X, mas Y"? Diga Y.
- Tem coisa fazendo ação de gente? Ponha a pessoa ou o leitor como sujeito.
- Tem três abstratos em fila? Fique com o que é concreto.
- O parágrafo fecha com aforismo? Termine no fato.
- Tem "jornada", "experiência", "especial", "rigor"? Diga o que é.
- Tem travessão ou aspas curvas? Troque.

## Nota

Se quiser dar nota, use as cinco dimensões do original (diretividade, ritmo,
confiança no leitor, autenticidade, densidade), de 1 a 10 cada; abaixo de
35/50, revise. Diga que a nota é estimativa, não medição.
