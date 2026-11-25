// Checa firestore.rules e storage.rules contra o emulador — as regras vão
// para produção a cada push na main (deploy-web.yml), então rodar isto antes
// de mexer nelas. Pela raiz do repositório (precisa de Java para o emulador):
//   npm --prefix test_regras install
//   npm --prefix test_regras test
//
// Host e porta vêm das variáveis que `firebase emulators:exec` define; o
// projeto `demo-` nunca fala com o Firebase de verdade.
import {readFileSync} from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, deleteField, serverTimestamp,
  collection, query, where, getDocs, arrayUnion, arrayRemove,
} from 'firebase/firestore';
import {ref, uploadBytes, deleteObject} from 'firebase/storage';

const daRaiz = (arquivo) =>
  readFileSync(new URL(`../${arquivo}`, import.meta.url), 'utf8');

const env = await initializeTestEnvironment({
  projectId: 'demo-regras',
  firestore: {rules: daRaiz('firestore.rules')},
  storage: {rules: daRaiz('storage.rules')},
});

const google = {firebase: {sign_in_provider: 'google.com'}};
const alice = env.authenticatedContext('alice', google);
const bob = env.authenticatedContext('bob', google);
const semGoogle = env.authenticatedContext('carol',
  {firebase: {sign_in_provider: 'password'}});
const anonimo = env.unauthenticatedContext();
const carolDoGoogle = env.authenticatedContext('carol-google', google);
const dono = env.authenticatedContext('dono', {
  email: 'felipe.anegrini@gmail.com', ...google,
});
const outroEmail = env.authenticatedContext('intruso', {
  email: 'outro@example.com', ...google,
});

let falhas = 0;
async function caso(nome, promessa) {
  try {
    await promessa;
    console.log(`ok    ${nome}`);
  } catch (erro) {
    falhas++;
    console.log(`FALHA ${nome}\n      ${erro.message}`);
  }
}

const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xe0]);
const fotoDaAlice = (ctx) => ref(ctx.storage(), 'fotos_de_perfil/alice.jpg');

// --- Storage: sem upload próprio (só áudio público) ---------------------- //
// O avatar é só exibição (foto da conta Google): nada sobe para o Storage —
// upload e delete em `fotos_de_perfil/` são negados para todo mundo,
// inclusive o dono. O único caminho com leitura é `audio/` (MP3 pré-gerados,
// escrita só por deploy).
await caso('dono NÃO envia foto (upload próprio removido)',
  assertFails(uploadBytes(fotoDaAlice(alice), jpeg, {contentType: 'image/jpeg'})));
await caso('dono NÃO apaga foto (nada para apagar)',
  assertFails(deleteObject(fotoDaAlice(alice))));
await caso('outro usuário não apaga a foto alheia',
  assertFails(deleteObject(fotoDaAlice(bob))));
await caso('anônimo não apaga foto',
  assertFails(deleteObject(fotoDaAlice(anonimo))));
await caso('ninguém sobe arquivo com o nome de outro uid',
  assertFails(uploadBytes(ref(bob.storage(), 'fotos_de_perfil/alice.jpg'), jpeg,
    {contentType: 'image/jpeg'})));

// --- Firestore: planos compartilhados ---------------------------------- //
const planoValido = () => ({
  titulo: 'Gênesis em 10 dias',
  livros: ['genesis'],
  dias: 10,
  incluirDevocionais: false,
  devocionalAntes: true,
  criadoPor: 'alice',
  criadoEm: serverTimestamp(),
  participantes: {alice: {nome: 'Alice', lidos: []}},
});
const plano = (ctx, id) => doc(ctx.firestore(), 'planos', id);

await caso('cria plano com os campos de compartilhar()',
  assertSucceeds(setDoc(plano(alice, 'p1'), planoValido())));
