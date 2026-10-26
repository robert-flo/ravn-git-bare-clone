# ravn-git-bare-clone

Launcher y runtime modular de clonación bare y gestión de worktrees para Arch Linux (Arquetipo A).

## Características

- **Clonación bare y worktrees automáticos:** Clona repositorios remotos en `$BARE_HOME/<repo>.git` y genera worktrees con upstream tracking para las ramas remotas no-default en `$WORKTREES_HOME/<repo>/<branch>`.
- **Master / rama default libre:** La rama default (`origin/HEAD`, e.g. `main` o `master`) no se checkoutea automáticamente para permitir trabajo en paralelo sin colisiones entre agentes o tareas.
- **Módulos create e issue:** Permite crear nuevos worktrees vinculados a ramas o issues de GitHub con tracking upstream.
- **Sincronización idempotente:** Al re-ejecutar sobre repositorios existentes (`clone` o `sync`), actualiza referencias remotas (`git fetch origin`) y crea worktrees únicamente para las ramas remotas faltantes.
- **Soporte de lotes:** Permite clonar múltiples repositorios organizados en grupos mediante `--group <ruta> <repos...>`.
- **Completions y compatibilidad:** Autocompletado para bash y zsh; provee comandos de compatibilidad `git-bare-clone`, `git-create-worktree` y `git-issue-worktree`.
- **Arquitectura modular (Arquetipo A):** Estructura inspirada en `git-setup` con catálogo TSV de comandos (`runtime/commands.tsv`), despacho dinámico (`runtime/lib/dispatch.sh`), librerías compartidas y scripts autónomos en `runtime/scripts/`.

## Estructura del Repositorio

```text
├── Makefile
├── ravn-git-bare-clone           # Launcher raíz ejecutable
├── bin/                          # Wrappers de compatibilidad
│   ├── git-bare-clone
│   ├── git-create-worktree
│   └── git-issue-worktree
├── runtime/
│   ├── commands.tsv              # Catálogo de comandos y alias
│   ├── completion/               # Scripts de autocompletado
│   │   ├── _git-bare-clone       # Completions para Zsh
│   │   └── git-bare-clone.bash   # Completions para Bash
│   ├── helper/
│   │   └── set_variable.sh       # Variables de entorno y rutas base
│   ├── lib/
│   │   ├── command_catalog.sh    # Parser del catálogo de comandos
│   │   ├── command_interface.sh  # Validación de argumentos y opciones
│   │   ├── dispatch.sh           # Despachador hacia scripts ejecutables
│   │   ├── global_fn.sh          # Librería global de utilidades (100644)
│   │   ├── lifecycle.sh          # Captura de señales y cleanup
│   │   └── presentation.sh       # Formateo de terminal y presentación
│   └── scripts/
│       ├── clone                 # Implementación del comando clone
│       ├── create                # Implementación del comando create
│       ├── help                  # Implementación del comando help
│       ├── issue                 # Implementación del comando issue
│       └── sync                  # Implementación del comando sync
└── tests/
    ├── run.sh                    # Runner de pruebas
    ├── test-completion.sh
    ├── test-git-bare-clone-batch.sh
    ├── test-git-bare-clone-defaults.sh
    ├── test-git-bare-clone-sync.sh
    ├── test-git-worktree-base.sh
    └── test-set-variable.sh
```

## Uso

### Modo Interactivo

Ejecutá el launcher sin argumentos para abrir el menú interactivo:

```bash
ravn-git-bare-clone
```

### Comandos Directos

```bash
# Clonar repositorio individual (master queda libre)
ravn-git-bare-clone clone git@github.com:user/repo.git
ravn-git-bare-clone clone robert-flo/alpha

# Clonar con directorio personalizado de worktrees
ravn-git-bare-clone clone -w /ruta/custom user/repo

# Clonar lotes de repositorios por grupo
ravn-git-bare-clone clone \
  --group /z/repos/core org/api org/web \
  --group /z/repos/tools org/cli

# Sincronizar ramas remotas faltantes
ravn-git-bare-clone sync org/repo

# Crear un worktree nuevo con tracking upstream
ravn-git-bare-clone create nueva-feature

# Crear un worktree vinculado a un issue de GitHub
ravn-git-bare-clone issue 42 fix-login

# Ver ayuda
ravn-git-bare-clone help
ravn-git-bare-clone clone -h
```

### Comandos de Compatibilidad

Se mantienen como accesos directos compatibles con los llamadores existentes:

```bash
git-bare-clone <repo>
git-create-worktree <nombre>
git-issue-worktree <issue> <slug>
```

## Instalación

```bash
make install PREFIX=/opt/ravn-git-bare-clone BINDIR=/usr/bin
```

## Pruebas y Validación

```bash
make lint   # Valida con shellcheck
make test   # Ejecuta la suite de pruebas bash
make check  # Ejecuta lint y test
```

## Licencia

[MIT](LICENSE)
