# Contribuindo / Contributing

Contribuições são bem-vindas. / Contributions are welcome.

1. Abra uma *issue* descrevendo o problema ou a ideia antes de mudanças grandes. / Open an issue before big changes.
2. Compile com `./build.sh` (precisa só das Command Line Tools). / Build with `./build.sh`.
3. Rode `./tests/run.sh` antes de enviar. Textos novos da interface: use `tr("English text")` e adicione a tradução em `Resources/pt.lproj/Localizable.strings`.
4. Teste ativando/desativando fontes e, se mexer no modo Automático, com um app que só lê pastas de fontes.
5. Não inclua fontes, dados de biblioteca (`library.json`) nem caminhos pessoais no código. / No fonts, no personal paths.
6. Commits no formato `tipo: descrição` (`feat`, `fix`, `docs`, `refactor`). / Conventional commits.

## Se o projeto estiver num HD exFAT
Não deixe a pasta `.git` em volume exFAT (corrompe os pacotes do Git). Use
`git init --separate-git-dir <pasta-no-disco-APFS>`.