await caso('cria plano sem os bools de devocionais (documento antigo)', (() => {
  const {incluirDevocionais, devocionalAntes, ...semBools} = planoValido();
  return assertSucceeds(setDoc(plano(alice, 'p2'), semBools));
})());
await caso('recusa campo extra na criação',
  assertFails(setDoc(plano(alice, 'p3'), {...planoValido(), lixo: 'x'.repeat(100)})));
await caso('recusa incluirDevocionais que não é bool',
  assertFails(setDoc(plano(alice, 'p4'), {...planoValido(), incluirDevocionais: 'sim'})));
await caso('recusa devocionalAntes que não é bool',
  assertFails(setDoc(plano(alice, 'p5'), {...planoValido(), devocionalAntes: 1})));
await caso('recusa criador fora de participantes',
  assertFails(setDoc(plano(alice, 'p6'), {...planoValido(), participantes: {}})));
await caso('recusa plano criado por login que não é Google',
  assertFails(setDoc(plano(semGoogle, 'p7'),
    {...planoValido(), criadoPor: 'carol',
      participantes: {carol: {nome: 'Carol', lidos: []}}})));

// Os updates não mudaram, mas dependem do documento que o create exige:
// sem isto nada acusaria se uma mudança futura no create os quebrasse.
await caso('bob entra no plano pelo link',
  assertSucceeds(updateDoc(plano(bob, 'p1'),
    {'participantes.bob': {nome: 'Bob', lidos: []}})));
await caso('bob marca os próprios dias',
  assertSucceeds(updateDoc(plano(bob, 'p1'), {'participantes.bob.lidos': [1, 2]})));
await caso('bob não mexe nos dias da alice',
  assertFails(updateDoc(plano(bob, 'p1'), {'participantes.alice.lidos': [1]})));
await caso('criadora renomeia o plano',
  assertSucceeds(updateDoc(plano(alice, 'p1'), {titulo: 'Gênesis devagar'})));
await caso('participante não renomeia o plano',
  assertFails(updateDoc(plano(bob, 'p1'), {titulo: 'Outro nome'})));
// Revisão: o criador troca livros ou dias e grava uma revisão nova; cada
// participante zera a própria entrada ao vê-la (PlanosNaNuvem.alinharRevisao).
await caso('criadora muda os dias e grava a revisão',
  assertSucceeds(updateDoc(plano(alice, 'p1'), {dias: 5, revisao: 1700000000000})));
await caso('revisão que não é int é recusada',
  assertFails(updateDoc(plano(alice, 'p1'), {revisao: 'nova'})));
await caso('participante não grava a revisão do plano',
  assertFails(updateDoc(plano(bob, 'p1'), {revisao: 1700000000001})));
await caso('criadora zera a própria entrada na revisão nova',
  assertSucceeds(updateDoc(plano(alice, 'p1'),
    {'participantes.alice.lidos': [], 'participantes.alice.revisao': 1700000000000})));
await caso('bob zera a própria entrada e carimba a revisão',
  assertSucceeds(updateDoc(plano(bob, 'p1'),
    {'participantes.bob.lidos': [], 'participantes.bob.revisao': 1700000000000})));
await caso('revisão da entrada que não é int é recusada',
  assertFails(updateDoc(plano(bob, 'p1'), {'participantes.bob.revisao': 'x'})));
await caso('campo extra na entrada é recusado',
  assertFails(updateDoc(plano(bob, 'p1'), {'participantes.bob.lixo': 'x'})));
await caso('bob não carimba a revisão na entrada da alice',
  assertFails(updateDoc(plano(bob, 'p1'), {'participantes.alice.revisao': 1})));
await caso('entrada inteira com campo extra é recusada',
  assertFails(updateDoc(plano(bob, 'p1'),
    {'participantes.bob': {nome: 'Bob', lidos: [], revisao: 1700000000000, lixo: 'x'}})));
// [1], não []: os dias do bob já estão vazios aqui, e gravar o mesmo valor
// não muda a entrada, então a regra nem a veria.
await caso('criadora não mexe na entrada do bob junto com a revisão',
  assertFails(updateDoc(plano(alice, 'p1'),
    {revisao: 1700000000002, 'participantes.bob.lidos': [1]})));
