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
  doc, setDoc, updateDoc, deleteDoc, deleteField, serverTimestamp,
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

// --- Storage: foto de perfil ------------------------------------------- //
await caso('dono envia a própria foto jpeg',
  assertSucceeds(uploadBytes(fotoDaAlice(alice), jpeg, {contentType: 'image/jpeg'})));
await caso('dono APAGA a própria foto (o bug corrigido)',
  assertSucceeds(deleteObject(fotoDaAlice(alice))));
await uploadBytes(fotoDaAlice(alice), jpeg, {contentType: 'image/jpeg'});
await caso('dono troca a foto regravando o mesmo arquivo',
  assertSucceeds(uploadBytes(fotoDaAlice(alice), jpeg, {contentType: 'image/jpeg'})));
await caso('foto de 5 MiB ou mais é recusada',
  assertFails(uploadBytes(fotoDaAlice(alice), new Uint8Array(5 * 1024 * 1024),
    {contentType: 'image/jpeg'})));
await caso('outro usuário não apaga a foto alheia',
  assertFails(deleteObject(fotoDaAlice(bob))));
await caso('anônimo não apaga foto',
  assertFails(deleteObject(fotoDaAlice(anonimo))));
await caso('dono não envia png',
  assertFails(uploadBytes(fotoDaAlice(alice), jpeg, {contentType: 'image/png'})));
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
await caso('bob sai do plano',
  assertSucceeds(updateDoc(plano(bob, 'p1'), {'participantes.bob': deleteField()})));
await caso('quem não criou não exclui o plano',
  assertFails(deleteDoc(plano(bob, 'p1'))));
await caso('criadora exclui o plano',
  assertSucceeds(deleteDoc(plano(alice, 'p1'))));

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

await env.cleanup();
console.log(falhas === 0 ? '\nTodas as regras ok.' : `\n${falhas} falha(s).`);
process.exit(falhas === 0 ? 0 : 1);
