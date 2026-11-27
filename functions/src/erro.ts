// Normalização e limite de taxa dos relatórios de erro da web.
//
// O app manda o relatório por `POST /tabernaculo/api/erro` (rewrite do Hosting
// para a Function `registrarErro`, ver firebase.json). O corpo é hostil por
// definição: vem de qualquer navegador, sem login. Nada do que chega é
// gravado como veio — só os campos conhecidos, com teto de tamanho, e a URL
// reduzida ao caminho (sem query string, que pode carregar conteúdo digitado).
//
// A gravação é agregada pelo hash do erro: a mesma falha repetida incrementa
// `ocorrencias` em vez de criar um documento por visita. Isso mantém a
// coleção `erros` pequena sem precisar de TTL nem de limpeza agendada.
import {createHash} from "node:crypto";

export const ORIGENS = ["janela", "promessa", "dart"] as const;
export type OrigemDoErro = (typeof ORIGENS)[number];

export interface ErroNormalizado {
  origem: OrigemDoErro;
  /** Área do app que chamou Registro.erro (ex. "Nuvem.iniciar"). */
  contexto: string;
  mensagem: string;
  pilha: string;
  arquivo: string;
  linha: number;
  url: string;
  versao: string;
  plataforma: string;
}

const TAMANHO_DO_CONTEXTO = 80;
const TAMANHO_DA_MENSAGEM = 1000;
const TAMANHO_DA_PILHA = 8000;
const TAMANHO_DO_ARQUIVO = 300;
const TAMANHO_DA_URL = 300;
const TAMANHO_DA_VERSAO = 40;
const TAMANHO_DA_PLATAFORMA = 20;

function ehObjeto(valor: unknown): valor is Record<string, unknown> {
  return typeof valor === "object" && valor !== null && !Array.isArray(valor);
}

function texto(valor: unknown, limite: number): string {
  if (typeof valor !== "string") return "";
  // \u0000 e demais controles não acrescentam nada ao diagnóstico e atrapalham
  // busca/leitura no console do Firestore.
  return valor
      .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, "")
      .slice(0, limite);
}

/** Só o caminho: query string e fragmento podem carregar o que a pessoa digitou. */
function caminho(valor: string): string {
  if (!valor.startsWith("/")) return "";
  return semConsulta(valor, TAMANHO_DA_URL);
}

/**
 * Corta query e fragmento mantendo o resto. O `arquivo` de um erro de janela
 * chega como URL do script e pode, em tese, trazer parâmetro; o diagnóstico
 * não perde nada sem ele.
 */
function semConsulta(valor: string, limite: number): string {
  const corte = valor.search(/[?#]/);
  return (corte === -1 ? valor : valor.slice(0, corte)).slice(0, limite);
}

/**
 * Valida e reduz o corpo recebido ao contrato de `erros/{hash}`.
 * null = relatório inválido (sem origem conhecida ou sem mensagem).
 */
export function normalizarErro(corpo: unknown): ErroNormalizado | null {
  if (!ehObjeto(corpo)) return null;
  const origem = texto(corpo.origem, 20);
  if (!(ORIGENS as readonly string[]).includes(origem)) return null;
  const mensagem = texto(corpo.mensagem, TAMANHO_DA_MENSAGEM);
  if (mensagem.length === 0) return null;
  const linha = corpo.linha;
  return {
    origem: origem as OrigemDoErro,
    contexto: texto(corpo.contexto, TAMANHO_DO_CONTEXTO),
    mensagem,
    pilha: texto(corpo.pilha, TAMANHO_DA_PILHA),
    arquivo: semConsulta(texto(corpo.arquivo, TAMANHO_DO_ARQUIVO), TAMANHO_DO_ARQUIVO),
    linha:
      typeof linha === "number" && Number.isInteger(linha) &&
      linha >= 0 && linha <= 1000000
        ? linha
        : 0,
    url: caminho(texto(corpo.url, TAMANHO_DA_URL)),
    versao: texto(corpo.versao, TAMANHO_DA_VERSAO),
    plataforma: texto(corpo.plataforma, TAMANHO_DA_PLATAFORMA),
  };
}

/**
 * Id do documento: a mesma falha (mesma origem, mensagem, local e versão)
 * cai no mesmo documento, venha de quem vier. O hash também impede que uma
 * mensagem enorme vire id de documento (o Firestore limita a 1500 bytes).
 */
export function chaveDoErro(dados: ErroNormalizado): string {
  return createHash("sha256")
      .update([
        dados.origem,
        dados.contexto,
        dados.mensagem,
        dados.arquivo,
        String(dados.linha),
        dados.url,
        dados.versao,
      ].join("|"))
      .digest("hex")
      .slice(0, 32);
}

/** Por quantos dias um relatório fica depois da última ocorrência. */
export const DIAS_DE_RETENCAO = 90;

/**
 * Quando o relatório sai sozinho: a política de TTL do Firestore na coleção
 * `erros` apaga o documento depois de `expiraEm`. Cada ocorrência nova empurra
 * a data, então uma falha que continua acontecendo não some do console; a que
 * parou sai 90 dias depois da última vez. É o que a política de privacidade
 * promete ("Onde os dados ficam e por quanto tempo").
 */
export function expiracaoDoErro(agora: Date): Date {
  return new Date(agora.getTime() + DIAS_DE_RETENCAO * 24 * 60 * 60 * 1000);
}

/**
 * Chave do cliente para o limite de taxa. O IP em si nunca é gravado: o hash
 * com sal aleatório por instância só existe na memória do processo e não
 * permite reconstruir o endereço a partir do Firestore (que não o recebe).
 */
export function chaveDoCliente(ip: string, sal: string): string {
  return createHash("sha256").update(sal).update(ip).digest("hex").slice(0, 16);
}

/**
 * Janela deslizante por instância. É uma defesa de custo, não uma garantia:
 * com várias instâncias, cada uma conta a própria fatia. O teto de
 * `maxInstances` da Function limita o pior caso.
 */
export class LimitadorDeTaxa {
  private readonly janelas = new Map<string, {inicio: number; contagem: number}>();

  constructor(
    private readonly limite = 10,
    private readonly janelaMs = 60_000,
  ) {}

  permitir(chave: string, agora = Date.now()): boolean {
    // Um navegador em loop não pode crescer o mapa sem fim.
    if (this.janelas.size > 10_000) this.janelas.clear();
    const atual = this.janelas.get(chave);
    if (atual === undefined || agora - atual.inicio >= this.janelaMs) {
      this.janelas.set(chave, {inicio: agora, contagem: 1});
      return true;
    }
    if (atual.contagem >= this.limite) return false;
    atual.contagem++;
    return true;
  }
}