await caso('carol entra pelo link num plano já revisado (arrayUnion, como entrar())',
  assertSucceeds(updateDoc(plano(carolDoGoogle, 'p1'), {
    'participantes.carol-google.nome': 'Carol',
    'participantes.carol-google.lidos': arrayUnion(),
  })));
await caso('criação com revisao é recusada',
  assertFails(setDoc(plano(alice, 'p8'), {...planoValido(), revisao: 1})));
await caso('bob sai do plano',
  assertSucceeds(updateDoc(plano(bob, 'p1'), {'participantes.bob': deleteField()})));
await caso('quem não criou não exclui o plano',
  assertFails(deleteDoc(plano(bob, 'p1'))));
await caso('criadora exclui o plano',
  assertSucceeds(deleteDoc(plano(alice, 'p1'))));

// --- Firestore: planos, leitura, listagem e exclusão ------------------- //
const planoDaAlice = (id) => setDoc(plano(alice, id),
  {...planoValido(), participantes: {alice: {nome: 'Alice', lidos: [1]}}});
const consultaDeParticipante = (ctx, uid) => getDocs(query(
  collection(ctx.firestore(), 'planos'), where(`participantes.${uid}`, '!=', null)));

await caso('seed: plano da alice com bob dentro', (async () => {
  await assertSucceeds(planoDaAlice('p10'));
  await assertSucceeds(updateDoc(plano(bob, 'p10'),
    {'participantes.bob': {nome: 'Bob', lidos: [2]}}));
})());
await caso('list por participantes passa para o próprio uid',
  assertSucceeds(consultaDeParticipante(bob, 'bob')));
await caso('list por participantes devolve o plano em que participa', (async () => {
  const resultado = await consultaDeParticipante(bob, 'bob');
  if (!resultado.docs.some((d) => d.id === 'p10')) throw new Error('p10 ausente');
})());
await caso('list por participantes falha para o uid alheio',
  assertFails(consultaDeParticipante(bob, 'alice')));
await caso('list sem filtro de participante falha',
  assertFails(getDocs(collection(bob.firestore(), 'planos'))));
await caso('get de plano existente em que não participa falha',
  assertFails(getDoc(plano(carolDoGoogle, 'p10'))));
await caso('get de plano apagado devolve exists=false para quem tem login', (async () => {
  const snapshot = await assertSucceeds(getDoc(plano(bob, 'nunca-existiu')));
  if (snapshot.exists()) throw new Error('deveria não existir');
})());
await caso('get de plano apagado falha sem login Google',
  assertFails(getDoc(plano(anonimo, 'nunca-existiu'))));
await caso('delete de plano já apagado passa',
  assertSucceeds(deleteDoc(plano(bob, 'nunca-existiu'))));
await caso('delete de plano alheio existente continua falhando',
  assertFails(deleteDoc(plano(bob, 'p10'))));
await caso('delete de plano inexistente falha sem login Google',
  assertFails(deleteDoc(plano(anonimo, 'nunca-existiu'))));

// arrayUnion/arrayRemove nos dias lidos e o entrar com arrayUnion([]).
await caso('arrayUnion nos próprios lidos passa',
  assertSucceeds(updateDoc(plano(bob, 'p10'),
    {'participantes.bob.lidos': arrayUnion(3)})));
await caso('arrayRemove nos próprios lidos passa',
  assertSucceeds(updateDoc(plano(bob, 'p10'),
    {'participantes.bob.lidos': arrayRemove(2)})));
await caso('arrayUnion nos lidos da alice falha para o bob',
  assertFails(updateDoc(plano(bob, 'p10'),
    {'participantes.alice.lidos': arrayUnion(9)})));
await caso('arrayRemove nos lidos da alice falha para o bob',
  assertFails(updateDoc(plano(bob, 'p10'),
    {'participantes.alice.lidos': arrayRemove(1)})));
