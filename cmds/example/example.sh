desc="A short description of the script"
args=("--one:first argument in zsh's _describe format" \
      "--two:[b,o] second argument with argument options (boolean, optional)")
help=("example", "A long description of the script.

 The description can be a multi-line string without an issue.")


execute() {
	echo $(pwd)
    echo $one
    echo $two
}
