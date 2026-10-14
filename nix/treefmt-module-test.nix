{ runCommand, treefmt }:

runCommand "watermarks-remover-treefmt-module"
  { nativeBuildInputs = [ treefmt.config.build.wrapper ]; }
  ''
    export HOME="$TMPDIR"
    mkdir tree && cd tree
    touch treefmt-root

    zwsp='\342\200\213'
    printf "Hello$zwsp world\n" > marked.md
    printf 'Hello world\n' > clean.txt
    touch -d @1000000000 clean.txt
    printf "fixture$zwsp\n" > fixture.nix
    cp fixture.nix fixture.orig
    [ "$(wc -c < marked.md)" = 15 ] || { echo "fixture lacks the zero-width space"; exit 1; }

    treefmt

    [ "$(cat marked.md)" = "Hello world" ] || { echo "marked.md was not cleaned"; exit 1; }
    [ "$(stat -c %Y clean.txt)" = 1000000000 ] || { echo "clean.txt was rewritten"; exit 1; }
    cmp fixture.nix fixture.orig || { echo "fixture.nix is outside includes but changed"; exit 1; }
    if compgen -G '*.bak' >/dev/null; then echo "backup files left behind"; exit 1; fi

    # Without the cache every file reaches the formatter again, so this fails
    # if a second pass would still change or touch anything.
    treefmt --no-cache --fail-on-change

    touch "$out"
  ''