await caso('lidos do bob ficaram [3] após union e remove', (async () => {
  const lidos = (await getDoc(plano(bob, 'p10'))).data().participantes.bob.lidos;
  if (JSON.stringify(lidos) !== '[3]') throw new Error(JSON.stringify(lidos));
})());

await caso('seed: plano só da alice',
  assertSucceeds(planoDaAlice('p11')));
await caso('entrar com nome e arrayUnion([]) cria lidos=[] quando falta', (async () => {
  await assertSucceeds(updateDoc(plano(bob, 'p11'), {
    'participantes.bob.nome': 'Bob',
    'participantes.bob.lidos': arrayUnion(),
  }));
  const entrada = (await getDoc(plano(bob, 'p11'))).data().participantes.bob;
  if (entrada.nome !== 'Bob' || entrada.lidos.length !== 0) {
    throw new Error(JSON.stringify(entrada));
  }
})());
await caso('entrar de novo com arrayUnion([]) preserva os lidos existentes', (async () => {
  await assertSucceeds(updateDoc(plano(bob, 'p11'),
    {'participantes.bob.lidos': arrayUnion(4, 5)}));
  await assertSucceeds(updateDoc(plano(bob, 'p11'), {
    'participantes.bob.nome': 'Bob',
    'participantes.bob.lidos': arrayUnion(),
  }));
  const lidos = (await getDoc(plano(bob, 'p11'))).data().participantes.bob.lidos;
  if (JSON.stringify(lidos) !== '[4,5]') throw new Error(JSON.stringify(lidos));
})());
await caso('entrar com nome e arrayUnion([]) na entrada alheia falha',
  assertFails(updateDoc(plano(bob, 'p11'), {
    'participantes.alice.nome': 'Falsa',
    'participantes.alice.lidos': arrayUnion(),
  })));

// --- Firestore: config/recursos ----------------------------------------- //
const recursos = (ctx) => doc(ctx.firestore(), 'config', 'recursos');
const configValida = () => ({conversasAtivas: true, atualizadoEm: serverTimestamp()});

await caso('só o dono grava config/recursos',
  assertSucceeds(setDoc(recursos(dono), configValida())));
await caso('dono grava comentarioNoCapituloAtivo em config/recursos',
  assertSucceeds(setDoc(recursos(dono),
    {comentarioNoCapituloAtivo: true, atualizadoEm: serverTimestamp()}, {merge: true})));
await caso('recusa comentarioNoCapituloAtivo que não é bool',
  assertFails(setDoc(recursos(dono),
    {comentarioNoCapituloAtivo: 'sim', atualizadoEm: serverTimestamp()})));
await caso('recusa campo desconhecido em config/recursos, mesmo vindo do dono',
  assertFails(setDoc(recursos(dono), {campoInventado: 1, atualizadoEm: serverTimestamp()})));
await caso('outro e-mail não grava config/recursos',
  assertFails(setDoc(recursos(outroEmail), configValida())));
await caso('usuário comum não grava config/recursos',
  assertFails(setDoc(recursos(alice), configValida())));
await caso('anônimo não grava config/recursos',
  assertFails(setDoc(recursos(anonimo), configValida())));
await caso('usuário logado lê config/recursos',
  assertSucceeds(getDoc(recursos(alice))));
await caso('anônimo também lê config/recursos',
  assertSucceeds(getDoc(recursos(anonimo))));
await caso('dono apaga a lista antiga de convidados de config/recursos',
  assertSucceeds(setDoc(recursos(dono),
    {emailsComConversas: deleteField(), atualizadoEm: serverTimestamp()}, {merge: true})));

// --- Firestore: convidados/{email} --------------------------------------- //
const convite = (ctx, email) => doc(ctx.firestore(), 'convidados', email);
const conviteValido = () => ({criadoEm: serverTimestamp()});
const convidados = (ctx) => getDocs(collection(ctx.firestore(), 'convidados'));

