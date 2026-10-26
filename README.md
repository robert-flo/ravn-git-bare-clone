# ravn-git-bare-clone

Launcher y runtime modular de clonación bare y gestión de worktrees para Arch Linux (Arquetipo A).

## Características

- **Clonación bare y worktrees automáticos:** Clona repositorios remotos en `$BARE_HOME/<repo>.git` y genera worktrees con upstream tracking para todas las ramas remotas en `$WORKTREES_HOME/<repo>/<branch>`.
- **Sincronización idempotente:** Al re-ejecutar sobre repositorios existentes, actualiza referencias remotas (`git fetch origin`) y crea worktrees únicamente para las ramas remotas nuevas.
- **Soporte de lotes:** Permite clonar múltiples repositorios organizados en grupos mediante `--group <ruta> <repos...>`.
- **Arquitectura modular (Arquetipo A):** Estructura inspirada en `git-setup` con catálogo TSV de comandos (`runtime/commands.tsv`), despacho dinámico (`runtime/lib/dispatch.sh`), librerías compartidas y scripts autónomos en `runtime/scripts/`.

## Estructura del Repositorio

```text
├── Makefile
├── ravn-git-bare-clone           # Launcher raíz ejecutable
├── runtime/
│   ├── commands.tsv              # Catálogo de comandos y alias
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
│       └── help                  # Implementación del comando help
└── tests/
    ├── run.sh                    # Runner de pruebas
    ├── test-git-bare-clone-batch.sh
    ├── test-git-bare-clone-defaults.sh
    └── test-git-bare-clone-sync.sh
```

## Uso

### Modo Interactivo

Ejecutá el launcher sin argumentos para abrir el menú interactivo:

```bash
ravn-git-bare-clone
```

### Comandos Directos

```bash
# Clonar repositorio individual
ravn-git-bare-clone clone git@github.com:user/repo.git
ravn-git-bare-clone clone robert-flo/alpha

# Clonar con directorio personalizado de worktrees
ravn-git-bare-clone clone -w /ruta/custom user/repo

# Clonar lotes de repositorios por grupo
ravn-git-bare-clone clone \
  --group /z/repos/core org/api org/web \
  --group /z/repos/tools org/cli

# Ver ayuda
ravn-git-bare-clone help
ravn-git-bare-clone clone -h
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
