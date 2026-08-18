Este documento descreve as diretrizes e práticas de segurança aplicadas ao projeto **Devocional**, incluindo o processo para reporte de vulnerabilidades, arquitetura de proteção de dados e gestão de segredos.

---

## 1. Versões Suportadas

Apenas a versão mais recente em execução no ambiente de produção (Web via GitHub Pages) e os builds oficiais do aplicativo Android recebem atualizações diretas de segurança.

| Plataforma | Suporte a Correções de Segurança |
| :--- | :--- |
| Web (GitHub Pages) | :white_check_mark: Suportado (Versão Atual) |
| Android (APK / App) | :white_check_mark: Suportado (Versão Atual) |
| Builds legados ou não oficiais | :x: Não suportado |

---

## 2. Arquitetura de Segurança e Privacidade de Dados

O aplicativo foi projetado com o princípio de exposição mínima de dados e processamento prioritariamente local.

### 2.1 Armazenamento Local
- **Dispositivos Móveis (Android):** Os dados de progresso de leitura, anotações e versículos favoritos são salvos exclusivamente no armazenamento local do dispositivo por meio do `shared_preferences`. Não há comunicação automática com servidores de terceiros no Android para sincronização de dados pessoais.
- **Exportação Manual:** A cópia de segurança no Android é realizada via área de transferência (Clipboard) em formato de texto estruturado, permitindo que o próprio usuário gerencie e transporte seus backups com total controle.

### 2.2 Sincronização na Nuvem e Autenticação (Apenas Web)
- **Autenticação:** O login via Conta Google utiliza o método `signInWithPopup` fornecido pelo Firebase Auth. Não são utilizados *redirects* ou *iframes* de terceiros que possam sofrer com restrições de partição de armazenamento ou comprometer a sessão do usuário.
- **Segurança no Firestore:** Cada usuário autenticado possui acesso exclusivo ao seu próprio documento localizado no caminho `usuarios/{uid}`.
- **Regras de Acesso:** O acesso aos dados no Cloud Firestore é protegido por regras rígidas de segurança (`firestore.rules`), garantindo que apenas o proprietário autenticado (`request.auth.uid == userId`) possa ler ou escrever em seu respetivo documento. A remoção de dados locais não apaga registros na nuvem, atuando a sincronização por fusão (*merge*).

---

## 3. Gestão de Chaves de API e Segredos

### 3.1 Injeção de Variáveis em Tempo de Compilação
As chaves de API necessárias para o funcionamento dos serviços integrados (Firebase, IA Gemini e Google Text-to-Speech) não são mantidas estáticas no código-fonte. Elas são injetadas exclusivamente em tempo de compilação via parâmetros `--dart-define`:

- `FIREBASE_API_KEY_WEB`
- `GEMINI_API_KEY_WEB` e `GEMINI_API_KEY_ANDROID`
- `TTS_API_KEY_WEB` e `TTS_API_KEY_ANDROID`

### 3.2 Proteção de Chaves Públicas
Conforme a arquitetura padrão para aplicações no lado do cliente (Web e Mobile), as chaves do Firebase e do Google Cloud presentes nos artefatos de compilação são consideradas públicas por desenho. A segurança dos serviços é assegurada por:

1. **Restrição de Origem no Google Cloud Console:** As chaves de API da Web são restritas aos domínios autorizados do projeto.
2. **Restrição de Escopo de APIs:** As chaves do serviço de voz (Text-to-Speech) e de inteligência artificial possuem escopo limitado estritamente às APIs necessárias para a execução do app.
3. **Regras do Banco de Dados:** O acesso aos dados no Firestore independe da chave de API, sendo controlado integralmente pelas regras de autenticação do backend do Firebase.

---

## 4. Segurança do Pipeline de Integração e Implantação (CI/CD)

- **Fixação de Commit SHA no GitHub Actions:** Todas as ações do GitHub Actions utilizadas no fluxo de *deploy* automatizado (`.github/workflows/deploy-web.yml`) estão fixadas pelo SHA completo do *commit*, prevenindo riscos associados a *tags* mutáveis.
- **Versão Imutável do SDK:** A versão do SDK do Flutter é mantida fixa em `3.44.9` via `.fvmrc` e no pipeline de integração contínua, garantindo reproduzibilidade e prevenindo quebras não auditadas.
- **Segredos do Repositório:** As chaves de compilação de produção são gerenciadas através dos *GitHub Secrets* e disponibilizadas exclusivamente durante o processo de compilação automatizada.

---

## 5. Reportando uma Vulnerabilidade

Caso você identifique uma falha de segurança, vulnerabilidade de exposição de dados ou comportamento inadequado no aplicativo, pedimos que faça o reporte de maneira responsável.

### Como Reportar
**Não abra uma issue pública no GitHub para reportar vulnerabilidades de segurança.**

Em vez disso, utilize o recurso de **Security Advisories** na guia de segurança do repositório no GitHub ou entre em contato diretamente com o mantenedor do projeto.

Ao enviar o relatório, inclua:
1. Descrição clara da vulnerabilidade ou falha encontrada.
2. Passos detalhados para reprodução do problema.
3. Cenário e impacto potencial de exploração.
4. Sugestões de correção, caso possua.

### Prazos de Resposta
- **Confirmação do Recebimento:** Até 48 horas úteis.
- **Análise e Validação:** Até 5 dias úteis.
- **Aplicação da Correção:** As correções validadas serão aplicadas prioritariamente no pipeline e publicadas em produção assim que homologadas.