await caso('dono convida um e-mail',
  assertSucceeds(setDoc(convite(dono, 'outro@example.com'), conviteValido())));
await caso('dono convida de novo o mesmo e-mail',
  assertSucceeds(setDoc(convite(dono, 'outro@example.com'), conviteValido())));
await caso('recusa convite com campo a mais',
  assertFails(setDoc(convite(dono, 'x@example.com'), {...conviteValido(), nota: 'a'})));
await caso('recusa convite com e-mail em maiúsculas',
  assertFails(setDoc(convite(dono, 'X@example.com'), conviteValido())));
await caso('convidado lê o próprio convite',
  assertSucceeds(getDoc(convite(outroEmail, 'outro@example.com'))));
const comEmail = (uid, email, provedor = 'google.com') =>
  env.authenticatedContext(uid, {email, firebase: {sign_in_provider: provedor}});

await caso('conta sem e-mail no token não lê o convite alheio',
  assertFails(getDoc(convite(alice, 'outro@example.com'))));
await caso('outro convidado não lê o convite alheio',
  assertFails(getDoc(convite(comEmail('vizinho', 'vizinho@example.com'),
    'outro@example.com'))));
await caso('mesmo e-mail por senha, sem Google, não lê o convite',
  assertFails(getDoc(convite(comEmail('senha', 'outro@example.com', 'password'),
    'outro@example.com'))));
await caso('e-mail em maiúsculas no token lê o convite em minúsculas',
  assertSucceeds(getDoc(convite(comEmail('caixa', 'Outro@Example.com'),
    'outro@example.com'))));
await caso('conta sem convite lê o próprio caminho, que não existe',
  assertSucceeds(getDoc(convite(comEmail('vizinho', 'vizinho@example.com'),
    'vizinho@example.com'))));
await caso('anônimo não lê convite',
  assertFails(getDoc(convite(anonimo, 'outro@example.com'))));
await caso('convidado não lista os convidados',
  assertFails(convidados(outroEmail)));
await caso('anônimo não lista os convidados',
  assertFails(convidados(anonimo)));
await caso('dono lista os convidados',
  assertSucceeds(convidados(dono)));
await caso('conta comum não se convida',
  assertFails(setDoc(convite(outroEmail, 'outro2@example.com'), conviteValido())));
await caso('convidado não apaga o próprio convite',
  assertFails(deleteDoc(convite(outroEmail, 'outro@example.com'))));
await caso('dono remove o convite',
  assertSucceeds(deleteDoc(convite(dono, 'outro@example.com'))));

// --- Firestore: usuarios/{uid}, campos do contrato ---------------------- //
const mesclar = (ctx, uid, campos) => setDoc(doc(ctx.firestore(), 'usuarios', uid),
  {...campos, atualizadoEm: serverTimestamp()}, {merge: true});
const copiaValida = () => ({versao: 1, marcacoes: [], dias_lidos: []});
const planosDoUsuario = () => ({planos: [], planos_lidos: {}});
const livrosDoUsuario = () => ({versao: 1, livros: {}, destaques: []});
const lembretesValidos = () =>
  ({ativo: true, manha: 360, promessas: 360, leitura: 480, noite: 1260});

await caso('grava a própria copia',
  assertSucceeds(mesclar(alice, 'alice', {copia: copiaValida()})));
await caso('copia com chave extra é recusada',
  assertFails(mesclar(alice, 'alice', {copia: {...copiaValida(), extra: 1}})));
await caso('chave extra no topo do documento é recusada',
  assertFails(mesclar(alice, 'alice', {lixo: 1})));
await caso('não grava a copia do bob',
  assertFails(mesclar(alice, 'bob', {copia: copiaValida()})));
await caso('grava os próprios planos',
  assertSucceeds(mesclar(alice, 'alice', {planos: planosDoUsuario()})));
await caso('planos com chave extra são recusados',
  assertFails(mesclar(alice, 'alice', {planos: {...planosDoUsuario(), x: 1}})));
