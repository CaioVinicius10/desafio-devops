
## 1. `version: '3'` obsoleto no docker-compose.yaml

Não é erro, mas o Compose v2 cospe esse warning a cada comando:

## 2. Rede `node-network` referenciada mas não declarada

Os três serviços tinham `networks: - node-network`, mas não havia o bloco `networks:` no nível raiz do arquivo declarando essa rede. No Compose v3 antigo isso passava silenciosamente (criava uma rede default), mas no Compose v2 atual é obrigatório declarar.

Adicionei no final do compose:

```yaml
networks:
    node-network:
        driver: bridge
```

## 3. realizei ajustes no `Dockerfile` necessarios de melhoria, como versões alpine e tambem tinha `Dockerfile` com varios comandos que podiam ser otimizados em um unico comando fiz isso tambem.

## 4. `mysql` v2.18.1 não conversa com MySQL 8 (caching_sha2_password)

O MySQL 8 usa `caching_sha2_password` como plugin de auth padrão. O driver `mysql@2.18.1` (sem release desde 2018) não suporta isso - ele só conhece `mysql_native_password`. Resultado: a conexão falha silenciosamente, o callback recebe erro, o código ignora e tenta iterar em `undefined`.

Troquei `mysql` por `mysql2` no `package.json`:

```json
"mysql2": "^3.11.0"
```

E no `connectionDb.js`:

```js
const mysql = require('mysql2');
```

API é compatível, não precisou mexer em nada no `routes.js`. Bonus: o `mysql2` é mantido ativamente, suporta os métodos novos de auth e tem prepared statements de verdade.

---

## 5. `Unknown database 'nodedb'`

Com o `mysql2` no lugar, o erro ficou bem mais claro (em vez de engolir como o `mysql` v2 fazia):

```
code: 'ER_BAD_DB_ERROR',
errno: 1049,
sqlMessage: "Unknown database 'nodedb'"
```

O `connectionDb.js` tinha:

```js
database: process.env.DATABASE || 'nodedb'
```

Só que o banco criado pelo `init.sql` e pelo `MYSQL_DATABASE` do compose se chama `node_db` (com underscore). Como o container não tinha `.env` carregado, caía no default errado e tentava se conectar num banco que não existe.

Aproveitei pra resolver outro env do mesmo arquivo: a linha

```js
user: process.env.USER || 'root'
```
Renomeei todas as variáveis pra prefixo `DB_` para seguir um padrão que fosse mais profissional.

```js
host:     process.env.DB_HOST     || 'db',
user:     process.env.DB_USER     || 'root',
password: process.env.DB_PASSWORD || 'root',
database: process.env.DB_NAME     || 'node_db'
```

E passei as variáveis direto no compose, pro container não depender de `.env` na máquina de quem rodar:

```yaml
app:
    environment:
        - DB_HOST=db
        - DB_USER=root
        - DB_PASSWORD=root
        - DB_NAME=node_db
```

O `.env.example` foi atualizado pra refletir os novos nomes.

---

## 6. `502 Bad Gateway` no nginx

Com a app respondendo direto na porta 3000 (testei com `Invoke-WebRequest http://localhost:3000` e veio 200), o nginx ainda dava 502.

Olhando o `nginx.conf`:

```nginx
location / {
    proxy_pass http://app;
}
```

Sem porta. Quando o `proxy_pass` é só `http://app`, o nginx vai pra porta 80 do host `app` por padrão - mas o app escuta na 3000.

Troquei pra:

```nginx
proxy_pass http://app:3000;
```
---

Teve tambem uma implementação de uma melhoria que realizei de rota de /health como melhoria para monitoramos se a aplicação está health ou unhealth.


Criei tambem uma pasta chamada K8S e nela temos uma pasta referente ao mysql, nginx e ao node com os manifestos kubernetes prontos para subir.

para o deploy eu usei a pratica de Kustomize onde temos duas pastas, base e overlays, basicamente oque vai ser aplicado será o conteudo da pasta overlays tem duas pastas gar [google artifact registry] e local, local para deploy localmente e gar puxando a imagem em cloud e deploy em um cluster ambiente que subir localmente do kubernetes na minha maquina. Todos os containers usando imagens baseada em deploy por hash do commit por ex: sha-f4cd7a6.

### CI/CD (GitHub Actions)

O workflow `.github/workflows/build-and-deploy.yml` faz na nuvem:

- build das 3 imagens (app, nginx, db)
- push no Google Artifact Registry com tag `sha-<commit>`
- atualiza o `k8s/overlays/gar/kustomization.yaml` no git (GitOps)

O `kubectl apply` **nao roda no CI** — o cluster e local (Docker Desktop) e a nuvem nao alcanca `kubernetes.docker.internal`.

Secrets necessarios no GitHub: `GCP_PROJECT_ID`, `GAR_LOCATION`, `GAR_REPOSITORY`, `GCP_SA_KEY`. O secret `KUBECONFIG` nao e usado.