await caso('planos aceita planos_concluidos e planos_recomecados',
  assertSucceeds(mesclar(alice, 'alice', {planos: {...planosDoUsuario(),
    planos_concluidos: {p1: 1764000000000},
    planos_recomecados: {p1: 1763000000000}}})));
await caso('planos recusa chave desconhecida',
  assertFails(mesclar(alice, 'alice', {planos: {...planosDoUsuario(),
    planos_concluidos: {}, planos_pausados: {}}})));
await caso('planos_concluidos como lista é recusado',
  assertFails(mesclar(alice, 'alice', {planos: {...planosDoUsuario(),
    planos_concluidos: ['p1']}})));
await caso('planos_recomecados como número é recusado',
  assertFails(mesclar(alice, 'alice', {planos: {...planosDoUsuario(),
    planos_recomecados: 1}})));
await caso('não grava os planos do bob',
  assertFails(mesclar(alice, 'bob', {planos: planosDoUsuario()})));
await caso('grava a própria leitura de livros',
  assertSucceeds(mesclar(alice, 'alice', {livros: livrosDoUsuario()})));
await caso('livros com chave extra são recusados',
  assertFails(mesclar(alice, 'alice', {livros: {...livrosDoUsuario(), x: 1}})));
await caso('não grava os livros do bob',
  assertFails(mesclar(alice, 'bob', {livros: livrosDoUsuario()})));
await caso('grava os próprios lembretes',
  assertSucceeds(mesclar(alice, 'alice', {lembretes: lembretesValidos()})));
await caso('lembretes com horário fora da faixa são recusados',
  assertFails(mesclar(alice, 'alice', {lembretes: {...lembretesValidos(), manha: 1440}})));
await caso('não grava os lembretes do bob',
  assertFails(mesclar(alice, 'bob', {lembretes: lembretesValidos()})));

// --- Firestore: usuarios/{uid}.conversas ------------------------------- //
const usuario = (ctx) => doc(ctx.firestore(), 'usuarios', 'alice');
await caso('conversas como mapa passa',
  assertSucceeds(setDoc(usuario(alice),
    {conversas: {spurgeon: []}, atualizadoEm: serverTimestamp()})));
await caso('conversas como string é recusada',
  assertFails(setDoc(usuario(alice),
    {conversas: 'não é mapa', atualizadoEm: serverTimestamp()})));
await caso('conversas como lista é recusada',
  assertFails(setDoc(usuario(alice),
    {conversas: ['não', 'é', 'mapa'], atualizadoEm: serverTimestamp()})));
await caso('login que não é Google não ganha documento',
  assertFails(setDoc(doc(semGoogle.firestore(), 'usuarios', 'carol'),
    {conversas: {}, atualizadoEm: serverTimestamp()})));
await caso('outro usuário não grava no documento alheio',
  assertFails(setDoc(doc(bob.firestore(), 'usuarios', 'alice'),
    {conversas: {}, atualizadoEm: serverTimestamp()})));

// --- Firestore: lembretes (sem login, de propósito) -------------------- //
const token = 'tok' + 'x'.repeat(140);
const lembrete = {
  token, minutosManha: 360, minutosPromessas: 360, minutosLeitura: 480,
  minutosNoite: 1260, fuso: 'America/Sao_Paulo',
};
await caso('anônimo ainda registra lembrete (não pode quebrar)',
  assertSucceeds(setDoc(doc(anonimo.firestore(), 'lembretes', token), lembrete)));
await caso('lembrete com token diferente do id é recusado',
  assertFails(setDoc(doc(anonimo.firestore(), 'lembretes', 'outro'), lembrete)));

const fid = 'fid' + 'y'.repeat(20);
const lembretePorFid = {
  fid, minutosManha: 360, minutosPromessas: 360, minutosLeitura: 480,
  minutosNoite: 1260, fuso: 'America/Sao_Paulo',
};
const lembreteAnonimo = (id) => doc(anonimo.firestore(), 'lembretes', id);
await caso('lembrete por fid grava com id igual ao fid',
  assertSucceeds(setDoc(lembreteAnonimo(fid), lembretePorFid)));
await caso('lembrete por fid com id diferente do fid é recusado',
  assertFails(setDoc(lembreteAnonimo('outro-fid'), lembretePorFid)));
await caso('lembrete por fid regravado por inteiro, sem proximoEnvio, continua válido',
  assertSucceeds(setDoc(lembreteAnonimo(fid), {...lembretePorFid, minutosManha: 400})));
await caso('cliente não grava proximoEnvio (só a Function, via Admin SDK)',
  assertFails(setDoc(lembreteAnonimo(fid), {...lembretePorFid, proximoEnvio: 'x'})));
await caso('lista de lembretes é negada',
  assertFails(getDocs(collection(anonimo.firestore(), 'lembretes'))));

// --- Firestore: denúncias de resposta da IA ---------------------------- //
const denunciaValida = () => ({
  uid: 'alice',
  criadoEm: serverTimestamp(),
  motivo: 'doutrina',
  detalhe: 'A referência do versículo está trocada.',
  persona: 'spurgeon',
  conversaId: 'c1',
  mensagemId: 'm2',
  pergunta: 'O que significa Gênesis 1:1?',
  resposta: 'Uma resposta gerada pela IA.',
  versao: '1.22.0',
  plataforma: 'web',
});
const denuncia = (ctx, id = 'd1') => doc(ctx.firestore(), 'denuncias', id);

await caso('denúncia com o próprio uid e os campos do contrato passa',
  assertSucceeds(setDoc(denuncia(alice), denunciaValida())));
await caso('denúncia com uid de outra conta é recusada',
  assertFails(setDoc(denuncia(bob, 'd2'), {...denunciaValida(), uid: 'alice'})));
await caso('denúncia anônima é recusada',
  assertFails(setDoc(doc(anonimo.firestore(), 'denuncias', 'd3'),
    {...denunciaValida(), uid: 'ninguem'})));
await caso('denúncia de login que não é Google é recusada',
  assertFails(setDoc(doc(semGoogle.firestore(), 'denuncias', 'd4'),
    {...denunciaValida(), uid: 'carol'})));
await caso('denúncia com motivo fora da lista é recusada',
  assertFails(setDoc(denuncia(alice, 'd5'),
    {...denunciaValida(), motivo: 'qualquer coisa'})));
await caso('denúncia com campo extra é recusada',
  assertFails(setDoc(denuncia(alice, 'd6'),
    {...denunciaValida(), extra: 'x'})));
await caso('denúncia com resposta acima do teto é recusada',
  assertFails(setDoc(denuncia(alice, 'd7'),
    {...denunciaValida(), resposta: 'x'.repeat(30001)})));
await caso('denúncia não é legível pelo cliente',
  assertFails(getDoc(denuncia(alice))));
await caso('denúncias não podem ser listadas',
  assertFails(getDocs(collection(alice.firestore(), 'denuncias'))));
await caso('denúncia não pode ser alterada',
  assertFails(updateDoc(denuncia(alice), {detalhe: 'outro texto'})));
await caso('denúncia não pode ser apagada',
  assertFails(deleteDoc(denuncia(alice))));

// --- Firestore: erros (só a Function, via Admin SDK) ------------------- //
await caso('cliente não grava relatório de erro',
  assertFails(setDoc(doc(alice.firestore(), 'erros', 'e1'),
    {origem: 'dart', mensagem: 'x'})));
await caso('cliente não lê relatório de erro',
  assertFails(getDoc(doc(alice.firestore(), 'erros', 'e1'))));

await env.cleanup();
console.log(falhas === 0 ? '\nTodas as regras ok.' : `\n${falhas} falha(s).`);
process.exit(falhas === 0 ? 0 : 1);
